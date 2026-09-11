#!/usr/bin/env python3
"""Two deterministic deletion/succession races in a newly owned scratch DB.

The existing exact local container is verified by the rollback gate. Only its
schema is copied (no rows, keys, sessions or credentials). A new scratch HMAC
and synthetic accounts are generated. Winner commits only inside scratch; the
exact ownership-marked scratch database is dropped after evidence is captured.
"""
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time
import uuid
import verify_archived_horse_transfer as gate

def psql(database,text,check=True,timeout=40,user='postgres'):
    command=['docker','exec','-i',gate.CONTAINER_ID,'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-U',user,'-d',database]
    result=subprocess.run(command,input=text,text=True,capture_output=True,timeout=timeout)
    if check and result.returncode:raise RuntimeError('SCRATCH_SQL_FAILED')
    return result

def claim(actor,role='authenticated'):
    return "set local role "+role+"; do $$ begin perform set_config('request.jwt.claim.role','"+role+"',true); perform set_config('request.jwt.claim.sub','"+actor+"',true); end $$;"

def main():
    run_id=uuid.uuid4().hex;database='c010_archhorse_'+run_id[:20]
    marker='avaryn-archived-horse-race:'+run_id+':'+gate.CLUSTER
    private=gate.BASE/'private/archived-horse-transfer'/run_id;private.mkdir(parents=True,mode=0o700)
    report={'status':'FAIL','mode':'isolated-scratch-races','scratchDatabase':database,'cases':[],'mainDatabaseUnchanged':False,'scratchDropped':False}
    created=False;main_before=None
    def log(name,text):
        fd=os.open(private/name,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
        with os.fdopen(fd,'w') as file:file.write(text)
    def fixture(label):
        owner,recipient=[str(uuid.uuid4()) for _ in range(2)]
        query=f"""begin;
        create temporary table values_for_case(key text primary key,value jsonb); grant all on values_for_case to authenticated;
        insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
        select '00000000-0000-0000-0000-000000000000',v.id::uuid,'authenticated','authenticated',v.id||'@archhorse-race.invalid','',now(),'{{}}','{{}}',now(),now()
        from (values('{owner}'),('{recipient}')) v(id);
        insert into values_for_case values('profiles',(select jsonb_object_agg(auth_user_id,id) from public.profiles where auth_user_id in('{owner}','{recipient}')));
        {claim(owner)}
        insert into values_for_case select 'horse',to_jsonb(h) from public.create_canonical_horse_profile('Scratch archive {label}',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid()) h;
        select public.update_canonical_horse_profile((select (value->>'horse_id')::uuid from values_for_case where key='horse'),1,'Scratch archive {label}',null,null,'unknown',null,null,null,null,null,null,null,null,'archived',gen_random_uuid());
        insert into values_for_case select 'transfer',to_jsonb(t) from public.initiate_horse_authority_transfer(
          (select (value->>'horse_id')::uuid from values_for_case where key='horse'),
          (select (value->>'{recipient}')::uuid from values_for_case where key='profiles'),gen_random_uuid()) t;
        select jsonb_object_agg(key,value) from values_for_case; commit;"""
        result=psql(database,query,False);log(label+'-fixture.log',result.stdout+'\n'+result.stderr)
        gate.check(result.returncode==0,'SCRATCH_FIXTURE_FAILED')
        data=json.loads([line for line in result.stdout.splitlines() if line.startswith('{')][-1])
        return {'owner':owner,'recipient':recipient,'owner_profile':data['profiles'][owner],'recipient_profile':data['profiles'][recipient],
                'horse':data['horse']['horse_id'],'transfer':data['transfer']['transfer_id'],'token':data['transfer']['transfer_token']}
    try:
        report['identity']=gate.inspect_target();main_before=gate.snapshot()
        gate.check(len(main_before['ledger'])==48 and '202609110005' not in main_before['ledger'],'BASELINE_MIGRATIONS_MISMATCH')
        for version,digest in main_before['ledger'].items():
            paths=list((gate.ROOT/'supabase/migrations').glob(version+'_*.sql'))
            gate.check(len(paths)==1 and hashlib.sha256(paths[0].read_bytes()).hexdigest()==digest,'BASELINE_SOURCE_DRIFT')
        report['migrationSha256']=hashlib.sha256(gate.MIGRATION.read_bytes()).hexdigest()
        # Schema-only, five named namespaces, no data or role/password dump.
        dump=subprocess.run(['docker','exec',gate.CONTAINER_ID,'pg_dump','-U','postgres','-d','postgres','--schema-only',
          '--schema=public','--schema=private','--schema=auth','--schema=storage','--schema=extensions'],capture_output=True,text=True,timeout=30)
        gate.check(dump.returncode==0,'SCHEMA_DUMP_FAILED')
        report['schemaDumpSha256']=hashlib.sha256(dump.stdout.encode()).hexdigest();report['schemaDumpBytes']=len(dump.stdout.encode())
        gate.check(psql('postgres',f"select count(*) from pg_database where datname='{database}';").stdout.strip()=='0','SCRATCH_ALREADY_EXISTS')
        psql('postgres',f'create database "{database}" template template0;');created=True
        psql('postgres',f"comment on database \"{database}\" is '{marker}';")
        psql(database,'drop schema public; create schema extensions; create extension "uuid-ossp" with schema extensions; create extension pgcrypto with schema extensions; create extension btree_gist with schema extensions; create extension pgtap with schema extensions;')
        schema=dump.stdout.replace('CREATE SCHEMA extensions;','CREATE SCHEMA IF NOT EXISTS extensions;')
        # Preserve original object owners and ACLs. This container's existing
        # bootstrap administrator can restore supabase_admin-owned schemas;
        # postgres is intentionally not allowed to SET ROLE to that account.
        result=psql(database,schema,False,user='supabase_admin');log('schema-restore.log',result.stdout+'\n'+result.stderr)
        gate.check(result.returncode==0,'SCHEMA_RESTORE_FAILED')
        empty=psql(database,"select (select count(*) from auth.users)+(select count(*) from public.profiles)+(select count(*) from storage.objects);")
        gate.check(empty.stdout.strip()=='0','SCRATCH_NOT_EMPTY')
        psql(database,"insert into private.c003d_secrets(secret_name,secret_value) values('invitation_hmac_v1',extensions.gen_random_bytes(32));")
        result=psql(database,gate.MIGRATION.read_text(),False);log('migration.log',result.stdout+'\n'+result.stderr)
        gate.check(result.returncode==0,'SCRATCH_MIGRATION_FAILED')
        for first in ['accept','delete']:
            f=fixture(first);correlation=str(uuid.uuid4())
            accept=claim(f['recipient'])+f"select * from public.respond_horse_authority_transfer('{f['token']}','accept','{uuid.uuid4()}');"
            deletion=claim('','service_role')+f"select public.prepare_c010_account_deletion('{f['recipient']}','{correlation}');"
            first_body,second_body=(accept,deletion) if first=='accept' else (deletion,accept)
            command=['docker','exec','-i',gate.CONTAINER_ID,'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-U','postgres','-d',database]
            process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
            process.stdin.write(("begin; set local statement_timeout='5s'; "+first_body+" select 'FIRST_HELD'; select pg_sleep(0.8); commit;").encode());process.stdin.close()
            selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ);captured=b'';deadline=time.monotonic()+6
            while b'FIRST_HELD\n' not in captured and time.monotonic()<deadline:
                if selector.select(max(0,deadline-time.monotonic())):
                    chunk=os.read(process.stdout.fileno(),65536)
                    if not chunk:break
                    captured+=chunk
            selector.close()
            if b'FIRST_HELD\n' not in captured:
                process.wait(timeout=7);log(first+'-no-marker.log',(captured+process.stdout.read()+process.stderr.read()).decode())
                raise RuntimeError('RACE_MARKER_NOT_REACHED')
            start=time.monotonic();second=psql(database,"begin; set local statement_timeout='5s'; "+second_body+' commit;',False,timeout=8);elapsed=time.monotonic()-start
            process.wait(timeout=7);log(first+'-race.log',(captured+process.stdout.read()+process.stderr.read()).decode()+'\n'+second.stdout+'\n'+second.stderr)
            readback=psql(database,f"""select jsonb_build_object('primary',h.primary_authority_profile_id,'status',h.status,
              'recipient_status',p.status,'transfer_status',t.status,
              'accept_audits',(select count(*) from public.audit_events e where e.resource_id=t.id and e.event_type='horse.authority_transfer_accepted'),
              'grants',(select count(*) from public.horse_profile_permission_grants g where g.horse_id=h.id))
              from public.canonical_horses h join public.profiles p on p.id='{f['recipient_profile']}'
              join public.horse_authority_transfers t on t.id='{f['transfer']}' where h.id='{f['horse']}';""")
            state=json.loads(readback.stdout.strip())
            checks={'winnerCommitted':process.returncode==0,'contenderWaitedForLock':elapsed>=0.35,'horseStillArchived':state['status']=='archived','noGrantsCreated':state['grants']==0}
            if first=='accept':checks.update(accepted=state['primary']==f['recipient_profile'] and state['transfer_status']=='accepted',
              deletionBlocked=second.returncode==0 and 'PRIMARY_HORSE_AUTHORITY_REQUIRED' in second.stdout and state['recipient_status']=='active',oneAudit=state['accept_audits']==1)
            else:checks.update(deletionPrepared=state['recipient_status']=='auth_removal_pending' and state['transfer_status']=='revoked',
              acceptanceRefused=second.returncode!=0 and state['primary']==f['owner_profile'],noAcceptAudit=state['accept_audits']==0)
            report['cases'].append({'winner':first,'status':'PASS' if all(checks.values()) else 'FAIL','checks':checks,'contenderSeconds':round(elapsed,3)})
            gate.check(all(checks.values()),'RACE_EXPECTATION_FAILED')
        report['status']='PASS'
    except Exception as error:
        report['failureCode']=str(error) if str(error).replace('_','').isupper() else type(error).__name__
    finally:
        try:
            gate.inspect_target()
            if main_before is not None:report['mainDatabaseUnchanged']=main_before==gate.snapshot()
            if created:
                current=psql('postgres',f"select shobj_description(oid,'pg_database') from pg_database where datname='{database}';").stdout.strip()
                gate.check(current==marker,'SCRATCH_OWNER_MISMATCH')
                # Do not force termination of any connection. All our bounded
                # race queries are complete before dropping this exact DB.
                psql('postgres',f'drop database "{database}";')
                report['scratchDropped']=psql('postgres',f"select count(*) from pg_database where datname='{database}';").stdout.strip()=='0'
        except Exception as error:report['cleanupFailure']=str(error) if str(error).replace('_','').isupper() else type(error).__name__
        if not report['mainDatabaseUnchanged'] or not report['scratchDropped']:report['status']='FAIL'
        report['privateDiagnostics']=str(private.relative_to(gate.ROOT))
        (gate.BASE/'evidence/archived-horse-transfer-races.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='privateDiagnostics'},indent=2))
    return 0 if report['status']=='PASS' else 1

if __name__=='__main__':sys.exit(main())
