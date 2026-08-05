require 'open3'
require 'securerandom'
require 'thread'

container = ARGV.shift || 'supabase_db_avaryn-flutterflow-workspace'
psql = [
  'docker', 'exec', '-i', container, 'psql', '-X', '-A', '-t', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'
].freeze

def sql!(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  raise "Local SQL failed: #{stderr.lines.last.to_s.strip}" unless status.success?
  stdout
end

auth_id = SecureRandom.uuid
correlation_id = SecureRandom.uuid
horse_id = sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000','#{auth_id}',
      'authenticated','authenticated','#{auth_id}@example.invalid','',now(),
      '{}','{}',now(),now()
    );
    begin;
    set local role authenticated;
    select set_config('request.jwt.claim.role','authenticated',true);
    select set_config('request.jwt.claim.sub','#{auth_id}',true);
    select horse_id from public.create_canonical_horse(
      'Concurrency horse',null,'unknown',null,'#{correlation_id}','{}'
    );
    commit;
  SQL
).lines.last.to_s.strip
raise 'Concurrency fixture did not create a horse' unless horse_id.match?(/\A[0-9a-f-]{36}\z/)

gate = Queue.new
ready = Queue.new
results = 2.times.map do |index|
  Thread.new do
    ready << true
    gate.pop
    Open3.capture3(
      *psql,
      stdin_data: <<~SQL
        \\set VERBOSITY verbose
        begin;
        set local role authenticated;
        select set_config('request.jwt.claim.role','authenticated',true);
        select set_config('request.jwt.claim.sub','#{auth_id}',true);
        select * from public.update_canonical_horse(
          '#{horse_id}',1,'Concurrent #{index}',null,'unknown',null,'active','#{SecureRandom.uuid}'
        );
        commit;
      SQL
    )
  end
end
2.times { ready.pop }
2.times { gate << true }
outcomes = results.map(&:value)

successes = outcomes.count { |_stdout, _stderr, status| status.success? }
stale = outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+40001:\s+STALE_HORSE_VERSION/)
end
raise "Expected one winner and one stale writer, got #{outcomes.inspect}" unless successes == 1 && stale == 1

state = sql!(psql, "select row_version from public.canonical_horses where id='#{horse_id}';").strip
raise "Expected row_version 2 after race, got #{state}" unless state == '2'

puts 'C-003C canonical horse concurrency passed'
