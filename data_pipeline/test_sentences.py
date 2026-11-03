import os
import json
from pipeline_config import get_raw_dir

base_dir = str(get_raw_dir())

sent_path = os.path.join(base_dir, 'sentences', 'sentences.json')
with open(sent_path, 'r', encoding='utf-8') as f:
    sentences = json.load(f)

print(f'Total sentences: {len(sentences)}')

# Build map of word -> list of matching sentences
word_to_sentences = {}
for s in sentences:
    level = s.get('hsk_level', 1)
    zh = s.get('chinese', '')
    pinyin = s.get('pinyin', '')
    en = s.get('translation', {}).get('en', '')
    s_id = s.get('id', '')
    audio_normal = s.get('audio', {}).get('normal', '')
    audio_slow = s.get('audio', {}).get('slow', '')

    tokens = s.get('tokens', [])
    for t in tokens:
        word = t.get('word', '')
        if word:
            word_to_sentences.setdefault(word, []).append({
                'id': s_id,
                'level': level,
                'zh': zh,
                'pinyin': pinyin,
                'en': en,
                'audio_normal': audio_normal,
                'audio_slow': audio_slow,
            })

print(f'Unique words indexed in tokens: {len(word_to_sentences)}')

# Check against HSK 1-6
total_all = 0
matched_all = 0
for l in range(1, 7):
    path = os.path.join(base_dir, 'clem109', f'hsk-level-{l}.json')
    with open(path, 'r', encoding='utf-8') as f:
        data = json.loads(f.read())
    matched = sum(1 for x in data if x['hanzi'] in word_to_sentences or any(x['hanzi'] in s.get('chinese', '') for s in sentences))
    total_all += len(data)
    matched_all += matched
    print(f'HSK {l}: {matched} / {len(data)} have matching sentences ({matched/len(data)*100:.1f}%)')

print(f'Overall sentence coverage: {matched_all} / {total_all} ({matched_all/total_all*100:.1f}%)')
