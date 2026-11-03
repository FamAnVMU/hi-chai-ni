import urllib.request
import json

# Check Tatoeba per_language exports
url = "https://downloads.tatoeba.org/exports/per_language/cmn/"
print("Testing Tatoeba exports...")
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        content = resp.read().decode('utf-8')
        print("Tatoeba exports directory found! Sample:")
        for line in content.splitlines()[:20]:
            if 'href' in line:
                print(line.strip())
except Exception as e:
    print("Error accessing downloads.tatoeba.org:", e)

# Test Tatoeba API
api_url = "https://tatoeba.org/en/api_v0/search?from=cmn&to=vie&has_audio=yes&trans_filter=limit&limit=5"
print("\nTesting Tatoeba search API...")
req2 = urllib.request.Request(api_url, headers={"User-Agent": "Mozilla/5.0 (HI Chinese Educational Agent)"})
try:
    with urllib.request.urlopen(req2, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print("API Response results count:", len(data.get('results', [])))
        if data.get('results'):
            sample = data['results'][0]
            print("Sample sentence:", sample.get('text'))
            print("Audio count:", len(sample.get('audios', [])))
            print("Translations count:", len(sample.get('translations', [])))
except Exception as e:
    print("Error calling Tatoeba API:", e)
