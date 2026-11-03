import urllib.request
import ssl
import json
from collections import Counter

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

base = 'https://gushi-chinese.online/hsk-3.0/downloads'
req = urllib.request.Request(f'{base}/hsk-3.0-grammar-all.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
    obj = json.loads(resp.read().decode('utf-8'))
    data = obj.get('data', [])
    levels = Counter([d['level'] for d in data])
    print("Level breakdown in Gushi HSK 3.0:")
    for lvl in sorted(levels.keys()):
        print(f"  Level {lvl}: {levels[lvl]} points")
    
    cats = Counter([d['categoryChinese'] for d in data])
    print("\nCategory Chinese breakdown:")
    for c, cnt in cats.most_common():
        print(f"  {c}: {cnt}")
