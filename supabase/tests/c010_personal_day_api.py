#!/usr/bin/env python3
"""Personal-day RPC integration against one explicit, disposable local target.

Real password login and ordinary authorized RPC writes only. This deliberately
creates synthetic fixtures; never run against the live pilot/preview target.
No Auth administration, SQL writes, reset, or container lifecycle operations.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime as dt
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from zoneinfo import ZoneInfo

from c010_task_visibility_api import LocalHttpError


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True)
    parser.add_argument('--fixture-file', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    fixture = json.loads(args.fixture_file.read_text())
    # Explicit test-target naming is an additional guard against the live A.
    if not args.target.startswith('avaryn-c010-product-day-') or fixture.get('target') != args.target or args.fixture_file.parent.name != args.target:
        parser.error('an explicit isolated personal-day test target is required')
    endpoint = urllib.parse.urlsplit(fixture['api_url'])
    if endpoint.scheme != 'http' or endpoint.hostname != '127.0.0.1' or not endpoint.port or endpoint.username or endpoint.password:
        parser.error('only explicit loopback API endpoints are accepted')
    users = fixture['users']
    if any(not row['email'].endswith('@' + args.target + '.invalid') for row in users.values()):
        parser.error('only this target\'s synthetic accounts are accepted')
    results = []
    provenance = {'target': args.target, 'organizations': [], 'horses': [], 'tasks': [], 'activities': []}
    fresh = lambda: str(uuid.uuid4())

    def request(actor, method, path, body=None):
        headers = {'apikey': fixture['anon_key'], 'Content-Type': 'application/json'}
        if actor:
            headers['Authorization'] = 'Bearer ' + users[actor]['access_token']
        req = urllib.request.Request(fixture['api_url'] + path, method=method, headers=headers,
                                     data=json.dumps(body).encode() if body is not None else None)
        try:
            with urllib.request.urlopen(req, timeout=8) as response:
                return json.loads(response.read() or b'null')
        except urllib.error.HTTPError as error:
            try:
                payload = json.loads(error.read())
            except ValueError:
                payload = {}
            raise LocalHttpError(error.code, payload) from None

    def rpc(actor, name, body):
        return request(actor, 'POST', '/rest/v1/rpc/' + name, body)

    def check(condition, label):
        results.append({'case': label, 'result': 'PASS' if condition else 'FAIL'})
        if not condition:
            raise AssertionError(label)

    def refused(actor, name, body, code, message=None):
        try:
            rpc(actor, name, body)
        except LocalHttpError as error:
            return error.status == code and (message is None or error.message == message)
        return False

    def day(actor, selected):
        value = rpc(actor, 'get_c010_personal_day', {'p_on_date': selected})
        return value, {item['source_id']: item for item in value['items']}

    error = None
    try:
        for actor, user in users.items():
            login = request(None, 'POST', '/auth/v1/token?grant_type=password',
                            {'email': user['email'], 'password': user['password']})
            check(login['user']['id'] == user['user_id'], 'real Auth identity: ' + actor)
            user['access_token'] = login['access_token']
        check(refused(None, 'get_c010_personal_day', {}, 401), 'anonymous personal day refused')
        calendar = rpc('groom', 'get_c010_calendar_context', {})
        on_date = calendar['today_date']
        tomorrow = (dt.date.fromisoformat(on_date) + dt.timedelta(days=1)).isoformat()
        for admin in ('admin_a', 'admin_b'):
            organization = rpc(admin, 'create_c010_stable', {'p_name': 'Personal day HTTP ' + admin,
                'p_location_name': 'Disposable test', 'p_request_id': fresh()})['organization_id']
            provenance['organizations'].append({'actor': admin, 'id': organization})
            invitation = rpc(admin, 'create_c010_stable_invitation', {
                'p_organization_id': organization, 'p_role_code': 'groom', 'p_target_email': users['groom']['email'],
                'p_expires_at': (dt.datetime.now(dt.timezone.utc)+dt.timedelta(days=2)).isoformat(), 'p_request_id': fresh()})[0]
            accepted = rpc('groom', 'respond_stable_invitation', {'p_invitation_token': invitation['invitation_token'],
                'p_action': 'accept', 'p_correlation_id': fresh()})[0]
            provenance['organizations'][-1]['membership_id'] = accepted['membership_id']
            task = rpc(admin, 'upsert_c010_stable_task', {'p_organization_id': organization,
                'p_task_id': None, 'p_expected_row_version': None, 'p_title': 'Personal day HTTP task',
                'p_note': 'Read the water instruction before completing.', 'p_category': 'water',
                'p_due_date': on_date, 'p_due_time': None, 'p_assignee_profile_id': users['groom']['profile_id'],
                'p_location_text': 'Water trough', 'p_stable_place_id': None, 'p_horse_id': None, 'p_request_id': fresh()})
            provenance['tasks'].append(task['task_id'])
        horse_body = {name: None for name in ('p_official_name','p_birth_date','p_breed','p_discipline','p_level','p_color','p_notes','p_chip_number','p_passport_number','p_passport_valid_until')}
        horse_body.update(p_display_name='Personal day HTTP personal horse',p_sex='unknown',p_correlation_id=fresh())
        horse = rpc('trainer','create_canonical_horse_profile',horse_body)[0]['horse_id']
        provenance['horses'].append(horse)
        grants = {}
        for actor, permissions in [('groom',['horse.view','horse.planning.manage']),('rider',['horse.view']),('outsider',['horse.view'])]:
            for permission in permissions:
                grant = rpc('trainer','grant_horse_profile_permission',{'p_horse_id':horse,
                    'p_grantee_profile_id':users[actor]['profile_id'],'p_permission_code':permission,'p_relationship_id':None,
                    'p_valid_from':None,'p_valid_until':None,'p_reason_code':'MANUAL_GRANT','p_correlation_id':fresh()})[0]
                grants[(actor,permission)] = grant
        start = dt.datetime.combine(dt.date.fromisoformat(on_date),dt.time(14),ZoneInfo('Europe/Amsterdam'))
        def activity(day_offset=0):
            begins = start + dt.timedelta(days=day_offset)
            saved = rpc('trainer','upsert_c010_horse_schedule_item',{'p_horse_id':horse,'p_schedule_item_id':None,
                'p_expected_row_version':None,'p_item_kind':'training','p_title':'Personal day HTTP training',
                'p_instruction':'Synthetische registratie: rustig uitstappen.','p_priority':'high',
                'p_scheduled_start_at':begins.astimezone(dt.timezone.utc).isoformat(),
                'p_scheduled_end_at':(begins+dt.timedelta(hours=1)).astimezone(dt.timezone.utc).isoformat(),
                'p_source_timezone':'Europe/Amsterdam','p_state':'planned','p_state_reason':None,
                'p_participant_profile_ids':[users[a]['profile_id'] for a in ('trainer','groom','rider')], 'p_request_id':fresh()})
            provenance['activities'].append(saved['schedule_item_id'])
            return saved['schedule_item_id']
        item, future_item = activity(), activity(1)
        projection, rows = day('groom',on_date)
        check(set(provenance['tasks']).issubset(rows), 'real API personal tasks from two stables')
        check(projection['on_date']==on_date and projection['time_zone']=='Europe/Amsterdam', 'selected day and explicit calendar contract')
        check(rows[item]['organization_id'] is None and rows[item]['can_complete'], 'personal training needs no stable and preserves manage permission')
        check(rows[item]['instruction']=='Synthetische registratie: rustig uitstappen.', 'actual activity instruction delivered')
        check(all(rows[t]['scheduled_start_at'] is None and rows[t]['due_time'] is None for t in provenance['tasks']), 'no invented time for date-only tasks')
        check(future_item not in rows and future_item in day('groom',tomorrow)[1], 'tomorrow activity comes from same source')
        check(len(projection['items'])==len({(r['source_type'],r['source_id']) for r in projection['items']}), 'no duplicate canonical source records')
        check(item not in day('outsider',on_date)[1], 'general view without participation excluded')
        check(item not in day('admin_a',on_date)[1], 'unrelated manager cannot read personal training')
        check(day('rider',on_date)[1][item]['can_complete'] is False, 'participant read-only capability truthful')
        command = {'p_schedule_item_id':item,'p_expected_row_version':1,'p_request_id':fresh()}
        check(refused('rider','complete_c010_personal_activity',command,403,'HORSE_PLANNING_PERMISSION_REQUIRED'), 'view-only real HTTP complete denied')
        before = request('trainer','GET','/rest/v1/schedule_items?select=id,title,instruction,priority,scheduled_start_at,scheduled_end_at,source_timezone,state,row_version&id=eq.'+item)[0]
        stale = {**command,'p_expected_row_version':99,'p_request_id':fresh()}
        began = time.monotonic()
        check(refused('groom','complete_c010_personal_activity',stale,409,'STALE_SCHEDULE_VERSION'), 'actual PostgREST stale version returns409')
        check(time.monotonic()-began<5, 'stale conflict is bounded without database retry loop')
        check(day('groom',on_date)[1][item]['status']=='planned', 'conflict caused no completion')
        with ThreadPoolExecutor(max_workers=2) as pool:
            replies = list(pool.map(lambda _:rpc('groom','complete_c010_personal_activity',command),range(2)))
        check(all(r['row_version']==2 and r['state']=='completed' for r in replies) and {r['idempotent'] for r in replies}=={False,True}, 'concurrent same request completes once and replays once')
        after = request('trainer','GET','/rest/v1/schedule_items?select=id,title,instruction,priority,scheduled_start_at,scheduled_end_at,source_timezone,state,row_version&id=eq.'+item)[0]
        check({k:v for k,v in before.items() if k not in ('state','row_version')}=={k:v for k,v in after.items() if k not in ('state','row_version')}, 'HTTP completion preserves activity fields and UTC interval')
        check(day('groom',on_date)[1][item]['status']=='completed' and not day('groom',on_date)[1][item]['can_complete'], 'real completion remains visible as completed')
        a = provenance['organizations'][0]
        rpc('groom','transition_c010_stable_task',{'p_organization_id':a['id'],'p_task_id':provenance['tasks'][0],
            'p_expected_row_version':1,'p_action':'complete','p_request_id':fresh()})
        check(day('groom',on_date)[1][provenance['tasks'][0]]['status']=='completed', 'existing task completion remains visible in personal day')
        rpc('admin_a','revoke_c010_membership',{'p_organization_id':a['id'],'p_membership_id':a['membership_id'],
            'p_expected_row_version':1,'p_request_id':fresh()})
        rows = day('groom',on_date)[1]
        check(provenance['tasks'][0] not in rows and provenance['tasks'][1] in rows and item in rows, 'membership revoke removes only its stable tasks; independent personal activity retained')
        for permission in ('horse.planning.manage','horse.view'):
            grant = grants[('groom',permission)]
            rpc('trainer','transition_horse_profile_permission_grant',{'p_grant_id':grant['grant_id'],
                'p_expected_row_version':grant['row_version'],'p_action':'revoke','p_reason_code':'TEST_REVOKED','p_correlation_id':fresh()})
            expected = 'HORSE_PLANNING_PERMISSION_REQUIRED' if permission.endswith('manage') else 'HORSE_SCHEDULE_UNAVAILABLE'
            check(refused('groom','complete_c010_personal_activity',command,403,expected), 'receipt requires current '+permission)
        check(item not in day('groom',on_date)[1], 'revoked horse read permission hides terminal item')
        check(day('rider',on_date)[1][item]['status']=='completed', 'other participant still sees authoritative completed state')
    except Exception as exc:
        error = type(exc).__name__ + ': ' + str(exc)
    private_file = args.fixture_file.parent/'personal-day-api-owned-fixtures.json'
    private_file.write_text(json.dumps(provenance,indent=2)+'\n'); private_file.chmod(0o600)
    summary={'target':args.target,'result':'PASS' if error is None and all(r['result']=='PASS' for r in results) else 'FAIL',
        'pass':sum(r['result']=='PASS' for r in results),'fail':sum(r['result']=='FAIL' for r in results),
        'error':error,'cases':results,'fixture_policy':'new synthetic domain fixtures in isolated target only; retained with private provenance'}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k!='cases'}))
    return 0 if summary['result']=='PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
