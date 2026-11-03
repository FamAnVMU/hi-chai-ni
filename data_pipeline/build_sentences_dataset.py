import os
import bz2
import json
import re
from pipeline_config import (
    get_assets_data_dir,
    get_processed_dir,
    get_raw_dir,
    get_reports_dir,
)

RAW_TATOEBA = str(get_raw_dir("tatoeba"))
RAW_SENTENCES = str(get_raw_dir("sentences"))
PROCESSED_DIR = str(get_processed_dir())
REPORTS_DIR = str(get_reports_dir())
ASSETS_DIR = str(get_assets_data_dir())

os.makedirs(PROCESSED_DIR, exist_ok=True)
os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(ASSETS_DIR, exist_ok=True)

# 1. Load HSK Vocabulary map
vocab_file = os.path.join(PROCESSED_DIR, "hsk_all_vocab.json")
with open(vocab_file, "r", encoding="utf-8") as f:
    vocab_data = json.load(f)

vocab_list = vocab_data["vocabularies"]
word_to_info = {}
for v in vocab_list:
    sim = v.get("simplified", "")
    senses = v.get("senses", [])
    meaning_vi = senses[0].get("meaning_vi", "") if senses else ""
    word_to_info[sim] = {
        "id": v.get("id", ""),
        "hsk_level": v.get("hsk_level", 1),
        "pinyin": v.get("pinyin", ""),
        "meaning_vi": meaning_vi
    }

sorted_words = sorted(word_to_info.keys(), key=len, reverse=True)
print(f"Loaded {len(word_to_info)} HSK words for text matching.")

# 2. Load Tatoeba Vietnamese Translations
vie_sent_file = os.path.join(RAW_TATOEBA, "vie_sentences_detailed.tsv.bz2")
vie_sentences = {}
if os.path.exists(vie_sent_file):
    with bz2.open(vie_sent_file, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3:
                vie_sentences[parts[0]] = {
                    "text": parts[2],
                    "user": parts[3] if len(parts) > 3 else "tatoeba_translator"
                }
print(f"Loaded {len(vie_sentences)} Vietnamese sentences from Tatoeba.")

# 3. Load Tatoeba CMN -> VIE and CMN -> ENG Links
cmn_to_vie = {}
cmn_vie_links = os.path.join(RAW_TATOEBA, "cmn-vie_links.tsv.bz2")
if os.path.exists(cmn_vie_links):
    with bz2.open(cmn_vie_links, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                c_id, v_id = parts[0], parts[1]
                if v_id in vie_sentences:
                    cmn_to_vie.setdefault(c_id, []).append(vie_sentences[v_id])

print(f"Loaded {len(cmn_to_vie)} Chinese-Vietnamese translation pairs.")

# 4. Load Tatoeba Audio Links
cmn_audio_file = os.path.join(RAW_TATOEBA, "cmn_sentences_with_audio.tsv.bz2")
audio_by_sent = {}
if os.path.exists(cmn_audio_file):
    with bz2.open(cmn_audio_file, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                s_id, a_id = parts[0], parts[1]
                speaker = parts[2] if len(parts) > 2 and parts[2] else "tatoeba_contributor"
                lic = parts[3] if len(parts) > 3 and parts[3] else "CC BY-NC 4.0"
                audio_by_sent.setdefault(s_id, []).append({
                    "audio_id": a_id,
                    "speaker": speaker,
                    "license": lic,
                    "audio_url": f"https://tatoeba.org/audio/download/{a_id}",
                    "audio_type": "human_recording",
                    "attribution_url": f"https://tatoeba.org/sentences/show/{s_id}"
                })
print(f"Loaded {len(audio_by_sent)} Tatoeba sentences with human audio.")

# 5. Load Tatoeba Sentences matching HSK
tatoeba_entries = []
cmn_detailed_file = os.path.join(RAW_TATOEBA, "cmn_sentences_detailed.tsv.bz2")
if os.path.exists(cmn_detailed_file):
    with bz2.open(cmn_detailed_file, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3:
                s_id, lang, text = parts[0], parts[1], parts[2]
                user = parts[3] if len(parts) > 3 else "tatoeba_contributor"

                # Check if has audio or translation
                has_audio = s_id in audio_by_sent
                has_vie = s_id in cmn_to_vie

                if not (has_audio or has_vie):
                    continue

                # Match words
                matched_words = []
                matched_vocab_ids = []
                max_hsk = 0
                for w in sorted_words:
                    if w in text:
                        matched_words.append(w)
                        info = word_to_info[w]
                        matched_vocab_ids.append(info["id"])
                        if info["hsk_level"] > max_hsk:
                            max_hsk = info["hsk_level"]

                if not matched_words:
                    continue

                hsk_level = max_hsk if max_hsk > 0 else 1
                level_basis = "estimated_vocab_grammar"

                vie_info = cmn_to_vie.get(s_id, [{}])[0]
                vie_text = vie_info.get("text", "")
                vie_user = vie_info.get("user", "")

                audios = audio_by_sent.get(s_id, [])

                entry = {
                    "id": f"tat_{s_id}",
                    "sentence_id": f"tat_{s_id}",
                    "chinese": text,
                    "traditional": "",
                    "pinyin": "",
                    "translation_vi": vie_text,
                    "translation_en": "",
                    "translation_vi_source": "tatoeba_original" if vie_text else "needs_verification",
                    "hsk_level": hsk_level,
                    "hsk_level_basis": level_basis,
                    "tokens": [{"word": w, "pinyin": word_to_info[w]["pinyin"], "meaning_vi": word_to_info[w]["meaning_vi"], "hsk_level": word_to_info[w]["hsk_level"]} for w in matched_words[:6]],
                    "matched_vocab_ids": matched_vocab_ids[:8],
                    "grammar_tags": [],
                    "topic": "daily_conversation",
                    "contributor": user,
                    "translator": vie_user,
                    "source": "Tatoeba Project (tatoeba.org)",
                    "license": "CC BY 2.0 FR",
                    "has_human_audio": 1 if len(audios) > 0 else 0,
                    "has_tts_fallback": 1,
                    "audios": audios
                }
                tatoeba_entries.append(entry)

print(f"Compiled {len(tatoeba_entries)} qualified Tatoeba sentences.")

# 6. Load Structured HSK Sentences from sentences.json
curated_entries = []
curated_file = os.path.join(RAW_SENTENCES, "sentences.json")
if os.path.exists(curated_file):
    with open(curated_file, "r", encoding="utf-8") as f:
        c_list = json.load(f)

    for item in c_list:
        lvl = item.get("hsk_level", 1)
        sim = item.get("chinese", "")
        trad = item.get("traditional", "")
        pinyin = item.get("pinyin", "")
        en = item.get("translation", {}).get("en", "")
        tokens = item.get("tokens", [])
        g_points = item.get("grammar_points", [])
        g_tags = item.get("grammar_tags", [])
        topic = item.get("topic", "general")
        audio_info = item.get("audio", {})
        audio_meta = item.get("audio_meta", {})

        # Find matched vocab IDs
        matched_vocab_ids = []
        for t in tokens:
            w = t.get("word", "")
            if w in word_to_info:
                matched_vocab_ids.append(word_to_info[w]["id"])

        audios = []
        if audio_info.get("normal"):
            audios.append({
                "audio_id": f"{item['id']}_normal",
                "speaker": audio_meta.get("voice", "zh-female-studio"),
                "license": audio_meta.get("license", "Apache-2.0"),
                "audio_url": audio_info["normal"],
                "audio_type": "studio_simulation",
                "speed_type": "normal",
                "sample_rate": audio_meta.get("sample_rate", 24000)
            })
        if audio_info.get("slow"):
            audios.append({
                "audio_id": f"{item['id']}_slow",
                "speaker": audio_meta.get("voice", "zh-female-studio"),
                "license": audio_meta.get("license", "Apache-2.0"),
                "audio_url": audio_info["slow"],
                "audio_type": "studio_simulation",
                "speed_type": "slow",
                "sample_rate": audio_meta.get("sample_rate", 24000)
            })

        # Produce Vietnamese translation draft from tokens if not present, marked needs_verification
        vi_parts = []
        for t in tokens:
            w = t.get("word", "")
            if w in word_to_info and word_to_info[w]["meaning_vi"]:
                vi_parts.append(word_to_info[w]["meaning_vi"])
        vi_meaning = " ".join(vi_parts) if vi_parts else ""

        entry = {
            "id": item["id"],
            "sentence_id": item["id"],
            "chinese": sim,
            "traditional": trad,
            "pinyin": pinyin,
            "translation_vi": vi_meaning,
            "translation_en": en,
            "translation_vi_source": "lexicon_draft" if vi_meaning else "needs_verification",
            "hsk_level": lvl,
            "hsk_level_basis": "direct_corpus",
            "tokens": [{
                "word": t.get("word", ""),
                "pinyin": t.get("pinyin", ""),
                "meaning_vi": word_to_info.get(t.get("word", ""), {}).get("meaning_vi", t.get("gloss_en", "")),
                "hsk_level": word_to_info.get(t.get("word", ""), {}).get("hsk_level", lvl)
            } for t in tokens],
            "matched_vocab_ids": matched_vocab_ids,
            "grammar_tags": g_points if g_points else g_tags,
            "topic": topic,
            "contributor": "Corpus Contributor",
            "translator": "Lexicon Parser",
            "source": "HSK Syllabus Corpus & CosyVoice2",
            "license": "Apache-2.0",
            "has_human_audio": 0,
            "has_tts_fallback": 1,
            "audios": audios
        }
        curated_entries.append(entry)

print(f"Loaded {len(curated_entries)} structured HSK sentences from curated corpus.")

# 7. Merge and Deduplicate
all_sentences = []
seen_texts = set()

# First add Tatoeba human audio sentences
for s in tatoeba_entries:
    if s["has_human_audio"] == 1 and s["chinese"] not in seen_texts:
        seen_texts.add(s["chinese"])
        all_sentences.append(s)

# Then add curated corpus sentences
for s in curated_entries:
    if s["chinese"] not in seen_texts:
        seen_texts.add(s["chinese"])
        all_sentences.append(s)

# Then add remaining Tatoeba translation sentences
for s in tatoeba_entries:
    if s["chinese"] not in seen_texts and s["translation_vi"]:
        seen_texts.add(s["chinese"])
        all_sentences.append(s)

print(f"Total unified sentences compiled: {len(all_sentences)}")

# 8. Save Processed Files
all_file = os.path.join(PROCESSED_DIR, "sentences_all.json")
with open(all_file, "w", encoding="utf-8") as f:
    json.dump({
        "total_count": len(all_sentences),
        "sentences": all_sentences
    }, f, ensure_ascii=False, indent=2)

print(f"Saved {all_file} ({os.path.getsize(all_file)/(1024*1024):.2f} MB)")

# Level-by-level files
by_level = {i: [] for i in range(1, 7)}
for s in all_sentences:
    lvl = s["hsk_level"]
    if 1 <= lvl <= 6:
        by_level[lvl].append(s)

for lvl in range(1, 7):
    lvl_file = os.path.join(PROCESSED_DIR, f"sentences_hsk{lvl}.json")
    with open(lvl_file, "w", encoding="utf-8") as f:
        json.dump({
            "hsk_level": lvl,
            "count": len(by_level[lvl]),
            "sentences": by_level[lvl]
        }, f, ensure_ascii=False, indent=2)
    print(f"Saved {lvl_file}: {len(by_level[lvl])} sentences ({os.path.getsize(lvl_file)/(1024):.1f} KB)")

# Compact asset bundle for app (curated selection of ~1,500 sentences covering HSK 1-6)
# Prioritize human audio, then verified translations, up to 250 sentences per level
curated_bundle = []
for lvl in range(1, 7):
    level_sents = by_level[lvl]
    # Human audio first
    with_human = [s for s in level_sents if s["has_human_audio"] == 1]
    without_human = [s for s in level_sents if s["has_human_audio"] == 0]
    selected = (with_human + without_human)[:250]
    curated_bundle.extend(selected)

bundle_file = os.path.join(ASSETS_DIR, "sentences_corpus.json")
with open(bundle_file, "w", encoding="utf-8") as f:
    json.dump({
        "version": "1.0.0",
        "total_count": len(curated_bundle),
        "sentences": [{
            "id": s["id"],
            "chinese": s["chinese"],
            "traditional": s["traditional"],
            "pinyin": s["pinyin"],
            "translation_vi": s["translation_vi"],
            "translation_en": s["translation_en"],
            "translation_vi_source": s["translation_vi_source"],
            "hsk_level": s["hsk_level"],
            "hsk_level_basis": s["hsk_level_basis"],
            "topic": s["topic"],
            "tokens": s["tokens"],
            "matched_vocab_ids": s["matched_vocab_ids"],
            "grammar_tags": s["grammar_tags"],
            "contributor": s["contributor"],
            "source": s["source"],
            "license": s["license"],
            "has_human_audio": s["has_human_audio"],
            "audios": s["audios"]
        } for s in curated_bundle]
    }, f, ensure_ascii=False, separators=(',', ':'))

print(f"Saved compact sentences bundle {bundle_file} ({os.path.getsize(bundle_file)/(1024*1024):.2f} MB, {len(curated_bundle)} sentences)")
