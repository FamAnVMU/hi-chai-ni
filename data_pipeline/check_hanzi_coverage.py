import json
import os
from pipeline_config import get_processed_dir, get_raw_dir

RAW_DIR = str(get_raw_dir("hanzi"))
VOCAB_FILE = str(get_processed_dir() / "hsk_all_vocab.json")

# Load HSK 1-6 vocabulary
with open(VOCAB_FILE, "r", encoding="utf-8") as f:
    vocab_data = json.load(f)

vocab_list = vocab_data["vocabularies"]

# Extract unique characters and map to HSK levels and vocabularies
char_to_info = {}
for v in vocab_list:
    sim = v.get("simplified", "")
    lvl = v.get("hsk_level", 1)
    word_id = v.get("id", "")
    pinyin = v.get("pinyin", "")
    meaning_vi = v.get("meaning_vi", "")

    for c in sim:
        if '\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf':
            if c not in char_to_info:
                char_to_info[c] = {
                    "character": c,
                    "min_hsk_level": lvl,
                    "hsk_levels": set([lvl]),
                    "words": [{"id": word_id, "word": sim, "pinyin": pinyin, "meaning": meaning_vi}]
                }
            else:
                char_to_info[c]["hsk_levels"].add(lvl)
                char_to_info[c]["min_hsk_level"] = min(char_to_info[c]["min_hsk_level"], lvl)
                if len(char_to_info[c]["words"]) < 5:
                    char_to_info[c]["words"].append({"id": word_id, "word": sim, "pinyin": pinyin, "meaning": meaning_vi})

print(f"Total unique characters in HSK 1-6: {len(char_to_info)}")

# Index graphics.txt
graphics_chars = set()
with open(os.path.join(RAW_DIR, "graphics.txt"), "r", encoding="utf-8") as f:
    for line in f:
        item = json.loads(line)
        graphics_chars.add(item["character"])

print(f"Total characters in graphics.txt: {len(graphics_chars)}")

# Check coverage
found_chars = set(char_to_info.keys()).intersection(graphics_chars)
missing_chars = set(char_to_info.keys()) - graphics_chars

print(f"Coverage: {len(found_chars)} / {len(char_to_info)} ({len(found_chars)/len(char_to_info)*100:.2f}%)")
if missing_chars:
    print(f"Missing characters ({len(missing_chars)}):")
    for c in missing_chars:
        info = char_to_info[c]
        print(f" - {c}: HSK {info['min_hsk_level']}, in words: {[w['word'] for w in info['words']]}")
else:
    print("ALL characters are supported!")
