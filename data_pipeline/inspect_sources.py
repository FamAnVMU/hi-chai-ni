import re
from pipeline_config import secure_open_url

for path in ['/hsk-3.0/downloads', '/hsk-3.0', '/about']:
    url = f'https://gushi-chinese.online{path}'
    print(f"\n=== FETCHING {url} ===")
    try:
        with secure_open_url(url, timeout=10) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
            print("Length:", len(html))
            hrefs = re.findall(r'href=["\'](.*?)["\']', html)
            for h in hrefs:
                if any(k in h.lower() for k in ['download', 'csv', 'json', 'zip', 'github', 'drive', 'grammar', 'license']):
                    print("  Href:", h)
            for line in html.splitlines():
                if any(k in line.lower() for k in ['grammar', 'license', 'cc by', 'download', '428']):
                    print("  Text:", line.strip()[:150])
    except Exception as e:
        print("Error fetching", url, e)
