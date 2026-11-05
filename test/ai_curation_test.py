#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HI Chinese - AI Curation Test Suite
File: test/ai_curation_test.py

Verifies:
1. PinyinAligner:
   - 100% 1-to-1 Hanzi-to-syllable alignment.
   - Common polyphones (多音字): 着, 得, 地, 行, 会, 便, 觉, 乐, 长, etc.
2. TranslationVerifier:
   - Structured JSON output with translation_vi, question_vi, options_vi, explanation_vi.
3. ReadingAudioProcessor:
   - Files conform to 'rdg_hsk<level>_<id>.mp3' naming convention.
   - File size < 500 KB per reading passage.
"""

import sys
import os
import unittest
import json

# Add project root to sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from tool.ai_curation.pinyin_aligner import PinyinAligner
from tool.ai_curation.translation_verifier import TranslationVerifier
from tool.ai_curation.audio_processor import ReadingAudioProcessor


class TestPinyinAligner(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.aligner = PinyinAligner()

    def test_polyphone_de_di_de(self):
        """Tests disambiguation between structural 得, adverbial 地, and noun 地方."""
        # 得 -> de (complement)
        py, pairs = self.aligner.align_text("他高兴得跳了起来")
        pair_dict = dict(pairs)
        self.assertEqual(len(pairs), self.aligner.count_hanzi("他高兴得跳了起来"))
        self.assertIn(('得', 'de'), pairs)

        # 地 -> de (adverbial)
        py2, pairs2 = self.aligner.align_text("他慢慢地走过来")
        self.assertEqual(len(pairs2), self.aligner.count_hanzi("他慢慢地走过来"))
        self.assertIn(('地', 'de'), pairs2)

        # 地方 -> dì fang
        py3, pairs3 = self.aligner.align_text("这是个好地方")
        self.assertEqual(len(pairs3), self.aligner.count_hanzi("这是个好地方"))
        self.assertIn(('地', 'dì'), pairs3)

    def test_polyphone_zhe_zhao(self):
        """Tests aspect particle 着 (zhe) vs 着急 (zháo)."""
        py, pairs = self.aligner.align_text("他看着书，心里很着急")
        self.assertEqual(len(pairs), self.aligner.count_hanzi("他看着书，心里很着急"))
        # First 着 should be zhe (aspect)
        first_zhe = [syl for ch, syl in pairs if ch == '着'][0]
        self.assertEqual(first_zhe, 'zhe')
        # Second 着 should be zháo (anxious)
        second_zhe = [syl for ch, syl in pairs if ch == '着'][1]
        self.assertEqual(second_zhe, 'zháo')

    def test_polyphone_xing_hang(self):
        """Tests 行走 (xíng) vs 银行 (háng)."""
        py, pairs = self.aligner.align_text("一行人走进了中国银行")
        self.assertEqual(len(pairs), self.aligner.count_hanzi("一行人走进了中国银行"))
        xings = [syl for ch, syl in pairs if ch == '行']
        self.assertEqual(xings[0], 'xíng')
        self.assertEqual(xings[1], 'háng')

    def test_polyphone_hui_kuai(self):
        """Tests 开会 (huì) vs 会计 (kuài)."""
        py, pairs = self.aligner.align_text("今天开会，公司的会计也来了")
        self.assertEqual(len(pairs), self.aligner.count_hanzi("今天开会，公司的会计也来了"))
        huis = [syl for ch, syl in pairs if ch == '会']
        self.assertEqual(huis[0], 'huì')
        self.assertEqual(huis[1], 'kuài')

    def test_polyphone_bian_pian(self):
        """Tests 方便 (biàn) vs 便宜 (pián)."""
        py, pairs = self.aligner.align_text("超市很方便，东西也很便宜")
        self.assertEqual(len(pairs), self.aligner.count_hanzi("超市很方便，东西也很便宜"))
        biáns = [syl for ch, syl in pairs if ch == '便']
        self.assertEqual(biáns[0], 'biàn')
        self.assertEqual(biáns[1], 'pián')

    def test_strict_syllable_count_seed_fixture(self):
        """Verifies that all passages in seed fixture have 100% equal Hanzi and Pinyin syllables."""
        seed_path = os.path.join(PROJECT_ROOT, "assets", "data", "hsk_seed_fixture_v1.json")
        with open(seed_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        passages = data.get("readingPassages", [])
        self.assertGreater(len(passages), 0)

        for p in passages:
            content = p.get("contentZh") or p.get("content_cn", "")
            py = p.get("pinyin", "")
            hanzi_count = self.aligner.count_hanzi(content)
            syl_count = len(py.split())
            self.assertEqual(
                hanzi_count,
                syl_count,
                f"Mismatch in {p['id']}: Hanzi={hanzi_count} vs Pinyin Syllables={syl_count}",
            )


class TestTranslationVerifier(unittest.TestCase):
    def test_structured_json_contract(self):
        """Verifies that translation verifier returns all required contract fields."""
        verifier = TranslationVerifier(dry_run=True)
        res = verifier.translate_and_verify(
            content_cn="今天天气很好，我们去公园散步。",
            question_cn="他们打算去哪儿？",
            options_cn=["公园", "学校", "医院", "银行"],
            answer_index=0,
        )
        self.assertIn("translation_vi", res)
        self.assertIn("question_vi", res)
        self.assertIn("options_vi", res)
        self.assertIn("explanation_vi", res)
        self.assertEqual(len(res["options_vi"]), 4)
        self.assertTrue(len(res["translation_vi"]) > 5)
        self.assertTrue(len(res["explanation_vi"]) > 5)


class TestReadingAudioProcessor(unittest.TestCase):
    def test_all_audio_files_meet_criteria(self):
        """Verifies all audio in assets/audio/reading/ meet naming and size budget (<500KB)."""
        processor = ReadingAudioProcessor()
        report = processor.verify_all()
        self.assertGreater(report["total_files"], 0, "No audio files found in assets/audio/reading/")
        self.assertEqual(
            report["failed_files"],
            [],
            f"Some audio files failed criteria: {report['failed_files']}",
        )
        self.assertEqual(report["passed_files"], report["total_files"])


if __name__ == "__main__":
    unittest.main()
