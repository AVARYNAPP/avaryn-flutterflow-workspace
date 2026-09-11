#!/usr/bin/env python3
"""Rollback-only migration/contract gate on the explicitly owned local dev DB.

No remote connection, no migration ledger write and no persistent fixture data.
Private diagnostics may contain synthetic one-time tokens; stdout is sanitized.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tool'))
import avaryn_local as local

TARGET='avaryn-c010-vitality-20260911-a'
CONTAINER_ID='a0fe4d12515e6fb4121966a0dffd46ef136f0a7fcf622b25e31ce17128e75f1e'
CLUSTER='7684330901039525928'
BASE=ROOT/'.avaryn-local/productization-20260911'
STATE=ROOT/'.avaryn-local/c010-productization-20260911/private/local-environments'/TARGET
MIGRATION=ROOT/'supabase/migrations/202609110005_c010_archived_horse_authority_transfer.sql'
TEST=ROOT/'supabase/tests/c010_archived_horse_authority_transfer.sql'
FUNCTIONS=['list_c010_my_archived_horses','initiate_horse_authority_transfer','initiate_horse_authority_transfer_by_email','respond_horse_authority_transfer','revoke_horse_authority_transfer']

def check(value,code):
    if not value:raise RuntimeError(code)

def sql(text):
    return subprocess.run(['docker','exec','-i',CONTAINER_ID,'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'],input=text,text=True,capture_output=True,timeout=55)

def inspect_target():
    path=STATE/'environment.json'
    check(path.is_file() and not path.is_symlink() and path.stat().st_mode&0o777==0o600,'PRIVATE_CONFIG_MODE')
    cfg=json.loads(path.read_text());cfg['state']=STATE
    check(cfg['target']==TARGET and cfg['owner']==local.OWNER and cfg['ports']['db']==56802 and cfg['ports']['api']==56801,'TARGET_MISMATCH')
    obj=local.inspect(TARGET+'-db');proof=local.verify_container(cfg,'db',obj)
    check(obj['Id']==CONTAINER_ID and obj['State']['Running'],'CONTAINER_MISMATCH')
    check(any(m.get('Name')==TARGET+'-db' and m.get('Destination')=='/var/lib/postgresql/data' for m in obj['Mounts']),'VOLUME_MISMATCH')
    result=sql("select system_identifier from pg_control_system();")
    check(result.returncode==0 and result.stdout.strip()==CLUSTER,'CLUSTER_MISMATCH')
    return {'target':TARGET,'containerId':CONTAINER_ID,'clusterId':CLUSTER,'volume':TARGET+'-db','dbPort':56802,'apiPort':56801,'loopbackBindings':proof['ports']}

def snapshot():
    names=','.join("'"+name+"'" for name in FUNCTIONS)
    query="""select jsonb_build_object(
      'ledger',(select jsonb_object_agg(version,sha256) from avaryn_local_meta.migrations),
      'definitions',(select jsonb_object_agg(p.oid::regprocedure::text,pg_get_functiondef(p.oid))
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in("""+names+""")),
      'fixture_users',(select count(*) from auth.users where email like '%-archived-horse@example.invalid'));
    """
    result=sql(query);check(result.returncode==0,'SNAPSHOT_FAILED');return json.loads(result.stdout.strip())

def unwrapped(path,ending):
    text=path.read_text();match=re.fullmatch(r'\s*begin\s*;([\s\S]*)\b'+ending+r'\s*;\s*',text,re.I)
    check(match is not None,'TRANSACTION_SHAPE');return match.group(1)

def main():
    stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    private=BASE/'private/archived-horse-transfer';private.mkdir(parents=True,exist_ok=True,mode=0o700)
    evidence=BASE/'evidence';evidence.mkdir(parents=True,exist_ok=True)
    proof={'status':'FAIL','mode':'rollback-only','sourceHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [MIGRATION,TEST]}}
    try:
        proof['identity']=inspect_target();before=snapshot();ledger=before['ledger']
        check(len(ledger)==48 and '202609110005' not in ledger,'BASELINE_MIGRATIONS_MISMATCH')
        for version,digest in ledger.items():
            files=list((ROOT/'supabase/migrations').glob(version+'_*.sql'))
            check(len(files)==1 and hashlib.sha256(files[0].read_bytes()).hexdigest()==digest,'BASELINE_SOURCE_DRIFT')
        body="BEGIN; SET LOCAL statement_timeout='15s'; SET LOCAL lock_timeout='3s';\n"+unwrapped(MIGRATION,'commit')+'\n'+unwrapped(TEST,'rollback')+'\nROLLBACK;\n'
        result=sql(body)
        log=result.stdout+'\n'+result.stderr;logpath=private/(stamp+'-rollback.log')
        fd=os.open(logpath,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as f:f.write(log)
        after=snapshot();proof['databaseUnchanged']=before==after
        proof['assertions']=[line for line in result.stdout.splitlines() if re.match(r'^(?:not )?ok \d+\b',line)]
        proof['plan']=[line for line in result.stdout.splitlines() if re.match(r'^1\.\.\d+$',line)]
        proof['exitCode']=result.returncode;proof['privateLog']=str(logpath.relative_to(ROOT));proof['logSha256']=hashlib.sha256(log.encode()).hexdigest()
        proof['baselineMigrations']=len(ledger);proof['fixtureRowsBeforeAfter']=[before['fixture_users'],after['fixture_users']]
        if result.returncode:
            match=re.search(r'^ERROR:\s*(.+)$',result.stderr,re.M);proof['error']=match.group(1)[:220] if match else 'SQL_FAILED'
        check(result.returncode==0 and proof['assertions'] and not any(s.startswith('not ok') for s in proof['assertions']) and before==after,'ROLLBACK_GATE_FAILED')
        check(proof['sourceHashes']=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [MIGRATION,TEST]},'SOURCE_CHANGED')
        proof['status']='PASS'
    except Exception as error:
        proof['failureCode']=str(error) if re.fullmatch('[A-Z_]+',str(error)) else type(error).__name__
    (evidence/'archived-horse-transfer-rollback.json').write_text(json.dumps(proof,indent=2)+'\n')
    print(json.dumps({k:v for k,v in proof.items() if k not in ['sourceHashes','assertions','privateLog']},indent=2))
    print('assertions='+str(len(proof.get('assertions',[]))))
    return 0 if proof['status']=='PASS' else 1

if __name__=='__main__':sys.exit(main())
