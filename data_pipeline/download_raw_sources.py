import os
import sys
import urllib.request
import time

def download_file(url, dest_path):
    print(f"Downloading {url} -> {dest_path}...")
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    start = time.time()
    with urllib.request.urlopen(req) as resp, open(dest_path, 'wb') as out:
        total_size = int(resp.headers.get('content-length', 0))
        downloaded = 0
        block_size = 65536
        while True:
            chunk = resp.read(block_size)
            if not chunk:
                break
            out.write(chunk)
            downloaded += len(chunk)
            if total_size > 0:
                percent = downloaded * 100 / total_size
                sys.stdout.write(f"\r  {downloaded / 1024 / 1024:.2f} MB / {total_size / 1024 / 1024:.2f} MB ({percent:.1f}%)")
            else:
                sys.stdout.write(f"\r  {downloaded / 1024 / 1024:.2f} MB")
            sys.stdout.flush()
    elapsed = time.time() - start
    print(f"\n  Done in {elapsed:.2f}s ({os.path.getsize(dest_path) / 1024 / 1024:.2f} MB)")

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    raw_dir = os.path.join(base_dir, "raw")

    # 1. Clem109 HSK Vocabulary 1-6
    clem_base = "https://raw.githubusercontent.com/clem109/hsk-vocabulary/master/hsk-vocab-json"
    for l in range(1, 7):
        dest = os.path.join(raw_dir, "clem109", f"hsk-level-{l}.json")
        if not os.path.exists(dest):
            download_file(f"{clem_base}/hsk-level-{l}.json", dest)
        else:
            print(f"Already exists: {dest}")

    # 2. DrKameleon complete HSK vocabulary 1-6 (old 2012 syllabus)
    drk_base = "https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/wordlists/exclusive/old"
    for l in range(1, 7):
        dest = os.path.join(raw_dir, "drkameleon", f"hsk-level-{l}.json")
        if not os.path.exists(dest):
            download_file(f"{drk_base}/{l}.json", dest)
        else:
            print(f"Already exists: {dest}")

    # 3. CVDICT.u8 (Phong Phan CC BY-SA 4.0)
    cvdict_dest = os.path.join(raw_dir, "cvdict", "CVDICT.u8")
    if not os.path.exists(cvdict_dest):
        download_file("https://raw.githubusercontent.com/ph0ngp/CVDICT/main/CVDICT.u8", cvdict_dest)
    else:
        print(f"Already exists: {cvdict_dest}")

    # 4. Hanviet CSV (Phong Phan MIT)
    hanviet_dest = os.path.join(raw_dir, "hanviet", "hanviet.csv")
    if not os.path.exists(hanviet_dest):
        download_file("https://raw.githubusercontent.com/ph0ngp/hanviet-pinyin-wordlist/main/hanviet.csv", hanviet_dest)
    else:
        print(f"Already exists: {hanviet_dest}")

    # 5. HSK Sentences (no7z MIT)
    sentences_dest = os.path.join(raw_dir, "sentences", "sentences.json")
    if not os.path.exists(sentences_dest):
        download_file("https://raw.githubusercontent.com/no7z/hsk-sentences-audio/master/dist/sentences.json", sentences_dest)
    else:
        print(f"Already exists: {sentences_dest}")

    print("\nAll raw sources downloaded successfully!")

if __name__ == "__main__":
    main()
