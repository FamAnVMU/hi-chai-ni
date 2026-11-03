import urllib.request
import bz2

for f in ['cmn-vie_links.tsv.bz2', 'cmn-eng_links.tsv.bz2']:
    url = f"https://downloads.tatoeba.org/exports/per_language/cmn/{f}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            decompressed = bz2.decompress(resp.read()).decode('utf-8')
            lines = decompressed.strip().splitlines()
            print(f"Total links in {f}: {len(lines)}")
            for line in lines[:3]:
                print(" -", line)
    except Exception as e:
        print(f"Error {f}: {e}")
