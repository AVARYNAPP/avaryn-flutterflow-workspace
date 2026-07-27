require 'open3'
require 'securerandom'
require 'set'
require 'timeout'

container = 'supabase_db_avaryn-flutterflow-workspace'
iterations = 1
scenario_filter = nil
quiet = false
timeout_seconds = 10
arguments = ARGV.dup
until arguments.empty?
  argument = arguments.shift
  case argument
  when '--iterations'
    iterations = Integer(arguments.shift)
  when '--scenario'
    scenario_filter = arguments.shift
  when '--timeout'
    timeout_seconds = Integer(arguments.shift)
  when '--quiet'
    quiet = true
  else
    container = argument
  end
end

raise 'iterations must be positive' unless iterations.positive?
raise 'timeout must be positive' unless timeout_seconds.positive?

PSQL = [
  'docker', 'exec', '-i', container,
  'psql', '-X', '-A', '-t', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'
].freeze

def sql!(source)
  stdout, stderr, status = Open3.capture3(*PSQL, stdin_data: source)
  return stdout if status.success?

  raise "Local SQL failed: #{stderr.lines.last.to_s.strip}"
end

def ids
  {
    stable: SecureRandom.uuid,
    control_stable: SecureRandom.uuid,
    owner: SecureRandom.uuid,
    admin: SecureRandom.uuid,
    member: SecureRandom.uuid,
    control_owner: SecureRandom.uuid,
    owner_member: SecureRandom.uuid,
    admin_member: SecureRandom.uuid,
    member_member: SecureRandom.uuid,
    control_owner_member: SecureRandom.uuid,
    owner_membership: SecureRandom.uuid,
    admin_membership: SecureRandom.uuid,
    member_membership: SecureRandom.uuid,
    control_owner_membership: SecureRandom.uuid,
    horse: SecureRandom.uuid,
    control_horse: SecureRandom.uuid
  }
end

def create_fixture(initial_grant: false)
  fixture = ids
  grant_sql = if initial_grant
    <<~SQL
      insert into public.horse_access_grants (
        stable_id, horse_id, membership_id, category,
        can_view, can_edit, granted_by_user_id, granted_request_id
      ) values (
        '#{fixture[:stable]}', '#{fixture[:horse]}',
        '#{fixture[:member_membership]}', 'horse.basic',
        true, true, '#{fixture[:owner]}', '#{SecureRandom.uuid}'
      );
    SQL
  else
    ''
  end
  sql!(
    <<~SQL
      begin;
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
      ) values
        ('00000000-0000-0000-0000-000000000000', '#{fixture[:owner]}', 'authenticated', 'authenticated', '#{fixture[:owner]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{fixture[:admin]}', 'authenticated', 'authenticated', '#{fixture[:admin]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{fixture[:member]}', 'authenticated', 'authenticated', '#{fixture[:member]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{fixture[:control_owner]}', 'authenticated', 'authenticated', '#{fixture[:control_owner]}@example.invalid', '', now(), '{}', '{}', now(), now());
      insert into public.stables (
        id, kind, name, status, timezone, locale,
        created_by_user_id, creation_request_id
      ) values
        ('#{fixture[:stable]}', 'organization', 'Horse race stable', 'active', 'UTC', 'nl', '#{fixture[:owner]}', '#{SecureRandom.uuid}'),
        ('#{fixture[:control_stable]}', 'organization', 'Horse control stable', 'active', 'UTC', 'nl', '#{fixture[:control_owner]}', '#{SecureRandom.uuid}');
      insert into public.stable_members (
        id, stable_id, display_name, source
      ) values
        ('#{fixture[:owner_member]}', '#{fixture[:stable]}', 'Race owner', 'owner_creation'),
        ('#{fixture[:admin_member]}', '#{fixture[:stable]}', 'Race admin', 'manual'),
        ('#{fixture[:member_member]}', '#{fixture[:stable]}', 'Race member', 'manual'),
        ('#{fixture[:control_owner_member]}', '#{fixture[:control_stable]}', 'Control owner', 'owner_creation');
      insert into public.stable_memberships (
        id, stable_id, user_id, stable_member_id, role, status, joined_at
      ) values
        ('#{fixture[:owner_membership]}', '#{fixture[:stable]}', '#{fixture[:owner]}', '#{fixture[:owner_member]}', 'owner', 'active', now()),
        ('#{fixture[:admin_membership]}', '#{fixture[:stable]}', '#{fixture[:admin]}', '#{fixture[:admin_member]}', 'admin', 'active', now()),
        ('#{fixture[:member_membership]}', '#{fixture[:stable]}', '#{fixture[:member]}', '#{fixture[:member_member]}', 'member', 'active', now()),
        ('#{fixture[:control_owner_membership]}', '#{fixture[:control_stable]}', '#{fixture[:control_owner]}', '#{fixture[:control_owner_member]}', 'owner', 'active', now());
      set constraints all immediate;
      insert into public.horses (
        id, stable_id, display_name, source_kind,
        created_by_user_id, created_request_id
      ) values
        ('#{fixture[:horse]}', '#{fixture[:stable]}', 'Race Horse', 'manual', '#{fixture[:owner]}', '#{SecureRandom.uuid}'),
        ('#{fixture[:control_horse]}', '#{fixture[:control_stable]}', 'Control Horse', 'manual', '#{fixture[:control_owner]}', '#{SecureRandom.uuid}');
      #{grant_sql}
      commit;
    SQL
  )
  fixture
end

def participant(name:, actor:, expression:, request_id: SecureRandom.uuid, delay: 0.0)
  {
    name: name,
    actor: actor,
    expression: expression.sub('__REQUEST_ID__', request_id),
    request_id: request_id,
    delay: delay
  }
end

def participant_sql(entry, gate_key, gate_tag)
  <<~SQL
    \\set VERBOSITY verbose
    begin;
    set local application_name = 'ffai-horse-race-#{gate_tag}-#{entry[:name]}';
    select pg_advisory_lock_shared(#{gate_key});
    select pg_advisory_unlock_shared(#{gate_key});
    set local role authenticated;
    select set_config('request.jwt.claim.role', 'authenticated', true);
    select set_config('request.jwt.claim.sub', '#{entry[:actor]}', true);
    select pg_sleep(#{entry[:delay]});
    select 'RACE_RESULT|#{entry[:name]}|#{entry[:request_id]}|' ||
      (#{entry[:expression]})::text;
    commit;
  SQL
end

def capture(entry, timeout_seconds, gate_key, gate_tag)
  Open3.popen3(*PSQL) do |stdin, stdout, stderr, wait_thread|
    stdin.write(participant_sql(entry, gate_key, gate_tag))
    stdin.close
    stdout_reader = Thread.new { stdout.read }
    stderr_reader = Thread.new { stderr.read }
    timed_out = false
    status = begin
      Timeout.timeout(timeout_seconds) { wait_thread.value }
    rescue Timeout::Error
      timed_out = true
      Process.kill('TERM', wait_thread.pid)
      begin
        Timeout.timeout(2) { wait_thread.value }
      rescue Timeout::Error
        Process.kill('KILL', wait_thread.pid)
        wait_thread.value
      end
    end
    {
      participant: entry,
      stdout: stdout_reader.value,
      stderr: stderr_reader.value,
      status: status,
      timed_out: timed_out
    }
  end
end

def race(participants, timeout_seconds)
  gate_key = SecureRandom.random_number(2_000_000_000) + 1
  gate_tag = SecureRandom.hex(8)
  gate_stdin, gate_stdout, gate_stderr, gate_wait = Open3.popen3(*PSQL)
  gate_stdout_reader = Thread.new { gate_stdout.read }
  gate_stderr_reader = Thread.new { gate_stderr.read }
  gate_stdin.write("select pg_advisory_lock(#{gate_key});\n")
  gate_stdin.flush

  gate_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  loop do
    break if sql!("select pg_try_advisory_lock(#{gate_key});").strip == 'f'
    raise 'Coordinator advisory gate was not acquired' if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= gate_deadline
    sleep 0.01
  end

  threads = participants.map do |entry|
    Thread.new do
      capture(entry, timeout_seconds, gate_key, gate_tag)
    end
  end

  loop do
    waiting = sql!(
      <<~SQL
        select count(*)
        from pg_stat_activity
        where application_name like 'ffai-horse-race-#{gate_tag}-%'
          and wait_event_type = 'Lock';
      SQL
    ).strip.to_i
    break if waiting == participants.length
    raise "Only #{waiting}/#{participants.length} database participants reached the gate" if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) >= gate_deadline
    sleep 0.01
  end

  gate_stdin.write("select pg_advisory_unlock(#{gate_key});\n\\q\n")
  gate_stdin.close
  gate_wait.value
  gate_stdout_reader.value
  gate_stderr_reader.value
  threads.map(&:value)
ensure
  gate_stdin&.close unless gate_stdin&.closed?
  if gate_wait&.alive?
    Process.kill('TERM', gate_wait.pid)
    gate_wait.value
  end
end

def classify(result)
  raise "#{result[:participant][:name]} timed out" if result[:timed_out]

  sentinel = result[:stdout].lines.find { |line| line.include?('RACE_RESULT|') }
  if result[:status]&.success? && sentinel
    return {
      kind: :success,
      value: sentinel.strip.split('|', 4).last,
      sqlstate: nil,
      message: nil
    }
  end
  match = result[:stderr].match(/ERROR:\s+([0-9A-Z]{5}):\s+([A-Z0-9_]+)/)
  raise(
    "#{result[:participant][:name]} produced an unreadable failure: " \
    "#{result[:stderr].lines.last.to_s.strip}"
  ) unless match

  raise "#{result[:participant][:name]} deadlocked" if match[1] == '40P01'

  {
    kind: :error,
    value: nil,
    sqlstate: match[1],
    message: match[2]
  }
end

def events(request_ids)
  quoted = request_ids.map { |value| "'#{value}'::uuid" }.join(',')
  output = sql!(
    <<~SQL
      select request_id::text || '|' || event_type || '|security'
      from public.stable_security_events
      where request_id in (#{quoted})
      union all
      select request_id::text || '|' || event_type || '|profile'
      from public.horse_profile_change_events
      where request_id in (#{quoted})
      order by 1;
    SQL
  )
  output.lines.map(&:strip).reject(&:empty?).group_by { |line| line.split('|').first }
end

def state(fixture)
  sql!(
    <<~SQL
      select concat_ws('|',
        h.status,
        h.row_version,
        m.status,
        count(g.id) filter (where g.status = 'active'),
        count(g.id),
        (select count(*) from public.stable_security_events e where e.stable_id = '#{fixture[:control_stable]}'),
        (select count(*) from public.horse_profile_change_events e where e.stable_id = '#{fixture[:control_stable]}'),
        (select count(*) from public.horses ch where ch.stable_id = '#{fixture[:control_stable]}'),
        (select count(*) from public.horses rh where rh.stable_id = '#{fixture[:stable]}'),
        (select status from public.stable_memberships am where am.id = '#{fixture[:admin_membership]}'),
        (select status from public.stables rs where rs.id = '#{fixture[:stable]}')
      )
      from public.horses h
      join public.stable_memberships m on m.id = '#{fixture[:member_membership]}'
      left join public.horse_access_grants g on g.horse_id = h.id
      where h.id = '#{fixture[:horse]}'
      group by h.status, h.row_version, m.status;
    SQL
  ).strip.split('|')
end

def assert_event_count!(event_map, entry, expected_type, expected_count)
  rows = event_map.fetch(entry[:request_id], [])
  actual = rows.count { |line| line.split('|')[1] == expected_type }
  return if actual == expected_count && rows.length == expected_count

  raise(
    "#{entry[:name]} event mismatch: expected #{expected_type}=#{expected_count}, " \
    "got #{rows.inspect}"
  )
end

def require_success!(outcome, label)
  raise "#{label} failed: #{outcome.inspect}" unless outcome[:kind] == :success
end

def require_error!(outcome, label, sqlstate, messages)
  valid = outcome[:kind] == :error &&
    outcome[:sqlstate] == sqlstate &&
    messages.include?(outcome[:message])
  raise "#{label} unexpected outcome: #{outcome.inspect}" unless valid
end

def validate_control!(values)
  raise "Control stable changed: #{values.inspect}" unless values[5..7] == %w[0 0 1]
end

def scenario_create_suspend(order)
  fixture = create_fixture
  create_delay = order == :create_first ? 0.0 : 0.15
  suspend_delay = order == :suspend_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'create',
      actor: fixture[:admin],
      delay: create_delay,
      expression: "public.create_horse('#{fixture[:stable]}', 'Concurrent Foal', '__REQUEST_ID__')"
    ),
    participant(
      name: 'suspend-admin',
      actor: fixture[:owner],
      delay: suspend_delay,
      expression: "public.suspend_stable_membership('#{fixture[:admin_membership]}', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    create, suspend = outcomes
    require_success!(suspend, 'suspend admin')
    assert_event_count!(event_map, participants[1], 'membership_suspended', 1)
    if create[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_created', 1)
      raise 'Committed create is missing' unless values[8] == '2'
    else
      require_error!(create, 'create', '42501', ['NOT_AUTHORIZED'])
      assert_event_count!(event_map, participants[0], 'horse_created', 0)
      raise 'Rejected create left a Horse' unless values[8] == '1'
    end
    raise 'Create/suspend did not suspend the actor' unless values[9] == 'suspended'
    raise 'Create/suspend changed stable status' unless values[10] == 'active'
  end]
end

def scenario_create_archive(order)
  fixture = create_fixture
  create_delay = order == :create_first ? 0.0 : 0.15
  archive_delay = order == :archive_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'create',
      actor: fixture[:owner],
      delay: create_delay,
      expression: "public.create_horse('#{fixture[:stable]}', 'Concurrent Foal', '__REQUEST_ID__')"
    ),
    participant(
      name: 'archive-stable',
      actor: fixture[:owner],
      delay: archive_delay,
      expression: "public.archive_stable('#{fixture[:stable]}', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    create, archive = outcomes
    require_success!(archive, 'archive stable')
    assert_event_count!(event_map, participants[1], 'stable_archived', 1)
    if create[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_created', 1)
      raise 'Committed create before archive is missing' unless values[8] == '2'
    else
      require_error!(create, 'create', '42501', ['NOT_AUTHORIZED'])
      assert_event_count!(event_map, participants[0], 'horse_created', 0)
      raise 'Rejected archived-stable create left a Horse' unless values[8] == '1'
    end
    raise 'Create/archive did not archive the stable' unless values[10] == 'archived'
  end]
end

def scenario_grant_suspend(order)
  fixture = create_fixture
  grant_delay = order == :grant_first ? 0.0 : 0.15
  suspend_delay = order == :suspend_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'grant',
      actor: fixture[:owner],
      delay: grant_delay,
      expression: "public.grant_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', true, false, true, false, null, null, null, '__REQUEST_ID__')"
    ),
    participant(
      name: 'suspend',
      actor: fixture[:owner],
      delay: suspend_delay,
      expression: "public.suspend_stable_membership('#{fixture[:member_membership]}', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    grant, suspend = outcomes
    require_success!(suspend, 'suspend')
    assert_event_count!(event_map, participants[1], 'membership_suspended', 1)
    if grant[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 1)
      raise 'Grant/suspend final grant mismatch' unless values[3..4] == %w[1 1]
    else
      require_error!(grant, 'grant', '42501', ['TARGET_MEMBERSHIP_UNAVAILABLE'])
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 0)
      raise 'Rejected grant left a row' unless values[3..4] == %w[0 0]
    end
    raise 'Target membership was not suspended' unless values[2] == 'suspended'
  end]
end

def scenario_admin_grant_suspension(order)
  fixture = create_fixture
  grant_delay = order == :grant_first ? 0.0 : 0.15
  suspend_delay = order == :suspend_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'admin-grant',
      actor: fixture[:admin],
      delay: grant_delay,
      expression: "public.grant_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', true, false, true, false, null, null, null, '__REQUEST_ID__')"
    ),
    participant(
      name: 'suspend-admin',
      actor: fixture[:owner],
      delay: suspend_delay,
      expression: "public.suspend_stable_membership('#{fixture[:admin_membership]}', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    grant, suspend = outcomes
    require_success!(suspend, 'suspend admin')
    assert_event_count!(event_map, participants[1], 'membership_suspended', 1)
    if grant[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 1)
      raise 'Actor-loss committed grant missing' unless values[3..4] == %w[1 1]
    else
      require_error!(grant, 'admin grant', '42501', ['HORSE_UNAVAILABLE'])
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 0)
      raise 'Actor-loss rejection left a grant' unless values[3..4] == %w[0 0]
    end
  end]
end

def scenario_grant_archive(order)
  fixture = create_fixture
  grant_delay = order == :grant_first ? 0.0 : 0.15
  archive_delay = order == :archive_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'grant',
      actor: fixture[:owner],
      delay: grant_delay,
      expression: "public.grant_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', true, false, true, false, null, null, null, '__REQUEST_ID__')"
    ),
    participant(
      name: 'archive',
      actor: fixture[:admin],
      delay: archive_delay,
      expression: "public.archive_horse('#{fixture[:horse]}', '__REQUEST_ID__', 'Concurrency archive')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    grant, archive = outcomes
    require_success!(archive, 'archive')
    assert_event_count!(event_map, participants[1], 'horse_archived', 1)
    if grant[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 1)
      raise 'Grant/archive final grant mismatch' unless values[3..4] == %w[1 1]
    else
      require_error!(grant, 'grant', '42501', ['HORSE_UNAVAILABLE'])
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 0)
      raise 'Rejected archived-Horse grant left a row' unless values[3..4] == %w[0 0]
    end
    raise 'Horse was not archived exactly once' unless values[0..1] == %w[archived 2]
  end]
end

def scenario_revoke_archive(order)
  fixture = create_fixture(initial_grant: true)
  revoke_delay = order == :revoke_first ? 0.0 : 0.15
  archive_delay = order == :archive_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'revoke',
      actor: fixture[:owner],
      delay: revoke_delay,
      expression: "public.revoke_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', '__REQUEST_ID__')"
    ),
    participant(
      name: 'archive',
      actor: fixture[:admin],
      delay: archive_delay,
      expression: "public.archive_horse('#{fixture[:horse]}', '__REQUEST_ID__', 'Concurrency archive')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    revoke, archive = outcomes
    require_success!(archive, 'archive')
    assert_event_count!(event_map, participants[1], 'horse_archived', 1)
    if revoke[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_access_revoked', 1)
      raise 'Revoke/archive final grant mismatch' unless values[3..4] == %w[0 1]
    else
      require_error!(revoke, 'revoke', '42501', ['HORSE_UNAVAILABLE'])
      assert_event_count!(event_map, participants[0], 'horse_access_revoked', 0)
      raise 'Rejected revoke changed grant' unless values[3..4] == %w[1 1]
    end
    raise 'Horse was not archived' unless values[0..1] == %w[archived 2]
  end]
end

def scenario_update_archive(order)
  fixture = create_fixture
  update_delay = order == :update_first ? 0.0 : 0.15
  archive_delay = order == :archive_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'update',
      actor: fixture[:admin],
      delay: update_delay,
      expression: "(public.update_horse_profile('#{fixture[:horse]}', 1, '__REQUEST_ID__', 'Race Horse Updated', null, null, 'unknown', null, null, null)).row_version"
    ),
    participant(
      name: 'archive',
      actor: fixture[:owner],
      delay: archive_delay,
      expression: "public.archive_horse('#{fixture[:horse]}', '__REQUEST_ID__', 'Concurrency archive')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    update, archive = outcomes
    require_success!(archive, 'archive')
    assert_event_count!(event_map, participants[1], 'horse_archived', 1)
    if update[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_profile_updated', 1)
      raise 'Update/archive lost a version' unless values[0..1] == %w[archived 3]
    else
      require_error!(update, 'update', '42501', ['NOT_AUTHORIZED'])
      assert_event_count!(event_map, participants[0], 'horse_profile_updated', 0)
      raise 'Rejected update changed version' unless values[0..1] == %w[archived 2]
    end
  end]
end

def scenario_update_update
  fixture = create_fixture
  participants = [
    participant(
      name: 'update-a',
      actor: fixture[:owner],
      expression: "(public.update_horse_profile('#{fixture[:horse]}', 1, '__REQUEST_ID__', 'Race Horse A', null, null, 'unknown', null, null, null)).row_version"
    ),
    participant(
      name: 'update-b',
      actor: fixture[:admin],
      expression: "(public.update_horse_profile('#{fixture[:horse]}', 1, '__REQUEST_ID__', 'Race Horse B', null, null, 'unknown', null, null, null)).row_version"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    successes = outcomes.each_index.select { |index| outcomes[index][:kind] == :success }
    failures = outcomes.each_index.to_a - successes
    raise 'Concurrent updates did not produce one winner' unless successes.length == 1
    require_error!(outcomes[failures.first], 'losing update', '40001', ['ROW_VERSION_CONFLICT'])
    successes.each do |index|
      assert_event_count!(event_map, participants[index], 'horse_profile_updated', 1)
    end
    failures.each do |index|
      assert_event_count!(event_map, participants[index], 'horse_profile_updated', 0)
    end
    raise 'Concurrent update final version mismatch' unless values[0..1] == %w[active 2]
  end]
end

def scenario_update_revoke(order)
  fixture = create_fixture(initial_grant: true)
  update_delay = order == :update_first ? 0.0 : 0.15
  revoke_delay = order == :revoke_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'member-update',
      actor: fixture[:member],
      delay: update_delay,
      expression: "(public.update_horse_profile('#{fixture[:horse]}', 1, '__REQUEST_ID__', 'Member Race Update', null, null, 'unknown', null, null, null)).row_version"
    ),
    participant(
      name: 'revoke',
      actor: fixture[:owner],
      delay: revoke_delay,
      expression: "public.revoke_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    update, revoke = outcomes
    require_success!(revoke, 'revoke')
    assert_event_count!(event_map, participants[1], 'horse_access_revoked', 1)
    if update[:kind] == :success
      assert_event_count!(event_map, participants[0], 'horse_profile_updated', 1)
      raise 'Update/revoke lost the committed profile update' unless values[0..1] == %w[active 2]
    else
      require_error!(update, 'member update', '42501', ['NOT_AUTHORIZED'])
      assert_event_count!(event_map, participants[0], 'horse_profile_updated', 0)
      raise 'Rejected member update changed the Horse' unless values[0..1] == %w[active 1]
    end
    raise 'Update/revoke did not revoke exactly one grant' unless values[3..4] == %w[0 1]
  end]
end

def scenario_grant_grant
  fixture = create_fixture
  participants = %w[grant-a grant-b].map do |name|
    participant(
      name: name,
      actor: fixture[:owner],
      expression: "public.grant_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', true, false, true, false, null, null, null, '__REQUEST_ID__')"
    )
  end
  [fixture, participants, lambda do |outcomes, event_map, values|
    outcomes.each_with_index { |outcome, index| require_success!(outcome, participants[index][:name]) }
    event_counts = participants.map do |entry|
      event_map.fetch(entry[:request_id], []).count
    end
    raise "Concurrent grants event mismatch: #{event_counts}" unless event_counts.sort == [0, 1]
    raise 'Concurrent grants created duplicate rows' unless values[3..4] == %w[1 1]
  end]
end

def scenario_grant_revoke(order)
  fixture = create_fixture(initial_grant: true)
  grant_delay = order == :grant_first ? 0.0 : 0.15
  revoke_delay = order == :revoke_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'grant',
      actor: fixture[:owner],
      delay: grant_delay,
      expression: "public.grant_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', true, false, true, false, null, null, null, '__REQUEST_ID__')"
    ),
    participant(
      name: 'revoke',
      actor: fixture[:owner],
      delay: revoke_delay,
      expression: "public.revoke_horse_access('#{fixture[:horse]}', '#{fixture[:member_membership]}', 'horse.basic', '__REQUEST_ID__')"
    )
  ]
  [fixture, participants, lambda do |outcomes, event_map, values|
    outcomes.each_with_index { |outcome, index| require_success!(outcome, participants[index][:name]) }
    assert_event_count!(event_map, participants[1], 'horse_access_revoked', 1)
    grant_events = event_map.fetch(participants[0][:request_id], []).count
    if grant_events == 1
      assert_event_count!(event_map, participants[0], 'horse_access_granted', 1)
      raise 'Regrant after revoke did not create a fresh active row' unless values[3..4] == %w[1 2]
    elsif grant_events.zero?
      raise 'Idempotent grant before revoke left active access' unless values[3..4] == %w[0 1]
    else
      raise "Grant/revoke grant event mismatch: #{grant_events}"
    end
  end]
end

builders = {
  'create-suspend-create-first' => -> { scenario_create_suspend(:create_first) },
  'create-suspend-suspend-first' => -> { scenario_create_suspend(:suspend_first) },
  'create-archive-create-first' => -> { scenario_create_archive(:create_first) },
  'create-archive-archive-first' => -> { scenario_create_archive(:archive_first) },
  'grant-suspend-grant-first' => -> { scenario_grant_suspend(:grant_first) },
  'grant-suspend-suspend-first' => -> { scenario_grant_suspend(:suspend_first) },
  'admin-grant-suspend-grant-first' => -> { scenario_admin_grant_suspension(:grant_first) },
  'admin-grant-suspend-suspend-first' => -> { scenario_admin_grant_suspension(:suspend_first) },
  'grant-archive-grant-first' => -> { scenario_grant_archive(:grant_first) },
  'grant-archive-archive-first' => -> { scenario_grant_archive(:archive_first) },
  'revoke-archive-revoke-first' => -> { scenario_revoke_archive(:revoke_first) },
  'revoke-archive-archive-first' => -> { scenario_revoke_archive(:archive_first) },
  'update-archive-update-first' => -> { scenario_update_archive(:update_first) },
  'update-archive-archive-first' => -> { scenario_update_archive(:archive_first) },
  'update-update' => -> { scenario_update_update },
  'update-revoke-update-first' => -> { scenario_update_revoke(:update_first) },
  'update-revoke-revoke-first' => -> { scenario_update_revoke(:revoke_first) },
  'grant-grant' => -> { scenario_grant_grant },
  'grant-revoke-grant-first' => -> { scenario_grant_revoke(:grant_first) },
  'grant-revoke-revoke-first' => -> { scenario_grant_revoke(:revoke_first) }
}

if scenario_filter
  raise "Unknown scenario #{scenario_filter}" unless builders.key?(scenario_filter)
  builders.select! { |name, _builder| name == scenario_filter }
end

seen_requests = Set.new
passed = 0
iterations.times do |iteration|
  builders.each do |name, builder|
    fixture, participants, validator = builder.call
    participants.each do |entry|
      raise 'Request ID was reused' unless seen_requests.add?(entry[:request_id])
    end
    raw_results = race(participants, timeout_seconds)
    outcomes = raw_results.map { |result| classify(result) }
    event_map = events(participants.map { |entry| entry[:request_id] })
    values = state(fixture)
    validator.call(outcomes, event_map, values)
    validate_control!(values)
    unless quiet
      puts(
        "#{name} iteration=#{iteration + 1}: " \
        "#{outcomes.map { |outcome| outcome[:kind] }.join('/')} state=#{values.join('|')}"
      )
    end
    passed += 1
  end
end

puts(
  "SUMMARY: #{passed}/#{iterations * builders.length} Horse Core races passed; " \
  "participants=#{passed * 2}/#{iterations * builders.length * 2}"
)
