import urllib.request

base = "https://downloads.tatoeba.org/exports/per_language/cmn/"
files = [
    "cmn_sentences_with_audio.tsv.bz2",
    "cmn-vie_links.tsv.bz2",
    "cmn-eng_links.tsv.bz2",
    "cmn_sentences_detailed.tsv.bz2"
]

for f in files:
    url = base + f
    req = urllib.request.Request(url, method='HEAD', headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            size_mb = int(resp.headers.get('Content-Length', 0)) / (1024 * 1024)
            print(f"{f}: {size_mb:.2f} MB")
    except Exception as e:
        print(f"Error {f}: {e}")
