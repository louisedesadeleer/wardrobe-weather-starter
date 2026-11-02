import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock
import send_email

class SenderTests(unittest.TestCase):
    def test_dry_run_never_connects(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'mail.eml';f.write_text('Subject: Test\n\nHello\n')
            with patch('sys.argv',['send_email.py',str(f),'--to','me@example.com','--send-id','test']),patch('smtplib.SMTP_SSL') as smtp:
                send_email.main();smtp.assert_not_called()
    def test_explicit_recipient_and_duplicate_protection(self):
        with tempfile.TemporaryDirectory() as tmp:
            f=Path(tmp)/'mail.eml';f.write_text('Subject: Test\nTo: old@example.com\nCc: old-cc@example.com\nBcc: old-bcc@example.com\n\nHello\n')
            args=['send_email.py',str(f),'--to','me@example.com','--send-id','test','--send','--receipts',tmp+'/receipts']
            with patch('sys.argv',args),patch.dict(os.environ,{'SMTP_HOST':'smtp.example.com','SMTP_USER':'sender@example.com','SMTP_PASSWORD':'fake-test-only'}),patch('smtplib.SMTP_SSL') as smtp:
                client=smtp.return_value.__enter__.return_value
                send_email.main()
                call=client.send_message.call_args
                self.assertEqual(call.kwargs['to_addrs'],['me@example.com'])
                self.assertIsNone(call.args[0]['Cc']);self.assertIsNone(call.args[0]['Bcc'])
                with self.assertRaises(SystemExit):send_email.main()
                self.assertEqual(client.send_message.call_count,1)

if __name__=='__main__':unittest.main()
