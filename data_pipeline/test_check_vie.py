import urllib.request

url = "https://downloads.tatoeba.org/exports/per_language/vie/vie_sentences_detailed.tsv.bz2"
req = urllib.request.Request(url, method='HEAD', headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        size_mb = int(resp.headers.get('Content-Length', 0)) / (1024 * 1024)
        print(f"vie_sentences_detailed.tsv.bz2: {size_mb:.2f} MB")
except Exception as e:
    print("Error:", e)
