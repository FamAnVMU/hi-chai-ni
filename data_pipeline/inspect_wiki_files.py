import urllib.request
import json
import csv
import io

def fetch_json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode('utf-8'))

for fname in ['hsk1_export.txt', 'hsk1_partial_link_allsetwiki.txt', 'hsk1_pinyin.txt']:
    url = f'https://raw.githubusercontent.com/krmanik/Chinese-Grammar/master/HSK1/{fname}'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode('utf-8')
            print(f"=== {fname} preview (len {len(text)}) ===")
            print(text[:400])
    except Exception as e:
        print(f"Error {fname}:", e)
