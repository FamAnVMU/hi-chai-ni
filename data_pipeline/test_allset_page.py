from pipeline_config import secure_open_url

url = 'https://resources.allsetlearning.com/chinese/grammar/ASG846EA'
try:
    with secure_open_url(url, timeout=10) as resp:
        html = resp.read().decode('utf-8', errors='ignore')
        print("Page length:", len(html))
        for line in html.splitlines():
            if any(k in line.lower() for k in ['level', 'a1', 'a2', 'b1', 'b2', 'c1', 'hsk']):
                print("Line:", line.strip()[:120])
except Exception as e:
    print("Error:", e)
