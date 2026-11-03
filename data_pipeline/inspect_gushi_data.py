import json
from pipeline_config import secure_open_url

base = 'https://gushi-chinese.online/hsk-3.0/downloads'
with secure_open_url(f'{base}/hsk-3.0-grammar-all.json', timeout=15) as resp:
    obj = json.loads(resp.read().decode('utf-8'))
    print("Metadata:")
    for k in ['name', 'language', 'source', 'compiledBy', 'license', 'attribution', 'updated', 'kind', 'count', 'fields']:
        print(f"  {k}: {obj.get(k)}")
    
    data = obj.get('data', [])
    print(f"\nTotal data length: {len(data)}")
    for i in range(min(5, len(data))):
        print(f"\nItem {i}:")
        print(json.dumps(data[i], ensure_ascii=False, indent=2))
