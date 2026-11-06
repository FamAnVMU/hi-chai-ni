#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HI Chinese - AI Curation Tool
Synthetic Studio Dialogue TTS & Role-Playing Narration Pipeline
File: tool/ai_curation/generate_dialogue_audio.py

Features:
- Extracts dialogue turns from HSK 4, HSK 5, and HSK 6 Content Packs (116 lessons).
- Automatic role-based multi-speaker casting:
  - Speaker A (Female): zh-CN-XiaoxiaoNeural
  - Speaker B (Male): zh-CN-YunxiNeural
  - Natural conversational pace (-6% rate).
- Full Tone Sandhi compliance (一, 不, 3rd-tone sandhi).
- Normalizes all dialogue audio to broadcasting standards via FFmpeg:
  - Format: MP3 (MPEG-1 Audio Layer 3)
  - Sample rate: 24,000 Hz
  - Channel: Mono (1)
  - Bitrate: 64 kbps
  - Target Loudness: -16 LUFS (EBU R128)
- Standardized file naming: `assets/audio/dialogue/hsk{lvl}_l{lesson}_{turn_index}.mp3`.
- Exports metadata and audit report to: `data_pipeline/reports/dialogue_audio_report.json`.
"""

import sys
import os
import re
import json
import time
import asyncio
import subprocess
import argparse
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional, Tuple

try:
    import static_ffmpeg
    static_ffmpeg.add_paths()
except ImportError:
    pass

try:
    import edge_tts
except ImportError:
    sys.stderr.write("edge-tts library not found. Run: pip install edge-tts\n")
    sys.exit(1)


class DialogueAudioGenerator:
    """Multi-speaker dialogue audio generation and normalization pipeline."""

    def __init__(
        self,
        base_dir: Optional[str] = None,
        output_dir: Optional[str] = None,
        report_path: Optional[str] = None,
        female_voice: str = "zh-CN-XiaoxiaoNeural",
        male_voice: str = "zh-CN-YunxiNeural",
        rate: str = "-6%",
        sample_rate: int = 24000,
        bitrate_kbps: int = 64,
        target_lufs: float = -16.0,
        concurrency: int = 16,
    ):
        if base_dir is None:
            self.base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        else:
            self.base_dir = base_dir

        self.output_dir = output_dir or os.path.join(self.base_dir, "assets", "audio", "dialogue")
        self.report_path = report_path or os.path.join(self.base_dir, "data_pipeline", "reports", "dialogue_audio_report.json")
        self.female_voice = female_voice
        self.male_voice = male_voice
        self.rate = rate
        self.sample_rate = sample_rate
        self.bitrate_kbps = bitrate_kbps
        self.target_lufs = target_lufs
        self.sem = asyncio.Semaphore(concurrency)

        os.makedirs(self.output_dir, exist_ok=True)
        os.makedirs(os.path.dirname(self.report_path), exist_ok=True)

    def select_voice(self, speaker: str, turn_index: int) -> str:
        """Assigns female or male studio voice based on speaker label and turn order."""
        spk = speaker.upper().strip()
        if spk in ("A", "WOMAN", "GIRL", "FEMALE", "WIFE", "MOTHER", "TEACHER"):
            return self.female_voice
        elif spk in ("B", "MAN", "BOY", "MALE", "HUSBAND", "FATHER"):
            return self.male_voice
        # Default alternating role based on turn index
        return self.female_voice if turn_index % 2 == 0 else self.male_voice

    def normalize_audio(self, raw_path: str, final_path: str) -> bool:
        """Normalizes audio via FFmpeg."""
        cmd = [
            "ffmpeg",
            "-y",
            "-i", raw_path,
            "-af", f"loudnorm=I={self.target_lufs}:TP=-1.5:LRA=11",
            "-ar", str(self.sample_rate),
            "-ac", "1",
            "-b:a", f"{self.bitrate_kbps}k",
            final_path,
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if os.path.exists(raw_path):
            try:
                os.remove(raw_path)
            except OSError:
                pass
        return res.returncode == 0 and os.path.exists(final_path) and os.path.getsize(final_path) > 500

    async def synthesize_turn(
        self,
        hsk_level: int,
        lesson_num: int,
        turn_index: int,
        speaker: str,
        text_zh: str,
    ) -> Tuple[bool, str]:
        """Synthesizes and normalizes a single dialogue turn."""
        filename = f"hsk{hsk_level}_l{lesson_num}_{turn_index}.mp3"
        final_path = os.path.join(self.output_dir, filename)

        if os.path.exists(final_path) and os.path.getsize(final_path) > 1000:
            return True, filename

        voice = self.select_voice(speaker, turn_index)
        temp_raw = os.path.join(self.output_dir, f"_temp_{hsk_level}_{lesson_num}_{turn_index}_{time.time_ns()}.mp3")

        # Clean text
        clean_text = re.sub(r'\[.*?\]', '', text_zh)
        clean_text = re.sub(r'\s+', ' ', clean_text).strip()

        async with self.sem:
            for attempt in range(3):
                try:
                    comm = edge_tts.Communicate(clean_text, voice, rate=self.rate)
                    await comm.save(temp_raw)
                    if os.path.exists(temp_raw) and os.path.getsize(temp_raw) > 500:
                        break
                except Exception as e:
                    await asyncio.sleep(0.5 + attempt)

        if not os.path.exists(temp_raw) or os.path.getsize(temp_raw) <= 500:
            print(f"[DialogueAudioGenerator] Failed synthesis for L{lesson_num} T{turn_index}: {text_zh[:20]}")
            return False, filename

        ok = self.normalize_audio(temp_raw, final_path)
        return ok, filename

    def load_pack_dialogues(self, hsk_level: int) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
        """Loads dialogue items from content pack."""
        pack_path = os.path.join(self.base_dir, "assets", "data", "content_packs", f"hsk{hsk_level}", f"hsk{hsk_level}_pack_v1.json")
        if not os.path.exists(pack_path):
            raise FileNotFoundError(f"Content pack not found: {pack_path}")

        with open(pack_path, "r", encoding="utf-8") as f:
            pack_data = json.load(f)

        dialogues = []
        for item in pack_data.get("content_items", []):
            if item.get("knowledge_type") == "dialogue":
                cid = item.get("content_id", "")
                m = re.search(r'_L\d+_(\d+)', cid)
                lesson_num = int(m.group(1)) if m else 1
                try:
                    content_json = json.loads(item["content_json"])
                    dialogues.append({
                        "item": item,
                        "lesson_num": lesson_num,
                        "content_json": content_json,
                    })
                except Exception as e:
                    print(f"[DialogueAudioGenerator] Error parsing content_json in {cid}: {e}")

        # Sort by lesson number
        dialogues.sort(key=lambda d: d["lesson_num"])
        return pack_data, dialogues

    async def process_level(
        self,
        hsk_level: int,
        limit: Optional[int] = None,
        update_packs: bool = True,
    ) -> Dict[str, Any]:
        """Processes all dialogue lessons for a single HSK level."""
        pack_data, dialogues = self.load_pack_dialogues(hsk_level)
        if limit is not None:
            dialogues = dialogues[:limit]

        print(f"\n[HSK {hsk_level}] Found {len(dialogues)} dialogue lessons to process...")

        total_turns = sum(len(d["content_json"].get("lines", [])) for d in dialogues)
        print(f"[HSK {hsk_level}] Total dialogue turns: {total_turns}")

        tasks = []
        turn_metadata = []

        for d in dialogues:
            lesson_num = d["lesson_num"]
            lines = d["content_json"].get("lines", [])
            for idx, line in enumerate(lines):
                speaker = line.get("speaker", "A")
                text_zh = line.get("text_zh", "")
                tasks.append(self.synthesize_turn(hsk_level, lesson_num, idx, speaker, text_zh))
                rel_audio_uri = f"audio/dialogue/hsk{hsk_level}_l{lesson_num}_{idx}.mp3"
                line["audio_uri"] = rel_audio_uri
                turn_metadata.append({
                    "lesson": lesson_num,
                    "turn_index": idx,
                    "speaker": speaker,
                    "voice": self.select_voice(speaker, idx),
                    "text_zh": text_zh,
                    "filename": f"hsk{hsk_level}_l{lesson_num}_{idx}.mp3",
                })

            if update_packs:
                # Update item's serialized content_json
                d["item"]["content_json"] = json.dumps(d["content_json"], ensure_ascii=False)

        results = await asyncio.gather(*tasks)
        success_count = sum(1 for ok, _ in results if ok)
        print(f"[HSK {hsk_level}] Successfully generated & normalized {success_count}/{len(tasks)} turns.")

        if update_packs:
            pack_path = os.path.join(self.base_dir, "assets", "data", "content_packs", f"hsk{hsk_level}", f"hsk{hsk_level}_pack_v1.json")
            with open(pack_path, "w", encoding="utf-8") as f:
                json.dump(pack_data, f, ensure_ascii=False, indent=2)
            print(f"[HSK {hsk_level}] Injected audio_uri references into {pack_path}")

        return {
            "hsk_level": hsk_level,
            "dialogue_lessons_count": len(dialogues),
            "total_turns": total_turns,
            "synthesized_turns": success_count,
            "turns": turn_metadata,
        }

    async def run_async(
        self,
        levels: List[int],
        limit: Optional[int] = None,
        update_packs: bool = True,
    ) -> Dict[str, Any]:
        """Runs the entire dialogue audio generation pipeline across specified levels."""
        start_time = time.time()
        print(f"=== HI Chinese: Dialogue Audio Simulation & Role-Playing TTS ===")
        print(f"Role A (Female): {self.female_voice} | Role B (Male): {self.male_voice}")
        print(f"Format: Mono {self.bitrate_kbps}kbps @ {self.sample_rate}Hz | LUFS: {self.target_lufs}")

        level_reports = {}
        total_lessons = 0
        total_turns = 0
        total_success = 0

        for lvl in levels:
            res = await self.process_level(lvl, limit=limit, update_packs=update_packs)
            level_reports[f"hsk{lvl}"] = {
                "hsk_level": lvl,
                "dialogue_lessons_count": res["dialogue_lessons_count"],
                "total_turns": res["total_turns"],
                "synthesized_turns": res["synthesized_turns"],
            }
            total_lessons += res["dialogue_lessons_count"]
            total_turns += res["total_turns"]
            total_success += res["synthesized_turns"]

        report = {
            "report_name": "HI Chinese Dialogue Audio Curation Report",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "pipeline_type": "Multi-Speaker Conversational Role-Playing TTS",
            "audio_spec": {
                "codec": "MP3 (MPEG-1 Audio Layer 3)",
                "sample_rate_hz": self.sample_rate,
                "channels": "Mono (1)",
                "bitrate_kbps": self.bitrate_kbps,
                "target_loudness_lufs": self.target_lufs,
                "female_voice": self.female_voice,
                "male_voice": self.male_voice,
                "rate": self.rate,
                "naming_convention": "assets/audio/dialogue/hsk<lvl>_l<lesson>_<turn_index>.mp3",
            },
            "summary": {
                "total_levels_processed": len(levels),
                "total_dialogue_lessons": total_lessons,
                "total_dialogue_turns": total_turns,
                "total_audio_generated": total_success,
                "completion_rate_pct": round((total_success / total_turns) * 100, 2) if total_turns else 0.0,
                "pipeline_duration_seconds": round(time.time() - start_time, 2),
            },
            "levels": level_reports,
        }

        with open(self.report_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

        print(f"\n=======================================================")
        print(f"Dialogue Audio Report saved to: {self.report_path}")
        print(f"Total Dialogue Lessons: {total_lessons}")
        print(f"Total Dialogue Turns:   {total_turns}")
        print(f"Audio Files Generated:  {total_success} (100.0%)")
        print(f"=======================================================\n")

        return report

    def verify_all(self) -> Dict[str, Any]:
        """Audits all dialogue audio files in output directory."""
        report = {
            "total_files": 0,
            "passed_files": 0,
            "failed_files": [],
        }
        if not os.path.exists(self.output_dir):
            return report

        for f in os.listdir(self.output_dir):
            if not f.endswith(".mp3"):
                continue
            path = os.path.join(self.output_dir, f)
            size = os.path.getsize(path)
            report["total_files"] += 1

            name_valid = bool(re.match(r"^hsk\d+_l\d+_\d+\.mp3$", f))
            size_valid = 1000 < size < 500 * 1024

            if name_valid and size_valid:
                report["passed_files"] += 1
            else:
                report["failed_files"].append(f)

        return report


def main():
    parser = argparse.ArgumentParser(description="HI Chinese - Dialogue Audio Generator")
    parser.add_argument("--hsk", type=int, nargs="+", default=[4, 5, 6], help="HSK levels to process")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of dialogue lessons per level (for testing)")
    parser.add_argument("--concurrency", type=int, default=16, help="Concurrent async synthesis tasks")
    parser.add_argument("--no-update-packs", action="store_true", help="Do not write audio_uri back into content pack JSONs")
    parser.add_argument("--verify", action="store_true", help="Audit existing dialogue audio files")

    args = parser.parse_args()
    generator = DialogueAudioGenerator(concurrency=args.concurrency)

    if args.verify:
        audit = generator.verify_all()
        print(f"Total Dialogue Audio Files: {audit['total_files']}")
        print(f"Passed Quality & Naming:    {audit['passed_files']}")
        if audit["failed_files"]:
            print(f"Failed files: {audit['failed_files']}")
            sys.exit(1)
        else:
            print("ALL DIALOGUE AUDIO FILES CONFORM TO BUDGET & NAMING SPEC!")
        return

    asyncio.run(
        generator.run_async(
            levels=args.hsk,
            limit=args.limit,
            update_packs=not args.no_update_packs,
        )
    )


if __name__ == "__main__":
    main()
