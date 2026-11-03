import urllib.request
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

url = 'https://resources.allsetlearning.com/chinese/grammar/ASG846EA'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        html = resp.read().decode('utf-8', errors='ignore')
        print("Page length:", len(html))
        # Look for level info in html
        for line in html.splitlines():
            if any(k in line.lower() for k in ['level', 'a1', 'a2', 'b1', 'b2', 'c1', 'hsk']):
                print("Line:", line.strip()[:120])
except Exception as e:
    print("Error:", e)
