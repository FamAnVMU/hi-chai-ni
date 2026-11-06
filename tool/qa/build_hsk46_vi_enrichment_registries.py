import json
import hashlib
import os
from datetime import datetime, timezone
from collections import Counter

def compute_sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()

def compute_file_sha256(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def is_vietnamese(text):
    vi_chars = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
    return any(c in vi_chars for c in text.lower())

def main():
    out_dir = os.path.join('audit', 'hsk46_vi_enrichment')
    os.makedirs(out_dir, exist_ok=True)

    vocab_files = {
        4: 'assets/data/hsk4_vocabularies.json',
        5: 'assets/data/hsk5_vocabularies.json',
        6: 'assets/data/hsk6_vocabularies.json'
    }

    pack_files = {
        4: 'assets/data/content_packs/hsk4/hsk4_pack_v1.json',
        5: 'assets/data/content_packs/hsk5/hsk5_pack_v1.json',
        6: 'assets/data/content_packs/hsk6/hsk6_pack_v1.json'
    }

    raw_vocab_data = {}
    vocab_registry = []
    vocab_by_level_simplified = {}
    vocab_by_id = {}

    for lvl in [4, 5, 6]:
        with open(vocab_files[lvl], 'r', encoding='utf-8') as f:
            data = json.load(f)
        raw_vocab_data[lvl] = data
        vocab_by_level_simplified[lvl] = {}
        for v in data['vocabularies']:
            vid = v['id']
            simp = v['simplified']
            vocab_by_id[vid] = v
            vocab_by_level_simplified[lvl].setdefault(simp, []).append(v)

            senses_out = []
            for s_idx, s in enumerate(v.get('senses', [])):
                senses_out.append({
                    'sense_id': s['id'],
                    'index': s.get('order_index', s_idx + 1),
                    'part_of_speech': s.get('part_of_speech', ''),
                    'meaning_vi': s.get('meaning_vi', ''),
                    'meaning_en': s.get('meaning_en', '')
                })

            examples_out = []
            for e_idx, e in enumerate(v.get('examples', [])):
                examples_out.append({
                    'example_id': e['id'],
                    'index': e.get('order_index', e_idx + 1),
                    'example_cn': e.get('example_cn', ''),
                    'example_pinyin': e.get('example_pinyin', ''),
                    'example_en': e.get('example_en', ''),
                    'example_vi': e.get('example_vi'),
                    'audio_uri': e.get('audio_uri', '')
                })

            reg_entry = {
                'vocab_id': vid,
                'canonical_id': v.get('canonical_id', ''),
                'hsk_level': lvl,
                'canonical_headword': simp,
                'traditional': v.get('traditional', ''),
                'pinyin': v.get('pinyin', ''),
                'pinyin_clean': v.get('pinyin_clean', ''),
                'hanviet': v.get('hanviet', ''),
                'file_path': vocab_files[lvl].replace('\\', '/'),
                'sense_count': len(senses_out),
                'senses': senses_out,
                'example_count': len(examples_out),
                'examples': examples_out
            }
            vocab_registry.append(reg_entry)

    lesson_registry = []
    segment_registry = []
    example_registry = []
    english_gloss_report = []
    missing_examples_report = {
        'metadata': {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'total_no_example': 0,
            'total_empty_parentheses': 0,
            'total_omitted_standalone': 0
        },
        'category_1_no_example_at_all': [],
        'category_2_empty_parentheses': [],
        'category_3_standalone_omitted_from_lessons': []
    }
    ambiguous_mapping_report = {
        'metadata': {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'total_ambiguous_polyphones': 3,
            'total_occurrences_in_pack': 6
        },
        'polyphones_hsk4': [],
        'multi_sense_words': []
    }

    raw_pack_data = {}
    for lvl in [4, 5, 6]:
        with open(pack_files[lvl], 'r', encoding='utf-8') as f:
            pack = json.load(f)
        raw_pack_data[lvl] = pack

        content_items_map = {ci['content_id']: ci for ci in pack.get('content_items', [])}

        for unit in pack['curriculum']['units']:
            u_id = unit['id']
            for l in unit['lessons']:
                l_id = l['id']
                lesson_registry.append({
                    'lesson_id': l_id,
                    'hsk_level': lvl,
                    'unit_id': u_id,
                    'order_index': l['order_index'],
                    'title_vi': l['title_vi'],
                    'title_zh': l['title_zh'],
                    'pinyin': l.get('pinyin', ''),
                    'estimated_minutes': l.get('estimated_minutes', 45),
                    'file_path': pack_files[lvl].replace('\\', '/'),
                    'segment_count': len(l.get('segments', [])),
                    'status': 'active'
                })

                for seg in l.get('segments', []):
                    seg_id = seg['id']
                    ref_id = seg['content_ref_id']
                    stype = seg['segment_type']

                    segment_registry.append({
                        'segment_id': seg_id,
                        'lesson_id': l_id,
                        'unit_id': u_id,
                        'hsk_level': lvl,
                        'segment_type': stype,
                        'step_order': seg['step_order'],
                        'title': seg['title'],
                        'content_ref_id': ref_id,
                        'file_path': pack_files[lvl].replace('\\', '/'),
                        'content_json_path': f"content_items[content_id={ref_id}].content_json"
                    })

                    if stype == 'vocabulary' and ref_id in content_items_map:
                        ci = content_items_map[ref_id]
                        cj = json.loads(ci['content_json'])
                        words = cj.get('words', [])

                        for w_idx, w in enumerate(words):
                            simp = w['simplified']
                            full_ex = w.get('example_sentence', '')

                            ex_cn = ''
                            gloss = None
                            gloss_type = 'missing_example'

                            if not full_ex:
                                gloss_type = 'missing_example'
                            elif full_ex.endswith(' ()'):
                                ex_cn = full_ex[:-3]
                                gloss = ''
                                gloss_type = 'empty_parentheses'
                            elif ' (' in full_ex and full_ex.endswith(')'):
                                split_idx = full_ex.rfind(' (')
                                ex_cn = full_ex[:split_idx]
                                gloss = full_ex[split_idx + 2:-1]
                                if is_vietnamese(gloss):
                                    gloss_type = 'vietnamese'
                                else:
                                    gloss_type = 'english'
                            else:
                                ex_cn = full_ex
                                gloss = None
                                gloss_type = 'no_gloss'

                            matched_v_candidates = vocab_by_level_simplified.get(lvl, {}).get(simp, [])

                            matched_v = None
                            matched_sense = None
                            matched_example = None
                            mapping_status = 'EXACT_MATCH'

                            if len(matched_v_candidates) == 1:
                                matched_v = matched_v_candidates[0]
                                if matched_v.get('senses'):
                                    matched_sense = matched_v['senses'][0]
                                for e in matched_v.get('examples', []):
                                    if e.get('example_cn') == ex_cn:
                                        matched_example = e
                                        break
                                if not matched_example and matched_v.get('examples'):
                                    matched_example = matched_v['examples'][0]
                            elif len(matched_v_candidates) > 1:
                                mapping_status = 'AMBIGUOUS_MAPPING'
                                for cand in matched_v_candidates:
                                    for e in cand.get('examples', []):
                                        if e.get('example_cn') == ex_cn:
                                            matched_v = cand
                                            matched_example = e
                                            break
                                    if matched_v:
                                        break
                                if not matched_v:
                                    matched_v = matched_v_candidates[0]
                                if matched_v.get('senses'):
                                    matched_sense = matched_v['senses'][0]
                            else:
                                mapping_status = 'UNMATCHED_VOCAB'

                            if gloss_type == 'missing_example':
                                mapping_status = 'MISSING_EXAMPLE'

                            ex_hash = compute_sha256_bytes(ex_cn.encode('utf-8')) if ex_cn else None
                            full_hash = compute_sha256_bytes(full_ex.encode('utf-8')) if full_ex else None

                            locator_id = f"LOC_HSK{lvl}_{l_id}_{seg_id}_{simp}_{w_idx}"

                            ex_entry = {
                                'locator_id': locator_id,
                                'hsk_level': lvl,
                                'lesson_id': l_id,
                                'unit_id': u_id,
                                'segment_id': seg_id,
                                'content_item_id': ref_id,
                                'word_index': w_idx,
                                'word_simplified': simp,
                                'pinyin': w.get('pinyin', ''),
                                'meaning_vi': w.get('meaning_vi', ''),
                                'part_of_speech': w.get('part_of_speech', ''),
                                'original_example_sentence': full_ex,
                                'example_cn': ex_cn,
                                'original_gloss': gloss,
                                'gloss_type': gloss_type,
                                'vocab_id': matched_v['id'] if matched_v else None,
                                'sense_id': matched_sense['id'] if matched_sense else None,
                                'example_id': matched_example['id'] if matched_example else None,
                                'example_hash': ex_hash,
                                'full_sentence_hash': full_hash,
                                'mapping_status': mapping_status,
                                'source_file': pack_files[lvl].replace('\\', '/'),
                                'standalone_file': vocab_files[lvl].replace('\\', '/')
                            }
                            example_registry.append(ex_entry)

                            if gloss_type == 'english':
                                english_gloss_report.append({
                                    'locator_id': locator_id,
                                    'hsk_level': lvl,
                                    'lesson_id': l_id,
                                    'segment_id': seg_id,
                                    'content_item_id': ref_id,
                                    'word_simplified': simp,
                                    'vocab_id': matched_v['id'] if matched_v else None,
                                    'sense_id': matched_sense['id'] if matched_sense else None,
                                    'example_id': matched_example['id'] if matched_example else None,
                                    'example_cn': ex_cn,
                                    'english_gloss': gloss,
                                    'example_hash': ex_hash
                                })
                            elif gloss_type == 'missing_example':
                                missing_examples_report['category_1_no_example_at_all'].append({
                                    'locator_id': locator_id,
                                    'hsk_level': lvl,
                                    'lesson_id': l_id,
                                    'segment_id': seg_id,
                                    'content_item_id': ref_id,
                                    'word_simplified': simp,
                                    'vocab_id': matched_v['id'] if matched_v else None,
                                    'sense_id': matched_sense['id'] if matched_sense else None
                                })
                            elif gloss_type == 'empty_parentheses':
                                missing_examples_report['category_2_empty_parentheses'].append({
                                    'locator_id': locator_id,
                                    'hsk_level': lvl,
                                    'lesson_id': l_id,
                                    'segment_id': seg_id,
                                    'content_item_id': ref_id,
                                    'word_simplified': simp,
                                    'vocab_id': matched_v['id'] if matched_v else None,
                                    'sense_id': matched_sense['id'] if matched_sense else None,
                                    'example_cn': ex_cn,
                                    'example_hash': ex_hash
                                })

    omitted_words = {
        4: ['作者'],
        5: ['遵守', '作为', '作品', '作文'],
        6: []
    }
    for lvl, words in omitted_words.items():
        for simp in words:
            v_list = vocab_by_level_simplified.get(lvl, {}).get(simp, [])
            for v in v_list:
                missing_examples_report['category_3_standalone_omitted_from_lessons'].append({
                    'hsk_level': lvl,
                    'word_simplified': simp,
                    'vocab_id': v['id'],
                    'canonical_id': v.get('canonical_id', ''),
                    'file_path': vocab_files[lvl].replace('\\', '/'),
                    'sense_count': len(v.get('senses', [])),
                    'example_count': len(v.get('examples', [])),
                    'examples': v.get('examples', [])
                })

    missing_examples_report['metadata']['total_no_example'] = len(missing_examples_report['category_1_no_example_at_all'])
    missing_examples_report['metadata']['total_empty_parentheses'] = len(missing_examples_report['category_2_empty_parentheses'])
    missing_examples_report['metadata']['total_omitted_standalone'] = len(missing_examples_report['category_3_standalone_omitted_from_lessons'])

    for simp in ['等', '对', '过']:
        v_list = vocab_by_level_simplified[4].get(simp, [])
        pack_occurrences = [e for e in example_registry if e['hsk_level'] == 4 and e['word_simplified'] == simp]
        ambiguous_mapping_report['polyphones_hsk4'].append({
            'headword': simp,
            'standalone_entries': [
                {
                    'vocab_id': v['id'],
                    'pinyin': v.get('pinyin', ''),
                    'senses': v.get('senses', []),
                    'examples': v.get('examples', [])
                }
                for v in v_list
            ],
            'content_pack_occurrences': [
                {
                    'locator_id': occ['locator_id'],
                    'lesson_id': occ['lesson_id'],
                    'segment_id': occ['segment_id'],
                    'word_index': occ['word_index'],
                    'meaning_vi': occ['meaning_vi'],
                    'example_sentence': occ['original_example_sentence']
                }
                for occ in pack_occurrences
            ]
        })

    for v in vocab_registry:
        if v['sense_count'] > 1:
            ambiguous_mapping_report['multi_sense_words'].append({
                'vocab_id': v['vocab_id'],
                'hsk_level': v['hsk_level'],
                'headword': v['canonical_headword'],
                'sense_count': v['sense_count'],
                'senses': v['senses']
            })

    path_vocab_reg = os.path.join(out_dir, 'vocabulary_registry.json')
    path_lesson_reg = os.path.join(out_dir, 'lesson_registry.json')
    path_segment_reg = os.path.join(out_dir, 'segment_registry.json')
    path_example_reg = os.path.join(out_dir, 'example_registry.json')
    path_english_report = os.path.join(out_dir, 'english_gloss_report.json')
    path_missing_report = os.path.join(out_dir, 'missing_examples_report.json')
    path_ambiguous_report = os.path.join(out_dir, 'ambiguous_mapping_report.json')
    path_manifest = os.path.join(out_dir, 'immutable_identity_manifest.json')

    with open(path_vocab_reg, 'w', encoding='utf-8') as f:
        json.dump(vocab_registry, f, ensure_ascii=False, indent=2)

    with open(path_lesson_reg, 'w', encoding='utf-8') as f:
        json.dump(lesson_registry, f, ensure_ascii=False, indent=2)

    with open(path_segment_reg, 'w', encoding='utf-8') as f:
        json.dump(segment_registry, f, ensure_ascii=False, indent=2)

    with open(path_example_reg, 'w', encoding='utf-8') as f:
        json.dump(example_registry, f, ensure_ascii=False, indent=2)

    with open(path_english_report, 'w', encoding='utf-8') as f:
        json.dump(english_gloss_report, f, ensure_ascii=False, indent=2)

    with open(path_missing_report, 'w', encoding='utf-8') as f:
        json.dump(missing_examples_report, f, ensure_ascii=False, indent=2)

    with open(path_ambiguous_report, 'w', encoding='utf-8') as f:
        json.dump(ambiguous_mapping_report, f, ensure_ascii=False, indent=2)

    manifest_data = {
        'schema_version': '1.0.0',
        'task_id': 'CORE-HSK46-VI-001',
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'dataset_summary': {
            'total_standalone_vocabularies': len(vocab_registry),
            'standalone_by_level': {
                'hsk4': len([v for v in vocab_registry if v['hsk_level'] == 4]),
                'hsk5': len([v for v in vocab_registry if v['hsk_level'] == 5]),
                'hsk6': len([v for v in vocab_registry if v['hsk_level'] == 6])
            },
            'total_lessons': len(lesson_registry),
            'lessons_by_level': {
                'hsk4': len([l for l in lesson_registry if l['hsk_level'] == 4]),
                'hsk5': len([l for l in lesson_registry if l['hsk_level'] == 5]),
                'hsk6': len([l for l in lesson_registry if l['hsk_level'] == 6])
            },
            'total_segments': len(segment_registry),
            'segments_by_level': {
                'hsk4': len([s for s in segment_registry if s['hsk_level'] == 4]),
                'hsk5': len([s for s in segment_registry if s['hsk_level'] == 5]),
                'hsk6': len([s for s in segment_registry if s['hsk_level'] == 6])
            },
            'total_lesson_word_occurrences': len(example_registry),
            'lesson_words_by_level': {
                'hsk4': len([e for e in example_registry if e['hsk_level'] == 4]),
                'hsk5': len([e for e in example_registry if e['hsk_level'] == 5]),
                'hsk6': len([e for e in example_registry if e['hsk_level'] == 6])
            },
            'total_english_gloss_sentences': len(english_gloss_report),
            'english_gloss_by_level': {
                'hsk4': len([e for e in english_gloss_report if e['hsk_level'] == 4]),
                'hsk5': len([e for e in english_gloss_report if e['hsk_level'] == 5]),
                'hsk6': len([e for e in english_gloss_report if e['hsk_level'] == 6])
            },
            'total_missing_examples_at_all': len(missing_examples_report['category_1_no_example_at_all']),
            'missing_examples_by_level': {
                'hsk4': len([e for e in missing_examples_report['category_1_no_example_at_all'] if e['hsk_level'] == 4]),
                'hsk5': len([e for e in missing_examples_report['category_1_no_example_at_all'] if e['hsk_level'] == 5]),
                'hsk6': len([e for e in missing_examples_report['category_1_no_example_at_all'] if e['hsk_level'] == 6])
            },
            'total_empty_parentheses': len(missing_examples_report['category_2_empty_parentheses']),
            'empty_parentheses_by_level': {
                'hsk4': len([e for e in missing_examples_report['category_2_empty_parentheses'] if e['hsk_level'] == 4]),
                'hsk5': len([e for e in missing_examples_report['category_2_empty_parentheses'] if e['hsk_level'] == 5]),
                'hsk6': len([e for e in missing_examples_report['category_2_empty_parentheses'] if e['hsk_level'] == 6])
            },
            'total_standalone_omitted_words': len(missing_examples_report['category_3_standalone_omitted_from_lessons']),
            'total_multi_sense_words': len(ambiguous_mapping_report['multi_sense_words']),
            'multi_sense_by_level': {
                'hsk4': len([m for m in ambiguous_mapping_report['multi_sense_words'] if m['hsk_level'] == 4]),
                'hsk5': len([m for m in ambiguous_mapping_report['multi_sense_words'] if m['hsk_level'] == 5]),
                'hsk6': len([m for m in ambiguous_mapping_report['multi_sense_words'] if m['hsk_level'] == 6])
            }
        },
        'registries_sha256': {
            'vocabulary_registry.json': compute_file_sha256(path_vocab_reg),
            'lesson_registry.json': compute_file_sha256(path_lesson_reg),
            'segment_registry.json': compute_file_sha256(path_segment_reg),
            'example_registry.json': compute_file_sha256(path_example_reg),
            'english_gloss_report.json': compute_file_sha256(path_english_report),
            'missing_examples_report.json': compute_file_sha256(path_missing_report),
            'ambiguous_mapping_report.json': compute_file_sha256(path_ambiguous_report)
        },
        'production_content_packs_sha256': {
            'hsk4_pack_v1.json': raw_pack_data[4]['manifest']['sha256'],
            'hsk5_pack_v1.json': raw_pack_data[5]['manifest']['sha256'],
            'hsk6_pack_v1.json': raw_pack_data[6]['manifest']['sha256']
        }
    }

    with open(path_manifest, 'w', encoding='utf-8') as f:
        json.dump(manifest_data, f, ensure_ascii=False, indent=2)

    print('Registries built successfully!')
    print(f'vocabulary_registry: {len(vocab_registry)} items')
    print(f'lesson_registry: {len(lesson_registry)} items')
    print(f'segment_registry: {len(segment_registry)} items')
    print(f'example_registry: {len(example_registry)} items')
    print(f'english_gloss_report: {len(english_gloss_report)} items')
    missing_count = manifest_data['dataset_summary']['total_missing_examples_at_all']
    empty_count = manifest_data['dataset_summary']['total_empty_parentheses']
    print(f'missing_examples_report: {missing_count} items missing')
    print(f'empty_parentheses: {empty_count} items')
    print(f'manifest written with registry hashes')

if __name__ == '__main__':
    main()
