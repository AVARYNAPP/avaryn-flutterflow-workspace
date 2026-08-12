require 'json'
require 'open3'
require 'securerandom'
require 'thread'

container = ARGV.shift || 'supabase_db_avaryn-c0091-fresh-stack'
psql = [
  'docker', 'exec', '-i', container, 'psql', '-X', '-A', '-t', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'
].freeze

def sql!(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  raise "Local SQL failed: #{stderr.strip}" unless status.success?
  stdout
end

def authenticated_sql(auth_id, source)
  <<~SQL
    \\set VERBOSITY verbose
    begin;
    set local role authenticated;
    select set_config('request.jwt.claim.role','authenticated',true);
    select set_config('request.jwt.claim.sub','#{auth_id}',true);
    #{source}
    commit;
  SQL
end

def race(psql, statements)
  gate = Queue.new
  ready = Queue.new
  workers = statements.map do |statement|
    Thread.new do
      ready << true
      gate.pop
      Open3.capture3(*psql, stdin_data: statement)
    end
  end
  statements.length.times { ready.pop }
  statements.length.times { gate << true }
  workers.map(&:value)
end

def json_result(stdout)
  JSON.parse(stdout.lines.map(&:strip).find { |line| line.start_with?('{') })
end

auth_id = SecureRandom.uuid
horse_id = sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000','#{auth_id}',
      'authenticated','authenticated','#{auth_id}@example.invalid','',now(),
      '{"provider":"email","providers":["email"]}','{}',now(),now()
    );
    #{authenticated_sql(auth_id, <<~INNER)}
      select horse_id from public.create_canonical_horse_profile(
        'C-009.1 Activity contract race',null,null,'unknown',null,null,null,null,
        null,null,null,null,'#{SecureRandom.uuid}'
      );
    INNER
  SQL
).lines.map(&:strip).select { |line| line.match?(/\A[0-9a-f-]{36}\z/) }.last
raise 'Concurrency horse was not created' unless horse_id

# An exact concurrent replay with a new activity kind and no user note must
# converge on one durable row. Empty instruction is the canonical absence.
request_id = SecureRandom.uuid
create_sql = authenticated_sql(
  auth_id,
  <<~SQL
    select public.upsert_canonical_horse_schedule_item(
      '#{horse_id}',null,null,'farrier','Hoefsmid',null,'normal',
      date_trunc('day',now())+interval '9 hours',
      date_trunc('day',now())+interval '10 hours',
      'Europe/Amsterdam','planned',null,'#{request_id}'
    );
  SQL
)
create_outcomes = race(psql, [create_sql, create_sql])
unless create_outcomes.all? { |_stdout, _stderr, status| status.success? }
  raise "Concurrent optional-note create failed: #{create_outcomes.inspect}"
end
created = create_outcomes.map { |stdout, _stderr, _status| json_result(stdout) }
ids = created.map { |value| value.fetch('schedule_item_id') }
unless ids.uniq.length == 1 && created.count { |value| value.fetch('idempotent') } == 1
  raise "Concurrent replay did not converge: #{created.inspect}"
end
schedule_id = ids.first
state = sql!(
  psql,
  "select count(*) || '|' || max(row_version) || '|' || max(instruction) from public.schedule_items where id='#{schedule_id}';"
).strip
raise "Optional-note idempotency state invalid: #{state}" unless state == '1|1|'

# Two different writers race from the same CAS version. Exactly one advances;
# the other remains fail-closed with the established stale-version error.
updates = [
  ['veterinary', 'Dierenarts'],
  ['transport', 'Transport']
].map do |kind, title|
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.upsert_canonical_horse_schedule_item(
        '#{horse_id}','#{schedule_id}',1,'#{kind}','#{title}',null,'normal',
        date_trunc('day',now())+interval '9 hours',
        date_trunc('day',now())+interval '10 hours',
        'Europe/Amsterdam','planned',null,'#{SecureRandom.uuid}'
      );
    SQL
  )
end
update_outcomes = race(psql, updates)
successes = update_outcomes.count { |_stdout, _stderr, status| status.success? }
stale = update_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+40001:\s+STALE_SCHEDULE_VERSION/)
end
unless successes == 1 && stale == 1
  raise "Expected one contract winner and one stale writer: #{update_outcomes.inspect}"
end
state = sql!(
  psql,
  "select row_version || '|' || item_kind || '|' || instruction from public.schedule_items where id='#{schedule_id}';"
).strip
unless state.match?(/\A2\|(veterinary|transport)\|\z/)
  raise "Activity contract CAS state invalid: #{state}"
end

puts 'C-009.1 Planning activity contract concurrency passed'
