import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parent))
import archived_horse_increment as target


class IncrementGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.plan=target.source_plan()
    def test_frozen_source_and48base(self):
        self.assertEqual(json.loads(target.PLAN_PATH.read_text()),self.plan)
        self.assertEqual(len(self.plan['baseline']),48)
        self.assertEqual(self.plan['baseline'][-1]['version'],'202609110004')
        self.assertEqual(self.plan['migration']['version'],'202609110005')
        with patch.object(target,'SOURCE_SHA','0'*64),self.assertRaises(ValueError):target.source_plan()
    def test_only_exact48_or49_ledger(self):
        for name in ('dev','pilot'):
            for after,count in [(False,48),(True,49)]:
                rows=target.expected_history(self.plan,name,after)
                self.assertEqual(target.validate_history(rows,self.plan,name),count)
                with self.assertRaises(ValueError):target.validate_history(rows[:-2],self.plan,name)
                rows=copy.deepcopy(rows);rows[0]['sha256']='0'*64
                with self.assertRaises(ValueError):target.validate_history(rows,self.plan,name)
    def test_history_does_not_confuse_target_formats(self):
        with self.assertRaises(ValueError):target.validate_history(target.expected_history(self.plan,'dev'),self.plan,'pilot')
    def test_apply_needs_review_before_opening_connections(self):
        with patch.object(sys,'argv',['executor','--target','dev','--mode','apply']),patch.object(target,'Run') as opened:
            with self.assertRaises(SystemExit):target.main()
            opened.assert_not_called()
    def test_prepare_cannot_write_source_database(self):
        for name in ('dev','pilot'):
            r=target.Run.__new__(target.Run);r.target=name;r.mode='prepare'
            with self.assertRaisesRegex(ValueError,'WRITE_NOT_ALLOWED'):r.execute('bad','bad',write=True)
    def test_dev_guard_does_not_require_or_add_new_privilege(self):
        guard=target.history_guard('dev',target.expected_history(self.plan,'dev'))
        self.assertIn('pg_advisory_xact_lock',guard)
        self.assertIn('HISTORY_CHANGED_BEFORE005',guard)
        self.assertNotIn('lock table',guard.lower())
        self.assertNotIn('grant ',guard.lower())
        self.assertIn('lock table supabase_migrations.schema_migrations',target.history_guard('pilot',target.expected_history(self.plan,'pilot')))
    def test_one_migration_one_ledger_no_bootstrap(self):
        data=target.source_file(target.ROOT,target.SOURCE).read_bytes()
        for name in ('dev','pilot'):
            r=target.Run.__new__(target.Run);r.target=name;r.plan=self.plan
            sql=r.migration()
            self.assertEqual(sql.lower().count('insert into '+('avaryn_local_meta.migrations' if name=='dev' else 'supabase_migrations.schema_migrations')),1)
            self.assertNotIn('create schema',sql.lower())
            self.assertNotIn('create table',sql.lower())
            self.assertNotIn('202609110004',sql)
    def test_suites_are_bounded_rollback(self):
        self.assertEqual(sum(v for _,v in target.SUITES),50)
        for name,count in target.SUITES:
            sql=target.test_sql(name);self.assertTrue(sql.startswith('begin;'));self.assertTrue(sql.rstrip().endswith('rollback;'))
            p=subprocess.CompletedProcess([],0,('\n'.join('ok '+str(i+1) for i in range(count))).encode(),b'')
            self.assertEqual(target.test_result(name,p)['status'],'PASS')
            p.stdout+=b'\nnot ok 999 - failure';self.assertEqual(target.test_result(name,p)['status'],'FAIL')
        with self.assertRaises(ValueError):target.test_sql('../private')
    def test_existing_acl_and_policy_unchanged(self):
        acl=[{'grantor':'postgres','grantee':g,'privilege':'EXECUTE','grantable':False} for g in ('authenticated','postgres')]
        old=[{'kind':'function','identity':n+'()','owner':'postgres','acl':acl,'config':['search_path=""'],'body_hash':'old'} for n in target.CHANGED_NAMES]
        policy={'kind':'policy','identity':'public.profiles.policy','owner':'postgres','acl':None,'config':{},'body_hash':'policy'}
        old.append(policy)
        helper={'kind':'function','identity':target.NEW_NAME+'()','owner':'postgres','acl':acl,'config':['search_path=""'],'body_hash':'new'}
        after=[v|{'body_hash':'new'} if v['kind']=='function' else v for v in old]+[helper]
        target.assert_schema_delta(old,after)
        for mutated in [after[:-1],after+[helper|{'identity':'public.extra()'}]]:
            with self.assertRaises(ValueError):target.assert_schema_delta(old,mutated)
        for key,bad in [('owner','other'),('acl',[]),('config',['search_path=public'])]:
            mutated=copy.deepcopy(after);mutated[0][key]=bad
            with self.assertRaises(ValueError):target.assert_schema_delta(old,mutated)
        with self.assertRaises(ValueError):target.assert_schema_delta(old,after[:-1]+[helper|{'acl':acl+[{'grantor':'postgres','grantee':'anon','privilege':'EXECUTE','grantable':False}]}])
        with self.assertRaises(ValueError):target.assert_schema_delta(old,[v|{'body_hash':'changed'} if v['kind']=='policy' else v for v in after])


if __name__=='__main__':unittest.main()
