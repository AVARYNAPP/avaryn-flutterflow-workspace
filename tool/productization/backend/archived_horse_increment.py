#!/usr/bin/env python3
"""Exact archived-horse005 preparation/apply on owned dev or AVARYN Pilot.

Prepare only reads its source database, takes a full backup, restores one NEW
local database and rehearses005 there. Apply needs the matching reviewed proof,
a coordinated write pause and a completely unchanged current baseline.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import pilot_timezone_increment as previous
from check_pilot_connection import ROOT,BASE,EVIDENCE,REF,ORG,configuration,private_write
from backup_pilot_database import LOCAL_CONTAINER,LOCAL_TARGET,LOCAL_CLUSTER,REMOTE_CLUSTER,local,parsed,run,fingerprint_sql
from apply_pilot_migrations import migration_sql
from prepare_pilot_release import source_file

sys.path.insert(0,str(ROOT/'tool'))
from avaryn_local import migration_transaction

VERSION='202609110005'
NAME='c010_archived_horse_authority_transfer'
SOURCE='supabase/migrations/'+VERSION+'_'+NAME+'.sql'
SOURCE_SHA='755aa06c7d613aa887ed8f9c69ce9afe68560c45e00bb19d7955ef85677f98bc'
PLAN_PATH=Path(__file__).with_name('archived-horse005-plan.json')
CHANGED_NAMES={'public.initiate_horse_authority_transfer','public.initiate_horse_authority_transfer_by_email',
               'public.respond_horse_authority_transfer','public.revoke_horse_authority_transfer'}
NEW_NAME='public.list_c010_my_archived_horses'
SUITES=(('c010_archived_horse_authority_transfer',48),('c003e_atomic_transfers',1),('c010_account_deletion',1))
PREVIOUS_EXECUTOR_SHA='94c4a6f0f383725f9071e393a2e8cc8a25b336c7515a8b84c47217264f71f0f5'
PREVIOUS_PLAN_SHA='540718f153c98f7a8258a315a2c7e3353d55116fb30736abfc3327e61982d23b'
DEV_HISTORY="select coalesce(jsonb_agg(jsonb_build_object('version',version,'sha256',sha256) order by version),'[]') from avaryn_local_meta.migrations;"
DEV_STATE=ROOT/'.avaryn-local/c010-productization-20260911/private/local-environments'/LOCAL_TARGET
sha=previous.sha
digest_json=previous.digest_json
readonly=previous.readonly


def source_plan():
    old=previous.source_plan() # Pins the immutable47 manifest plus reviewed004.
    baseline=old['baseline']+[{k:old['migration'][k] for k in ('version','name','sha256')}|{'statement_count':1}]
    data=source_file(ROOT,SOURCE).read_bytes()
    if sha(data)!=SOURCE_SHA:raise ValueError('ONLY_REVIEWED005_SOURCE_ALLOWED')
    item={'version':VERSION,'name':NAME,'path':SOURCE,'sha256':SOURCE_SHA,'transaction_wrapper':'source'}
    dependencies=['pilot_timezone_increment.py','backup_pilot_database.py','check_pilot_connection.py','apply_pilot_migrations.py','prepare_pilot_release.py']
    return {'project_ref':REF,'organization_id':ORG,'pilot_cluster':REMOTE_CLUSTER,'dev_cluster':LOCAL_CLUSTER,
        'dev_target':LOCAL_TARGET,'baseline':baseline,'migration':item,
        'executor_sql_sha256':{'pilot':sha(migration_sql(item,data).encode()),'dev':sha(migration_transaction(data.decode(),VERSION,SOURCE_SHA).encode())},
        'helper_hashes':{v:sha(Path(__file__).with_name(v).read_bytes()) for v in dependencies},
        'local_runner_sha256':sha((ROOT/'tool/avaryn_local.py').read_bytes()),
        'tests':[{'name':n,'assertions':count,'sha256':sha(source_file(ROOT,'supabase/tests/'+n+'.sql').read_bytes())} for n,count in SUITES],
        'unchanged':['all48 historical migrations','existing data','table/column privileges and RLS','existing function owners/ACL','Auth/Edge/SMTP/Storage bytes'],
        'only_new_permission':'authenticated EXECUTE on actorless list_c010_my_archived_horses()',
        'backup':'full custom archive, decoded and actually restored to a new local database before rehearsal',
        'automatic_retry':False,'automatic_restore':False,'fixture_seed':False}


def expected_history(plan,target,after=False):
    rows=plan['baseline']+([{k:plan['migration'][k] for k in ('version','name','sha256')}|{'statement_count':1}] if after else [])
    return [{k:r[k] for k in ('version','sha256')} for r in rows] if target=='dev' else rows


def validate_history(actual,plan,target):
    if actual==expected_history(plan,target):return 48
    if actual==expected_history(plan,target,True):return 49
    raise ValueError('HISTORY_DRIFT_NO_RESET_OR_REAPPLY')


def history_guard(target,actual):
    query=DEV_HISTORY if target=='dev' else previous.HISTORY
    # The owned local ledger intentionally grants postgres only SELECT/INSERT.
    # Serialize this coordinated executor without widening its table privileges.
    lock=("perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('avaryn:migrations:"+LOCAL_TARGET+"',0));") if target=='dev' else ''
    table_lock='' if target=='dev' else 'lock table supabase_migrations.schema_migrations in share row exclusive mode;'
    expected=json.dumps(actual,separators=(',',':')).replace("'","''")
    return table_lock+"do $guard$begin "+lock+" if ("+query.rstrip(';')+") is distinct from '"+expected+"'::jsonb then raise exception 'HISTORY_CHANGED_BEFORE005';end if;end$guard$;\n"


def assert_schema_delta(before,after):
    old={r['kind']+' '+r['identity']:r for r in before};new={r['kind']+' '+r['identity']:r for r in after}
    added=set(new)-set(old)
    if added!={'function '+NEW_NAME+'()'} or set(old)-set(new):raise ValueError('UNEXPECTED_SCHEMA_ADDITION_OR_REMOVAL')
    changed=set()
    for key,row in old.items():
        if row['kind']=='function' and row['identity'].split('(')[0] in CHANGED_NAMES:
            changed.add(row['identity'].split('(')[0])
            if {k:v for k,v in row.items() if k!='body_hash'}!={k:v for k,v in new[key].items() if k!='body_hash'}:
                raise ValueError('EXISTING_FUNCTION_OWNER_ACL_CHANGED')
        elif new[key]!=row:raise ValueError('UNRELATED_SCHEMA_CHANGED')
    if changed!=CHANGED_NAMES:raise ValueError('EXPECTED_FOUR_OLD_ROUTINES_MISSING')
    added_row=new[next(iter(added))]
    wanted=[{'grantor':'postgres','grantee':grantee,'privilege':'EXECUTE','grantable':False} for grantee in ('authenticated','postgres')]
    if added_row['owner']!='postgres' or added_row['acl']!=wanted or added_row['config']!=['search_path=""']:
        raise ValueError('NEW_LIST_PERMISSION_OR_SEARCH_PATH_CHANGED')


def test_sql(name):
    if name not in dict(SUITES):raise ValueError('UNRECOGNIZED_SUITE')
    data=source_file(ROOT,'supabase/tests/'+name+'.sql').read_text()
    if not data.startswith('begin;') or not data.rstrip().endswith('rollback;'):raise ValueError('TEST_NOT_ROLLBACK')
    return "begin;set local lock_timeout='5s';set local statement_timeout='45s';create extension if not exists pgtap with schema extensions;set local role postgres;\n"+data[6:data.rfind('rollback;')]+"\nrollback;\n"


def test_result(name,result):
    text=result.stdout.decode(errors='replace')+'\n'+result.stderr.decode(errors='replace')
    lines=re.findall(r'(?m)^\s*((?:not )?ok \d+[^\n]*)',text)
    passed=result.returncode==0 and len(lines)==dict(SUITES)[name] and not any(v.startswith('not ') for v in lines) and not re.search(r'Looks like you failed|planned \d+ tests but ran',text)
    return {'suite':name,'status':'PASS' if passed else 'FAIL','assertions':len(lines),'source_sha256':sha(source_file(ROOT,'supabase/tests/'+name+'.sql').read_bytes())}


class Run:
    def __init__(self,target,mode):
        self.target=target;self.mode=mode;self.plan=source_plan()
        if json.loads(PLAN_PATH.read_text())!=self.plan:raise ValueError('REVIEW_PLAN_CHANGED')
        self.env=configuration()[1] if target=='pilot' else None
        previous.check_local()
        if target=='dev':
            cfg=json.loads((DEV_STATE/'environment.json').read_text())
            if cfg['target']!=LOCAL_TARGET or cfg['ports']['api']!=56801 or cfg['ports']['db']!=56802:raise ValueError('DEV_CONFIG_IDENTITY_MISMATCH')
        self.stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.directory=BASE/('horse005-'+target+'-'+mode+'-'+self.stamp);self.directory.mkdir(mode=0o700)
        self.code_sha=sha(Path(__file__).read_bytes());self.index=0
        self.history_sql=DEV_HISTORY if target=='dev' else previous.HISTORY
        self.ledger_table='avaryn_local_meta.migrations' if target=='dev' else 'supabase_migrations.schema_migrations'
    def capture(self,result,label,as_json=True):
        self.index+=1
        for suffix,value in [('stdout',result.stdout),('stderr',result.stderr)]:private_write(self.directory/(f'{self.index:03d}-{label}-{suffix}.log'),value.decode(errors='replace'))
        if result.returncode:raise ValueError(label.upper()+'_FAILED_NO_RETRY')
        return parsed(result) if as_json else result
    def execute(self,sql,label,write=False,as_json=True):
        if write and self.mode!='apply':raise ValueError('SOURCE_DATABASE_WRITE_NOT_ALLOWED')
        if self.target=='dev':p=local(sql)
        else:
            env=dict(self.env)
            if write:env['PGOPTIONS']='-c default_transaction_read_only=off -c statement_timeout=60000 -c lock_timeout=5000'
            p=subprocess.run(['/opt/homebrew/bin/psql','-X','-q','-A','-t','-w','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True,env=env,timeout=90)
        return self.capture(p,label,as_json)
    def snapshot(self,label):
        identity=self.execute(readonly(previous.IDENTITY),label+'-identity')
        previous.validate_identity(identity,self.target=='pilot','postgres')
        if self.target=='pilot':
            tls=self.execute('\\conninfo\n',label+'-tls',as_json=False)
            if not any(s.startswith(b'SSL connection (') for s in tls.stdout.splitlines()):raise ValueError('TLS_NOT_CONFIRMED')
        history=self.execute(readonly(self.history_sql),label+'-history');count=validate_history(history,self.plan,self.target)
        if self.target=='dev' and json.loads((DEV_STATE/'migrations.json').read_text())!={v['version']:v['sha256'] for v in history}:raise ValueError('DEV_LEDGER_MIRROR_DIFFERS')
        tables=self.execute(readonly(previous.TABLES),label+'-tables')
        result={'identity':identity,'history':history,'count':count,'tables':tables,
            'rows':self.execute(fingerprint_sql(tables),label+'-rows'),
            'catalog':self.execute(readonly(previous.CATALOG),label+'-catalog'),
            'security':self.execute(readonly(previous.TABLE_SECURITY),label+'-security')}
        private_write(self.directory/(label+'-snapshot.json'),json.dumps(result,indent=2)+'\n');return result
    def migration(self):
        data=source_file(ROOT,SOURCE).read_bytes()
        return migration_sql(self.plan['migration'],data) if self.target=='pilot' else migration_transaction(data.decode(),VERSION,SOURCE_SHA).replace('BEGIN;','BEGIN;\nset local lock_timeout=\'5s\';set local statement_timeout=\'60s\';',1)
    def evidence(self,value):
        value|={'target':self.target,'project_ref':REF if self.target=='pilot' else LOCAL_TARGET,'checked_at':self.stamp,
                'migration_sha256':SOURCE_SHA,'plan_sha256':digest_json(self.plan),'script_sha256':self.code_sha}
        private_write(self.directory/'receipt.json',json.dumps(value,indent=2)+'\n')
        path=EVIDENCE/('horse005-'+self.target+'-'+self.mode+'-'+self.stamp+'.json');path.write_text(json.dumps(value,indent=2)+'\n')
        print(json.dumps({'status':value['status'],'target':self.target,'evidence':str(path.relative_to(ROOT)),'private_run':str(self.directory.relative_to(ROOT)),'source_database_writes':value.get('source_database_writes',False)}))


def prepare(r,before,reuse=None):
    if before['count']!=48:raise ValueError('PREPARE_REQUIRES48_NO_REAPPLY')
    if reuse:
        original=previous.check_private(reuse,directory=True)
        pin=json.loads(previous.check_private(original/'approved-resume-pin.json').read_text())
        original_before=json.loads(previous.check_private(original/'before-snapshot.json').read_text())
        archive=previous.check_private(original/(r.target+'48-before005.dump'))
        db=pin.get('restore_database','')
        if (pin.get('target')!=r.target or pin.get('migration_sha256')!=SOURCE_SHA
            or pin.get('old_executor_sha256')!=PREVIOUS_EXECUTOR_SHA or pin.get('old_plan_sha256')!=PREVIOUS_PLAN_SHA
            or pin.get('backup_sha256')!=sha(archive.read_bytes()) or pin.get('baseline_snapshot_sha256')!=digest_json(original_before)
            or original_before!=before):raise ValueError('REUSE_PIN_OR_CURRENT_BASELINE_DIFFERS')
        if not re.fullmatch(r'(expected49-catalog\.json|\d{3}-local005-catalog-stdout\.log)',pin.get('catalog_file','')):raise ValueError('REUSE_CATALOG_PATH_INVALID')
        if db!='avaryn_'+r.target+'005_restore_'+original.name.rsplit('-',1)[1].lower():raise ValueError('REUSE_DATABASE_NOT_ORIGINAL')
        old_catalog=json.loads(previous.check_private(original/pin['catalog_file']).read_text())
        if digest_json(old_catalog)!=pin.get('catalog_sha256'):raise ValueError('REUSE_CATALOG_PIN_DIFFERS')
        r.capture(run(['/opt/homebrew/bin/pg_restore','--file=/dev/null',str(archive)]),'reuse-archive-decode',False)
    else:
        archive=r.directory/(r.target+'48-before005.dump')
        command=['/opt/homebrew/bin/pg_dump','-w','-Fc'] if r.target=='pilot' else ['docker','exec',LOCAL_CONTAINER,'pg_dump','-U','supabase_admin','-d','postgres','-Fc']
        with os.fdopen(os.open(archive,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'wb') as output:
            dumped=subprocess.run(command,stdout=output,stderr=subprocess.PIPE,env=r.env,timeout=180)
        private_write(r.directory/'dump-stderr.log',dumped.stderr.decode(errors='replace'))
        if dumped.returncode or archive.stat().st_size<10000:raise ValueError('BACKUP_FAILED')
        r.capture(run(['/opt/homebrew/bin/pg_restore','--list',str(archive)]),'archive-list',False)
        r.capture(run(['/opt/homebrew/bin/pg_restore','--file=/dev/null',str(archive)]),'archive-decode',False)
        if r.snapshot('after-backup')!=before:raise ValueError('SOURCE_CHANGED_DURING_BACKUP_STOP')
        print(json.dumps({'status':'BACKUP_BASELINE_CAPTURED','target':r.target,'source_database_writes':False}),flush=True)
        db='avaryn_'+r.target+'005_restore_'+r.stamp.lower()
    if not re.fullmatch(r'avaryn_(pilot|dev)005_restore_\d{8}t\d{6}z',db):raise ValueError('RESTORE_NAME_INVALID')
    if not db.startswith('avaryn_'+r.target+'005_restore_'):raise ValueError('REUSE_TARGET_MISMATCH')
    if not reuse:
        created=run(['docker','exec','-i',LOCAL_CONTAINER,'psql','-X','-q','-w','-U','supabase_admin','-d','postgres','-v','ON_ERROR_STOP=1'],input=('create database '+db+' owner postgres template template0;').encode())
        r.capture(created,'create-new-restore-database',False)
        with archive.open('rb') as handle:p=subprocess.run(['docker','exec','-i',LOCAL_CONTAINER,'pg_restore','-U','supabase_admin','-d',db,'--single-transaction','--exit-on-error'],stdin=handle,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=180)
        r.capture(p,'actual-restore',False)
    previous.validate_identity(parsed(local(readonly(previous.IDENTITY),db)),False,db)
    for sql,key in [(r.history_sql,'history'),(previous.CATALOG,'catalog'),(previous.TABLE_SECURITY,'security')]:
        expected=expected_history(r.plan,r.target,True) if reuse and key=='history' else old_catalog if reuse and key=='catalog' else before[key]
        if r.capture(local(readonly(sql),db),'restore-'+key)!=expected:raise ValueError('RESTORED_'+key.upper()+'_DIFFERS')
    rows=r.capture(local(fingerprint_sql(before['tables']),db),'restore-rows')
    changed=[a['relation'] for a,b in zip(before['rows'],rows) if a!=b]
    if changed!=([r.ledger_table] if reuse else []):raise ValueError('RESTORED_ROWS_DIFFER')
    names=','.join("'"+n.split('.')[1]+"'" for n in sorted(CHANGED_NAMES))
    r.capture(local(readonly("select pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in("+names+") order by p.proname;"),db),'four-function-recovery-source',False)
    private_write(r.directory/'RECOVERY.md','Full archive restored and verified in '+db+'. Only this new database was used for rehearsal. Never restore over current users automatically. If005 has a confirmed defect, use the captured four old function definitions and ACL baseline to review a new forward-only correction; keep archived succession history intact. A full restore requires a separately approved outage/data cutover and the retained archive; do not delete or edit migration history. Auth/SMTP/Edge configuration and Storage bytes are outside this database archive.\n')
    if not reuse:r.capture(local(r.migration(),db),'local005-rehearsal',False)
    catalog=r.capture(local(readonly(previous.CATALOG),db),'local005-catalog');assert_schema_delta(before['catalog'],catalog)
    if r.capture(local(readonly(previous.TABLE_SECURITY),db),'local005-security')!=before['security']:raise ValueError('TABLE_SECURITY_CHANGED')
    # Exercise the exact prologue as postgres, without a DDL or ledger INSERT.
    good=expected_history(r.plan,r.target,True)
    r.capture(local('begin;'+history_guard(r.target,good)+'rollback;',db),'guard-positive-postgres',False)
    bad=[dict(v) for v in good];bad[-1]['sha256']='0'*64
    refused=local('begin;'+history_guard(r.target,bad)+'rollback;',db)
    for suffix,value in [('stdout',refused.stdout),('stderr',refused.stderr)]:private_write(r.directory/('guard-refusal-'+suffix+'.log'),value.decode(errors='replace'))
    if refused.returncode==0 or b'HISTORY_CHANGED_BEFORE005' not in refused.stderr:raise ValueError('GUARD_DID_NOT_REFUSE_DRIFT')
    tests=[]
    for name,_ in SUITES:
        p=run(['docker','exec','-i',LOCAL_CONTAINER,'psql','-X','-q','-A','-t','-w','-U','supabase_admin','-d',db,'-v','ON_ERROR_STOP=1'],input=test_sql(name).encode(),timeout=90)
        r.capture(p,name,False);result=test_result(name,p);tests.append(result)
        if result['status']!='PASS':raise ValueError('ROLLBACK_SUITE_FAILED_'+name)
    if validate_history(r.capture(local(readonly(r.history_sql),db),'rehearsal-history'),r.plan,r.target)!=49:raise ValueError('RESTORE_HISTORY_NOT49')
    rows=r.capture(local(fingerprint_sql(before['tables']),db),'rehearsal-rows')
    if [a['relation'] for a,b in zip(before['rows'],rows) if a!=b]!=[r.ledger_table]:raise ValueError('REHEARSAL_CHANGED_EXISTING_ROWS')
    if r.capture(local(readonly(previous.CATALOG),db),'post-tests-catalog')!=catalog:raise ValueError('TEST_SCHEMA_NOT_ROLLED_BACK')
    private_write(r.directory/'expected49-catalog.json',json.dumps(catalog,indent=2)+'\n')
    private_write(r.directory/'backup-reference.json',json.dumps({'path':str(archive),'sha256':sha(archive.read_bytes())},indent=2)+'\n')
    r.evidence({'status':'PASS_PREPARED48_TO49','source_database_writes':False,'baseline_snapshot_sha256':digest_json(before),
        'backup_sha256':sha(archive.read_bytes()),'backup_bytes':archive.stat().st_size,'backup_mode':'0600','actual_restore_database':db,
        'restored_tables':len(before['tables']),'existing_tables_preserved_in_rehearsal':len(rows)-1,'only_rehearsal_changed_table':r.ledger_table,
        'expected_catalog_sha256':digest_json(catalog),'tests':tests,'assertions':sum(v['assertions'] for v in tests),
        'restore_reused':bool(reuse),'guard_positive_and_drift_refusal':'PASS_EXACT_POSTGRES_ROLLBACK',
        'limits':['No main-dev or Pilot apply; root review required.','Later source data changes invalidate this prepared baseline.','SQL fixtures were rolled back only in the separate restored database.']})


def apply(r,before,prepared):
    directory=previous.check_private(prepared,directory=True)
    receipt=json.loads(previous.check_private(directory/'receipt.json').read_text())
    baseline=json.loads(previous.check_private(directory/'before-snapshot.json').read_text())
    catalog=json.loads(previous.check_private(directory/'expected49-catalog.json').read_text())
    ref=json.loads(previous.check_private(directory/'backup-reference.json').read_text());archive=previous.check_private(Path(ref['path']))
    if (receipt.get('status')!='PASS_PREPARED48_TO49' or receipt.get('target')!=r.target or receipt.get('script_sha256')!=r.code_sha
        or receipt.get('plan_sha256')!=digest_json(r.plan) or receipt.get('migration_sha256')!=SOURCE_SHA
        or receipt.get('baseline_snapshot_sha256')!=digest_json(baseline) or receipt.get('backup_sha256')!=sha(archive.read_bytes())
        or ref.get('sha256')!=receipt.get('backup_sha256') or receipt.get('expected_catalog_sha256')!=digest_json(catalog)
        or len(receipt.get('tests',[]))!=len(SUITES) or any(t['status']!='PASS' for t in receipt['tests'])):raise ValueError('PREPARED_PROOF_MISMATCH')
    if before['count']==49:
        if before['catalog']!=catalog or before['security']!=baseline['security']:raise ValueError('ALREADY49_SCHEMA_DIFFERS')
        r.evidence({'status':'ALREADY49_VERIFIED_NO_WRITE','source_database_writes':False});return
    if before!=baseline:raise ValueError('BASELINE_DRIFT_FRESH_BACKUP_REQUIRED')
    if source_plan()!=r.plan:raise ValueError('SOURCE_DRIFT')
    guard=history_guard(r.target,before['history'])
    sql=r.migration().replace("set local statement_timeout='60s';","set local statement_timeout='60s';\n"+guard,1)
    r.execute(sql,'apply-only005',True,False)
    if r.target=='dev':
        if r.execute(readonly(r.history_sql),'committed-history')!=expected_history(r.plan,'dev',True):raise ValueError('DEV_COMMIT_HISTORY_DIFFERS_NO_MIRROR_WRITE')
        old=DEV_STATE/'migrations.json';private_write(r.directory/'local-mirror-before.json',old.read_text())
        updated={v['version']:v['sha256'] for v in expected_history(r.plan,'dev',True)}
        temporary=DEV_STATE/('.migrations-005-'+r.stamp+'.json');private_write(temporary,json.dumps(updated,indent=2)+'\n');os.replace(temporary,old)
    after=r.snapshot('after-apply')
    if after['count']!=49 or after['catalog']!=catalog or after['security']!=baseline['security'] or after['tables']!=baseline['tables']:raise ValueError('POSTCOMMIT_SCHEMA_DIFFERS_KEEP_EVIDENCE')
    changed=[a['relation'] for a,b in zip(baseline['rows'],after['rows']) if a!=b]
    if changed!=[r.ledger_table]:raise ValueError('POSTCOMMIT_DATA_DIFFERS_NO_AUTOMATIC_RESTORE')
    r.evidence({'status':'PASS_APPLIED005_49','source_database_writes':True,'only_migration':VERSION,'history_before':48,'history_after':49,
        'original48_hashes_preserved':True,'existing_tables_preserved':len(after['rows'])-1,'only_changed_table':r.ledger_table,
        'backup_sha256':receipt['backup_sha256'],'expected_catalog_sha256':digest_json(catalog),'fixture_seed':False})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--target',choices=['dev','pilot'],required=True)
    p.add_argument('--mode',choices=['preflight','prepare','apply'],required=True);p.add_argument('--prepared',type=Path)
    p.add_argument('--reuse-restore',type=Path)
    p.add_argument('--root-reviewed',action='store_true');p.add_argument('--writes-paused',action='store_true');a=p.parse_args()
    if a.mode=='apply' and (not a.prepared or not a.root_reviewed or not a.writes_paused):p.error('apply requires exact prepared proof, review and write pause')
    if a.reuse_restore and a.mode!='prepare':p.error('reuse-restore is only valid for prepare')
    os.umask(0o077);r=Run(a.target,a.mode);before=r.snapshot('before')
    if a.mode=='preflight':r.evidence({'status':'PASS_READONLY'+str(before['count']),'source_database_writes':False,'history_count':before['count']})
    elif a.mode=='prepare':prepare(r,before,a.reuse_restore)
    else:apply(r,before,a.prepared)


if __name__=='__main__':
    try:main()
    except Exception as error:
        print(json.dumps({'status':'BLOCKED','reason':str(error) if isinstance(error,ValueError) else type(error).__name__,'automatic_retry':False,'automatic_restore':False}));sys.exit(1)
