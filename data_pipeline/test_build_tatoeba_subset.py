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

RAW_DIR = str(get_raw_dir("tatoeba"))
PROCESSED_DIR = str(get_processed_dir())
REPORTS_DIR = str(get_reports_dir())
ASSETS_DIR = str(get_assets_data_dir())

# 1. Load HSK Vocabulary for matching
vocab_file = os.path.join(PROCESSED_DIR, "hsk_all_vocab.json")
with open(vocab_file, "r", encoding="utf-8") as f:
    vocab_data = json.load(f)

vocab_list = vocab_data["vocabularies"]
word_to_hsk = {v["simplified"]: {"hsk_level": v["hsk_level"], "id": v["id"], "pinyin": v["pinyin"], "meaning_vi": v["meaning_vi"]} for v in vocab_list}
sorted_words = sorted(word_to_hsk.keys(), key=len, reverse=True)
print(f"Loaded {len(word_to_hsk)} HSK vocabulary words for segmentation & difficulty estimation.")

# 2. Load Tatoeba Sentences with Audio
cmn_audio_file = os.path.join(RAW_DIR, "cmn_sentences_with_audio.tsv.bz2")
audio_by_sent = {}
with bz2.open(cmn_audio_file, "rt", encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 2:
            s_id = parts[0]
            a_id = parts[1]
            speaker = parts[2] if len(parts) > 2 else "tatoeba_contributor"
            lic = parts[3] if len(parts) > 3 and parts[3] else "CC BY-NC 4.0"
            attr_url = parts[4] if len(parts) > 4 and parts[4] else f"https://tatoeba.org/audio/download/{a_id}"
            audio_by_sent.setdefault(s_id, []).append({
                "audio_id": a_id,
                "speaker": speaker,
                "license": lic,
                "audio_url": f"https://tatoeba.org/audio/download/{a_id}",
                "audio_type": "human_recording",
                "attribution_url": attr_url
            })

print(f"Loaded Tatoeba audio links for {len(audio_by_sent)} sentences.")

# 3. Load Vietnamese Sentences
vie_sent_file = os.path.join(RAW_DIR, "vie_sentences_detailed.tsv.bz2")
vie_sentences = {}
with bz2.open(vie_sent_file, "rt", encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 3:
            v_id = parts[0]
            text = parts[2]
            user = parts[3] if len(parts) > 3 else "tatoeba_translator"
            vie_sentences[v_id] = {"text": text, "user": user}

print(f"Loaded {len(vie_sentences)} Vietnamese sentences from Tatoeba.")

# 4. Load CMN -> VIE Links
cmn_vie_links_file = os.path.join(RAW_DIR, "cmn-vie_links.tsv.bz2")
cmn_to_vie = {}
with bz2.open(cmn_vie_links_file, "rt", encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 2:
            c_id = parts[0]
            v_id = parts[1]
            if v_id in vie_sentences:
                cmn_to_vie.setdefault(c_id, []).append(vie_sentences[v_id])

print(f"Loaded {len(cmn_to_vie)} Chinese-Vietnamese translation pairs from Tatoeba.")

# 5. Load CMN Detailed Sentences
cmn_detailed_file = os.path.join(RAW_DIR, "cmn_sentences_detailed.tsv.bz2")
tatoeba_hsk_sentences = []

with bz2.open(cmn_detailed_file, "rt", encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 3:
            s_id = parts[0]
            text = parts[2]
            user = parts[3] if len(parts) > 3 else "tatoeba_contributor"
            date = parts[4] if len(parts) > 4 else ""

            # Check if has audio or translation
            has_audio = s_id in audio_by_sent
            has_vie = s_id in cmn_to_vie

            if not (has_audio or has_vie):
                continue

            # Detect HSK words
            matched_words = []
            matched_vocab_ids = []
            max_hsk = 0
            for w in sorted_words:
                if w in text:
                    matched_words.append(w)
                    info = word_to_hsk[w]
                    matched_vocab_ids.append(info["id"])
                    if info["hsk_level"] > max_hsk:
                        max_hsk = info["hsk_level"]

            if not matched_words:
                continue

            # Estimate level
            if max_hsk > 0:
                hsk_level = max_hsk
                level_basis = "estimated_vocab_grammar"
            else:
                hsk_level = 1
                level_basis = "unassigned"

            vie_info = cmn_to_vie.get(s_id, [{}])[0]
            vie_text = vie_info.get("text", "")
            vie_user = vie_info.get("user", "")

            audios = audio_by_sent.get(s_id, [])

            entry = {
                "id": f"tat_{s_id}",
                "chinese": text,
                "traditional": "",
                "pinyin": "",
                "translation_vi": vie_text,
                "translation_en": "",
                "translation_vi_source": "tatoeba_original" if vie_text else "none",
                "hsk_level": hsk_level,
                "hsk_level_basis": level_basis,
                "matched_words": matched_words[:8],
                "matched_vocab_ids": matched_vocab_ids[:8],
                "tokens": [{"word": w, "hsk_level": word_to_hsk[w]["hsk_level"]} for w in matched_words[:5]],
                "topic": "daily_life",
                "contributor": user,
                "source": "Tatoeba Project (tatoeba.org)",
                "license": "CC BY 2.0 FR",
                "has_human_audio": 1 if len(audios) > 0 else 0,
                "audios": audios,
            }
            tatoeba_hsk_sentences.append(entry)

print(f"Extracted {len(tatoeba_hsk_sentences)} Tatoeba sentences matching HSK vocabulary.")
print(f"Sentences with human audio in Tatoeba HSK subset: {sum(1 for s in tatoeba_hsk_sentences if s['has_human_audio'] == 1)}")
