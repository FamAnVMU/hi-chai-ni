import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import time
import urllib.parse
import urllib.request

try:
    from pypinyin import Style, pinyin

    HAS_PYPINYIN = True
except ImportError:
    HAS_PYPINYIN = False


def compute_sha256(text: str) -> str:
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()


def generate_pinyin_text(text: str) -> str:
    if not HAS_PYPINYIN or not text:
        return ""
    pinyin_result = pinyin(text, style=Style.TONE)
    return " ".join([item[0] for item in pinyin_result if item and item[0]])


def translate_zh_to_vi(text: str, cache: dict, timeout: int = 5) -> str:
    cleaned = text.strip()
    if not cleaned:
        return ""
    if cleaned in cache:
        return cache[cleaned]

    try:
        url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=zh-CN&tl=vi&dt=t&q=" + urllib.parse.quote(cleaned)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            translated = "".join([part[0] for part in data[0] if part and part[0]])
            if translated:
                cache[cleaned] = translated
                return translated
    except Exception:
        pass

    cache[cleaned] = cleaned
    return cleaned


def find_citation_sentence(content: str, question: str, answer: str) -> str:
    sentences = [s.strip() for s in re.split(r"[。！？；\n]", content) if s.strip()]
    if not sentences:
        return content

    target_chars = set(re.sub(r"[^\u4e00-\u9fa5]", "", question + answer))
    best_sentence = sentences[0]
    best_score = -1

    for sentence in sentences:
        sent_chars = set(re.sub(r"[^\u4e00-\u9fa5]", "", sentence))
        common_count = len(target_chars.intersection(sent_chars))
        if answer in sentence:
            common_count += 10
        if common_count > best_score:
            best_score = common_count
            best_sentence = sentence

    return best_sentence


def extract_concise_title(content: str, default_level: int) -> str:
    dialogue_match = re.match(r"^[男女]：(.*?)[，。！？]", content)
    if dialogue_match and len(dialogue_match.group(1)) >= 2:
        candidate = dialogue_match.group(1).strip()
        if len(candidate) <= 12:
            return candidate

    first_sentence = re.split(r"[。！？\n]", content)[0].strip()
    first_sentence = re.sub(r"^[男女]：", "", first_sentence).strip()
    if 2 <= len(first_sentence) <= 12:
        return first_sentence
    elif len(first_sentence) > 12:
        return first_sentence[:10] + "..."

    level_topics = {
        1: "日常生活小事",
        2: "生活与朋友",
        3: "旅行与工作",
        4: "社会与文化",
    }
    return level_topics.get(default_level, "阅读理解")


def load_c3_data(c3_dir: Path) -> list:
    c3_dir.mkdir(parents=True, exist_ok=True)
    file_specs = [
        ("c3-m-train.json", "https://raw.githubusercontent.com/nlpdata/c3/master/data/c3-m-train.json"),
        ("c3-m-dev.json", "https://raw.githubusercontent.com/nlpdata/c3/master/data/c3-m-dev.json"),
        ("c3-d-train.json", "https://raw.githubusercontent.com/nlpdata/c3/master/data/c3-d-train.json"),
        ("c3-d-dev.json", "https://raw.githubusercontent.com/nlpdata/c3/master/data/c3-d-dev.json"),
    ]

    all_entries = []
    for filename, url in file_specs:
        file_path = c3_dir / filename
        if not file_path.exists():
            print(f"Downloading {filename} from {url}...")
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    data = resp.read()
                    file_path.write_bytes(data)
                print(f"Downloaded {filename} ({len(data)} bytes)")
            except Exception as e:
                print(f"Failed to download {filename}: {e}")
                continue

        if file_path.exists():
            try:
                loaded = json.loads(file_path.read_text(encoding="utf-8"))
                if isinstance(loaded, list):
                    all_entries.extend(loaded)
            except Exception as e:
                print(f"Failed to parse {filename}: {e}")

    return all_entries


def collect_existing_hashes(project_root: Path) -> set[str]:
    hashes = set()
    fixture_paths = [
        project_root / "assets" / "data" / "hsk_seed_fixture_v1.json",
        project_root / "assets" / "data" / "hsk_seed_fixture_v2.json",
    ]
    for path in fixture_paths:
        if path.exists():
            try:
                content = json.loads(path.read_text(encoding="utf-8"))
                passages = content.get("readingPassages", [])
                for p in passages:
                    text = p.get("contentZh") or p.get("content_cn") or ""
                    if text:
                        hashes.add(compute_sha256(text))
            except Exception:
                pass
    return hashes


def convert_c3_to_passages(
    project_root: Path,
    output_path: Path,
    target_per_level: int = 16,
) -> list[dict]:
    c3_dir = project_root / "data_pipeline" / "raw" / "c3"
    cache_file = c3_dir / "translations_cache.json"

    translation_cache = {}
    if cache_file.exists():
        try:
            translation_cache = json.loads(cache_file.read_text(encoding="utf-8"))
        except Exception:
            translation_cache = {}

    all_c3_entries = load_c3_data(c3_dir)
    print(f"Loaded {len(all_c3_entries)} total entries from C3 dataset.")

    existing_hashes = collect_existing_hashes(project_root)
    print(f"Collected {len(existing_hashes)} existing hashes for deduplication.")

    level_buckets = {1: [], 2: [], 3: [], 4: []}
    seen_hashes = set(existing_hashes)

    for item in all_c3_entries:
        if not isinstance(item, list) or len(item) < 2:
            continue
        paragraphs = item[0]
        raw_questions = item[1]
        if not isinstance(paragraphs, list) or not isinstance(raw_questions, list):
            continue

        content_cn = "".join(paragraphs).strip()
        if not content_cn:
            continue

        h = compute_sha256(content_cn)
        if h in seen_hashes:
            continue

        valid_questions = []
        for q in raw_questions:
            if not isinstance(q, dict):
                continue
            question_text = q.get("question", "").strip()
            choices = q.get("choice", [])
            answer = q.get("answer", "")

            if not question_text or not isinstance(choices, list) or len(choices) != 4:
                continue
            if answer not in choices:
                continue

            valid_questions.append({
                "question": question_text,
                "options": [str(c).strip() for c in choices],
                "answer_text": str(answer).strip(),
                "answer_index": choices.index(answer),
            })

        if not (2 <= len(valid_questions) <= 4):
            continue

        hanzi_count = len(re.sub(r"[^\u4e00-\u9fa5]", "", content_cn))
        assigned_level = 0
        if hanzi_count < 75:
            assigned_level = 1
        elif 75 <= hanzi_count < 100:
            assigned_level = 2
        elif 100 <= hanzi_count < 150:
            assigned_level = 3
        elif 150 <= hanzi_count <= 250:
            assigned_level = 4

        if assigned_level in level_buckets:
            if len(level_buckets[assigned_level]) < target_per_level:
                seen_hashes.add(h)
                level_buckets[assigned_level].append({
                    "content_cn": content_cn,
                    "questions": valid_questions,
                    "level": assigned_level,
                })

    for lvl in (1, 2, 3, 4):
        print(f"Selected HSK {lvl}: {len(level_buckets[lvl])} passages")

    final_passages = []
    global_index = 1

    for lvl in (1, 2, 3, 4):
        for candidate in level_buckets[lvl]:
            passage_id = f"RDG_C3_{global_index:03d}"
            content = candidate["content_cn"]
            pinyin_str = generate_pinyin_text(content)
            translation_vi = translate_zh_to_vi(content, translation_cache)
            title = extract_concise_title(content, lvl)

            processed_questions = []
            for q_idx, q_data in enumerate(candidate["questions"], start=1):
                q_id = f"q_c3_{global_index:03d}_{q_idx}"
                q_text = q_data["question"]
                options = q_data["options"]
                ans_idx = q_data["answer_index"]
                ans_text = q_data["answer_text"]

                citation = find_citation_sentence(content, q_text, ans_text)
                explanation = f"Dựa vào câu: \"{citation}\", đáp án chính xác là: {ans_text}."

                processed_questions.append({
                    "id": q_id,
                    "type": "single_choice",
                    "question": q_text,
                    "options": options,
                    "answer": ans_idx,
                    "citationText": citation,
                    "explanationVi": explanation,
                })

            passage_obj = {
                "id": passage_id,
                "hsk_level": lvl,
                "hskLevel": lvl,
                "title_cn": title,
                "title": title,
                "content_cn": content,
                "contentZh": content,
                "pinyin": pinyin_str,
                "translation_vi": translation_vi,
                "translationVi": translation_vi,
                "questions": processed_questions,
                "questions_json": json.dumps(processed_questions, ensure_ascii=False),
            }

            final_passages.append(passage_obj)
            global_index += 1

    try:
        cache_file.write_text(json.dumps(translation_cache, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception:
        pass

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(final_passages, ensure_ascii=False, indent=2), encoding="utf-8")
    return final_passages


def main():
    parser = argparse.ArgumentParser(description="Convert C3 dataset into graded ReadingPassages with 2-4 questions.")
    parser.add_argument("--output", "-o", type=str, default="", help="Path to output JSON file")
    parser.add_argument("--per-level", "-n", type=int, default=16, help="Target passages per HSK level (1 to 4)")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent
    output_path = Path(args.output) if args.output else project_root / "assets" / "data" / "graded_reading_passages.json"

    print(f"Converting C3 dataset to graded reading passages -> {output_path}")
    start_time = time.time()
    passages = convert_c3_to_passages(project_root, output_path, target_per_level=args.per_level)
    elapsed = time.time() - start_time

    print(f"Successfully converted {len(passages)} passages in {elapsed:.2f}s.")
    print(f"Output saved to: {output_path}")


if __name__ == "__main__":
    main()
