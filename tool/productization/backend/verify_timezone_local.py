#!/usr/bin/env python3
"""Six bounded rollback suites for the owned, already migrated dev backend.

No lifecycle actions, migration apply, reset, remote URLs or persistent fixtures.
The same suite list is reused for the pilot004 restored-copy rehearsal.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tool'))
import avaryn_local as local

TARGET='avaryn-c010-vitality-20260911-a'
MIGRATION_SHA='a9e47de0b01bb8fd407e354b1ea1a148d89455a53e79c70561aa13f6365b08bd'
SQL_SUITES=(
    ('c010_account_calendar_timezone',105),
    ('c010_calendar_windows',1),
    ('c010_personal_day',44),
    ('c010_rider_vitality',69),
    ('c010_flexible_task_timing',42),
    ('c010_connected_facilities',59),
)


def test_sql(name):
    if name not in dict(SQL_SUITES):raise ValueError('UNRECOGNIZED_SUITE')
    path=ROOT/'supabase/tests'/(name+'.sql')
    if path.is_symlink():raise ValueError('TEST_SYMLINK')
    data=path.read_text()
    if not data.startswith('begin;') or not data.strip().endswith('rollback;'):
        raise ValueError('ROLLBACK_TEST_SHAPE_CHANGED')
    # Extension installation, when needed on a restored copy, is also rolled back.
    return ("begin;set local lock_timeout='5s';set local statement_timeout='45s';"
            "create extension if not exists pgtap with schema extensions;set local role postgres;\n"
            +data[6:data.rfind('rollback;')]+"\nrollback;\n")


def test_result(name,result):
    stdout=result.stdout.decode() if isinstance(result.stdout,bytes) else result.stdout
    stderr=result.stderr.decode() if isinstance(result.stderr,bytes) else result.stderr
    lines=re.findall(r'(?m)^\s*((?:not )?ok \d+[^\n]*)',stdout)
    failed=sum(line.startswith('not ') for line in lines)
    passed=(result.returncode==0 and len(lines)==dict(SQL_SUITES)[name] and not failed
            and not re.search(r'Looks like you failed|planned \d+ tests but ran',stdout+'\n'+stderr))
    return {'suite':name,'status':'PASS' if passed else 'FAIL','assertions':len(lines),'failed':failed,
            'exit_code':result.returncode,'source_sha256':hashlib.sha256((ROOT/'supabase/tests'/(name+'.sql')).read_bytes()).hexdigest()}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--target',required=True);p.add_argument('--state-dir',required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    if args.target!=TARGET:p.error('only the explicitly owned vitality development target is supported')
    cfg=local.load_context(args);local.verify_container(cfg,'db')
    if cfg['ports']['api']!=56801 or cfg['ports']['db']!=56802:raise ValueError('DEV_PORT_IDENTITY_CHANGED')
    actual=local.sql(cfg,"select sha256 from avaryn_local_meta.migrations where version='202609110004';").stdout.strip()
    if actual!=MIGRATION_SHA:raise ValueError('004_MUST_ALREADY_BE_APPLIED')
    log=cfg['state']/'timezone-test-logs';log.mkdir(mode=0o700,exist_ok=True);results=[]
    for name,_ in SQL_SUITES:
        r=local.sql(cfg,test_sql(name),check=False)
        for suffix,value in [('stdout',r.stdout),('stderr',r.stderr)]:
            path=log/(name+'.'+suffix);path.write_text(value);path.chmod(0o600)
        row=test_result(name,r);results.append(row);print(json.dumps(row),flush=True)
        if row['status']!='PASS':break
    receipt={'status':'PASS' if len(results)==len(SQL_SUITES) and all(r['status']=='PASS' for r in results) else 'FAIL','target':TARGET,'suites':results,'remote_writes':False,'fixture_transactions':'rollback'}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(receipt,indent=2)+'\n')
    return 0 if receipt['status']=='PASS' else 1


if __name__=='__main__':sys.exit(main())
