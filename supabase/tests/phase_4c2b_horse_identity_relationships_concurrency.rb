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
    owner: SecureRandom.uuid,
    admin: SecureRandom.uuid,
    member: SecureRandom.uuid,
    owner_member: SecureRandom.uuid,
    admin_member: SecureRandom.uuid,
    member_member: SecureRandom.uuid,
    owner_membership: SecureRandom.uuid,
    admin_membership: SecureRandom.uuid,
    member_membership: SecureRandom.uuid,
    horse: SecureRandom.uuid,
    identifier: SecureRandom.uuid,
    relationship: SecureRandom.uuid
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
        ('00000000-0000-0000-0000-000000000000', '#{ids[:admin]}', 'authenticated', 'authenticated', '#{ids[:admin]}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:member]}', 'authenticated', 'authenticated', '#{ids[:member]}@example.invalid', '', now(), '{}', '{}', now(), now());
      insert into public.stables (
        id, kind, name, status, timezone, locale,
        created_by_user_id, creation_request_id
      ) values (
        '#{ids[:stable]}', 'organization', '4C2B race stable',
        'active', 'UTC', 'nl', '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.stable_members (
        id, stable_id, display_name, source
      ) values
        ('#{ids[:owner_member]}', '#{ids[:stable]}', 'Race owner', 'owner_creation'),
        ('#{ids[:admin_member]}', '#{ids[:stable]}', 'Race admin', 'manual'),
        ('#{ids[:member_member]}', '#{ids[:stable]}', 'Race member', 'manual');
      insert into public.stable_memberships (
        id, stable_id, user_id, stable_member_id, role, status, joined_at
      ) values
        ('#{ids[:owner_membership]}', '#{ids[:stable]}', '#{ids[:owner]}', '#{ids[:owner_member]}', 'owner', 'active', now()),
        ('#{ids[:admin_membership]}', '#{ids[:stable]}', '#{ids[:admin]}', '#{ids[:admin_member]}', 'admin', 'active', now()),
        ('#{ids[:member_membership]}', '#{ids[:stable]}', '#{ids[:member]}', '#{ids[:member_member]}', 'member', 'active', now());
      set constraints all immediate;
      insert into public.horses (
        id, stable_id, display_name, source_kind,
        created_by_user_id, created_request_id
      ) values (
        '#{ids[:horse]}', '#{ids[:stable]}', 'Race Horse',
        'manual', '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.horse_access_grants (
        stable_id, horse_id, membership_id, category,
        can_view, can_edit, granted_by_user_id, granted_request_id, grant_reason
      ) values (
        '#{ids[:stable]}', '#{ids[:horse]}', '#{ids[:member_membership]}',
        'horse.identity', true, true, '#{ids[:owner]}',
        '#{SecureRandom.uuid}', 'Concurrency identity edit'
      );
      insert into public.horse_identifiers (
        id, stable_id, horse_id, identifier_type, identifier_value,
        created_by_user_id, created_request_id,
        last_mutated_by_user_id, last_mutation_request_id
      ) values (
        '#{ids[:identifier]}', '#{ids[:stable]}', '#{ids[:horse]}',
        'chip', 'initial', '#{ids[:owner]}', '#{SecureRandom.uuid}',
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      insert into public.horse_relationships (
        id, stable_id, horse_id, stable_member_id, relationship_type,
        valid_from, created_by_user_id, created_request_id
      ) values (
        '#{ids[:relationship]}', '#{ids[:stable]}', '#{ids[:horse]}',
        '#{ids[:member_member]}', 'rider', current_date,
        '#{ids[:owner]}', '#{SecureRandom.uuid}'
      );
      commit;
    SQL
  )
  ids
end

def participant(name:, actor:, expression:, delay: 0.0)
  request_id = SecureRandom.uuid
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
    set local application_name = 'ffai-4c2b-race-#{gate_tag}-#{entry[:name]}';
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
    status = Timeout.timeout(12) { wait_thread.value }
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
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
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
        where application_name like 'ffai-4c2b-race-#{gate_tag}-%'
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
        h.status,
        i.row_version,
        i.identifier_value,
        r.status,
        r.row_version,
        am.status,
        (select count(*) from public.horse_relationships ar
          where ar.horse_id = '#{ids[:horse]}' and ar.status = 'active')
      )
      from public.horses h
      join public.horse_identifiers i on i.id = '#{ids[:identifier]}'
      join public.horse_relationships r on r.id = '#{ids[:relationship]}'
      join public.stable_memberships am on am.id = '#{ids[:admin_membership]}'
      where h.id = '#{ids[:horse]}';
    SQL
  ).strip.split('|')
end

def require_success!(outcome, label)
  raise "#{label} failed: #{outcome.inspect}" unless outcome[:kind] == :success
end

def require_error!(outcome, label, state, message)
  valid = outcome[:kind] == :error &&
    outcome[:sqlstate] == state &&
    outcome[:message] == message
  raise "#{label} unexpected: #{outcome.inspect}" unless valid
end

def scenario_identifier_revoke(psql, order)
  ids = fixture(psql)
  update_delay = order == :update_first ? 0.0 : 0.15
  revoke_delay = order == :revoke_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'identifier-update',
      actor: ids[:member],
      delay: update_delay,
      expression: "(public.upsert_horse_identifier('#{ids[:horse]}', '#{ids[:identifier]}', 1, '__REQUEST_ID__', 'chip', 'updated', null, null, null, null)).row_version"
    ),
    participant(
      name: 'revoke',
      actor: ids[:owner],
      delay: revoke_delay,
      expression: "public.revoke_horse_access('#{ids[:horse]}', '#{ids[:member_membership]}', 'horse.identity', '__REQUEST_ID__')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    update, revoke = outcomes
    require_success!(revoke, 'revoke')
    if update[:kind] == :success
      raise 'Identifier winner missing' unless values[1..2] == %w[2 updated]
    else
      require_error!(update, 'identifier update', '42501', 'NOT_AUTHORIZED')
      raise 'Rejected identifier changed' unless values[1..2] == %w[1 initial]
    end
  end]
end

def scenario_identifier_update_update(psql)
  ids = fixture(psql)
  participants = %w[update-a update-b].map do |name|
    participant(
      name: name,
      actor: ids[:owner],
      expression: "(public.upsert_horse_identifier('#{ids[:horse]}', '#{ids[:identifier]}', 1, '__REQUEST_ID__', 'chip', '#{name}', null, null, null, null)).row_version"
    )
  end
  [ids, participants, lambda do |outcomes, values|
    raise 'Identifier race did not have one winner' unless
      outcomes.count { |outcome| outcome[:kind] == :success } == 1
    loser = outcomes.find { |outcome| outcome[:kind] == :error }
    require_error!(loser, 'identifier loser', '40001', 'ROW_VERSION_CONFLICT')
    raise 'Identifier version mismatch' unless values[1] == '2'
  end]
end

def scenario_relationship_suspend(psql, order)
  ids = fixture(psql)
  add_delay = order == :add_first ? 0.0 : 0.15
  suspend_delay = order == :suspend_first ? 0.0 : 0.15
  participants = [
    participant(
      name: 'relationship-add',
      actor: ids[:admin],
      delay: add_delay,
      expression: "public.add_horse_relationship('#{ids[:horse]}', '#{ids[:admin_member]}', 'trainer', '__REQUEST_ID__')"
    ),
    participant(
      name: 'suspend-admin',
      actor: ids[:owner],
      delay: suspend_delay,
      expression: "public.suspend_stable_membership('#{ids[:admin_membership]}', '__REQUEST_ID__')"
    )
  ]
  [ids, participants, lambda do |outcomes, values|
    add, suspend = outcomes
    require_success!(suspend, 'suspend admin')
    if add[:kind] == :success
      raise 'Committed relationship missing' unless values[6] == '2'
    else
      require_error!(add, 'relationship add', '42501', 'RELATIONSHIP_UNAVAILABLE')
      raise 'Rejected relationship remained' unless values[6] == '1'
    end
    raise 'Admin was not suspended' unless values[5] == 'suspended'
  end]
end

def scenario_relationship_archive(psql, operation)
  ids = fixture(psql)
  mutate_first = %w[add_first end_first].include?(operation)
  mutate_delay = mutate_first ? 0.0 : 0.15
  archive_delay = mutate_first ? 0.15 : 0.0
  mutation = if operation.start_with?('add')
    participant(
      name: 'relationship-add',
      actor: ids[:admin],
      delay: mutate_delay,
      expression: "public.add_horse_relationship('#{ids[:horse]}', '#{ids[:admin_member]}', 'trainer', '__REQUEST_ID__')"
    )
  else
    participant(
      name: 'relationship-end',
      actor: ids[:admin],
      delay: mutate_delay,
      expression: "public.end_horse_relationship('#{ids[:relationship]}', 1, '__REQUEST_ID__', current_date)"
    )
  end
  archive = participant(
    name: 'archive',
    actor: ids[:owner],
    delay: archive_delay,
    expression: "public.archive_horse('#{ids[:horse]}', '__REQUEST_ID__', '4C2B race archive')"
  )
  [ids, [mutation, archive], lambda do |outcomes, values|
    change, archived = outcomes
    require_success!(archived, 'archive')
    if change[:kind] == :success
      expected = operation.start_with?('add') ? '2' : 'ended'
      actual = operation.start_with?('add') ? values[6] : values[3]
      raise 'Committed relationship mutation missing' unless actual == expected
    else
      require_error!(
        change,
        'relationship mutation',
        '42501',
        operation.start_with?('add') ? 'HORSE_UNAVAILABLE' : 'RELATIONSHIP_UNAVAILABLE'
      )
    end
    raise 'Horse was not archived' unless values[0] == 'archived'
  end]
end

builders = {
  'identifier-update-revoke-update-first' => -> { scenario_identifier_revoke(psql, :update_first) },
  'identifier-update-revoke-revoke-first' => -> { scenario_identifier_revoke(psql, :revoke_first) },
  'identifier-update-update' => -> { scenario_identifier_update_update(psql) },
  'relationship-add-suspend-add-first' => -> { scenario_relationship_suspend(psql, :add_first) },
  'relationship-add-suspend-suspend-first' => -> { scenario_relationship_suspend(psql, :suspend_first) },
  'relationship-add-archive-add-first' => -> { scenario_relationship_archive(psql, 'add_first') },
  'relationship-add-archive-archive-first' => -> { scenario_relationship_archive(psql, 'add_archive_first') },
  'relationship-end-archive-end-first' => -> { scenario_relationship_archive(psql, 'end_first') },
  'relationship-end-archive-archive-first' => -> { scenario_relationship_archive(psql, 'end_archive_first') }
}

passed = 0
iterations.times do |iteration|
  builders.each do |name, builder|
    ids, participants, validator = builder.call
    outcomes = race(psql, participants).map { |result| classify(result) }
    values = state(psql, ids)
    validator.call(outcomes, values)
    puts "#{name} iteration=#{iteration + 1}: #{outcomes.map { |value| value[:kind] }.join('/')}" unless quiet
    passed += 1
  end
end

puts(
  "SUMMARY: #{passed}/#{iterations * builders.length} 4C.2B races passed; " \
  "participants=#{passed * 2}/#{iterations * builders.length * 2}"
)
