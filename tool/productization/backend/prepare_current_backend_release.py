#!/usr/bin/env python3
"""Offline current source snapshot. Never applies migrations or deploys functions.

The historical47 bootstrap manifest stays immutable. This snapshot records the
current49 source and the current three Edge files for the product candidate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from prepare_pilot_release import ROOT, PROJECT_REF, ORG, EDGE_FILES, source_file

OUTPUT=ROOT/'apps/avaryn/config/backend-release.json'
HISTORICAL_SOURCE_DIGEST='41829a55f5283d349bc285e41d2706a68d87f904f54aa17bb3323e6eb6fda11d'
INCREMENTS={
    'supabase/migrations/202609110004_c010_account_calendar_timezone.sql':'a9e47de0b01bb8fd407e354b1ea1a148d89455a53e79c70561aa13f6365b08bd',
    'supabase/migrations/202609110005_c010_archived_horse_authority_transfer.sql':'755aa06c7d613aa887ed8f9c69ce9afe68560c45e00bb19d7955ef85677f98bc',
}
digest=lambda data:hashlib.sha256(data).hexdigest()

def build_manifest(root=ROOT):
    baseline_path=source_file(root,'tool/productization/backend/pilot-release-manifest.json')
    baseline=json.loads(baseline_path.read_text())
    sealed={k:v for k,v in baseline.items() if k!='source_manifest_sha256'}
    if (baseline.get('source_manifest_sha256')!=HISTORICAL_SOURCE_DIGEST
        or digest(json.dumps(sealed,sort_keys=True,separators=(',',':')).encode())!=HISTORICAL_SOURCE_DIGEST):
        raise ValueError('Historical source manifest no longer matches the reviewed bootstrap.')
    if baseline.get('project_ref')!=PROJECT_REF or baseline.get('organization_id')!=ORG or len(baseline.get('migrations',[]))!=47:
        raise ValueError('Historical pilot identity or migration count differs.')
    expected={item['path']:item['sha256'] for item in baseline['migrations']}|INCREMENTS
    actual={p.relative_to(root).as_posix() for p in (root/'supabase/migrations').glob('*.sql')}
    if actual!=set(expected):raise ValueError('Review the exact migration set before changing the candidate.')
    migrations=[]
    for relative,wanted in sorted(expected.items()):
        data=source_file(root,relative).read_bytes()
        if digest(data)!=wanted:raise ValueError('Previously reviewed migration source changed.')
        migrations.append({'path':relative,'version':Path(relative).name.split('_')[0],'sha256':wanted,'bytes':len(data)})
    release=json.loads(source_file(root,'apps/avaryn/config/release.json').read_text())
    if not release['candidate'].startswith('C010-V8-PRODUCTIZATION-'):raise ValueError('Unexpected product candidate.')
    edges=[]
    for relative in EDGE_FILES:
        data=source_file(root,relative).read_bytes()
        edges.append({'path':relative,'sha256':digest(data),'bytes':len(data)})
    return {'schemaVersion':1,'candidate':release['candidate'],'projectRef':PROJECT_REF,'organizationId':ORG,
        'status':'SOURCE_SNAPSHOT_NOT_DEPLOYMENT_PROOF','historical47ManifestSha256':digest(baseline_path.read_bytes()),
        'migrations':migrations,'edgeFiles':edges,'functions':['delete-account','media-assets'],
        'scope':'No fixture import, no seed, no migration execution, no deployment. Use separate actual environment receipts.'}

def verify_manifest(value,root=ROOT):
    if value!=build_manifest(root):raise ValueError('Candidate source or destination differs from the recorded snapshot.')

def stage_edges(destination,value,root=ROOT):
    verify_manifest(value,root)
    destination=destination.absolute()
    if destination.exists() or any(p.is_symlink() for p in [destination,*destination.parents]):
        raise ValueError('A new nonsymlink staging directory is required.')
    destination.mkdir(mode=0o700)
    for item in value['edgeFiles']:
        dest=destination/item['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source_file(root,item['path']),dest)
        if digest(dest.read_bytes())!=item['sha256']:raise ValueError('Copied source hash differs.')
    (destination/'backend-release.json').write_text(json.dumps(value,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-snapshot',action='store_true')
    parser.add_argument('--stage-edges',type=Path)
    args=parser.parse_args()
    if args.write_snapshot:OUTPUT.write_text(json.dumps(build_manifest(),indent=2)+'\n')
    value=json.loads(OUTPUT.read_text());verify_manifest(value)
    if args.stage_edges:stage_edges(args.stage_edges,value)
    print(json.dumps({'status':'OFFLINE_SOURCE_PASS','candidate':value['candidate'],'projectRef':PROJECT_REF,
                      'migrations':len(value['migrations']),'edgeFiles':len(value['edgeFiles']),'snapshotSha256':digest(OUTPUT.read_bytes()),'remoteWrites':False}))

if __name__=='__main__':main()
