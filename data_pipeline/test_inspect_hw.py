import urllib.request
import json
import re

url_hw_render = "https://raw.githubusercontent.com/chanind/hanzi-writer/master/src/CharacterRenderer.js"
req = urllib.request.Request(url_hw_render, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        content = resp.read().decode('utf-8')
        print("Found CharacterRenderer.js, length:", len(content))
        # Look for transform or scale
        for line in content.splitlines():
            if 'transform' in line.lower() or 'scale' in line.lower() or '900' in line or '1024' in line:
                print("Line:", line.strip())
except Exception as e:
    print("Error:", e)
