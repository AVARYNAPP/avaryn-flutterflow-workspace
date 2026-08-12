require 'json'
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
        'C-009.1 concurrency',null,null,'unknown',null,null,null,null,null,
        null,null,null,'#{SecureRandom.uuid}'
      );
    INNER
  SQL
).lines.map(&:strip).select { |line| line.match?(/\A[0-9a-f-]{36}\z/) }.last
raise 'C-009.1 concurrency horse was not created' unless horse_id

# Two physical sessions use the exact same durable create request. The advisory
# request lock and receipt must make both calls succeed with one asset identity.
create_request = SecureRandom.uuid
create_statement = authenticated_sql(
  auth_id,
  <<~SQL
    select public.create_canonical_media_upload_session(
      '#{horse_id}','race.jpg','image/jpeg','#{create_request}'
    );
  SQL
)
create_outcomes = race(psql, [create_statement, create_statement])
unless create_outcomes.all? { |_stdout, _stderr, status| status.success? }
  raise "Concurrent create failed: #{create_outcomes.inspect}"
end
created_ids = create_outcomes.map do |stdout, _stderr, _status|
  JSON.parse(stdout.lines.map(&:strip).find { |line| line.start_with?('{') })
    .fetch('media_asset_id')
end
unless created_ids.uniq.length == 1
  raise "Concurrent create diverged: #{created_ids.inspect}"
end
create_state = sql!(
  psql,
  <<~SQL
    select count(*) || '|' || count(distinct id)
    from public.media_assets
    where uploaded_by_user_id='#{auth_id}' and created_request_id='#{create_request}';
  SQL
).strip
raise "Expected one create request converged, got #{create_state}" unless create_state == '1|1'

# Prepare two server-verified image assets and links. Both clients race from the
# same horse row version; the row lock plus CAS must yield one winner/one stale.
asset_ids = [SecureRandom.uuid, SecureRandom.uuid]
link_ids = [SecureRandom.uuid, SecureRandom.uuid]
requests = [SecureRandom.uuid, SecureRandom.uuid]
sql!(
  psql,
  <<~SQL
    insert into public.media_assets(
      id,stable_id,horse_id,status,original_filename,expected_mime_type,
      max_byte_size,mime_type,byte_size,sha256,uploaded_by_user_id,
      created_request_id,last_mutated_by_user_id,last_mutation_request_id,ready_at
    ) values
      ('#{asset_ids[0]}',null,'#{horse_id}','ready','race-a.jpg','image/jpeg',
       10485760,'image/jpeg',128,decode(repeat('00',32),'hex'),'#{auth_id}',
       '#{requests[0]}','#{auth_id}','#{requests[0]}',now()),
      ('#{asset_ids[1]}',null,'#{horse_id}','ready','race-b.jpg','image/jpeg',
       10485760,'image/jpeg',128,decode(repeat('11',32),'hex'),'#{auth_id}',
       '#{requests[1]}','#{auth_id}','#{requests[1]}',now());
    insert into public.media_links(
      id,stable_id,media_asset_id,horse_id,link_kind,created_by_user_id,
      created_request_id
    ) values
      ('#{link_ids[0]}',null,'#{asset_ids[0]}','#{horse_id}','horse','#{auth_id}','#{requests[0]}'),
      ('#{link_ids[1]}',null,'#{asset_ids[1]}','#{horse_id}','horse','#{auth_id}','#{requests[1]}');
  SQL
)

profile_statements = asset_ids.map do |asset_id|
  authenticated_sql(
    auth_id,
    <<~SQL
      select public.set_canonical_horse_profile_media(
        '#{horse_id}','#{asset_id}',1,'#{SecureRandom.uuid}'
      );
    SQL
  )
end
profile_outcomes = race(psql, profile_statements)
successes = profile_outcomes.count { |_stdout, _stderr, status| status.success? }
stale = profile_outcomes.count do |_stdout, stderr, status|
  !status.success? && stderr.match?(/ERROR:\s+40001:\s+STALE_HORSE_VERSION/)
end
unless successes == 1 && stale == 1
  raise "Expected one profile media writer won and one stale, got #{profile_outcomes.inspect}"
end

profile_state = sql!(
  psql,
  <<~SQL
    select horse.row_version || '|' || count(*) filter (
      where event.event_type='horse.updated'
        and event.metadata->>'operation_code'='set_canonical_horse_profile_media'
    ) || '|' || (horse.profile_media_asset_id in ('#{asset_ids[0]}','#{asset_ids[1]}'))
    from public.canonical_horses horse
    left join public.audit_events event on event.resource_id=horse.id
    where horse.id='#{horse_id}'
    group by horse.row_version, horse.profile_media_asset_id;
  SQL
).strip
raise "C-009.1 profile race state invalid: #{profile_state}" unless profile_state == '2|1|true'

puts 'C-009.1 canonical media concurrency passed'
