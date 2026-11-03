import os
import json
import csv
import re
from collections import defaultdict, Counter

base_dir = os.path.dirname(os.path.abspath(__file__))
raw_dir = os.path.join(base_dir, 'raw', 'grammar')

# 1. Load Gushi
gushi_path = os.path.join(raw_dir, 'gushi_hsk3', 'hsk-3.0-grammar-all.json')
with open(gushi_path, 'r', encoding='utf-8') as f:
    gushi_json = json.load(f)
gushi_data = gushi_json.get('data', [])
print(f"Loaded {len(gushi_data)} Gushi HSK 3.0 points.")

# 2. Load Chinese Grammar Wiki
wiki_points = {} # id -> dict
wiki_sentences = defaultdict(list)

for lvl in range(1, 7):
    # Load grammar list
    list_path = os.path.join(raw_dir, 'chinese_grammar_wiki', f'hsk{lvl}_grammar_list.txt')
    if os.path.exists(list_path):
        with open(list_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) >= 4:
                    url_path = parts[0]
                    gid = parts[1]
                    title = parts[2]
                    struct = parts[3]
                    ex = parts[4] if len(parts) > 4 else ''
                    if gid not in wiki_points:
                        wiki_points[gid] = {
                            'id': gid,
                            'wiki_hsk_folder': lvl,
                            'url': f"https://resources.allsetlearning.com{url_path}",
                            'title': title,
                            'structure': struct,
                            'sample_sentence': ex,
                            'tags': set(),
                            'examples': []
                        }

    # Load csv sentences
    csv_path = os.path.join(raw_dir, 'chinese_grammar_wiki', f'hsk{lvl}.csv')
    if os.path.exists(csv_path):
        with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
            reader = csv.reader(f)
            for r in reader:
                if len(r) >= 9:
                    seg_zh = r[0].strip('\ufeff ')
                    zh = r[1].strip()
                    pinyin = r[2].strip()
                    en = r[3].strip()
                    sound = r[4].strip()
                    struct = r[5].strip()
                    tags = [t.strip() for t in r[6].split(',') if t.strip()]
                    title = r[7].strip()
                    url = r[8].strip()
                    gid = url.split('/')[-1]

                    if gid not in wiki_points:
                        wiki_points[gid] = {
                            'id': gid,
                            'wiki_hsk_folder': lvl,
                            'url': url,
                            'title': title,
                            'structure': struct,
                            'sample_sentence': '',
                            'tags': set(),
                            'examples': []
                        }
                    for t in tags:
                        wiki_points[gid]['tags'].add(t)
                    
                    wiki_points[gid]['examples'].append({
                        'chinese': zh,
                        'chinese_segmented': seg_zh,
                        'pinyin': pinyin,
                        'translation_en': en,
                        'sound_ref': sound,
                        'structure': struct
                    })

print(f"Loaded {len(wiki_points)} unique Chinese Grammar Wiki points.")
total_wiki_examples = sum(len(p['examples']) for p in wiki_points.values())
print(f"Total Wiki sentence examples: {total_wiki_examples}")

# Sample Gushi
print("\nSample Gushi items:")
for g in gushi_data[:3]:
    print(f"  Level {g['level']}: {g['point']} | pattern: {g['pattern']} | cat: {g['categoryChinese']} ({g['categoryEnglish']})")
    print(f"    explanation: {g['explanation']}")
    print(f"    example: {g['exampleChinese']} -> {g['exampleEnglish']}")

# Sample Wiki
print("\nSample Wiki items:")
sample_keys = list(wiki_points.keys())[:3]
for k in sample_keys:
    p = wiki_points[k]
    print(f"  ID {p['id']} (HSK folder {p['wiki_hsk_folder']}): {p['title']}")
    print(f"    struct: {p['structure']}")
    print(f"    tags: {list(p['tags'])[:3]}")
    print(f"    examples count: {len(p['examples'])}")
    if p['examples']:
        print(f"    ex 0: {p['examples'][0]['chinese']} ({p['examples'][0]['pinyin']}) -> {p['examples'][0]['translation_en']}")
