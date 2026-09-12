import copy
import json
from pathlib import Path
import unittest

import backup_operational_pilot as backup


class Guards(unittest.TestCase):
    def test_current49_all_source_bytes_match(self):
        self.assertEqual(len(backup.expected_history()), 49)

    def test_wrong_target_refused(self):
        value = json.loads(backup.MANIFEST.read_text())
        value['projectRef'] = 'unrelated'
        with self.assertRaisesRegex(ValueError, 'TARGET_MISMATCH'):
            backup.expected_history(value)

    def test_old47_refused(self):
        value = json.loads(backup.MANIFEST.read_text())
        value['migrations'] = value['migrations'][:47]
        with self.assertRaisesRegex(ValueError, 'EXACT49'):
            backup.expected_history(value)

    def test_checksum_drift_refused(self):
        value = json.loads(backup.MANIFEST.read_text())
        value['migrations'][-1]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'CHECKSUM'):
            backup.expected_history(value)

    def test_private_or_traversal_source_refused(self):
        for path in ['../private/key.json', '/tmp/source.sql']:
            value = json.loads(backup.MANIFEST.read_text())
            value['migrations'][-1]['path'] = path
            with self.assertRaisesRegex(ValueError, 'PATH_INVALID'):
                backup.expected_history(value)

    def test_restore_name_cannot_target_existing_app(self):
        self.assertEqual(backup.restore_name('20260912T160000Z'), 'avaryn_pilot49_backup_20260912t160000z')
        for value in ['postgres', '20260912T160000Z;drop database postgres;', '../x']:
            with self.assertRaises(ValueError):
                backup.restore_name(value)

    def test_row_count_match_does_not_hide_changed_values(self):
        before = [{'relation': 'public.profiles', 'rows': 2, 'md5': 'a'}]
        after = copy.deepcopy(before)
        after[0]['md5'] = 'b'
        with self.assertRaisesRegex(ValueError, 'RESTORED_ROWS_DIFFERS'):
            backup.identical(before, after, 'RESTORED_ROWS')

    def test_no_remote_mutation_switch_or_restore_reset(self):
        import inspect
        source = inspect.getsource(backup)
        self.assertNotIn('DROP DATABASE', source.upper())
        self.assertNotIn('default_transaction_read_only=off', source)
        self.assertNotIn('--disable-triggers', source)


if __name__ == '__main__':
    unittest.main()
