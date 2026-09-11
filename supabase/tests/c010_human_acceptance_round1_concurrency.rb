require 'json'
require 'open3'
require 'securerandom'
require 'thread'

container = ARGV.shift || 'supabase_db_avaryn-c0091-fresh-stack'
database = ARGV.shift || 'postgres'
psql = [
  'docker', 'exec', '-i', '-e', 'PGPASSWORD=postgres', container,
  'psql', '-X', '-A', '-t', '-q', '-v', 'ON_ERROR_STOP=1',
  '-U', 'supabase_admin', '-d', database,
].freeze

def sql!(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  raise "Local SQL failed: #{stderr.strip}" unless status.success?

  stdout
end

def authenticated_sql(auth_id, source)
  <<~SQL
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

auth_id = SecureRandom.uuid
sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values(
      '00000000-0000-0000-0000-000000000000','#{auth_id}',
      'authenticated','authenticated','#{auth_id}@example.invalid','',now(),
      '{}','{}',now(),now()
    );
  SQL
)
profile_id = sql!(
  psql,
  "select id from public.profiles where auth_user_id='#{auth_id}';",
).strip
stable_id, task_id = sql!(
  psql,
  authenticated_sql(
    auth_id,
    <<~SQL
      with stable as(
        select public.create_c010_stable(
          'Round 1 concurrency','Local','#{SecureRandom.uuid}'
        ) result
      ), task as(
        select public.upsert_c010_stable_task(
          (stable.result->>'organization_id')::uuid,null,null,
          'Concurrent task',null,'other',current_date,null,'#{profile_id}',
          null,null,null,'#{SecureRandom.uuid}'
        ) result from stable
      )
      select (stable.result->>'organization_id')||'|'||(task.result->>'task_id')
      from stable,task;
    SQL
  ),
).lines.map(&:strip).find { |line| line.count('|') == 1 }.split('|', 2)

unless [stable_id, task_id].all? { |value| value&.match?(/\A[0-9a-f-]{36}\z/) }
  raise 'C-010 Round 1 concurrency fixture invalid'
end

requests = %w[complete cancel].map do |action|
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.transition_c010_stable_task(
        '#{stable_id}','#{task_id}',1,'#{action}','#{SecureRandom.uuid}'
      );
    SQL
  )
end
outcomes = race(psql, requests)
successes = outcomes.count { |_stdout, _stderr, status| status.success? }
stale = outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/STALE_TASK_VERSION/)
end
unless successes == 1 && stale == 1
  raise "Concurrent task transitions did not serialize: #{outcomes.inspect}"
end

state = sql!(
  psql,
  <<~SQL
    select status||'|'||row_version||'|'||(
      select count(*) from public.stable_task_events event where event.task_id=task.id
    ) from public.stable_tasks task where id='#{task_id}';
  SQL
).strip
unless state.match?(/\A(completed|cancelled)\|2\|2\z/)
  raise "Task history/version terminal shape invalid: #{state}"
end

puts 'C-010 Round 1 task CAS concurrency passed'
