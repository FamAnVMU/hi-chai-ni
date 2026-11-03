import os
import json
import urllib.request
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HEADERS = {'User-Agent': 'Mozilla/5.0'}

def download_file(url, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        data = resp.read()
        with open(out_path, 'wb') as f:
            f.write(data)
    print(f"Downloaded {len(data):,} bytes -> {out_path}")

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    raw_dir = os.path.join(base_dir, 'raw', 'grammar')
    
    # 1. Gushi HSK 3.0
    print("=== Downloading Gushi HSK 3.0 Grammar Data ===")
    gushi_dir = os.path.join(raw_dir, 'gushi_hsk3')
    gushi_base = 'https://gushi-chinese.online/hsk-3.0/downloads'
    download_file(f'{gushi_base}/LICENCE.txt', os.path.join(gushi_dir, 'LICENCE.txt'))
    download_file(f'{gushi_base}/hsk-3.0-grammar-all.json', os.path.join(gushi_dir, 'hsk-3.0-grammar-all.json'))
    download_file(f'{gushi_base}/hsk-3.0-grammar-all.csv', os.path.join(gushi_dir, 'hsk-3.0-grammar-all.csv'))
    for lvl in range(1, 8):
        download_file(f'{gushi_base}/hsk-3.0-grammar-{lvl}.json', os.path.join(gushi_dir, f'hsk-3.0-grammar-{lvl}.json'))
        download_file(f'{gushi_base}/hsk-3.0-grammar-{lvl}.csv', os.path.join(gushi_dir, f'hsk-3.0-grammar-{lvl}.csv'))

    # 2. Chinese Grammar Wiki (krmanik/Chinese-Grammar)
    print("\n=== Downloading Chinese Grammar Wiki Data (krmanik) ===")
    wiki_dir = os.path.join(raw_dir, 'chinese_grammar_wiki')
    wiki_repo = 'https://raw.githubusercontent.com/krmanik/Chinese-Grammar/master'
    download_file(f'{wiki_repo}/README.md', os.path.join(wiki_dir, 'README.md'))
    for lvl in range(1, 7):
        download_file(f'{wiki_repo}/CSV%20Files%20HSK1%20-%20HSK6/hsk{lvl}.csv', os.path.join(wiki_dir, f'hsk{lvl}.csv'))
        download_file(f'{wiki_repo}/HSK{lvl}/hsk{lvl}_grammar_list.txt', os.path.join(wiki_dir, f'hsk{lvl}_grammar_list.txt'))
        download_file(f'{wiki_repo}/HSK{lvl}/hsk{lvl}_export.txt', os.path.join(wiki_dir, f'hsk{lvl}_export.txt'))

    print("\nRaw downloads completed successfully!")

if __name__ == '__main__':
    main()
