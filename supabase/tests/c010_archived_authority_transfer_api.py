#!/usr/bin/env python3
"""Real Auth/HTTP archive succession; only an isolated personal-day test target."""
import argparse
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from c010_task_visibility_api import LocalHttpError


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target',required=True)
    parser.add_argument('--fixture-file',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();fixture=json.loads(args.fixture_file.read_text())
    endpoint=urllib.parse.urlsplit(fixture['api_url'])
    if not args.target.startswith('avaryn-c010-product-day-') or fixture.get('target')!=args.target or args.fixture_file.parent.name!=args.target:
        parser.error('isolated target/fixture identity mismatch')
    if endpoint.scheme!='http' or endpoint.hostname!='127.0.0.1' or not endpoint.port or endpoint.username or endpoint.password:
        parser.error('explicit loopback endpoint required')
    users=fixture['users'];results=[];owned={};fresh=lambda:str(uuid.uuid4())
    if any(not u['email'].endswith('@'+args.target+'.invalid') for u in users.values()):parser.error('non-synthetic account refused')
    def req(actor,path,body):
        headers={'apikey':fixture['anon_key'],'Content-Type':'application/json'}
        if actor:headers['Authorization']='Bearer '+users[actor]['access_token']
        request=urllib.request.Request(fixture['api_url']+path,data=json.dumps(body).encode(),headers=headers,method='POST')
        try:
            with urllib.request.urlopen(request,timeout=8) as response:return json.loads(response.read())
        except urllib.error.HTTPError as error:
            try:payload=json.loads(error.read())
            except ValueError:payload={}
            raise LocalHttpError(error.code,payload) from None
    def rpc(actor,name,body):return req(actor,'/rest/v1/rpc/'+name,body)
    def check(value,label):
        results.append({'case':label,'result':'PASS' if value else 'FAIL'})
        if not value:raise AssertionError(label)
    def denied(actor,name,body,status,message):
        try:rpc(actor,name,body)
        except LocalHttpError as error:return error.status==status and error.message==message
        return False
    def rows(actor):return rpc(actor,'list_c010_my_archived_organizations',{})
    error=None
    try:
        for actor in ('admin_b','trainer','outsider'):
            session=req(None,'/auth/v1/token?grant_type=password',{k:users[actor][k] for k in ('email','password')})
            check(session['user']['id']==users[actor]['user_id'],'real Auth identity '+actor)
            users[actor]['access_token']=session['access_token']
        name='Archived authority HTTP fixture'
        organization=rpc('admin_b','create_c010_stable',{'p_name':name,'p_location_name':'Disposable','p_request_id':fresh()})['organization_id'];owned['organization_id']=organization
        current=[r for r in rpc('admin_b','list_c010_stables',{}) if r['organization_id']==organization][0]
        first=rpc('admin_b','initiate_organization_authority_transfer_by_email',{'p_organization_id':organization,'p_recipient_email':users['trainer']['email'],'p_correlation_id':fresh()})[0]
        rpc('admin_b','retire_c010_stable',{'p_organization_id':organization,'p_expected_row_version':current['row_version'],'p_confirmed_name':name,'p_request_id':fresh()})
        check(any(r['organization_id']==organization for r in rows('admin_b')),'archived owner can find closed obligation through new list')
        check(not any(r['organization_id']==organization for r in rows('outsider')),'unrelated account cannot list another archive')
        began=time.monotonic()
        check(denied('trainer','respond_stable_authority_transfer',{'p_transfer_token':first['transfer_token'],'p_action':'accept','p_correlation_id':fresh()},409,'STALE_ORGANIZATION_ACCESS_VERSION'),'real stale archived acceptance returns HTTP409')
        check(time.monotonic()-began<5,'HTTP409 has bounded response time')
        rpc('admin_b','revoke_organization_authority_transfer',{'p_transfer_id':first['transfer_id'],'p_expected_row_version':1,'p_correlation_id':fresh()})
        transfer=rpc('admin_b','initiate_organization_authority_transfer_by_email',{'p_organization_id':organization,'p_recipient_email':users['trainer']['email'],'p_correlation_id':fresh()})[0]
        owned['transfer_id']=transfer['transfer_id']
        preview=rpc('trainer','preview_organization_authority_transfer',{'p_transfer_token':transfer['transfer_token']})
        check(len(preview)==1 and preview[0]['organization_id']==organization,'existing recipient preview route reads exact closed organization')
        check(rpc('outsider','preview_organization_authority_transfer',{'p_transfer_token':transfer['transfer_token']})==[],'wrong recipient sees no preview metadata')
        accepted=rpc('trainer','respond_stable_authority_transfer',{'p_transfer_token':transfer['transfer_token'],'p_action':'accept','p_correlation_id':fresh()})[0]
        check(accepted['status']=='accepted' and accepted['applied'],'existing HTTP token flow accepts archive succession')
        check(not any(r['organization_id']==organization for r in rows('admin_b')) and any(r['organization_id']==organization for r in rows('trainer')),'minimal archive responsibility moves to accepted recipient')
        check(not rpc('trainer','has_organization_permission',{'p_organization_id':organization,'p_permission_code':'organization.view'}),'new archive primary still lacks operational organization view')
        check(denied('trainer','respond_stable_authority_transfer',{'p_transfer_token':transfer['transfer_token'],'p_action':'accept','p_correlation_id':fresh()},403,'TRANSFER_NOT_AVAILABLE'),'used token cannot accept a second time')
        check(not any(r['organization_id']==organization for r in rpc('trainer','list_c010_stables',{})),'archived organization is not reopened in ordinary stable picker')
    except Exception as exc:error=type(exc).__name__+': '+str(exc)
    private=args.fixture_file.parent/'archive-transfer-api-fixtures.json';private.write_text(json.dumps(owned,indent=2)+'\n');private.chmod(0o600)
    result={'target':args.target,'result':'PASS' if error is None else 'FAIL','pass':sum(r['result']=='PASS' for r in results),'fail':sum(r['result']=='FAIL' for r in results),'error':error,'cases':results,'fixture_policy':'one new synthetic archived organization retained in isolated target; no preview fixtures changed'}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='cases'}))
    return 0 if result['result']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
