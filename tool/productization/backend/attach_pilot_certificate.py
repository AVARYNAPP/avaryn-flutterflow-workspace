#!/usr/bin/env python3
"""Attach an independently obtained, reviewed Supabase root CA locally.

No network, password read, system trust change or TLS downgrade. The explicit
SHA256 must come from the root's verified dashboard download receipt, not from
an unverified TLS peer. Existing configuration and credential generation remain.
"""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import uuid

from check_pilot_connection import BASE, REF, ORG, configuration, private_write


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--certificate',type=Path,required=True)
    parser.add_argument('--sha256',required=True)
    args=parser.parse_args()
    if not re.fullmatch('[0-9a-f]{64}',args.sha256):raise ValueError('CA_SHA256_REQUIRED')
    source=args.certificate.resolve()
    if args.certificate.is_symlink() or not source.is_file():raise ValueError('CA_FILE_INVALID')
    data=source.read_bytes()
    if hashlib.sha256(data).hexdigest()!=args.sha256:raise ValueError('CA_SHA256_MISMATCH')
    if data.count(b'-----BEGIN CERTIFICATE-----')!=1 or b'PRIVATE KEY' in data or len(data)>32768:
        raise ValueError('CA_CERTIFICATE_INVALID')
    c,_=configuration()
    openssl='/opt/homebrew/opt/openssl@3/bin/openssl'
    check=subprocess.run([openssl,'x509','-noout','-text','-checkend','0'],input=data,capture_output=True)
    if check.returncode or b'CA:TRUE' not in check.stdout or b'Supabase Root 2021 CA' not in check.stdout:
        raise ValueError('CA_SUBJECT_OR_LIFETIME_INVALID')
    os.umask(0o077)
    generation=BASE/('trusted-ca-'+uuid.uuid4().hex);generation.mkdir(mode=0o700)
    cert=generation/'supabase-root-ca.pem';private_write(cert,data.decode('ascii'))
    private_write(generation/'previous-connection.json',json.dumps(c,indent=2)+'\n')
    service=configparser.ConfigParser();service.read(c['pgservicefile'])
    service[c['pgservice']]['sslrootcert']=str(cert)
    service_path=generation/'pg_service.conf'
    fd=os.open(service_path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:service.write(f,space_around_delimiters=False)
    c.update(sslrootcert=str(cert),pgservicefile=str(service_path),ca_sha256=args.sha256,
             ca_source='Verified AVARYN C010 Pilot Supabase dashboard certificate download',connection_tested=False)
    pending=generation/'connection.json';private_write(pending,json.dumps(c,indent=2)+'\n')
    pointer=BASE/('.connection-'+uuid.uuid4().hex+'.json');private_write(pointer,pending.read_text())
    os.replace(pointer,BASE/'connection.json')
    print(json.dumps({'status':'PRIVATE_CA_ATTACHED','project_ref':REF,'organization_id':ORG,
                      'ca_sha256':args.sha256,'tls_mode':'verify-full','network_executed':False,
                      'previous_configuration_preserved':True,'credentials_unchanged':True}))


if __name__=='__main__':main()
