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
                    sample_ex = parts[4] if len(parts) > 4 else ''
                    wiki_points[gid] = {
                        'id': gid,
                        'hsk_folder': lvl,
                        'title': title,
                        'struct': struct,
                        'sample_ex': sample_ex
                    }

# Find key markers in Gushi point
def extract_keywords(pt):
    # e.g. 前缀“第-” -> 第
    # 介词（在、给、跟、对、从、往、比） -> 在, 给, 跟, 对, 从, 往, 比
    # “把”字句 -> 把
    # 动态助词“了” -> 了
    quotes = re.findall(r'[“"‘\'](.*?)[”"’\']', pt)
    parens = re.findall(r'[（(](.*?)[）)]', pt)
    res = []
    for q in quotes:
        clean = re.sub(r'^[-\s]+|[-\s]+$', '', q)
        if clean:
            res.extend(re.split(r'[/、,，]', clean))
    for p in parens:
        clean = re.sub(r'^[-\s]+|[-\s]+$', '', p)
        if clean:
            res.extend(re.split(r'[/、,，……\s]+', clean))
    res = [r for r in res if r and len(r) <= 6]
    return list(set(res))

matches = []
for i, g in enumerate(gushi_points):
    g_pt = g['point']
    g_lvl = g['level']
    keywords = extract_keywords(g_pt)
    
    # Check against wiki
    matched_wiki = []
    for wid, w in wiki_points.items():
        score = 0
        w_title = w['title'].lower()
        w_struct = w['struct']
        
        for kw in keywords:
            if kw in w_struct or f'"{kw}"' in w['title'] or f'with "{kw}"' in w_title or f'with {kw}' in w_title:
                score += 2
            elif kw in w_title:
                score += 1
        
        if score > 0:
            matched_wiki.append((wid, w['title'], w['struct'], w['hsk_folder'], score))
    
    matched_wiki.sort(key=lambda x: x[4], reverse=True)
    if matched_wiki:
        matches.append((g, matched_wiki[:3]))

print(f"Matched {len(matches)} out of {len(gushi_points)} Gushi points to Wiki points.")

print("\n--- First 15 Matches Sample ---")
for g, mw in matches[:15]:
    print(f"\n[HSK {g['level']}] {g['point']} (cat: {g['categoryChinese']})")
    for wid, title, struct, w_lvl, score in mw:
        print(f"   -> Wiki (HSK {w_lvl}): [{wid}] {title} | {struct} (score: {score})")
