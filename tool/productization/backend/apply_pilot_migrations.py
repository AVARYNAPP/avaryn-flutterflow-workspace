#!/usr/bin/env python3
"""Exact 47-migration rehearsal or controlled fresh-pilot apply; never seeds.

Remote mode requires a matching successful local rehearsal receipt and its
verified remote baseline backup. Every migration+standard history row is one
transaction. Ambiguous/failing results stop, never retry or repair history.
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

from check_pilot_connection import ROOT,BASE,EVIDENCE,REF,configuration,private_write
from backup_pilot_database import REMOTE_CLUSTER,LOCAL_CLUSTER,LOCAL_CONTAINER,LOCAL_CONTAINER_ID,LOCAL_TARGET,local,parsed,run
from prepare_pilot_release import verify_manifest,source_file

LEDGER="""create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations(
 version text primary key,statements text[],name text);
"""
CATALOG="""select coalesce(jsonb_agg(to_jsonb(r) order by kind,identity),'[]') from (
 select 'function'::text kind,n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' identity,
  pg_get_userbyid(p.proowner) owner,md5(pg_get_functiondef(p.oid)) body_hash,
  p.proacl::text acl,to_jsonb(p.proconfig) config
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','private') and p.prokind='f'
 union all
 select 'policy',n.nspname||'.'||c.relname||'.'||p.polname,pg_get_userbyid(c.relowner),
  md5(jsonb_build_object('command',p.polcmd,'permissive',p.polpermissive,'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),
    'roles',(select jsonb_agg(case when role_id=0 then 'PUBLIC' else pg_get_userbyid(role_id) end order by case when role_id=0 then 'PUBLIC' else pg_get_userbyid(role_id) end) from unnest(p.polroles) role_id))::text),
  c.relacl::text,jsonb_build_object('rls',c.relrowsecurity,'force',c.relforcerowsecurity)
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in('public','private','storage','auth')
) r;"""


def quoted(value,tag):
    delimiter='$avaryn_'+tag+'$'
    if delimiter in value:raise ValueError('SQL_DELIMITER_COLLISION')
    return delimiter+value+delimiter


def migration_sql(item,data,first=False):
    original=data.decode('utf8')
    controls=[m for m in re.finditer(r'(?mi)^(begin|commit);[ \t]*$',original)]
    if item['transaction_wrapper']=='source':
        if [m.group(1).lower() for m in controls]!=['begin','commit']:raise ValueError('TRANSACTION_SHAPE_CHANGED')
        a,b=controls;body=original[:a.start()]+original[a.end():b.start()]+original[b.end():]
    else:
        if controls:raise ValueError('UNEXPECTED_TRANSACTION_CONTROL')
        body=original
    # Original bytes are retained in the standard statements[] history field.
    # Only reviewed outer BEGIN/COMMIT markers are replaced for atomic ledgering.
    history=("insert into supabase_migrations.schema_migrations(version,name,statements) values ("
       +quoted(item['version'],'version')+','+quoted(item['name'],'name')+',array['
       +quoted(original,item['sha256'])+"]);\n")
    return "begin;\nset local lock_timeout='5s';\nset local statement_timeout='60s';\n"+(LEDGER if first else '')+body+'\n'+history+'commit;\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',choices=['local-rehearsal','remote-fresh'],required=True)
    parser.add_argument('--backup-run',type=Path,required=True)
    parser.add_argument('--rehearsal-receipt',type=Path)
    args=parser.parse_args();os.umask(0o077)
    manifest=json.loads((ROOT/'tool/productization/backend/pilot-release-manifest.json').read_text());verify_manifest(manifest)
    directory=args.backup_run.resolve()
    if not directory.is_relative_to(BASE) or any(p.is_symlink() for p in [directory,*directory.parents]):raise ValueError('BACKUP_SCOPE_INVALID')
    backup_receipt=json.loads((directory/'local-restore-corrected/receipt.json').read_text())
    if backup_receipt.get('status')!='PASS_FULL_DATABASE_BACKUP_AND_REAL_LOCAL_RESTORE' or backup_receipt.get('remote_cluster')!=REMOTE_CLUSTER:
        raise ValueError('BACKUP_GATE_NOT_PASSED')
    if hashlib.sha256((directory/'pilot-before-bootstrap.dump').read_bytes()).hexdigest()!=backup_receipt['backup_sha256']:
        raise ValueError('BACKUP_HASH_CHANGED')
    remote=args.mode=='remote-fresh';dbname=backup_receipt['database']
    if not re.fullmatch('avaryn_pilot_restore_[0-9]{8}t[0-9]{6}z',dbname):raise ValueError('LOCAL_REHEARSAL_SCOPE_INVALID')
    if remote:
        if not args.rehearsal_receipt:raise ValueError('REHEARSAL_RECEIPT_REQUIRED')
        rehearsal=json.loads(args.rehearsal_receipt.read_text())
        if (rehearsal.get('status')!='PASS_LOCAL_47_REHEARSAL' or rehearsal.get('source_manifest_sha256')!=manifest['source_manifest_sha256']
            or rehearsal.get('backup_sha256')!=backup_receipt['backup_sha256']):raise ValueError('LOCAL_REHEARSAL_NOT_MATCHED')
        c,env=configuration();env['PGOPTIONS']='-c default_transaction_read_only=off -c statement_timeout=60000 -c lock_timeout=5000'
        def execute(sql):return subprocess.run(['/opt/homebrew/bin/psql','-X','-q','-A','-t','-w','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True,env=env,timeout=90)
    else:
        container=parsed(run(['docker','inspect',LOCAL_CONTAINER]))[0]
        if container['Id']!=LOCAL_CONTAINER_ID or container['Config']['Labels'].get('io.avaryn.local.target')!=LOCAL_TARGET:
            raise ValueError('LOCAL_TARGET_MISMATCH')
        def execute(sql):return local(sql,dbname)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run_dir=directory/(args.mode+'-'+stamp);run_dir.mkdir(mode=0o700)
    def capture(sql,name):
        result=execute(sql);private_write(run_dir/(name+'-stdout.log'),result.stdout.decode(errors='replace'));private_write(run_dir/(name+'-stderr.log'),result.stderr.decode(errors='replace'));return result
    identity=parsed(capture("begin read only; select jsonb_build_object('cluster',(select system_identifier::text from pg_control_system()),'database',current_database(),'role',current_user,'superuser',(select rolsuper from pg_roles where rolname=current_user),'auth_users',(select count(*) from auth.users),'objects',(select count(*) from storage.objects),'buckets',(select count(*) from storage.buckets),'history',to_regclass('supabase_migrations.schema_migrations'),'application_relations',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','private') and c.relkind in('r','p'))); commit;",'pre-identity'))
    if (identity['cluster']!=(REMOTE_CLUSTER if remote else LOCAL_CLUSTER) or identity['database']!=('postgres' if remote else dbname)
        or identity['role']!='postgres' or identity['superuser'] or identity['auth_users'] or identity['objects'] or identity['buckets']
        or identity['history'] is not None or identity['application_relations']):raise ValueError('FRESH_IDENTITY_OR_EMPTY_BASELINE_CHANGED')
    outcomes=[]
    for index,item in enumerate(manifest['migrations']):
        data=source_file(ROOT,item['path']).read_bytes()
        if hashlib.sha256(data).hexdigest()!=item['sha256']:raise ValueError('MIGRATION_HASH_CHANGED')
        sql=migration_sql(item,data,first=index==0)
        result=capture(sql,'migration-'+item['version'])
        outcomes.append({'version':item['version'],'source_sha256':item['sha256'],'executor_sha256':hashlib.sha256(sql.encode()).hexdigest(),'exit_code':result.returncode})
        private_write(run_dir/('progress-'+str(index+1)+'.json'),json.dumps(outcomes,indent=2)+'\n')
        if result.returncode:raise ValueError('MIGRATION_FAILED_'+item['version']+'_STOPPED_NO_RETRY')
        if (index+1)%5==0 or index==46:print(json.dumps({'mode':args.mode,'applied':index+1,'total':47}),flush=True)
    history=parsed(capture("begin read only; select jsonb_agg(jsonb_build_object('version',version,'name',name,'sha256',encode(extensions.digest(convert_to(statements[1],'UTF8'),'sha256'),'hex')) order by version) from supabase_migrations.schema_migrations; commit;",'post-history'))
    expected=[{'version':r['version'],'name':r['name'],'sha256':r['sha256']} for r in manifest['migrations']]
    if history!=expected:raise ValueError('APPLIED_HISTORY_MISMATCH')
    post=capture((ROOT/'tool/productization/backend/pilot_postflight.sql').read_text(),'postflight')
    if post.returncode:raise ValueError('POSTFLIGHT_FAILED')
    facts=json.loads(post.stdout.decode().splitlines()[0])
    if any(facts[k]!=0 for k in ['auth_users','profiles','organizations','canonical_horses','storage_objects','vitality_days','vitality_receipts']):
        raise ValueError('UNEXPECTED_APPLICATION_DATA')
    if (facts['migration_count']!=47 or facts['private_vitality_direct_client_read'] or facts['private_vitality_direct_client_write']
        or facts['vitality_anon_execute'] or not facts['vitality_authenticated_execute'] or facts['deletion_prepare_client_execute']
        or not facts['deletion_prepare_service_execute'] or any(b['public'] for b in facts['storage_buckets'])):
        raise ValueError('POSTFLIGHT_SECURITY_CONTRACT_FAILED')
    catalog=parsed(capture('begin read only; '+CATALOG+' commit;','post-catalog'))
    catalog_sha=hashlib.sha256(json.dumps(catalog,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if remote and catalog_sha!=rehearsal['catalog_sha256']:raise ValueError('REMOTE_SCHEMA_DIFFERS_FROM_REHEARSAL')
    if remote:capture("notify pgrst,'reload schema';",'schema-reload')
    receipt={'status':'PASS_REMOTE_47_APPLY' if remote else 'PASS_LOCAL_47_REHEARSAL','project_ref':REF,
       'source_manifest_sha256':manifest['source_manifest_sha256'],'backup_sha256':backup_receipt['backup_sha256'],
       'catalog_sha256':catalog_sha,'catalog_objects':len(catalog),'database':identity['database'],'cluster':identity['cluster'],
       'migration_count':47,'history_hashes_match':True,'migration_results':outcomes,'postflight':facts,
       'remote_writes':remote,'fixture_seed':False,'executed_as_superuser':False,'checked_at':stamp,
       'limits':['Remote Auth/Edge/Storage-byte acceptance remains separate.','Database backup does not include hosted Auth/SMTP/Edge configuration.']}
    private_write(run_dir/'receipt.json',json.dumps(receipt,indent=2)+'\n')
    output=EVIDENCE/(args.mode+'-'+stamp+'.json');output.write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'status':receipt['status'],'evidence':str(output),'catalog_sha256':catalog_sha,'remote_writes':remote}))


if __name__=='__main__':
    try:main()
    except Exception as e:
        print(json.dumps({'status':'BLOCKED','code':str(e) if isinstance(e,ValueError) else type(e).__name__,'automatic_retry':False}));sys.exit(1)
