import urllib.request
import ssl
import json

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

base = 'https://gushi-chinese.online/hsk-3.0/downloads'

# 1. Fetch LICENCE.txt
print("=== FETCHING LICENCE.txt ===")
try:
    req = urllib.request.Request(f'{base}/LICENCE.txt', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        lic = resp.read().decode('utf-8', errors='ignore')
        print(lic[:1000])
except Exception as e:
    print("Error fetching licence:", e)

# 2. Fetch hsk-3.0-grammar-all.json
print("\n=== FETCHING hsk-3.0-grammar-all.json ===")
try:
    req = urllib.request.Request(f'{base}/hsk-3.0-grammar-all.json', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print("Type:", type(data))
        if isinstance(data, list):
            print("Total records:", len(data))
            print("First item keys:", data[0].keys() if data else 'Empty')
            print("First item sample:", json.dumps(data[0], ensure_ascii=False, indent=2))
            print("Second item sample:", json.dumps(data[1], ensure_ascii=False, indent=2))
        elif isinstance(data, dict):
            print("Dict keys:", data.keys())
except Exception as e:
    print("Error fetching grammar-all.json:", e)
