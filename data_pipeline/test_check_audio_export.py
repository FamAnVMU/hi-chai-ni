import urllib.request
import re

url = "https://downloads.tatoeba.org/exports/"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=10) as resp:
    html = resp.read().decode('utf-8')
    matches = re.findall(r'href="([^"]+)"', html)
    for m in matches:
        if 'audio' in m:
            print(m)
