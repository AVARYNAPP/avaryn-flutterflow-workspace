#!/usr/bin/env python3
"""Remote read-only backup, then real restore to ONE new own local database.

No remote writes or migration apply. No restore over an existing database. The
local 47-migration application database and its users/data remain untouched.
"""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys

from check_pilot_connection import ROOT,BASE,EVIDENCE,REF,configuration,private_write,query

REMOTE_CLUSTER='7678069749886157684'
LOCAL_TARGET='avaryn-c010-vitality-20260911-a'
LOCAL_CONTAINER=LOCAL_TARGET+'-db'
LOCAL_CLUSTER='7684330901039525928'
LOCAL_CONTAINER_ID='a0fe4d12515e6fb4121966a0dffd46ef136f0a7fcf622b25e31ce17128e75f1e'
PG='/opt/homebrew/bin/'
CATALOG="""select coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'owner',pg_get_userbyid(c.relowner),'kind',c.relkind) order by n.nspname,c.relname),'[]')
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
 and c.relkind in ('r','p') and not exists(select 1 from pg_depend d
 where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e');"""


def run(argv,*,input=None,env=None,timeout=90):
    return subprocess.run(argv,input=input,capture_output=True,env=env,timeout=timeout)


def local(sql,database='postgres'):
    return run(['docker','exec','-i',LOCAL_CONTAINER,'psql','-X','-q','-A','-t','-w','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=sql.encode())


def parsed(result):
    if result.returncode:raise ValueError('DATABASE_QUERY_FAILED_PRIVATE_LOG')
    return json.loads(result.stdout.decode().strip() if isinstance(result.stdout,bytes) else result.stdout.strip())


def qid(value):return '"'+value.replace('"','""')+'"'
def lit(value):return "'"+value.replace("'","''")+"'"


def fingerprint_sql(tables):
    parts=[]
    for row in tables:
        name=row['schema']+'.'+row['name'];qualified=qid(row['schema'])+'.'+qid(row['name'])
        parts.append(f"select {lit(name)} as relation,count(*)::bigint as rows,md5(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),'')) as md5 from {qualified} t")
    return "begin read only; set local statement_timeout='30s'; select coalesce(jsonb_agg(to_jsonb(x) order by relation),'[]') from ("+' union all '.join(parts)+") x; commit;"


def main():
    os.umask(0o077);c,env=configuration()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    directory=BASE/('baseline-backup-'+stamp);directory.mkdir(mode=0o700)
    # Pin both ends before even the local CREATE DATABASE.
    identity=parsed(query(env,"begin read only; select jsonb_build_object('cluster',(select system_identifier::text from pg_control_system()),'database',current_database(),'auth_users',(select count(*) from auth.users),'identities',(select count(*) from auth.identities),'objects',(select count(*) from storage.objects),'buckets',(select count(*) from storage.buckets),'history',to_regclass('supabase_migrations.schema_migrations')); commit;"))
    if identity!={'cluster':REMOTE_CLUSTER,'database':'postgres','auth_users':0,'identities':0,'objects':0,'buckets':0,'history':None}:
        private_write(directory/'unexpected-identity.json',json.dumps(identity,indent=2));raise ValueError('REMOTE_BASELINE_CHANGED')
    inspected=run(['docker','inspect',LOCAL_CONTAINER]);container=parsed(inspected)[0]
    if (container['Id']!=LOCAL_CONTAINER_ID or not container['State']['Running']
        or container['Config']['Labels'].get('io.avaryn.local.target')!=LOCAL_TARGET
        or container['NetworkSettings']['Ports'].get('5432/tcp')!=[{'HostIp':'127.0.0.1','HostPort':'56802'}]
        or not any(m['Name']==LOCAL_TARGET+'-db' for m in container['Mounts'] if m['Type']=='volume')):
        raise ValueError('LOCAL_RESTORE_TARGET_MISMATCH')
    local_identity=parsed(local("begin read only; select jsonb_build_object('cluster',(select system_identifier::text from pg_control_system()),'version',current_setting('server_version')); commit;"))
    if local_identity['cluster']!=LOCAL_CLUSTER:raise ValueError('LOCAL_CLUSTER_MISMATCH')
    tables=parsed(query(env,'begin read only; '+CATALOG+' commit;'))
    if any(row['schema'] in ('public','private') for row in tables):raise ValueError('REMOTE_APP_NOT_EMPTY')
    before_result=query(env,fingerprint_sql(tables));before=parsed(before_result)
    private_write(directory/'before-table-hashes.json',json.dumps(before,indent=2)+'\n')
    private_write(directory/'before-catalog.json',json.dumps(tables,indent=2)+'\n')
    # Full custom archive: no schema/data exclusions and no standard CLI dump.
    backup=directory/'pilot-before-bootstrap.dump'
    fd=os.open(backup,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'wb') as output:
        dumped=subprocess.run([PG+'pg_dump','-w','--format=custom'],stdout=output,stderr=subprocess.PIPE,env=env,timeout=240)
    private_write(directory/'dump-stderr.log',dumped.stderr.decode(errors='replace'))
    if dumped.returncode or backup.stat().st_size<10000:raise ValueError('FULL_DUMP_FAILED')
    sha=hashlib.sha256(backup.read_bytes()).hexdigest()
    listed=run([PG+'pg_restore','--list',str(backup)]);private_write(directory/'archive-list.log',listed.stdout.decode(errors='replace'))
    decoded=run([PG+'pg_restore','--file=/dev/null',str(backup)],timeout=120)
    private_write(directory/'archive-decode-stderr.log',decoded.stderr.decode(errors='replace'))
    if listed.returncode or decoded.returncode:raise ValueError('ARCHIVE_VALIDATION_FAILED')
    after=parsed(query(env,fingerprint_sql(tables)))
    if before!=after:raise ValueError('REMOTE_ROWS_CHANGED_DURING_BACKUP')
    # The unique new database lives on the already owned isolated cluster only.
    dbname='avaryn_pilot_restore_'+stamp.lower()
    if not re.fullmatch('avaryn_pilot_restore_[0-9]{8}t[0-9]{6}z',dbname):raise ValueError('RESTORE_DATABASE_INVALID')
    marker={'local_target':LOCAL_TARGET,'local_container_id':LOCAL_CONTAINER_ID,'local_cluster':LOCAL_CLUSTER,
            'database':dbname,'remote_project_ref':REF,'remote_cluster':REMOTE_CLUSTER,'backup_sha256':sha,
            'created_at':stamp,'restores_over_existing_database':False,'remote_writes':False}
    private_write(directory/'restore-target.json',json.dumps(marker,indent=2)+'\n')
    exists=parsed(local('select jsonb_build_object(\'exists\',exists(select 1 from pg_database where datname='+lit(dbname)+'));'))
    if exists['exists']:raise ValueError('RESTORE_DATABASE_ALREADY_EXISTS')
    created=local('create database '+qid(dbname)+' template template0;')
    private_write(directory/'create-local-stderr.log',created.stderr.decode(errors='replace'))
    if created.returncode:raise ValueError('LOCAL_CREATE_FAILED')
    with backup.open('rb') as source:
        restored=subprocess.run(['docker','exec','-i',LOCAL_CONTAINER,'pg_restore','--single-transaction','--exit-on-error','--no-password','--username=supabase_admin','--dbname='+dbname],stdin=source,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=240)
    private_write(directory/'restore-stdout.log',restored.stdout.decode(errors='replace'));private_write(directory/'restore-stderr.log',restored.stderr.decode(errors='replace'))
    if restored.returncode:raise ValueError('LOCAL_RESTORE_FAILED_PRESERVED_FOR_DIAGNOSIS')
    restored_tables=parsed(local('begin read only; '+CATALOG+' commit;',dbname))
    restored_rows=parsed(local(fingerprint_sql(tables),dbname))
    private_write(directory/'restored-catalog.json',json.dumps(restored_tables,indent=2)+'\n')
    private_write(directory/'restored-table-hashes.json',json.dumps(restored_rows,indent=2)+'\n')
    if restored_rows!=before or restored_tables!=tables:raise ValueError('RESTORE_COMPARISON_FAILED')
    receipt={**marker,'status':'PASS_FULL_DATABASE_BACKUP_AND_REAL_LOCAL_RESTORE','backup_bytes':backup.stat().st_size,
             'backup_file_mode':'0600','table_hashes_compared':len(before),'table_catalog_owners_match':True,
             'source_remote_rows_unchanged':True,'auth_users':0,'storage_objects':0,
             'local_existing_application_database_modified':False,'restore_database_retained_for_rehearsal':True,
             'limitations':['Database archive contains no Storage bytes; Storage objects were verified empty.',
              'Hosted Auth/SMTP/Edge configuration is outside this database backup and needs separate management access.',
              'Restore administration uses local supabase_admin to preserve owners; application rehearsal must run as postgres.']}
    private_write(directory/'receipt.json',json.dumps(receipt,indent=2)+'\n')
    EVIDENCE.mkdir(parents=True,exist_ok=True);out=EVIDENCE/('baseline-backup-restore-'+stamp+'.json');out.write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'status':receipt['status'],'evidence':str(out),'backup_sha256':sha,'remote_writes':False}))


if __name__=='__main__':
    try:main()
    except Exception as e:
        print(json.dumps({'status':'BLOCKED','code':str(e) if isinstance(e,ValueError) else type(e).__name__,'remote_writes':False}));sys.exit(1)
