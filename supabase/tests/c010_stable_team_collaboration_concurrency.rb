require 'json'
require 'open3'
require 'securerandom'
require 'thread'

container = ARGV.shift || 'supabase_db_avaryn-c0091-fresh-stack'
database = ARGV.shift || 'avaryn_c010_fresh'
psql = [
  'docker', 'exec', '-i', '-e', 'PGPASSWORD=postgres', container,
  'psql', '-X', '-A', '-t', '-q', '-U', 'supabase_admin', '-d', database,
  '-v', 'ON_ERROR_STOP=1'
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

auth_id = SecureRandom.uuid
stable_id, horse_id = sql!(
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
    #{authenticated_sql(auth_id, <<~INNER)}
      with stable as(
        select public.create_c010_stable(
          'C-010 concurrency stable','Local','#{SecureRandom.uuid}'
        ) result
      ), horse as(
        select * from public.create_canonical_horse_profile(
          'C-010 concurrency horse',null,null,'unknown',null,null,null,null,
          null,null,null,null,'#{SecureRandom.uuid}'
        )
      )
      select (stable.result->>'organization_id')||'|'||horse.horse_id
      from stable,horse;
    INNER
  SQL
).lines.map(&:strip).find { |line| line.count('|') == 1 }.split('|', 2)

membership_id = sql!(
  psql,
  <<~SQL
    select membership.id from public.organization_memberships membership
    join public.profiles profile on profile.id=membership.profile_id
    where membership.organization_id='#{stable_id}' and profile.auth_user_id='#{auth_id}';
  SQL
).strip

unless [stable_id, horse_id, membership_id].all? { |value| value&.match?(/\A[0-9a-f-]{36}\z/) }
  raise 'C-010 concurrency fixture invalid'
end

residency_requests = 2.times.map do
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.set_c010_horse_residency(
        '#{horse_id}','#{stable_id}',null,'#{SecureRandom.uuid}'
      );
    SQL
  )
end
residency_outcomes = race(psql, residency_requests)
residency_successes = residency_outcomes.count do |_stdout, _stderr, status|
  status.success?
end
residency_stale = residency_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/STALE_RESIDENCY_VERSION/)
end
unless residency_successes == 1 && residency_stale == 1
  raise "Concurrent residency requests did not serialize: #{residency_outcomes.inspect}"
end
residency_count = sql!(
  psql,
  "select count(*) from public.horse_residencies where horse_id='#{horse_id}' and status='active';"
).strip
raise "Expected one active residency, got #{residency_count}" unless residency_count == '1'

# Both writers start from the same membership CAS version. Even when the
# manager tries to change its own reserved authority membership, both calls
# must fail closed and never create a second authority or team role.
role_updates = %w[rider trainer].map do |role|
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.set_c010_team_role(
        '#{stable_id}','#{membership_id}',1,'#{role}','#{SecureRandom.uuid}'
      );
    SQL
  )
end
role_outcomes = race(psql, role_updates)
denied = role_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/PRIMARY_ADMIN_ROLE_IMMUTABLE/)
end
raise "Primary manager race was not fail-closed: #{role_outcomes.inspect}" unless denied == 2

puts 'C-010 residency and primary-manager concurrency passed'
