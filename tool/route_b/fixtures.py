"""Real local signup, mail confirmation, login and public RPC fixture creation."""
import datetime as dt
import html
import re
import secrets
import time
import urllib.parse
import uuid
from zoneinfo import ZoneInfo


def seed(engine, cfg):
    path = cfg['state'] / 'fixtures.json'
    if path.exists():
        import json
        f = json.loads(path.read_text())
        if f['target'] != cfg['target'] or f['api_url'] != cfg['api_url']:
            raise ValueError('Fixture target mismatch.')
    else:
        f = {'target': cfg['target'], 'api_url': cfg['api_url'],
             'anon_key': cfg['anon_key'], 'preview_origin': cfg['preview_url'],
             'users': {}, 'organizations': {}, 'horses': {}, 'tasks': {},
             'memberships': {}, 'grants': {}, 'planning': {}, 'feeding': {}}
    def save(): engine.private_json(path, f)
    def uid(): return str(uuid.uuid4())
    def request(method, route, body=None, token=None, mail=False):
        return engine.request(cfg, method, route, body, token, mail)
    def rpc(actor, name, body):
        return request('POST', '/rest/v1/rpc/' + name, body, f['users'][actor]['access_token'])
    for role in ['admin_a', 'admin_b', 'trainer', 'rider', 'groom', 'outsider']:
        if role not in f['users']:
            f['users'][role] = {'email': role.replace('_', '-') + '@' + cfg['target'] + '.invalid',
                                'password': secrets.token_urlsafe(24)}
            save()
        user = f['users'][role]
        if not user.get('user_id'):
            signed = request('POST', '/auth/v1/signup', {k: user[k] for k in ['email','password']})
            assert not signed.get('access_token'), 'Email confirmation must be required.'
            user['user_id'] = (signed.get('user') or signed)['id']; save()
        if not user.get('mail_confirmed'):
            matching = []
            for _ in range(40):
                messages = request('GET', '/api/v1/messages', mail=True).get('messages', [])
                matching = [m for m in messages if any(x['Address'] == user['email'] for x in m['To'])]
                if matching: break
                time.sleep(.5)
            assert matching, 'Confirmation mail absent for fixture label ' + role
            detail = request('GET', '/api/v1/message/' + matching[0]['ID'], mail=True)
            content = html.unescape(detail.get('Text','') + '\n' + detail.get('HTML',''))
            links = re.findall(re.escape(cfg['api_url']) + r'/(?:auth/v1/)?verify\?[^\s"<>]+', content)
            assert links, 'Local confirmation link absent.'
            query = urllib.parse.parse_qs(urllib.parse.urlparse(links[0]).query)
            confirmed = request('POST','/auth/v1/verify',{'token_hash':query['token'][0],'type':query['type'][0]})
            assert confirmed.get('user',{}).get('email_confirmed_at')
            user['mail_confirmed'] = True; save()
        session = request('POST','/auth/v1/token?grant_type=password',{k:user[k] for k in ['email','password']})
        assert session['user']['id'] == user['user_id']
        user.update(access_token=session['access_token'],refresh_token=session['refresh_token']);save()
        profile = rpc(role,'get_current_account_profile',{})[0]
        user['profile_id'] = profile['profile_id'];save()
        if not profile.get('onboarding_completed_at'):
            rpc(role,'update_current_account_profile',{
                'p_expected_row_version':profile['row_version'],'p_first_name':'Lokaal',
                'p_last_name':role.replace('_',' '),'p_phone_e164':None,'p_locale':'nl',
                'p_time_zone':'Europe/Amsterdam','p_theme_mode':'light',
                'p_onboarding_intent':'createStable','p_complete_onboarding':True,
                'p_avatar_object_path':None,'p_correlation_id':uid()})
        print('Confirmed real Auth fixture: '+role,flush=True)
    for label in ['a','b']:
        actor='admin_'+label
        if label not in f['organizations']:
            f['organizations'][label]=rpc(actor,'create_c010_stable',{'p_name':'AVARYN Stal '+label.upper(),
                'p_location_name':'Lokale acceptatie '+label.upper(),'p_request_id':uid()});save()
        org=f['organizations'][label]['organization_id']
        for role in (['trainer','rider','groom'] if label=='a' else ['trainer']):
            key=label+'_'+role
            if key not in f['memberships']:
                invitation=rpc(actor,'create_c010_stable_invitation',{'p_organization_id':org,
                    'p_role_code':role,'p_target_email':f['users'][role]['email'],
                    'p_expires_at':(dt.datetime.now(dt.timezone.utc)+dt.timedelta(days=7)).isoformat(),'p_request_id':uid()})[0]
                f['memberships'][key]={'invitation_token':invitation['invitation_token']};save()
            membership=f['memberships'][key]
            if not membership.get('accepted'):
                result=rpc(role,'respond_stable_invitation',{'p_invitation_token':membership['invitation_token'],
                    'p_action':'accept','p_correlation_id':uid()})[0]
                assert result['status']=='accepted'
                membership.update(accepted=True,membership_id=result['membership_id']);save()
    for label,orglabel,display in [('a','a','Orion'),('a_extra','a','Nova'),('b','b','Atlas')]:
        actor='admin_'+orglabel
        if label not in f['horses']:
            body={k:None for k in ['p_official_name','p_birth_date','p_breed','p_discipline','p_level','p_color','p_notes','p_chip_number','p_passport_number','p_passport_valid_until']}
            body.update(p_display_name=display,p_sex='unknown',p_correlation_id=uid())
            f['horses'][label]=rpc(actor,'create_canonical_horse_profile',body)[0];save()
        horse=f['horses'][label]
        if not horse.get('residency_set'):
            rpc(actor,'set_c010_horse_residency',{'p_horse_id':horse['horse_id'],
                'p_stable_organization_id':f['organizations'][orglabel]['organization_id'],
                'p_expected_residency_row_version':None,'p_request_id':uid()})
            horse['residency_set']=True;save()
        roles=['trainer','rider','groom'] if label=='a' else (['trainer'] if label=='b' else [])
        for role in roles:
            key=label+'_'+role
            if key not in f['grants']:
                perms=['horse.view']
                if role in ['trainer','rider']:perms+=['horse.planning.manage']
                if role=='groom':perms+=['horse.feeding.manage']
                f['grants'][key]=rpc(actor,'set_c010_horse_collaborator',{
                    'p_horse_id':horse['horse_id'],'p_profile_id':f['users'][role]['profile_id'],
                    'p_relationship_type_code':role,'p_permission_codes':perms,'p_active':True,'p_request_id':uid()});save()
    amsterdam=ZoneInfo('Europe/Amsterdam')
    local_day=dt.datetime.now(amsterdam).date()
    today=local_day.isoformat()
    for key,orglabel,horsekey,assignee,title in [
        ('water_a','a','a','groom','Water controleren Orion'),
        ('personal_rider','a','a','rider','Orion poetsen'),
        ('horse_hidden','a','a_extra','admin_a','Nova hooi controleren'),
        ('stable_a','a',None,'groom','Gang vegen'),
        ('water_b','b','b','admin_b','Water controleren Atlas')]:
        if key not in f['tasks']:
            f['tasks'][key]=rpc('admin_'+orglabel,'upsert_c010_stable_task',{
                'p_organization_id':f['organizations'][orglabel]['organization_id'],'p_task_id':None,
                'p_expected_row_version':None,'p_title':title,'p_note':'Synthetische lokale acceptatie',
                'p_category':'water','p_due_date':today,'p_due_time':'17:00',
                'p_assignee_profile_id':f['users'][assignee]['profile_id'],'p_location_text':'Weide',
                'p_stable_place_id':None,'p_horse_id':f['horses'][horsekey]['horse_id'] if horsekey else None,'p_request_id':uid()});save()
    for label in ['a','b']:
        hid=f['horses'][label]['horse_id'];actor='admin_'+label
        if label not in f['planning']:
            f['planning'][label]=rpc(actor,'upsert_c010_horse_schedule_item',{
                'p_horse_id':hid,'p_schedule_item_id':None,'p_expected_row_version':None,'p_item_kind':'training',
                'p_title':'Training '+('Orion' if label=='a' else 'Atlas'),'p_instruction':'Lokale acceptatie',
                'p_priority':'normal','p_scheduled_start_at':dt.datetime.combine(local_day,dt.time(14),amsterdam).isoformat(),
                'p_scheduled_end_at':dt.datetime.combine(local_day,dt.time(15),amsterdam).isoformat(),'p_source_timezone':'Europe/Amsterdam',
                'p_state':'planned','p_state_reason':None,'p_participant_profile_ids':[f['users']['trainer']['profile_id']],
                'p_request_id':uid()});save()
        if label not in f['feeding']:
            f['feeding'][label]=rpc(actor,'save_c010_horse_feeding_round',{
                'p_horse_id':hid,'p_plan_type':'standard','p_feeding_plan_id':None,'p_expected_plan_row_version':None,
                'p_round_code':'morning','p_effective_from':today,'p_effective_until':None,
                'p_products':[{'product_type':'roughage','description':'Hooi','quantity':2,'unit_code':'kg'}],
                'p_request_id':uid()});save()
    f['complete']=True;save()
    print('Fixtures ready: six confirmed accounts, two stables, three horses, explicit memberships/grants.',flush=True)
    return f
