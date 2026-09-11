#!/usr/bin/env python3
"""Bounded synthetic media gate: exact owned 56860 BFF -> 56801 backend.

Run with bundled Pillow Python. Never prints credentials, response bodies or signed
URLs. Uses fresh sessions of existing synthetic admin_a/outsider; logout is local.
No schema/container/config changes and no writes to existing horses.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.avaryn-local/productization-20260911'
CONFIG = BASE / 'private/dev-vitality-server.json'
FIXTURES = BASE / 'private/dev-vitality-fixtures.json'
ENV = ROOT / '.avaryn-local/c010-productization-20260911/private/local-environments/avaryn-c010-vitality-20260911-a/environment.json'
ORIGIN = 'http://127.0.0.1:56860'
UPSTREAM = 'http://127.0.0.1:56801'
TARGET = 'avaryn-c010-vitality-20260911-a'
OWNER = 'avaryn-route-b-v1'
INPUT = ROOT / 'apps/avaryn/src/assets/orion.png'
SOURCES = ['apps/avaryn/scripts/dev-server.mjs', 'apps/avaryn/src/media-path.js',
           'apps/avaryn/config/rpc-routes.json', 'supabase/functions/media-assets/index.ts',
           'supabase/migrations/202608080003_c0091_canonical_media_hardening.sql']
SAFE_CODE = re.compile(r'^[A-Z0-9_]{1,80}$')

class GateFailure(Exception):
    pass

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

class Gate:
    def __init__(self):
        self.run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
        self.private = BASE / 'private/media-http' / self.run_id
        self.evidence = BASE / 'evidence' / ('media-http-' + self.run_id + '.json')
        self.report = {'run_id': self.run_id, 'status': 'RUNNING', 'target': TARGET,
                       'scope': 'Own new synthetic horse only; fresh sessions; no global logout',
                       'checks': [], 'requests': [], 'retained_own_records': {},
                       'source_hashes_before': self.hashes()}
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        self.tokens = {}
        self.config = None

    def hashes(self):
        return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES}

    def check(self, label, condition, **facts):
        self.report['checks'].append({'name': label, 'status': 'PASS' if condition else 'FAIL', **facts})
        if not condition:
            raise GateFailure(label)

    def private_json(self, path):
        info = path.lstat()
        self.check('private_file_' + path.name, stat.S_ISREG(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o600)
        return json.loads(path.read_text())

    def request(self, label, path, method='POST', body=None, token=None, headers=None, direct=False):
        base = UPSTREAM if direct else ORIGIN
        # All callers must supply paths, never arbitrary endpoints or signed hosts.
        if not path.startswith('/') or path.startswith('//') or '#' in path:
            raise GateFailure('nonlocal_request_rejected')
        hdr = {'Origin': ORIGIN}
        if direct:
            hdr['apikey'] = self.config['anonKey']
        if token:
            hdr['Authorization'] = 'Bearer ' + token
        if headers:
            hdr.update(headers)
        if body is not None and not isinstance(body, bytes):
            body = json.dumps(body).encode()
            hdr.setdefault('Content-Type', 'application/json')
        started = time.monotonic()
        req = urllib.request.Request(base + path, data=body, headers=hdr, method=method)
        try:
            response = self.opener.open(req, timeout=28)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            status = response.code
            data = response.read(11 * 1024 * 1024)
            response_headers = dict(response.headers)
        try:
            value = json.loads(data)
        except (json.JSONDecodeError, UnicodeDecodeError):
            value = None
        raw_code = value.get('code') if isinstance(value, dict) else None
        safe_code = raw_code if isinstance(raw_code, str) and SAFE_CODE.fullmatch(raw_code) else None
        self.report['requests'].append({'name': label, 'method': method, 'status': status,
                                        'safe_code': safe_code, 'duration_ms': round((time.monotonic()-started)*1000)})
        return status, value, data, response_headers

    def rpc(self, label, name, args, actor='admin_a'):
        return self.request(label, '/api/rest/v1/rpc/' + name, body=args, token=self.tokens[actor])

    def edge(self, label, body, actor='admin_a'):
        return self.request(label, '/api/functions/v1/media-assets', body=body, token=self.tokens[actor])

    def preflight(self):
        self.config = self.private_json(CONFIG)
        env = self.private_json(ENV)
        fixture = self.private_json(FIXTURES)
        self.check('pinned_config_identity', self.config['projectId'] == TARGET and self.config['upstream'] == UPSTREAM
                   and env['target'] == TARGET and env['ports']['api'] == 56801 and env['ports']['web'] == 56860
                   and env['owner'] == OWNER and self.config['anonKey'] == env['anon_key']
                   and fixture['backendProject'] == TARGET and fixture['target'] == TARGET)
        raw = subprocess.run(['docker', 'ps', '-aq', '--filter', 'label=io.avaryn.local.target=' + TARGET],
                             capture_output=True, check=True, text=True).stdout.split()
        self.check('owned_container_count', len(raw) == 8, count=len(raw))
        containers = json.loads(subprocess.run(['docker', 'inspect', *raw], capture_output=True, check=True, text=True).stdout)
        safe = []
        gateway_match = False
        for c in containers:
            labels = c['Config'].get('Labels', {})
            bindings = c.get('HostConfig', {}).get('PortBindings') or {}
            public = [(port, p['HostIp'], p['HostPort']) for port, values in bindings.items() for p in (values or [])]
            self.check('owned_running_' + c['Name'].strip('/'), labels.get('io.avaryn.local.owner') == OWNER
                       and labels.get('io.avaryn.local.target') == TARGET and c['State']['Running']
                       and all(ip == '127.0.0.1' for _, ip, _ in public))
            gateway_match |= any(host_port == '56801' for _, _, host_port in public)
            safe.append({'id': c['Id'], 'name': c['Name'], 'running': c['State']['Running'], 'loopback_bindings': public})
        self.check('actual_gateway_port_pinned', gateway_match)
        self.report['container_identity'] = safe
        status, runtime, _, _ = self.request('runtime_identity', '/runtime.json', method='GET')
        release = json.loads((ROOT / 'apps/avaryn/dist/version.json').read_text())
        self.check('actual_runtime_matches_release_and_backend', status == 200 and runtime.get('localOnly') is True
                   and runtime.get('backendProject') == TARGET and runtime.get('candidate') == release.get('candidate'))
        self.report['candidate'] = runtime['candidate']
        self.report['release_version_sha256'] = hashlib.sha256((ROOT / 'apps/avaryn/dist/version.json').read_bytes()).hexdigest()
        self.fixtures = fixture

    def signed_path(self, value, expected_operation):
        parsed = urllib.parse.urlsplit(value)
        expected = r'^/storage/v1/object/' + ('upload/sign' if expected_operation == 'upload' else 'sign') + r'/horse-media/canonical/[0-9a-f-]{36}/[0-9a-f-]{36}/(original|thumbnail)$'
        query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
        self.check('signed_' + expected_operation + '_path_contract', bool(re.fullmatch(expected, parsed.path))
                   and len(query) == 1 and query[0][0] == 'token' and bool(query[0][1])
                   and not parsed.fragment and not parsed.username and not parsed.password)
        self.report.setdefault('signed_url_origins', {})[expected_operation] = parsed.scheme + '://' + parsed.netloc
        return '/api' + parsed.path + '?' + parsed.query

    def run(self):
        from PIL import Image
        self.private.mkdir(parents=True, mode=0o700)
        os.chmod(self.private, 0o700)
        image = Image.open(INPUT).convert('RGB')
        pictures = {}
        for variant, bounds in [('original', (1024, 1024)), ('thumbnail', (256, 256))]:
            resized = image.copy()
            resized.thumbnail(bounds, Image.Resampling.LANCZOS)
            output = io.BytesIO()
            resized.save(output, format='PNG', optimize=True)
            pictures[variant] = output.getvalue()
            path = self.private / (variant + '.png')
            path.write_bytes(pictures[variant]); path.chmod(0o600)
            self.report.setdefault('image_variants', {})[variant] = {'width': resized.width, 'height': resized.height,
                      'bytes': len(pictures[variant]), 'sha256': hashlib.sha256(pictures[variant]).hexdigest()}
        self.report['image_source'] = {'path': str(INPUT.relative_to(ROOT)), 'sha256': hashlib.sha256(INPUT.read_bytes()).hexdigest(),
                                      'provenance': 'Existing supplied AI-generated illustrative horse; no user horse photo'}
        for actor in ['admin_a', 'outsider']:
            f = self.fixtures['users'][actor]
            self.check('synthetic_confirmed_' + actor, f['email'].endswith('.invalid') and f['mail_confirmed'] is True)
            status, value, _, _ = self.request('login_' + actor, '/api/auth/v1/token?grant_type=password', body={'email': f['email'], 'password': f['password']})
            self.check('own_fresh_session_' + actor, status == 200 and value.get('user', {}).get('id') == f['user_id'] and bool(value.get('access_token')))
            self.tokens[actor] = value['access_token']
        # Test the transport boundary before creating any domain data.
        status, _, _, _ = self.request('missing_bearer', '/api/functions/v1/media-assets', body={'action':'canonical_create'})
        self.check('missing_bearer_denied', status == 401)
        status, _, _, _ = self.request('foreign_origin', '/api/functions/v1/media-assets', body={'action':'canonical_create'}, token=self.tokens['admin_a'], headers={'Origin':'https://foreign.invalid'})
        self.check('foreign_origin_denied', status == 403)
        status, _, _, _ = self.request('malformed_json', '/api/functions/v1/media-assets', body=b'{', token=self.tokens['admin_a'], headers={'Content-Type':'application/json'})
        self.check('malformed_json_denied', status == 400)
        horse_name = 'HTTP mediaproef ' + self.run_id
        params = {'p_display_name': horse_name, 'p_official_name': None, 'p_birth_date': None, 'p_sex':'unknown',
                  'p_breed':None, 'p_discipline':None, 'p_level':None, 'p_color':None,
                  'p_notes':'Eigen synthetisch paard voor afgebakende media-HTTPcontrole; geen gebruikersdata.',
                  'p_chip_number':None,'p_passport_number':None,'p_passport_valid_until':None,'p_correlation_id':str(uuid.uuid4())}
        status, value, _, _ = self.rpc('create_own_horse', 'create_canonical_horse_profile', params)
        self.check('own_horse_created', status == 200 and isinstance(value, list) and bool(value[0].get('horse_id')))
        horse = value[0]['horse_id']; horse_version = value[0]['row_version']
        self.report['retained_own_records']['horse'] = {'id':horse,'name':horse_name,'status':'active'}
        self.save()
        status, session, _, _ = self.edge('canonical_create', {'action':'canonical_create','horse_id':horse,'original_filename':'synthetic-horse.png','mime_type':'image/png','request_id':str(uuid.uuid4())})
        self.check('two_variant_session', status == 200 and session.get('status') == 'pending' and {u['variant'] for u in session.get('uploads', [])} == {'original','thumbnail'})
        asset = session['media_asset_id']
        self.report['retained_own_records']['ready_asset'] = {'id':asset,'status':'pending'}
        self.save()
        descriptors = {d['variant']:d for d in session['uploads']}
        original_path = self.signed_path(descriptors['original']['signed_upload_url'], 'upload')
        status, _, _, _ = self.request('wrong_variant_upload_signature', original_path.replace('/original?', '/thumbnail?'), method='PUT', body=pictures['thumbnail'], token=self.tokens['admin_a'], headers={'Content-Type':'image/png'})
        self.check('wrong_variant_upload_signature_denied', status in [400,401,403])
        for variant in ['original', 'thumbnail']:
            desc = descriptors[variant]; path = self.signed_path(desc['signed_upload_url'], 'upload')
            self.check('declared_' + variant + '_mime_size', desc['expected_mime_type'] == 'image/png' and len(pictures[variant]) <= desc['max_byte_size'])
            status, _, _, _ = self.request('signed_put_' + variant, path, method='PUT', body=pictures[variant], token=self.tokens['admin_a'], headers={'Content-Type':'image/png'})
            self.check('uploaded_' + variant, status in [200,201])
        status, ready, _, _ = self.edge('canonical_finalize', {'action':'canonical_finalize','media_asset_id':asset,'expected_row_version':session['row_version'],'request_id':str(uuid.uuid4())})
        self.check('finalize_valid_png_ready', status == 200 and ready.get('status') == 'ready' and ready.get('media_asset_id') == asset)
        self.report['retained_own_records']['ready_asset']['status'] = 'ready'
        status, selected, _, _ = self.rpc('select_profile_media', 'set_canonical_horse_profile_media', {'p_horse_id':horse,'p_media_asset_id':asset,'p_expected_row_version':horse_version,'p_request_id':str(uuid.uuid4())})
        self.check('profile_media_selected', status == 200 and selected.get('profile_media_asset_id') == asset and selected.get('horse_id') == horse)
        self.report['retained_own_records']['horse']['profile_media_asset_id'] = asset
        self.save()
        signed_download = None
        for variant in ['original','thumbnail']:
            status, value, _, _ = self.edge('canonical_download_' + variant, {'action':'canonical_download','media_asset_id':asset,'variant':variant})
            self.check('download_authorized_' + variant, status == 200 and value.get('mime_type') == 'image/png' and value.get('expires_in') == 60)
            path = self.signed_path(value['signed_download_url'], 'download')
            status, _, data, hdr = self.request('signed_get_' + variant, path, method='GET', token=self.tokens['admin_a'])
            self.check('download_bytes_' + variant, status == 200 and data == pictures[variant] and hdr.get('Content-Type','').startswith('image/png'))
            decoded = Image.open(io.BytesIO(data)); decoded.load()
            expected = self.report['image_variants'][variant]
            self.check('decoded_' + variant + '_dimensions', decoded.size == (expected['width'],expected['height']))
            self.check('private_download_cache_' + variant, hdr.get('Cache-Control') == 'no-store' and hdr.get('Referrer-Policy') == 'no-referrer')
            signed_download = path
        status, _, _, _ = self.request('tampered_signature', signed_download.split('?')[0] + '?token=invalid.signature.value', method='GET', token=self.tokens['admin_a'])
        self.check('tampered_signature_denied', status in [400,401,403])
        status, _, _, _ = self.request('wrong_variant_download_signature', signed_download.replace('/thumbnail?', '/original?'), method='GET', token=self.tokens['admin_a'])
        self.check('wrong_variant_download_signature_denied', status in [400,401,403])
        status, _, _, _ = self.request('unknown_variant_path', signed_download.replace('/thumbnail?', '/preview?'), method='GET', token=self.tokens['admin_a'])
        self.check('unknown_variant_path_denied', status == 404)
        status, _, _, _ = self.edge('outsider_download_authorization', {'action':'canonical_download','media_asset_id':asset,'variant':'original'}, 'outsider')
        self.check('outsider_cannot_obtain_signed_url', status == 404)
        status, _, _, _ = self.edge('outsider_create', {'action':'canonical_create','horse_id':horse,'original_filename':'blocked.png','mime_type':'image/png','request_id':str(uuid.uuid4())}, 'outsider')
        self.check('outsider_cannot_create_media', status in [403,404,409])
        status, rows, _, _ = self.rpc('owner_list_reload', 'list_c010_horses', {})
        row = next((r for r in rows if r.get('horse_id') == horse), None) if isinstance(rows,list) else None
        self.check('reload_keeps_exact_profile_media', status == 200 and row and row.get('profile_media_asset_id') == asset)
        status, rows, _, _ = self.rpc('outsider_list_reload', 'list_c010_horses', {}, 'outsider')
        self.check('outsider_list_has_no_own_horse', status == 200 and isinstance(rows,list) and not any(r.get('horse_id') == horse for r in rows))
        # A second own asset proves real content decoding, not just a file extension/MIME claim.
        status, bad, _, _ = self.edge('malformed_image_create', {'action':'canonical_create','horse_id':horse,'original_filename':'malformed.png','mime_type':'image/png','request_id':str(uuid.uuid4())})
        self.check('malformed_test_session_created', status == 200 and bad.get('status') == 'pending')
        self.report['retained_own_records']['malformed_asset'] = {'id':bad['media_asset_id'],'status':'pending','purpose':'Invalid PNG finalization refusal evidence'}
        self.save()
        for desc in bad['uploads']:
            data = pictures[desc['variant']][:-20] if desc['variant'] == 'original' else pictures['thumbnail']
            status, _, _, _ = self.request('malformed_put_' + desc['variant'], self.signed_path(desc['signed_upload_url'],'upload'), method='PUT', body=data, token=self.tokens['admin_a'], headers={'Content-Type':'image/png'})
            self.check('malformed_uploaded_' + desc['variant'], status in [200,201])
        status, value, _, _ = self.edge('malformed_image_finalize', {'action':'canonical_finalize','media_asset_id':bad['media_asset_id'],'expected_row_version':bad['row_version'],'request_id':str(uuid.uuid4())})
        self.check('real_decoder_rejects_truncated_png', status == 409 and value.get('code') == 'MEDIA_CONTENT_TYPE_INVALID')
        status, _, _, _ = self.edge('malformed_asset_cannot_download', {'action':'canonical_download','media_asset_id':bad['media_asset_id'],'variant':'original'})
        self.check('pending_malformed_asset_unavailable', status == 404)
        self.report['status'] = 'PASS'

    def logout_local(self):
        for actor, token in list(self.tokens.items()):
            try:
                status, _, _, _ = self.request('own_session_logout_local_' + actor, '/auth/v1/logout?scope=local', body={}, token=token, direct=True)
                self.report['checks'].append({'name':'local_logout_' + actor,'status':'PASS' if status in [200,204] else 'FAIL','http_status':status})
            except Exception as error:
                self.report['checks'].append({'name':'local_logout_' + actor,'status':'FAIL','error_type':type(error).__name__})
        self.tokens.clear()

    def save(self):
        self.report['source_hashes_after'] = self.hashes()
        self.report['source_hashes_unchanged'] = self.report['source_hashes_before'] == self.report['source_hashes_after']
        self.report['completed_at'] = datetime.now(timezone.utc).isoformat()
        self.evidence.parent.mkdir(parents=True, exist_ok=True)
        self.evidence.write_text(json.dumps(self.report,indent=2)+'\n')
        if self.private.exists():
            p=self.private/'owned-records.json';p.write_text(json.dumps(self.report['retained_own_records'],indent=2)+'\n');p.chmod(0o600)

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--preflight-only',action='store_true');args=parser.parse_args()
    gate=Gate()
    try:
        gate.preflight()
        if args.preflight_only:
            gate.report['status']='PASS';gate.report['mode']='read-only preflight'
        else:
            gate.run()
    except Exception as error:
        gate.report['status']='FAIL'
        gate.report['failure']={'type':type(error).__name__, 'check':str(error) if isinstance(error,GateFailure) else 'redacted_runtime_failure'}
    finally:
        gate.logout_local()
        if any(c['status']=='FAIL' for c in gate.report['checks']):gate.report['status']='FAIL'
        gate.save()
    print(json.dumps({'status':gate.report['status'],'evidence':str(gate.evidence.relative_to(ROOT)),
                      'checks':len(gate.report['checks']),'failed':[c['name'] for c in gate.report['checks'] if c['status']=='FAIL'],
                      'failure':gate.report.get('failure'),'request_count':len(gate.report['requests'])}))
    sys.exit(0 if gate.report['status']=='PASS' else 1)
