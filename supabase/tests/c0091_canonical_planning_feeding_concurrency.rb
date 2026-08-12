require 'json'
require 'date'
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
        'C-009.1 Planning Feeding race',null,null,'unknown',null,null,null,null,
        null,null,null,null,'#{SecureRandom.uuid}'
      );
    INNER
  SQL
).lines.map(&:strip).select { |line| line.match?(/\A[0-9a-f-]{36}\z/) }.last
raise 'Concurrency horse was not created' unless horse_id

# Two sessions replay the exact same schedule request. The horse advisory lock
# plus receipt must converge on one durable row and two successful results.
schedule_request = SecureRandom.uuid
schedule_create = authenticated_sql(
  auth_id,
  <<~SQL
    select public.upsert_canonical_horse_schedule_item(
      '#{horse_id}',null,null,'training','Race training','Same request','normal',
      date_trunc('day',now())+interval '9 hours',
      date_trunc('day',now())+interval '10 hours',
      'Europe/Amsterdam','planned',null,'#{schedule_request}'
    );
  SQL
)
create_outcomes = race(psql, [schedule_create, schedule_create])
unless create_outcomes.all? { |_stdout, _stderr, status| status.success? }
  raise "Concurrent schedule create failed: #{create_outcomes.inspect}"
end
created_ids = create_outcomes.map { |stdout, _stderr, _status| json_result(stdout).fetch('schedule_item_id') }
unless created_ids.uniq.length == 1
  raise "Concurrent schedule create diverged: #{created_ids.inspect}"
end
schedule_id = created_ids.first
schedule_state = sql!(
  psql,
  "select count(*) || '|' || max(row_version) from public.schedule_items where id='#{schedule_id}';"
).strip
raise "Schedule idempotency state invalid: #{schedule_state}" unless schedule_state == '1|1'

# Two different writers start from the same CAS version. Exactly one advances
# the row and the other must fail stale without partial mutation.
update_statements = ['A', 'B'].map do |suffix|
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.upsert_canonical_horse_schedule_item(
        '#{horse_id}','#{schedule_id}',1,'training','Race #{suffix}',
        'CAS writer #{suffix}','normal',
        date_trunc('day',now())+interval '9 hours',
        date_trunc('day',now())+interval '10 hours',
        'Europe/Amsterdam','planned',null,'#{SecureRandom.uuid}'
      );
    SQL
  )
end
update_outcomes = race(psql, update_statements)
successes = update_outcomes.count { |_stdout, _stderr, status| status.success? }
stale = update_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+40001:\s+STALE_SCHEDULE_VERSION/)
end
unless successes == 1 && stale == 1
  raise "Expected one schedule winner and one stale writer: #{update_outcomes.inspect}"
end
schedule_state = sql!(
  psql,
  "select row_version || '|' || title from public.schedule_items where id='#{schedule_id}';"
).strip
unless schedule_state.start_with?('2|Race ')
  raise "Schedule CAS state invalid: #{schedule_state}"
end

def create_approved_plan(psql, auth_id, horse_id, plan_type, name, from, through)
  create = json_result(sql!(
    psql,
    authenticated_sql(
      auth_id,
      <<~SQL
        select public.create_canonical_horse_feeding_plan(
          '#{horse_id}','#{plan_type}','#{name}','#{from}',
          #{through ? "'#{through}'" : 'null'},'Concurrency plan','#{SecureRandom.uuid}'
        );
      SQL
    )
  ))
  version_id = create.fetch('feeding_plan_version_id')
  sql!(
    psql,
    authenticated_sql(
      auth_id,
      <<~SQL
        select public.upsert_canonical_horse_feeding_item(
          '#{horse_id}','#{version_id}',null,null,'feed',null,'Race feed',null,
          1,'kg','bucket','ochtend','07:00',null,null,
          '#{SecureRandom.uuid}',null,'#{SecureRandom.uuid}'
        );
        select public.transition_canonical_horse_feeding_version(
          '#{horse_id}','#{version_id}',1,'approve','#{SecureRandom.uuid}'
        );
      SQL
    )
  )
  [create.fetch('feeding_plan_id'), version_id]
end

today = Date.today
base_plan, base_version = create_approved_plan(
  psql, auth_id, horse_id, 'standard', 'Race base', today, nil
)
sql!(
  psql,
  authenticated_sql(
    auth_id,
    "select public.transition_canonical_horse_feeding_version('#{horse_id}','#{base_version}',2,'activate','#{SecureRandom.uuid}');"
  )
)

temp_a_plan, temp_a_version = create_approved_plan(
  psql, auth_id, horse_id, 'temporary', 'Race temporary A', today, today + 2
)
temp_b_plan, temp_b_version = create_approved_plan(
  psql, auth_id, horse_id, 'temporary', 'Race temporary B', today + 1, today + 3
)

activation_statements = [temp_a_version, temp_b_version].map do |version_id|
  authenticated_sql(
    auth_id,
    "select public.transition_canonical_horse_feeding_version('#{horse_id}','#{version_id}',2,'activate','#{SecureRandom.uuid}');"
  )
end
activation_outcomes = race(psql, activation_statements)
activation_successes = activation_outcomes.count { |_stdout, _stderr, status| status.success? }
conflicts = activation_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+23P01:\s+TEMPORARY_FEEDING_PLAN_CONFLICT/)
end
unless activation_successes == 1 && conflicts == 1
  raise "Expected one temporary activation and one overlap conflict: #{activation_outcomes.inspect}"
end

feeding_state = sql!(
  psql,
  <<~SQL
    select
      count(*) filter (where plan_type='standard' and status='active') || '|' ||
      count(*) filter (where plan_type='temporary' and status='active') || '|' ||
      count(*) filter (where stable_id is null)
    from public.feeding_plans where horse_id='#{horse_id}';
  SQL
).strip
unless feeding_state == '1|1|3'
  raise "Feeding activation/standalone state invalid: #{feeding_state}"
end

puts 'C-009.1 canonical Planning/Feeding concurrency passed'
