import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import prepare_current_backend_release as current

class CurrentBackendSourceTests(unittest.TestCase):
    def test_exact49_and_three_current_edges_without_deployment_claim(self):
        value=current.build_manifest()
        self.assertEqual(len(value['migrations']),49)
        self.assertEqual(value['migrations'][-1]['version'],'202609110005')
        self.assertEqual(len(value['edgeFiles']),3)
        self.assertEqual(value['status'],'SOURCE_SNAPSHOT_NOT_DEPLOYMENT_PROOF')

    def test_snapshot_target_source_or_candidate_drift_refused(self):
        value=current.build_manifest()
        for field,changed in [('projectRef','ipdovjdtnfslrftvrdrl'),('candidate','previous-candidate'),('edgeFiles',[])]:
            wrong=copy.deepcopy(value);wrong[field]=changed
            with self.assertRaises(ValueError):current.verify_manifest(wrong)

    def test_reviewed_migration_hash_cannot_be_silently_rewritten(self):
        wrong=dict(current.INCREMENTS);key=next(iter(wrong));wrong[key]='0'*64
        with patch.object(current,'INCREMENTS',wrong),self.assertRaises(ValueError):current.build_manifest()

    def test_edge_staging_has_only_exact_sources_and_snapshot(self):
        value=current.build_manifest()
        with tempfile.TemporaryDirectory(dir=Path(tempfile.gettempdir()).resolve()) as temp:
            directory=Path(temp)/'edges';current.stage_edges(directory,value)
            self.assertEqual({p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file()},
                             {item['path'] for item in value['edgeFiles']}|{'backend-release.json'})
            for item in value['edgeFiles']:self.assertEqual(current.digest((directory/item['path']).read_bytes()),item['sha256'])
            with self.assertRaises(ValueError):current.stage_edges(directory,value)

    def test_symlink_staging_refused(self):
        with tempfile.TemporaryDirectory(dir=Path(tempfile.gettempdir()).resolve()) as temp:
            base=Path(temp);(base/'link').symlink_to(base,target_is_directory=True)
            with self.assertRaises(ValueError):current.stage_edges(base/'link/new',current.build_manifest())

if __name__=='__main__':unittest.main()
