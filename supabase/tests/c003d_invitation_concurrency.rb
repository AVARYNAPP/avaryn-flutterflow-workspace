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

owner_auth = SecureRandom.uuid
target_auth = SecureRandom.uuid
horse_correlation = SecureRandom.uuid
invitation_correlation = SecureRandom.uuid

fixture = sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values
      ('00000000-0000-0000-0000-000000000000','#{owner_auth}',
       'authenticated','authenticated','#{owner_auth}@example.invalid','',now(),'{}','{}',now(),now()),
      ('00000000-0000-0000-0000-000000000000','#{target_auth}',
       'authenticated','authenticated','#{target_auth}@example.invalid','',now(),'{}','{}',now(),now());
    begin;
    set local role authenticated;
    select set_config('request.jwt.claim.role','authenticated',true);
    select set_config('request.jwt.claim.sub','#{owner_auth}',true);
    with horse as (
      select horse_id from public.create_canonical_horse(
        'Invitation race horse',null,'unknown',null,'#{horse_correlation}','{}'
      )
    ), invitation as (
      select created.invitation_id,created.invitation_token,horse.horse_id
      from horse cross join lateral public.create_horse_access_invitation(
        horse.horse_id,'#{target_auth}@example.invalid',array['horse.view'],
        null,null,now()+interval '1 day','#{invitation_correlation}'
      ) created
    )
    select horse_id||'|'||invitation_id||'|'||invitation_token from invitation;
    commit;
  SQL
).lines.last.to_s.strip

horse_id, invitation_id, invitation_token = fixture.split('|', 3)
unless horse_id&.match?(/\A[0-9a-f-]{36}\z/) &&
       invitation_id&.match?(/\A[0-9a-f-]{36}\z/) &&
       invitation_token&.match?(/\A[0-9a-f]{64}\z/)
  raise "Concurrency fixture invalid: #{fixture}"
end

gate = Queue.new
ready = Queue.new
workers = 2.times.map do
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
        select set_config('request.jwt.claim.sub','#{target_auth}',true);
        select * from public.respond_horse_access_invitation(
          '#{invitation_token}','accept','#{SecureRandom.uuid}'
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
consumed = outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+42501:\s+INVITATION_NOT_AVAILABLE/)
end
unless successes == 1 && consumed == 1
  raise "Expected one acceptance and one consumed-token failure, got #{outcomes.inspect}"
end

state = sql!(
  psql,
  <<~SQL
    select invitation.status||'|'||count(grant_row.id)
    from public.horse_access_invitations invitation
    left join public.horse_profile_permission_grants grant_row
      on grant_row.horse_id=invitation.horse_id
      and grant_row.grantee_profile_id=(select id from public.profiles where auth_user_id='#{target_auth}')
      and grant_row.status='active'
    where invitation.id='#{invitation_id}'
    group by invitation.status;
  SQL
).strip
raise "Expected one accepted invitation and one active grant, got #{state}" unless state == 'accepted|1'

puts 'C-003D invitation concurrency passed'
