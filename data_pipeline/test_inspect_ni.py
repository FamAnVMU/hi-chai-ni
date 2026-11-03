import urllib.request
import json

url_graphics = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"

# Let's inspect a common character like '你' or '好'
chars_to_find = {'你', '好', '中', '国', '学'}
found = {}

req = urllib.request.Request(url_graphics, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=30) as resp:
    for line in resp:
        line_str = line.decode('utf-8')
        c = json.loads(line_str)
        char = c.get("character")
        if char in chars_to_find:
            found[char] = c
            print(f"Found {char}: {len(c.get('strokes', []))} strokes")
            if len(found) == len(chars_to_find):
                break

print("\nDetail of '你':")
ni = found.get('你', {})
print("Strokes count:", len(ni.get('strokes', [])))
for i, stroke in enumerate(ni.get('strokes', [])):
    print(f"Stroke {i+1}: {stroke[:50]}... (len {len(stroke)})")
    print(f"Median {i+1}: {ni.get('medians', [])[i]}")
