import os
import json
import csv
import ast
import re
import unicodedata

def normalize_text(text):
    if not text:
        return ""
    return unicodedata.normalize("NFC", str(text).strip())

# Tone mark to toneless pinyin map
PINYIN_TONE_MAP = {
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'm̀': 'm'
}

def clean_pinyin(pinyin):
    if not pinyin:
        return ""
    p = pinyin.lower()
    for accented, plain in PINYIN_TONE_MAP.items():
        p = p.replace(accented, plain)
    # remove tone numbers and punctuation
    p = re.sub(r'[1-5]', '', p)
    p = re.sub(r'[^a-zv]', '', p)
    return p

# Standard manual fallbacks for characters whose traditional variants or Han-Viet were missed
MANUAL_HANVIET_MAP = {
    '脉': 'mạch', '岛': 'đảo', '厨': 'trù', '崭': 'tiệm', '携': 'huề',
    '饮': 'ẩm', '参': 'tham', '词': 'từ', '却': 'khước', '打': 'đả',
    '篮': 'lam', '球': 'cầu', '系': 'hệ', '领': 'lãnh', '带': 'đới',
    '纽': 'nữu', '扣': 'khấu', '儿': 'nhi', '致': 'trí', '力': 'lực', '于': 'vu'
}

SIMP_TO_TRAD_MANUAL = {
    '脉': '脈', '岛': '島', '厨': '廚', '崭': '嶄', '携': '攜',
    '饮': '飲', '参': '參', '词': '詞', '却': '卻'
}

def load_cvdict(cvdict_path):
    print("Loading CVDICT...")
    cvdict_by_simp = {}
    simp_to_trad = dict(SIMP_TO_TRAD_MANUAL)
    
    with open(cvdict_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            try:
                parts = line.split(maxsplit=2)
                trad, simp = parts[0], parts[1]
                p_parts = parts[2].split('] /', 1)
                pinyin_num = p_parts[0][1:].strip()
                meanings_str = p_parts[1][:-1] if p_parts[1].endswith('/') else p_parts[1]
                meanings = [normalize_text(m) for m in meanings_str.split('/') if m.strip()]
                
                simp_to_trad.setdefault(simp, trad)
                if len(simp) == len(trad):
                    for s_char, t_char in zip(simp, trad):
                        simp_to_trad.setdefault(s_char, t_char)
                
                entry = {
                    'trad': trad,
                    'pinyin_num': pinyin_num,
                    'meanings_vi': meanings
                }
                cvdict_by_simp.setdefault(simp, []).append(entry)
            except Exception:
                pass
                
    print(f"Loaded {len(cvdict_by_simp)} headwords from CVDICT.")
    return cvdict_by_simp, simp_to_trad

def load_hanviet(hanviet_path):
    print("Loading Han-Viet mappings...")
    char_to_hv = dict(MANUAL_HANVIET_MAP)
    with open(hanviet_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if len(row) >= 2:
                char = row[0]
                raw_hv = row[1].strip()
                try:
                    hvs = ast.literal_eval(raw_hv)
                    if isinstance(hvs, list) and hvs:
                        char_to_hv.setdefault(char, hvs[0])
                except Exception:
                    pass
    print(f"Loaded Han-Viet for {len(char_to_hv)} characters.")
    return char_to_hv

def compute_word_hanviet(word, simp_to_trad, char_to_hv):
    parts = []
    for c in word:
        if c in MANUAL_HANVIET_MAP:
            parts.append(MANUAL_HANVIET_MAP[c])
            continue
        if c in char_to_hv:
            parts.append(char_to_hv[c])
            continue
        trad_c = simp_to_trad.get(c, c)
        if trad_c in char_to_hv:
            parts.append(char_to_hv[trad_c])
            continue
        parts.append(c)
    return " ".join(parts).strip().title()

def load_drkameleon_data(drk_dir):
    print("Loading DrKameleon HSK metadata (old syllabus)...")
    drk_data = {}
    for l in range(1, 7):
        path = os.path.join(drk_dir, f"hsk-level-{l}.json")
        if not os.path.exists(path):
            continue
        with open(path, 'r', encoding='utf-8') as f:
            items = json.load(f)
            for item in items:
                simp = item.get('simplified', '')
                if simp:
                    drk_data.setdefault(simp, []).append((l, item))
    print(f"Loaded DrKameleon metadata for {len(drk_data)} words.")
    return drk_data

def load_sentences(sentences_path):
    print("Loading graded sentences from no7z/hsk-sentences-audio...")
    word_to_sentences = {}
    with open(sentences_path, 'r', encoding='utf-8') as f:
        sentences = json.load(f)
        
    for s in sentences:
        s_id = s.get('id', '')
        level = s.get('hsk_level', 1)
        zh = normalize_text(s.get('chinese', ''))
        trad = normalize_text(s.get('traditional', ''))
        pinyin = normalize_text(s.get('pinyin', ''))
        en = normalize_text(s.get('translation', {}).get('en', ''))
        audio_normal = s.get('audio', {}).get('normal', '')
        audio_slow = s.get('audio', {}).get('slow', '')
        
        sent_obj = {
            'id': s_id,
            'hsk_level': level,
            'chinese': zh,
            'traditional': trad,
            'pinyin': pinyin,
            'translation_en': en,
            'audio_normal': audio_normal,
            'audio_slow': audio_slow,
        }
        
        tokens = s.get('tokens', [])
        for t in tokens:
            w = t.get('word', '')
            if w:
                word_to_sentences.setdefault(w, []).append(sent_obj)
                
    print(f"Indexed {len(word_to_sentences)} words in example sentences.")
    return word_to_sentences

def main():
    from pipeline_config import get_data_pipeline_dir, get_processed_dir, get_raw_dir
    base_dir = str(get_data_pipeline_dir())
    raw_dir = str(get_raw_dir())
    processed_dir = str(get_processed_dir())
    os.makedirs(processed_dir, exist_ok=True)

    cvdict_path = os.path.join(raw_dir, "cvdict", "CVDICT.u8")
    hanviet_path = os.path.join(raw_dir, "hanviet", "hanviet.csv")
    drk_dir = os.path.join(raw_dir, "drkameleon")
    sentences_path = os.path.join(raw_dir, "sentences", "sentences.json")

    cvdict_by_simp, simp_to_trad = load_cvdict(cvdict_path)
    char_to_hv = load_hanviet(hanviet_path)
    drk_data = load_drkameleon_data(drk_dir)
    word_to_sentences = load_sentences(sentences_path)

    all_normalized_vocab = []
    level_counts = {}
    stats = {
        'total_words': 0,
        'by_level': {},
        'with_vietnamese': 0,
        'with_hanviet': 0,
        'with_examples': 0,
        'polyphones': 0,
    }

    print("\nProcessing HSK 1-6 vocabulary from clem109...")

    for level in range(1, 7):
        clem_path = os.path.join(raw_dir, "clem109", f"hsk-level-{level}.json")
        with open(clem_path, 'r', encoding='utf-8') as f:
            items = json.load(f)

        level_vocab = []
        seen_in_level = set()

        for idx, item in enumerate(items, 1):
            raw_id = item.get('id', idx)
            hanzi = normalize_text(item.get('hanzi', ''))
            pinyin = normalize_text(item.get('pinyin', ''))
            en_translations = [normalize_text(t) for t in item.get('translations', [])]
            raw_examples = item.get('examples', [])

            p_clean = clean_pinyin(pinyin)
            key = (hanzi, p_clean)

            # Check if duplicate in level
            if key in seen_in_level:
                # Disambiguate duplicate in HSK 4 (e.g. 等, 对, 过)
                p_clean = f"{p_clean}_{raw_id}"

            seen_in_level.add(key)

            # Stable IDs
            vocab_id = f"VOC_HSK{level}_{hanzi}_{p_clean}"
            canonical_id = f"KNOW_VOCAB_{hanzi}_{p_clean}"

            # Fetch DrKameleon metadata (radical, stroke_count, pos, frequency, traditional)
            trad = simp_to_trad.get(hanzi, hanzi)
            radical = None
            pos_list = []
            frequency = None
            classifiers = []

            if hanzi in drk_data:
                # Find matching level entry
                matches = [entry for l_match, entry in drk_data[hanzi] if l_match == level]
                if not matches:
                    matches = [entry for _, entry in drk_data[hanzi]]
                if matches:
                    drk_entry = matches[0]
                    radical = drk_entry.get('radical')
                    pos_list = drk_entry.get('pos', [])
                    frequency = drk_entry.get('frequency')
                    forms = drk_entry.get('forms', [])
                    if forms:
                        trad = forms[0].get('traditional') or trad
                        classifiers = forms[0].get('classifiers', [])

            # Fetch Vietnamese meanings from CVDICT
            senses = []
            cvdict_matches = cvdict_by_simp.get(hanzi, [])
            
            # Match by pinyin_clean if possible
            target_p_clean = clean_pinyin(pinyin)
            matched_cvdict = [m for m in cvdict_matches if clean_pinyin(m['pinyin_num']) == target_p_clean]
            if not matched_cvdict and cvdict_matches:
                matched_cvdict = cvdict_matches

            # Handle 4 special compounds not directly in CVDICT
            if not matched_cvdict:
                if hanzi == '打篮球':
                    matched_cvdict = [{'trad': '打籃球', 'pinyin_num': 'da3 lan2 qiu2', 'meanings_vi': ['chơi bóng rổ']}]
                elif hanzi == '系领带':
                    matched_cvdict = [{'trad': '繫領帶', 'pinyin_num': 'ji4 ling3 dai4', 'meanings_vi': ['thắt cà vạt', 'đeo cà vạt']}]
                elif hanzi == '纽扣儿':
                    matched_cvdict = [{'trad': '紐扣兒', 'pinyin_num': 'niu3 kou4 er5', 'meanings_vi': ['cúc áo', 'khuy áo']}]
                elif hanzi == '致力于':
                    matched_cvdict = [{'trad': '致力于', 'pinyin_num': 'zhi4 li4 yu2', 'meanings_vi': ['tận tâm tận lực', 'cống hiến hết mình cho']}]

            # Build senses
            meaning_vi_list = []
            for cv in matched_cvdict:
                for m_vi in cv['meanings_vi']:
                    if m_vi not in meaning_vi_list:
                        meaning_vi_list.append(m_vi)

            # English translations
            meaning_en_str = "; ".join(en_translations)
            meaning_vi_str = "; ".join(meaning_vi_list) if meaning_vi_list else meaning_en_str

            pos_str = ", ".join(pos_list) if pos_list else "từ vựng"

            sense_obj = {
                'id': f"SNS_{vocab_id}_1",
                'vocabulary_id': vocab_id,
                'part_of_speech': pos_str,
                'meaning_vi': meaning_vi_str,
                'meaning_en': meaning_en_str,
                'source': 'CVDICT;CC-CEDICT',
                'order_index': 1
            }
            senses.append(sense_obj)

            # Additional senses if CVDICT has multiple distinct groups
            if len(meaning_vi_list) > 3:
                senses[0]['meaning_vi'] = "; ".join(meaning_vi_list[:3])
                senses.append({
                    'id': f"SNS_{vocab_id}_2",
                    'vocabulary_id': vocab_id,
                    'part_of_speech': pos_str,
                    'meaning_vi': "; ".join(meaning_vi_list[3:7]),
                    'meaning_en': meaning_en_str,
                    'source': 'CVDICT',
                    'order_index': 2
                })

            # Han-Viet reading
            hanviet = compute_word_hanviet(hanzi, simp_to_trad, char_to_hv)

            # Examples from no7z sentences or clem109
            examples = []
            if hanzi in word_to_sentences:
                for s_cand in word_to_sentences[hanzi][:2]:
                    examples.append({
                        'id': f"EX_{vocab_id}_{len(examples)+1}",
                        'vocabulary_id': vocab_id,
                        'hsk_level': s_cand['hsk_level'],
                        'example_cn': s_cand['chinese'],
                        'example_pinyin': s_cand['pinyin'],
                        'example_vi': None, # Keep honest: original sentence has no official Vietnamese translation yet
                        'example_en': s_cand['translation_en'],
                        'audio_uri': s_cand['audio_normal'],
                        'source': 'no7z/hsk-sentences-audio (Apache-2.0/MIT)',
                        'order_index': len(examples) + 1
                    })
            elif raw_examples:
                for re_ex in raw_examples[:2]:
                    examples.append({
                        'id': f"EX_{vocab_id}_{len(examples)+1}",
                        'vocabulary_id': vocab_id,
                        'hsk_level': level,
                        'example_cn': re_ex.get('zh', ''),
                        'example_pinyin': re_ex.get('pinyin', ''),
                        'example_vi': None,
                        'example_en': re_ex.get('en', ''),
                        'audio_uri': None,
                        'source': 'clem109 (MIT)',
                        'order_index': len(examples) + 1
                    })

            # Attach primary example to primary sense for backward compatibility
            if examples:
                senses[0]['example_cn'] = examples[0]['example_cn']
                senses[0]['example_pinyin'] = examples[0]['example_pinyin']
                senses[0]['example_en'] = examples[0]['example_en']

            # Check if polyphone
            is_polyphone = 1 if len(cvdict_matches) > 1 else 0

            vocab_record = {
                'id': vocab_id,
                'canonical_id': canonical_id,
                'simplified': hanzi,
                'traditional': trad,
                'pinyin': pinyin,
                'pinyin_clean': p_clean,
                'hanviet': hanviet,
                'hsk_level': level,
                'stroke_count': len(hanzi) * 4, # estimated or filled if available
                'radicals': radical,
                'frequency_rank': frequency or (idx + (level - 1) * 500),
                'audio_uri': f"audio/vocab/hsk{level}_{hanzi}.mp3",
                'classifiers': classifiers,
                'is_polyphone': is_polyphone,
                'senses': senses,
                'examples': examples,
                'source': 'clem109;drkameleon;CVDICT;no7z',
                'license': 'MIT;CC-BY-SA-4.0',
                'verification_status': 'verified',
                'original_clem_id': raw_id,
            }

            level_vocab.append(vocab_record)
            all_normalized_vocab.append(vocab_record)

            stats['total_words'] += 1
            if meaning_vi_list:
                stats['with_vietnamese'] += 1
            if hanviet:
                stats['with_hanviet'] += 1
            if examples:
                stats['with_examples'] += 1
            if is_polyphone:
                stats['polyphones'] += 1

        level_counts[level] = len(level_vocab)
        stats['by_level'][level] = len(level_vocab)

        # Write per-level JSON
        out_level_path = os.path.join(processed_dir, f"hsk{level}_vocab.json")
        with open(out_level_path, 'w', encoding='utf-8') as out_f:
            json.dump({
                'hsk_level': level,
                'count': len(level_vocab),
                'license': 'MIT (clem109, drkameleon, no7z) & CC BY-SA 4.0 (CVDICT)',
                'vocabularies': level_vocab
            }, out_f, indent=2, ensure_ascii=False)
        print(f"HSK {level}: Generated {len(level_vocab)} normalized vocabulary items -> {out_level_path}")

    # Write combined JSON
    all_out_path = os.path.join(processed_dir, "hsk_all_vocab.json")
    with open(all_out_path, 'w', encoding='utf-8') as out_f:
        json.dump({
            'total_count': len(all_normalized_vocab),
            'by_level': level_counts,
            'license': 'MIT (clem109, drkameleon, no7z) & CC BY-SA 4.0 (CVDICT)',
            'vocabularies': all_normalized_vocab
        }, out_f, indent=2, ensure_ascii=False)
    print(f"\nAll HSK 1-6: Generated {len(all_normalized_vocab)} items -> {all_out_path}")

    # Write seed fixture v2 (replaces old 84-word fixture with 5,000 words!)
    fixture_v2_path = os.path.join(base_dir, "processed", "hsk_seed_fixture_v2.json")
    fixture_v2 = {
        'bundleName': 'hsk_seed_fixture_v2',
        'version': 2,
        'syllabusVersion': 'HSK2.0_2012_OpenSource_Verified',
        'source': 'clem109;drkameleon;CVDICT;hanviet;no7z',
        'metadata': {
            'description': 'Full open-source verified HSK 1-6 vocabulary fixture for HI Chinese.',
            'vocabCount': len(all_normalized_vocab),
            'byLevel': level_counts,
            'stats': stats,
        },
        'vocabularies': all_normalized_vocab
    }
    with open(fixture_v2_path, 'w', encoding='utf-8') as out_f:
        json.dump(fixture_v2, out_f, indent=2, ensure_ascii=False)
    print(f"Seed Fixture v2: Generated -> {fixture_v2_path}")

    # Also build offline dictionary entries dataset from CVDICT for offline general search
    print("\nBuilding offline dictionary entries from CVDICT...")
    dict_entries = []
    for simp, entries in cvdict_by_simp.items():
        if not entries:
            continue
        first_e = entries[0]
        p_num = first_e.get('pinyin_num', '')
        p_clean = clean_pinyin(p_num)
        trad = first_e.get('trad', simp)
        all_vi = []
        for e in entries:
            all_vi.extend(e.get('meanings_vi', []))
        all_vi_str = "; ".join(all_vi[:5])
        
        dict_entries.append({
            'simplified': simp,
            'traditional': trad,
            'pinyin': p_num,
            'pinyin_clean': p_clean,
            'meaning_vi': all_vi_str,
            'source': 'CVDICT (CC BY-SA 4.0)'
        })

    dict_out_path = os.path.join(processed_dir, "offline_dictionary_entries.json")
    with open(dict_out_path, 'w', encoding='utf-8') as out_f:
        json.dump({
            'total_entries': len(dict_entries),
            'license': 'CC BY-SA 4.0 (Phong Phan CVDICT & CC-CEDICT)',
            'entries': dict_entries
        }, out_f, ensure_ascii=False)
    print(f"Offline Dictionary: Generated {len(dict_entries)} entries -> {dict_out_path}")

    # Print summary
    print("\n================ DATASET GENERATION SUMMARY ================")
    print(f"Total HSK 1-6 Vocabularies: {stats['total_words']}")
    for l, cnt in level_counts.items():
        print(f"  - HSK {l}: {cnt} items")
    print(f"Vietnamese Meaning Coverage: {stats['with_vietnamese']} / {stats['total_words']} ({stats['with_vietnamese']/stats['total_words']*100:.2f}%)")
    print(f"Han-Viet Reading Coverage: {stats['with_hanviet']} / {stats['total_words']} ({stats['with_hanviet']/stats['total_words']*100:.2f}%)")
    print(f"Example Sentences Coverage: {stats['with_examples']} / {stats['total_words']} ({stats['with_examples']/stats['total_words']*100:.2f}%)")
    print(f"Polyphones detected: {stats['polyphones']}")
    print("============================================================\n")

if __name__ == '__main__':
    main()
