import os
import urllib.request
import time
from pipeline_config import get_raw_dir

RAW_DIR = str(get_raw_dir("tatoeba"))
os.makedirs(RAW_DIR, exist_ok=True)

TATOEBA_URLS = {
    "cmn_sentences_with_audio.tsv.bz2": "https://downloads.tatoeba.org/exports/per_language/cmn/cmn_sentences_with_audio.tsv.bz2",
    "cmn-vie_links.tsv.bz2": "https://downloads.tatoeba.org/exports/per_language/cmn/cmn-vie_links.tsv.bz2",
    "cmn-eng_links.tsv.bz2": "https://downloads.tatoeba.org/exports/per_language/cmn/cmn-eng_links.tsv.bz2",
    "cmn_sentences_detailed.tsv.bz2": "https://downloads.tatoeba.org/exports/per_language/cmn/cmn_sentences_detailed.tsv.bz2",
    "vie_sentences_detailed.tsv.bz2": "https://downloads.tatoeba.org/exports/per_language/vie/vie_sentences_detailed.tsv.bz2",
}

for fname, url in TATOEBA_URLS.items():
    target = os.path.join(RAW_DIR, fname)
    if os.path.exists(target) and os.path.getsize(target) > 100:
        print(f"{fname} already exists ({os.path.getsize(target)/(1024):.1f} KB)")
        continue
    print(f"Downloading {fname} from {url}...")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as resp, open(target, 'wb') as f:
            f.write(resp.read())
        print(f"Downloaded {fname} ({os.path.getsize(target)/(1024):.1f} KB) in {time.time()-start:.1f}s")
    except Exception as e:
        print(f"Error downloading {fname}: {e}")
