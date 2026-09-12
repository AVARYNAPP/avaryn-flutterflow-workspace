#!/usr/bin/env python3
"""Export only the exact ready M-owned media in a verified operational49 snapshot.

Normal synthetic M login + canonical_download + signed GET only. No upload,
archive, service key, arbitrary URL, remote SQL or personal-account session.
Any unowned/unmapped object blocks completeness rather than bypassing access.
"""
import argparse, datetime, hashlib, json, os, re, stat, sys, urllib.request, urllib.error
from pathlib import Path
from urllib.parse import urlsplit, parse_qs
from check_pilot_connection import ROOT, BASE, EVIDENCE, REF, private_write
from backup_pilot_database import local, parsed, LOCAL_CLUSTER
from pilot_timezone_increment import check_local, readonly

PRIVATE = BASE.parent
UPSTREAM = 'https://' + REF + '.supabase.co'


def synthetic_fixture(value):
    return (value.get('synthetic') is True and value.get('personalAccountDeletionForbidden') is True
            and re.fullmatch(r'[^@\s+]+\+[^@\s+]+@[^@\s]+\.[^@\s]+',value.get('email','').lower()) is not None)


def private_json(path):
    if not path.is_file() or any(p.is_symlink() for p in [path,*path.parents]) or stat.S_IMODE(path.stat().st_mode)!=0o600:
        raise ValueError('PRIVATE_FILE_INVALID')
    return json.loads(path.read_text())


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None


def download_url(value, object_path):
    if not isinstance(value,str): raise ValueError('CAPABILITY_URL_INVALID')
    url=urlsplit(value)
    query=parse_qs(url.query,keep_blank_values=True)
    if (url.scheme!='https' or url.netloc!=REF+'.supabase.co' or url.username or url.password or url.fragment
            or url.path!='/storage/v1/object/sign/horse-media/'+object_path
            or set(query)!={'token'} or len(query['token'])!=1
            or not re.fullmatch(r'[A-Za-z0-9_.-]{1,8192}',query['token'][0])):
        raise ValueError('CAPABILITY_URL_INVALID')
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--backup-run',type=Path,required=True)
    p.add_argument('--root-reviewed',action='store_true',required=True)
    args=p.parse_args();os.umask(0o077)
    directory=args.backup_run.absolute()
    if not directory.is_relative_to(BASE) or any(p.is_symlink() for p in [directory,*directory.parents]) or stat.S_IMODE(directory.stat().st_mode)!=0o700:
        raise ValueError('BACKUP_RUN_SCOPE_INVALID')
    receipt=private_json(directory/'receipt.json');marker=private_json(directory/'restore-target.json')
    archive=directory/'pilot49-full.dump'
    if (receipt.get('status')!='PASS_DATABASE_BACKUP_AND_REAL_RESTORE' or receipt.get('projectRef')!=REF
            or marker.get('project_ref')!=REF or marker.get('local_cluster')!=LOCAL_CLUSTER
            or hashlib.sha256(archive.read_bytes()).hexdigest()!=receipt.get('backupSha256')
            or marker.get('backup_sha256')!=receipt.get('backupSha256')):
        raise ValueError('VERIFIED_DATABASE_BACKUP_REQUIRED')
    database=marker.get('database','')
    if not re.fullmatch(r'avaryn_pilot49_backup_\d{8}t\d{6}z',database): raise ValueError('SCRATCH_SCOPE_INVALID')
    objects=private_json(directory/'storage-inventory.json')
    m=private_json(PRIVATE/'managed-synthetic-20260912.json');key=private_json(BASE/'runtime-key.json')
    email=m.get('email','').lower()
    if (not synthetic_fixture(m)
            or key.get('project_ref')!=REF or not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]{16,1024}',key.get('key',''))):
        raise ValueError('EXACT_NORMAL_SYNTHETIC_M_REQUIRED')
    out=directory/'media-bytes';out.mkdir(mode=0o700)
    check_local()
    quote=lambda s:"'"+s.replace("'","''")+"'"
    # Only the verified local restore is queried. This joins all snapshot objects
    # to M's existing active primary horse; an unmatched object prevents export.
    rows=parsed(local(readonly("""select coalesce(jsonb_agg(jsonb_build_object(
      'bucket_id',s.bucket_id,'name',s.name,'object_id',s.id,'asset_id',a.id,'variant',v.variant,
      'mime',v.mime_type,'bytes',v.byte_size,'sha256',encode(v.sha256,'hex')) order by s.bucket_id,s.name),'[]')
      from storage.objects s join public.media_asset_variants v on v.bucket_id=s.bucket_id and v.object_path=s.name
      join public.media_assets a on a.id=v.media_asset_id join public.canonical_horses h on h.id=a.horse_id
      join public.profiles p on p.id=h.primary_authority_profile_id join auth.users u on u.id=p.auth_user_id
      where lower(u.email)="""+quote(email)+""" and p.status='active' and h.status='active'
      and a.status='ready' and v.status='ready';"""),database))
    if (len(rows)!=len(objects) or not rows or len(rows)>20
            or {(r['bucket_id'],r['name']) for r in rows}!={(r['bucket_id'],r['name']) for r in objects}):
        raise ValueError('SNAPSHOT_BYTES_NOT_ALL_AUTHORIZED_READY_M_MEDIA')
    for row in rows:
        if (row['bucket_id']!='horse-media' or row['variant'] not in('original','thumbnail')
                or not re.fullmatch(r'(canonical|[0-9a-f-]{36})/[0-9a-f-]{36}/[0-9a-f-]{36}/(original|thumbnail)',row['name'])
                or row['mime'] not in('image/png','image/jpeg','image/webp')
                or not isinstance(row['bytes'],int) or not 0<row['bytes']<=10*1024*1024
                or not re.fullmatch(r'[0-9a-f]{64}',row['sha256'] or '')):
            raise ValueError('SNAPSHOT_VARIANT_METADATA_INVALID')
    events=[]
    def request(label,path,body=None,bearer=None,method='POST',limit=1024*1024,raw=False):
        if not raw and path not in('/auth/v1/token?grant_type=password','/auth/v1/user','/auth/v1/logout?scope=local','/functions/v1/media-assets'):
            raise ValueError('API_PATH_REFUSED')
        headers={} if raw else {'apikey':key['key'],'Content-Type':'application/json','X-Supabase-Api-Version':'2024-01-01'}
        if bearer:headers['Authorization']='Bearer '+bearer
        url=path if raw else UPSTREAM+path
        req=urllib.request.Request(url,headers=headers,method=method,data=None if method=='GET' else json.dumps(body or {}).encode())
        try:r=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect()).open(req,timeout=25)
        except urllib.error.HTTPError as e:r=e
        with r:
            data=r.read(limit+1)
            events.append({'case':label,'status':r.code})
            if len(data)>limit or r.code not in(200,204):raise ValueError('AUTHORIZED_READ_FAILED')
            return data if raw else json.loads(data) if data else {}
    token=None;files=[]
    try:
        session=request('M_login','/auth/v1/token?grant_type=password',{'email':email,'password':m['password']})
        if session.get('user',{}).get('email','').lower()!=email:raise ValueError('M_AUTH_IDENTITY_MISMATCH')
        token=session['access_token']
        actor=request('M_user','/auth/v1/user',bearer=token,method='GET')
        if actor.get('id')!=session['user']['id'] or not actor.get('email_confirmed_at'):raise ValueError('M_USER_NOT_VERIFIED')
        for index,row in enumerate(rows):
            value=request('authorize_'+row['variant'],'/functions/v1/media-assets',{'action':'canonical_download','media_asset_id':row['asset_id'],'variant':row['variant']},token)
            if value.get('mime_type')!=row['mime']:raise ValueError('MIME_METADATA_CHANGED')
            url=download_url(value.get('signed_download_url'),row['name'])
            data=request('bytes_'+row['variant'],url,method='GET',limit=row['bytes'],raw=True)
            if len(data)!=row['bytes'] or hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('SIGNED_BYTES_DO_NOT_MATCH_SNAPSHOT')
            filename=f'{index+1:03d}-{row["variant"]}.bin'
            with os.fdopen(os.open(out/filename,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'wb') as handle:handle.write(data)
            files.append({**row,'file':filename})
        private_write(out/'manifest.json',json.dumps({'databaseBackupSha256':receipt['backupSha256'],'objects':files},indent=2)+'\n')
        status='PASS_ALL_SNAPSHOT_STORAGE_BYTES_VERIFIED'
    finally:
        if token:
            try:request('M_logout_only_new_backup_session','/auth/v1/logout?scope=local',bearer=token)
            except Exception:events.append({'case':'session_cleanup_unconfirmed','status':None})
    result={'status':status,'projectRef':REF,'databaseBackupSha256':receipt['backupSha256'],
            'snapshotStorageObjects':len(objects),'verifiedObjects':len(files),'verifiedBytes':sum(r['bytes'] for r in files),
            'normalSyntheticOwnerAuthorizationOnly':True,'remoteSqlCalls':0,'uploads':0,'remoteApplicationWrites':0,
            'privateFileModes':'0600','events':events,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'limits':['Matches only the database snapshot; later uploads are outside this backup.',
                      'Bytes were downloaded and checksummed, not uploaded to a second Storage service.',
                      'No system/service credential used; unrelated or archived objects would block complete coverage.']}
    private_write(out/'receipt.json',json.dumps(result,indent=2)+'\n')
    (EVIDENCE/(directory.name+'-storage.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':
    try:main()
    except Exception as e:
        print(json.dumps({'status':'BLOCKED','code':str(e) if isinstance(e,ValueError) and str(e).isupper() else type(e).__name__,'uploads':0,'remoteSqlWrites':0}))
        raise SystemExit(1)
