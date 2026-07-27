require 'open3'
require 'securerandom'
require 'timeout'

container = 'supabase_db_avaryn-flutterflow-workspace'
iterations = 1
quiet = false
arguments = ARGV.dup
until arguments.empty?
  argument = arguments.shift
  case argument
  when '--iterations'
    iterations = Integer(arguments.shift)
  when '--quiet'
    quiet = true
  else
    container = argument
  end
end

raise 'iterations must be positive' unless iterations.positive?

psql = [
  'docker', 'exec', '-i', container,
  'psql', '-X', '-A', '-t', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'
].freeze

def sql!(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  return stdout if status.success?

  raise "Local SQL failed: #{stderr.lines.last(5).join.strip}"
end

def base_ids
  {
    stable: SecureRandom.uuid,
    control_stable: SecureRandom.uuid,
    owner: SecureRandom.uuid,
    worker: SecureRandom.uuid,
    control_owner: SecureRandom.uuid,
    owner_member: SecureRandom.uuid,
    worker_member: SecureRandom.uuid,
    control_member: SecureRandom.uuid,
    owner_membership: SecureRandom.uuid,
    worker_membership: SecureRandom.uuid,
    control_membership: SecureRandom.uuid,
    horse: SecureRandom.uuid,
    control_horse: SecureRandom.uuid
  }
end

def base_fixture_sql(ids)
  <<~SQL
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
      ('#{ids[:stable]}', 'organization', '4C4 race stable', 'active', 'UTC', 'nl', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
      ('#{ids[:control_stable]}', 'organization', '4C4 control stable', 'active', 'UTC', 'nl', '#{ids[:control_owner]}', '#{SecureRandom.uuid}');
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
    set constraints all immediate;
    insert into public.horses (
      id, stable_id, display_name, source_kind,
      created_by_user_id, created_request_id
    ) values
      ('#{ids[:horse]}', '#{ids[:stable]}', 'Race Horse', 'manual', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
      ('#{ids[:control_horse]}', '#{ids[:control_stable]}', 'Control Horse', 'manual', '#{ids[:control_owner]}', '#{SecureRandom.uuid}');
  SQL
end

def standard_activation_fixture(psql)
  ids = base_ids.merge(
    plan_a: SecureRandom.uuid,
    plan_b: SecureRandom.uuid,
    version_a: SecureRandom.uuid,
    version_b: SecureRandom.uuid,
    item_a: SecureRandom.uuid,
    item_b: SecureRandom.uuid
  )
  sql!(
    psql,
    <<~SQL
      begin;
      #{base_fixture_sql(ids)}
      insert into public.feeding_plans (
        id, stable_id, horse_id, plan_type, name, status,
        effective_from, effective_until,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:plan_a]}', '#{ids[:stable]}', '#{ids[:horse]}', 'standard', 'Race plan A', 'draft', '2026-08-01', null, '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:plan_b]}', '#{ids[:stable]}', '#{ids[:horse]}', 'standard', 'Race plan B', 'draft', '2026-08-01', null, '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      insert into public.feeding_plan_versions (
        id, stable_id, feeding_plan_id, version_number, status,
        source_kind, change_reason,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:version_a]}', '#{ids[:stable]}', '#{ids[:plan_a]}', 1, 'draft', 'user', 'Race version A', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:version_b]}', '#{ids[:stable]}', '#{ids[:plan_b]}', 1, 'draft', 'user', 'Race version B', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      insert into public.feeding_plan_items (
        id, stable_id, feeding_plan_version_id, product_name,
        source_status, planned_quantity, unit_code, offering_method,
        round_code, local_time, override_key,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:item_a]}', '#{ids[:stable]}', '#{ids[:version_a]}', 'Race feed A', 'user_entered', 1, 'kg', 'bucket', 'morning', '08:00', 'race-a', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:item_b]}', '#{ids[:stable]}', '#{ids[:version_b]}', 'Race feed B', 'user_entered', 1, 'kg', 'bucket', 'morning', '08:00', 'race-b', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      update public.feeding_plan_versions
      set status = 'approved', approved_by_user_id = '#{ids[:owner]}',
          approved_at = now()
      where id in ('#{ids[:version_a]}', '#{ids[:version_b]}');
      commit;
    SQL
  )
  ids
end

def approval_activation_fixture(psql)
  ids = base_ids.merge(
    plan: SecureRandom.uuid,
    version: SecureRandom.uuid,
    item: SecureRandom.uuid
  )
  sql!(
    psql,
    <<~SQL
      begin;
      #{base_fixture_sql(ids)}
      insert into public.feeding_plans (
        id, stable_id, horse_id, plan_type, name, status,
        effective_from, effective_until,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:plan]}', '#{ids[:stable]}', '#{ids[:horse]}',
        'standard', 'Approval race plan', 'draft', '2026-08-01', null,
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.feeding_plan_versions (
        id, stable_id, feeding_plan_id, version_number, status,
        source_kind, change_reason,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:version]}', '#{ids[:stable]}', '#{ids[:plan]}', 1,
        'draft', 'user', 'Approval activation lock race',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.feeding_plan_items (
        id, stable_id, feeding_plan_version_id, product_name,
        source_status, planned_quantity, unit_code, offering_method,
        round_code, local_time, override_key,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:item]}', '#{ids[:stable]}', '#{ids[:version]}',
        'Approval race feed', 'user_entered', 1, 'kg', 'bucket',
        'morning', '08:00', 'approval-race',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      commit;
    SQL
  )
  ids
end

def temporary_execution_fixture(psql)
  ids = base_ids.merge(
    standard_plan: SecureRandom.uuid,
    standard_version: SecureRandom.uuid,
    standard_item: SecureRandom.uuid,
    temporary_plan: SecureRandom.uuid,
    temporary_version: SecureRandom.uuid,
    temporary_item: SecureRandom.uuid,
    schedule_item: SecureRandom.uuid,
    assignment: SecureRandom.uuid
  )
  sql!(
    psql,
    <<~SQL
      begin;
      #{base_fixture_sql(ids)}
      insert into public.feeding_plans (
        id, stable_id, horse_id, plan_type, name, status,
        effective_from, effective_until,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:standard_plan]}', '#{ids[:stable]}', '#{ids[:horse]}', 'standard', 'Standard race plan', 'draft', '2026-08-01', null, '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:temporary_plan]}', '#{ids[:stable]}', '#{ids[:horse]}', 'temporary', 'Temporary race plan', 'draft', '2026-08-01', '2026-08-01', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      insert into public.feeding_plan_versions (
        id, stable_id, feeding_plan_id, version_number, status,
        source_kind, change_reason,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:standard_version]}', '#{ids[:stable]}', '#{ids[:standard_plan]}', 1, 'draft', 'user', 'Standard race version', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:temporary_version]}', '#{ids[:stable]}', '#{ids[:temporary_plan]}', 1, 'draft', 'user', 'Temporary race version', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      insert into public.feeding_plan_items (
        id, stable_id, feeding_plan_version_id, product_name,
        source_status, planned_quantity, unit_code, offering_method,
        round_code, local_time, override_key, default_stable_member_id,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values
        ('#{ids[:standard_item]}', '#{ids[:stable]}', '#{ids[:standard_version]}', 'Standard race feed', 'user_entered', 1, 'kg', 'bucket', 'morning', '08:00', 'race-key', '#{ids[:worker_member]}', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:temporary_item]}', '#{ids[:stable]}', '#{ids[:temporary_version]}', 'Temporary race feed', 'user_entered', 0.8, 'kg', 'bucket', 'morning', '08:00', 'race-key', '#{ids[:worker_member]}', '#{ids[:owner]}', '#{SecureRandom.uuid}', '#{ids[:owner]}', '#{SecureRandom.uuid}');
      update public.feeding_plan_versions
      set status = 'approved', approved_by_user_id = '#{ids[:owner]}',
          approved_at = now()
      where id in ('#{ids[:standard_version]}', '#{ids[:temporary_version]}');
      update public.feeding_plans
      set status = 'active', active_version_id = '#{ids[:standard_version]}'
      where id = '#{ids[:standard_plan]}';
      insert into public.schedule_items (
        id, stable_id, horse_id, item_kind, data_category,
        title, instruction, priority, scheduled_start_at,
        source_timezone, source_local_date, source_local_time, state,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:schedule_item]}', '#{ids[:stable]}', '#{ids[:horse]}',
        'feeding', 'horse.nutrition', 'Standard race feed', 'Race safely.', 'normal',
        '2026-08-01 08:00:00+00', 'UTC', '2026-08-01', '08:00', 'planned',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.feeding_occurrences (
        schedule_item_id, stable_id, feeding_plan_version_id,
        feeding_plan_item_id, occurrence_local_date, planned_quantity,
        unit_code, offering_method, override_key,
        source_plan_type, source_status
      ) values (
        '#{ids[:schedule_item]}', '#{ids[:stable]}',
        '#{ids[:standard_version]}', '#{ids[:standard_item]}',
        '2026-08-01', 1, 'kg', 'bucket', 'race-key',
        'standard', 'user_entered'
      );
      insert into public.schedule_assignments (
        id, stable_id, schedule_item_id, stable_member_id,
        assignment_role, status,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:assignment]}', '#{ids[:stable]}', '#{ids[:schedule_item]}',
        '#{ids[:worker_member]}', 'responsible', 'assigned',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      commit;
    SQL
  )
  ids
end

def participant(name:, actor:, expression:, delay: 0.0)
  {
    name: name,
    actor: actor,
    expression: expression.sub('__REQUEST_ID__', SecureRandom.uuid),
    delay: delay
  }
end

def participant_sql(entry, gate_key, gate_tag)
  <<~SQL
    \\set VERBOSITY verbose
    begin;
    set local application_name = 'ffai-4c4-race-#{gate_tag}-#{entry[:name]}';
    select pg_advisory_lock_shared(#{gate_key});
    select pg_advisory_unlock_shared(#{gate_key});
    set local role authenticated;
    select set_config('request.jwt.claim.role', 'authenticated', true);
    select set_config('request.jwt.claim.sub', '#{entry[:actor]}', true);
    select pg_sleep(#{entry[:delay]});
    select 'RACE_RESULT|#{entry[:name]}|' || (#{entry[:expression]})::text;
    commit;
  SQL
end

def capture(psql, entry, gate_key, gate_tag)
  Open3.popen3(*psql) do |stdin, stdout, stderr, wait_thread|
    stdin.write(participant_sql(entry, gate_key, gate_tag))
    stdin.close
    stdout_reader = Thread.new { stdout.read }
    stderr_reader = Thread.new { stderr.read }
    status = Timeout.timeout(20) { wait_thread.value }
    {
      entry: entry,
      stdout: stdout_reader.value,
      stderr: stderr_reader.value,
      status: status
    }
  rescue Timeout::Error
    Process.kill('TERM', wait_thread.pid)
    wait_thread.value
    raise "#{entry[:name]} timed out"
  end
end

def race(psql, participants)
  gate_key = SecureRandom.random_number(2_000_000_000) + 1
  gate_tag = SecureRandom.hex(8)
  gate_in, gate_out, gate_err, gate_wait = Open3.popen3(*psql)
  out_reader = Thread.new { gate_out.read }
  err_reader = Thread.new { gate_err.read }
  gate_in.write("select pg_advisory_lock(#{gate_key});\n")
  gate_in.flush
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
  loop do
    break if sql!(psql, "select pg_try_advisory_lock(#{gate_key});").strip == 'f'
    raise 'Coordinator gate was not acquired' if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 0.01
  end
  threads = participants.map do |entry|
    Thread.new { capture(psql, entry, gate_key, gate_tag) }
  end
  loop do
    waiting = sql!(
      psql,
      "select count(*) from pg_stat_activity " \
      "where application_name like 'ffai-4c4-race-#{gate_tag}-%' " \
      "and wait_event_type = 'Lock';"
    ).strip.to_i
    break if waiting == participants.length
    raise "Only #{waiting}/#{participants.length} participants reached gate" if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 0.01
  end
  gate_in.write("select pg_advisory_unlock(#{gate_key});\n\\q\n")
  gate_in.close
  gate_wait.value
  out_reader.value
  err_reader.value
  threads.map(&:value)
ensure
  gate_in&.close unless gate_in&.closed?
  if gate_wait&.alive?
    Process.kill('TERM', gate_wait.pid)
    gate_wait.value
  end
end

def classify(result)
  line = result[:stdout].lines.find { |value| value.include?('RACE_RESULT|') }
  return { kind: :success, value: line.strip.split('|', 3).last } if
    result[:status].success? && line

  match = result[:stderr].match(/ERROR:\s+([0-9A-Z]{5}):\s+([A-Z0-9_]+)/)
  raise "#{result[:entry][:name]} unreadable failure" unless match
  raise "#{result[:entry][:name]} deadlocked" if match[1] == '40P01'

  { kind: :error, sqlstate: match[1], message: match[2] }
end

def activate_expression(version, through_date)
  "public.activate_feeding_plan_version(" \
    "'#{version}', 2, '#{through_date}', '__REQUEST_ID__')"
end

def verify_control!(psql, ids)
  signature = sql!(
    psql,
    <<~SQL
      select concat_ws('|',
        stable.status,
        horse.status,
        horse.row_version,
        (select count(*) from public.feeding_plans plan
          where plan.stable_id = '#{ids[:control_stable]}'),
        (select count(*) from public.feeding_change_events event
          where event.stable_id = '#{ids[:control_stable]}')
      )
      from public.stables stable
      join public.horses horse on horse.id = '#{ids[:control_horse]}'
      where stable.id = '#{ids[:control_stable]}';
    SQL
  ).strip
  raise "Control stable changed: #{signature}" unless
    signature == 'active|active|1|0|0'
end

def execution_expression(ids)
  "public.record_feeding_execution(" \
    "'#{ids[:schedule_item]}', null, '__REQUEST_ID__', 'completed', " \
    "'2026-08-01 08:00:00+00', '2026-08-01 08:10:00+00', " \
    "'2026-08-01 08:10:00', 'UTC', 'online', null, null, " \
    "1, 'kg', 0, 'none', null, null)"
end

def scenario_standard_activation(psql, delay_a)
  ids = standard_activation_fixture(psql)
  participants = [
    participant(
      name: 'activate-a',
      actor: ids[:owner],
      delay: delay_a ? 0.15 : 0.0,
      expression: activate_expression(ids[:version_a], '2026-08-01')
    ),
    participant(
      name: 'activate-b',
      actor: ids[:owner],
      delay: delay_a ? 0.0 : 0.15,
      expression: activate_expression(ids[:version_b], '2026-08-01')
    )
  ]
  [ids, participants]
end

def scenario_approval_activation(psql, approval_first)
  ids = approval_activation_fixture(psql)
  participants = [
    participant(
      name: 'approve-version',
      actor: ids[:owner],
      delay: approval_first ? 0.0 : 0.15,
      expression: "public.approve_feeding_plan_version(" \
        "'#{ids[:version]}', 1, '__REQUEST_ID__')"
    ),
    participant(
      name: 'activate-version',
      actor: ids[:owner],
      delay: approval_first ? 0.15 : 0.0,
      expression: activate_expression(ids[:version], '2026-08-01')
    )
  ]
  [ids, participants]
end

def verify_approval_activation!(psql, ids, outcomes, approval_first)
  approval, activation = outcomes
  raise "Approval race failed: #{approval.inspect}" unless
    approval[:kind] == :success
  if approval_first
    raise "Post-approval activation failed: #{activation.inspect}" unless
      activation[:kind] == :success
    expected = 'active|approved|2|1|1|2'
  else
    valid_rejection = activation[:kind] == :error &&
      activation[:sqlstate] == '55000' &&
      activation[:message] == 'FEEDING_VERSION_NOT_ACTIVATABLE'
    raise "Pre-approval activation was not rejected: #{activation.inspect}" unless
      valid_rejection
    expected = 'draft|approved|2|0|0|1'
  end
  signature = sql!(
    psql,
    <<~SQL
      select concat_ws('|',
        plan.status,
        version.status,
        version.row_version,
        (select count(*) from public.feeding_occurrences occurrence
          where occurrence.feeding_plan_version_id = '#{ids[:version]}'),
        (select count(*) from private.feeding_mutation_receipts receipt
          where receipt.target_id = '#{ids[:version]}'
            and receipt.operation_name = 'activate_feeding_plan_version'),
        (select count(*) from public.feeding_change_events event
          where event.feeding_plan_version_id = '#{ids[:version]}')
      )
      from public.feeding_plans plan
      join public.feeding_plan_versions version
        on version.id = '#{ids[:version]}'
      where plan.id = '#{ids[:plan]}';
    SQL
  ).strip
  raise "Approval/activation final signature mismatch: #{signature}" unless
    signature == expected
  verify_control!(psql, ids)
end

def verify_standard!(psql, ids, outcomes)
  raise 'Standard activation race did not have one winner' unless
    outcomes.count { |outcome| outcome[:kind] == :success } == 1
  loser = outcomes.find { |outcome| outcome[:kind] == :error }
  raise "Unexpected standard loser: #{loser.inspect}" unless
    loser[:sqlstate] == '23P01' &&
    loser[:message] == 'STANDARD_FEEDING_PLAN_OVERLAP'
  state = sql!(
    psql,
    <<~SQL
      select concat_ws('|',
        count(*) filter (where status = 'active'),
        count(*) filter (where status = 'draft'),
        (select count(*) from public.feeding_occurrences occurrence
          where occurrence.stable_id = '#{ids[:stable]}'),
        (select count(*) from private.feeding_mutation_receipts receipt
          where receipt.stable_id = '#{ids[:stable]}'
            and receipt.operation_name = 'activate_feeding_plan_version')
      )
      from public.feeding_plans
      where id in ('#{ids[:plan_a]}', '#{ids[:plan_b]}');
    SQL
  ).strip
  raise "Standard activation final state mismatch: #{state}" unless
    state == '1|1|1|1'
  verify_control!(psql, ids)
end

def scenario_temporary_execution(psql, activation_first)
  ids = temporary_execution_fixture(psql)
  participants = [
    participant(
      name: 'activate-temporary',
      actor: ids[:owner],
      delay: activation_first ? 0.0 : 0.15,
      expression: activate_expression(ids[:temporary_version], '2026-08-01')
    ),
    participant(
      name: 'execute-standard',
      actor: ids[:worker],
      delay: activation_first ? 0.15 : 0.0,
      expression: execution_expression(ids)
    )
  ]
  [ids, participants]
end

def verify_temporary_execution!(psql, ids, outcomes)
  activation, execution = outcomes
  raise "Temporary activation failed: #{activation.inspect}" unless
    activation[:kind] == :success
  unless execution[:kind] == :success ||
      (
        execution[:kind] == :error &&
        %w[NOT_AUTHORIZED SCHEDULE_ITEM_TERMINAL].include?(execution[:message])
      )
    raise "Unexpected execution outcome: #{execution.inspect}"
  end
  state = sql!(
    psql,
    <<~SQL
      select concat_ws('|',
        item.state,
        assignment.status,
        (select count(*) from public.schedule_executions execution
          where execution.schedule_item_id = '#{ids[:schedule_item]}'),
        (select count(*) from public.feeding_execution_details detail
          where detail.schedule_item_id = '#{ids[:schedule_item]}'),
        (select count(*) from public.feeding_occurrences occurrence
          where occurrence.feeding_plan_version_id = '#{ids[:temporary_version]}'),
        (select count(*) from public.feeding_plans plan
          where plan.id = '#{ids[:temporary_plan]}' and plan.status = 'active')
      )
      from public.schedule_items item
      join public.schedule_assignments assignment
        on assignment.id = '#{ids[:assignment]}'
      where item.id = '#{ids[:schedule_item]}';
    SQL
  ).strip
  valid = [
    'completed|completed|1|1|0|1',
    'cancelled|cancelled|0|0|1|1'
  ]
  raise "Temporary/execution final state mismatch: #{state}" unless
    valid.include?(state)
  verify_control!(psql, ids)
end

builders = {
  'approval-activation-approval-first' => lambda {
    ids, participants = scenario_approval_activation(psql, true)
    [
      ids,
      participants,
      lambda { |outcomes|
        verify_approval_activation!(psql, ids, outcomes, true)
      }
    ]
  },
  'approval-activation-activation-first' => lambda {
    ids, participants = scenario_approval_activation(psql, false)
    [
      ids,
      participants,
      lambda { |outcomes|
        verify_approval_activation!(psql, ids, outcomes, false)
      }
    ]
  },
  'standard-activation-a-first' => lambda {
    ids, participants = scenario_standard_activation(psql, false)
    [ids, participants, ->(outcomes) { verify_standard!(psql, ids, outcomes) }]
  },
  'standard-activation-b-first' => lambda {
    ids, participants = scenario_standard_activation(psql, true)
    [ids, participants, ->(outcomes) { verify_standard!(psql, ids, outcomes) }]
  },
  'temporary-execution-activation-first' => lambda {
    ids, participants = scenario_temporary_execution(psql, true)
    [
      ids,
      participants,
      ->(outcomes) { verify_temporary_execution!(psql, ids, outcomes) }
    ]
  },
  'temporary-execution-execution-first' => lambda {
    ids, participants = scenario_temporary_execution(psql, false)
    [
      ids,
      participants,
      ->(outcomes) { verify_temporary_execution!(psql, ids, outcomes) }
    ]
  }
}

passed = 0
iterations.times do |iteration|
  builders.each do |name, builder|
    _ids, participants, validator = builder.call
    outcomes = race(psql, participants).map { |result| classify(result) }
    validator.call(outcomes)
    puts(
      "#{name} iteration=#{iteration + 1}: " \
      "#{outcomes.map { |value| value[:kind] }.join('/')}"
    ) unless quiet
    passed += 1
  end
end

puts(
  "SUMMARY: #{passed}/#{iterations * builders.length} 4C.4 races passed; " \
  "participants=#{passed * 2}/#{iterations * builders.length * 2}"
)
