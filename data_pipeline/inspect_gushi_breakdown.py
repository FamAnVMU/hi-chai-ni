from collections import Counter
import json
from pipeline_config import secure_open_url

base = 'https://gushi-chinese.online/hsk-3.0/downloads'
with secure_open_url(f'{base}/hsk-3.0-grammar-all.json', timeout=15) as resp:
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
