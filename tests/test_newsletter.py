import copy
import json
from pathlib import Path
import tempfile
import unittest
from collections import Counter
from email import policy
from email.parser import BytesParser
import newsletter as n

class NewsletterTests(unittest.TestCase):
    def setUp(self):
        self.backup=json.loads((n.ROOT/'examples/wardrobe.json').read_text())
        self.lib=self.backup['library'];self.config=json.loads((n.ROOT/'config.example.json').read_text())
        self.days=n.daytime_days(n.demo_forecast())
    def test_daylight_excludes_night_and_after_sunset(self):
        f=n.demo_forecast();f['daily']['sunset'][0]='2026-07-06T17:30';f['hourly']['temperature_2m'][18]=-50
        day=n.daytime_days(f)[0]
        self.assertEqual(day['low'],26);self.assertEqual(day['high'],28)
        self.assertEqual(day['band'],'hot')
    def test_missing_temperature_fails(self):
        f=n.demo_forecast();f['hourly']['temperature_2m'][10]=None
        with self.assertRaises(ValueError):n.daytime_days(f)
    def test_week_has_unique_tops_and_bottoms_at_most_twice(self):
        picks=n.choose(self.lib,self.days,self.config)
        self.assertTrue(all(picks));self.assertEqual(len({p['id'] for p in picks}),7)
        counts=Counter(i for p in picks for i in p['itemIds'])
        for item in self.lib['items']:
            self.assertLessEqual(counts[item['id']],1 if item['category']=='Top' else 2)
    def test_exhaustion_never_relaxes_limits(self):
        self.lib['outfits']=self.lib['outfits'][-8:-6]
        picks=n.choose(self.lib,self.days,self.config)
        self.assertEqual(sum(p is not None for p in picks),2)
    def test_stale_tags_and_unknown_categories_excluded(self):
        outfit=self.lib['outfits'][-8];r=self.lib['ratings'][outfit['id']];items={i['id']:i for i in self.lib['items']}
        r['photoHash']='old'
        self.assertFalse(n.eligible(outfit,r,items,self.days[0]))
        r['photoHash']=outfit['photoHash'];items[outfit['itemIds'][0]]['category']='Mystery'
        self.assertFalse(n.eligible(outfit,r,items,self.days[0]))
    def test_worn_top_consumes_weekly_allowance(self):
        first=self.lib['outfits'][-8]
        self.lib['logs']=[dict(date='2026-07-06',status='worn',outfitId=first['id'],itemIds=first['itemIds'])]
        picks=n.choose(self.lib,self.days[1:],self.config)
        self.assertTrue(all(first['itemIds'][0] not in p['itemIds'] for p in picks if p))
    def test_rain_excludes_dry_only(self):
        day=dict(self.days[0],rain=70)
        self.assertIsNone(n.choose(self.lib,[day],self.config)[0])
    def test_preview_and_email_have_embedded_images_no_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);n.generate(self.backup,n.demo_forecast(),self.config,p,demo=True)
            html=(p/'newsletter.html').read_text()
            self.assertNotIn('Example outfit',html);self.assertIn('warm-week demo',html)
            msg=BytesParser(policy=policy.default).parsebytes((p/'newsletter.eml').read_bytes())
            self.assertEqual(len([x for x in msg.walk() if x.get_content_type()=='image/jpeg']),7)
    def test_demo_path_traversal_rejected(self):
        with self.assertRaises(ValueError):n.load_image('demo:../../secret',{})

if __name__=='__main__':unittest.main()
