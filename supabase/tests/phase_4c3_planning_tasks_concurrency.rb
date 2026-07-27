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

  raise "Local SQL failed: #{stderr.lines.last.to_s.strip}"
end

def fixture(psql)
  ids = {
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
    control_horse: SecureRandom.uuid,
    item: SecureRandom.uuid,
    assignment: SecureRandom.uuid
  }
  sql!(
    psql,
    <<~SQL
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
        ('#{ids[:stable]}', 'organization', '4C3 race stable', 'active', 'UTC', 'nl', '#{ids[:owner]}', '#{SecureRandom.uuid}'),
        ('#{ids[:control_stable]}', 'organization', '4C3 control stable', 'active', 'UTC', 'nl', '#{ids[:control_owner]}', '#{SecureRandom.uuid}');
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
      insert into public.schedule_items (
        id, stable_id, horse_id, item_kind, data_category,
        title, instruction, priority,
        scheduled_start_at, scheduled_end_at,
        source_timezone, source_local_date, source_local_time,
        state, created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:item]}', '#{ids[:stable]}', '#{ids[:horse]}',
        'task', 'horse.schedule', 'Race item', 'Race safely.',
        'normal', '2026-07-28 08:00:00+00', '2026-07-28 08:30:00+00',
        'UTC', '2026-07-28', '08:00', 'planned',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.schedule_assignments (
        id, stable_id, schedule_item_id, stable_member_id,
        assignment_role, status,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:assignment]}', '#{ids[:stable]}', '#{ids[:item]}',
        '#{ids[:worker_member]}', 'responsible', 'assigned',
        '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      commit;
    SQL
  )
  ids
end

def participant(name:, actor:, expression:, delay: 0.0, request_id: nil)
  request_id ||= SecureRandom.uuid
  {
    name: name,
    actor: actor,
    request_id: request_id,
    expression: expression.sub('__REQUEST_ID__', request_id),
    delay: delay
  }
end

def participant_sql(entry, gate_key, gate_tag)
  <<~SQL
    \\set VERBOSITY verbose
    begin;
    set local application_name = 'ffai-4c3-race-#{gate_tag}-#{entry[:name]}';
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
    status = Timeout.timeout(15) { wait_thread.value }
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
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6
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
      <<~SQL
        select count(*) from pg_stat_activity
        where application_name like 'ffai-4c3-race-#{gate_tag}-%'
          and wait_event_type = 'Lock';
      SQL
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

def state(psql, ids)
  sql!(
    psql,
    <<~SQL
      select concat_ws('|',
        horse.status,
        item.state,
        item.row_version,
        item.title,
        assignment.status,
        worker.status,
        (select count(*) from public.schedule_executions execution
          where execution.schedule_item_id = '#{ids[:item]}'),
        (select count(*) from public.schedule_change_events event
          where event.schedule_item_id = '#{ids[:item]}'
            and event.event_type in (
              'schedule_execution_recorded',
              'schedule_item_updated'
            )),
        (select count(*) from private.schedule_mutation_receipts receipt
          where receipt.stable_id = '#{ids[:stable]}'),
        control_horse.status,
        control_horse.row_version,
        (select count(*) from public.schedule_items control_item
          where control_item.stable_id = '#{ids[:control_stable]}')
      )
      from public.horses horse
      join public.schedule_items item on item.id = '#{ids[:item]}'
      join public.schedule_assignments assignment
        on assignment.id = '#{ids[:assignment]}'
      join public.stable_memberships worker
        on worker.id = '#{ids[:worker_membership]}'
      join public.horses control_horse
        on control_horse.id = '#{ids[:control_horse]}'
      where horse.id = '#{ids[:horse]}';
    SQL
  ).strip.split('|')
end

def require_success!(outcome, label)
  raise "#{label} failed: #{outcome.inspect}" unless outcome[:kind] == :success
end

def require_error!(outcome, label, states, messages)
  valid = outcome[:kind] == :error &&
    states.include?(outcome[:sqlstate]) &&
    messages.include?(outcome[:message])
  raise "#{label} unexpected: #{outcome.inspect}" unless valid
end

def verify_control!(values)
  raise 'Control stable changed' unless values[9..11] == %w[active 1 0]
end

def execution_expression(ids, status = 'completed')
  "public.record_schedule_execution('#{ids[:item]}', '__REQUEST_ID__', " \
    "'#{status}', '2026-07-28 08:01:00+00', " \
    "'2026-07-28 08:10:00+00', '2026-07-28 08:10:00', " \
    "'UTC', 'online', null, null)"
end

def scenario_execution_execution(psql, same_request)
  ids = fixture(psql)
  shared_request = same_request ? SecureRandom.uuid : nil
  participants = %w[execution-a execution-b].map do |name|
    participant(
      name: name,
      actor: ids[:worker],
      request_id: shared_request,
      expression: execution_expression(ids)
    )
  end
  [ids, participants, lambda do |outcomes, values|
    if same_request
      outcomes.each { |outcome| require_success!(outcome, 'idempotent execution') }
    else
      raise 'Execution race did not have one winner' unless
        outcomes.count { |outcome| outcome[:kind] == :success } == 1
      loser = outcomes.find { |outcome| outcome[:kind] == :error }
      require_error!(
        loser,
        'execution loser',
        %w[42501 55000],
        %w[NOT_AUTHORIZED SCHEDULE_ITEM_TERMINAL]
      )
    end
    raise 'Execution race final state mismatch' unless
      values[0..8] == [
        'active', 'completed', '2', 'Race item', 'completed', 'active',
        '1', '1', '1'
      ]
    verify_control!(values)
  end]
end

def scenario_execution_return(psql, execution_first)
  ids = fixture(psql)
  participants = [
    participant(
      name: 'execution',
      actor: ids[:worker],
      delay: execution_first ? 0.0 : 0.15,
      expression: execution_expression(ids, 'partial')
    ),
    participant(
      name: 'return-assignment',
      actor: ids[:worker],
      delay: execution_first ? 0.15 : 0.0,
      expression: "public.return_schedule_assignment('#{ids[:assignment]}', 1, '__REQUEST_ID__')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    execution, returned = outcomes
    require_success!(returned, 'assignment return')
    if execution[:kind] == :success
      raise 'Committed execution missing' unless values[1] == 'in_progress' &&
        values[6..8] == %w[1 1 2]
    else
      require_error!(execution, 'execution', %w[42501], %w[NOT_AUTHORIZED])
      raise 'Rejected execution changed item' unless values[1] == 'planned' &&
        values[6..8] == %w[0 0 1]
    end
    raise 'Assignment was not returned' unless values[4] == 'returned'
    verify_control!(values)
  end]
end

def scenario_execution_suspend(psql, execution_first)
  ids = fixture(psql)
  participants = [
    participant(
      name: 'execution',
      actor: ids[:worker],
      delay: execution_first ? 0.0 : 0.15,
      expression: execution_expression(ids, 'partial')
    ),
    participant(
      name: 'suspend-membership',
      actor: ids[:owner],
      delay: execution_first ? 0.15 : 0.0,
      expression: "public.suspend_stable_membership('#{ids[:worker_membership]}', '__REQUEST_ID__')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    execution, suspended = outcomes
    require_success!(suspended, 'membership suspend')
    if execution[:kind] == :success
      raise 'Committed execution missing' unless values[1] == 'in_progress' &&
        values[6..8] == %w[1 1 1]
    else
      require_error!(
        execution,
        'execution',
        %w[42501],
        %w[SCHEDULE_UNAVAILABLE]
      )
      raise 'Rejected execution changed item' unless values[1] == 'planned' &&
        values[6..8] == %w[0 0 0]
    end
    raise 'Membership was not suspended' unless values[5] == 'suspended'
    verify_control!(values)
  end]
end

def scenario_execution_archive(psql, execution_first)
  ids = fixture(psql)
  participants = [
    participant(
      name: 'execution',
      actor: ids[:worker],
      delay: execution_first ? 0.0 : 0.15,
      expression: execution_expression(ids, 'partial')
    ),
    participant(
      name: 'archive-horse',
      actor: ids[:owner],
      delay: execution_first ? 0.15 : 0.0,
      expression: "public.archive_horse('#{ids[:horse]}', '__REQUEST_ID__', '4C3 concurrency archive')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    execution, archived = outcomes
    require_success!(archived, 'Horse archive')
    if execution[:kind] == :success
      raise 'Committed execution missing' unless values[1] == 'in_progress' &&
        values[6..8] == %w[1 1 1]
    else
      require_error!(
        execution,
        'execution',
        %w[42501],
        %w[SCHEDULE_UNAVAILABLE]
      )
      raise 'Rejected execution changed item' unless values[1] == 'planned' &&
        values[6..8] == %w[0 0 0]
    end
    raise 'Horse was not archived' unless values[0] == 'archived'
    verify_control!(values)
  end]
end

def scenario_update_archive(psql, update_first)
  ids = fixture(psql)
  participants = [
    participant(
      name: 'update-item',
      actor: ids[:owner],
      delay: update_first ? 0.0 : 0.15,
      expression: "public.update_schedule_item('#{ids[:item]}', 1, '__REQUEST_ID__', 'Updated race item', 'Race safely.', 'normal', '2026-07-28 08:00:00+00', '2026-07-28 08:30:00+00', 'UTC', '2026-07-28', '08:00')"
    ),
    participant(
      name: 'archive-horse',
      actor: ids[:owner],
      delay: update_first ? 0.15 : 0.0,
      expression: "public.archive_horse('#{ids[:horse]}', '__REQUEST_ID__', '4C3 update/archive race')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    update, archived = outcomes
    require_success!(archived, 'Horse archive')
    if update[:kind] == :success
      raise 'Committed update missing' unless values[2..3] == [
        '2', 'Updated race item'
      ] && values[7..8] == %w[1 1]
    else
      require_error!(
        update,
        'schedule update',
        %w[42501],
        %w[SCHEDULE_UNAVAILABLE]
      )
      raise 'Rejected update changed item' unless values[2..3] == [
        '1', 'Race item'
      ] && values[7..8] == %w[0 0]
    end
    raise 'Horse was not archived' unless values[0] == 'archived'
    verify_control!(values)
  end]
end

builders = {
  'execution-execution-distinct' => -> {
    scenario_execution_execution(psql, false)
  },
  'execution-execution-same-request' => -> {
    scenario_execution_execution(psql, true)
  },
  'execution-return-execution-first' => -> {
    scenario_execution_return(psql, true)
  },
  'execution-return-return-first' => -> {
    scenario_execution_return(psql, false)
  },
  'execution-suspend-execution-first' => -> {
    scenario_execution_suspend(psql, true)
  },
  'execution-suspend-suspend-first' => -> {
    scenario_execution_suspend(psql, false)
  },
  'execution-archive-execution-first' => -> {
    scenario_execution_archive(psql, true)
  },
  'execution-archive-archive-first' => -> {
    scenario_execution_archive(psql, false)
  },
  'update-archive-update-first' => -> {
    scenario_update_archive(psql, true)
  },
  'update-archive-archive-first' => -> {
    scenario_update_archive(psql, false)
  }
}

passed = 0
iterations.times do |iteration|
  builders.each do |name, builder|
    ids, participants, validator = builder.call
    outcomes = race(psql, participants).map { |result| classify(result) }
    values = state(psql, ids)
    validator.call(outcomes, values)
    puts(
      "#{name} iteration=#{iteration + 1}: " \
      "#{outcomes.map { |value| value[:kind] }.join('/')}"
    ) unless quiet
    passed += 1
  end
end

puts(
  "SUMMARY: #{passed}/#{iterations * builders.length} 4C.3 races passed; " \
  "participants=#{passed * 2}/#{iterations * builders.length * 2}"
)
