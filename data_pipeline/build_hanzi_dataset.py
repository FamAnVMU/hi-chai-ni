import json
import os
import re
from pipeline_config import (
    get_assets_data_dir,
    get_data_pipeline_dir,
    get_processed_dir,
    get_raw_dir,
    get_reports_dir,
)

RAW_DIR = get_raw_dir("hanzi")
PROCESSED_DIR = get_processed_dir()
REPORTS_DIR = get_reports_dir()
ASSETS_DIR = get_assets_data_dir()
DATA_PIPELINE_DIR = get_data_pipeline_dir()

os.makedirs(PROCESSED_DIR, exist_ok=True)
os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(ASSETS_DIR, exist_ok=True)

# 1. Load HSK Vocabulary
vocab_file = os.path.join(PROCESSED_DIR, "hsk_all_vocab.json")
with open(vocab_file, "r", encoding="utf-8") as f:
    vocab_data = json.load(f)

vocab_list = vocab_data["vocabularies"]

# Character mapping
char_info = {}
for v in vocab_list:
    sim = v.get("simplified", "")
    lvl = v.get("hsk_level", 1)
    word_id = v.get("id", "")
    pinyin = v.get("pinyin", "")
    meaning_vi = v.get("meaning_vi", "")
    hanviet = v.get("hanviet", "")

    for c in sim:
        if '\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf':
            if c not in char_info:
                char_info[c] = {
                    "character": c,
                    "hsk_level": lvl,
                    "hsk_levels": [lvl],
                    "sample_words": [{
                        "id": word_id,
                        "word": sim,
                        "pinyin": pinyin,
                        "meaning_vi": meaning_vi
                    }],
                    "hanviet": hanviet if len(sim) == 1 else ""
                }
            else:
                if lvl not in char_info[c]["hsk_levels"]:
                    char_info[c]["hsk_levels"].append(lvl)
                char_info[c]["hsk_level"] = min(char_info[c]["hsk_level"], lvl)
                if len(char_info[c]["sample_words"]) < 4:
                    char_info[c]["sample_words"].append({
                        "id": word_id,
                        "word": sim,
                        "pinyin": pinyin,
                        "meaning_vi": meaning_vi
                    })
                if len(sim) == 1 and not char_info[c]["hanviet"]:
                    char_info[c]["hanviet"] = hanviet

print(f"Loaded {len(char_info)} unique characters from HSK 1-6 vocabulary.")

# 2. Load Han-Viet dictionary for standalone characters
hanviet_file = os.path.join(DATA_PIPELINE_DIR, "raw", "hanviet", "hanviet.csv")
hanviet_map = {}
if os.path.exists(hanviet_file):
    with open(hanviet_file, "r", encoding="utf-8") as f:
        import csv
        reader = csv.reader(f)
        header = next(reader, None)
        for row in reader:
            if len(row) >= 2:
                c = row[0].strip()
                hv_str = row[1].strip("[]'\" ")
                if c not in hanviet_map and hv_str:
                    hanviet_map[c] = hv_str

# Apply Han-Viet
for c, info in char_info.items():
    if not info["hanviet"] and c in hanviet_map:
        info["hanviet"] = hanviet_map[c]

# 3. Load Make Me a Hanzi dictionary.txt
dict_file = os.path.join(RAW_DIR, "dictionary.txt")
dict_entries = {}
with open(dict_file, "r", encoding="utf-8") as f:
    for line in f:
        item = json.loads(line)
        c = item.get("character")
        if c in char_info:
            dict_entries[c] = item

print(f"Loaded dictionary entries for {len(dict_entries)} / {len(char_info)} characters.")

# 4. Load Make Me a Hanzi graphics.txt
graphics_file = os.path.join(RAW_DIR, "graphics.txt")
graphics_entries = {}
with open(graphics_file, "r", encoding="utf-8") as f:
    for line in f:
        item = json.loads(line)
        c = item.get("character")
        if c in char_info:
            graphics_entries[c] = item

print(f"Loaded graphics entries for {len(graphics_entries)} / {len(char_info)} characters.")

# 5. Build Unified Character Dataset
final_dataset = []
validation_issues = []

for c in sorted(char_info.keys()):
    info = char_info[c]
    d_entry = dict_entries.get(c, {})
    g_entry = graphics_entries.get(c, {})

    strokes = g_entry.get("strokes", [])
    medians = g_entry.get("medians", [])

    is_supported = (len(strokes) > 0 and len(strokes) == len(medians))
    
    # Validation checks
    if len(strokes) == 0:
        validation_issues.append({"character": c, "issue": "Missing stroke data"})
    elif len(strokes) != len(medians):
        validation_issues.append({"character": c, "issue": f"Stroke count mismatch: {len(strokes)} strokes vs {len(medians)} medians"})

    # Check SVG path format
    for idx, s in enumerate(strokes):
        if not s.startswith("M"):
            validation_issues.append({"character": c, "issue": f"Stroke {idx+1} does not start with M: {s[:20]}"})

    # Pinyin from dictionary or sample words
    pinyins = d_entry.get("pinyin", [])
    pinyin_str = ", ".join(pinyins) if pinyins else (info["sample_words"][0]["pinyin"] if info["sample_words"] else "")

    # Meaning
    def_en = d_entry.get("definition", "")
    meaning_vi = info["sample_words"][0]["meaning_vi"] if info["sample_words"] else ""

    entry = {
        "id": f"hanzi_{ord(c):04x}",
        "character": c,
        "stroke_count": len(strokes),
        "hsk_level": info["hsk_level"],
        "all_hsk_levels": sorted(info["hsk_levels"]),
        "pinyin": pinyin_str,
        "hanviet": info["hanviet"],
        "definition_en": def_en,
        "meaning_vi": meaning_vi,
        "radical": d_entry.get("radical", ""),
        "decomposition": d_entry.get("decomposition", ""),
        "etymology": d_entry.get("etymology", {}),
        "strokes": strokes,
        "medians": medians,
        "sample_words": info["sample_words"],
        "is_supported": 1 if is_supported else 0,
        "source": "Make Me a Hanzi (skishore/makemeahanzi)",
        "license": "Arphic Public License / OFL"
    }
    final_dataset.append(entry)

print(f"Total compiled characters: {len(final_dataset)}")
print(f"Validation issues found: {len(validation_issues)}")

# 6. Save full dataset and level datasets
all_file = os.path.join(PROCESSED_DIR, "hanzi_all.json")
with open(all_file, "w", encoding="utf-8") as f:
    json.dump({
        "total_count": len(final_dataset),
        "source": "Make Me a Hanzi",
        "characters": final_dataset
    }, f, ensure_ascii=False, indent=2)

print(f"Saved {all_file} ({os.path.getsize(all_file)/(1024*1024):.2f} MB)")

# Level-by-level files
by_level = {i: [] for i in range(1, 7)}
for entry in final_dataset:
    lvl = entry["hsk_level"]
    if 1 <= lvl <= 6:
        by_level[lvl].append(entry)

for lvl in range(1, 7):
    lvl_file = os.path.join(PROCESSED_DIR, f"hanzi_hsk{lvl}.json")
    with open(lvl_file, "w", encoding="utf-8") as f:
        json.dump({
            "hsk_level": lvl,
            "count": len(by_level[lvl]),
            "characters": by_level[lvl]
        }, f, ensure_ascii=False, indent=2)
    print(f"Saved {lvl_file}: {len(by_level[lvl])} characters ({os.path.getsize(lvl_file)/(1024):.1f} KB)")

# Save compact offline bundle for app (minified json without indent to save space)
asset_bundle_file = os.path.join(ASSETS_DIR, "hanzi_stroke_data.json")
with open(asset_bundle_file, "w", encoding="utf-8") as f:
    json.dump({
        "version": "1.0.0",
        "total_count": len(final_dataset),
        "characters": [{
            "id": item["id"],
            "character": item["character"],
            "stroke_count": item["stroke_count"],
            "hsk_level": item["hsk_level"],
            "pinyin": item["pinyin"],
            "hanviet": item["hanviet"],
            "meaning_vi": item["meaning_vi"],
            "radical": item["radical"],
            "decomposition": item["decomposition"],
            "strokes": item["strokes"],
            "medians": item["medians"],
            "sample_words": item["sample_words"],
            "is_supported": item["is_supported"]
        } for item in final_dataset]
    }, f, ensure_ascii=False, separators=(',', ':'))

print(f"Saved compact asset bundle {asset_bundle_file} ({os.path.getsize(asset_bundle_file)/(1024*1024):.2f} MB)")
