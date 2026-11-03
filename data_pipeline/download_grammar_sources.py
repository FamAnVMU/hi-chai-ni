import json
from pathlib import Path
import sys

from pipeline_config import download_file_secure, get_raw_dir

HEADERS = {'User-Agent': 'Mozilla/5.0'}

def download_file(url: str, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    size = download_file_secure(url, out_path, headers=HEADERS, timeout=30)
    print(f"Downloaded {size:,} bytes -> {out_path}")

def main():
    raw_dir = get_raw_dir('grammar')
    
    print("=== Downloading Gushi HSK 3.0 Grammar Data ===")
    gushi_dir = raw_dir / 'gushi_hsk3'
    gushi_base = 'https://gushi-chinese.online/hsk-3.0/downloads'
    download_file(f'{gushi_base}/LICENCE.txt', gushi_dir / 'LICENCE.txt')
    download_file(f'{gushi_base}/hsk-3.0-grammar-all.json', gushi_dir / 'hsk-3.0-grammar-all.json')
    download_file(f'{gushi_base}/hsk-3.0-grammar-all.csv', gushi_dir / 'hsk-3.0-grammar-all.csv')
    for lvl in range(1, 8):
        download_file(f'{gushi_base}/hsk-3.0-grammar-{lvl}.json', gushi_dir / f'hsk-3.0-grammar-{lvl}.json')
        download_file(f'{gushi_base}/hsk-3.0-grammar-{lvl}.csv', gushi_dir / f'hsk-3.0-grammar-{lvl}.csv')

    print("\n=== Downloading Chinese Grammar Wiki Data (krmanik) ===")
    wiki_dir = raw_dir / 'chinese_grammar_wiki'
    wiki_repo = 'https://raw.githubusercontent.com/krmanik/Chinese-Grammar/master'
    download_file(f'{wiki_repo}/README.md', wiki_dir / 'README.md')
    for lvl in range(1, 7):
        download_file(f'{wiki_repo}/CSV%20Files%20HSK1%20-%20HSK6/hsk{lvl}.csv', wiki_dir / f'hsk{lvl}.csv')
        download_file(f'{wiki_repo}/HSK{lvl}/hsk{lvl}_grammar_list.txt', wiki_dir / f'hsk{lvl}_grammar_list.txt')
        download_file(f'{wiki_repo}/HSK{lvl}/hsk{lvl}_export.txt', wiki_dir / f'hsk{lvl}_export.txt')

    print("\nRaw downloads completed successfully!")

if __name__ == '__main__':
    main()
