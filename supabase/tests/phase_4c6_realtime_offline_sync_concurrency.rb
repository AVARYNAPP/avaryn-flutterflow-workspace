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

  raise "Local SQL failed: #{stderr.lines.last(8).join.strip}"
end

def wait_for_barrier(psql, gate_key, tag, expected)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
  loop do
    waiting = sql!(
      psql,
      <<~SQL,
        select count(*)
        from pg_stat_activity
        where application_name like 'ffai-4c6-#{tag}-%'
          and wait_event_type = 'Lock';
      SQL
    ).lines.last.to_i
    return if waiting == expected
    raise "Only #{waiting}/#{expected} participants reached barrier" if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.01
  end
end

def race(psql, participants)
  gate_key = SecureRandom.random_number(2_000_000_000) + 1
  tag = SecureRandom.hex(8)
  gate_in, gate_out, gate_err, gate_wait = Open3.popen3(*psql)
  gate_out_reader = Thread.new { gate_out.read }
  gate_err_reader = Thread.new { gate_err.read }
  gate_in.write("select pg_advisory_lock(#{gate_key});\n")
  gate_in.flush
  acquisition_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
  loop do
    break if sql!(
      psql,
      "select pg_try_advisory_lock(#{gate_key});",
    ).strip == 'f'
    raise 'Coordinator barrier was not acquired' if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= acquisition_deadline

    sleep 0.01
  end

  threads = participants.map do |participant|
    Thread.new do
      authorization = if participant[:superuser]
                        ''
                      else
                        <<~SQL
                          set local role authenticated;
                          select set_config(
                            'request.jwt.claim.role', 'authenticated', true
                          );
                          select set_config(
                            'request.jwt.claim.sub',
                            '#{participant[:actor]}',
                            true
                          );
                        SQL
                      end
      statement = participant[:statement] ||
                  "select #{participant.fetch(:expression)};"
      sql_result(
        psql,
        <<~SQL,
          begin;
          set local application_name =
            'ffai-4c6-#{tag}-#{participant[:name]}';
          select pg_advisory_lock_shared(#{gate_key});
          select pg_advisory_unlock_shared(#{gate_key});
          #{authorization}
          select pg_sleep(#{participant[:delay]});
          #{statement}
          commit;
        SQL
      )
    end
  end

  wait_for_barrier(psql, gate_key, tag, participants.length)
  gate_in.write("select pg_advisory_unlock(#{gate_key});\n\\q\n")
  gate_in.close
  Timeout.timeout(20) { gate_wait.value }
  gate_out_reader.value
  gate_err_reader.value
  Timeout.timeout(20) { threads.map(&:value) }
ensure
  gate_in&.close unless gate_in&.closed?
  if gate_wait&.alive?
    Process.kill('TERM', gate_wait.pid)
    gate_wait.value
  end
end

def ordered_cursor_race(psql, first_statement, second_statement)
  hold_key = SecureRandom.random_number(2_000_000_000) + 1
  tag = SecureRandom.hex(8)
  hold_in, hold_out, hold_err, hold_wait = Open3.popen3(*psql)
  hold_out_reader = Thread.new { hold_out.read }
  hold_err_reader = Thread.new { hold_err.read }
  hold_in.write("select pg_advisory_lock(#{hold_key});\n")
  hold_in.flush
  acquisition_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
  loop do
    break if sql!(
      psql,
      "select pg_try_advisory_lock(#{hold_key});",
    ).strip == 'f'
    raise 'Cursor coordinator barrier was not acquired' if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= acquisition_deadline

    sleep 0.01
  end

  first_thread = Thread.new do
    sql_result(
      psql,
      <<~SQL,
        begin;
        set local application_name = 'ffai-4c6-#{tag}-cursor-first';
        #{first_statement}
        select pg_advisory_lock_shared(#{hold_key});
        select pg_advisory_unlock_shared(#{hold_key});
        commit;
      SQL
    )
  end
  # The first transaction has inserted its event and now holds the stable
  # authority row lock while waiting at the coordinator barrier.
  wait_for_barrier(psql, hold_key, tag, 1)

  second_thread = Thread.new do
    sql_result(
      psql,
      <<~SQL,
        begin;
        set local application_name = 'ffai-4c6-#{tag}-cursor-second';
        #{second_statement}
        commit;
      SQL
    )
  end
  # The second transaction must be blocked on the same authority row before
  # the first commit is released. This proves ordering without scheduler sleeps.
  wait_for_barrier(psql, hold_key, tag, 2)

  hold_in.write("select pg_advisory_unlock(#{hold_key});\n\\q\n")
  hold_in.close
  Timeout.timeout(20) { hold_wait.value }
  hold_out_reader.value
  hold_err_reader.value
  Timeout.timeout(20) { [first_thread.value, second_thread.value] }
ensure
  hold_in&.close unless hold_in&.closed?
  if hold_wait&.alive?
    Process.kill('TERM', hold_wait.pid)
    hold_wait.value
  end
end

execution_first = 0
revoke_first = 0
cursor_ordered = 0
import_serialized = 0
cutover_serialized = 0

iterations.times do |iteration|
  ids = {
    owner: SecureRandom.uuid,
    worker: SecureRandom.uuid,
    control_owner: SecureRandom.uuid,
    stable: SecureRandom.uuid,
    control_stable: SecureRandom.uuid,
    owner_member: SecureRandom.uuid,
    worker_member: SecureRandom.uuid,
    control_member: SecureRandom.uuid,
    owner_membership: SecureRandom.uuid,
    worker_membership: SecureRandom.uuid,
    control_membership: SecureRandom.uuid,
    horse: SecureRandom.uuid,
    control_horse: SecureRandom.uuid,
    item: SecureRandom.uuid,
    assignment: SecureRandom.uuid,
    device: SecureRandom.uuid,
    execution_request: SecureRandom.uuid,
    suspend_request: SecureRandom.uuid,
    import_job: SecureRandom.uuid,
    import_create_request: SecureRandom.uuid,
    import_validate_request: SecureRandom.uuid,
    import_suspend_request: SecureRandom.uuid,
    cutover_job: SecureRandom.uuid,
    cutover_item: SecureRandom.uuid,
    cutover_horse: SecureRandom.uuid,
    cutover_create_request: SecureRandom.uuid,
    cutover_request: SecureRandom.uuid,
  }

  authority_version = sql!(
    psql,
    <<~SQL,
      begin;
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
      ) values
        ('00000000-0000-0000-0000-000000000000', '#{ids[:owner]}', 'authenticated', 'authenticated', '#{ids[:owner]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:worker]}', 'authenticated', 'authenticated', '#{ids[:worker]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:control_owner]}', 'authenticated', 'authenticated', '#{ids[:control_owner]}@example.invalid', '', now(), '{}', '{}', now(), now());
      insert into public.stables (
        id, kind, name, status, timezone, locale,
        created_by_user_id, creation_request_id
      ) values
        ('#{ids[:stable]}', 'organization', '4C.6 race stable', 'active', 'UTC', 'nl', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:control_stable]}', 'organization', '4C.6 control stable', 'active', 'UTC', 'nl', '#{ids[:control_owner]}', '#{SecureRandom.uuid}');
      insert into public.stable_members (
        id, stable_id, display_name, source
      ) values
        ('#{ids[:owner_member]}', '#{ids[:stable]}', 'Race owner', 'owner_creation'),
        ('#{ids[:worker_member]}', '#{ids[:stable]}', 'Race worker', 'manual'),
        ('#{ids[:control_member]}', '#{ids[:control_stable]}', 'Control owner', 'owner_creation');
      insert into public.stable_memberships (
        id, stable_id, user_id, stable_member_id, role, status, joined_at
      ) values
        ('#{ids[:owner_membership]}', '#{ids[:stable]}', '#{ids[:owner]}', '#{ids[:owner_member]}', 'owner', 'active', now()),
        ('#{ids[:worker_membership]}', '#{ids[:stable]}', '#{ids[:worker]}', '#{ids[:worker_member]}', 'viewer', 'active', now()),
        ('#{ids[:control_membership]}', '#{ids[:control_stable]}', '#{ids[:control_owner]}', '#{ids[:control_member]}', 'owner', 'active', now());
      insert into public.horses (
        id, stable_id, display_name, source_kind,
        created_by_user_id, created_request_id
      ) values
        ('#{ids[:horse]}', '#{ids[:stable]}', '4C.6 race Horse', 'manual', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:control_horse]}', '#{ids[:control_stable]}', '4C.6 control Horse', 'manual', '#{ids[:control_owner]}', '#{SecureRandom.uuid}');
      insert into public.schedule_items (
        id, stable_id, horse_id, item_kind, data_category,
        title, instruction, priority, scheduled_start_at,
        source_timezone, source_local_date, source_local_time, state,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:item]}', '#{ids[:stable]}', '#{ids[:horse]}',
        'task', 'horse.schedule', 'Offline revoke race',
        'Exactly one serialized outcome.', 'normal',
        '2026-07-28 08:00:00+00', 'UTC', '2026-07-28', '08:00',
        'planned', '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.schedule_assignments (
        id, stable_id, schedule_item_id, stable_member_id,
        assignment_role, status, created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:assignment]}', '#{ids[:stable]}', '#{ids[:item]}',
        '#{ids[:worker_member]}', 'responsible', 'assigned',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.client_sync_devices (
        id, stable_id, actor_user_id, encryption_public_key,
        encryption_key_fingerprint, registered_authority_version
      )
      select
        '#{ids[:device]}', '#{ids[:stable]}', '#{ids[:worker]}',
        '-----BEGIN PGP PUBLIC KEY BLOCK-----'
          || repeat('x', 200)
          || '-----END PGP PUBLIC KEY BLOCK-----',
        extensions.digest(
          convert_to('#{ids[:device]}', 'UTF8'), 'sha256'
        ),
        authority_version
      from public.stable_sync_authorities
      where stable_id = '#{ids[:stable]}';
      commit;
      select authority_version
      from public.stable_sync_authorities
      where stable_id = '#{ids[:stable]}';
    SQL
  ).lines.last.to_i

  participants = [
    {
      name: 'sync',
      actor: ids[:worker],
      delay: iteration.even? ? 0.0 : 0.05,
      expression: <<~SQL.strip,
        public.sync_schedule_execution(
          '#{ids[:stable]}',
          '#{ids[:device]}',
          #{authority_version},
          '#{ids[:item]}',
          '#{ids[:execution_request]}',
          'completed',
          '2026-07-28 08:00:00+00',
          '2026-07-28 08:05:00+00',
          '2026-07-28 08:05:00',
          'UTC',
          null
        )
      SQL
    },
    {
      name: 'suspend',
      actor: ids[:owner],
      delay: iteration.even? ? 0.05 : 0.0,
      expression: <<~SQL.strip,
        public.suspend_stable_membership(
          '#{ids[:worker_membership]}',
          '#{ids[:suspend_request]}'
        )
      SQL
    },
  ]
  sync_result, suspend_result = race(psql, participants)

  unless suspend_result[2]
    raise "Suspend participant failed: #{suspend_result[1]}"
  end
  unless sync_result[2] ||
      sync_result[1].include?('SYNC_RESET_REQUIRED') ||
      sync_result[1].include?('SYNC_UNAVAILABLE') ||
      sync_result[1].include?('NOT_AUTHORIZED') ||
      sync_result[1].include?('SCHEDULE_UNAVAILABLE')
    raise "Unexpected sync participant failure: #{sync_result[1]}"
  end

  signature = sql!(
    psql,
    <<~SQL,
      select concat_ws(
        '|',
        (
          select status
          from public.stable_memberships
          where id = '#{ids[:worker_membership]}'
        ),
        (
          select status
          from public.client_sync_devices
          where id = '#{ids[:device]}'
        ),
        (
          select count(*)
          from public.schedule_executions
          where request_id = '#{ids[:execution_request]}'
        ),
        (
          select count(*)
          from public.schedule_change_events
          where request_id = '#{ids[:execution_request]}'
            and event_type = 'schedule_execution_recorded'
        ),
        (
          select authority_version > #{authority_version}
          from public.stable_sync_authorities
          where stable_id = '#{ids[:stable]}'
        ),
        (
          select status || ':' || display_name
          from public.horses
          where id = '#{ids[:control_horse]}'
        )
      );
    SQL
  ).lines.last
  membership_status, device_status, executions, events, version_bumped,
    control_signature = signature.split('|')

  raise "Membership did not suspend: #{signature}" unless
    membership_status == 'suspended'
  raise "Device did not revoke: #{signature}" unless device_status == 'revoked'
  raise "Authority did not rotate: #{signature}" unless version_bumped == 't'
  raise "Control tenant changed: #{signature}" unless
    control_signature == 'active:4C.6 control Horse'
  raise "Execution/event mismatch: #{signature}" unless executions == events
  raise "More than one execution committed: #{signature}" unless
    %w[0 1].include?(executions)

  if executions == '1'
    execution_first += 1
    raise 'Sync reported failure although its serialized write committed' unless
      sync_result[2]
  else
    revoke_first += 1
    raise 'Sync reported success after revoke won' if sync_result[2]
  end

  sql!(
    psql,
    <<~SQL,
      begin;
      update public.stable_memberships
      set
        role = 'admin',
        status = 'active',
        ended_at = null,
        ended_reason = null
      where id = '#{ids[:worker_membership]}';
      insert into public.legacy_import_jobs (
        id, actor_user_id, stable_id, local_stable_fingerprint,
        app_version, schema_version, horse_seed_version,
        source_record_count, source_inventory, source_manifest_hash,
        request_id
      )
      values (
        '#{ids[:import_job]}', '#{ids[:worker]}', '#{ids[:stable]}',
        extensions.digest(convert_to('local-stable', 'UTF8'), 'sha256'),
        '4.0.0', 2, 1, 0,
        '{"horses":0,"stable_members":0,"schedule_items":0,"feeding_plans":0,"schedule_executions":0}'::jsonb,
        extensions.digest(convert_to('empty-manifest', 'UTF8'), 'sha256'),
        '#{ids[:import_create_request]}'
      );
      commit;
    SQL
  )
  import_participants = [
    {
      name: 'import',
      actor: ids[:worker],
      delay: iteration.even? ? 0.0 : 0.05,
      expression: <<~SQL.strip,
        public.validate_legacy_import_job(
          '#{ids[:import_job]}',
          1,
          '#{ids[:import_validate_request]}'
        )
      SQL
    },
    {
      name: 'import-suspend',
      actor: ids[:owner],
      delay: iteration.even? ? 0.05 : 0.0,
      expression: <<~SQL.strip,
        public.suspend_stable_membership(
          '#{ids[:worker_membership]}',
          '#{ids[:import_suspend_request]}'
        )
      SQL
    },
  ]
  import_result, import_suspend_result = race(psql, import_participants)
  unless import_suspend_result[2]
    raise "Import suspend participant failed: #{import_suspend_result[1]}"
  end
  unless import_result[2] ||
      import_result[1].include?('SYNC_UNAVAILABLE') ||
      import_result[1].include?('IMPORT_UNAVAILABLE')
    raise "Unexpected import participant failure: #{import_result[1]}"
  end
  import_signature = sql!(
    psql,
    <<~SQL,
      select concat_ws(
        '|',
        (
          select status from public.stable_memberships
          where id = '#{ids[:worker_membership]}'
        ),
        (
          select status from public.legacy_import_jobs
          where id = '#{ids[:import_job]}'
        ),
        (
          select count(*) from private.client_mutation_receipts
          where actor_user_id = '#{ids[:worker]}'
            and request_id = '#{ids[:import_validate_request]}'
        ),
        (
          select count(*) from public.stable_change_events
          where stable_id = '#{ids[:stable]}'
            and entity_id = '#{ids[:import_job]}'
            and change_kind = 'legacy_import_validated'
        )
      );
    SQL
  ).lines.last
  import_membership, import_status, import_receipts, import_events =
    import_signature.split('|')
  raise "Import membership did not suspend: #{import_signature}" unless
    import_membership == 'suspended'
  raise "Import receipt/event mismatch: #{import_signature}" unless
    import_receipts == import_events
  if import_status == 'validated'
    raise 'Import reported failure although its serialized write committed' unless
      import_result[2]
  elsif import_status == 'draft'
    raise 'Import reported success after revocation won' if import_result[2]
  else
    raise "Unexpected import status: #{import_signature}"
  end
  import_serialized += 1

  legacy_horse_id = 900_000 + iteration
  sql!(
    psql,
    <<~SQL,
      begin;
      update public.stable_memberships
      set
        role = 'admin',
        status = 'active',
        ended_at = null,
        ended_reason = null
      where id = '#{ids[:worker_membership]}';
      insert into public.horses (
        id, stable_id, display_name, legacy_local_horse_id, source_kind,
        created_by_user_id, created_request_id
      )
      values (
        '#{ids[:cutover_horse]}', '#{ids[:stable]}',
        'Cutover mapped horse', #{legacy_horse_id}, 'legacy_import',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.legacy_import_jobs (
        id, actor_user_id, stable_id, local_stable_fingerprint,
        app_version, schema_version, horse_seed_version, status,
        source_record_count, source_inventory, selected_record_count,
        imported_record_count, source_manifest_hash,
        mapping_manifest_hash, request_id, row_version, verified_at
      )
      values (
        '#{ids[:cutover_job]}', '#{ids[:worker]}', '#{ids[:stable]}',
        extensions.digest(convert_to('cutover-stable', 'UTF8'), 'sha256'),
        '4.0.0', 2, 1, 'verified', 1,
        '{"horses":1,"stable_members":0,"schedule_items":0,"feeding_plans":0,"schedule_executions":0}'::jsonb,
        1, 1,
        extensions.digest(convert_to('cutover-manifest', 'UTF8'), 'sha256'),
        private.sync_payload_hash(
          jsonb_build_array(
            jsonb_build_object(
              'entity_type', 'horse',
              'legacy_local_id', '#{legacy_horse_id}',
              'cloud_id', '#{ids[:cutover_horse]}'::uuid,
              'source_hash', encode(
                private.sync_payload_hash(
                  jsonb_build_object(
                    'display_name', 'Cutover mapped horse',
                    'sex', 'unknown'
                  )
                ),
                'hex'
              ),
              'cloud_hash', encode(
                private.sync_payload_hash(
                  jsonb_build_object(
                    'display_name', 'Cutover mapped horse',
                    'sex', 'unknown'
                  )
                ),
                'hex'
              )
            )
          )
        ),
        '#{ids[:cutover_create_request]}', 2, now()
      );
      insert into public.legacy_import_items (
        id, stable_id, job_id, entity_type, legacy_local_id, cloud_id,
        status, source_classification, selected_explicitly,
        source_hash, cloud_hash
      )
      values (
        '#{ids[:cutover_item]}', '#{ids[:stable]}',
        '#{ids[:cutover_job]}', 'horse', '#{legacy_horse_id}',
        '#{ids[:cutover_horse]}', 'imported', 'user', false,
        private.sync_payload_hash(
          jsonb_build_object(
            'display_name', 'Cutover mapped horse',
            'sex', 'unknown'
          )
        ),
        private.sync_payload_hash(
          jsonb_build_object(
            'display_name', 'Cutover mapped horse',
            'sex', 'unknown'
          )
        )
      );
      insert into private.legacy_import_payloads (item_id, payload)
      values (
        '#{ids[:cutover_item]}',
        jsonb_build_object(
          'display_name', 'Cutover mapped horse',
          'sex', 'unknown'
        )
      );
      commit;
    SQL
  )
  cutover_participants = [
    {
      name: 'cutover',
      actor: ids[:worker],
      delay: iteration.even? ? 0.0 : 0.05,
      expression: <<~SQL.strip,
        public.cutover_legacy_import_job(
          '#{ids[:cutover_job]}',
          2,
          extensions.digest(
            convert_to('cutover-stable', 'UTF8'),
            'sha256'
          ),
          true,
          '#{ids[:cutover_request]}'
        )
      SQL
    },
    {
      name: 'cutover-target-update',
      superuser: true,
      delay: iteration.even? ? 0.05 : 0.0,
      statement: <<~SQL.strip,
        update public.horses
        set display_name = 'Changed during cutover'
        where id = '#{ids[:cutover_horse]}';
      SQL
    },
  ]
  cutover_result, target_update_result = race(psql, cutover_participants)
  raise "Cutover target update failed: #{target_update_result[1]}" unless
    target_update_result[2]
  unless cutover_result[2] ||
      cutover_result[1].include?('CUTOVER_NOT_READY')
    raise "Unexpected cutover participant failure: #{cutover_result[1]}"
  end
  cutover_status = sql!(
    psql,
    <<~SQL,
      select status
      from public.legacy_import_jobs
      where id = '#{ids[:cutover_job]}';
    SQL
  ).lines.last
  if cutover_status == 'cutover'
    raise 'Cutover reported failure although it serialized first' unless
      cutover_result[2]
  elsif cutover_status == 'verified'
    raise 'Cutover succeeded after target mutation serialized first' if
      cutover_result[2]
  else
    raise "Unexpected cutover race status: #{cutover_status}"
  end
  cutover_serialized += 1

  first_source_event = SecureRandom.random_number(1_000_000_000) +
                       3_000_000_000
  second_source_event = first_source_event + 1
  first_cursor_result, second_cursor_result = ordered_cursor_race(
    psql,
    <<~SQL.strip,
      insert into public.stable_change_events (
        stable_id, horse_id, entity_type, entity_id, change_kind,
        data_category, row_version, source_stream, source_event_id
      )
      values (
        '#{ids[:stable]}', '#{ids[:horse]}', 'horse',
        '#{ids[:horse]}', 'cursor_first', 'horse.basic', 1,
        'legacy_import', #{first_source_event}
      );
    SQL
    <<~SQL.strip,
      insert into public.stable_change_events (
        stable_id, horse_id, entity_type, entity_id, change_kind,
        data_category, row_version, source_stream, source_event_id
      )
      values (
        '#{ids[:stable]}', '#{ids[:horse]}', 'horse',
        '#{ids[:horse]}', 'cursor_second', 'horse.basic', 1,
        'legacy_import', #{second_source_event}
      );
    SQL
  )
  raise "First cursor participant failed: #{first_cursor_result[1]}" unless
    first_cursor_result[2]
  raise "Second cursor participant failed: #{second_cursor_result[1]}" unless
    second_cursor_result[2]
  cursor_signature = sql!(
    psql,
    <<~SQL,
      select string_agg(
        source_event_id::text || ':' || sequence_id::text,
        ','
        order by sequence_id
      )
      from public.stable_change_events
      where stable_id = '#{ids[:stable]}'
        and source_stream = 'legacy_import'
        and source_event_id in (
          #{first_source_event},
          #{second_source_event}
        );
    SQL
  ).lines.last
  ordered_source_events = cursor_signature.split(',').map do |entry|
    entry.split(':').first.to_i
  end
  unless ordered_source_events == [first_source_event, second_source_event]
    raise "Cursor commit order inverted: #{cursor_signature}"
  end
  cursor_ordered += 1
end

puts(
  "PASS: #{iterations}/#{iterations} offline-sync/suspend races serialized; " \
  "#{import_serialized}/#{iterations} import/suspend races serialized; " \
  "#{cutover_serialized}/#{iterations} cutover/target races serialized; " \
  "#{cursor_ordered}/#{iterations} cursor commit-order races serialized; " \
  "execution-first=#{execution_first}, revoke-first=#{revoke_first}; " \
  'every device revoked, authority rotated, audit matched and control tenant stayed unchanged',
)
