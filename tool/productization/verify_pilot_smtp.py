#!/usr/bin/env python3
"""TLS/auth-only probe for the approved pilot SMTP key. Sends no email."""
import json, ssl, smtplib, stat
from pathlib import Path
from datetime import datetime, timezone
root=Path(__file__).resolve().parents[2]
private=root/'.avaryn-local/productization-20260911/private/pilot-backend/resend-smtp.json'
if private.is_symlink() or stat.S_IMODE(private.stat().st_mode)!=0o600: raise SystemExit('Private configuration permissions invalid')
c=json.loads(private.read_text())
if (c['projectRef'],c['domain'],c['permission'],c['keyId'])!=('rvymglpkttlfwhqpmupp','auth.avaryn.eu','sending_access','c0e9a139-a10c-4f7c-affd-82bf5e71cbe1'): raise SystemExit('Target mismatch')
r={'checkedAt':datetime.now(timezone.utc).isoformat(),'projectRef':c['projectRef'],'domain':c['domain'],'host':'smtp.resend.com','port':465,'sentEmails':0}
try:
 with smtplib.SMTP_SSL('smtp.resend.com',465,timeout=20,context=ssl.create_default_context()) as smtp:
  r['tls']=smtp.sock.version()
  code,_=smtp.login('resend',c['apiKey']);r['authenticationCode']=code;r['status']='PASS' if code==235 else 'FAIL'
except Exception as e:
 r['status']='FAIL';r['errorType']=type(e).__name__
r['limits']=['SMTP authentication only; actual Auth email delivery and recipient confirmation require separate verification.']
(root/'.avaryn-local/productization-20260911/evidence/pilot-smtp-auth.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r))
raise SystemExit(0 if r['status']=='PASS' else 1)
