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
profile_id = sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000'::uuid,'#{auth_id}'::uuid,
      'authenticated','authenticated','#{auth_id}@example.invalid','',now(),
      '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()
    );
    select id from public.profiles where auth_user_id='#{auth_id}';
  SQL
).lines.last.to_s.strip
raise 'C-007 concurrency profile was not provisioned' unless profile_id.match?(/\A[0-9a-f-]{36}\z/)

gate = Queue.new
ready = Queue.new
workers = 2.times.map do |index|
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
        select * from public.update_current_account_profile(
          1,'Concurrent','Writer #{index}',null,'nl','Europe/Amsterdam',
          'system','individualHorse',true,null,'#{SecureRandom.uuid}'
        );
        commit;
      SQL
    )
  end
end
2.times { ready.pop }
2.times { gate << true }
outcomes = workers.map(&:value)

successes = outcomes.count { |_stdout, _stderr, status| status.success? }
stale = outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+40001:\s+PROFILE_VERSION_STALE/)
end
unless successes == 1 && stale == 1
  raise "Expected one C-007 winner and one stale writer, got #{outcomes.inspect}"
end

state = sql!(
  psql,
  <<~SQL
    select row_version||'|'||count(*) filter(
      where event_type='profile.account_fields_updated'
    )
    from public.profiles profile
    left join public.audit_events event on event.resource_id=profile.id
    where profile.id='#{profile_id}'
    group by profile.row_version;
  SQL
).strip
raise "C-007 race state invalid: #{state}" unless state == '2|1'

puts 'C-007 personal profile concurrency passed'
