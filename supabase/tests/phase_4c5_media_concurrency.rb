require 'open3'
require 'securerandom'
require 'timeout'

container = ARGV.fetch(0, 'supabase_db_avaryn-flutterflow-workspace')
iterations = Integer(ENV.fetch('ITERATIONS', '50'))
raise 'ITERATIONS must be positive' unless iterations.positive?

psql = [
  'docker', 'exec', '-i', container,
  'psql', '-X', '-A', '-t', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1',
].freeze

def sql_result(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  [stdout.strip, stderr.strip, status.success?]
end

def sql!(psql, source)
  stdout, stderr, success = sql_result(psql, source)
  return stdout if success

  raise "Local SQL failed: #{stderr.lines.last(6).join.strip}"
end

def fixture_sql(ids)
  <<~SQL
    begin;
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000',
      '#{ids[:owner]}', 'authenticated', 'authenticated',
      '#{ids[:owner]}@example.invalid', '', now(), '{}', '{}', now(), now()
    );
    insert into public.stables (
      id, kind, name, status, timezone, locale,
      created_by_user_id, creation_request_id
    ) values (
      '#{ids[:stable]}', 'organization', '4C.5 race stable',
      'active', 'UTC', 'nl', '#{ids[:owner]}', '#{SecureRandom.uuid}'
    );
    insert into public.stable_members (
      id, stable_id, display_name, source
    ) values (
      '#{ids[:member]}', '#{ids[:stable]}', '4C.5 race owner',
      'owner_creation'
    );
    insert into public.stable_memberships (
      id, stable_id, user_id, stable_member_id, role, status, joined_at
    ) values (
      '#{ids[:membership]}', '#{ids[:stable]}', '#{ids[:owner]}',
      '#{ids[:member]}', 'owner', 'active', now()
    );
    set constraints all immediate;
    insert into public.horses (
      id, stable_id, display_name, source_kind,
      created_by_user_id, created_request_id
    ) values (
      '#{ids[:horse]}', '#{ids[:stable]}', 'Finalize Archive Race',
      'manual', '#{ids[:owner]}', '#{SecureRandom.uuid}'
    );
    insert into public.media_assets (
      id, stable_id, horse_id, original_filename, expected_mime_type,
      max_byte_size, uploaded_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    ) values (
      '#{ids[:asset]}', '#{ids[:stable]}', '#{ids[:horse]}',
      'race.png', 'image/png', 10485760, '#{ids[:owner]}',
      '#{ids[:create_request]}', '#{ids[:owner]}',
      '#{ids[:create_request]}'
    );
    insert into public.media_asset_variants (
      stable_id, media_asset_id, variant, object_path,
      expected_mime_type, max_byte_size
    ) values
      (
        '#{ids[:stable]}', '#{ids[:asset]}', 'original',
        '#{ids[:stable]}/#{ids[:horse]}/#{ids[:asset]}/original',
        'image/png', 10485760
      ),
      (
        '#{ids[:stable]}', '#{ids[:asset]}', 'thumbnail',
        '#{ids[:stable]}/#{ids[:horse]}/#{ids[:asset]}/thumbnail',
        'image/png', 1048576
      );
    insert into public.media_links (
      stable_id, media_asset_id, horse_id, link_kind,
      created_by_user_id, created_request_id
    ) values (
      '#{ids[:stable]}', '#{ids[:asset]}', '#{ids[:horse]}', 'horse',
      '#{ids[:owner]}', '#{ids[:create_request]}'
    );
    insert into storage.objects (bucket_id, name, metadata)
    values
      (
        'horse-media',
        '#{ids[:stable]}/#{ids[:horse]}/#{ids[:asset]}/original',
        '{"mimetype":"image/png"}'
      ),
      (
        'horse-media',
        '#{ids[:stable]}/#{ids[:horse]}/#{ids[:asset]}/thumbnail',
        '{"mimetype":"image/png"}'
      );
    commit;
  SQL
end

ready_wins = 0
archive_wins = 0
idempotency_checked = false

iterations.times do |iteration|
  ids = {
    owner: SecureRandom.uuid,
    stable: SecureRandom.uuid,
    member: SecureRandom.uuid,
    membership: SecureRandom.uuid,
    horse: SecureRandom.uuid,
    asset: SecureRandom.uuid,
    create_request: SecureRandom.uuid,
    finalize_request: SecureRandom.uuid,
    archive_request: SecureRandom.uuid,
  }
  sql!(psql, fixture_sql(ids))

  if iteration.zero?
    duplicate_request = SecureRandom.uuid
    duplicate_start = Queue.new
    duplicate_calls = 2.times.map do
      Thread.new do
        duplicate_start.pop
        sql_result(
          psql,
          <<~SQL
            begin;
            set local role authenticated;
            set local "request.jwt.claim.role" = 'authenticated';
            set local "request.jwt.claim.sub" = '#{ids[:owner]}';
            select public.create_media_upload_session(
              '#{ids[:horse]}', null, 'concurrent.png', 'image/png',
              '#{duplicate_request}'
            );
            commit;
          SQL
        )
      end
    end
    2.times { duplicate_start << true }
    duplicate_results = duplicate_calls.map(&:value)
    unless duplicate_results.all? { |result| result[2] }
      raise "Concurrent exact create failed: #{duplicate_results.map { |r| r[1] }.join}"
    end
    duplicate_assets = duplicate_results.map do |result|
      result[0][/"media_asset_id"\s*:\s*"([^"]+)"/, 1]
    end
    if duplicate_assets.any?(&:nil?) || duplicate_assets.uniq.length != 1
      raise "Concurrent exact create diverged: #{duplicate_results.map(&:first)}"
    end
    duplicate_count = sql!(
      psql,
      <<~SQL
        select count(*)
        from public.media_assets
        where uploaded_by_user_id = '#{ids[:owner]}'
          and created_request_id = '#{duplicate_request}';
      SQL
    ).lines.last.to_i
    raise 'Concurrent exact create produced duplicate assets' unless duplicate_count == 1
    idempotency_checked = true
  end

  start = Queue.new
  finalize_thread = Thread.new do
    start.pop
    sql_result(
      psql,
      <<~SQL
        begin;
        set local role service_role;
        select pg_sleep(0.01);
        select public.finalize_media_asset(
          '#{ids[:owner]}', '#{ids[:asset]}', 1,
          'image/png', 128, '#{'ab' * 32}',
          'image/png', 64, '#{'cd' * 32}',
          '#{ids[:finalize_request]}'
        );
        commit;
      SQL
    )
  end
  archive_thread = Thread.new do
    start.pop
    sql_result(
      psql,
      <<~SQL
        begin;
        set local role authenticated;
        select set_config('request.jwt.claim.role', 'authenticated', true);
        select set_config('request.jwt.claim.sub', '#{ids[:owner]}', true);
        select pg_sleep(0.01);
        select public.archive_horse(
          '#{ids[:horse]}',
          '#{ids[:archive_request]}',
          '4C.5 finalize versus Horse archive race'
        );
        commit;
      SQL
    )
  end
  2.times { start << true }
  finalize = nil
  archive = nil
  Timeout.timeout(20) do
    finalize = finalize_thread.value
    archive = archive_thread.value
  end
  unless archive[2]
    raise "Horse archive race failed: #{archive[1].lines.last(4).join.strip}"
  end
  unless finalize[2] || finalize[1].include?('MEDIA_UNAVAILABLE')
    raise "Unexpected finalize race failure: #{finalize[1].lines.last(4).join.strip}"
  end

  state = sql!(
    psql,
    <<~SQL
      select concat_ws(
        '|',
        (select status from public.horses where id = '#{ids[:horse]}'),
        (select status from public.media_assets where id = '#{ids[:asset]}'),
        (select count(*) from public.authorize_media_asset_download(
          '#{ids[:owner]}', '#{ids[:asset]}', 'original'
        )),
        (
          select count(distinct status)
          from public.media_asset_variants
          where media_asset_id = '#{ids[:asset]}'
        ),
        (
          select min(status)
          from public.media_asset_variants
          where media_asset_id = '#{ids[:asset]}'
        )
      );
    SQL
  )
  horse_status, asset_status, download_count, variant_state_count, variant_status =
    state.lines.last.to_s.split('|')
  raise "Horse did not archive: #{state}" unless horse_status == 'archived'
  raise "Archived Horse still authorized media: #{state}" unless download_count == '0'
  raise "Variant states diverged: #{state}" unless variant_state_count == '1'
  case asset_status
  when 'ready'
    ready_wins += 1
    raise "Ready asset variants not ready: #{state}" unless variant_status == 'ready'
    raise 'Finalize reported failure despite ready commit' unless finalize[2]
  when 'pending'
    archive_wins += 1
    raise "Pending asset variants not pending: #{state}" unless variant_status == 'pending'
    raise 'Finalize succeeded after archive won' if finalize[2]
  else
    raise "Invalid serialized asset state: #{state}"
  end
end

raise 'No race iterations completed' unless ready_wins + archive_wins == iterations
raise 'Concurrent request idempotency was not checked' unless idempotency_checked

puts(
  "PASS: #{iterations}/#{iterations} finalize/Horse-archive races serialized; " \
  "finalize-first=#{ready_wins}, archive-first=#{archive_wins}, " \
  'all archived Horses exposed zero media; exact concurrent create converged',
)
