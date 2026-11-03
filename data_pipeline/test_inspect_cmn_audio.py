import urllib.request
import bz2

url = "https://downloads.tatoeba.org/exports/per_language/cmn/cmn_sentences_with_audio.tsv.bz2"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        decompressed = bz2.decompress(resp.read()).decode('utf-8')
        lines = decompressed.strip().splitlines()
        print(f"Total Chinese sentences with audio in Tatoeba: {len(lines)}")
        print("Sample 5 entries:")
        for line in lines[:5]:
            print(" -", line)
except Exception as e:
    print("Error:", e)
