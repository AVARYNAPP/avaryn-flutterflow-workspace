require 'open3'
require 'securerandom'
require 'set'
require 'timeout'

container = 'supabase_db_avaryn-flutterflow-workspace'
scenario_filter = nil
start_order_filter = nil
iterations = 1
quiet = false
race_timeout = 10
arguments = ARGV.dup
until arguments.empty?
  argument = arguments.shift
  case argument
  when '--scenario'
    scenario_filter = Integer(arguments.shift)
  when '--start-order'
    start_order_filter = arguments.shift
  when '--iterations'
    iterations = Integer(arguments.shift)
  when '--timeout'
    race_timeout = Integer(arguments.shift)
  when '--quiet'
    quiet = true
  else
    container = argument
  end
end
raise 'iterations must be positive' unless iterations.positive?
raise 'timeout must be positive' unless race_timeout.positive?
raise 'scenario must be between 1 and 6' if scenario_filter && !(1..6).cover?(scenario_filter)
if start_order_filter
  valid_start_orders = {
    3 => %w[transfer-first leave-first],
    6 => %w[accept-first decline-first],
  }
  unless valid_start_orders.fetch(scenario_filter, []).include?(start_order_filter)
    raise 'start order does not match the selected scenario'
  end
end

psql = [
  'docker',
  'exec',
  '-i',
  container,
  'psql',
  '-X',
  '-A',
  '-t',
  '-q',
  '-U',
  'postgres',
  '-d',
  'postgres',
  '-v',
  'ON_ERROR_STOP=1',
]

def sql!(psql, source)
  stdout, stderr, status = Open3.capture3(*psql, stdin_data: source)
  return stdout if status.success?

  raise "Local SQL failed: #{stderr.lines.last.to_s.strip}"
end

def fixture_ids(index)
  suffix = format('%012x', index)
  {
    stable: "bc000000-0000-0000-0000-#{suffix}",
    other_stable: "bc100000-0000-0000-0000-#{suffix}",
    owner: "ac000000-0000-0000-0001-#{suffix}",
    admin: "ac000000-0000-0000-0002-#{suffix}",
    member: "ac000000-0000-0000-0003-#{suffix}",
    other_owner: "ac000000-0000-0000-0004-#{suffix}",
    invitee: "ac000000-0000-0000-0005-#{suffix}",
    owner_member: "dc000000-0000-0000-0001-#{suffix}",
    admin_member: "dc000000-0000-0000-0002-#{suffix}",
    member_member: "dc000000-0000-0000-0003-#{suffix}",
    other_owner_member: "dc000000-0000-0000-0004-#{suffix}",
    owner_membership: "ec000000-0000-0000-0001-#{suffix}",
    admin_membership: "ec000000-0000-0000-0002-#{suffix}",
    member_membership: "ec000000-0000-0000-0003-#{suffix}",
    other_owner_membership: "ec000000-0000-0000-0004-#{suffix}",
    invitation: "fc000000-0000-0000-0001-#{suffix}",
    invitation_token_hash_hex: SecureRandom.hex(32),
  }
end

def create_fixture(psql, index)
  ids = fixture_ids(index)
  sql!(
    psql,
    <<~SQL,
      begin;
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
      )
      values
        ('00000000-0000-0000-0000-000000000000', '#{ids[:owner]}', 'authenticated', 'authenticated', 'race-owner-#{index}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:admin]}', 'authenticated', 'authenticated', 'race-admin-#{index}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:member]}', 'authenticated', 'authenticated', 'race-member-#{index}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:other_owner]}', 'authenticated', 'authenticated', 'race-other-owner-#{index}@example.invalid', '', now(), '{}', '{}', now(), now()),
        ('00000000-0000-0000-0000-000000000000', '#{ids[:invitee]}', 'authenticated', 'authenticated', 'race-invitee-#{index}@example.invalid', '', now(), '{}', '{}', now(), now());
      insert into public.stables (
        id, kind, name, status, timezone, locale,
        created_by_user_id, creation_request_id
      ) values (
        '#{ids[:stable]}', 'organization', 'Race stable #{index}', 'active',
        'UTC', 'nl', '#{ids[:owner]}', gen_random_uuid()
      ), (
        '#{ids[:other_stable]}', 'organization', 'Other race stable #{index}',
        'active', 'UTC', 'nl', '#{ids[:other_owner]}', gen_random_uuid()
      );
      insert into public.stable_members (
        id, stable_id, display_name, source
      ) values
        ('#{ids[:owner_member]}', '#{ids[:stable]}', 'Race owner', 'owner_creation'),
        ('#{ids[:admin_member]}', '#{ids[:stable]}', 'Race admin', 'manual'),
        ('#{ids[:member_member]}', '#{ids[:stable]}', 'Race member', 'manual'),
        ('#{ids[:other_owner_member]}', '#{ids[:other_stable]}', 'Other owner', 'owner_creation');
      insert into public.stable_memberships (
        id, stable_id, user_id, stable_member_id, role, status, joined_at
      ) values
        ('#{ids[:owner_membership]}', '#{ids[:stable]}', '#{ids[:owner]}', '#{ids[:owner_member]}', 'owner', 'active', now()),
        ('#{ids[:admin_membership]}', '#{ids[:stable]}', '#{ids[:admin]}', '#{ids[:admin_member]}', 'admin', 'active', now()),
        ('#{ids[:member_membership]}', '#{ids[:stable]}', '#{ids[:member]}', '#{ids[:member_member]}', 'member', 'active', now()),
        ('#{ids[:other_owner_membership]}', '#{ids[:other_stable]}', '#{ids[:other_owner]}', '#{ids[:other_owner_member]}', 'owner', 'active', now());
      insert into public.stable_invitations (
        id, stable_id, invited_email, offered_role, token_hash, status,
        expires_at, invited_by_membership_id
      ) values (
        '#{ids[:invitation]}', '#{ids[:stable]}',
        'race-invitee-#{index}@example.invalid', 'member',
        decode('#{ids[:invitation_token_hash_hex]}', 'hex'), 'pending',
        now() + interval '1 day', '#{ids[:owner_membership]}'
      );
      commit;
    SQL
  )
  ids
end

def participant(
  name:,
  actor:,
  event_type:,
  subject_membership:,
  expression:,
  allowed_failures: [],
  allowed_idempotent_values: [],
  delay_seconds: 0.05
)
  {
    name: name,
    actor: actor,
    event_type: event_type,
    subject_membership: subject_membership,
    expression: expression,
    request_id: SecureRandom.uuid,
    allowed_failures: allowed_failures,
    allowed_idempotent_values: allowed_idempotent_values,
    delay_seconds: delay_seconds,
  }
end

def participant_sql(entry)
  expression = entry.fetch(:expression).sub(
    '__REQUEST_ID__',
    entry.fetch(:request_id),
  )
  <<~SQL
    \\set VERBOSITY verbose
    begin;
    set local role authenticated;
    select set_config('request.jwt.claim.role', 'authenticated', true);
    select set_config('request.jwt.claim.sub', '#{entry.fetch(:actor)}', true);
    select pg_sleep(#{entry.fetch(:delay_seconds)});
    select 'RACE_RESULT|#{entry.fetch(:name)}|#{entry.fetch(:request_id)}|' ||
      (#{expression})::text;
    commit;
  SQL
end

def capture_with_timeout(command, stdin_data, timeout_seconds)
  Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
    stdin.write(stdin_data)
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
    [stdout_reader.value, stderr_reader.value, status, timed_out]
  end
end

def run_race(psql, label, participants, timeout_seconds:)
  ready = Queue.new
  start = Queue.new
  threads = participants.map do |entry|
    Thread.new do
      ready << true
      start.pop
      begin
        stdout, stderr, status, timed_out = capture_with_timeout(
          psql,
          participant_sql(entry),
          timeout_seconds,
        )
        {
          participant: entry,
          stdout: stdout,
          stderr: stderr,
          status: status,
          timed_out: timed_out,
        }
      rescue StandardError => error
        {
          participant: entry,
          stdout: '',
          stderr: '',
          status: nil,
          timed_out: false,
          exception: "#{error.class}: #{error.message}",
        }
      end
    end
  end
  participants.length.times { ready.pop }
  participants.length.times { start << true }
  results = threads.map(&:value)
  raise "#{label}: race returned no participants" if results.empty?

  results.each do |result|
    if result.fetch(:timed_out)
      result[:classification] = 'timeout'
      result[:sqlstate] = 'TIMEOUT'
      result[:error_code] = "exceeded_#{timeout_seconds}s"
    elsif result[:exception]
      result[:classification] = 'unknown_exception'
      result[:sqlstate] = 'EXCEPTION'
      result[:error_code] = result.fetch(:exception)
    elsif result.fetch(:status).success?
      marker = result.fetch(:stdout).lines
        .map(&:strip)
        .find { |line| line.start_with?('RACE_RESULT|') }
      if marker.nil?
        result[:classification] = 'unknown_response'
        result[:sqlstate] = 'NO_MARKER'
        result[:error_code] = 'successful participant returned no marker'
      else
        fields = marker.split('|', 4)
        result[:classification] = 'success'
        result[:return_value] = fields.fetch(3)
      end
    else
      match = result.fetch(:stderr).match(
        /ERROR:\s+([0-9A-Z]{5}):\s*([^\r\n]+)/,
      )
      if match.nil?
        result[:classification] = 'unknown_error'
        result[:sqlstate] = 'UNPARSEABLE'
        result[:error_code] = result.fetch(:stderr).strip
      else
        result[:classification] = 'database_error'
        result[:sqlstate] = match[1]
        result[:error_code] = match[2].strip
      end
    end
  end
  results
end

def event_rows(psql, request_ids)
  quoted = request_ids.map { |value| "'#{value}'::uuid" }.join(',')
  output = sql!(
    psql,
    <<~SQL,
      select request_id, event_type, stable_id, actor_user_id,
        coalesce(subject_membership_id::text, '')
      from public.stable_security_events
      where request_id = any(array[#{quoted}])
      order by request_id, id;
    SQL
  )
  output.lines.each_with_object([]) do |line, rows|
    values = line.strip.split('|', -1)
    next unless values.length == 5

    rows << {
      request_id: values[0],
      event_type: values[1],
      stable_id: values[2],
      actor_user_id: values[3],
      subject_membership_id: values[4],
    }
  end
end

def validate_participants(label, ids, results, events)
  errors = []
  results.each do |result|
    entry = result.fetch(:participant)
    participant_events = events.select do |event|
      event.fetch(:request_id) == entry.fetch(:request_id)
    end
    if result.fetch(:classification) == 'success'
      if participant_events.empty?
        value = result.fetch(:return_value)
        unless entry.fetch(:allowed_idempotent_values).include?(value)
          errors << "#{label}: #{entry.fetch(:name)} had uncorrelated success #{value}"
        end
        result[:outcome] = "idempotent:#{value}"
      else
        unless participant_events.length == 1
          errors << "#{label}: #{entry.fetch(:name)} wrote multiple events"
        end
        event = participant_events.first
        expected_subject = entry.fetch(:subject_membership)
        subject_matches = if expected_subject == :any_nonempty
                            event && !event.fetch(:subject_membership_id).empty?
                          else
                            event &&
                              event.fetch(:subject_membership_id) ==
                                expected_subject
                          end
        if event && !(event.fetch(:event_type) == entry.fetch(:event_type) &&
            event.fetch(:stable_id) == ids.fetch(:stable) &&
            event.fetch(:actor_user_id) == entry.fetch(:actor) &&
            subject_matches)
          errors << "#{label}: #{entry.fetch(:name)} event correlation mismatch"
        end
        unless result.fetch(:return_value) == 'true'
          errors << "#{label}: committed mutation did not return true"
        end
        result[:outcome] = "committed:#{event&.fetch(:event_type, 'unknown')}"
      end
    elsif result.fetch(:classification) == 'database_error'
      unless participant_events.empty?
        errors << "#{label}: rolled-back participant left a success event"
      end
      failure = [
        result.fetch(:sqlstate),
        result.fetch(:error_code),
      ]
      unless entry.fetch(:allowed_failures).include?(failure)
        errors << "#{label}: #{entry.fetch(:name)} returned unknown failure #{failure.join(':')}"
      end
      result[:outcome] = "controlled_error:#{failure.join(':')}"
    else
      unless participant_events.empty?
        errors << "#{label}: unknown participant outcome left an event"
      end
      result[:outcome] = [
        result.fetch(:classification),
        result.fetch(:sqlstate),
        result.fetch(:error_code),
      ].join(':')
      errors << "#{label}: #{entry.fetch(:name)} #{result.fetch(:outcome)}"
    end
  end
  errors
end

def terminal_state(psql, ids)
  output = sql!(
    psql,
    <<~SQL,
      select
        (select id::text from public.stable_memberships
          where stable_id = '#{ids[:stable]}'
            and role = 'owner' and status = 'active'),
        (select count(*) from public.stable_memberships
          where stable_id = '#{ids[:stable]}'
            and role = 'owner' and status = 'active'),
        (select role from public.stable_memberships
          where id = '#{ids[:owner_membership]}'),
        (select status from public.stable_memberships
          where id = '#{ids[:owner_membership]}'),
        (select (ended_at is not null)::int from public.stable_memberships
          where id = '#{ids[:owner_membership]}'),
        (select role from public.stable_memberships
          where id = '#{ids[:admin_membership]}'),
        (select status from public.stable_memberships
          where id = '#{ids[:admin_membership]}'),
        (select (ended_at is not null)::int from public.stable_memberships
          where id = '#{ids[:admin_membership]}'),
        (select role from public.stable_memberships
          where id = '#{ids[:member_membership]}'),
        (select status from public.stable_memberships
          where id = '#{ids[:member_membership]}'),
        (select (ended_at is not null)::int from public.stable_memberships
          where id = '#{ids[:member_membership]}'),
        (select status from public.stable_invitations
          where id = '#{ids[:invitation]}'),
        (select coalesce(invitee_user_id::text, '') from public.stable_invitations
          where id = '#{ids[:invitation]}'),
        (select coalesce(accepted_membership_id::text, '') from public.stable_invitations
          where id = '#{ids[:invitation]}'),
        (select (accepted_at is not null)::int from public.stable_invitations
          where id = '#{ids[:invitation]}'),
        (select (declined_at is not null)::int from public.stable_invitations
          where id = '#{ids[:invitation]}'),
        (select count(*) from public.stable_memberships
          where stable_id = '#{ids[:stable]}'
            and user_id = '#{ids[:invitee]}'
            and status = 'active'),
        (select count(*) from public.stable_memberships m
          join public.stable_invitations i on i.accepted_membership_id = m.id
          where i.id = '#{ids[:invitation]}'
            and m.source_invitation_id = i.id
            and m.stable_member_id is not null),
        (select count(*) from (
          select stable_member_id
          from public.stable_memberships
          where stable_id = '#{ids[:stable]}'
            and stable_member_id is not null
          group by stable_member_id having count(*) > 1
        ) duplicate_links),
        (select count(*) from public.stable_memberships m
          join public.stable_members sm on sm.id = m.stable_member_id
          where m.stable_id <> sm.stable_id),
        (select count(*) from public.stable_memberships
          where (status = 'active' and ended_at is not null)
             or (status <> 'active' and ended_at is null)),
        (select count(*) from public.stable_memberships
          where stable_id = '#{ids[:other_stable]}'
            and id = '#{ids[:other_owner_membership]}'
            and user_id = '#{ids[:other_owner]}'
            and stable_member_id = '#{ids[:other_owner_member]}'
            and role = 'owner' and status = 'active'),
        (select count(*) from public.stables
          where id = '#{ids[:other_stable]}'
            and name like 'Other race stable %'
            and status = 'active');
    SQL
  )
  keys = %i[
    active_owner_membership active_owner_count
    owner_role owner_status owner_ended
    admin_role admin_status admin_ended
    member_role member_status member_ended
    invitation_status invitation_user invitation_membership
    invitation_accepted invitation_declined invitee_active_memberships
    invitation_source_links duplicate_links cross_stable_links
    invalid_lifecycle control_owner_count control_stable_count
  ]
  values = output.lines.first.to_s.strip.split('|', -1)
  unless values.length == keys.length
    raise "terminal-state query returned #{values.length}/#{keys.length} values"
  end

  keys.zip(values).to_h
end

def participant_contract(outcome, sqlstate, events)
  {
    outcome: outcome,
    sqlstate: sqlstate,
    events: events,
    event_count: events.length,
  }
end

def terminal_contract(
  ids,
  active_owner_membership:,
  owner: %w[owner active 0],
  admin: %w[admin active 0],
  member: %w[member active 0],
  invitation: :pending
)
  invitation_values = case invitation
                      when :pending
                        ['pending', '', '', '0', '0', '0', '0']
                      when :accepted
                        ['accepted', ids.fetch(:invitee), :nonempty, '1', '0', '1', '1']
                      when :declined
                        ['declined', ids.fetch(:invitee), '', '0', '1', '0', '0']
                      else
                        raise "unknown invitation terminal state #{invitation}"
                      end
  {
    active_owner_membership: active_owner_membership,
    active_owner_count: '1',
    owner_role: owner.fetch(0),
    owner_status: owner.fetch(1),
    owner_ended: owner.fetch(2),
    admin_role: admin.fetch(0),
    admin_status: admin.fetch(1),
    admin_ended: admin.fetch(2),
    member_role: member.fetch(0),
    member_status: member.fetch(1),
    member_ended: member.fetch(2),
    invitation_status: invitation_values.fetch(0),
    invitation_user: invitation_values.fetch(1),
    invitation_membership: invitation_values.fetch(2),
    invitation_accepted: invitation_values.fetch(3),
    invitation_declined: invitation_values.fetch(4),
    invitee_active_memberships: invitation_values.fetch(5),
    invitation_source_links: invitation_values.fetch(6),
    duplicate_links: '0',
    cross_stable_links: '0',
    invalid_lifecycle: '0',
    control_owner_count: '1',
    control_stable_count: '1',
  }
end

def value_matches?(expected, actual)
  expected == :nonempty ? !actual.empty? : expected == actual
end

def validate_outcome_signature!(
  psql,
  label,
  ids,
  results,
  events,
  allowed_signatures
)
  request_ids = results.map do |result|
    result.fetch(:participant).fetch(:request_id)
  end
  raise "#{label}: participant request IDs are not unique" unless request_ids.uniq == request_ids

  actual_participants = results.each_with_object({}) do |result, entries|
    participant = result.fetch(:participant)
    participant_events = events.select do |event|
      event.fetch(:request_id) == participant.fetch(:request_id)
    end
    entries[participant.fetch(:name)] = {
      outcome: result.fetch(:outcome),
      sqlstate: result.fetch(:sqlstate, 'none'),
      request_id: participant.fetch(:request_id),
      events: participant_events.map { |event| event.fetch(:event_type) },
      event_count: participant_events.length,
    }
  end
  actual_state = terminal_state(psql, ids)

  matching_signature = allowed_signatures.find do |signature|
    expected_participants = signature.fetch(:participants).each_with_object({}) do |(name, contract), entries|
      result = results.find do |candidate|
        candidate.fetch(:participant).fetch(:name) == name
      end
      entries[name] = contract.merge(
        request_id: result&.fetch(:participant)&.fetch(:request_id),
      )
    end
    participants_match = expected_participants == actual_participants
    state_matches = signature.fetch(:state).all? do |key, expected|
      value_matches?(expected, actual_state.fetch(key))
    end
    participants_match && state_matches
  end

  unless matching_signature
    raise(
      "#{label}: no complete serial outcome matched; " \
      "participants=#{actual_participants.inspect}; state=#{actual_state.inspect}",
    )
  end

  results.each do |result|
    outcome = result.fetch(:outcome)
    result[:contract_status] = if outcome.start_with?('committed:')
                                 'committed'
                               elsif outcome.start_with?('controlled_error:')
                                 'rejected'
                               else
                                 'idempotent'
                               end
  end
  matching_signature.fetch(:name)
end

def report_participants(label, results, events)
  results.each do |result|
    entry = result.fetch(:participant)
    participant_events = events.select do |event|
      event.fetch(:request_id) == entry.fetch(:request_id)
    end
    response = result[:return_value] || result[:error_code] || ''
    puts(
      "RESULT: scenario=#{label} participant=#{entry.fetch(:name)} " \
      "request=#{entry.fetch(:request_id)} " \
      "classification=#{result.fetch(:classification)} " \
      "contract_status=#{result.fetch(:contract_status, 'unvalidated')} " \
      "outcome=#{result.fetch(:outcome, 'unvalidated')} " \
      "sqlstate=#{result.fetch(:sqlstate, 'none')} response=#{response.inspect} " \
      "expected_event=#{entry.fetch(:event_type)} " \
      "actual_events=#{participant_events.map { |event| event.fetch(:event_type) }.inspect} " \
      "event_count=#{participant_events.length}",
    )
  end
end

def build_scenario(psql, number, start_order: nil)
  ids = create_fixture(psql, SecureRandom.random_number(0xfffffffffffe) + 1)
  case number
  when 1
    {
      label: 'two concurrent ownership transfers',
      ids: ids,
      participants: [
        participant(
          name: 'transfer-admin',
          actor: ids[:owner],
          event_type: 'ownership_transferred',
          subject_membership: ids[:admin_membership],
          allowed_failures: [['42501', 'OWNER_REQUIRED']],
          expression:
            "public.transfer_stable_ownership('#{ids[:stable]}', " \
            "'#{ids[:admin_membership]}', '__REQUEST_ID__')",
        ),
        participant(
          name: 'transfer-member',
          actor: ids[:owner],
          event_type: 'ownership_transferred',
          subject_membership: ids[:member_membership],
          allowed_failures: [['42501', 'OWNER_REQUIRED']],
          expression:
            "public.transfer_stable_ownership('#{ids[:stable]}', " \
            "'#{ids[:member_membership]}', '__REQUEST_ID__')",
        ),
      ],
      contract_kind: :mutually_exclusive,
      allowed_signatures: [
        {
          name: 'transfer-admin committed; transfer-member rejected',
          participants: {
            'transfer-admin' => participant_contract(
              'committed:ownership_transferred',
              'none',
              ['ownership_transferred'],
            ),
            'transfer-member' => participant_contract(
              'controlled_error:42501:OWNER_REQUIRED',
              '42501',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:admin_membership],
            owner: %w[admin active 0],
            admin: %w[owner active 0],
          ),
        },
        {
          name: 'transfer-member committed; transfer-admin rejected',
          participants: {
            'transfer-admin' => participant_contract(
              'controlled_error:42501:OWNER_REQUIRED',
              '42501',
              [],
            ),
            'transfer-member' => participant_contract(
              'committed:ownership_transferred',
              'none',
              ['ownership_transferred'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:member_membership],
            owner: %w[admin active 0],
            member: %w[owner active 0],
          ),
        },
      ],
    }
  when 2
    {
      label: 'ownership transfer versus target removal',
      ids: ids,
      participants: [
        participant(
          name: 'transfer-target',
          actor: ids[:owner],
          event_type: 'ownership_transferred',
          subject_membership: ids[:admin_membership],
          allowed_failures: [['22023', 'INVALID_TRANSFER_TARGET']],
          expression:
            "public.transfer_stable_ownership('#{ids[:stable]}', " \
            "'#{ids[:admin_membership]}', '__REQUEST_ID__')",
        ),
        participant(
          name: 'remove-target',
          actor: ids[:owner],
          event_type: 'membership_removed',
          subject_membership: ids[:admin_membership],
          allowed_failures: [['42501', 'REMOVE_NOT_ALLOWED']],
          expression:
            "public.remove_stable_membership('#{ids[:admin_membership]}', " \
            "'__REQUEST_ID__')",
        ),
      ],
      contract_kind: :mutually_exclusive,
      allowed_signatures: [
        {
          name: 'transfer committed; removal rejected',
          participants: {
            'transfer-target' => participant_contract(
              'committed:ownership_transferred',
              'none',
              ['ownership_transferred'],
            ),
            'remove-target' => participant_contract(
              'controlled_error:42501:REMOVE_NOT_ALLOWED',
              '42501',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:admin_membership],
            owner: %w[admin active 0],
            admin: %w[owner active 0],
          ),
        },
        {
          name: 'removal committed; transfer rejected',
          participants: {
            'transfer-target' => participant_contract(
              'controlled_error:22023:INVALID_TRANSFER_TARGET',
              '22023',
              [],
            ),
            'remove-target' => participant_contract(
              'committed:membership_removed',
              'none',
              ['membership_removed'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            admin: %w[admin removed 1],
          ),
        },
      ],
    }
  when 3
    raise 'scenario 3 requires a start order' if start_order.nil?

    transfer_delay = start_order == 'transfer-first' ? 0.0 : 0.2
    leave_delay = start_order == 'leave-first' ? 0.0 : 0.2
    {
      label: "ownership transfer versus current owner leave (#{start_order})",
      ids: ids,
      participants: [
        participant(
          name: 'transfer-admin',
          actor: ids[:owner],
          event_type: 'ownership_transferred',
          subject_membership: ids[:admin_membership],
          delay_seconds: transfer_delay,
          expression:
            "public.transfer_stable_ownership('#{ids[:stable]}', " \
            "'#{ids[:admin_membership]}', '__REQUEST_ID__')",
        ),
        participant(
          name: 'owner-leave',
          actor: ids[:owner],
          event_type: 'membership_left',
          subject_membership: ids[:owner_membership],
          allowed_failures: [['42501', 'OWNER_MUST_TRANSFER_FIRST']],
          delay_seconds: leave_delay,
          expression:
            "public.leave_stable('#{ids[:stable]}', '__REQUEST_ID__')",
        ),
      ],
      contract_kind: :serially_combinable,
      allowed_signatures: [
        {
          name: 'leave rejected before transfer; transfer committed',
          participants: {
            'transfer-admin' => participant_contract(
              'committed:ownership_transferred',
              'none',
              ['ownership_transferred'],
            ),
            'owner-leave' => participant_contract(
              'controlled_error:42501:OWNER_MUST_TRANSFER_FIRST',
              '42501',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:admin_membership],
            owner: %w[admin active 0],
            admin: %w[owner active 0],
          ),
        },
        {
          name: 'transfer committed; former owner leave committed',
          participants: {
            'transfer-admin' => participant_contract(
              'committed:ownership_transferred',
              'none',
              ['ownership_transferred'],
            ),
            'owner-leave' => participant_contract(
              'committed:membership_left',
              'none',
              ['membership_left'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:admin_membership],
            owner: %w[admin left 1],
            admin: %w[owner active 0],
          ),
        },
      ],
    }
  when 4
    {
      label: 'remove versus leave on the same member',
      ids: ids,
      participants: [
        participant(
          name: 'owner-remove',
          actor: ids[:owner],
          event_type: 'membership_removed',
          subject_membership: ids[:member_membership],
          allowed_failures: [['22023', 'MEMBERSHIP_NOT_REMOVABLE']],
          expression:
            "public.remove_stable_membership('#{ids[:member_membership]}', " \
            "'__REQUEST_ID__')",
        ),
        participant(
          name: 'member-leave',
          actor: ids[:member],
          event_type: 'membership_left',
          subject_membership: ids[:member_membership],
          allowed_idempotent_values: ['false'],
          expression:
            "public.leave_stable('#{ids[:stable]}', '__REQUEST_ID__')",
        ),
      ],
      contract_kind: :mutually_exclusive,
      allowed_signatures: [
        {
          name: 'removal committed; leave idempotent',
          participants: {
            'owner-remove' => participant_contract(
              'committed:membership_removed',
              'none',
              ['membership_removed'],
            ),
            'member-leave' => participant_contract(
              'idempotent:false',
              'none',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            member: %w[member removed 1],
          ),
        },
        {
          name: 'leave committed; removal rejected',
          participants: {
            'owner-remove' => participant_contract(
              'controlled_error:22023:MEMBERSHIP_NOT_REMOVABLE',
              '22023',
              [],
            ),
            'member-leave' => participant_contract(
              'committed:membership_left',
              'none',
              ['membership_left'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            member: %w[member left 1],
          ),
        },
      ],
    }
  when 5
    {
      label: 'two concurrent remove attempts',
      ids: ids,
      participants: [
        participant(
          name: 'remove-first',
          actor: ids[:owner],
          event_type: 'membership_removed',
          subject_membership: ids[:member_membership],
          allowed_idempotent_values: ['true'],
          expression:
            "public.remove_stable_membership('#{ids[:member_membership]}', " \
            "'__REQUEST_ID__')",
        ),
        participant(
          name: 'remove-second',
          actor: ids[:owner],
          event_type: 'membership_removed',
          subject_membership: ids[:member_membership],
          allowed_idempotent_values: ['true'],
          expression:
            "public.remove_stable_membership('#{ids[:member_membership]}', " \
            "'__REQUEST_ID__')",
        ),
      ],
      contract_kind: :mutually_exclusive,
      allowed_signatures: [
        {
          name: 'first removal committed; second idempotent',
          participants: {
            'remove-first' => participant_contract(
              'committed:membership_removed',
              'none',
              ['membership_removed'],
            ),
            'remove-second' => participant_contract(
              'idempotent:true',
              'none',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            member: %w[member removed 1],
          ),
        },
        {
          name: 'second removal committed; first idempotent',
          participants: {
            'remove-first' => participant_contract(
              'idempotent:true',
              'none',
              [],
            ),
            'remove-second' => participant_contract(
              'committed:membership_removed',
              'none',
              ['membership_removed'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            member: %w[member removed 1],
          ),
        },
      ],
    }
  when 6
    raise 'scenario 6 requires a start order' if start_order.nil?

    accept_delay = start_order == 'accept-first' ? 0.0 : 0.2
    decline_delay = start_order == 'decline-first' ? 0.0 : 0.2
    {
      label: "invitation accept versus decline (#{start_order})",
      ids: ids,
      participants: [
        participant(
          name: 'accept-invitation',
          actor: ids[:invitee],
          event_type: 'invitation_accepted',
          subject_membership: :any_nonempty,
          allowed_failures: [['42501', 'INVITATION_UNAVAILABLE']],
          delay_seconds: accept_delay,
          expression:
            "((public.accept_stable_invitation(" \
            "'#{ids[:invitation_token_hash_hex]}', 'Race invitee', null, " \
            "'__REQUEST_ID__'))->>'idempotent' = 'false')",
        ),
        participant(
          name: 'decline-invitation',
          actor: ids[:invitee],
          event_type: 'invitation_declined',
          subject_membership: '',
          allowed_failures: [['42501', 'INVITATION_UNAVAILABLE']],
          delay_seconds: decline_delay,
          expression:
            "public.decline_stable_invitation(" \
            "'#{ids[:invitation_token_hash_hex]}', '__REQUEST_ID__')",
        ),
      ],
      contract_kind: :mutually_exclusive,
      allowed_signatures: [
        {
          name: 'accept committed; decline rejected',
          participants: {
            'accept-invitation' => participant_contract(
              'committed:invitation_accepted',
              'none',
              ['invitation_accepted'],
            ),
            'decline-invitation' => participant_contract(
              'controlled_error:42501:INVITATION_UNAVAILABLE',
              '42501',
              [],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            invitation: :accepted,
          ),
        },
        {
          name: 'decline committed; accept rejected',
          participants: {
            'accept-invitation' => participant_contract(
              'controlled_error:42501:INVITATION_UNAVAILABLE',
              '42501',
              [],
            ),
            'decline-invitation' => participant_contract(
              'committed:invitation_declined',
              'none',
              ['invitation_declined'],
            ),
          },
          state: terminal_contract(
            ids,
            active_owner_membership: ids[:owner_membership],
            invitation: :declined,
          ),
        },
      ],
    }
  else
    raise "Unknown scenario #{number}"
  end
end

scenario_numbers = scenario_filter ? [scenario_filter] : (1..6).to_a
scenario_specs = scenario_numbers.flat_map do |number|
  if number == 3
    orders = start_order_filter ? [start_order_filter] :
      %w[transfer-first leave-first]
    orders.map { |order| [number, order] }
  elsif number == 6
    orders = start_order_filter ? [start_order_filter] :
      %w[accept-first decline-first]
    orders.map { |order| [number, order] }
  else
    [[number, nil]]
  end
end
passed_scenarios = 0
seen_request_ids = Set.new
seen_invitation_ids = Set.new
iterations.times do |iteration|
  scenario_specs.each do |number, start_order|
    scenario = build_scenario(psql, number, start_order: start_order)
    label = "#{scenario.fetch(:label)} iteration=#{iteration + 1}"
    invitation_id = scenario.fetch(:ids).fetch(:invitation)
    unless seen_invitation_ids.add?(invitation_id)
      raise "#{label}: invitation ID was reused"
    end
    requests = scenario.fetch(:participants).map { |entry| entry.fetch(:request_id) }
    requests.each do |request_id|
      raise "#{label}: request ID was reused" unless seen_request_ids.add?(request_id)
    end
    results = run_race(
      psql,
      label,
      scenario.fetch(:participants),
      timeout_seconds: race_timeout,
    )
    events = event_rows(psql, requests)
    errors = validate_participants(
      label,
      scenario.fetch(:ids),
      results,
      events,
    )
    begin
      matched_signature = validate_outcome_signature!(
        psql,
        label,
        scenario.fetch(:ids),
        results,
        events,
        scenario.fetch(:allowed_signatures),
      )
    rescue StandardError => error
      errors << error.message
    end
    report_participants(label, results, events) if !quiet || !errors.empty?
    unless quiet
      puts(
        "CONTRACT: scenario=#{label} kind=#{scenario.fetch(:contract_kind)} " \
        "matched=#{matched_signature.inspect}",
      )
    end
    raise errors.join("\n") unless errors.empty?

    passed_scenarios += 1
  end
end

puts(
  "SUMMARY: #{passed_scenarios}/#{iterations * scenario_specs.length} " \
  "correlated multi-connection races passed; participants=" \
  "#{passed_scenarios * 2}/#{iterations * scenario_specs.length * 2}",
)
