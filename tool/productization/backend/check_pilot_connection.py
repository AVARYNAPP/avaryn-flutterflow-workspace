#!/usr/bin/env python3
"""Exact AVARYN pilot read-only preflight. Never prints credentials or SQL rows."""
from pathlib import Path
import configparser
import datetime
import hashlib
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'.avaryn-local/productization-20260911/private/pilot-backend'
EVIDENCE=ROOT/'.avaryn-local/productization-20260911/evidence/pilot-backend'
REF='rvymglpkttlfwhqpmupp'
ORG='ufvwcbrvwbqmejwraend'


def configuration():
    p=BASE/'connection.json'
    c=json.loads(p.read_text())
    expected={'project_ref':REF,'organization_id':ORG,'connection_mode':'session',
              'host':'aws-1-eu-west-1.pooler.supabase.com','port':5432,'database':'postgres',
              'user':'postgres.'+REF,'sslmode':'verify-full',
              'pgservice':'avaryn_c010_pilot'}
    if any(c.get(k)!=v for k,v in expected.items()):
        raise ValueError('PILOT_IDENTITY_MISMATCH')
    for filename in [p,Path(c['pgservicefile']),Path(c['pgpassfile'])]:
        if (not filename.is_relative_to(BASE) or filename.is_symlink()
            or not filename.is_file() or filename.stat().st_mode&0o777!=0o600
            or any(parent.is_symlink() for parent in filename.parents)):
            raise ValueError('PRIVATE_CONFIGURATION_INVALID')
    if c.get('sslrootcert')!='system':
        cert=Path(c.get('sslrootcert',''))
        if (not cert.is_relative_to(BASE) or cert.is_symlink() or not cert.is_file()
            or cert.stat().st_mode&0o777!=0o600
            or any(parent.is_symlink() for parent in cert.parents)
            or hashlib.sha256(cert.read_bytes()).hexdigest()!=c.get('ca_sha256')):
            raise ValueError('PINNED_CA_INVALID')
    service=configparser.ConfigParser();service.read(c['pgservicefile'])
    if any(service[c['pgservice']].get(k)!=v for k,v in {
        'host':c['host'],'port':'5432','dbname':'postgres','user':c['user'],
        'sslmode':'verify-full','sslrootcert':c['sslrootcert'],'connect_timeout':'10'}.items()):
        raise ValueError('PILOT_SERVICE_MISMATCH')
    env={k:v for k,v in os.environ.items() if not k.startswith('PG')}
    env.update(PGSERVICEFILE=c['pgservicefile'],PGPASSFILE=c['pgpassfile'],
               PGSERVICE=c['pgservice'],PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000 -c lock_timeout=3000')
    return c,env


def private_write(path,data):
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:f.write(data)


def query(env,sql):
    completed=subprocess.run(['/opt/homebrew/bin/psql','-X','-q','-A','-t','-w','-v','ON_ERROR_STOP=1'],
                             input=sql,text=True,capture_output=True,env=env,timeout=45)
    return completed


def main():
    os.umask(0o077);c,env=configuration()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run=BASE/('read-preflight-'+stamp);run.mkdir(mode=0o700)
    sql=(ROOT/'tool/productization/backend/pilot_preflight.sql').read_text()
    result=query(env,sql)
    private_write(run/'stdout.log',result.stdout);private_write(run/'stderr.log',result.stderr)
    if result.returncode:
        reason=('TLS' if any(x in result.stderr.lower() for x in ['certificate','ssl','tls']) else
                'AUTH' if 'password authentication failed' in result.stderr.lower() else
                'NETWORK_OR_DATABASE_QUERY')
        safe={'status':'BLOCKED','project_ref':REF,'classification':reason,'exit_code':result.returncode,
              'private_run':str(run),'remote_writes':False}
    else:
        rows=[json.loads(line) for line in result.stdout.splitlines() if line.strip().startswith('{')]
        if len(rows)!=1:raise ValueError('PREFLIGHT_RESPONSE_INVALID')
        data=rows[0]
        tls=query(env,'\\conninfo\n')
        private_write(run/'client-tls-stdout.log',tls.stdout);private_write(run/'client-tls-stderr.log',tls.stderr)
        tls_lines=[line.strip() for line in tls.stdout.splitlines() if line.startswith('SSL connection (')]
        client_tls=tls.returncode==0 and len(tls_lines)==1
        more=query(env,"""begin read only; set local statement_timeout='15s';
select jsonb_build_object(
 'database',current_database(),'session_role',session_user,
 'cluster_name',current_setting('cluster_name',true),
 'server_address',inet_server_addr()::text,
 'system_identifier',case when has_function_privilege(current_user,'pg_catalog.pg_control_system()','EXECUTE')
   then (select system_identifier::text from pg_catalog.pg_control_system()) else null end,
 'postgres_attributes',(select jsonb_build_object('superuser',rolsuper,'createdb',rolcreatedb,'createrole',rolcreaterole,'replication',rolreplication,'bypassrls',rolbypassrls) from pg_roles where rolname=current_user),
 'exposed_schemas_role',(select jsonb_agg(setting) from pg_roles cross join lateral unnest(rolconfig) setting where rolname='authenticator' and setting like 'pgrst.db_schemas=%'),
 'auth_schema_owner',(select pg_get_userbyid(nspowner) from pg_namespace where nspname='auth'),
 'storage_schema_owner',(select pg_get_userbyid(nspowner) from pg_namespace where nspname='storage'));
commit;
""")
        private_write(run/'identity-stdout.log',more.stdout);private_write(run/'identity-stderr.log',more.stderr)
        if more.returncode:raise ValueError('IDENTITY_QUERY_FAILED_PRIVATE_LOG')
        identity=json.loads(more.stdout.strip())
        history=[]
        if data['migration_history_present']:
            h=query(env,"begin read only; set local statement_timeout='15s'; select coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name) order by version),'[]') from supabase_migrations.schema_migrations; commit;")
            private_write(run/'history-stdout.log',h.stdout);private_write(run/'history-stderr.log',h.stderr)
            if h.returncode:raise ValueError('HISTORY_QUERY_FAILED')
            history=json.loads(h.stdout.strip())
        fresh=(data['database']=='postgres' and data['auth_users']==0 and data['auth_identities']==0
               and data['storage_objects']==0 and data['storage_buckets']==[]
               and data['application_relations']==[] and history==[] and client_tls)
        prerequisites=(data['auth_uid_present'] and data['crypto_functions_present'] and data['btree_gist_available']
                       and set(data['required_roles'])=={'postgres','anon','authenticated','service_role','authenticator'})
        safe={'status':'PASS' if fresh and prerequisites else 'REVIEW_REQUIRED','project_ref':REF,'organization_id':ORG,
              'connection_host':c['host'],'connection_mode':'session','TLS_verification':'verify-full',
              'ca_sha256':c.get('ca_sha256'),'ca_mode':'system' if c['sslrootcert']=='system' else 'pinned-project-certificate',
              'preflight':data,'system_identifier':identity['system_identifier'],
              'client_tls_verified':client_tls,'client_tls':tls_lines,
              'postgres_hop_tls_note':'pg_stat_ssl describes Supavisor to PostgreSQL, not client to Supavisor',
              'postgres_attributes':identity['postgres_attributes'],'migration_history':history,
              'fresh_baseline':fresh,'prerequisites':prerequisites,'remote_writes':False,
              'private_run':str(run),'checked_at':stamp,
              'query_sha256':hashlib.sha256(sql.encode()).hexdigest()}
    private_write(run/'receipt.json',json.dumps(safe,indent=2)+'\n')
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    public={k:v for k,v in safe.items() if k!='private_run'}
    dest=EVIDENCE/('read-preflight-'+stamp+'.json')
    dest.write_text(json.dumps(public,indent=2)+'\n')
    print(json.dumps({'status':safe['status'],'project_ref':REF,'evidence':str(dest),
                      'remote_writes':False,'classification':safe.get('classification')}))


if __name__=='__main__':
    try:main()
    except Exception as e:
        # No subprocess exception repr/argv/env or libpq connection error on stdout.
        print(json.dumps({'status':'BLOCKED','code':str(e) if isinstance(e,ValueError) else type(e).__name__,
                          'remote_writes':False}))
        sys.exit(1)
