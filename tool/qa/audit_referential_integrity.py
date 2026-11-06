#!/usr/bin/env python3
"""Thread 5 – Referential integrity audit for HI Chinese content packs (HSK 1–6).

Read-only. Never modifies data. Exit code 1 when a CRITICAL check fails.

Checks:
  C1  Unit / lesson / segment IDs are globally unique across all packs.
  C2  content_items.content_id is globally unique across all packs (DB column is UNIQUE).
  C3  Every lesson segment content_ref_id resolves to an existing content_item.
  C4  Every content_item.curriculum_id equals its pack's curriculum id.
  C5  Every vocabulary entry (hsk4/5/6 asset files + seed fixture v2) has pinyin and meaning_vi.
  C6  Every word embedded in pack vocabulary content_json has simplified, pinyin, meaning_vi.
  C7  Exit exam questions: answer_index within options range.
  W1  (warning) Pack vocabulary example sentences whose gloss is English instead of Vietnamese.
  W2  (warning) Vocabulary assets without any example sentence.

Usage:  python tool/qa/audit_referential_integrity.py [--json out.json]
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKS = {lvl: ROOT / f"assets/data/content_packs/hsk{lvl}/hsk{lvl}_pack_v1.json" for lvl in range(1, 7)}
VOCAB_FILES = {lvl: ROOT / f"assets/data/hsk{lvl}_vocabularies.json" for lvl in (4, 5, 6)}
FIXTURE = ROOT / "assets/data/hsk_seed_fixture_v2.json"

VI_CHARS = re.compile(r"[ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]", re.I)
GLOSS = re.compile(r"\(([^()]*)\)\s*$")


def load(p: Path):
    with p.open(encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    results: dict[str, dict] = {}
    unit_ids, lesson_ids, seg_ids, content_ids = Counter(), Counter(), Counter(), Counter()
    all_content: set[str] = set()
    dangling, wrong_curr, bad_words, bad_exam = [], [], [], []
    english_gloss = Counter()
    pack_summary = {}

    packs = {lvl: load(p) for lvl, p in PACKS.items() if p.exists()}
    for lvl, pack in packs.items():
        curr = pack["curriculum"]
        cid = curr["id"]
        n_units = n_lessons = n_segs = 0
        for u in curr["units"]:
            unit_ids[u["id"]] += 1
            n_units += 1
            for les in u.get("lessons", []):
                lesson_ids[les["id"]] += 1
                n_lessons += 1
                for s in les.get("segments", []):
                    seg_ids[s["id"]] += 1
                    n_segs += 1
        for ci in pack["content_items"]:
            content_ids[ci["content_id"]] += 1
            all_content.add(ci["content_id"])
            if ci.get("curriculum_id") != cid:
                wrong_curr.append(f"hsk{lvl}:{ci['content_id']} -> {ci.get('curriculum_id')} (expected {cid})")
            if ci["knowledge_type"] == "vocabulary":
                words = json.loads(ci["content_json"]).get("words", [])
                for w in words:
                    missing = [k for k in ("simplified", "pinyin", "meaning_vi") if not str(w.get(k, "")).strip()]
                    if missing:
                        bad_words.append(f"hsk{lvl}:{ci['content_id']}:{w.get('simplified')} missing {missing}")
                    m = GLOSS.search(str(w.get("example_sentence", "")))
                    if m and re.search(r"[A-Za-z]", m.group(1)) and not VI_CHARS.search(m.group(1)):
                        english_gloss[lvl] += 1
        exam = pack.get("exit_exam") or {}
        questions = exam.get("questions")
        if questions is None and exam.get("exam_data_json"):
            data = json.loads(exam["exam_data_json"])
            questions = data.get("questions", []) if isinstance(data, dict) else data
        for q in questions or []:
            opts, idx = q.get("options"), q.get("answer_index")
            if opts is not None and idx is not None and not (0 <= int(idx) < len(opts)):
                bad_exam.append(f"hsk{lvl}:{q.get('id')} answer_index={idx} options={len(opts)}")
        pack_summary[f"hsk{lvl}"] = {
            "units": n_units, "lessons": n_lessons, "segments": n_segs,
            "content_items": len(pack["content_items"]), "exit_exam_questions": len(questions or []),
        }

    # C3 – dangling refs (second pass, all packs loaded)
    for lvl, pack in packs.items():
        for u in pack["curriculum"]["units"]:
            for les in u.get("lessons", []):
                for s in les.get("segments", []):
                    ref = s.get("content_ref_id")
                    if ref and ref not in all_content:
                        dangling.append(f"hsk{lvl}:{s['id']} -> {ref}")

    dup = lambda c: sorted(k for k, v in c.items() if v > 1)  # noqa: E731

    # C5 – vocabulary assets
    vocab_missing, vocab_no_example, vocab_counts = [], Counter(), {}
    sources = [(f"hsk{l}_vocabularies.json", load(p)["vocabularies"]) for l, p in VOCAB_FILES.items() if p.exists()]
    sources.append(("hsk_seed_fixture_v2.json", load(FIXTURE)["vocabularies"]))
    for name, vocabs in sources:
        vocab_counts[name] = len(vocabs)
        for v in vocabs:
            senses = v.get("senses") or []
            has_meaning = any(str(s.get("meaning_vi", "")).strip() for s in senses)
            missing = []
            if not str(v.get("pinyin", "")).strip():
                missing.append("pinyin")
            if not has_meaning:
                missing.append("meaning_vi")
            if missing:
                vocab_missing.append(f"{name}:{v.get('id')} missing {missing}")
            if name != "hsk_seed_fixture_v2.json" and not any(str(s.get("example_cn", "")).strip() for s in senses):
                vocab_no_example[name] += 1

    checks = {
        "C1_unique_unit_ids": dup(unit_ids),
        "C1_unique_lesson_ids": dup(lesson_ids),
        "C1_unique_segment_ids": dup(seg_ids),
        "C2_unique_content_ids": dup(content_ids),
        "C3_dangling_segment_refs": dangling,
        "C4_content_item_curriculum_mismatch": wrong_curr,
        "C5_vocab_missing_pinyin_or_meaning": vocab_missing,
        "C6_pack_words_missing_fields": bad_words,
        "C7_exit_exam_bad_answer_index": bad_exam,
    }
    critical_fail = False
    print("=== HI Chinese – Referential Integrity Audit ===")
    for k, v in checks.items():
        status = "PASS" if not v else "FAIL"
        critical_fail |= bool(v)
        print(f"[{status}] {k}: {len(v)}")
        for item in v[:10]:
            print(f"        - {item}")
        results[k] = {"status": status, "count": len(v), "samples": v[:50]}
    print(f"[WARN] W1_english_gloss_in_pack_examples: {dict(english_gloss)}")
    print(f"[WARN] W2_vocab_without_example: {dict(vocab_no_example)}")
    print(f"Packs: {json.dumps(pack_summary)}")
    print(f"Vocab counts: {vocab_counts}")
    results["W1_english_gloss_in_pack_examples"] = dict(english_gloss)
    results["W2_vocab_without_example"] = dict(vocab_no_example)
    results["pack_summary"] = pack_summary
    results["vocab_counts"] = vocab_counts

    if "--json" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--json") + 1])
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("RESULT:", "FAIL" if critical_fail else "PASS")
    return 1 if critical_fail else 0


if __name__ == "__main__":
    sys.exit(main())
