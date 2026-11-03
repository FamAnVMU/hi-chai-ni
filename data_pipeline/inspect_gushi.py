import json
from pipeline_config import secure_open_url

base = 'https://gushi-chinese.online/hsk-3.0/downloads'

print("=== FETCHING LICENCE.txt ===")
try:
    with secure_open_url(f'{base}/LICENCE.txt', timeout=10) as resp:
        lic = resp.read().decode('utf-8', errors='ignore')
        print(lic[:1000])
except Exception as e:
    print("Error fetching licence:", e)

print("\n=== FETCHING hsk-3.0-grammar-all.json ===")
try:
    with secure_open_url(f'{base}/hsk-3.0-grammar-all.json', timeout=15) as resp:
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
