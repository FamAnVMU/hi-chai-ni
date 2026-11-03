import urllib.request
import json

url = "https://api.github.com/repos/chanind/hanzi-writer/git/trees/master?recursive=1"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        tree = json.loads(resp.read().decode('utf-8'))
        files = [item['path'] for item in tree.get('tree', []) if item['path'].endswith('.js') or item['path'].endswith('.ts')]
        print("Source files in hanzi-writer:", len(files))
        for f in files[:20]:
            print(" -", f)
except Exception as e:
    print("Error:", e)
