import os
import urllib.request
import time

RAW_DIR = r"C:\Users\phama\Downloads\hi_chinese\data_pipeline\raw\hanzi"
os.makedirs(RAW_DIR, exist_ok=True)

GRAPHICS_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"
DICTIONARY_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt"

def download_file(url, target_path):
    print(f"Downloading {url} to {target_path}...")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    start_time = time.time()
    with urllib.request.urlopen(req) as response, open(target_path, 'wb') as out_file:
        chunk_size = 64 * 1024
        total_downloaded = 0
        while True:
            chunk = response.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
            total_downloaded += len(chunk)
    elapsed = time.time() - start_time
    print(f"Downloaded {total_downloaded / (1024 * 1024):.2f} MB in {elapsed:.1f}s -> {target_path}")

graphics_path = os.path.join(RAW_DIR, "graphics.txt")
dictionary_path = os.path.join(RAW_DIR, "dictionary.txt")

if not os.path.exists(graphics_path) or os.path.getsize(graphics_path) < 1000:
    download_file(GRAPHICS_URL, graphics_path)
else:
    print(f"graphics.txt already exists ({os.path.getsize(graphics_path)/(1024*1024):.2f} MB)")

if not os.path.exists(dictionary_path) or os.path.getsize(dictionary_path) < 1000:
    download_file(DICTIONARY_URL, dictionary_path)
else:
    print(f"dictionary.txt already exists ({os.path.getsize(dictionary_path)/(1024*1024):.2f} MB)")
