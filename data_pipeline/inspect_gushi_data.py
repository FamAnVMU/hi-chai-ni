import urllib.request
import ssl
import json

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

base = 'https://gushi-chinese.online/hsk-3.0/downloads'
req = urllib.request.Request(f'{base}/hsk-3.0-grammar-all.json', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
    obj = json.loads(resp.read().decode('utf-8'))
    print("Metadata:")
    for k in ['name', 'language', 'source', 'compiledBy', 'license', 'attribution', 'updated', 'kind', 'count', 'fields']:
        print(f"  {k}: {obj.get(k)}")
    
    data = obj.get('data', [])
    print(f"\nTotal data length: {len(data)}")
    for i in range(min(5, len(data))):
        print(f"\nItem {i}:")
        print(json.dumps(data[i], ensure_ascii=False, indent=2))
