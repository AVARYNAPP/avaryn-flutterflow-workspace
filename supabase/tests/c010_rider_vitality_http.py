#!/usr/bin/env python3
"""Bounded real-Auth Vitality checks on its separately owned local test stack.

This script never applies a migration or resets an environment. It refuses to
run unless all current source hashes already match the local migration ledger.
Creates only new synthetic users through signup/mail confirmation/password login.
Private credentials stay in this target's 0600 fixture file, never in output.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime as dt
import html
import json
from pathlib import Path
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tool'))
import avaryn_local as local

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target',required=True)
    parser.add_argument('--state-dir',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.target!='avaryn-c010-vitality-20260911-a':
        parser.error('only the explicitly owned Vitality test target is accepted')
    cfg=local.load_context(args)
    if cfg['ports']['api']!=56801 or cfg['ports']['db']!=56802:
        parser.error('unexpected test target ports')
    for service in local.SERVICES:local.verify_container(cfg,service)
    def ledger():
        return dict(line.split('|') for line in local.sql(cfg,
            'begin read only;select version,sha256 from avaryn_local_meta.migrations order by version;commit;').stdout.splitlines() if '|'in line)
    before=ledger()
    sources={p.name.split('_')[0]:local.digest(p.read_bytes()) for p in (local.ROOT/'supabase/migrations').glob('*.sql')}
    if before!=sources or '202609110003'not in before:
        raise SystemExit('Required reviewed Vitality migration not applied; no fixture writes performed.')
    cases=[];users=[];run_id=str(uuid.uuid4());completed=False
    private_path=cfg['state']/('vitality-http-'+run_id+'.json')
    def save_private():local.private_json(private_path,{'target':args.target,'users':users})
    def check(label,value):
        cases.append({'label':label,'status':'PASS'if value else'FAIL'})
        if not value:raise AssertionError(label)
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def http(method,path,body=None,token=None,service=False,mail=False):
        key=cfg['service_key']if service else cfg['anon_key']
        base=f"http://127.0.0.1:{cfg['ports']['mail']}"if mail else cfg['api_url']
        headers={}if mail else{'apikey':key,'Authorization':'Bearer '+(token or key)}
        if body is not None:headers['Content-Type']='application/json'
        req=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
        try:
            with opener.open(req,timeout=12)as response:return response.status,json.load(response)
        except urllib.error.HTTPError as error:
            try:data=json.loads(error.read())
            except ValueError:data={}
            return error.code,data
    def rpc(user,name,body):return http('POST','/rest/v1/rpc/'+name,body,user and user['access_token'])
    def signup(label):
        user={'label':label,'email':label+'-'+uuid.uuid4().hex+'@vitality-test.invalid','password':secrets.token_urlsafe(24)}
        users.append(user);save_private()
        status,signed=http('POST','/auth/v1/signup',{k:user[k]for k in('email','password')})
        check(label+' real signup requires email confirmation',status in(200,201)and not signed.get('access_token'))
        matching=[]
        for _ in range(20):
            _,messages=http('GET','/api/v1/messages',mail=True)
            matching=[m for m in messages.get('messages',[])if any(t['Address']==user['email']for t in m['To'])]
            if matching:break
            time.sleep(.25)
        if not matching:raise AssertionError('Own confirmation mail unavailable')
        _,message=http('GET','/api/v1/message/'+matching[0]['ID'],mail=True)
        content=html.unescape(message.get('Text','')+'\n'+message.get('HTML',''))
        links=re.findall(re.escape(cfg['api_url'])+r'/(?:auth/v1/)?verify\?[^\s"<>]+',content)
        if not links:raise AssertionError('Own local confirmation link unavailable')
        query=urllib.parse.parse_qs(urllib.parse.urlparse(links[0]).query)
        status,confirmed=http('POST','/auth/v1/verify',{'token_hash':query['token'][0],'type':query['type'][0]})
        check(label+' actual email confirmed',status==200 and bool(confirmed.get('user',{}).get('email_confirmed_at')))
        status,session=http('POST','/auth/v1/token?grant_type=password',{k:user[k]for k in('email','password')})
        check(label+' password login',status==200 and bool(session.get('access_token')))
        user.update(auth_id=session['user']['id'],access_token=session['access_token']);save_private()
        status,profile=rpc(user,'get_current_account_profile',{})
        check(label+' real canonical profile',status==200 and isinstance(profile,list)and len(profile)==1)
        user['profile_id']=profile[0]['profile_id'];save_private();return user
    def read(user,day):return rpc(user,'get_c010_my_vitality_day',{'p_on_date':day})
    def write(user,day,version,document,request_id=None):
        return rpc(user,'save_c010_my_vitality_day',{'p_on_date':day,'p_expected_row_version':version,
            'p_document':document,'p_request_id':request_id or str(uuid.uuid4())})
    def held_deletion(user):
        request=str(uuid.uuid4())
        command=['docker','exec','-i',local.name(cfg,'db'),'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres']
        process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
        sql="begin;set local statement_timeout='5s';set local role service_role;select set_config('request.jwt.claim.sub','',true);"
        sql+="select public.prepare_c010_account_deletion('"+user['auth_id']+"','"+request+"');select 'VITALITY_LOCK_HELD';select pg_sleep(0.8);commit;"
        process.stdin.write(sql);process.stdin.close()
        while True:
            line=process.stdout.readline()
            if line.strip()=='VITALITY_LOCK_HELD':break
            if not line:raise AssertionError('Own deletion transaction did not acquire lock')
        return process
    try:
        owner=signup('owner');other=signup('other')
        status,empty=read(owner,None);day=empty.get('on_date')
        check('default day/calendar is authoritative',status==200 and empty['calendar']['time_zone']=='Europe/Amsterdam'and day==empty['calendar']['today_date']and empty['row_version']==0)
        status,_=read(None,day);check('anonymous read refused',status in(401,403))
        document={'warmup':None,'reflection':{'person':'Rustig','horse':'Energiek','focus':'Private synthetic HTTP note','sharingIntent':'later'},'focus':'Own focus','routines':{}}
        request=str(uuid.uuid4());status,saved=write(owner,day,0,document,request)
        check('real authenticated save',status==200 and saved.get('row_version')==1)
        status,current=read(owner,day);check('whole document reread',status==200 and current['document']==document)
        status,replay=write(owner,day,0,document,request);check('same request idempotent',status==200 and replay.get('idempotent')and not replay.get('applied'))
        status,error=write(owner,day,0,{});check('stale CAS returns HTTP409',status==409 and error.get('message')=='C010_VITALITY_VERSION_STALE')
        status,_=write(owner,day,1,{'profile_id':other['profile_id']});check('actor injection refused',status==400)
        status,foreign=read(other,day);check('other actor cannot see document',status==200 and not foreign['exists']and foreign['row_version']==0)
        status,_=http('GET','/rest/v1/c010_vitality_days?select=*',token=owner['access_token']);check('private table not exposed',status in(400,403,404))
        with ThreadPoolExecutor(max_workers=2)as pool:
            results=list(pool.map(lambda value:write(owner,day,1,{'focus':value}),['race-left','race-right']))
        check('two-session same-version race has one winner',sorted(status for status,_ in results)==[200,409])
        status,current=read(owner,day);check('race advances version once',status==200 and current['row_version']==2)
        next_day=(dt.date.fromisoformat(day)+dt.timedelta(days=1)).isoformat();same_request=str(uuid.uuid4())
        with ThreadPoolExecutor(max_workers=2)as pool:
            same=list(pool.map(lambda _:write(owner,next_day,0,{'focus':'same request'},same_request),range(2)))
        check('simultaneous identical request has one application',all(status==200 for status,_ in same)and sum(bool(result.get('applied'))for _,result in same)==1)
        status,deleted=rpc(owner,'delete_c010_my_vitality_day',{'p_on_date':day,'p_expected_row_version':2,'p_request_id':str(uuid.uuid4())})
        check('delete erases content with new version',status==200 and deleted.get('row_version')==3 and not deleted.get('exists'))
        status,current=read(owner,day);check('deleted day retains only CAS boundary',status==200 and not current['exists']and current['row_version']==3 and current['document']['reflection']is None)
        status,error=write(owner,day,0,document,request);check('old request cannot resurrect deleted day',status==409)
        status,_=write(other,day,0,{'focus':'Keep other actor'});check('other owner independent save',status==200)
        process=held_deletion(owner)
        status,error=write(owner,next_day,1,{'focus':'Must never survive'})
        process.wait(timeout=7)
        check('deletion transaction committed',process.returncode==0)
        check('queued write cannot cross deletion boundary',status==403 and error.get('message')=='ACTIVE_PROFILE_REQUIRED')
        status,_=read(owner,next_day);check('old JWT cannot read after preparation',status==403)
        sql="begin read only;select count(*) from private.c010_vitality_days where profile_id='"+owner['profile_id']+"';select count(*) from private.c010_vitality_receipts where profile_id='"+owner['profile_id']+"';commit;"
        counts=local.sql(cfg,sql,role='postgres').stdout.splitlines()
        check('actual lifecycle erases content and receipts',counts==['0','0'])
        status,current=read(other,day);check('deletion preserves other owner',status==200 and current['document']['focus']=='Keep other actor')
        check('migration ledger unchanged after tests',ledger()==before)
        completed=True
    finally:
        save_private()
        result={'target':args.target,'status':'PASS'if completed and cases and all(c['status']=='PASS'for c in cases)else'FAIL',
            'checks':cases,'pass_count':sum(c['status']=='PASS'for c in cases),'migration_sha256':before.get('202609110003'),
            'fixture_scope':'Only newly created synthetic accounts on the isolated Vitality target; histories preserved; no preview or remote writes.'}
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'status':result['status'],'checks':len(cases),'pass':result['pass_count'],'target':args.target}))
    return 0

if __name__=='__main__':sys.exit(main())
