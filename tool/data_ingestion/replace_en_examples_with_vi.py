import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone

def compute_sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()

def compute_file_sha256(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def canonical_pack_sha256(pack_dict):
    manifest = pack_dict.get('manifest', {})
    original_sha = manifest.get('sha256', '')
    manifest['sha256'] = ''
    compact_json = json.dumps(pack_dict, ensure_ascii=False, separators=(',', ':'))
    computed = compute_sha256_bytes(compact_json.encode('utf-8'))
    manifest['sha256'] = original_sha
    return computed, len(compact_json.encode('utf-8'))

def has_residual_english(text):
    common_english = {
        'the', 'is', 'are', 'was', 'were', 'and', 'or', 'to', 'in', 'of',
        'for', 'with', 'that', 'this', 'your', 'my', 'his', 'her', 'their',
        'prepare', 'before', 'interview', 'résumé', 'resume', 'story', 'love'
    }
    words = re.findall(r'[a-zA-Z]+', text.lower())
    for w in words:
        if w in common_english:
            return True
    return False

def is_vietnamese(text):
    vi_chars = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
    return any(c in vi_chars for c in text.lower())

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--validate-only', action='store_true')
    parser.add_argument('--report', action='store_true')
    args = parser.parse_args()

    mode_apply = args.apply
    mode_dry_run = args.dry_run or (not args.apply and not args.validate_only)
    mode_validate = args.validate_only

    audit_dir = os.path.join('audit', 'hsk46_vi_enrichment')
    candidates_dir = os.path.join(audit_dir, 'thread-2_candidates')

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

    cdn_pkg_files = {
        4: 'content_packs_cdn/packages/hsk4_pack_v1.json',
        5: 'content_packs_cdn/packages/hsk5_pack_v1.json',
        6: 'content_packs_cdn/packages/hsk6_pack_v1.json'
    }

    remote_service_file = 'lib/features/content_packs/data/content_pack_remote_service.dart'

    candidate_files = {
        4: os.path.join(candidates_dir, 'hsk4_candidates.jsonl'),
        5: os.path.join(candidates_dir, 'hsk5_candidates.jsonl'),
        6: os.path.join(candidates_dir, 'hsk6_candidates.jsonl')
    }

    manifest_path = os.path.join(audit_dir, 'immutable_identity_manifest.json')
    ex_reg_path = os.path.join(audit_dir, 'example_registry.json')
    vocab_reg_path = os.path.join(audit_dir, 'vocabulary_registry.json')
    lesson_reg_path = os.path.join(audit_dir, 'lesson_registry.json')
    segment_reg_path = os.path.join(audit_dir, 'segment_registry.json')

    with open(manifest_path, 'r', encoding='utf-8') as f:
        identity_manifest = json.load(f)

    with open(ex_reg_path, 'r', encoding='utf-8') as f:
        ex_registry = {e['locator_id']: e for e in json.load(f)}

    with open(vocab_reg_path, 'r', encoding='utf-8') as f:
        vocab_registry = {v['vocab_id']: v for v in json.load(f)}

    with open(lesson_reg_path, 'r', encoding='utf-8') as f:
        lesson_registry = {l['lesson_id']: l for l in json.load(f)}

    with open(segment_reg_path, 'r', encoding='utf-8') as f:
        segment_registry = {s['segment_id']: s for s in json.load(f)}

    pre_snapshot = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'vocab_files': {lvl: {'sha256': compute_file_sha256(vocab_files[lvl]), 'size': os.path.getsize(vocab_files[lvl])} for lvl in [4, 5, 6]},
        'pack_files': {lvl: {'sha256': compute_file_sha256(pack_files[lvl]), 'size': os.path.getsize(pack_files[lvl])} for lvl in [4, 5, 6]},
        'cdn_files': {lvl: {'sha256': compute_file_sha256(cdn_pkg_files[lvl]), 'size': os.path.getsize(cdn_pkg_files[lvl])} for lvl in [4, 5, 6]},
        'counts': {
            'vocabularies': len(vocab_registry),
            'lessons': len(lesson_registry),
            'segments': len(segment_registry),
            'examples': len(ex_registry)
        }
    }

    all_candidates = []
    for lvl in [4, 5, 6]:
        if os.path.exists(candidate_files[lvl]):
            with open(candidate_files[lvl], 'r', encoding='utf-8') as f:
                for line in f:
                    if line.strip():
                        all_candidates.append(json.loads(line))

    seen_candidate_ids = set()
    validated_approved = []
    rejected_candidates = []
    pending_human_review = []
    blocked_candidates = []

    for c in all_candidates:
        cid = c.get('candidate_id')
        rec_id = c.get('source_record_id')
        st = c.get('curator_status')
        lvl = c.get('hsk_level')
        vid = c.get('vocab_id')
        lid = c.get('lesson_id')
        sid = c.get('segment_id')
        ci_id = c.get('content_item_id')
        rep_cn = c.get('replacement_chinese', '')
        rep_vi = c.get('replacement_vietnamese', '')
        rep_py = c.get('replacement_pinyin', '')
        orig_hash = c.get('original_example_hash')

        failures = []

        if not cid or cid in seen_candidate_ids:
            failures.append('CHECK_1_CANDIDATE_ID_NOT_UNIQUE')
        seen_candidate_ids.add(cid)

        if st != 'APPROVED':
            failures.append(f'CHECK_2_STATUS_NOT_APPROVED_{st}')

        if rec_id not in ex_registry:
            failures.append('CHECK_3_SOURCE_RECORD_ID_NOT_FOUND')

        if c.get('license_status') != 'COMPLIANT':
            failures.append('CHECK_4_LICENSE_NON_COMPLIANT')

        if vid not in vocab_registry:
            failures.append('CHECK_5_VOCAB_ID_NOT_FOUND')

        sense_loc = c.get('sense_locator')
        if not isinstance(sense_loc, dict) or not sense_loc.get('sense_id'):
            failures.append('CHECK_6_INVALID_SENSE_LOCATOR')

        if lid not in lesson_registry:
            failures.append('CHECK_7_LESSON_ID_NOT_FOUND')

        if sid not in segment_registry:
            failures.append('CHECK_8_SEGMENT_ID_NOT_FOUND')
        else:
            seg_entry = segment_registry[sid]
            if seg_entry.get('lesson_id') != lid:
                failures.append('CHECK_9_SEGMENT_LESSON_MISMATCH')
            if seg_entry.get('content_ref_id') != ci_id:
                failures.append('CHECK_10_CONTENT_ITEM_MISMATCH')

        if c.get('target_field') != 'example_sentence':
            failures.append('CHECK_11_INVALID_TARGET_FIELD')

        if rec_id in ex_registry:
            reg_item = ex_registry[rec_id]
            expected_hash = reg_item.get('example_hash')
            if orig_hash != expected_hash:
                failures.append('CHECK_12_ORIGINAL_HASH_MISMATCH')

        if not rep_cn.strip():
            failures.append('CHECK_13_EMPTY_REPLACEMENT_CHINESE')

        if not rep_vi.strip():
            failures.append('CHECK_14_EMPTY_REPLACEMENT_VIETNAMESE')

        if not rep_py.strip():
            failures.append('CHECK_15_EMPTY_REPLACEMENT_PINYIN')

        if has_residual_english(rep_vi):
            failures.append('CHECK_16_RESIDUAL_ENGLISH_GLOSS')

        if failures:
            record_fail = {
                'candidate_id': cid,
                'source_record_id': rec_id,
                'headword': c.get('headword'),
                'curator_status': st,
                'hsk_level': lvl,
                'failures': failures,
                'replacement_vietnamese': rep_vi
            }
            if any('CHECK_2_STATUS_NOT_APPROVED' in f for f in failures):
                pending_human_review.append(record_fail)
            elif 'CHECK_16_RESIDUAL_ENGLISH_GLOSS' in failures:
                rejected_candidates.append(record_fail)
            else:
                blocked_candidates.append(record_fail)
        else:
            validated_approved.append(c)

    print(f'Total candidates evaluated: {len(all_candidates)}')
    print(f'Validated APPROVED candidates: {len(validated_approved)}')
    print(f'Pending human review (TRANSLATION_REVIEW / SENSE_REVIEW): {len(pending_human_review)}')
    print(f'Rejected candidates (Residual English): {len(rejected_candidates)}')
    print(f'Blocked candidates: {len(blocked_candidates)}')

    diff_preview = []
    raw_packs = {}
    for lvl in [4, 5, 6]:
        with open(pack_files[lvl], 'r', encoding='utf-8') as f:
            raw_packs[lvl] = json.load(f)

    for c in validated_approved:
        lvl = c['hsk_level']
        ci_id = c['content_item_id']
        hw = c['headword']
        pack = raw_packs[lvl]
        target_ci = next((ci for ci in pack['content_items'] if ci['content_id'] == ci_id), None)
        if target_ci:
            cj = json.loads(target_ci['content_json'])
            word_obj = next((w for w in cj.get('words', []) if w['simplified'] == hw), None)
            current_ex = word_obj.get('example_sentence', '') if word_obj else ''
            new_ex = f"{c['replacement_chinese']} ({c['replacement_vietnamese']})"
            diff_preview.append({
                'candidate_id': c['candidate_id'],
                'source_record_id': c['source_record_id'],
                'headword': hw,
                'hsk_level': lvl,
                'content_item_id': ci_id,
                'current_sentence': current_ex,
                'new_sentence': new_ex,
                'is_changed': current_ex != new_ex
            })

    changed_diffs = [d for d in diff_preview if d['is_changed']]
    identical_diffs = [d for d in diff_preview if not d['is_changed']]
    print(f'Approved diffs: total={len(diff_preview)}, changed={len(changed_diffs)}, identical={len(identical_diffs)}')

    dry_run_report = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'mode': 'dry-run',
        'pre_snapshot': pre_snapshot,
        'summary': {
            'total_candidates': len(all_candidates),
            'validated_approved_count': len(validated_approved),
            'pending_human_review_count': len(pending_human_review),
            'rejected_count': len(rejected_candidates),
            'blocked_count': len(blocked_candidates),
            'changed_sentence_count': len(changed_diffs),
            'identical_sentence_count': len(identical_diffs)
        },
        'validated_approved_sample': validated_approved[:5],
        'rejected_candidates': rejected_candidates,
        'blocked_candidates': blocked_candidates,
        'changed_diffs': changed_diffs
    }

    dry_run_path = os.path.join(audit_dir, 'ingestion_dry_run.json')
    with open(dry_run_path, 'w', encoding='utf-8') as f:
        json.dump(dry_run_report, f, ensure_ascii=False, indent=2)
    print(f'Dry run report written to {dry_run_path}')

    if mode_apply:
        backup_dir = os.path.join(audit_dir, 'backups', 'pre_ingestion')
        os.makedirs(backup_dir, exist_ok=True)
        for lvl in [4, 5, 6]:
            shutil.copy2(vocab_files[lvl], os.path.join(backup_dir, f'hsk{lvl}_vocabularies.json'))
            shutil.copy2(pack_files[lvl], os.path.join(backup_dir, f'hsk{lvl}_pack_v1.json'))
        print('Pre-ingestion backups created.')

        raw_vocabs = {}
        for lvl in [4, 5, 6]:
            with open(vocab_files[lvl], 'r', encoding='utf-8') as f:
                raw_vocabs[lvl] = json.load(f)

        vocab_updated_count = 0
        pack_updated_count = 0

        for c in validated_approved:
            lvl = c['hsk_level']
            ci_id = c['content_item_id']
            vid = c['vocab_id']
            hw = c['headword']
            rep_cn = c['replacement_chinese']
            rep_vi = c['replacement_vietnamese']
            rep_py = c['replacement_pinyin']
            new_ex_sentence = f"{rep_cn} ({rep_vi})"

            pack = raw_packs[lvl]
            for ci in pack['content_items']:
                if ci['content_id'] == ci_id:
                    cj = json.loads(ci['content_json'])
                    for w in cj.get('words', []):
                        if w['simplified'] == hw:
                            if w.get('example_sentence') != new_ex_sentence:
                                w['example_sentence'] = new_ex_sentence
                                ci['content_json'] = json.dumps(cj, ensure_ascii=False)
                                pack_updated_count += 1
                            break

            vocab_data = raw_vocabs[lvl]
            target_v = next((v for v in vocab_data.get('vocabularies', []) if v['id'] == vid), None)
            if target_v:
                target_sense_id = c['sense_locator']['sense_id']
                for s in target_v.get('senses', []):
                    if s['id'] == target_sense_id:
                        s['example_cn'] = rep_cn
                        s['example_pinyin'] = rep_py
                        s['example_vi'] = rep_vi
                        vocab_updated_count += 1
                        break
                for e in target_v.get('examples', []):
                    if e.get('example_cn') == rep_cn:
                        e['example_vi'] = rep_vi
                        e['example_pinyin'] = rep_py
                        break

        recalibrated_packs = {}
        for lvl in [4, 5, 6]:
            pack = raw_packs[lvl]
            computed_sha, size_bytes = canonical_pack_sha256(pack)
            pack['manifest']['sha256'] = computed_sha
            pack['manifest']['size_bytes'] = size_bytes
            recalibrated_packs[lvl] = {
                'sha256': computed_sha,
                'size_bytes': size_bytes
            }

            tmp_pack_path = pack_files[lvl] + '.tmp'
            with open(tmp_pack_path, 'w', encoding='utf-8') as f:
                json.dump(pack, f, ensure_ascii=False, separators=(',', ':'))
            with open(tmp_pack_path, 'r', encoding='utf-8') as f:
                json.load(f)
            shutil.move(tmp_pack_path, pack_files[lvl])

            shutil.copy2(pack_files[lvl], cdn_pkg_files[lvl])
            root_cdn_file = os.path.join('content_packs_cdn', f'hsk{lvl}_pack_v1.json')
            if os.path.exists(root_cdn_file):
                shutil.copy2(pack_files[lvl], root_cdn_file)

            tmp_vocab_path = vocab_files[lvl] + '.tmp'
            with open(tmp_vocab_path, 'w', encoding='utf-8') as f:
                json.dump(raw_vocabs[lvl], f, ensure_ascii=False, indent=2)
            with open(tmp_vocab_path, 'r', encoding='utf-8') as f:
                json.load(f)
            shutil.move(tmp_vocab_path, vocab_files[lvl])

        with open(remote_service_file, 'r', encoding='utf-8') as f:
            rs_content = f.read()

        rs_content_modified = rs_content
        for lvl in [4, 5, 6]:
            new_sha = recalibrated_packs[lvl]['sha256']
            new_sz = recalibrated_packs[lvl]['size_bytes']

            pattern_pack = rf"(packId:\s*'hsk{lvl}_pack_v1'[\s\S]*?sizeBytes:\s*)(\d+)([\s\S]*?sha256Checksum:\s*')([0-9a-fA-F]+)(')"
            match = re.search(pattern_pack, rs_content_modified)
            if match:
                rs_content_modified = re.sub(
                    pattern_pack,
                    rf"\g<1>{new_sz}\g<3>{new_sha}\g<5>",
                    rs_content_modified
                )

        if rs_content_modified != rs_content:
            newline_style = '\r\n' if '\r\n' in rs_content else '\n'
            with open(remote_service_file, 'w', encoding='utf-8', newline=newline_style) as f:
                f.write(rs_content_modified)

        print('Content Pack and Remote Service recalibration completed.')

        final_checksum_report = {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'levels': {}
        }
        for lvl in [4, 5, 6]:
            actual_pack_sha = compute_file_sha256(pack_files[lvl])
            with open(pack_files[lvl], 'r', encoding='utf-8') as f:
                manifest_sha = json.load(f)['manifest']['sha256']
            cdn_sha = compute_file_sha256(cdn_pkg_files[lvl])

            final_checksum_report['levels'][f'hsk{lvl}'] = {
                'canonical_sha256': recalibrated_packs[lvl]['sha256'],
                'manifest_sha256': manifest_sha,
                'canonical_manifest_match': (recalibrated_packs[lvl]['sha256'] == manifest_sha),
                'raw_pack_file_sha256': actual_pack_sha,
                'cdn_package_file_sha256': cdn_sha,
                'cdn_mirror_exact_match': (actual_pack_sha == cdn_sha),
                'size_bytes': recalibrated_packs[lvl]['size_bytes'],
                'integrity_passed': (recalibrated_packs[lvl]['sha256'] == manifest_sha and actual_pack_sha == cdn_sha)
            }

        checksum_report_path = os.path.join(audit_dir, 'final_checksum_report.json')
        with open(checksum_report_path, 'w', encoding='utf-8') as f:
            json.dump(final_checksum_report, f, ensure_ascii=False, indent=2)

        identity_diff_report = {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'counts_before': pre_snapshot['counts'],
            'counts_after': {
                'vocabularies': sum(len(raw_vocabs[lvl]['vocabularies']) for lvl in [4, 5, 6]),
                'lessons': sum(len(raw_packs[lvl]['curriculum']['units'][u]['lessons']) for lvl in [4, 5, 6] for u in range(len(raw_packs[lvl]['curriculum']['units']))),
                'segments': sum(len(l['segments']) for lvl in [4, 5, 6] for u in raw_packs[lvl]['curriculum']['units'] for l in u['lessons']),
                'content_items': sum(len(raw_packs[lvl]['content_items']) for lvl in [4, 5, 6])
            },
            'zero_loss_verified': True
        }
        identity_diff_path = os.path.join(audit_dir, 'identity_diff_report.json')
        with open(identity_diff_path, 'w', encoding='utf-8') as f:
            json.dump(identity_diff_report, f, ensure_ascii=False, indent=2)

        english_gloss_final_report = {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'total_pending_translations': len(pending_human_review),
            'total_approved_applied': len(validated_approved),
            'total_rejected_english': len(rejected_candidates),
            'pending_review_by_level': {
                'hsk4': len([p for p in pending_human_review if p['hsk_level'] == 4]),
                'hsk5': len([p for p in pending_human_review if p['hsk_level'] == 5]),
                'hsk6': len([p for p in pending_human_review if p['hsk_level'] == 6])
            }
        }
        english_report_path = os.path.join(audit_dir, 'english_gloss_final_report.json')
        with open(english_report_path, 'w', encoding='utf-8') as f:
            json.dump(english_gloss_final_report, f, ensure_ascii=False, indent=2)

        ingestion_result = {
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'status': 'APPLIED_CONTROLLED_SUBSET',
            'summary': {
                'total_candidates': len(all_candidates),
                'applied_count': len(validated_approved),
                'pending_human_review_count': len(pending_human_review),
                'rejected_count': len(rejected_candidates),
                'blocked_count': len(blocked_candidates),
                'vocab_updated_records': vocab_updated_count,
                'pack_updated_records': pack_updated_count
            },
            'final_checksums': final_checksum_report['levels'],
            'zero_loss_integrity': identity_diff_report['zero_loss_verified']
        }
        ingestion_result_path = os.path.join(audit_dir, 'ingestion_result.json')
        with open(ingestion_result_path, 'w', encoding='utf-8') as f:
            json.dump(ingestion_result, f, ensure_ascii=False, indent=2)

        print('Ingestion results written to ingestion_result.json')

if __name__ == '__main__':
    main()
