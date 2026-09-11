"""Explicit product backend mode: synthetic files/mocks, no real Docker or DB."""
import argparse
from contextlib import ExitStack, redirect_stdout, redirect_stderr
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch, Mock

spec=importlib.util.spec_from_file_location('product_local_runner',Path(__file__).resolve().parents[1]/'avaryn_local.py')
local=importlib.util.module_from_spec(spec);spec.loader.exec_module(local)
REAL_ROOT,REAL_RUN=local.ROOT,local.run

class ProductClientTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.target='avaryn-c010-portable-unit';self.state=self.root/'private'
        for name in ['package.json','capacitor.config.json','config/release.json']:
            path=self.root/'apps/avaryn'/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps({'fixture':name}))
        self.provenance={'packageName':'@avaryn/client','applicationId':'com.mycompany.avarynalpha',
            'candidate':'C010-V8-SYNTHETIC-TEST-01','files':{p:local.digest((self.root/'apps/avaryn'/p).read_bytes()) for p in ['package.json','capacitor.config.json','config/release.json']}}
        self.stack=ExitStack();self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(local,'ROOT',self.root))
        self.command=self.stack.enter_context(patch.object(local,'run',side_effect=self.public_read))
        self.docker=self.stack.enter_context(patch.object(local,'docker',side_effect=AssertionError('No real Docker in unit gate')))
        self.stack.enter_context(redirect_stdout(io.StringIO()))
    def args(self,**kwargs):
        values=dict(command='prepare',target=self.target,state_dir=str(self.state),port_base=58100,web_port=58160,
            product_client=True,backend_only=True,reuse_build=False,smoke_only=False,no_fixtures=False)
        values.update(kwargs);return argparse.Namespace(**values)
    def public_read(self,argv,**kwargs):
        self.assertEqual(argv,['node',self.root/'apps/avaryn/scripts/local-backend-config.mjs','--provenance-only'])
        return types.SimpleNamespace(returncode=0,stdout=json.dumps(self.provenance),stderr='')
    def context(self,**kwargs):return local.load_context(self.args(**kwargs),create=True)
    def binding(self,project=None):
        path=self.root/'.flutterflow/workspace.json';path.parent.mkdir();path.write_text(json.dumps({'projectId':project or local.PROJECT}))
    def schema(self):
        paths=self.root/'supabase/migrations';paths.mkdir(parents=True,exist_ok=True)
        for v in ['202609110004','202609110005']:(paths/(v+'_synthetic.sql')).write_text('-- synthetic metadata fixture '+v+'\n')
        return {'ledger':{p.name.split('_')[0]:local.digest(p.read_bytes()) for p in paths.glob('*.sql')},
            'schema':{key:True for key in ['auth','profiles','horses','stables','storage','profile_rpc','horse_archive_rpc','stable_archive_rpc','profile_anon_denied','horse_archive_anon_denied','horse_archive_authenticated']}}
    def smoke_patches(self,snapshot=None,profile_status=401):
        snapshot=snapshot or self.schema()
        def sql(cfg,query,**kwargs):
            self.assertIn('BEGIN READ ONLY;',query);self.assertTrue(query.rstrip().endswith('COMMIT;'))
            self.assertEqual(kwargs,{'role':'postgres'})
            for token in ['INSERT ','UPDATE ','DELETE ','ALTER ','CREATE ','GRANT ','REVOKE ']:self.assertNotIn(token,query)
            return types.SimpleNamespace(stdout=json.dumps(snapshot))
        def api(cfg,path,token=None,**kwargs):
            if path=='/rest/v1/rpc/get_current_account_profile':self.assertIsNone(token);return profile_status,{}
            if path=='/functions/v1/delete-account':return (400,{'code':'DELETION_CONFIRMATION_REQUIRED'}) if token else (401,{'code':'AUTHENTICATION_REQUIRED'})
            if path=='/auth/v1/user':return 200,{'id':token+'-user','email_confirmed_at':'2026-09-11'}
            self.fail('Unexpected API')
        self.stack.enter_context(patch.object(local,'sql',side_effect=sql))
        self.api=self.stack.enter_context(patch.object(local,'api_response',side_effect=api))
        self.stack.enter_context(patch.object(local,'request',return_value={'version':'synthetic-auth'}))
        self.stack.enter_context(patch.object(local,'verify_cors',return_value=[{'case':'synthetic CORS gate','result':'PASS'}]))
        self.stack.enter_context(patch.object(local,'inspect',return_value={'HostConfig':{'PortBindings':{}},'NetworkSettings':{'Ports':{}}}))
        self.stack.enter_context(patch.object(local,'verify_container',return_value={'running':True}))
    def test_fresh_product_context_never_reads_ff_and_persists_only_public_provenance(self):
        cfg=self.context();self.assertFalse((self.root/'.flutterflow').exists());self.assertTrue(cfg['product_client'])
        saved=json.loads((cfg['state']/'environment.json').read_text());self.assertEqual(saved['client_mode'],'product');self.assertEqual(saved['product_provenance'],self.provenance)
        self.assertEqual((cfg['state']/'environment.json').stat().st_mode&0o777,0o600)
        self.assertNotIn('product_client',saved);self.docker.assert_not_called()
    def test_real_node_provenance_helper_connects_to_the_runner_without_private_binding(self):
        original=Path.read_text
        def public_only(path,*args,**kwargs):
            self.assertNotEqual(path.name,'workspace.json');return original(path,*args,**kwargs)
        with patch.object(local,'ROOT',REAL_ROOT),patch.object(local,'run',REAL_RUN),patch.object(Path,'read_text',public_only):
            value=local.product_context(self.args())
        self.assertEqual(value['packageName'],'@avaryn/client');self.assertEqual(value['files']['package.json'],local.digest((REAL_ROOT/'apps/avaryn/package.json').read_bytes()))
        self.docker.assert_not_called()
    def test_every_product_command_requires_explicit_backend_only_before_state_creation(self):
        for command in ['prepare','start','verify','status','stop']:
            with self.subTest(command=command),self.assertRaisesRegex(ValueError,'requires --backend-only'):
                local.load_context(self.args(command=command,backend_only=False),create=True)
        self.command.assert_not_called();self.assertFalse(self.state.exists())
    def test_product_reuse_build_and_full_verify_are_refused_before_source_or_state_access(self):
        for options in [dict(reuse_build=True),dict(command='verify',smoke_only=False)]:
            with self.subTest(options=options),self.assertRaises(ValueError):self.context(**options)
        self.command.assert_not_called();self.assertFalse(self.state.exists())
    def test_provenance_hash_mismatch_is_refused(self):
        self.provenance['files']['package.json']='a'*64
        with self.assertRaisesRegex(ValueError,'provenance'):self.context()
        self.assertFalse(self.state.exists())
    def test_provenance_failure_omits_subprocess_diagnostics(self):
        self.command.side_effect=None;self.command.return_value=types.SimpleNamespace(returncode=1,stdout='private-synthetic-value',stderr='private-synthetic-value')
        with self.assertRaises(ValueError) as error:self.context()
        self.assertNotIn('private-synthetic-value',str(error.exception));self.assertFalse(self.state.exists())
    def test_legacy_context_still_requires_original_ff_binding(self):
        with self.assertRaises(FileNotFoundError):self.context(product_client=False)
        self.command.assert_not_called();self.binding();cfg=self.context(product_client=False)
        self.assertNotIn('product_client',cfg);self.assertNotIn('client_mode',cfg)
    def test_product_target_cannot_enter_legacy_flutter_mode_even_if_binding_exists(self):
        self.context();self.binding()
        with self.assertRaisesRegex(ValueError,'requires explicit --product-client'):self.context(product_client=False)
    def test_existing_owned_local_state_can_use_explicit_product_mode_without_rewriting_it(self):
        self.binding();cfg=self.context(product_client=False);path=cfg['state']/'environment.json';before=path.read_bytes()
        cfg=self.context();self.assertTrue(cfg['product_client']);self.assertEqual(path.read_bytes(),before)
    def test_foreign_or_hosted_state_is_not_adopted(self):
        cfg=self.context();path=cfg['state']/'environment.json';base=json.loads(path.read_text())
        for field,value in [('owner','another-owner'),('project_id','other-project'),('target','avaryn-c010-other-target'),('hosted_preview_origin','https://other.invalid')]:
            path.write_text(json.dumps({**base,field:value}))
            with self.subTest(field=field),self.assertRaises(ValueError):self.context()
    def test_product_private_state_rejects_world_readable_and_symlink_files(self):
        cfg=self.context();path=cfg['state']/'environment.json';path.chmod(0o644)
        with self.assertRaisesRegex(ValueError,'0600'):self.context()
        path.chmod(0o600);other=cfg['state']/'saved.json';path.rename(other);path.symlink_to(other)
        with self.assertRaisesRegex(ValueError,'0600'):self.context()
    def test_current_public_package_change_is_revalidated_without_resetting_backend(self):
        cfg=self.context();before=(cfg['state']/'environment.json').read_bytes()
        (self.root/'apps/avaryn/package.json').write_text('{"fixture":"new-package"}')
        self.provenance['files']['package.json']=local.digest((self.root/'apps/avaryn/package.json').read_bytes())
        next_cfg=self.context();self.assertEqual(next_cfg['product_provenance'],self.provenance);self.assertEqual((cfg['state']/'environment.json').read_bytes(),before)
    def test_main_product_start_only_calls_backend_and_optional_seed(self):
        for no_fixtures in [False,True]:
            args=['runner','start','--target',self.target,'--state-dir',str(self.state),'--port-base','58100','--web-port','58160','--product-client','--backend-only']+(['--no-fixtures'] if no_fixtures else [])
            with patch.object(local.sys,'argv',args),patch.object(local,'start_backend') as start,patch.object(local,'seed_fixtures') as seed,patch.object(local,'build_release') as build,patch.object(local,'start_web') as web:
                local.main();start.assert_called_once();self.assertEqual(seed.call_count,0 if no_fixtures else 1);build.assert_not_called();web.assert_not_called()
    def test_direct_product_verify_cannot_invoke_legacy_regression_jobs(self):
        cfg=self.context()
        for backend,smoke in [(False,True),(True,False),(False,False)]:
            with self.subTest(backend=backend,smoke=smoke),self.assertRaises(ValueError):local.verify(cfg,backend,smoke)
        self.docker.assert_not_called()
    def test_no_fixture_smoke_checks_health_exact_ledger_schema_and_anonymous_guards_without_session_claim(self):
        cfg=self.context();self.smoke_patches();self.command.reset_mock()
        local.verify(cfg,True,True,True);proof=json.loads((cfg['state']/'verify.json').read_text())
        self.assertEqual(proof['mode'],'product-backend-smoke');self.assertEqual(proof['authenticated_fixture_sessions'],'NOT TESTED');self.assertEqual(proof['frontend'],'NOT TESTED')
        self.assertEqual({call.args[1] for call in self.api.call_args_list},{'/rest/v1/rpc/get_current_account_profile','/functions/v1/delete-account'})
        self.command.assert_not_called();self.assertFalse((cfg['state']/'fixtures.json').exists())
    def test_missing_fixtures_are_not_silently_skipped(self):
        cfg=self.context();self.smoke_patches()
        with self.assertRaisesRegex(ValueError,'fixtures missing'):local.verify(cfg,True,True)
        self.assertFalse((cfg['state']/'verify.json').exists())
    def test_fixture_smoke_retains_real_session_and_no_confirmation_deletion_guard_contract(self):
        cfg=self.context();self.smoke_patches();local.private_json(cfg['state']/'fixtures.json',{'complete':True,'target':self.target,'users':{r:{'access_token':r,'user_id':r+'-user'} for r in ['admin_a','outsider']}})
        local.verify(cfg,True,True);proof=json.loads((cfg['state']/'verify.json').read_text());self.assertEqual(proof['authenticated_fixture_sessions'],'PASS')
        self.assertEqual(sum(c.args[1]=='/auth/v1/user' for c in self.api.call_args_list),2)
        for c in self.api.call_args_list:self.assertFalse(c.kwargs.get('body'))
    def test_no_fixture_skip_is_invalid_for_legacy_or_non_smoke_modes(self):
        cfg=self.context();cfg.pop('product_client')
        with self.assertRaises(ValueError):local.verify(cfg,True,True,True)
    def test_missing_changed_or_extra_ledger_migration_fails_closed(self):
        cfg=self.context();base=self.schema()
        for operation in ['missing','changed','extra']:
            value=copy.deepcopy(base)
            if operation=='missing':value['ledger'].pop('202609110005')
            elif operation=='changed':value['ledger']['202609110005']='a'*64
            else:value['ledger']['209909110001']='a'*64
            with self.subTest(operation=operation),patch.object(local,'request',return_value={'version':'test'}),patch.object(local,'sql',return_value=types.SimpleNamespace(stdout=json.dumps(value))),self.assertRaisesRegex(ValueError,'ledger'):
                local.verify_product_schema(cfg)
    def test_missing_schema_or_permissive_archive_acl_fails_closed(self):
        cfg=self.context();base=self.schema()
        for key in ['horse_archive_rpc','profile_anon_denied','horse_archive_anon_denied','horse_archive_authenticated']:
            value=copy.deepcopy(base);value['schema'][key]=False
            with self.subTest(key=key),patch.object(local,'request',return_value={'version':'test'}),patch.object(local,'sql',return_value=types.SimpleNamespace(stdout=json.dumps(value))),self.assertRaisesRegex(ValueError,'schema'):
                local.verify_product_schema(cfg)
    def test_successful_anonymous_profile_response_is_a_failure(self):
        cfg=self.context();self.smoke_patches(profile_status=200)
        with self.assertRaisesRegex(ValueError,'not refused'):local.verify(cfg,True,True,True)
    def test_product_stop_only_stops_8_owned_services_and_checks_3_backend_ports(self):
        cfg=self.context();ports=[];probe=Mock();probe.__enter__=Mock(return_value=probe);probe.__exit__=Mock(return_value=False);probe.connect_ex.side_effect=lambda pair:ports.append(pair[1]) or 1
        with patch.object(local,'inspect',return_value={'owned':True}),patch.object(local,'verify_container',return_value={'running':False}),patch.object(local,'docker') as docker,patch.object(local,'web_process') as web,patch.object(local.os,'kill') as kill,patch.object(local.socket,'socket',return_value=probe):
            local.stop(cfg);self.assertEqual(docker.call_args_list,[unittest.mock.call('stop',local.name(cfg,s)) for s in reversed(local.SERVICES)]);web.assert_not_called();kill.assert_not_called()
        self.assertEqual(ports,[58101,58102,58104]);proof=json.loads((cfg['state']/'stop.json').read_text());self.assertEqual(set(proof['ports_closed']),{'api','db','mail'});self.assertFalse(proof['frontend_managed']);self.assertTrue(proof['all_containers_stopped'])
    def test_stop_refuses_unowned_container_before_signalling_it(self):
        cfg=self.context()
        with patch.object(local,'inspect',return_value={'foreign':True}),patch.object(local,'verify_container',side_effect=ValueError('Foreign ownership')):
            with self.assertRaisesRegex(ValueError,'Foreign ownership'):local.stop(cfg)
        self.docker.assert_not_called()
    def test_product_status_is_public_provenance_not_credentials_or_frontend_readiness(self):
        cfg=self.context()
        with patch.object(local,'inspect',return_value=None):value=local.status(cfg)
        self.assertEqual(value['client_mode'],'product');self.assertFalse(value['frontend_managed']);self.assertEqual(value['product_provenance'],self.provenance)
        for secret in ['anon_key','service_key','db_password','jwt_secret']:self.assertNotIn(cfg[secret],json.dumps(value))

if __name__=='__main__':unittest.main()
