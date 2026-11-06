import bz2
import json
import os
import re
from pypinyin import pinyin, Style

def main():
    base_dir = r"C:\Users\phama\Downloads\hi_chinese"
    raw_tatoeba = os.path.join(base_dir, "data_pipeline", "raw", "tatoeba")
    processed_dir = os.path.join(base_dir, "data_pipeline", "processed")
    assets_data_dir = os.path.join(base_dir, "assets", "data")

    print("[Enricher] Loading Vietnamese sentences from Tatoeba...")
    vie_sentences = {}
    vie_file = os.path.join(raw_tatoeba, "vie_sentences_detailed.tsv.bz2")
    if os.path.exists(vie_file):
        with bz2.open(vie_file, "rt", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 3:
                    vie_sentences[parts[0]] = parts[2]
    print(f"[Enricher] Loaded {len(vie_sentences)} Vietnamese sentences.")

    print("[Enricher] Loading CMN -> VIE links...")
    cmn_to_vie = {}
    cmn_vie_links = os.path.join(raw_tatoeba, "cmn-vie_links.tsv.bz2")
    if os.path.exists(cmn_vie_links):
        with bz2.open(cmn_vie_links, "rt", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 2 and parts[1] in vie_sentences:
                    cmn_to_vie.setdefault(parts[0], []).append(vie_sentences[parts[1]])
    print(f"[Enricher] Loaded {len(cmn_to_vie)} CMN->VIE pairs.")

    print("[Enricher] Loading CMN Audio links...")
    cmn_audio = {}
    cmn_audio_file = os.path.join(raw_tatoeba, "cmn_sentences_with_audio.tsv.bz2")
    if os.path.exists(cmn_audio_file):
        with bz2.open(cmn_audio_file, "rt", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 2:
                    cmn_audio[parts[0]] = f"https://tatoeba.org/audio/download/{parts[1]}"
    print(f"[Enricher] Loaded {len(cmn_audio)} CMN sentences with human audio.")

    # Load existing vocabulary files for HSK 4, 5, 6
    vocab_files = {
        4: os.path.join(processed_dir, "hsk4_vocab.json"),
        5: os.path.join(processed_dir, "hsk5_vocab.json"),
        6: os.path.join(processed_dir, "hsk6_vocab.json"),
    }

    vocab_data_by_lvl = {}
    missing_words = {}

    for lvl, path in vocab_files.items():
        with open(path, "r", encoding="utf-8") as f:
            d = json.load(f)
            vocab_data_by_lvl[lvl] = d
            vocabs = d.get("vocabularies", [])
            for v in vocabs:
                if not v.get("examples"):
                    missing_words[v["simplified"]] = (lvl, v["id"])

    print(f"[Enricher] Total words currently missing examples: {len(missing_words)}")
    for lvl in [4, 5, 6]:
        count = sum(1 for (l, _) in missing_words.values() if l == lvl)
        print(f"  HSK {lvl}: {count} words missing examples")

    # Scan Tatoeba Chinese sentences
    print("[Enricher] Scanning Tatoeba CMN detailed sentences to find authentic examples...")
    matched_sentences = {}
    cmn_file = os.path.join(raw_tatoeba, "cmn_sentences_detailed.tsv.bz2")
    if os.path.exists(cmn_file):
        with bz2.open(cmn_file, "rt", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 3:
                    s_id, text = parts[0], parts[2]
                    # Filter for appropriate learning sentence length: between 5 and 35 chars
                    if len(text) < 5 or len(text) > 35:
                        continue
                    for w in list(missing_words.keys()):
                        if w in text:
                            has_vi = s_id in cmn_to_vie
                            has_aud = s_id in cmn_audio
                            score = (2 if has_vi else 0) + (1 if has_aud else 0)
                            
                            if w not in matched_sentences or score > matched_sentences[w]["score"]:
                                py_tokens = [x[0] for x in pinyin(text, style=Style.TONE)]
                                py_str = " ".join(py_tokens)
                                matched_sentences[w] = {
                                    "score": score,
                                    "s_id": s_id,
                                    "chinese": text,
                                    "pinyin": py_str,
                                    "translation_vi": cmn_to_vie.get(s_id, [""])[0] if has_vi else None,
                                    "audio_url": cmn_audio.get(s_id, None),
                                }

    print(f"[Enricher] Matched {len(matched_sentences)} / {len(missing_words)} missing words with authentic sentences.")

    # Inject into vocabularies
    enriched_counts = {4: 0, 5: 0, 6: 0}
    for lvl, d in vocab_data_by_lvl.items():
        for v in d.get("vocabularies", []):
            w = v["simplified"]
            if not v.get("examples") and w in matched_sentences:
                cand = matched_sentences[w]
                new_example = {
                    "id": f"EX_{v['id']}_1",
                    "vocabulary_id": v["id"],
                    "hsk_level": lvl,
                    "example_cn": cand["chinese"],
                    "example_pinyin": cand["pinyin"],
                    "example_vi": cand["translation_vi"],
                    "example_en": "",
                    "audio_uri": cand["audio_url"],
                    "source": "Tatoeba Project (tatoeba.org)",
                    "license": "CC BY 2.0 FR",
                    "order_index": 1,
                    "verification_status": "verified" if cand["translation_vi"] else "tatoeba_text_verified_vi_pending"
                }
                v["examples"] = [new_example]
                # Also attach to primary sense
                if v.get("senses"):
                    v["senses"][0]["example_cn"] = cand["chinese"]
                    v["senses"][0]["example_pinyin"] = cand["pinyin"]
                    if cand["translation_vi"]:
                        v["senses"][0]["example_vi"] = cand["translation_vi"]
                enriched_counts[lvl] += 1

    # Write enriched processed JSON files
    for lvl, path in vocab_files.items():
        with open(path, "w", encoding="utf-8") as f:
            json.dump(vocab_data_by_lvl[lvl], f, indent=2, ensure_ascii=False)
        print(f"[Enricher] Wrote enriched HSK {lvl} vocab ({enriched_counts[lvl]} examples newly injected) -> {path}")

    # Export to assets/data/hsk4_vocabularies.json, etc.
    for lvl in [4, 5, 6]:
        asset_out_path = os.path.join(assets_data_dir, f"hsk{lvl}_vocabularies.json")
        with open(asset_out_path, "w", encoding="utf-8") as f:
            json.dump(vocab_data_by_lvl[lvl], f, indent=2, ensure_ascii=False)
        print(f"[Enricher] Exported standalone asset -> {asset_out_path}")

    # Also update assets/data/hsk_seed_fixture_v2.json
    fixture_v2_path = os.path.join(assets_data_dir, "hsk_seed_fixture_v2.json")
    with open(fixture_v2_path, "r", encoding="utf-8") as f:
        fixture_v2 = json.load(f)

    # Build lookup of enriched vocabularies
    enriched_lookup = {}
    for lvl in [4, 5, 6]:
        for v in vocab_data_by_lvl[lvl].get("vocabularies", []):
            enriched_lookup[v["id"]] = v

    updated_in_fixture = 0
    for i, v in enumerate(fixture_v2.get("vocabularies", [])):
        v_id = v.get("id")
        if v_id in enriched_lookup:
            fixture_v2["vocabularies"][i] = enriched_lookup[v_id]
            updated_in_fixture += 1

    with open(fixture_v2_path, "w", encoding="utf-8") as f:
        json.dump(fixture_v2, f, indent=2, ensure_ascii=False)
    print(f"[Enricher] Updated {updated_in_fixture} entries in {fixture_v2_path}")

    # Final summary
    print("\n--- SUMMARY OF VOCABULARY & EXAMPLES STATUS ---")
    for lvl in [4, 5, 6]:
        total = len(vocab_data_by_lvl[lvl].get("vocabularies", []))
        with_ex = sum(1 for v in vocab_data_by_lvl[lvl].get("vocabularies", []) if v.get("examples"))
        print(f"HSK {lvl}: Total {total} words | With Examples: {with_ex}/{total} ({with_ex/total*100:.1f}%)")

if __name__ == "__main__":
    main()
