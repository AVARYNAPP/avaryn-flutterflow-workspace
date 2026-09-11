#!/usr/bin/env python3
"""Real authenticated HTTP regressions against an explicitly owned test backend.

Each run creates and retires two private synthetic matrix stables through the
normal public RPCs. Existing browser-fixture organizations are not modified.
Only labels/counts/statuses enter the result artifact. No admin DB connection.
The optional HTTPS transport can only forward to that same owned local backend.
"""
import argparse
import datetime
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from zoneinfo import ZoneInfo


class LocalHttpError(RuntimeError):
    def __init__(self, status, payload):
        self.status = status
        self.code = payload.get('code', payload.get('error_code', 'unknown'))
        self.message = payload.get('message', '')
        super().__init__('HTTP %s code %s' % (status, self.code))


def parse_instant(value):
    # PostgreSQL emits 0-6 fractional digits. Python 3.9 fromisoformat accepts
    # only some widths; zero-padding preserves the exact server instant.
    normalized = value[:-1] + '+00:00' if value.endswith('Z') else value
    normalized = re.sub(r'(\.\d{1,5})(?=[+-]\d{2}:\d{2}$)',
                        lambda match: match.group(1).ljust(7, '0'), normalized)
    instant = datetime.datetime.fromisoformat(normalized)
    if instant.tzinfo is None:
        raise ValueError('Server calendar timestamp must include a timezone')
    return instant


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', required=True)
    parser.add_argument('--fixture-file', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preview-transport-config', type=Path,
                        help='Explicit authenticated HTTPS transport to the same owned local backend')
    args = parser.parse_args()
    fixture = json.loads(args.fixture_file.read_text())
    if not re.fullmatch(r'avaryn-[a-z0-9-]+', args.target):
        parser.error('an explicit AVARYN local target is required')
    if fixture.get('target') != args.target or args.fixture_file.parent.name != args.target:
        parser.error('fixture/target mismatch')
    url = urllib.parse.urlsplit(fixture['api_url'])
    if url.scheme != 'http' or url.hostname not in ('127.0.0.1', '::1') or not url.port or url.username or url.password:
        parser.error('only an explicit loopback API is allowed')
    users = fixture['users']
    transport_url = fixture['api_url']
    transport_headers = {}
    if args.preview_transport_config:
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'tool/route_b'))
        from preview_transport import read_transport
        transport_url, transport_headers = read_transport(
            args.preview_transport_config, fixture, args.target)
    results = []
    organizations = []

    def request(actor, method, path, body=None, timeout=30):
        headers = {'apikey': fixture['anon_key'], 'Content-Type': 'application/json',
                   **transport_headers}
        if actor:
            headers['Authorization'] = 'Bearer ' + users[actor]['access_token']
        req = urllib.request.Request(transport_url + path, method=method,
                                     headers=headers, data=json.dumps(body).encode() if body is not None else None)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                return json.loads(response.read() or b'null')
        except urllib.error.HTTPError as error:
            try:
                payload = json.loads(error.read())
            except ValueError:
                payload = {}
            # Do not retain response data or token-bearing request URLs.
            raise LocalHttpError(error.code, payload) from None

    def rpc(actor, name, body, timeout=30):
        return request(actor, 'POST', '/rest/v1/rpc/' + name, body, timeout)

    def check(condition, label):
        results.append({'case': label, 'result': 'PASS' if condition else 'FAIL'})
        if not condition:
            raise AssertionError(label)

    def fresh_id():
        return str(uuid.uuid4())

    if args.preview_transport_config:
        # Fresh real Auth sessions stay in memory. Never persist hosted login
        # credentials or response tokens in the result or fixture artifact.
        for user in users.values():
            if not user['email'].endswith('@' + args.target + '.invalid'):
                raise ValueError('Hosted test transport only accepts this run’s synthetic accounts')
            session = request(None, 'POST', '/auth/v1/token?grant_type=password',
                              {key:user[key] for key in ('email','password')})
            if session.get('user', {}).get('id') != user['user_id']:
                raise ValueError('Hosted Auth account identity mismatch')
            user['access_token'] = session['access_token']

    def invite(admin, organization, actor, role):
        invitation = rpc(admin, 'create_c010_stable_invitation', {
            'p_organization_id': organization, 'p_role_code': role,
            'p_target_email': users[actor]['email'],
            'p_expires_at': (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=2)).isoformat(),
            'p_request_id': fresh_id()})
        if isinstance(invitation, list):
            invitation = invitation[0]
        return rpc(actor, 'respond_stable_invitation', {
            'p_invitation_token': invitation['invitation_token'], 'p_action': 'accept', 'p_correlation_id': fresh_id()})

    def task_rows(actor, organization):
        return request(actor, 'GET', '/rest/v1/stable_tasks?select=id,status&organization_id=eq.' + organization)

    error = None
    try:
        # Obtain real user sessions again, rather than trusting fixture JWT age.
        for actor in users:
            session = request(None, 'POST', '/auth/v1/token?grant_type=password',
                              {'email': users[actor]['email'], 'password': users[actor]['password']})
            users[actor]['access_token'] = session['access_token']
        check(True, 'six real password sessions')
        for admin in ('admin_a', 'admin_b'):
            name = 'C010 security matrix ' + admin
            stable = rpc(admin, 'create_c010_stable', {'p_name': name, 'p_location_name': 'Disposable', 'p_request_id': fresh_id()})
            organizations.append((admin, stable['organization_id'], name))
        a, b = organizations[0][1], organizations[1][1]
        for actor, role in [('trainer', 'trainer'), ('rider', 'rider'), ('groom', 'groom')]:
            invite('admin_a', a, actor, role)
        invite('admin_b', b, 'trainer', 'trainer')
        horse_args = {key: None for key in ('p_official_name', 'p_birth_date', 'p_breed', 'p_discipline', 'p_level', 'p_color', 'p_notes', 'p_chip_number', 'p_passport_number', 'p_passport_valid_until')}
        horse_args.update(p_display_name='C010 visibility horse', p_sex='unknown', p_correlation_id=fresh_id())
        horse = rpc('trainer', 'create_canonical_horse_profile', horse_args)[0]['horse_id']
        rpc('trainer', 'set_c010_horse_residency', {'p_horse_id': horse, 'p_stable_organization_id': a, 'p_expected_residency_row_version': None, 'p_request_id': fresh_id()})

        def collaborator(actor, enabled):
            rpc('trainer', 'set_c010_horse_collaborator', {
                'p_horse_id': horse, 'p_profile_id': users[actor]['profile_id'],
                'p_relationship_type_code': 'groom' if actor == 'groom' else 'trainer',
                'p_permission_codes': ['horse.view'] if enabled else [],
                'p_active': enabled, 'p_request_id': fresh_id()})

        collaborator('admin_a', True)
        collaborator('groom', True)
        today = datetime.datetime.now(ZoneInfo('Europe/Amsterdam')).date()
        tasks = []
        for linked in (False, True):
            for history in (False, True):
                saved = rpc('admin_a', 'upsert_c010_stable_task', {
                    'p_organization_id': a, 'p_task_id': None, 'p_expected_row_version': None,
                    'p_title': 'C010 API visibility', 'p_note': 'Synthetic confidential task detail',
                    'p_category': 'other', 'p_due_date': today.isoformat(), 'p_due_time': None,
                    'p_assignee_profile_id': users['groom']['profile_id'], 'p_location_text': None,
                    'p_stable_place_id': None, 'p_horse_id': horse if linked else None, 'p_request_id': fresh_id()})
                task = {'id': saved['task_id'], 'linked': linked, 'history': history, 'request_id': fresh_id()}
                if history:
                    rpc('groom', 'transition_c010_stable_task', {'p_organization_id': a, 'p_task_id': task['id'],
                        'p_expected_row_version': 1, 'p_action': 'complete', 'p_request_id': task['request_id']})
                tasks.append(task)
        start = datetime.datetime.combine(today, datetime.time(), ZoneInfo('Europe/Amsterdam')).isoformat()
        end = datetime.datetime.combine(today + datetime.timedelta(days=1), datetime.time(), ZoneInfo('Europe/Amsterdam')).isoformat()

        def visibility(actor, member, horse_access, label):
            expected = {t['id'] for t in tasks if member and (not t['linked'] or horse_access)}
            rows = task_rows(actor, a)
            check({row['id'] for row in rows} == expected, label + ': direct tasks open/history')
            events = request(actor, 'GET', '/rest/v1/stable_task_events?select=task_id,event_type&organization_id=eq.' + a)
            check({row['task_id'] for row in events} == expected and len(events) == sum(2 if t['history'] else 1 for t in tasks if t['id'] in expected), label + ': direct events')
            if member:
                activities = rpc(actor, 'list_c010_stable_activities', {'p_organization_id': a, 'p_from': start, 'p_through': end, 'p_scope': 'all'})
                check({row['activity_id'] for row in activities if row['activity_kind'] == 'stable_task'} == expected, label + ': public activity RPC')
            else:
                try:
                    rpc(actor, 'get_c010_stable_round1_workspace', {'p_organization_id': a, 'p_on_date': today.isoformat(), 'p_scope': 'all'})
                except RuntimeError as denied:
                    check('42501' in str(denied), label + ': workspace denied')
                else:
                    check(False, label + ': workspace denied')
            mine = rpc(actor, 'list_c010_personal_today', {'p_on_date': today.isoformat()})
            observed = {row['task_id'] for row in mine if row['organization_id'] == a}
            expected_mine = {t['id'] for t in tasks if t['id'] in expected and not t['history']} if actor == 'groom' else set()
            check(observed == expected_mine, label + ': own Today only')

        for actor, member, access in [('groom', True, True), ('admin_a', True, True), ('trainer', True, True), ('rider', True, False), ('outsider', False, False), ('admin_b', False, False)]:
            visibility(actor, member, access, actor + ' initial')
        for actor in ('rider', 'outsider', 'admin_b'):
            rpc('trainer', 'grant_horse_profile_permission', {'p_horse_id': horse,
                'p_grantee_profile_id': users[actor]['profile_id'], 'p_permission_code': 'horse.view',
                'p_relationship_id': None, 'p_valid_from': None, 'p_valid_until': None,
                'p_reason_code': 'MANUAL_GRANT', 'p_correlation_id': fresh_id()})
            visibility(actor, actor == 'rider', True, actor + ' explicit horse grant')
        collaborator('groom', False)
        collaborator('admin_a', False)
        visibility('groom', True, False, 'assignee horse grant revoked')
        visibility('admin_a', True, False, 'admin horse grant revoked')
        for task in [t for t in tasks if t['linked']]:
            try:
                rpc('groom', 'transition_c010_stable_task', {'p_organization_id': a, 'p_task_id': task['id'],
                    'p_expected_row_version': 1, 'p_action': 'complete', 'p_request_id': task['request_id']})
            except RuntimeError as denied:
                check('42501' in str(denied), 'revoked horse denies ' + ('receipt replay' if task['history'] else 'completion'))
            else:
                check(False, 'revoked horse denies mutation/receipt')
        linked_open = next(t for t in tasks if t['linked'] and not t['history'])
        try:
            rpc('admin_a', 'upsert_c010_stable_task', {
                'p_organization_id': a, 'p_task_id': linked_open['id'], 'p_expected_row_version': 1,
                'p_title': 'Unauthorized blind relink', 'p_note': None, 'p_category': 'other',
                'p_due_date': today.isoformat(), 'p_due_time': None,
                'p_assignee_profile_id': users['groom']['profile_id'], 'p_location_text': None,
                'p_stable_place_id': None, 'p_horse_id': None, 'p_request_id': fresh_id()})
        except RuntimeError as denied:
            check('42501' in str(denied), 'revoked admin horse denies blind task relink')
        else:
            check(False, 'revoked admin horse denies blind task relink')
        for actor in ('groom', 'rider'):
            membership = request('admin_a', 'GET', '/rest/v1/organization_memberships?select=id,row_version&organization_id=eq.' + a + '&profile_id=eq.' + users[actor]['profile_id'])[0]
            rpc('admin_a', 'revoke_c010_membership', {'p_organization_id': a, 'p_membership_id': membership['id'], 'p_expected_row_version': membership['row_version'], 'p_request_id': fresh_id()})
            visibility(actor, False, actor == 'rider', actor + ' membership revoked')
        # Calendar checks also cross the real authenticated HTTP boundary.
        calendar = rpc('trainer', 'get_c010_calendar_context', {})
        server_now = parse_instant(calendar['server_now'])
        server_day = datetime.date.fromisoformat(calendar['today_date'])
        next_day = parse_instant(calendar['next_day_at'])
        zone = ZoneInfo('Europe/Amsterdam')
        check(calendar['time_zone'] == 'Europe/Amsterdam' and
              server_now.astimezone(zone).date() == server_day and
              next_day == datetime.datetime.combine(server_day + datetime.timedelta(days=1), datetime.time(), zone),
              'HTTP server calendar contract')
        # Match the client _load chain: this older workspace RPC requires a
        # non-null date even though the newer round1 RPC accepts its omission.
        # The date comes from the server calendar, never the host clock.
        for planning_scope in ('all', 'mine'):
            stable_workspace = rpc('trainer', 'get_c010_stable_workspace', {
                'p_organization_id': a,
                'p_from': (server_now - datetime.timedelta(days=30)).isoformat(),
                'p_through': (server_now + datetime.timedelta(days=330)).isoformat(),
                'p_on_date': calendar['today_date'],
                'p_planning_scope': planning_scope,
            })
            check(stable_workspace['organization']['id'] == a and
                  stable_workspace['capabilities']['organization.view'] is True and
                  all(isinstance(stable_workspace[key], list) for key in ('horses', 'planning', 'feeding')),
                  'HTTP client workspace accepts explicit server calendar date ' + planning_scope)
        def create_date_task(admin, organization, actor, date, title):
            return rpc(admin, 'upsert_c010_stable_task', {
                'p_organization_id': organization, 'p_task_id': None, 'p_expected_row_version': None,
                'p_title': title, 'p_note': None, 'p_category': 'other', 'p_due_date': date.isoformat(),
                'p_due_time': None, 'p_assignee_profile_id': users[actor]['profile_id'],
                'p_location_text': None, 'p_stable_place_id': None, 'p_horse_id': None,
                'p_request_id': fresh_id()})['task_id']
        for day in map(datetime.date.fromisoformat, ('2026-01-01', '2026-03-29', '2026-10-25', '2026-12-31', '2028-02-29')):
            boundary_tasks = {create_date_task('admin_a', a, 'admin_a', day + datetime.timedelta(days=offset),
                                              'HTTP calendar boundary'): offset for offset in (-1, 0, 1)}
            rows = rpc('admin_a', 'list_c010_stable_activities', {
                'p_organization_id': a, 'p_from': datetime.datetime.combine(day, datetime.time(), zone).isoformat(),
                'p_through': datetime.datetime.combine(day + datetime.timedelta(days=1), datetime.time(), zone).isoformat(),
                'p_scope': 'all'})
            observed = [row for row in rows if row['activity_id'] in boundary_tasks]
            check(len(observed) == 1 and boundary_tasks[observed[0]['activity_id']] == 0 and
                  observed[0]['scheduled_at'] is None and observed[0]['due_date'] == day.isoformat(),
                  'HTTP half-open date-only calendar ' + day.isoformat())
        shared = {create_date_task(admin, organization, 'trainer', server_day, 'HTTP multi-stable Today')
                  for admin, organization in (('admin_a', a), ('admin_b', b))}
        mine = rpc('trainer', 'list_c010_personal_today', {'p_on_date': None})
        shared_rows = [row for row in mine if row['task_id'] in shared]
        check({row['task_id'] for row in shared_rows} == shared and
              {row['organization_id'] for row in shared_rows} == {a, b},
              'HTTP default server Today spans both memberships')
        check(all(row['can_complete'] is False for row in shared_rows),
              'HTTP read-only trainer receives no completion authority')
        workspace = rpc('trainer', 'get_c010_stable_round1_workspace', {'p_organization_id': a})
        check(workspace['on_date'] == calendar['today_date'] and workspace['time_zone'] == calendar['time_zone'],
              'HTTP default workspace shares server calendar')
        # Real REST must return business CAS promptly. 40001 would cause the
        # transaction layer to retry the same stale input until gateway timeout.
        cas_body = {
            'p_organization_id': a, 'p_task_id': None, 'p_expected_row_version': None,
            'p_title': 'HTTP CAS regression', 'p_note': 'v1', 'p_category': 'other',
            'p_due_date': server_day.isoformat(), 'p_due_time': None,
            'p_assignee_profile_id': users['admin_a']['profile_id'],
            'p_location_text': None, 'p_stable_place_id': None, 'p_horse_id': None,
            'p_request_id': fresh_id(),
        }
        created = rpc('admin_a', 'upsert_c010_stable_task', cas_body)
        cas_id = created['task_id']
        cas_body.update(p_task_id=cas_id, p_expected_row_version=1, p_note='v2', p_request_id=fresh_id())
        advanced = rpc('admin_a', 'upsert_c010_stable_task', cas_body)
        check(advanced['row_version'] == 2, 'HTTP CAS setup advances version')
        transition = {'p_organization_id': a, 'p_task_id': cas_id,
                      'p_expected_row_version': 1, 'p_action': 'complete', 'p_request_id': fresh_id()}
        stale_edit = dict(cas_body, p_note='stale overwrite', p_request_id=fresh_id())
        for operation, name, body in [('complete', 'transition_c010_stable_task', transition),
                                      ('edit', 'upsert_c010_stable_task', stale_edit)]:
            for attempt in (1, 2):
                started = time.monotonic()
                try:
                    rpc('admin_a', name, body, timeout=5)
                except LocalHttpError as conflict:
                    check(conflict.status == 409 and conflict.code == 'PT409' and
                          conflict.message == 'STALE_TASK_VERSION' and time.monotonic() - started < 5,
                          'HTTP stale ' + operation + ' attempt ' + str(attempt) + ' returns bounded409')
                else:
                    check(False, 'HTTP stale ' + operation + ' unexpectedly succeeded')
        current = request('admin_a', 'GET', '/rest/v1/stable_tasks?select=status,row_version,note&id=eq.' + cas_id)[0]
        events = request('admin_a', 'GET', '/rest/v1/stable_task_events?select=event_type&task_id=eq.' + cas_id)
        check(current == {'status': 'open', 'row_version': 2, 'note': 'v2'} and
              sorted(event['event_type'] for event in events) == ['created', 'updated'],
              'HTTP stale retries preserve task and event history')
        transition.update(p_expected_row_version=2, p_request_id=fresh_id())
        completed = rpc('admin_a', 'transition_c010_stable_task', transition, timeout=5)
        replayed = rpc('admin_a', 'transition_c010_stable_task', transition, timeout=5)
        events = request('admin_a', 'GET', '/rest/v1/stable_task_events?select=event_type&task_id=eq.' + cas_id)
        check(completed['status'] == 'completed' and completed['row_version'] == 3 and
              replayed['status'] == 'completed' and replayed['row_version'] == 3 and replayed['idempotent'] is True and
              sum(event['event_type'] == 'completed' for event in events) == 1,
              'HTTP current completion and receipt replay produce one event')

    except (AssertionError, RuntimeError, KeyError, ValueError, OSError) as failure:
        error = str(failure)[:220]
    finally:
        # Retire just this run's two matrix organizations, preserving records and
        # leaving all pre-existing preview organizations/memberships untouched.
        for admin, organization, name in organizations:
            try:
                row = request(admin, 'GET', '/rest/v1/organizations?select=row_version&id=eq.' + organization)[0]
                rpc(admin, 'retire_c010_stable', {'p_organization_id': organization, 'p_expected_row_version': row['row_version'], 'p_confirmed_name': name, 'p_request_id': fresh_id()})
            except Exception:
                results.append({'case': 'retire own matrix organization', 'result': 'FAIL'})
                error = error or 'Own synthetic matrix retirement failed'
        summary = {'target': args.target, 'test': 'real authenticated task visibility API',
                   'transport': 'protected_https_tunnel' if args.preview_transport_config else 'loopback',
                   'pass': sum(r['result'] == 'PASS' for r in results),
                   'fail': sum(r['result'] == 'FAIL' for r in results), 'cases': results,
                   'result': 'FAIL' if error else 'PASS', 'error': error}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(summary, indent=2))
        print(json.dumps({key: summary[key] for key in ('test', 'pass', 'fail', 'result', 'error')}))
    return 1 if error else 0


if __name__ == '__main__':
    raise SystemExit(main())
