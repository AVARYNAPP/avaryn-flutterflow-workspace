#!/usr/bin/env python3
"""Read-only Pilot49 backup and real restore to one NEW owned local database.

No remote SQL writes, migration, restore, fixture seed, Auth request or Storage
request. A coordinated short write pause makes the before/dump/after comparison
meaningful. All raw logs, hashes and data stay in private 0600 files.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from check_pilot_connection import ROOT, BASE, EVIDENCE, REF, ORG, configuration, private_write, query
from backup_pilot_database import LOCAL_CONTAINER, LOCAL_CLUSTER, REMOTE_CLUSTER, local, parsed, run, fingerprint_sql, CATALOG as TABLES
from pilot_timezone_increment import IDENTITY, HISTORY, CATALOG, TABLE_SECURITY, readonly, validate_identity, check_local

MANIFEST = ROOT / 'apps/avaryn/config/backend-release.json'
LAST_VERSION = '202609110005'
LAST_SHA = '755aa06c7d613aa887ed8f9c69ce9afe68560c45e00bb19d7955ef85677f98bc'
PREFIX = 'avaryn_pilot49_backup_'
sha = lambda data: hashlib.sha256(data).hexdigest()
COLUMN_SECURITY = """select coalesce(jsonb_agg(jsonb_build_object(
 'table',n.nspname||'.'||c.relname,'column',a.attname,'acl',
 (select coalesce(jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(g.grantor),
 'grantee',case when g.grantee=0 then 'PUBLIC' else pg_get_userbyid(g.grantee) end,
 'privilege',g.privilege_type,'grantable',g.is_grantable) order by pg_get_userbyid(g.grantor),g.grantee::regrole::text,g.privilege_type),'[]')
 from aclexplode(a.attacl) g)) order by n.nspname,c.relname,a.attnum),'[]')
 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
 where a.attnum>0 and not a.attisdropped and c.relkind in('r','p')
 and n.nspname in('public','private','auth','storage');"""


def expected_history(manifest=None):
    value = json.loads(MANIFEST.read_text()) if manifest is None else manifest
    if value.get('projectRef') != REF or value.get('organizationId') != ORG:
        raise ValueError('SOURCE_TARGET_MISMATCH')
    items = value.get('migrations', [])
    if len(items) != 49 or len({i['version'] for i in items}) != 49:
        raise ValueError('EXACT49_REQUIRED')
    rows = []
    for item in items:
        relative = Path(item['path'])
        path = ROOT / relative
        if (relative.is_absolute() or '..' in relative.parts or relative.parent != Path('supabase/migrations')
                or path.is_symlink() or not re.fullmatch(r'\d{12}_[a-z0-9_]+\.sql', relative.name)):
            raise ValueError('SOURCE_PATH_INVALID')
        if sha(path.read_bytes()) != item['sha256'] or not relative.name.startswith(item['version'] + '_'):
            raise ValueError('SOURCE_CHECKSUM_MISMATCH')
        rows.append({'version': item['version'], 'name': relative.stem[13:],
                     'sha256': item['sha256'], 'statement_count': 1})
    if rows != sorted(rows, key=lambda r: r['version']) or rows[-1]['version'] != LAST_VERSION or rows[-1]['sha256'] != LAST_SHA:
        raise ValueError('FINAL49_SOURCE_MISMATCH')
    return rows


def restore_name(stamp):
    if not re.fullmatch(r'\d{8}T\d{6}Z', stamp):
        raise ValueError('RESTORE_STAMP_INVALID')
    return PREFIX + stamp.lower()


def identical(before, after, label):
    if before != after:
        raise ValueError(label + '_DIFFERS_STOP_NO_RETRY')


class Backup:
    def __init__(self):
        self.expected = expected_history()
        self.env = configuration()[1]
        check_local()
        self.stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.directory = BASE / ('operational49-' + self.stamp)
        self.directory.mkdir(mode=0o700)
        self.index = 0

    def capture(self, result, label, as_json=True):
        self.index += 1
        for suffix, raw in [('stdout', result.stdout), ('stderr', result.stderr)]:
            private_write(self.directory / f'{self.index:03d}-{label}-{suffix}.log', raw.decode(errors='replace') if isinstance(raw, bytes) else raw)
        if result.returncode:
            raise ValueError(label.upper() + '_FAILED_PRIVATE_LOG')
        return parsed(result) if as_json else result

    def read(self, sql, label):
        return self.capture(query(self.env, sql), label)

    def snapshot(self, label):
        identity = self.read(readonly(IDENTITY), label + '-identity')
        validate_identity(identity)
        history = self.read(readonly(HISTORY), label + '-history')
        identical(self.expected, history, 'MANAGED49_HISTORY')
        tables = self.read(readonly(TABLES), label + '-tables')
        data = {'identity': identity, 'history': history, 'tables': tables,
                'rows': self.read(fingerprint_sql(tables), label + '-rows'),
                'catalog': self.read(readonly(CATALOG), label + '-catalog'),
                'security': self.read(readonly(TABLE_SECURITY), label + '-security'),
                'columnSecurity': self.read(readonly(COLUMN_SECURITY), label + '-column-security')}
        private_write(self.directory / (label + '.json'), json.dumps(data, indent=2) + '\n')
        return data

    def execute(self):
        before = self.snapshot('before')
        tls = self.capture(query(self.env, '\\conninfo\n'), 'client-tls', False)
        if not any(line.startswith('SSL connection (') for line in tls.stdout.splitlines()):
            raise ValueError('TLS_NOT_CONFIRMED')
        # Complete database archive: no data/schema exclusions, no CLI dump.
        archive = self.directory / 'pilot49-full.dump'
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with os.fdopen(os.open(archive, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as stream:
            result = subprocess.run(['/opt/homebrew/bin/pg_dump', '-w', '--format=custom'],
                                    stdout=stream, stderr=subprocess.PIPE, env=self.env, timeout=240)
        private_write(self.directory / 'dump-stderr.log', result.stderr.decode(errors='replace'))
        if result.returncode or archive.stat().st_size < 10000:
            raise ValueError('FULL_BACKUP_FAILED')
        finished = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.capture(run(['/opt/homebrew/bin/pg_restore', '--list', str(archive)]), 'archive-list', False)
        self.capture(run(['/opt/homebrew/bin/pg_restore', '--file=/dev/null', str(archive)]), 'archive-decode', False)
        identical(before, self.snapshot('after-dump'), 'SOURCE_DURING_DUMP')
        archive_sha = sha(archive.read_bytes())
        database = restore_name(self.stamp)
        marker = {'project_ref': REF, 'remote_cluster': REMOTE_CLUSTER, 'local_container': LOCAL_CONTAINER,
                  'local_cluster': LOCAL_CLUSTER, 'database': database, 'backup_sha256': archive_sha,
                  'created_at': self.stamp, 'remote_writes': False, 'restores_over_existing_database': False}
        private_write(self.directory / 'restore-target.json', json.dumps(marker, indent=2) + '\n')
        print(json.dumps({'status': 'BACKUP_CAPTURED', 'dumpCompletedAt': finished,
                          'privateRun': str(self.directory.relative_to(ROOT)), 'remoteWrites': False}), flush=True)
        # Only a name generated in this invocation. Existing database => refusal;
        # there is deliberately no DROP, reset, restore-in-place or retry option.
        check_local()
        exists = parsed(local("select to_jsonb(exists(select 1 from pg_database where datname='" + database + "'));"))
        if exists:
            raise ValueError('RESTORE_DESTINATION_ALREADY_EXISTS')
        created = run(['docker', 'exec', '-i', LOCAL_CONTAINER, 'psql', '-X', '-q', '-w', '-U', 'supabase_admin',
                       '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
                      input=('create database ' + database + ' owner postgres template template0;').encode())
        self.capture(created, 'create-new-scratch', False)
        with archive.open('rb') as stream:
            restored = subprocess.run(['docker', 'exec', '-i', LOCAL_CONTAINER, 'pg_restore', '-U', 'supabase_admin',
                                       '-d', database, '--single-transaction', '--exit-on-error'], stdin=stream,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=240)
        self.capture(restored, 'actual-restore', False)
        validate_identity(parsed(local(readonly(IDENTITY), database)), False, database)
        for key, sql in [('history', HISTORY), ('tables', TABLES), ('catalog', CATALOG), ('security', TABLE_SECURITY), ('columnSecurity', COLUMN_SECURITY)]:
            identical(before[key], self.capture(local(readonly(sql), database), 'restored-' + key), 'RESTORED_' + key.upper())
        identical(before['rows'], self.capture(local(fingerprint_sql(before['tables']), database), 'restored-rows'), 'RESTORED_ROWS')
        if sha(archive.read_bytes()) != archive_sha or archive.stat().st_mode & 0o777 != 0o600:
            raise ValueError('ARCHIVE_CHANGED')
        storage = self.capture(local(readonly("select coalesce(jsonb_agg(jsonb_build_object('id',id,'bucket_id',bucket_id,'name',name,'size',metadata->>'size','mime',metadata->>'mimetype') order by bucket_id,name),'[]') from storage.objects;"), database), 'storage-inventory')
        private_write(self.directory / 'storage-inventory.json', json.dumps(storage, indent=2) + '\n')
        private_write(self.directory / 'RECOVERY.md',
            'This complete database archive was actually restored and compared in ' + database + '.\n'
            'Never restore over current Pilot or dev data automatically. A disaster recovery requires a separate approved destination/cutover, an intake pause and reconciliation of writes after this snapshot.\n'
            'Use the private restore-target marker, exact archive SHA256 and captured source49 ledger/catalog to verify the destination. Existing Supabase roles/extensions must be present; restore used only existing local supabase_admin and retained owners/effective ACLs. No migration replay.\n'
            'Storage bytes and hosted Auth/SMTP/Edge/hosting configuration are NOT contained in this archive. storage-inventory.json identifies the exact object-byte coverage still required. Never reuse this scratch as the live app backend.\n')
        receipt = {'status': 'PASS_DATABASE_BACKUP_AND_REAL_RESTORE', 'projectRef': REF, 'remoteWrites': False,
                   'historyCount': 49, 'historyHashesMatchCurrentSource': True,
                   'backupBytes': archive.stat().st_size, 'backupSha256': archive_sha, 'backupMode': '0600',
                   'dumpStartedAt': started, 'dumpCompletedAt': finished,
                   'comparedTableCount': len(before['tables']), 'allTableRowHashesEqual': True,
                   'catalogOwnersEffectivePrivilegesRlsEqual': True, 'sourcePreservedDuringDump': True,
                   'restoreDestination': 'new isolated local database', 'existingDevDataModified': False,
                   'storageObjectMetadataCount': len(storage), 'storageBytesBackedUpByThisCommand': False,
                   'hostedConfigurationBackedUpByThisCommand': False,
                   'sourceManifestSha256': sha(MANIFEST.read_bytes()), 'scriptSha256': sha(Path(__file__).read_bytes()),
                   'limits': ['No remote restore or automatic rollback.',
                              'Only the database is restored; Storage bytes and managed configuration require separate coverage.',
                              'Later live application writes are outside this snapshot.']}
        private_write(self.directory / 'receipt.json', json.dumps(receipt, indent=2) + '\n')
        out = EVIDENCE / ('operational49-' + self.stamp + '.json')
        out.write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps({'status': receipt['status'], 'evidence': str(out.relative_to(ROOT)),
                          'backupSha256': archive_sha, 'tableCount': len(before['tables']), 'remoteWrites': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root-reviewed', action='store_true', required=True)
    parser.add_argument('--writes-paused', action='store_true', required=True)
    parser.parse_args()
    os.umask(0o077)
    Backup().execute()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # No libpq error text, command, SQL result, auth data or environment.
        print(json.dumps({'status': 'BLOCKED', 'code': str(error) if isinstance(error, ValueError) else type(error).__name__, 'remoteWrites': False}))
        sys.exit(1)
