import os
import json
import csv
import ast

base_dir = r'c:\Users\phama\Downloads\hi_chinese\data_pipeline\raw'

# 1. Load CVDICT to get simp -> trad mapping
cvdict_path = os.path.join(base_dir, 'cvdict', 'CVDICT.u8')
simp_to_trad = {}
with open(cvdict_path, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        try:
            parts = line.split(maxsplit=2)
            trad, simp = parts[0], parts[1]
            simp_to_trad.setdefault(simp, trad)
            for s_char, t_char in zip(simp, trad):
                simp_to_trad.setdefault(s_char, t_char)
        except Exception:
            pass

# 2. Load hanviet.csv
hv_path = os.path.join(base_dir, 'hanviet', 'hanviet.csv')
char_to_hv = {}
with open(hv_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    next(reader, None)
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

print(f'simp_to_trad char pairs: {len(simp_to_trad)}')
print(f'char_to_hv entries: {len(char_to_hv)}')

# Check coverage with simp -> trad fallback
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
            trad_c = simp_to_trad.get(c, c)
            if c in char_to_hv or trad_c in char_to_hv:
                found_chars += 1
            else:
                unmatched_chars.add(c)

print(f'Character Hanviet coverage with trad mapping: {found_chars} / {total_chars} ({found_chars/total_chars*100:.2f}%)')
if unmatched_chars:
    print(f'Unmatched characters ({len(unmatched_chars)} total): {unmatched_chars}')
