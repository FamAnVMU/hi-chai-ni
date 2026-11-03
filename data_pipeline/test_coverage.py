import os
import json
import csv
import ast

base_dir = r'c:\Users\phama\Downloads\hi_chinese\data_pipeline\raw'

# Load hanviet.csv
hv_path = os.path.join(base_dir, 'hanviet', 'hanviet.csv')
char_to_hv = {}
with open(hv_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    next(reader, None)  # skip header
    for row in reader:
        if len(row) >= 2:
            char = row[0]
            raw_hv = row[1].strip()
            try:
                hvs = ast.literal_eval(raw_hv)
                if isinstance(hvs, list) and hvs:
                    char_to_hv.setdefault(char, []).extend(hvs)
            except Exception:
                pass

print(f'Loaded Hanviet mappings for {len(char_to_hv)} characters')

# Check coverage for all 5000 words
total_chars = 0
found_chars = 0
unmatched_chars = set()

for l in range(1, 7):
    path = os.path.join(base_dir, 'clem109', f'hsk-level-{l}.json')
    with open(path, 'r', encoding='utf-8') as f:
        data = json.loads(f.read())
    for item in data:
        for c in item['hanzi']:
            total_chars += 1
            if c in char_to_hv:
                found_chars += 1
            else:
                unmatched_chars.add(c)

print(f'Character Hanviet coverage: {found_chars} / {total_chars} ({found_chars/total_chars*100:.2f}%)')
if unmatched_chars:
    print(f'Unmatched characters ({len(unmatched_chars)} total): {unmatched_chars}')
