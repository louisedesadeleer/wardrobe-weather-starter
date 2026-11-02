#!/usr/bin/env python3
"""Photo-first outfit emails. Local backup in; HTML, MIME email and audit JSON out."""
import argparse
import base64
from collections import Counter
from datetime import date, datetime, time, timedelta
from email.message import EmailMessage
from email.utils import make_msgid
from html import escape
from io import BytesIO
import json
import math
from pathlib import Path
from urllib.parse import urlencode, urlparse
from urllib.request import urlopen
from zoneinfo import ZoneInfo

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent

def band(c):
    return 'cold' if c < 10 else 'cool' if c < 18 else 'mild' if c < 24 else 'hot'

def live_forecast(config):
    query = {k: config[k] for k in ('latitude', 'longitude', 'timezone')}
    query.update(hourly='temperature_2m,precipitation_probability,wind_speed_10m', daily='sunset', forecast_days=7)
    with urlopen('https://api.open-meteo.com/v1/forecast?' + urlencode(query), timeout=30) as response:
        return json.load(response)

def demo_forecast():
    """Explicitly fictional warm week; deliberately cold nights test the daylight filter."""
    hourly = {k: [] for k in ('time', 'temperature_2m', 'precipitation_probability', 'wind_speed_10m')}
    daily = {'time': [], 'sunset': []}
    for i in range(7):
        day = date(2026, 7, 6) + timedelta(days=i)
        daily['time'].append(str(day)); daily['sunset'].append(f'{day}T20:58')
        for h in range(24):
            hourly['time'].append(f'{day}T{h:02}:00')
            hourly['temperature_2m'].append(26 + i % 4 + (2 if h >= 13 else 0) if 9 <= h <= 20 else 16)
            hourly['precipitation_probability'].append(5)
            hourly['wind_speed_10m'].append(12)
    return {'hourly': hourly, 'daily': daily, 'timezone': 'Europe/Lisbon', 'demo': True}

def daytime_days(forecast, start_hour=9):
    hourly = forecast['hourly']
    lengths = {len(hourly[k]) for k in ('time','temperature_2m','precipitation_probability','wind_speed_10m')}
    if len(lengths) != 1: raise ValueError('Incomplete hourly forecast')
    if len(forecast['daily']['time']) != len(forecast['daily']['sunset']): raise ValueError('Missing sunset')
    result = []
    for day, sunset in zip(forecast['daily']['time'], forecast['daily']['sunset']):
        end = datetime.fromisoformat(sunset)
        start = datetime.combine(date.fromisoformat(day), time(start_hour))
        indices = [i for i,t in enumerate(hourly['time']) if start <= datetime.fromisoformat(t) < end]
        if not indices: raise ValueError(f'No daytime temperatures for {day}')
        values = [[hourly[k][i] for i in indices] for k in ('temperature_2m','precipitation_probability','wind_speed_10m')]
        if any(v is None or not math.isfinite(v) for series in values for v in series): raise ValueError(f'Missing daytime values for {day}')
        temps, rain, wind = values
        result.append(dict(date=day, low=min(temps), high=max(temps), mean=sum(temps)/len(temps), rain=max(rain), wind=max(wind), sunset=end.strftime('%H:%M'), band=band(sum(temps)/len(temps))))
    return result

def category(value):
    v = value.strip().lower()
    if v in {'top','tops','t-shirt','tshirt','t shirt','shirt','blouse','knitwear','sweater','jumper','tank','tank top'}: return 'top'
    if v in {'bottom','bottoms','pants','trousers','jeans','shorts','skirt'}: return 'bottom'
    if v in {'shoe','shoes','footwear','accessory','accessories','bag','bags','outerwear','jacket','coat','dress','dresses','jumpsuit','one piece','jewelry','jewellery','swim'}: return 'other'
    return 'unknown'

def eligible(outfit, rating, items, day):
    if not rating or outfit.get('missingItems',0) or not outfit.get('itemIds'): return False
    if rating.get('photoHash') != outfit.get('photoHash'): return False
    if not rating.get('neutral') and day['band'] not in rating.get('temperatures',[]): return False
    if any(i not in items or category(items[i]['category']) == 'unknown' for i in outfit['itemIds']): return False
    if day['rain'] >= 40 and rating.get('rain') == 'dry-only': return False
    if day['wind'] >= 30 and rating.get('wind') == 'avoid-wind': return False
    return True

def choose(library, days, config):
    """Beam search across all days avoids a greedy Monday choice blocking Friday."""
    items = {i['id']: i for i in library['items']}
    outfits = {o['id']: o for o in library['outfits']}
    limits = {'top':config.get('top_limit',1), 'bottom':config.get('bottom_limit',2)}
    def week(s):
        d=date.fromisoformat(s); return str(d-timedelta(days=d.weekday()))
    counts=Counter(); previous=set()
    first=days[0]['date']
    seen=set()
    # Count distinct worn item-days earlier in the same calendar week.
    for log in library.get('logs',[]):
        if log['status'] != 'worn' or log['date'] >= first: continue
        ids = log.get('itemIds') or outfits.get(log['outfitId'],{}).get('itemIds',[])
        for item in ids:
            key=(log['date'], item)
            if key not in seen: counts[(week(log['date']),item)]+=1; seen.add(key)
        previous.add(log['outfitId'])
    states=[(0, [], counts, set())]
    for day in days:
        candidates=[o for o in library['outfits'] if eligible(o,library['ratings'].get(o['id']),items,day)]
        expanded=[]
        for score,picks,used,chosen in states:
            expanded.append((score, picks+[None], used, chosen))
            for outfit in candidates:
                if outfit['id'] in chosen: continue
                ids=set(outfit['itemIds']); wk=week(day['date'])
                if any(used[(wk,i)] >= limits.get(category(items[i]['category']),999) for i in ids): continue
                next_used=used.copy()
                for i in ids: next_used[(wk,i)]+=1
                planned=any(l['status']=='planned' and l['date']==day['date'] and l['outfitId']==outfit['id'] for l in library.get('logs',[]))
                expanded.append((score+1000+int(planned)*10-int(outfit['id'] in previous),picks+[outfit],next_used,chosen|{outfit['id']}))
        states=sorted(expanded,key=lambda x:x[0],reverse=True)[:300]
    return states[0][1]

def load_image(reference, photos):
    if reference.startswith('demo:'):
        name=reference[5:]
        if not name.startswith('demo-') or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name): raise ValueError('Invalid demo image')
        data=(ROOT/'examples/assets'/f'{name}.png').read_bytes()
    elif reference.startswith('photos/'):
        # Lookup only; never write arbitrary backup paths to disk.
        data=base64.b64decode(photos[reference],validate=True)
    else:
        u=urlparse(reference)
        if u.scheme != 'https' or u.username or u.password or not (u.hostname=='res.myindyx.com' or (u.hostname=='res.cloudinary.com' and u.path.startswith('/myindyx/'))): raise ValueError('Unsupported photo source; use a full backup with uploaded photos')
        with urlopen(reference,timeout=20) as r:
            final=urlparse(r.url)
            if final.hostname != u.hostname: raise ValueError('Unexpected image redirect')
            data=r.read(20_000_001)
    if len(data)>20_000_000: raise ValueError('Photo exceeds 20 MB')
    image=Image.open(BytesIO(data)); image.load(); return image.convert('RGBA')

def render_board(outfit, photos):
    canvas=Image.new('RGBA',(720,1066),'#eee8dd')
    if outfit.get('layers'):
        for layer in outfit['layers']:
            w=max(1,min(1080,round(720*layer['width']))); h=max(1,min(1599,round(1066*layer['height'])))
            img=ImageOps.contain(load_image(layer['image'],photos),(w,h))
            if layer.get('flipped'): img=ImageOps.mirror(img)
            img=img.rotate(-layer.get('rotation',0),resample=Image.Resampling.BICUBIC,expand=True)
            canvas.alpha_composite(img,(round(720*layer['centerX']-img.width/2),round(1066*layer['centerY']-img.height/2)))
    elif outfit.get('image'):
        img=ImageOps.contain(load_image(outfit['image'],photos),canvas.size)
        canvas.alpha_composite(img,((720-img.width)//2,(900-img.height)//2))
    else: raise ValueError('Outfit has no image or board layers')
    result=BytesIO();canvas.convert('RGB').save(result,format='JPEG',quality=90);return result.getvalue()

def generate(backup, forecast, config, out, count=7, demo=False, recipient=None):
    library=backup.get('library',backup)
    if 'items' not in library: raise ValueError('Use Prepare full backup, not the older compact newsletter export')
    days=daytime_days(forecast,config.get('start_hour',9))[:count]
    if not days: raise ValueError('No forecast days')
    picks=choose(library,days,config);out.mkdir(parents=True,exist_ok=True)
    cards=[];plain=[];audit=[];images=[]
    for i,(day,outfit) in enumerate(zip(days,picks)):
        label=date.fromisoformat(day['date']).strftime('%A · %d %B').replace('· 0','· ')
        summary=f"{'🌧️' if day['rain']>=40 else '☀️'} {day['low']:.0f}–{day['high']:.0f}°C · {config.get('start_hour',9):02}:00–{day['sunset']}"
        notes=[];img='';oid=None
        if outfit:
            oid=outfit['id'];rating=library['ratings'][oid]
            if day['rain']>=40: notes.append('Check rain protection; temperatures alone do not guarantee a rain-ready outfit.')
            if day['wind']>=30 and rating.get('wind')!='wind-ok': notes.append('Wind suitability not confirmed.')
            data=render_board(outfit,backup.get('photos',{}));filename=f'outfit-{i+1}.jpg';(out/filename).write_bytes(data);images.append((filename,data))
            img=f'<img src="{filename}" width="600" alt="Suggested outfit" style="width:100%;height:auto;display:block;border-radius:12px">'
        else: notes.append('No matching outfit within your repeat limits. Tag more outfits or add a look for this weather.')
        note=' '.join(notes)
        cards.append(f'<section style="margin:0 0 28px"><h2 style="font:22px Georgia,serif;margin:0 0 8px">{escape(label)}</h2><p style="font:14px Arial,sans-serif;color:#625b51;margin:0 0 12px">{escape(summary)}</p>{img}<p style="font:13px Arial,sans-serif">{escape(note)}</p></section>')
        plain.append(label+'\n'+summary+'\n'+note)
        audit.append(dict(**day,outfitId=oid,itemIds=outfit['itemIds'] if outfit else [],notes=notes))
    title='Your week, dressed.' if count>1 else 'Today, dressed.'
    if demo:title+=' (warm-week demo)'
    source='Fictional weather · example wardrobe' if demo else 'Forecast: Open-Meteo · '+config['timezone']
    html='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+escape(title)+'</title><body style="margin:0;background:#f6f2ea;color:#302c26"><main style="max-width:600px;margin:auto;padding:30px 20px"><h1 style="font:38px Georgia,serif;margin:0 0 28px">'+escape(title)+'</h1>'+''.join(cards)+f'<footer style="font:12px Arial,sans-serif">{escape(config["city"])} · {escape(source)}'+('' if demo else ' · <a href="https://open-meteo.com/">Weather data</a>')+'</footer></main></body></html>'
    (out/'newsletter.html').write_text(html);(out/'newsletter.txt').write_text(title+'\n\n'+'\n\n'.join(plain)+'\n'+source)
    (out/'selection.json').write_text(json.dumps(dict(demo=demo,config=config,days=audit),indent=2))
    msg=EmailMessage();msg['Subject']=title
    if recipient:msg['To']=recipient
    msg['Message-ID']=make_msgid();msg.set_content((out/'newsletter.txt').read_text())
    for name,_ in images:html=html.replace(f'src="{name}"',f'src="cid:{name}"')
    msg.add_alternative(html,subtype='html')
    for name,data in images:msg.get_payload()[1].add_related(data,maintype='image',subtype='jpeg',cid=f'<{name}>',filename=name,disposition='inline')
    (out/'newsletter.eml').write_bytes(bytes(msg))
    print(f'Created {out / "newsletter.html"}; {sum(p is not None for p in picks)}/{len(days)} days matched. Nothing sent.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo',action='store_true');parser.add_argument('--wardrobe',type=Path);parser.add_argument('--config',type=Path,default=ROOT/'config.example.json');parser.add_argument('--out',type=Path,default=ROOT/'outputs/newsletter');parser.add_argument('--days',type=int,choices=range(1,8),default=7);parser.add_argument('--to')
    args=parser.parse_args();config=json.loads(args.config.read_text())
    if not 0<=config.get('start_hour',9)<=23:parser.error('start_hour must be 0–23')
    if not args.demo and not args.wardrobe:parser.error('Provide --wardrobe private/wardrobe.json or use --demo')
    backup=json.loads((args.wardrobe or ROOT/'examples/wardrobe.json').read_text())
    forecast=demo_forecast() if args.demo else live_forecast(config)
    generate(backup,forecast,config,args.out,args.days,args.demo,args.to)

if __name__=='__main__':
    try:main()
    except (ValueError,KeyError,OSError) as e:raise SystemExit(f'Could not build newsletter: {e}')
