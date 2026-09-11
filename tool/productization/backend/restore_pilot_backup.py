#!/usr/bin/env python3
"""Resume only the documented own partial restore; no remote network or writes."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from backup_pilot_database import (BASE,EVIDENCE,REF,REMOTE_CLUSTER,LOCAL_TARGET,
    LOCAL_CONTAINER,LOCAL_CONTAINER_ID,LOCAL_CLUSTER,CATALOG,run,local,parsed,
    qid,lit,fingerprint_sql,private_write)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backup-run',type=Path,required=True)
    parser.add_argument('--retry-own-partial',action='store_true',required=True)
    args=parser.parse_args();directory=args.backup_run.resolve()
    if not directory.is_relative_to(BASE) or directory.is_symlink():raise ValueError('BACKUP_SCOPE_INVALID')
    marker=json.loads((directory/'restore-target.json').read_text());backup=directory/'pilot-before-bootstrap.dump'
    if any(marker[k]!=v for k,v in {'local_target':LOCAL_TARGET,'local_container_id':LOCAL_CONTAINER_ID,
        'local_cluster':LOCAL_CLUSTER,'remote_project_ref':REF,'remote_cluster':REMOTE_CLUSTER,
        'restores_over_existing_database':False,'remote_writes':False}.items()):raise ValueError('RESTORE_MARKER_INVALID')
    dbname=marker['database']
    if not re.fullmatch('avaryn_pilot_restore_[0-9]{8}t[0-9]{6}z',dbname):raise ValueError('DATABASE_SCOPE_INVALID')
    if hashlib.sha256(backup.read_bytes()).hexdigest()!=marker['backup_sha256'] or backup.stat().st_mode&0o777!=0o600:
        raise ValueError('BACKUP_HASH_OR_MODE_INVALID')
    inspected=parsed(run(['docker','inspect',LOCAL_CONTAINER]))[0]
    if inspected['Id']!=LOCAL_CONTAINER_ID or inspected['Config']['Labels'].get('io.avaryn.local.target')!=LOCAL_TARGET:
        raise ValueError('LOCAL_CONTAINER_CHANGED')
    check=parsed(local("select jsonb_build_object('cluster',(select system_identifier::text from pg_control_system()),'owner',(select pg_get_userbyid(datdba) from pg_database where datname="+lit(dbname)+"),'connections',(select count(*) from pg_stat_activity where datname="+lit(dbname)+"),'local_postgres_superuser',(select rolsuper from pg_roles where rolname='postgres'))"))
    if check['cluster']!=LOCAL_CLUSTER or check['owner']!='postgres' or check['connections']!=0:
        raise ValueError('OWN_SCRATCH_DATABASE_STATE_CHANGED')
    if not (directory/'restore-stderr.log').exists():raise ValueError('PRIOR_RESTORE_PROOF_MISSING')
    retry=directory/'local-restore-corrected';retry.mkdir(mode=0o700)
    # Only this script's failed, unused scratch is recreated. Never postgres,
    # another local target, a user-provided name, or a remote database.
    for sql in ['drop database '+qid(dbname)+';','create database '+qid(dbname)+' template template0;']:
        result=local(sql)
        if result.returncode:raise ValueError('OWN_SCRATCH_RECREATE_FAILED')
    with backup.open('rb') as stream:
        restored=subprocess.run(['docker','exec','-i',LOCAL_CONTAINER,'pg_restore','--single-transaction','--exit-on-error','--no-password','--username=supabase_admin','--dbname='+dbname],stdin=stream,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=240)
    private_write(retry/'stdout.log',restored.stdout.decode(errors='replace'));private_write(retry/'stderr.log',restored.stderr.decode(errors='replace'))
    if restored.returncode:raise ValueError('ATOMIC_LOCAL_RESTORE_FAILED')
    tables=json.loads((directory/'before-catalog.json').read_text());before=json.loads((directory/'before-table-hashes.json').read_text())
    restored_tables=parsed(local('begin read only; '+CATALOG+' commit;',dbname));restored_rows=parsed(local(fingerprint_sql(tables),dbname))
    private_write(retry/'catalog.json',json.dumps(restored_tables,indent=2)+'\n');private_write(retry/'table-hashes.json',json.dumps(restored_rows,indent=2)+'\n')
    if tables!=restored_tables or before!=restored_rows:raise ValueError('LOCAL_RESTORE_MISMATCH')
    receipt={**marker,'status':'PASS_FULL_DATABASE_BACKUP_AND_REAL_LOCAL_RESTORE','backup_bytes':backup.stat().st_size,
      'backup_mode':'0600','table_hashes_compared':len(before),'catalog_owners_match':True,
      'local_postgres_superuser':check['local_postgres_superuser'],'restore_role':'supabase_admin',
      'existing_local_application_database_modified':False,'remote_writes':False,
      'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
      'limits':['Storage objects were empty; no object bytes required restoring.','Auth/SMTP/Edge config needs separate management backup.','Initial failed restore preserved in logs; corrected restore is atomic and uses existing local admin only.']}
    private_write(retry/'receipt.json',json.dumps(receipt,indent=2)+'\n')
    out=EVIDENCE/('baseline-backup-restored-'+marker['created_at']+'.json');out.write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'status':receipt['status'],'table_hashes_compared':len(before),'backup_sha256':marker['backup_sha256'],'evidence':str(out),'remote_writes':False}))


if __name__=='__main__':
    try:main()
    except Exception as e:
        print(json.dumps({'status':'BLOCKED','code':str(e) if isinstance(e,ValueError) else type(e).__name__,'remote_writes':False}));sys.exit(1)
