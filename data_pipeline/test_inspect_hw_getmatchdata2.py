import urllib.request

url = "https://raw.githubusercontent.com/chanind/hanzi-writer/master/src/strokeMatches.ts"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=15) as resp:
    content = resp.read().decode('utf-8')
    lines = content.splitlines()
    print("=== strokeMatches.ts (lines 100 to 180) ===")
    for line in lines[100:180]:
        print(line)
