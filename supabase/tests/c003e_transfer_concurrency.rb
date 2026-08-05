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

def race_accept(psql, function_name, token, recipient_auth)
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
          select set_config('request.jwt.claim.sub','#{recipient_auth}',true);
          select * from public.#{function_name}('#{token}','accept','#{SecureRandom.uuid}');
          commit;
        SQL
      )
    end
  end
  2.times { ready.pop }
  2.times { gate << true }
  outcomes = workers.map(&:value)
  successes = outcomes.count { |_stdout, _stderr, status| status.success? }
  unavailable = outcomes.count do |_stdout, stderr, status|
    !status.success? && stderr.match?(/ERROR:\s+42501:\s+TRANSFER_NOT_AVAILABLE/)
  end
  return if successes == 1 && unavailable == 1

  raise "Expected one transfer winner and one terminal replay rejection, got #{outcomes.inspect}"
end

horse_sender_auth = SecureRandom.uuid
organization_sender_auth = SecureRandom.uuid
horse_recipient_auth = SecureRandom.uuid
organization_recipient_auth = SecureRandom.uuid

fixture = sql!(
  psql,
  <<~SQL
    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at
    ) values
      ('00000000-0000-0000-0000-000000000000','#{horse_sender_auth}',
       'authenticated','authenticated','#{horse_sender_auth}@example.invalid','',now(),'{}','{}',now(),now()),
      ('00000000-0000-0000-0000-000000000000','#{organization_sender_auth}',
       'authenticated','authenticated','#{organization_sender_auth}@example.invalid','',now(),'{}','{}',now(),now()),
      ('00000000-0000-0000-0000-000000000000','#{horse_recipient_auth}',
       'authenticated','authenticated','#{horse_recipient_auth}@example.invalid','',now(),'{}','{}',now(),now()),
      ('00000000-0000-0000-0000-000000000000','#{organization_recipient_auth}',
       'authenticated','authenticated','#{organization_recipient_auth}@example.invalid','',now(),'{}','{}',now(),now());
    create temporary table race_profiles as
      select auth_user_id,id from public.profiles
      where auth_user_id in('#{horse_recipient_auth}','#{organization_recipient_auth}');
    grant select on pg_temp.race_profiles to authenticated;
    begin;
    set local role authenticated;
    select set_config('request.jwt.claim.role','authenticated',true);
    select set_config('request.jwt.claim.sub','#{horse_sender_auth}',true);
    create temporary table race_horse as
      select horse_id from public.create_canonical_horse(
        'Transfer race horse',null,'unknown',null,'#{SecureRandom.uuid}','{}'
      );
    create temporary table race_horse_transfer as
      select horse.horse_id,transfer.transfer_id,transfer.transfer_token
      from race_horse horse cross join lateral public.initiate_horse_authority_transfer(
        horse.horse_id,
        (select id from pg_temp.race_profiles where auth_user_id='#{horse_recipient_auth}'),
        '#{SecureRandom.uuid}'
      ) transfer;
    select set_config('request.jwt.claim.sub','#{organization_sender_auth}',true);
    create temporary table race_organization as
      select organization_id from public.create_organization(
        'stable','Transfer race organization',null,'#{SecureRandom.uuid}','{}'
      );
    create temporary table race_organization_transfer as
      select organization.organization_id,transfer.transfer_id,transfer.transfer_token
      from race_organization organization cross join lateral public.initiate_organization_authority_transfer(
        organization.organization_id,
        (select id from pg_temp.race_profiles where auth_user_id='#{organization_recipient_auth}'),
        '#{SecureRandom.uuid}'
      ) transfer;
    select horse.horse_id||'|'||horse.transfer_id||'|'||horse.transfer_token||'|'||
      organization.organization_id||'|'||organization.transfer_id||'|'||organization.transfer_token
    from race_horse_transfer horse cross join race_organization_transfer organization;
    commit;
  SQL
).lines.last.to_s.strip

horse_id, horse_transfer_id, horse_token, organization_id, organization_transfer_id,
  organization_token = fixture.split('|', 6)
unless [horse_id, horse_transfer_id, organization_id, organization_transfer_id].all? do |value|
         value&.match?(/\A[0-9a-f-]{36}\z/)
       end && [horse_token, organization_token].all? { |value| value&.match?(/\A[0-9a-f]{64}\z/) }
  raise "Concurrency fixture invalid: #{fixture}"
end

race_accept(psql, 'respond_horse_authority_transfer', horse_token, horse_recipient_auth)
horse_state = sql!(
  psql,
  <<~SQL
    select transfer.status||'|'||(horse.primary_authority_profile_id=(
      select id from public.profiles where auth_user_id='#{horse_recipient_auth}'
    ))::text||'|'||horse.authority_version||'|'||horse.access_version
    from public.horse_authority_transfers transfer
    join public.canonical_horses horse on horse.id=transfer.horse_id
    where transfer.id='#{horse_transfer_id}' and horse.id='#{horse_id}';
  SQL
).strip
raise "Horse transfer race state invalid: #{horse_state}" unless horse_state == 'accepted|true|2|2'

race_accept(
  psql, 'respond_organization_authority_transfer', organization_token,
  organization_recipient_auth
)
organization_state = sql!(
  psql,
  <<~SQL
    select transfer.status||'|'||(organization.primary_admin_profile_id=(
      select id from public.profiles where auth_user_id='#{organization_recipient_auth}'
    ))::text||'|'||organization.access_version||'|'||count(assignment.id)
    from public.organization_authority_transfers transfer
    join public.organizations organization on organization.id=transfer.organization_id
    left join public.organization_memberships membership
      on membership.organization_id=organization.id
      and membership.profile_id=organization.primary_admin_profile_id
      and membership.status='active'
    left join public.organization_membership_roles assignment
      on assignment.membership_id=membership.id and assignment.status='active'
      and assignment.role_id=(select id from public.organization_roles
        where organization_id=organization.id and code='head_admin')
    where transfer.id='#{organization_transfer_id}' and organization.id='#{organization_id}'
    group by transfer.status,organization.primary_admin_profile_id,organization.access_version;
  SQL
).strip
unless organization_state == 'accepted|true|2|1'
  raise "Organization transfer race state invalid: #{organization_state}"
end

puts 'C-003E horse and organization transfer concurrency passed'
