import urllib.request

for path in ['src/Positioner.ts', 'src/Quiz.ts']:
    url = f"https://raw.githubusercontent.com/chanind/hanzi-writer/master/{path}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        content = resp.read().decode('utf-8')
        print(f"=== {path} (first 40 lines) ===")
        for line in content.splitlines()[:40]:
            print(line)
