#!/usr/bin/env python3
"""ONLY managed AVARYN Pilot47 ->48 (account timezone004).

preflight: remote read-only. prepare: remote read-only dump, real NEW local
restore, one local migration rehearsal and rollback tests. apply: only after
root review/go, matching prepare receipt, fresh identity/history/data checks.
Never invokes fresh47, resets users, changes roles or deploys Edge/config.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from check_pilot_connection import ROOT,BASE,EVIDENCE,REF,ORG,configuration,private_write
from backup_pilot_database import (REMOTE_CLUSTER,LOCAL_CLUSTER,LOCAL_CONTAINER,LOCAL_CONTAINER_ID,
    LOCAL_TARGET,local,parsed,run,CATALOG as TABLES,fingerprint_sql)
from apply_pilot_migrations import CATALOG as RAW_CATALOG,migration_sql
from prepare_pilot_release import source_file
from verify_timezone_local import SQL_SUITES,test_sql,test_result

VERSION='202609110004'
NAME='c010_account_calendar_timezone'
SOURCE='supabase/migrations/'+VERSION+'_'+NAME+'.sql'
SOURCE_SHA='a9e47de0b01bb8fd407e354b1ea1a148d89455a53e79c70561aa13f6365b08bd'
BASELINE_SHA='41829a55f5283d349bc285e41d2706a68d87f904f54aa17bb3323e6eb6fda11d'
PLAN_PATH=Path(__file__).with_name('pilot-timezone004-plan.json')
CHANGED_NAMES={
 'public.get_c010_calendar_context','public.list_c010_stable_activities','public.get_c010_personal_day',
 'public.list_c010_personal_today','public.get_c010_stable_round1_workspace','public.configure_c010_facilities',
 'public.update_c010_facility_unit','public.save_c010_facility_booking','public.get_c010_facility_workspace'}
NEW_NAME='private.c010_actor_time_zone'
IDENTITY="""select jsonb_build_object('cluster',(select system_identifier::text from pg_control_system()),
 'database',current_database(),'role',current_user,'session_role',session_user,
 'superuser',(select rolsuper from pg_roles where rolname=current_user));"""
HISTORY="""select coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,
 'statement_count',cardinality(statements),'sha256',encode(extensions.digest(convert_to(statements[1],'UTF8'),'sha256'),'hex')) order by version),'[]')
 from supabase_migrations.schema_migrations;"""
TABLE_SECURITY="""select coalesce(jsonb_agg(jsonb_build_object('name',n.nspname||'.'||c.relname,
 'owner',pg_get_userbyid(c.relowner),'acl',c.relacl::text,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity) order by n.nspname,c.relname),'[]')
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in('r','p')
 and n.nspname not like 'pg_%' and n.nspname<>'information_schema' and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e');"""


# pg_dump may omit owner-only ACLs (NULL means the owner's default privileges)
# and reorder entries. Compare every effective grant, grantor and grant option.
def acl_sql(acl,kind,owner):
    return "(select coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(a.grantor),'grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,'privilege',a.privilege_type,'grantable',a.is_grantable) order by pg_get_userbyid(a.grantor),case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,a.privilege_type,a.is_grantable),'[]') from aclexplode(coalesce("+acl+",acldefault('"+kind+"',"+owner+"))) a)"

RAW_TABLE_SECURITY=TABLE_SECURITY
TABLE_SECURITY=TABLE_SECURITY.replace("c.relacl::text",acl_sql('c.relacl','r','c.relowner'))
CATALOG=RAW_CATALOG.replace('p.proacl::text acl',acl_sql('p.proacl','f','p.proowner')+' acl').replace('c.relacl::text,jsonb_build_object',acl_sql('c.relacl','r','c.relowner')+',jsonb_build_object')


def sha(data):return hashlib.sha256(data).hexdigest()
def digest_json(data):return sha(json.dumps(data,sort_keys=True,separators=(',',':')).encode())
def readonly(sql):return "begin read only;set local statement_timeout='30s';\n"+sql+'\ncommit;'


def source_plan():
    m=json.loads(source_file(ROOT,'tool/productization/backend/pilot-release-manifest.json').read_text())
    original={k:v for k,v in m.items() if k!='source_manifest_sha256'}
    if m.get('source_manifest_sha256')!=BASELINE_SHA or digest_json(original)!=BASELINE_SHA or m.get('project_ref')!=REF or m.get('organization_id')!=ORG:
        raise ValueError('HISTORICAL47_MANIFEST_CHANGED')
    items=m['migrations']
    if len(items)!=47 or items[-1]['version']!='202609110003' or len({v['version'] for v in items})!=47:
        raise ValueError('EXPECTED_EXACT47_BASELINE')
    for item in items:
        if sha(source_file(ROOT,item['path']).read_bytes())!=item['sha256']:raise ValueError('HISTORICAL_SOURCE_CHANGED')
    data=source_file(ROOT,SOURCE).read_bytes()
    if sha(data)!=SOURCE_SHA:raise ValueError('ONLY_REVIEWED004_SOURCE_ALLOWED')
    item={'version':VERSION,'name':NAME,'path':SOURCE,'sha256':SOURCE_SHA,'transaction_wrapper':'source'}
    # Parse the exact wrapper now, before a connection is even considered.
    sql=migration_sql(item,data)
    return {'project_ref':REF,'organization_id':ORG,'cluster':REMOTE_CLUSTER,'baseline_manifest_sha256':BASELINE_SHA,
            'baseline':[{'version':v['version'],'name':v['name'],'sha256':v['sha256'],'statement_count':1} for v in items],
            'migration':item,'executor_sql_sha256':sha(sql.encode()),
            'tests':[{'name':n,'assertions':count,'sha256':sha(source_file(ROOT,'supabase/tests/'+n+'.sql').read_bytes())} for n,count in SQL_SUITES],
            'unchanged_scope':['original47 migrations','existing rows','RLS and table grants','existing function grants','Auth/SMTP/Edge configuration','Storage bytes'],
            'backup':'full custom pg_dump; archive listing/decode; actual separate local restore and rowhash comparison',
            'restore_target_prefix':'avaryn_pilot004_restore_','remote_fixture_seed':False,
            'acl_comparison':'sorted aclexplode(coalesce(acl,acldefault)) including grantor, grantee, privilege and grant option'}


def validate_history(actual,plan):
    old=plan['baseline'];last={k:plan['migration'][k] for k in ['version','name','sha256']};last['statement_count']=1
    if actual==old:return 47
    if actual==old+[last]:return 48
    raise ValueError('UNKNOWN_PARTIAL_OR_DIFFERENT_HISTORY_STOP')


def validate_identity(identity,remote=True,database=None):
    if identity!={'cluster':REMOTE_CLUSTER if remote else LOCAL_CLUSTER,'database':'postgres' if remote else database,
                   'role':'postgres','session_role':'postgres','superuser':False}:
        raise ValueError('ACTUAL_DATABASE_IDENTITY_MISMATCH')


def assert_schema_delta(before,after):
    old={v['kind']+' '+v['identity']:v for v in before};new={v['kind']+' '+v['identity']:v for v in after}
    added=set(new)-set(old)
    if len(added)!=1 or new[next(iter(added))]['identity']!=NEW_NAME+'()' or set(old)-set(new):
        raise ValueError('SCHEMA_DELTA_NOT_ONE_PRIVATE_HELPER')
    for key,row in old.items():
        name=row['identity'].split('(')[0]
        if row['kind']=='function' and name in CHANGED_NAMES:
            if {k:v for k,v in row.items() if k!='body_hash'}!={k:v for k,v in new[key].items() if k!='body_hash'}:
                raise ValueError('EXISTING_FUNCTION_OWNER_ACL_CHANGED')
        elif row!=new[key]:raise ValueError('UNRELATED_SCHEMA_CHANGED')
    helper=new[next(iter(added))]
    if helper['owner']!='postgres' or helper['acl']!=[{'grantor':'postgres','grantee':'postgres','privilege':'EXECUTE','grantable':False}]:raise ValueError('PRIVATE_HELPER_GRANT_CHANGED')


def check_private(path,directory=False):
    p=path.absolute()
    if not p.is_relative_to(BASE) or any(v.is_symlink() for v in [p,*p.parents]) or not p.exists():raise ValueError('PRIVATE_PATH_SCOPE_INVALID')
    if p.stat().st_mode&0o777!=(0o700 if directory else 0o600):raise ValueError('PRIVATE_PATH_MODE_INVALID')
    return p


class Run:
    def __init__(self,mode):
        self.mode=mode;self.plan=source_plan()
        if json.loads(PLAN_PATH.read_text())!=self.plan:raise ValueError('REVIEW_PLAN_CHANGED')
        self.config,self.env=configuration();self.stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.directory=BASE/('timezone004-'+mode+'-'+self.stamp);self.directory.mkdir(mode=0o700)
        self.code_sha=sha(Path(__file__).read_bytes());self.index=0
    def capture(self,result,label):
        self.index+=1
        for suffix,value in [('stdout',result.stdout),('stderr',result.stderr)]:
            private_write(self.directory/(f'{self.index:03d}-'+label+'-'+suffix+'.log'),value.decode(errors='replace') if isinstance(value,bytes) else value)
        if result.returncode:raise ValueError(label.upper()+'_FAILED_STOP_NO_RETRY')
        return parsed(result)
    def remote(self,sql,label,write=False,as_json=True):
        if write and self.mode!='apply':raise ValueError('REMOTE_WRITE_MODE_NOT_AUTHORIZED')
        env=dict(self.env)
        if write:env['PGOPTIONS']='-c default_transaction_read_only=off -c statement_timeout=60000 -c lock_timeout=5000'
        r=subprocess.run(['/opt/homebrew/bin/psql','-X','-q','-A','-t','-w','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True,env=env,timeout=90)
        if as_json:return self.capture(r,label)
        self.index+=1
        for suf,v in [('stdout',r.stdout),('stderr',r.stderr)]:private_write(self.directory/(f'{self.index:03d}-{label}-{suf}.log'),v.decode(errors='replace'))
        if r.returncode:raise ValueError(label.upper()+'_FAILED_STOP_NO_RETRY')
        return r
    def snapshot(self,label):
        identity=self.remote(readonly(IDENTITY),label+'-identity');validate_identity(identity)
        tls=self.remote('\\conninfo\n',label+'-tls',as_json=False)
        if not any(v.startswith(b'SSL connection (') for v in tls.stdout.splitlines()):raise ValueError('CLIENT_TLS_NOT_CONFIRMED')
        history=self.remote(readonly(HISTORY),label+'-history');count=validate_history(history,self.plan)
        tables=self.remote(readonly(TABLES),label+'-tables')
        rows=self.remote(fingerprint_sql(tables),label+'-rows')
        catalog=self.remote(readonly(CATALOG),label+'-catalog')
        security=self.remote(readonly(TABLE_SECURITY),label+'-table-security')
        value={'identity':identity,'history':history,'count':count,'tables':tables,'rows':rows,'catalog':catalog,'table_security':security}
        private_write(self.directory/(label+'-snapshot.json'),json.dumps(value,indent=2)+'\n');return value
    def evidence(self,value):
        value|={'project_ref':REF,'checked_at':self.stamp,'migration_sha256':SOURCE_SHA,'plan_sha256':digest_json(self.plan),'script_sha256':self.code_sha}
        private_write(self.directory/'receipt.json',json.dumps(value,indent=2)+'\n')
        EVIDENCE.mkdir(parents=True,exist_ok=True)
        dest=EVIDENCE/('timezone004-'+self.mode+'-'+self.stamp+'.json');dest.write_text(json.dumps(value,indent=2)+'\n')
        print(json.dumps({'status':value['status'],'evidence':str(dest),'private_run':str(self.directory.relative_to(ROOT)),'remote_writes':value.get('remote_writes',False)}))


def check_local():
    c=parsed(run(['docker','inspect',LOCAL_CONTAINER]))[0]
    if (c['Id']!=LOCAL_CONTAINER_ID or not c['State']['Running'] or c['Config']['Labels'].get('io.avaryn.local.target')!=LOCAL_TARGET
        or c['NetworkSettings']['Ports'].get('5432/tcp')!=[{'HostIp':'127.0.0.1','HostPort':'56802'}]
        or not any(v.get('Name')==LOCAL_TARGET+'-db' for v in c['Mounts'])):raise ValueError('LOCAL_RESTORE_TARGET_MISMATCH')
    if parsed(local("begin read only;select to_jsonb(system_identifier::text) from pg_control_system();commit;"))!=LOCAL_CLUSTER:
        raise ValueError('LOCAL_CLUSTER_MISMATCH')


def prepare(r,before,resume=None):
    if before['count']!=47:raise ValueError('PREPARE_REQUIRES47_NO_REAPPLY')
    check_local()
    if resume is None:
        backup=r.directory/'pilot47-before004.dump'
        fd=os.open(backup,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'wb') as output:p=subprocess.run(['/opt/homebrew/bin/pg_dump','-w','-Fc'],stdout=output,stderr=subprocess.PIPE,env=r.env,timeout=180)
        private_write(r.directory/'backup-stderr.log',p.stderr.decode(errors='replace'))
        if p.returncode or backup.stat().st_size<10000:raise ValueError('FULL_BACKUP_FAILED')
        listing=run(['/opt/homebrew/bin/pg_restore','--list',str(backup)]);decoded=run(['/opt/homebrew/bin/pg_restore','--file=/dev/null',str(backup)])
        private_write(r.directory/'backup-list.log',listing.stdout.decode(errors='replace'));private_write(r.directory/'backup-decode.log',decoded.stderr.decode(errors='replace'))
        if listing.returncode or decoded.returncode:raise ValueError('BACKUP_DECODE_FAILED')
        if r.snapshot('after-backup')!=before:raise ValueError('PILOT_CHANGED_DURING_BACKUP_NO_APPLY')
        db='avaryn_pilot004_restore_'+r.stamp.lower()
        # Name is generated here; no arbitrary database name or existing restore target.
        created=run(['docker','exec','-i',LOCAL_CONTAINER,'psql','-X','-q','-w','-U','supabase_admin','-d','postgres','-v','ON_ERROR_STOP=1'],input=('create database '+db+' owner postgres template template0;').encode())
        private_write(r.directory/'create-scratch-stderr.log',created.stderr.decode(errors='replace'))
        if created.returncode:raise ValueError('NEW_LOCAL_DATABASE_FAILED_NO_RETRY')
        with backup.open('rb') as handle:p=subprocess.run(['docker','exec','-i',LOCAL_CONTAINER,'pg_restore','-U','supabase_admin','-d',db,'--single-transaction','--exit-on-error'],stdin=handle,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=180)
        private_write(r.directory/'restore-stdout.log',p.stdout.decode(errors='replace'));private_write(r.directory/'restore-stderr.log',p.stderr.decode(errors='replace'))
        if p.returncode:raise ValueError('REAL_RESTORE_FAILED_RETAINED_NO_RETRY')
    else:
        previous=check_private(resume,directory=True)
        pin=json.loads(check_private(previous/'resume-pin.json').read_text())
        old_before=json.loads(check_private(previous/'before-snapshot.json').read_text())
        backup=check_private(previous/'pilot47-before004.dump')
        db='avaryn_pilot004_restore_'+previous.name.rsplit('-',1)[1].lower()
        if not re.fullmatch(r'avaryn_pilot004_restore_\d{8}t\d{6}z',db):raise ValueError('RESUME_TARGET_NAME_INVALID')
        if (pin.get('source_sha256')!=SOURCE_SHA or pin.get('backup_sha256')!=sha(backup.read_bytes())
            or pin.get('baseline_snapshot_sha256')!=digest_json(old_before) or pin.get('database')!=db):raise ValueError('RESUME_PIN_MISMATCH')
        # Raw remote ACLs must still be identical to the original failed run.
        # Only restore comparison changes representation; no changed grant passes.
        if ({k:v for k,v in old_before.items() if k not in('catalog','table_security')}!={k:v for k,v in before.items() if k not in('catalog','table_security')}
            or r.remote(readonly(RAW_CATALOG),'resume-raw-catalog')!=old_before['catalog']
            or r.remote(readonly(RAW_TABLE_SECURITY),'resume-raw-table-security')!=old_before['table_security']):raise ValueError('RESUME_REMOTE_BASELINE_CHANGED')
        decoded=run(['/opt/homebrew/bin/pg_restore','--file=/dev/null',str(backup)])
        private_write(r.directory/'resume-decode.log',decoded.stderr.decode(errors='replace'))
        if decoded.returncode:raise ValueError('RESUME_BACKUP_DECODE_FAILED')
    private_write(r.directory/'backup-reference.json',json.dumps({'path':str(backup),'sha256':sha(backup.read_bytes())},indent=2)+'\n')
    identity=parsed(local(readonly(IDENTITY),db));validate_identity(identity,False,db)
    if (parsed(local(readonly(HISTORY),db))!=before['history'] or parsed(local(fingerprint_sql(before['tables']),db))!=before['rows']
        or parsed(local(readonly(CATALOG),db))!=before['catalog'] or parsed(local(readonly(TABLE_SECURITY),db))!=before['table_security']):
        raise ValueError('RESTORED_COPY_DIFFERS_NO_APPLY')
    migration=migration_sql(r.plan['migration'],source_file(ROOT,SOURCE).read_bytes())
    p=local(migration,db);private_write(r.directory/'local004-stdout.log',p.stdout.decode());private_write(r.directory/'local004-stderr.log',p.stderr.decode(errors='replace'))
    if p.returncode:raise ValueError('LOCAL004_REHEARSAL_FAILED')
    local_after=parsed(local(readonly(CATALOG),db));assert_schema_delta(before['catalog'],local_after)
    if parsed(local(readonly(TABLE_SECURITY),db))!=before['table_security']:raise ValueError('TABLE_SECURITY_CHANGED')
    results=[]
    for name,_ in SQL_SUITES:
        p=run(['docker','exec','-i',LOCAL_CONTAINER,'psql','-X','-q','-A','-t','-w','-U','supabase_admin','-d',db,'-v','ON_ERROR_STOP=1'],input=test_sql(name).encode(),timeout=90)
        for suffix,v in [('stdout',p.stdout),('stderr',p.stderr)]:private_write(r.directory/(name+'-'+suffix+'.log'),v.decode(errors='replace'))
        row=test_result(name,p);results.append(row)
        if row['status']!='PASS':raise ValueError('LOCAL_SUITE_FAILED_'+name)
    if validate_history(parsed(local(readonly(HISTORY),db)),r.plan)!=48:raise ValueError('LOCAL_HISTORY_NOT48')
    rows=parsed(local(fingerprint_sql(before['tables']),db))
    if [a['relation'] for a,b in zip(before['rows'],rows) if a!=b]!=['supabase_migrations.schema_migrations']:
        raise ValueError('LOCAL_REHEARSAL_CHANGED_EXISTING_DATA')
    private_write(r.directory/'expected48-catalog.json',json.dumps(local_after,indent=2)+'\n')
    r.evidence({'status':'PASS_PREPARED47_TO48','baseline_snapshot_sha256':digest_json(before),'backup_sha256':sha(backup.read_bytes()),
        'backup_bytes':backup.stat().st_size,'backup_mode':'0600','actual_restore_database':db,'restored_tables':len(before['tables']),
        'expected_catalog_sha256':digest_json(local_after),'tests':results,'remote_writes':False,'fixture_seed':False,
        'limits':['Database backup excludes hosted Auth/SMTP/Edge configuration and Storage bytes.','Concurrent remote data changes invalidate this prepared baseline; do not restore over testers.']})


def apply(r,before,prepared):
    directory=check_private(prepared,directory=True)
    receipt=json.loads(check_private(directory/'receipt.json').read_text())
    baseline=json.loads(check_private(directory/'before-snapshot.json').read_text())
    catalog=json.loads(check_private(directory/'expected48-catalog.json').read_text())
    reference=json.loads(check_private(directory/'backup-reference.json').read_text())
    archive=check_private(Path(reference['path']))
    if (receipt.get('status')!='PASS_PREPARED47_TO48' or receipt.get('project_ref')!=REF or receipt.get('script_sha256')!=r.code_sha
        or receipt.get('plan_sha256')!=digest_json(r.plan) or receipt.get('migration_sha256')!=SOURCE_SHA
        or receipt.get('baseline_snapshot_sha256')!=digest_json(baseline) or receipt.get('backup_sha256')!=sha(archive.read_bytes()) or reference.get('sha256')!=receipt.get('backup_sha256')
        or receipt.get('expected_catalog_sha256')!=digest_json(catalog) or len(receipt.get('tests',[]))!=6
        or any(t['status']!='PASS' for t in receipt['tests'])):raise ValueError('PREPARED_PROOF_MISMATCH')
    if before['count']==48:
        if before['catalog']!=catalog or before['table_security']!=baseline['table_security']:raise ValueError('ALREADY48_SCHEMA_MISMATCH')
        r.evidence({'status':'ALREADY48_VERIFIED_NO_WRITE','remote_writes':False,'history_hashes_match':True});return
    if before!=baseline:raise ValueError('CURRENT_PILOT_CHANGED_NEW_BACKUP_REQUIRED')
    # Freeze source again after all read-only/prepared-proof checks.
    if source_plan()!=r.plan:raise ValueError('SOURCE_CHANGED_DURING_PREFLIGHT')
    # Recheck history while holding only its short transactional writer lock.
    expected=json.dumps(before['history'],separators=(',',':')).replace("'","''")
    history_guard="lock table supabase_migrations.schema_migrations in share row exclusive mode;\ndo $guard$begin if ("+HISTORY.rstrip(';')+") is distinct from '"+expected+"'::jsonb then raise exception 'HISTORY_CHANGED_BEFORE004';end if;end$guard$;\n"
    sql=migration_sql(r.plan['migration'],source_file(ROOT,SOURCE).read_bytes()).replace("set local statement_timeout='60s';","set local statement_timeout='60s';\n"+history_guard,1)
    r.remote(sql,'apply004',write=True,as_json=False)
    after=r.snapshot('after-apply')
    if (after['count']!=48 or after['catalog']!=catalog or after['table_security']!=baseline['table_security'] or after['tables']!=baseline['tables']):
        raise ValueError('POSTCOMMIT_SCHEMA_MISMATCH_NO_AUTOMATIC_RESTORE')
    changed=[a['relation'] for a,b in zip(baseline['rows'],after['rows']) if a!=b]
    if changed!=['supabase_migrations.schema_migrations']:raise ValueError('POSTCOMMIT_DATA_CHANGED_KEEP_EVIDENCE_NO_RETRY')
    r.evidence({'status':'PASS_REMOTE004_48','remote_writes':True,'only_migration':VERSION,'history_before':47,'history_after':48,
        'original47_hashes_preserved':True,'existing_tables_preserved':len(after['rows'])-1,'only_changed_table':changed[0],
        'backup_sha256':receipt['backup_sha256'],'expected_catalog_sha256':digest_json(catalog),'fixture_seed':False,
        'limits':['This is database schema/replay proof; managed authenticated UI/Edge acceptance remains separate.']})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--mode',choices=['preflight','prepare','apply'],required=True)
    p.add_argument('--prepared',type=Path);p.add_argument('--resume-restore',type=Path);p.add_argument('--root-reviewed',action='store_true');p.add_argument('--writes-paused',action='store_true');a=p.parse_args()
    if a.mode=='apply' and (not a.prepared or not a.root_reviewed or not a.writes_paused):p.error('apply requires reviewed prepared proof and coordinated write pause')
    if a.resume_restore and a.mode!='prepare':p.error('resume-restore is only valid for prepare')
    os.umask(0o077);r=Run(a.mode);before=r.snapshot('before')
    if a.mode=='preflight':r.evidence({'status':'PASS_READONLY'+str(before['count']),'history_count':before['count'],'snapshot_sha256':digest_json(before),'tables':len(before['tables']),'remote_writes':False});return
    if a.mode=='prepare':prepare(r,before,a.resume_restore)
    else:apply(r,before,a.prepared)


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print(json.dumps({'status':'BLOCKED','code':str(exc) if isinstance(exc,ValueError) else type(exc).__name__,'automatic_retry':False,'automatic_restore':False}));sys.exit(1)
