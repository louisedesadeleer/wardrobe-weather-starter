#!/usr/bin/env python3
"""Optional explicit SMTP delivery of the generated MIME email."""
import argparse
from email import policy
from email.parser import BytesParser
from email.utils import formatdate, make_msgid
import hashlib
import json
import os
from pathlib import Path
import smtplib
import ssl


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('email',type=Path);p.add_argument('--to',required=True)
    p.add_argument('--send-id',required=True,help='Unique edition, e.g. 2026-07-06; reuse to prevent duplicate delivery')
    p.add_argument('--send',action='store_true');p.add_argument('--receipts',type=Path,default=Path('private/receipts'))
    a=p.parse_args()
    if any(c in a.to for c in '\r\n,;') or a.to.count('@')!=1:p.error('Use one recipient email address')
    m=BytesParser(policy=policy.default).parsebytes(a.email.read_bytes())
    if not a.send:
        print(f'Dry run: {m["Subject"]} → {a.to}. Add --send to deliver.');return
    host=os.environ['SMTP_HOST'];user=os.environ['SMTP_USER'];password=os.environ['SMTP_PASSWORD']
    sender=os.environ.get('SMTP_FROM',user)
    for header in ['To','Cc','Bcc','From','Date','Message-ID']:
        if header in m:del m[header]
    m['To']=a.to;m['From']=sender;m['Date']=formatdate(localtime=True);m['Message-ID']=make_msgid()
    a.receipts.mkdir(parents=True,exist_ok=True)
    key=hashlib.sha256((a.to+'\0'+a.send_id).encode()).hexdigest()
    receipt=a.receipts/(key+'.json')
    # Exclusive marker prevents concurrent or accidental repeats. Uncertain failures require manual review.
    try:
        with receipt.open('x') as f:json.dump({'status':'attempting','edition':a.send_id},f)
    except FileExistsError:raise SystemExit('Edition already attempted. Check your sent mail and the receipt before retrying.')
    try:
        with smtplib.SMTP_SSL(host,int(os.environ.get('SMTP_PORT','465')),context=ssl.create_default_context(),timeout=30) as smtp:
            smtp.login(user,password);smtp.send_message(m,from_addr=sender,to_addrs=[a.to])
        receipt.write_text(json.dumps({'status':'accepted-by-smtp','edition':a.send_id,'messageId':m['Message-ID']}))
        print('Email accepted by SMTP server.')
    except Exception:
        receipt.write_text(json.dumps({'status':'uncertain-check-sent-mail','edition':a.send_id}))
        raise

if __name__=='__main__':main()
