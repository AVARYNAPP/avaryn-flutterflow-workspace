import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parent))
import pilot_timezone_increment as target
from verify_timezone_local import SQL_SUITES,test_sql,test_result


class IncrementGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.plan=target.source_plan()
    def test_plan_matches_reviewable_file(self):
        self.assertEqual(json.loads(target.PLAN_PATH.read_text()),self.plan)
        self.assertEqual(len(self.plan['baseline']),47)
        self.assertEqual(self.plan['migration']['version'],'202609110004')
    def test_original_manifest_integrity_rejected(self):
        with patch.object(target,'BASELINE_SHA','0'*64),self.assertRaisesRegex(ValueError,'HISTORICAL47_MANIFEST_CHANGED'):target.source_plan()
    def test_other_source_rejected(self):
        with patch.object(target,'SOURCE_SHA','0'*64),self.assertRaisesRegex(ValueError,'ONLY_REVIEWED004'):target.source_plan()
    def test_exact47_history(self):self.assertEqual(target.validate_history(self.plan['baseline'],self.plan),47)
    def test_exact48_history_is_verification_path(self):
        new={k:self.plan['migration'][k] for k in ['version','name','sha256']};new['statement_count']=1
        self.assertEqual(target.validate_history(self.plan['baseline']+[new],self.plan),48)
    def test_partial_history_refused(self):
        with self.assertRaisesRegex(ValueError,'UNKNOWN_PARTIAL'):target.validate_history(self.plan['baseline'][:-1],self.plan)
    def test_checksum_name_statement_shape_rejected(self):
        for key,bad in [('sha256','0'*64),('name','another_name'),('statement_count',2)]:
            rows=copy.deepcopy(self.plan['baseline']);rows[0][key]=bad
            with self.subTest(key=key),self.assertRaises(ValueError):target.validate_history(rows,self.plan)
    def test_actual_cluster_and_role_required(self):
        original={'cluster':target.REMOTE_CLUSTER,'database':'postgres','role':'postgres','session_role':'postgres','superuser':False}
        target.validate_identity(original)
        for key,bad in [('cluster',target.LOCAL_CLUSTER),('database','test'),('role','supabase_admin'),('session_role','another'),('superuser',True)]:
            with self.subTest(key=key),self.assertRaises(ValueError):target.validate_identity(original|{key:bad})
    def test_apply_flags_required_before_any_connection(self):
        with patch.object(sys,'argv',['executor','--mode','apply']),patch.object(target,'Run') as opened:
            with self.assertRaises(SystemExit):target.main()
            opened.assert_not_called()
    def test_read_mode_cannot_write(self):
        r=target.Run.__new__(target.Run);r.mode='preflight'
        with self.assertRaisesRegex(ValueError,'REMOTE_WRITE_MODE_NOT_AUTHORIZED'):r.remote('bad','bad',write=True)
    def test_only_one_incremental_standard_history_insert(self):
        data=target.source_file(target.ROOT,target.SOURCE).read_bytes();sql=target.migration_sql(self.plan['migration'],data)
        self.assertEqual(sql.count('insert into supabase_migrations.schema_migrations'),1)
        self.assertNotIn('create table if not exists supabase_migrations',sql)
        self.assertNotIn('avaryn_local_meta',sql)
        self.assertEqual(target.sha(sql.encode()),self.plan['executor_sql_sha256'])
    def test_all_suites_rollback_and_exact_counts(self):
        self.assertEqual(sum(n for _,n in SQL_SUITES),320)
        for name,count in SQL_SUITES:
            with self.subTest(name=name):
                sql=test_sql(name);self.assertTrue(sql.startswith('begin;'));self.assertTrue(sql.rstrip().endswith('rollback;'))
                result=subprocess.CompletedProcess([],0,'\n'.join('ok '+str(i+1)+' - test' for i in range(count)),'')
                self.assertEqual(test_result(name,result)['status'],'PASS')
                result.stdout+='\nnot ok 999 - failure';self.assertEqual(test_result(name,result)['status'],'FAIL')
    def test_unrecognized_suite_refused(self):
        with self.assertRaises(ValueError):test_sql('../secrets')
    def test_schema_delta_preserves_policies_and_acl(self):
        old={'kind':'function','identity':'public.get_c010_calendar_context()','owner':'postgres','acl':'{authenticated=X/postgres}','config':['search_path=""'],'body_hash':'old'}
        policy={'kind':'policy','identity':'public.profiles.some_policy','owner':'postgres','acl':None,'config':{},'body_hash':'policy'}
        helper={'kind':'function','identity':'private.c010_actor_time_zone()','owner':'postgres','acl':[{'grantor':'postgres','grantee':'postgres','privilege':'EXECUTE','grantable':False}],'config':['search_path=""'],'body_hash':'new'}
        after=[old|{'body_hash':'new'},policy,helper]
        target.assert_schema_delta([old,policy],after)
        for changed in [old|{'owner':'another'},old|{'acl':'{anon=X/postgres}'}]:
            with self.assertRaises(ValueError):target.assert_schema_delta([old,policy],[changed,policy,helper])
        with self.assertRaises(ValueError):target.assert_schema_delta([old,policy],[after[0],policy|{'body_hash':'changed'},helper])
        with self.assertRaises(ValueError):target.assert_schema_delta([old,policy],after+[helper|{'identity':'private.extra()'}])
        with self.assertRaises(ValueError):target.assert_schema_delta([old,policy],[after[0],policy,helper|{'acl':'{anon=X/postgres}'}])
    def test_private_path_cannot_reference_external_evidence(self):
        with self.assertRaises(ValueError):target.check_private(Path('/tmp/not-the-pilot-proof'))


if __name__=='__main__':unittest.main()
