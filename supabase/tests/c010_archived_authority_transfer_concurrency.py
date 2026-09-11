#!/usr/bin/env python3
"""Two deterministic archive-accept/deletion races on an isolated local target.

New synthetic fixtures only. Each winning transaction holds its own locks for
0.7s; the competing transaction is started after an explicit readiness marker.
No reset, query termination, history deletion or preview/pilot target access.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tool'))
import avaryn_local as local


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target',required=True)
    parser.add_argument('--state-dir')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not args.target.startswith('avaryn-c010-product-day-'):
        parser.error('only the separately owned personal-day test environment is accepted')
    cfg=local.load_context(args);local.verify_container(cfg,'db')
    cases=[]; fixtures=[]
    def claim(auth_id,role='authenticated'):
        return "set local role "+role+"; do $$ begin perform set_config('request.jwt.claim.role','"+role+"',true); perform set_config('request.jwt.claim.sub','"+auth_id+"',true); end $$;"
    def create_case(label):
        owner,recipient=[str(uuid.uuid4()) for _ in range(2)]
        sql=f"""begin;
        create temporary table case_values(key text primary key,value jsonb); grant all on case_values to authenticated;
        insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
        select '00000000-0000-0000-0000-000000000000',v.id::uuid,'authenticated','authenticated',v.id||'@archive-race.invalid','',now(),'{{}}','{{}}',now(),now()
        from (values('{owner}'),('{recipient}')) v(id);
        insert into case_values values('profiles',(select jsonb_object_agg(auth_user_id,id) from public.profiles where auth_user_id in('{owner}','{recipient}')));
        {claim(owner)}
        insert into case_values values('organization',public.create_c010_stable('Archive race {label}','Disposable',gen_random_uuid()));
        select public.retire_c010_stable((select (value->>'organization_id')::uuid from case_values where key='organization'),
        (select o.row_version from public.organizations o where id=(select (value->>'organization_id')::uuid from case_values where key='organization')),'Archive race {label}',gen_random_uuid());
        insert into case_values select 'transfer',to_jsonb(r) from public.initiate_organization_authority_transfer(
        (select (value->>'organization_id')::uuid from case_values where key='organization'),(select (value->>'{recipient}')::uuid from case_values where key='profiles'),gen_random_uuid()) r;
        select jsonb_object_agg(key,value) from case_values;
        commit;"""
        result=local.sql(cfg,sql,role='postgres')
        data=json.loads([line for line in result.stdout.splitlines() if line.startswith('{')][-1])
        return {'label':label,'owner_auth':owner,'recipient_auth':recipient,
          'owner_profile':data['profiles'][owner],'recipient_profile':data['profiles'][recipient],
          'organization_id':data['organization']['organization_id'],
          'token':data['transfer']['transfer_token'],'transfer_id':data['transfer']['transfer_id']}
    try:
        for first_action in ('accept','delete'):
            case=create_case(first_action);fixtures.append(case)
            recipient=case['recipient_auth']; correlation=str(uuid.uuid4())
            accept="select * from public.respond_stable_authority_transfer('"+case['token']+"','accept','"+str(uuid.uuid4())+"');"
            deletion="select public.prepare_c010_account_deletion('"+recipient+"','"+correlation+"');"
            first_body=(claim(recipient)+accept) if first_action=='accept' else (claim('','service_role')+deletion)
            second_body=(claim('','service_role')+deletion) if first_action=='accept' else (claim(recipient)+accept)
            command=['docker','exec','-i',local.name(cfg,'db'),'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-U','postgres','-d','postgres']
            process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
            process.stdin.write("begin; set local statement_timeout='5s'; "+first_body+" select 'FIRST_HELD'; select pg_sleep(0.7); commit;")
            process.stdin.close()
            observed=[];deadline=time.monotonic()+5
            while time.monotonic()<deadline:
                # psql flushes result rows after each statement.
                line=process.stdout.readline()
                if not line:break
                observed.append(line)
                if line.strip()=='FIRST_HELD':break
            if not observed or observed[-1].strip()!='FIRST_HELD':raise RuntimeError('first transaction did not reach lock marker')
            began=time.monotonic()
            second=local.sql(cfg,"begin; set local statement_timeout='5s'; "+second_body+" commit;",check=False,role='postgres')
            elapsed=time.monotonic()-began
            process.wait(timeout=6)
            first_log=''.join(observed)+process.stdout.read()+'\n'+process.stderr.read()
            private=cfg['state']/('archive-race-'+first_action+'.log')
            private.write_text(first_log+'\n'+second.stdout+'\n'+second.stderr);private.chmod(0o600)
            state_sql=f"""select jsonb_build_object('primary',o.primary_admin_profile_id,'organization_status',o.status,
              'recipient_status',p.status,'transfer_status',t.status,
              'active_memberships',(select count(*) from public.organization_memberships m where m.organization_id=o.id and m.status='active'),
              'accept_audits',(select count(*) from public.audit_events e where e.resource_id=t.id and e.event_type='organization.head_transfer_accepted'))
              from public.organizations o join public.profiles p on p.id='{case['recipient_profile']}'
              join public.organization_authority_transfers t on t.id='{case['transfer_id']}' where o.id='{case['organization_id']}';"""
            state=json.loads(local.sql(cfg,state_sql).stdout.strip())
            checks={'first_committed':process.returncode==0,'second_waited_for_actual_lock':elapsed>=0.3,
              'archive_stays_closed':state['organization_status']=='archived' and state['active_memberships']==0}
            if first_action=='accept':
                checks.update(accept_won=state['primary']==case['recipient_profile'] and state['transfer_status']=='accepted',
                  deletion_blocked=second.returncode==0 and 'PRIMARY_ORGANIZATION_ADMIN_REQUIRED' in second.stdout and state['recipient_status']=='active',
                  one_accept_audit=state['accept_audits']==1)
            else:
                checks.update(deletion_won=state['recipient_status']=='auth_removal_pending' and state['transfer_status']=='revoked',
                  acceptance_refused=second.returncode!=0 and state['primary']==case['owner_profile'],
                  no_accept_audit=state['accept_audits']==0)
            cases.append({'first':first_action,'result':'PASS' if all(checks.values()) else 'FAIL',
                          'checks':checks,'competing_request_seconds':round(elapsed,3)})
    finally:
        file=cfg['state']/'archive-race-fixtures.json';file.write_text(json.dumps(fixtures,indent=2)+'\n');file.chmod(0o600)
    result={'target':args.target,'result':'PASS' if len(cases)==2 and all(c['result']=='PASS' for c in cases) else 'FAIL',
            'cases':cases,'fixture_policy':'new local synthetic accounts and terminal archive/transfer history retained; no preview fixtures modified'}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    return 0 if result['result']=='PASS' else 1

if __name__=='__main__':sys.exit(main())
