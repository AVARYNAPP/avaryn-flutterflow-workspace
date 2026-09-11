import copy
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys

import configure_pilot_connection as connection
import prepare_pilot_release as release


class PilotPreparationTests(unittest.TestCase):
    def test_exact_manifest_and_no_fixture_payload(self):
        value = release.build_manifest()
        self.assertEqual(value['project_ref'], 'rvymglpkttlfwhqpmupp')
        self.assertEqual(len(value['migrations']), 47)
        self.assertEqual(value['deploy_functions'], ['delete-account', 'media-assets'])
        self.assertEqual(len(value['edge_files']), 3)
        self.assertFalse(value['managed_requirements']['source_fixture_import'])

    def test_changed_target_or_hash_is_refused(self):
        value = release.build_manifest()
        for change in ('target', 'hash'):
            altered = copy.deepcopy(value)
            if change == 'target': altered['project_ref'] = 'ipdovjdtnfslrftvrdrl'
            else: altered['migrations'][0]['sha256'] = '0' * 64
            with self.assertRaises(ValueError): release.verify_manifest(altered)

    def test_stage_exact_files_and_existing_destination_refused(self):
        with tempfile.TemporaryDirectory(dir=release.HERE) as directory:
            destination = Path(directory) / 'stage'
            value = release.build_manifest()
            release.stage_release(destination, value)
            files = {p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()}
            expected = {r['path'] for r in value['migrations'] + value['edge_files']}
            self.assertEqual(files, expected | {'supabase/config.toml', 'pilot-release-manifest.json'})
            self.assertIn('enabled = false', (destination / 'supabase/config.toml').read_text())
            with self.assertRaises(ValueError): release.stage_release(destination, value)

    def test_symlink_destination_refused(self):
        with tempfile.TemporaryDirectory(dir=release.HERE) as directory:
            base = Path(directory); (base / 'link').symlink_to(base, target_is_directory=True)
            with self.assertRaises(ValueError): release.stage_release(base / 'link/new', release.build_manifest())

    def test_pgpass_escaping_and_exact_destination(self):
        line = connection.pgpass_entry('session', 'Fictief:geheim\\test')
        self.assertEqual(line, 'aws-1-eu-west-1.pooler.supabase.com:5432:postgres:postgres.rvymglpkttlfwhqpmupp:Fictief\\:geheim\\\\test\n')
        for mode, password in [('unknown', 'x'), ('direct', ''), ('session', 'x\ny')]:
            with self.assertRaises(ValueError): connection.pgpass_entry(mode, password)

    def test_private_generation_and_no_secret_in_config(self):
        with tempfile.TemporaryDirectory(dir=release.HERE) as directory:
            base = Path(directory) / 'private'
            first = connection.store_connection(base, 'session', 'SyntheticOnlyPassword1')
            second = connection.store_connection(base, 'direct', 'SyntheticOnlyPassword2')
            self.assertTrue(Path(first['pgpassfile']).exists())
            self.assertNotEqual(first['pgpassfile'], second['pgpassfile'])
            self.assertNotIn('SyntheticOnlyPassword', (base / 'connection.json').read_text())
            self.assertEqual(json.loads((base / 'connection.json').read_text()), second)
            self.assertEqual(base.stat().st_mode & 0o777, 0o700)
            for p in base.rglob('*'):
                self.assertEqual(p.stat().st_mode & 0o777, 0o700 if p.is_dir() else 0o600)
            self.assertFalse(second['connection_tested'])
            self.assertFalse(second['management_access'])

    def test_noninteractive_password_input_refused(self):
        result = subprocess.run([sys.executable, '-B', str(release.HERE / 'configure_pilot_connection.py')],
                                input='NeverStoredSyntheticInput\n', text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn('NeverStoredSyntheticInput', result.stdout + result.stderr)

    def test_private_symlink_refused_before_password_write(self):
        with tempfile.TemporaryDirectory(dir=release.HERE) as directory:
            base = Path(directory); (base / 'link').symlink_to(base, target_is_directory=True)
            with self.assertRaises(ValueError):
                connection.store_connection(base / 'link/private', 'session', 'SyntheticOnly')


if __name__ == '__main__': unittest.main()
