#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HI Chinese - AI Curation Tool
Pinyin Aligner & Polyphone Disambiguation Pipeline
File: tool/ai_curation/pinyin_aligner.py

Features:
- Contextual pinyin generation using pypinyin and jieba.posseg.
- Grammatical polyphone disambiguation (多音字) for:
  着 (zhe/zháo/zhuó), 得 (de/dé/děi), 地 (de/dì), 行 (xíng/háng),
  会 (huì/kuài), 便 (biàn/pián), 觉 (jué/jiào), 乐 (lè/yuè), 长 (cháng/zhǎng), etc.
- 1-to-1 character-syllable alignment for Flutter RubyText rendering:
  Number of space-separated Pinyin syllables strictly matches the number of Hanzi characters.
"""

import sys
import os
import re
import json
import argparse
from typing import List, Tuple, Dict, Any, Optional

try:
    from pypinyin import pinyin, Style, load_phrases_dict
    import jieba
    import jieba.posseg as pseg
except ImportError as e:
    sys.stderr.write(f"Missing required dependency: {e}\nRun: pip install pypinyin jieba\n")
    sys.exit(1)

# Comprehensive Polyphone & Collocation Dictionary
POLYPHONE_PHRASES: Dict[str, List[List[str]]] = {
    # 得: de (complement) vs dé (obtain) vs děi (must)
    "高兴得": [["gāo"], ["xìng"], ["de"]],
    "跑得快": [["pǎo"], ["de"], ["kuài"]],
    "吃得好": [["chī"], ["de"], ["hǎo"]],
    "看得到": [["kàn"], ["de"], ["dào"]],
    "听得见": [["tīng"], ["de"], ["jiàn"]],
    "做得到": [["zuò"], ["de"], ["dào"]],
    "走得慢": [["zǒu"], ["de"], ["màn"]],
    "写得好": [["xiě"], ["de"], ["hǎo"]],
    "唱得好": [["chàng"], ["de"], ["hǎo"]],
    "长得": [["zhǎng"], ["de"]],
    "得去": [["děi"], ["qù"]],
    "得做": [["děi"], ["zuò"]],
    "得看": [["děi"], ["kàn"]],
    "得到": [["dé"], ["dào"]],
    "得分": [["dé"], ["fēn"]],
    "心得": [["xīn"], ["dé"]],
    "舍得": [["shě"], ["de"]],
    "值得": [["zhí"], ["de"]],
    "觉得": [["jué"], ["de"]],
    
    # 地: de (adverbial marker) vs dì (place/ground)
    "慢慢地": [["màn"], ["màn"], ["de"]],
    "认真地": [["rèn"], ["zhēn"], ["de"]],
    "高兴地": [["gāo"], ["xìng"], ["de"]],
    "轻轻地": [["qīng"], ["qīng"], ["de"]],
    "飞快地": [["fēi"], ["kuài"], ["de"]],
    "大声地": [["dà"], ["shēng"], ["de"]],
    "悄悄地": [["qiāo"], ["qiāo"], ["de"]],
    "安静地": [["ān"], ["jìng"], ["de"]],
    "努力地": [["nǔ"], ["lì"], ["de"]],
    "开心地": [["kāi"], ["xīn"], ["de"]],
    "地方": [["dì"], ["fang"]],
    "目的地": [["mù"], ["dì"], ["dì"]],
    "土地": [["tǔ"], ["dì"]],
    "地图": [["dì"], ["tú"]],
    "地理": [["dì"], ["lǐ"]],
    "地球": [["dì"], ["qiú"]],
    "地下": [["dì"], ["xià"]],

    # 着: zhe (aspect) vs zháo (burn/feel) vs zhuó (touch)
    "看着": [["kàn"], ["zhe"]],
    "走着": [["zǒu"], ["zhe"]],
    "听着": [["tīng"], ["zhe"]],
    "坐着": [["zuò"], ["zhe"]],
    "站着": [["zhàn"], ["zhe"]],
    "躺着": [["tǎng"], ["zhe"]],
    "拿着": [["ná"], ["zhe"]],
    "跟着": [["gēn"], ["zhe"]],
    "穿着": [["chuān"], ["zhe"]],
    "带着": [["dài"], ["zhe"]],
    "着急": [["zháo"], ["jí"]],
    "着凉": [["zháo"], ["liáng"]],
    "着火": [["zháo"], ["huǒ"]],
    "着迷": [["zháo"], ["mí"]],
    "睡着": [["shuì"], ["zháo"]],
    "着重": [["zhuó"], ["zhòng"]],
    "着手": [["zhuó"], ["shǒu"]],

    # 行: xíng (walk/travel/ok) vs háng (line/bank/profession)
    "一行人": [["yì"], ["xíng"], ["rén"]],
    "银行": [["yín"], ["háng"]],
    "银行卡": [["yín"], ["háng"], ["kǎ"]],
    "行业": [["háng"], ["yè"]],
    "同行": [["tóng"], ["háng"]],
    "行家": [["háng"], ["jia"]],
    "行动": [["xíng"], ["dòng"]],
    "行走": [["xíng"], ["zǒu"]],
    "自行车": [["zì"], ["xíng"], ["chē"]],
    "旅行": [["lǚ"], ["xíng"]],
    "不行": [["bù"], ["xíng"]],
    "举行": [["jǔ"], ["xíng"]],

    # 会: huì (meeting/can) vs kuài (accounting)
    "会计": [["kuài"], ["jì"]],
    "财会": [["cái"], ["kuài"]],
    "开会": [["kāi"], ["huì"]],
    "会议": [["huì"], ["yì"]],
    "一会儿": [["yí"], ["huì"], ["ér"]],

    # 便: biàn (convenient/then) vs pián (cheap)
    "便宜": [["pián"], ["yi"]],
    "占便宜": [["zhàn"], ["pián"], ["yi"]],
    "方便": [["fāng"], ["biàn"]],
    "便利": [["biàn"], ["lì"]],
    "即便": [["jí"], ["biàn"]],
    "随手便": [["suí"], ["shǒu"], ["biàn"]],

    # 觉: jué (feel) vs jiào (sleep)
    "睡觉": [["shuì"], ["jiào"]],
    "觉得": [["jué"], ["de"]],
    "感觉": [["gǎn"], ["jué"]],
    "发觉": [["fā"], ["jué"]],
    "午觉": [["wǔ"], ["jiào"]],

    # 乐: lè (happy) vs yuè (music)
    "音乐": [["yīn"], ["yuè"]],
    "乐器": [["yuè"], ["qì"]],
    "快乐": [["kuài"], ["lè"]],
    "乐观": [["lè"], ["guān"]],

    # 长: cháng (long) vs zhǎng (grow/leader)
    "长江": [["cháng"], ["jiāng"]],
    "很长": [["hěn"], ["cháng"]],
    "长城": [["cháng"], ["chéng"]],
    "长大": [["zhǎng"], ["dà"]],
    "校长": [["xiào"], ["zhǎng"]],
    "市长": [["shì"], ["zhǎng"]],
    "生长": [["shēng"], ["zhǎng"]],

    # 重: zhòng (heavy/important) vs chóng (repeat/again)
    "重新": [["chóng"], ["xīn"]],
    "重复": [["chóng"], ["fù"]],
    "重写": [["chóng"], ["xiě"]],
    "重要": [["zhòng"], ["yào"]],
    "重量": [["zhòng"], ["liàng"]],

    # 都: dōu (all) vs dū (metropolis/capital)
    "都是": [["dōu"], ["shì"]],
    "首都": [["shǒu"], ["dū"]],
    "都市": [["dū"], ["shì"]],

    # 没: méi (not have) vs mò (submerge)
    "没有": [["méi"], ["yǒu"]],
    "没关系": [["méi"], ["guān"], ["xi"]],
    "淹没": [["yān"], ["mò"]],
    "没收": [["mò"], ["shōu"]],

    # 还: hái (still/yet) vs huán (return)
    "还有": [["hái"], ["yǒu"]],
    "还是": [["hái"], ["shì"]],
    "还给": [["huán"], ["gěi"]],
    "还书": [["huán"], ["shū"]],
    "归还": [["guī"], ["huán"]],
}

# Load custom phrases into pypinyin
load_phrases_dict(POLYPHONE_PHRASES)

HANZI_REGEX = re.compile(r'[\u4e00-\u9fa5]')


class PinyinAligner:
    """Production-grade Pinyin alignment and polyphone disambiguation engine."""

    def __init__(self):
        # Initialize jieba
        jieba.initialize()

    @staticmethod
    def is_hanzi(char: str) -> bool:
        """Check if character is a Chinese Hanzi glyph."""
        return '\u4e00' <= char <= '\u9fa5'

    def count_hanzi(self, text: str) -> int:
        """Count total Hanzi glyphs in text."""
        return sum(1 for ch in text if self.is_hanzi(ch))

    def _disambiguate_token(self, word: str, flag: str) -> List[str]:
        """Convert a segmented token into individual character pinyin with POS context."""
        # 1. Pypinyin phrase lookup
        raw_pys = [s[0] for s in pinyin(word, style=Style.TONE)]

        # 2. Grammar & POS-based refinement
        # Case A: Structural particle 得 (ud) -> 'de'
        if word == '得' and flag in ('ud', 'u'):
            raw_pys = ['de']
        # Case B: Adverbial particle 地 (uv) -> 'de'
        elif word == '地' and flag in ('uv', 'u'):
            raw_pys = ['de']
        # Case C: Aspect particle 着 (uz) -> 'zhe'
        elif word == '着' and flag in ('uz', 'u'):
            raw_pys = ['zhe']
        # Case D: Structural particle 的 (uj) -> 'de'
        elif word == '的' and flag in ('uj', 'u'):
            raw_pys = ['de']
        # Case E: Particle 了 (ul) -> 'le'
        elif word == '了' and flag in ('ul', 'y', 'u'):
            raw_pys = ['le']
        # Case F: Token ending with 地 as adverb -> 'de'
        elif word.endswith('地') and len(word) > 1 and flag in ('d', 'ad', 'a', 'z'):
            raw_pys[-1] = 'de'
        # Case G: Token ending with 得 as complement -> 'de'
        elif word.endswith('得') and len(word) > 1 and word not in ('得到', '获得', '舍得', '心得'):
            raw_pys[-1] = 'de'
        # Case H: Token ending with 着 as aspect -> 'zhe'
        elif word.endswith('着') and len(word) > 1 and word not in ('着急', '着凉', '着火', '着迷'):
            raw_pys[-1] = 'zhe'

        return raw_pys

    def align_text(self, text: str) -> Tuple[str, List[Tuple[str, str]]]:
        """
        Generates 1-to-1 aligned Pinyin for all Hanzi in text.
        
        Returns:
            Tuple of:
            - space-separated Pinyin string
            - list of (hanzi_char, pinyin_syllable) pairs
        """
        words = list(pseg.cut(text))
        aligned_pairs: List[Tuple[str, str]] = []

        for w in words:
            word_str = w.word
            flag = w.flag
            # Only process tokens containing Hanzi
            hanzi_chars = [ch for ch in word_str if self.is_hanzi(ch)]
            if not hanzi_chars:
                continue

            # If the entire token is Hanzi
            if len(hanzi_chars) == len(word_str):
                syllables = self._disambiguate_token(word_str, flag)
                if len(syllables) != len(hanzi_chars):
                    # Fallback character by character
                    syllables = [pinyin(ch, style=Style.TONE)[0][0] for ch in hanzi_chars]
                for ch, syl in zip(hanzi_chars, syllables):
                    aligned_pairs.append((ch, syl))
            else:
                # Mixed token (e.g. punctuation + Hanzi or letter + Hanzi)
                for ch in word_str:
                    if self.is_hanzi(ch):
                        syl = pinyin(ch, style=Style.TONE)[0][0]
                        aligned_pairs.append((ch, syl))

        # Verification check: count must match exactly
        total_hanzi = self.count_hanzi(text)
        if len(aligned_pairs) != total_hanzi:
            raise ValueError(
                f"Pinyin alignment mismatch! Total Hanzi={total_hanzi}, "
                f"Aligned Syllables={len(aligned_pairs)} in text: {text[:40]}..."
            )

        pinyin_str = " ".join(syl for _, syl in aligned_pairs)
        return pinyin_str, aligned_pairs

    def align_passage(self, passage: Dict[str, Any]) -> Dict[str, Any]:
        """
        Aligns reading passage content and title.
        Ensures content_cn and pinyin fields are 100% matched.
        """
        updated = dict(passage)
        content_key = 'contentZh' if 'contentZh' in updated else 'content_cn'
        content = updated.get(content_key, '')
        
        if content:
            aligned_pinyin, pairs = self.align_text(content)
            updated['pinyin'] = aligned_pinyin
            updated['_aligned_syllables_count'] = len(pairs)
            updated['_hanzi_count'] = self.count_hanzi(content)

        return updated


def main():
    parser = argparse.ArgumentParser(description="HI Chinese - Pinyin Aligner & Polyphone Pipeline")
    parser.add_argument("--text", type=str, help="Single Chinese text to align")
    parser.add_argument("--input-file", type=str, help="Path to JSON file containing reading passages")
    parser.add_argument("--output-file", type=str, help="Path to save aligned JSON")
    parser.add_argument("--fix-seed", action="store_true", help="Align and update assets/data/hsk_seed_fixture_v1.json")
    parser.add_argument("--verify", type=str, help="Verify 1-to-1 alignment of an existing JSON file")

    args = parser.parse_args()
    aligner = PinyinAligner()

    if args.text:
        pinyin_str, pairs = aligner.align_text(args.text)
        print(f"Original Text: {args.text}")
        print(f"Hanzi Count:   {len(pairs)}")
        print(f"Pinyin:        {pinyin_str}")
        print("\nAlignment Breakdown:")
        for ch, syl in pairs:
            print(f"  {ch} -> {syl}")
        return

    if args.verify:
        with open(args.verify, 'r', encoding='utf-8') as f:
            data = json.load(f)
        passages = data.get('readingPassages', [])
        print(f"Verifying {len(passages)} passages in {args.verify}...")
        all_ok = True
        for p in passages:
            pid = p.get('id', 'unknown')
            content = p.get('contentZh') or p.get('content_cn', '')
            py = p.get('pinyin', '')
            hanzi_count = aligner.count_hanzi(content)
            syl_count = len(py.split())
            if hanzi_count == syl_count:
                print(f"  [OK] {pid}: Hanzi={hanzi_count}, Pinyin Syllables={syl_count}")
            else:
                print(f"  [MISMATCH] {pid}: Hanzi={hanzi_count}, Pinyin Syllables={syl_count}")
                all_ok = False
        if all_ok:
            print("\nALL PASSAGES 100% PERFECTLY ALIGNED!")
        else:
            print("\nALIGNMENT MISMATCHES DETECTED!")
            sys.exit(1)
        return

    if args.fix_seed:
        seed_path = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "data", "hsk_seed_fixture_v1.json")
        seed_path = os.path.normpath(seed_path)
        print(f"Aligning reading passages in {seed_path}...")
        with open(seed_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        passages = data.get('readingPassages', [])
        for i, p in enumerate(passages):
            aligned = aligner.align_passage(p)
            # Remove debug keys before saving
            aligned.pop('_aligned_syllables_count', None)
            aligned.pop('_hanzi_count', None)
            passages[i] = aligned
            print(f"  Aligned {aligned['id']}: {aligner.count_hanzi(aligned['contentZh'])} syllables.")

        data['readingPassages'] = passages
        with open(seed_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print("Updated assets/data/hsk_seed_fixture_v1.json successfully!")
        return

    if args.input_file:
        with open(args.input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        if isinstance(data, list):
            results = [aligner.align_passage(item) for item in data]
        elif isinstance(data, dict) and 'readingPassages' in data:
            data['readingPassages'] = [aligner.align_passage(p) for p in data['readingPassages']]
            results = data
        else:
            results = aligner.align_passage(data)

        out_path = args.output_file or args.input_file
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        print(f"Aligned output written to {out_path}")
        return

    parser.print_help()


if __name__ == "__main__":
    main()
