import os
import json
import re

base_dir = os.path.dirname(os.path.abspath(__file__))
raw_dir = os.path.join(base_dir, 'raw', 'grammar')

with open(os.path.join(raw_dir, 'gushi_hsk3', 'hsk-3.0-grammar-all.json'), 'r', encoding='utf-8') as f:
    gushi_points = json.load(f).get('data', [])

# Load Wiki points
wiki_points = {}
for lvl in range(1, 7):
    list_path = os.path.join(raw_dir, 'chinese_grammar_wiki', f'hsk{lvl}_grammar_list.txt')
    if os.path.exists(list_path):
        with open(list_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) >= 4:
                    gid = parts[1]
                    title = parts[2]
                    struct = parts[3]
                    wiki_points[gid] = {
                        'id': gid,
                        'hsk_folder': lvl,
                        'title': title,
                        'struct': struct,
                        'point': None
                    }

print(f"Total Gushi: {len(gushi_points)}, Total Wiki: {len(wiki_points)}")

# Let's inspect Gushi points across levels 1-6
for lvl in range(1, 7):
    pts = [g for g in gushi_points if g['level'] == lvl]
    print(f"\nLevel {lvl} ({len(pts)} points):")
    for p in pts[:10]:
        print(f"  [{p['categoryChinese']}] {p['point']} | pattern: {p['pattern']}")
