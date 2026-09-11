#!/usr/bin/env python3
"""AVARYN disposable local Route-B environment; no linked/remote CLI operations."""
import argparse
import base64
import datetime as dt
import fcntl
import hashlib
import hmac
import html
import http.server
import json
import os
from pathlib import Path
import re
import secrets
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'a-v-a-r-y-n-alpha-ynvyuq'
OWNER = 'avaryn-route-b-v1'
LABEL = 'io.avaryn.local'
IMAGES = json.loads((ROOT / 'tool/route_b/images.json').read_text())
SERVICES = ('db', 'mail', 'auth', 'rest', 'storage', 'realtime', 'edge', 'gateway')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def private_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.is_symlink():raise ValueError('Refusing private state symlink.')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd,0o600)
    with os.fdopen(fd, 'w') as handle:
        json.dump(value, handle, indent=2)
        handle.write('\n')

def run(argv, *, data=None, check=True, cwd=None):
    result = subprocess.run([str(x) for x in argv], input=data, text=True,
                            capture_output=True, cwd=cwd)
    if check and result.returncode:
        raise RuntimeError('Command failed: ' + str(argv[0]) + ' ' + str(argv[1]) +
                           ' (details suppressed; inspect only this target privately)')
    return result

def docker(*args, check=True, data=None):
    return run(['docker', *args], check=check, data=data)

def inspect(name):
    result = docker('container','inspect', name, check=False)
    if result.returncode:
        return None
    return json.loads(result.stdout)[0]

def validate_target(target):
    if not re.fullmatch(r'avaryn-c010-[a-z0-9][a-z0-9-]{3,45}', target):
        raise ValueError('Explicit target must begin avaryn-c010- and use only lower-case letters/digits/hyphens.')

def product_context(args):
    if not getattr(args,'product_client',False):return None
    if not getattr(args,'backend_only',False):
        raise ValueError('--product-client requires --backend-only; this runner never builds or serves the product client.')
    if getattr(args,'reuse_build',False):raise ValueError('--reuse-build belongs to the legacy Flutter client, not --product-client.')
    if getattr(args,'command',None)=='verify' and not getattr(args,'smoke_only',False):
        raise ValueError('Product verification requires --smoke-only; legacy Flutter suites are not product evidence.')
    result=run(['node',ROOT/'apps/avaryn/scripts/local-backend-config.mjs','--provenance-only'],check=False)
    if result.returncode:raise ValueError('Public AVARYN product provenance could not be validated.')
    try:
        provenance=json.loads(result.stdout)
        paths=['package.json','capacitor.config.json','config/release.json']
        if (provenance.get('packageName')!='@avaryn/client'
                or not re.fullmatch(r'C010-V8-[A-Z0-9-]{1,140}',provenance.get('candidate',''))
                or provenance.get('files')!={p:digest((ROOT/'apps/avaryn'/p).read_bytes()) for p in paths}):
            raise ValueError('Invalid provenance.')
    except (ValueError,TypeError,AttributeError):
        raise ValueError('Public AVARYN product provenance could not be validated.') from None
    return provenance

def load_context(args, create=False):
    validate_target(args.target)
    product=product_context(args)
    if product is None:
        binding = json.loads((ROOT / '.flutterflow/workspace.json').read_text())
        if binding.get('projectId') != PROJECT:
            raise ValueError('Wrong workspace project; AVARYN only.')
    state_root = Path(args.state_dir).expanduser().resolve() if args.state_dir else ROOT / '.avaryn-local'
    state_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(state_root, 0o700)
    state = state_root / args.target
    if state.is_symlink():raise ValueError('Environment directory must not be a symlink.')
    state.mkdir(exist_ok=True, mode=0o700)
    cfgfile = state / 'environment.json'
    if cfgfile.exists():
        if product is not None and (cfgfile.is_symlink() or not cfgfile.is_file() or cfgfile.stat().st_mode&0o777!=0o600):
            raise ValueError('Product environment must be a regular private 0600 file.')
        cfg = json.loads(cfgfile.read_text())
        if cfg.get('target') != args.target or cfg.get('project_id') != PROJECT or cfg.get('owner') != OWNER:
            raise ValueError('Unrecognized environment ownership.')
        if cfg.get('client_mode')=='product' and product is None:
            raise ValueError('This target requires explicit --product-client --backend-only.')
        if product is not None and cfg.get('hosted_preview_origin'):
            raise ValueError('Product development cannot adopt a hosted preview target.')
    elif create:
        base = args.port_base
        if base is None or not 1024 <= base <= 65470:
            raise ValueError('prepare requires explicit --port-base between 1024 and 65470.')
        cfg = {'target': args.target, 'project_id': PROJECT, 'owner': OWNER,
               'created_at': dt.datetime.now(dt.timezone.utc).isoformat(),
               'ports': {'api': base+1, 'db': base+2, 'mail': base+4, 'web': args.web_port or base+60},
               'jwt_secret': secrets.token_urlsafe(48), 'db_password': secrets.token_hex(24)}
        issued = int(time.time())
        def jwt(role):
            enc = lambda v: base64.urlsafe_b64encode(json.dumps(v,separators=(',',':')).encode()).rstrip(b'=').decode()
            body = enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'role':role,'iss':'supabase-local','iat':issued,'exp':issued+10*365*86400})
            return body+'.'+base64.urlsafe_b64encode(hmac.new(cfg['jwt_secret'].encode(),body.encode(),hashlib.sha256).digest()).rstrip(b'=').decode()
        cfg['anon_key'], cfg['service_key'] = jwt('anon'), jwt('service_role')
        if product is not None:cfg.update(client_mode='product',product_provenance=product)
        private_json(cfgfile,cfg)
    else:
        raise ValueError('Unknown target; run prepare first.')
    if not re.fullmatch(r'[a-f0-9]{48}',cfg.get('db_password','')):raise ValueError('Invalid local DB credential shape.')
    if len(set(cfg['ports'].values())) != len(cfg['ports']) or any(not 1024 <= p <= 65535 for p in cfg['ports'].values()):
        raise ValueError('Invalid or overlapping port configuration.')
    cfg['state'] = state
    cfg['api_url'] = f"http://127.0.0.1:{cfg['ports']['api']}"
    cfg['preview_url'] = f"http://127.0.0.1:{cfg['ports']['web']}"
    if product is not None:cfg.update(product_client=True,product_provenance=product)
    return cfg

def name(cfg, service):
    return cfg['target']+'-'+service

def labels(cfg):
    return {LABEL+'.owner':OWNER,LABEL+'.target':cfg['target'],LABEL+'.project':PROJECT}

def verify_container(cfg, service, obj=None):
    obj = obj or inspect(name(cfg,service))
    if not obj or any(obj['Config'].get('Labels',{}).get(k)!=v for k,v in labels(cfg).items()):
        raise ValueError('Container ownership mismatch: '+service)
    if obj['Config'].get('Image')!=IMAGES[service]:raise ValueError('Container image differs from pinned input: '+service)
    hc=obj['HostConfig']
    if hc.get('NetworkMode')!=cfg['target'] or hc.get('Privileged') or hc.get('PublishAllPorts'):
        raise ValueError('Unsafe container network or privilege: '+service)
    expected={'db':{'5432/tcp':cfg['ports']['db']},'mail':{'8025/tcp':cfg['ports']['mail']},'gateway':{'8000/tcp':cfg['ports']['api']}}.get(service,{})
    bindings=hc.get('PortBindings') or {}
    if set(bindings)!=set(expected):
        raise ValueError('Unexpected host ports: '+service)
    for port, entries in bindings.items():
        if entries!=[{'HostIp':'127.0.0.1','HostPort':str(expected[port])}]:
            raise ValueError('Non-loopback or unexpected binding: '+service)
    if set(obj['NetworkSettings']['Networks'])!={cfg['target']}:
        raise ValueError('Unexpected additional network: '+service)
    return {'service':service,'container':name(cfg,service),'running':obj['State']['Running'],
            'ports':bindings,'image':obj['Image'],'network':hc['NetworkMode']}

def envfile(cfg, service, values):
    f=cfg['state']/(service+'.env')
    content=''.join(str(k)+'='+str(v)+'\n' for k,v in values.items())
    if any('\n' in str(v) for v in values.values()):
        raise ValueError('Multiline container environment is forbidden.')
    fd=os.open(f,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
    with os.fdopen(fd,'w') as h:h.write(content)
    return f

def preview_origins(cfg):
    port=cfg['ports']['web']
    if not isinstance(port,int) or isinstance(port,bool) or not 1024<=port<=65535:
        raise ValueError('Invalid local preview port.')
    # Two names for the same explicitly loopback-bound server. Browser storage
    # stays separate so two real users can exercise realtime access changes.
    origins = [f'http://127.0.0.1:{port}',f'http://localhost:{port}']
    if cfg.get('hosted_preview_origin'):
        origins.append(hosted_preview_origin(cfg))
    return origins

def hosted_preview_origin(cfg):
    origin = cfg['hosted_preview_origin']
    parsed = urllib.parse.urlsplit(origin)
    if (parsed.scheme != 'https' or not parsed.hostname
            or origin != 'https://' + parsed.hostname
            or not parsed.hostname.endswith('.chatgpt.site')):
        raise ValueError('Hosted local backend requires the separate private Sites origin.')
    return origin

def auth_redirects(cfg):
    if not cfg.get('hosted_preview_origin'):
        return cfg['preview_url']+'/**'
    # The hosted environment uses exact callback paths on the two existing
    # loopback names and the separately approved HTTPS preview.
    return ','.join(origin + path for origin in preview_origins(cfg)
                    for path in ['', '/', '/auth/callback', '/auth/reset-password'])

def configs(cfg):
    db=name(cfg,'db'); mail=name(cfg,'mail'); uri=lambda role:f"postgresql://{role}:{cfg['db_password']}@{db}:5432/postgres"
    public_url = hosted_preview_origin(cfg) if cfg.get('hosted_preview_origin') else cfg['api_url']
    common={'GOTRUE_API_HOST':'0.0.0.0','GOTRUE_API_PORT':'9999','API_EXTERNAL_URL':public_url+'/auth/v1',
      'GOTRUE_SITE_URL':hosted_preview_origin(cfg) if cfg.get('hosted_preview_origin') else cfg['preview_url'],
      'GOTRUE_URI_ALLOW_LIST':auth_redirects(cfg),
      'GOTRUE_DB_DRIVER':'postgres','GOTRUE_DB_DATABASE_URL':uri('supabase_auth_admin'),
      'GOTRUE_JWT_SECRET':cfg['jwt_secret'],'GOTRUE_JWT_EXP':'3600','GOTRUE_JWT_AUD':'authenticated',
      'GOTRUE_JWT_ADMIN_ROLES':'service_role','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated',
      'GOTRUE_DISABLE_SIGNUP':'true' if cfg.get('hosted_preview_origin') else 'false',
      'GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_EXTERNAL_PHONE_ENABLED':'false',
      'GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED':'false','GOTRUE_MAILER_AUTOCONFIRM':'false',
      'GOTRUE_SMTP_HOST':mail,'GOTRUE_SMTP_PORT':'1025','GOTRUE_SMTP_ADMIN_EMAIL':'noreply@avaryn.local',
      'GOTRUE_SMTP_SENDER_NAME':'AVARYN local','GOTRUE_SMTP_MAX_FREQUENCY':'0s',
      'GOTRUE_RATE_LIMIT_EMAIL_SENT':'1000','GOTRUE_RATE_LIMIT_VERIFY':'1000','GOTRUE_PASSWORD_MIN_LENGTH':'12',
      'GOTRUE_MAILER_URLPATHS_CONFIRMATION':'/auth/v1/verify','GOTRUE_MAILER_URLPATHS_INVITE':'/auth/v1/verify',
      'GOTRUE_MAILER_URLPATHS_RECOVERY':'/auth/v1/verify','GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE':'/auth/v1/verify'}
    storage={'ANON_KEY':cfg['anon_key'],'SERVICE_KEY':cfg['service_key'],'AUTH_JWT_SECRET':cfg['jwt_secret'],
      'POSTGREST_URL':f'http://{name(cfg,"rest")}:3000','DATABASE_URL':uri('supabase_storage_admin'),'STORAGE_BACKEND':'file','FILE_STORAGE_BACKEND_PATH':'/var/lib/storage',
      'GLOBAL_S3_BUCKET':'local','REGION':'local','TENANT_ID':cfg['target'],'FILE_SIZE_LIMIT':'52428800',
      'ENABLE_IMAGE_TRANSFORMATION':'false','S3_PROTOCOL_ENABLED':'false'}
    kong={'_format_version':'2.1','_transform':True,
      'consumers':[{'username':'anon','keyauth_credentials':[{'key':cfg['anon_key']}]},
                   {'username':'service','keyauth_credentials':[{'key':cfg['service_key']}]}],
      'plugins':[{'name':'cors','config':{'origins':preview_origins(cfg),
      'headers':['Authorization','Content-Type','apikey','X-Client-Info','Prefer','Range','Accept-Profile','Content-Profile','X-Supabase-Api-Version','X-Upsert'],
      'methods':['GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS'],
      'exposed_headers':['Content-Range','Range-Unit','X-Total-Count'],'credentials':True}}], 'services':[]}
    for service,prefix,port in [('auth','/auth/v1/',9999),('rest','/rest/v1/',3000),('storage','/storage/v1/',5000),('edge','/functions/v1/',9000)]:
        kong['services'].append({'name':service,'url':f'http://{name(cfg,service)}:{port}/',
          'routes':[{'name':service,'paths':[prefix],'strip_path':True}],
          'plugins':[{'name':'key-auth','config':{'key_names':['apikey'],'hide_credentials':False}}]})
    kong['services'].append({'name':'auth-confirm','url':f'http://{name(cfg,"auth")}:9999/verify',
      'routes':[{'name':'auth-confirm','paths':['/auth/v1/verify'],'strip_path':True}]})
    kong['services'].append({'name':'realtime','url':f'http://realtime-dev.{cfg["target"]}:4000/socket',
      'routes':[{'name':'realtime','paths':['/realtime/v1/'],'strip_path':True}],
      'plugins':[{'name':'key-auth','config':{'key_names':['apikey'],'hide_credentials':False}}]})
    private_json(cfg['state']/'gateway.json',kong)
    return {'db':{'POSTGRES_PASSWORD':cfg['db_password'],'POSTGRES_USER':'supabase_admin','POSTGRES_DB':'postgres',
      'JWT_SECRET':cfg['jwt_secret'],'JWT_EXP':'3600'},'mail':{'MP_SMTP_DISABLE_RDNS':'true'},'auth':common,
      'rest':{'PGRST_DB_URI':uri('authenticator'),'PGRST_DB_SCHEMAS':'public','PGRST_DB_ANON_ROLE':'anon',
      'PGRST_JWT_SECRET':cfg['jwt_secret'],'PGRST_DB_EXTRA_SEARCH_PATH':'public,extensions','PGRST_DB_MAX_ROWS':'1000'},
      'realtime':{'PORT':'4000','DB_HOST':db,'DB_PORT':'5432','DB_USER':'supabase_admin','DB_PASSWORD':cfg['db_password'],'DB_NAME':'postgres','DB_AFTER_CONNECT_QUERY':'SET search_path TO _realtime','DB_ENC_KEY':cfg['db_password'][:16],'API_JWT_SECRET':cfg['jwt_secret'],'SECRET_KEY_BASE':hashlib.sha512(cfg['jwt_secret'].encode()).hexdigest(),'METRICS_JWT_SECRET':cfg['jwt_secret'],'ERL_AFLAGS':'-proto_dist inet_tcp','DNS_NODES':"''",'RLIMIT_NOFILE':'10000','APP_NAME':'realtime','SEED_SELF_HOST':'true','RUN_JANITOR':'true','DISABLE_HEALTHCHECK_LOGGING':'true'},
      'edge':{'JWT_SECRET':cfg['jwt_secret'],'SUPABASE_URL':f'http://{name(cfg,"gateway")}:8000',
      'SUPABASE_PUBLIC_URL':public_url,'SUPABASE_ANON_KEY':cfg['anon_key'],
      'AVARYN_ALLOWED_ORIGINS':','.join(preview_origins(cfg)),
      'AVARYN_INVITATION_URL':(hosted_preview_origin(cfg) if cfg.get('hosted_preview_origin') else cfg['preview_url'])+'/uitnodiging',
      'SUPABASE_SERVICE_ROLE_KEY':cfg['service_key'],'VERIFY_JWT':'false'},
      'storage':storage,'gateway':{'KONG_DATABASE':'off','KONG_DECLARATIVE_CONFIG':'/home/kong/avaryn.json',
      'KONG_PROXY_LISTEN':'0.0.0.0:8000','KONG_ADMIN_LISTEN':'off','KONG_PLUGINS':'bundled',
      'KONG_NGINX_WORKER_PROCESSES':'1','KONG_DNS_ORDER':'LAST,A,CNAME'}}

def prepare(cfg):
    existing=docker('network','inspect',cfg['target'],check=False)
    if existing.returncode:
        args=['network','create','--opt','com.docker.network.bridge.host_binding_ipv4=127.0.0.1']
        for k,v in labels(cfg).items():args+=['--label',k+'='+v]
        docker(*args,cfg['target'])
    else:
        net=json.loads(existing.stdout)[0]
        if net.get('Driver')!='bridge' or net.get('Internal') or net.get('Options',{}).get('com.docker.network.bridge.host_binding_ipv4')!='127.0.0.1':raise ValueError('Network configuration mismatch; refuse reuse.')
        if any(net.get('Labels',{}).get(k)!=v for k,v in labels(cfg).items()):raise ValueError('Network belongs to another environment.')
    envs=configs(cfg)
    for service in SERVICES:
        obj=inspect(name(cfg,service))
        if obj:
            verify_container(cfg,service,obj);continue
        if service in ['db','storage','edge']:
            volume=cfg['target']+'-'+('deno' if service=='edge' else service)
            existing_volume=docker('volume','inspect',volume,check=False)
            if existing_volume.returncode:
                volume_args=['volume','create']
                for k,v in labels(cfg).items():volume_args+=['--label',k+'='+v]
                docker(*volume_args,volume)
            elif any(json.loads(existing_volume.stdout)[0].get('Labels',{}).get(k)!=v for k,v in labels(cfg).items()):
                raise ValueError('Existing volume has no matching ownership: '+service)
        image=IMAGES[service]
        image_info=docker('image','inspect',image,check=False)
        if image_info.returncode:
            raise ValueError('Required pinned image is absent; fetch its exact digest separately: '+service)
        if json.loads(image_info.stdout)[0].get('Architecture')!=IMAGES['architecture']:
            raise ValueError('Pinned image architecture mismatch: '+service)
        args=['create','--name',name(cfg,service),'--network',cfg['target'],'--env-file',envfile(cfg,service,envs[service]),'--restart','no']
        for k,v in labels(cfg).items():args+=['--label',k+'='+v]
        if service=='db':args+=['--publish',f"127.0.0.1:{cfg['ports']['db']}:5432",'--mount',f"type=volume,source={cfg['target']}-db,target=/var/lib/postgresql/data"]
        if service=='mail':args+=['--publish',f"127.0.0.1:{cfg['ports']['mail']}:8025"]
        if service=='gateway':args+=['--publish',f"127.0.0.1:{cfg['ports']['api']}:8000",'--mount',f"type=bind,source={cfg['state']/'gateway.json'},target=/home/kong/avaryn.json,readonly"]
        if service=='edge':args+=['--mount',f'type=bind,source={ROOT/"tool/route_b/edge-main"},target=/home/deno/functions/main,readonly',
          '--mount',f'type=bind,source={ROOT/"supabase/functions"},target=/home/deno/functions/source,readonly',
          '--mount',f'type=volume,source={cfg["target"]}-deno,target=/root/.cache/deno']
        if service=='realtime':args+=['--network-alias',f'realtime-dev.{cfg["target"]}']
        if service=='storage':args+=['--mount',f"type=volume,source={cfg['target']}-storage,target=/var/lib/storage"]
        docker(*args,image,*(['start','--main-service','/home/deno/functions/main'] if service=='edge' else []))
        verify_container(cfg,service) # Actual Docker HostConfig is checked BEFORE START.
    private_json(cfg['state']/'bindings-before-start.json',[verify_container(cfg,s) for s in SERVICES])
    print('Prepared isolated target; all actual Docker bindings checked before startup.')

def sql(cfg, text, check=True, role="supabase_admin"):
    verify_container(cfg,'db')
    result=docker('exec','-i',name(cfg,'db'),'psql','-X','-A','-t','-q','-v','ON_ERROR_STOP=1','-U',role,'-d','postgres',data=text,check=False)
    if check and result.returncode:
        log=cfg['state']/'last-sql-failure.log'; log.write_text(result.stdout+'\n'+result.stderr);os.chmod(log,0o600)
        raise RuntimeError('Local SQL failed; private diagnostic: '+str(log))
    return result

def wait_for(test, label, attempts=120):
    for _ in range(attempts):
        try:
            if test():return
        except (RuntimeError, OSError):pass
        time.sleep(.5)
    raise RuntimeError('Local readiness timed out: '+label)

def request(cfg, method,path, body=None, token=None, mail=False):
    base=f"http://127.0.0.1:{cfg['ports']['mail']}" if mail else cfg['api_url']
    headers={'apikey':cfg['anon_key']}
    if body is not None:headers['Content-Type']='application/json'
    if token:headers['Authorization']='Bearer '+token
    req=urllib.request.Request(base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=30) as r:return json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        body=e.read().decode(errors='replace')
        try: code=json.loads(body).get('code')
        except ValueError:code=None
        raise RuntimeError('Local HTTP '+str(e.code)+' '+path.split('?')[0]+' code='+str(code))

def migration_transaction(source, version, sha256):
    if not re.fullmatch(r'\d{12}',version) or not re.fullmatch(r'[a-f0-9]{64}',sha256):
        raise ValueError('Invalid migration identity.')
    controls=re.findall(r'(?mi)^(begin|commit);[ \t]*$',source)
    if [c.lower() for c in controls] not in ([],['begin','commit']):
        raise ValueError('Unrecognized migration transaction shape; refuse automatic execution.')
    body=re.sub(r'(?mi)^(begin|commit);[ \t]*$','',source)
    return 'BEGIN;\n'+body+f"\nINSERT INTO avaryn_local_meta.migrations VALUES ('{version}','{sha256}');\nCOMMIT;"

def start_backend(cfg, through=None):
    prepare(cfg)
    verify_container(cfg,'db');docker('start',name(cfg,'db'))
    # The image's temporary init server accepts Unix sockets before role bootstrap.
    # Require its final TCP server before consuming the initialized schemas/roles.
    wait_for(lambda:docker('exec',name(cfg,'db'),'pg_isready','-h','127.0.0.1','-p','5432',check=False).returncode==0,'completed Postgres TCP bootstrap')
    wait_for(lambda:sql(cfg,'SELECT 1;',check=False).returncode==0,'postgres')
    # Private bootstrap: only this newly owned disposable DB; no authorization bypass in client fixtures.
    password=cfg['db_password']
    sql(cfg,"\n".join(f"ALTER ROLE {r} WITH PASSWORD '{password}';" for r in ['postgres','authenticator','supabase_auth_admin','supabase_storage_admin']))
    sql(cfg, 'CREATE SCHEMA IF NOT EXISTS _realtime; ALTER SCHEMA _realtime OWNER TO supabase_admin;')
    for service in ['mail','auth','storage','realtime']:
        verify_container(cfg,service);docker('start',name(cfg,service))
    wait_for(lambda:sql(cfg,"SELECT 1 FROM auth.users LIMIT 1; SELECT 1 FROM storage.buckets LIMIT 1;",check=False).returncode==0,'Auth and Storage schemas')
    wait_for(lambda:sql(cfg, "SELECT 1 FROM realtime.messages LIMIT 1;",check=False).returncode==0,'Realtime schemas')
    sql(cfg,'CREATE SCHEMA IF NOT EXISTS avaryn_local_meta; REVOKE ALL ON SCHEMA avaryn_local_meta FROM PUBLIC, anon, authenticated; CREATE TABLE IF NOT EXISTS avaryn_local_meta.migrations(version text PRIMARY KEY, sha256 text NOT NULL); GRANT USAGE ON SCHEMA avaryn_local_meta TO postgres; GRANT SELECT, INSERT ON avaryn_local_meta.migrations TO postgres; CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;')
    applied={r.split('|')[0]:r.split('|')[1] for r in sql(cfg,'SELECT version,sha256 FROM avaryn_local_meta.migrations ORDER BY version;').stdout.splitlines() if '|' in r}
    migrations=sorted((ROOT/'supabase/migrations').glob('*.sql'))
    for path in migrations:
        version=path.name.split('_')[0]
        if through and version>through:continue
        h=digest(path.read_bytes())
        if version in applied:
            if applied[version]!=h:raise ValueError('Applied migration changed: '+path.name)
            continue
        sql(cfg,migration_transaction(path.read_text(),version,h),role='postgres')
        applied[version]=h
        print('Applied migration '+version,flush=True)
    private_json(cfg['state']/'migrations.json',applied)
    for service in ['rest','edge','gateway']:
        verify_container(cfg,service)
        if service=='gateway' and inspect(name(cfg,service))['State']['Running']:docker('stop',name(cfg,service))
        docker('start',name(cfg,service))
    def ready():
        try:return request(cfg,'GET','/auth/v1/health').get('version') is not None
        except Exception:return False
    wait_for(ready,'Auth gateway')
    print('Backend ready: '+cfg['api_url']+'; migrations='+str(len(applied)))

def seed_fixtures(cfg):
    sys.path.insert(0,str(ROOT/'tool/route_b'))
    import fixtures
    return fixtures.seed(sys.modules[__name__],cfg)

def source_release_current(cfg):
    manifest=cfg['state']/'app/release-manifest.json'
    if not manifest.is_file():return False
    value=json.loads(manifest.read_text())
    if not value.get('release_files') or value.get('target_api_url')!=cfg['api_url']:return False
    if any(not (ROOT/p).is_file() or digest((ROOT/p).read_bytes())!=h for p,h in value['source_files'].items()):return False
    return all((cfg['state']/'app/build/web'/p).is_file() and digest((cfg['state']/'app/build/web'/p).read_bytes())==h for p,h in value['release_files'].items())

def build_release(cfg, reuse=False):
    private_json(cfg['state']/'target.json',{'api_url':cfg['api_url'],'anon_key':cfg['anon_key']})
    if reuse:
        if not source_release_current(cfg):raise ValueError('Existing release is absent, modified or stale.')
        return
    args=[sys.executable,ROOT/'tool/route_b/assemble_runtime.py','--target-config',cfg['state']/'target.json',
          '--output',cfg['state']/'app','--build','--isolated-cache']
    if (cfg['state']/'app').exists():args+=['--replace-derived']
    result=run(args,cwd=ROOT,check=False)
    (cfg['state']/'assembly-run.log').write_text(result.stdout+'\n'+result.stderr)
    if result.returncode:raise RuntimeError('Local assembly/build failed; inspect private assembly-run.log.')
    print('Current canonical runtimes assembled, pinned icons checked, offline release built.',flush=True)

def web_process(cfg):
    path=cfg['state']/'web-process.json'
    if not path.exists():return None
    value=json.loads(path.read_text())
    if value.get('target')!=cfg['target']:raise ValueError('Web process ownership mismatch.')
    current=run(['ps','-p',str(value['pid']),'-o','command='],check=False)
    if current.returncode:return None
    if current.stdout.strip()!=value['command']:raise ValueError('PID reused by another process; refusing to signal it.')
    return value

def start_web(cfg):
    if web_process(cfg):return
    argv=[sys.executable,str(ROOT/'tool/route_b/serve_local_preview.py'),'--directory',str(cfg['state']/'app/build/web'),
          '--port',str(cfg['ports']['web']),'--target',cfg['target']]
    log=(cfg['state']/'web.log').open('ab')
    proc=subprocess.Popen(argv,stdout=log,stderr=log,start_new_session=True);log.close()
    time.sleep(.2)
    current=run(['ps','-p',str(proc.pid),'-o','command='],check=False)
    if proc.poll() is not None or current.returncode:raise RuntimeError('Owned loopback preview failed to start.')
    command=current.stdout.strip()
    if str(ROOT/'tool/route_b/serve_local_preview.py') not in command or cfg['target'] not in command:raise ValueError('Unexpected web process identity.')
    private_json(cfg['state']/'web-process.json',{'target':cfg['target'],'pid':proc.pid,'command':command})
    def ready():
        with urllib.request.urlopen(cfg['preview_url'],timeout=5) as response:return response.status==200
    wait_for(ready,'release preview')
    print('Local browser endpoint: '+cfg['preview_url'],flush=True)

def api_response(cfg,path,token=None,body=None,method='POST'):
    headers={'apikey':cfg['anon_key'],'Content-Type':'application/json'}
    if token:headers['Authorization']='Bearer '+token
    req=urllib.request.Request(cfg['api_url']+path,data=json.dumps(body or {}).encode() if method!='GET' else None,headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=20) as result:return result.status,json.loads(result.read() or b'{}')
    except urllib.error.HTTPError as error:return error.code,json.loads(error.read() or b'{}')

def verify_cors(cfg):
    allowed_origins=preview_origins(cfg)
    denied_origins=['https://example.invalid',
      f'http://localhost:{cfg["ports"]["web"]+1}',
      f'http://localhost.example.invalid:{cfg["ports"]["web"]}','null']
    proofs=[]
    for origin,allowed in [(o,True) for o in allowed_origins]+[(o,False) for o in denied_origins]:
        for method,path in [('OPTIONS','/auth/v1/token'),('GET','/auth/v1/health')]:
            headers={'Origin':origin,'apikey':cfg['anon_key']}
            if method=='OPTIONS':headers.update({
              'Access-Control-Request-Method':'POST',
              'Access-Control-Request-Headers':'apikey,authorization,content-type,x-supabase-api-version'})
            req=urllib.request.Request(cfg['api_url']+path,method=method,headers=headers)
            with urllib.request.urlopen(req,timeout=10) as response:
                actual=response.headers.get('Access-Control-Allow-Origin')
                if allowed:
                    if actual!=origin:raise ValueError('Expected exact local CORS origin was denied.')
                    if method=='OPTIONS' and 'x-supabase-api-version' not in response.headers.get('Access-Control-Allow-Headers','').lower():
                        raise ValueError('Browser Auth API-version CORS header missing.')
                elif actual in ('*',origin):raise ValueError('Foreign CORS origin was permitted.')
                proofs.append({'case':'browser CORS '+method+' '+origin,'result':'PASS',
                               'expected_allowed':allowed,'allow_origin':actual})
    return proofs

def verify_product_schema(cfg):
    health=request(cfg,'GET','/auth/v1/health')
    if not isinstance(health.get('version'),str) or not health['version']:
        raise ValueError('Local Auth health response is unavailable.')
    # Read-only metadata: no fixtures, DDL, grants or domain rows are changed.
    query="""BEGIN READ ONLY;
SELECT json_build_object(
 'ledger',(SELECT coalesce(json_object_agg(version,sha256),'{}'::json) FROM avaryn_local_meta.migrations),
 'schema',json_build_object(
  'auth',to_regclass('auth.users') IS NOT NULL,
  'profiles',to_regclass('public.profiles') IS NOT NULL,
  'horses',to_regclass('public.canonical_horses') IS NOT NULL,
  'stables',to_regclass('public.organizations') IS NOT NULL,
  'storage',to_regclass('storage.objects') IS NOT NULL,
  'profile_rpc',to_regprocedure('public.get_current_account_profile()') IS NOT NULL,
  'horse_archive_rpc',to_regprocedure('public.list_c010_my_archived_horses()') IS NOT NULL,
  'stable_archive_rpc',to_regprocedure('public.list_c010_my_archived_organizations()') IS NOT NULL,
  'profile_anon_denied',NOT has_function_privilege('anon',to_regprocedure('public.get_current_account_profile()'),'EXECUTE'),
  'horse_archive_anon_denied',NOT has_function_privilege('anon',to_regprocedure('public.list_c010_my_archived_horses()'),'EXECUTE'),
  'horse_archive_authenticated',has_function_privilege('authenticated',to_regprocedure('public.list_c010_my_archived_horses()'),'EXECUTE')));
COMMIT;"""
    snapshot=json.loads(sql(cfg,query,role='postgres').stdout)
    paths=sorted((ROOT/'supabase/migrations').glob('*.sql'))
    expected={p.name.split('_')[0]:digest(p.read_bytes()) for p in paths}
    if not paths or len(expected)!=len(paths) or snapshot.get('ledger')!=expected:
        raise ValueError('Actual migration ledger does not match the complete current source.')
    fields={'auth','profiles','horses','stables','storage','profile_rpc','horse_archive_rpc','stable_archive_rpc',
            'profile_anon_denied','horse_archive_anon_denied','horse_archive_authenticated'}
    schema=snapshot.get('schema',{})
    if set(schema)!=fields or any(v is not True for v in schema.values()):
        raise ValueError('Required product schema or private account/archive ACL is unavailable.')
    status,_=api_response(cfg,'/rest/v1/rpc/get_current_account_profile')
    if status not in (401,403):raise ValueError('Anonymous account profile request was not refused.')
    return [{'case':label,'result':'PASS'} for label in [
        'Auth service health','complete current migration ledger hashes ('+str(len(expected))+')',
        'core product schema and account/archive ACL','anonymous profile read denied']]

def verify(cfg, backend_only=False, smoke_only=False, no_fixtures=False):
    product=cfg.get('product_client',False)
    if product and (not backend_only or not smoke_only):
        raise ValueError('Product verification is explicitly --backend-only --smoke-only.')
    if no_fixtures and not (product and backend_only and smoke_only):
        raise ValueError('--no-fixtures verification is only the explicit product backend smoke.')
    proofs=[]
    for service in SERVICES:
        obj=inspect(name(cfg,service));safe=verify_container(cfg,service,obj)
        if not safe['running']:raise ValueError('Required service is stopped: '+service)
        actual_ports={k:v for k,v in (obj['NetworkSettings'].get('Ports') or {}).items() if v}
        if actual_ports!=(obj['HostConfig'].get('PortBindings') or {}):raise ValueError('Actual published ports differ from checked pre-start bindings.')
        for entries in (obj['NetworkSettings'].get('Ports') or {}).values():
            if entries and any(e['HostIp']!='127.0.0.1' for e in entries):raise ValueError('Actual network binding is not loopback.')
        proofs.append({'case':'owned loopback service '+service,'result':'PASS'})
    fixturefile=cfg['state']/'fixtures.json'
    if product:proofs.extend(verify_product_schema(cfg))
    if not no_fixtures:
        if not fixturefile.is_file():raise ValueError('Real Auth fixtures missing; product smoke can explicitly use --no-fixtures.')
        f=json.loads(fixturefile.read_text())
        if not f.get('complete') or f['target']!=cfg['target']:raise ValueError('Incomplete/wrong fixtures.')
        for role,user in f['users'].items():
            status,data=api_response(cfg,'/auth/v1/user',user['access_token'],method='GET')
            if status!=200 or data.get('id')!=user['user_id'] or not data.get('email_confirmed_at'):
                raise ValueError('Real confirmed Auth session unavailable: '+role+'; start refreshes local sessions.')
            proofs.append({'case':'real confirmed Auth '+role,'result':'PASS'})
    # A health check must never submit a confirmed deletion request against
    # the persistent preview fixtures. Real deletion has separate throwaway tests.
    expected=[(None,401,'AUTHENTICATION_REQUIRED')]
    if not no_fixtures:expected += [('admin_a',400,'DELETION_CONFIRMATION_REQUIRED'),('outsider',400,'DELETION_CONFIRMATION_REQUIRED')]
    for role,status,code in expected:
        actual,data=api_response(cfg,'/functions/v1/delete-account',f['users'][role]['access_token'] if role else None)
        if actual!=status or data.get('code')!=code:raise ValueError('Account lifecycle check failed: '+str(role))
        proofs.append({'case':'Edge lifecycle guard '+str(role),'result':'PASS'})
    proofs.extend(verify_cors(cfg))
    if not backend_only:
        if not source_release_current(cfg):raise ValueError('Release source/hash verification failed.')
        if not web_process(cfg):raise ValueError('Owned browser process is absent.')
        with urllib.request.urlopen(cfg['preview_url']+'/stableDetails',timeout=10) as response:
            if response.status!=200:raise ValueError('Cold deep link does not load SPA.')
        proofs.append({'case':'current source release and cold SPA route','result':'PASS'})
    if not smoke_only:
        jobs=[('database',[sys.executable,ROOT/'tool/test_c010_repair_local.py','--target',cfg['target'],
              '--state-dir',cfg['state'].parent,'--output',cfg['state']/'database-tests']),
              ('authenticated-api',[sys.executable,ROOT/'supabase/tests/c010_task_visibility_api.py',
              '--target',cfg['target'],'--fixture-file',fixturefile,'--output',cfg['state']/'api-tests.json']),
              ('lifecycle-http',[sys.executable,ROOT/'tool/route_b/verify_lifecycle_http.py','--target',cfg['target'],
              '--state-dir',cfg['state'].parent,'--output',cfg['state']/'edge-http.json']),
              ('tooling',[sys.executable,'-B','-m','unittest','discover','-s','tool/route_b','-p','test_*.py'])]
        for label,command in jobs:
            outcome=run(command,cwd=ROOT,check=False)
            log=cfg['state']/(label+'-verify.log');log.write_text(outcome.stdout+'\n'+outcome.stderr);os.chmod(log,0o600)
            if outcome.returncode:raise RuntimeError('Verification suite failed: '+label+'; private log retained.')
            proofs.append({'case':label+' complete regression suite','result':'PASS'})
            print('PASS verification suite: '+label,flush=True)
    private_json(cfg['state']/'verify.json',{'target':cfg['target'],'result':'PASS','checks':proofs,
      'mode':'product-backend-smoke' if product else 'legacy-route-b',
      'authenticated_fixture_sessions':'NOT TESTED' if no_fixtures else 'PASS',
      'frontend':'NOT TESTED' if backend_only else 'PASS'})
    print('Verified '+str(len(proofs))+(' product backend smoke checks; frontend not tested.' if product else ' local ownership, Auth, lifecycle, CORS and release checks.'))

def status(cfg):
    result={'target':cfg['target'],'project_id':PROJECT,'api_url':cfg['api_url'],'preview_url':cfg['preview_url'],
            'services':[verify_container(cfg,s) for s in SERVICES if inspect(name(cfg,s))],
            'migration_count':len(json.loads((cfg['state']/'migrations.json').read_text())) if (cfg['state']/'migrations.json').exists() else 0}
    if cfg.get('product_client'):result.update(client_mode='product',product_provenance=cfg['product_provenance'],frontend_managed=False)
    print(json.dumps(result,indent=2));return result

def stop(cfg, backend_only=False):
    backend_only=backend_only or cfg.get('product_client',False)
    process=None if backend_only else web_process(cfg)
    if process:
        os.kill(process['pid'],signal.SIGTERM)
        wait_for(lambda:web_process(cfg) is None,'owned preview termination')
    for service in reversed(SERVICES):
        if inspect(name(cfg,service)):
            verify_container(cfg,service);docker('stop',name(cfg,service))
    closed={}
    for label,port in cfg['ports'].items():
        if backend_only and label=='web':continue
        with socket.socket() as probe:
            probe.settimeout(.2);closed[label]=probe.connect_ex(('127.0.0.1',port))!=0
    private_json(cfg['state']/'stop.json',{'target':cfg['target'],'ports_closed':closed,'frontend_managed':not backend_only,
      'all_containers_stopped':all(not verify_container(cfg,s)['running'] for s in SERVICES if inspect(name(cfg,s)))})
    if not all(closed.values()):raise RuntimeError('A configured local port remains open; no unrelated process was stopped.')
    print('Stopped only owned '+('backend; separate product server untouched' if backend_only else 'local target')+'; checked ports closed; data and evidence retained.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['prepare','start','verify','status','stop'])
    parser.add_argument('--target',required=True)
    parser.add_argument('--state-dir')
    parser.add_argument('--port-base',type=int)
    parser.add_argument('--web-port',type=int)
    parser.add_argument('--migrations-through')
    parser.add_argument('--backend-only',action='store_true')
    parser.add_argument('--product-client',action='store_true',help='Validate official product provenance instead of a FlutterFlow binding; requires --backend-only.')
    parser.add_argument('--no-fixtures',action='store_true')
    parser.add_argument('--smoke-only',action='store_true',help='Skip the full SQL/race/API/tooling suites in verify.')
    parser.add_argument('--reuse-build',action='store_true',help='Reuse only a release whose source and output hashes are current.')
    args=parser.parse_args()
    lockfile=None
    try:
        cfg=load_context(args,create=args.command in ['prepare','start'])
        lockfile=(cfg['state']/'.operation.lock').open('a')
        os.chmod(cfg['state']/'.operation.lock',0o600)
        if args.command!='status':
            try:fcntl.flock(lockfile.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:raise ValueError('Another operation already owns this local target; refuse concurrent mutation.')
        if args.command=='prepare':prepare(cfg)
        elif args.command=='start':
            start_backend(cfg,args.migrations_through)
            if not args.no_fixtures:seed_fixtures(cfg)
            if not args.backend_only:
                build_release(cfg,args.reuse_build)
                start_web(cfg)
        elif args.command=='stop':stop(cfg,backend_only=args.product_client)
        elif args.command=='verify':verify(cfg,args.backend_only,args.smoke_only,args.no_fixtures)
        else:status(cfg)
    except (ValueError,RuntimeError,OSError,AssertionError) as e:
        parser.exit(2,str(e)+'\n')
    finally:
        if lockfile is not None:lockfile.close()

if __name__=='__main__':main()
