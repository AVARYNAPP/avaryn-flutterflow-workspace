import argparse
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('avaryn_local',Path(__file__).resolve().parents[1]/'avaryn_local.py')
local=importlib.util.module_from_spec(spec);spec.loader.exec_module(local)

class LocalOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.cfg={'target':'avaryn-c010-fixture-test','ports':{'api':56001,'db':56002,'mail':56004,'web':56060}}
        self.obj={'Config':{'Labels':local.labels(self.cfg),'Image':local.IMAGES['db']},'HostConfig':{
            'NetworkMode':self.cfg['target'],'Privileged':False,'PublishAllPorts':False,
            'PortBindings':{'5432/tcp':[{'HostIp':'127.0.0.1','HostPort':'56002'}]}},
            'NetworkSettings':{'Networks':{self.cfg['target']:{}},'Ports':{}},
            'State':{'Running':False},'Image':'pinned-digest'}
    def test_cors_allows_only_two_exact_local_names_at_the_same_port(self):
        self.assertEqual(local.preview_origins(self.cfg),
                         ['http://127.0.0.1:56060','http://localhost:56060'])
        for foreign in ['https://example.invalid','http://localhost:56061',
                        'http://127.0.0.1:56061','http://localhost.example.invalid:56060',
                        'http://127.0.0.1.example.invalid:56060','null','*']:
            self.assertNotIn(foreign,local.preview_origins(self.cfg))
        for invalid in [0,65536,True,'56060']:
            cfg=copy.deepcopy(self.cfg);cfg['ports']['web']=invalid
            with self.assertRaises(ValueError):local.preview_origins(cfg)
    def test_explicit_target_required(self):
        for target in ['supabase-default','avaryn-audit-20260907','avaryn-c010-','avaryn-c010-valid;true','AVARYN-c010-test']:
            with self.subTest(target=target),self.assertRaises(ValueError):local.validate_target(target)
        local.validate_target(self.cfg['target'])
    def test_hosted_cors_and_callbacks_are_exact_without_wildcards(self):
        self.cfg.update(preview_url='http://127.0.0.1:56060',
                        hosted_preview_origin='https://avaryn-private.example.chatgpt.site')
        self.assertEqual(len(local.preview_origins(self.cfg)), 3)
        redirects = local.auth_redirects(self.cfg).split(',')
        self.assertNotIn('*', local.auth_redirects(self.cfg))
        self.assertIn(self.cfg['hosted_preview_origin']+'/auth/reset-password', redirects)
        self.assertIn('http://localhost:56060/auth/callback', redirects)
        self.assertNotIn(self.cfg['hosted_preview_origin']+'/anything', redirects)
        for value in ['http://127.0.0.1:56060', 'https://alpha.avaryn.eu',
                      'https://example.chatgpt.site/path', 'https://user@example.chatgpt.site']:
            self.cfg['hosted_preview_origin'] = value
            with self.assertRaises(ValueError): local.preview_origins(self.cfg)
    def test_prestart_loopback_allowed(self):
        self.assertFalse(local.verify_container(self.cfg,'db',self.obj)['running'])
    def test_no_wildcard_even_before_start(self):
        for addr in ['', '0.0.0.0','::','192.168.1.10']:
            obj=copy.deepcopy(self.obj);obj['HostConfig']['PortBindings']['5432/tcp'][0]['HostIp']=addr
            with self.subTest(addr=addr),self.assertRaises(ValueError):local.verify_container(self.cfg,'db',obj)
    def test_unrelated_labels_refused(self):
        self.obj['Config']['Labels'][local.LABEL+'.target']='unrelated-project'
        with self.assertRaises(ValueError):local.verify_container(self.cfg,'db',self.obj)
    def test_hostnetwork_privileged_publishall_refused(self):
        for key,value in [('NetworkMode','host'),('Privileged',True),('PublishAllPorts',True)]:
            obj=copy.deepcopy(self.obj);obj['HostConfig'][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):local.verify_container(self.cfg,'db',obj)
    def test_extra_network_refused(self):
        self.obj['NetworkSettings']['Networks']['unrelated']={}
        with self.assertRaises(ValueError):local.verify_container(self.cfg,'db',self.obj)
    def test_extra_or_changed_port_refused(self):
        for bindings in [{}, {'5432/tcp':[{'HostIp':'127.0.0.1','HostPort':'56003'}]},
                         {'5432/tcp':[{'HostIp':'127.0.0.1','HostPort':'56002'}],'80/tcp':[{'HostIp':'127.0.0.1','HostPort':'56005'}]}]:
            obj=copy.deepcopy(self.obj);obj['HostConfig']['PortBindings']=bindings
            with self.subTest(bindings=bindings),self.assertRaises(ValueError):local.verify_container(self.cfg,'db',obj)
    def test_migration_body_and_ledger_commit_atomically(self):
        value=local.migration_transaction('BEGIN;\nCREATE TABLE example(id int);\nCOMMIT;','202609070001','a'*64)
        self.assertEqual(value.count('BEGIN;'),1)
        self.assertEqual(value.count('COMMIT;'),1)
        self.assertLess(value.index('INSERT INTO avaryn_local_meta'),value.index('COMMIT;'))
        with self.assertRaises(ValueError):local.migration_transaction('BEGIN;\nCOMMIT;\nBEGIN;','202609070001','a'*64)
    def test_container_inspection_does_not_resolve_volume(self):
        with patch.object(local,'docker') as docker:
            docker.return_value.returncode=1
            self.assertIsNone(local.inspect('owned-name'))
            docker.assert_called_once_with('container','inspect','owned-name',check=False)

if __name__=='__main__':unittest.main()
