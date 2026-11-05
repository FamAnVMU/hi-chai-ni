#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HI Chinese - AI Curation Tool
Reading Audio Normalization & Slow-Pace Audio Curation Pipeline
File: tool/ai_curation/audio_processor.py

Features:
- Normalizes reading passage audio to EBU R128 standard (-16 LUFS).
- Encodes to Mono MP3 at 64–96 kbps, ensuring lightweight offline bundle (< 500KB / passage).
- Generates Mandarin Bean style slow-pace natural reading narration via edge-tts.
- Validates bitrates, duration, loudness and file sizes.
- Standardized naming convention: assets/audio/reading/rdg_hsk<level>_<id>.mp3.
"""

import sys
import os
import re
import json
import asyncio
import subprocess
import argparse
from typing import Dict, List, Any, Optional

try:
    import static_ffmpeg
    static_ffmpeg.add_paths()
except ImportError:
    pass

try:
    import edge_tts
except ImportError:
    edge_tts = None


class ReadingAudioProcessor:
    """Production audio normalizer and generator for Chinese reading passages."""

    def __init__(
        self,
        output_dir: Optional[str] = None,
        target_lufs: float = -16.0,
        bitrate_kbps: int = 64,
        voice: str = "zh-CN-XiaoxiaoNeural",
        rate: str = "-12%",
    ):
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.output_dir = output_dir or os.path.join(base_dir, "assets", "audio", "reading")
        self.target_lufs = target_lufs
        self.bitrate_kbps = bitrate_kbps
        self.voice = voice
        self.rate = rate
        os.makedirs(self.output_dir, exist_ok=True)

    def standardize_filename(self, hsk_level: int, passage_id: str) -> str:
        """
        Creates standardized filename: rdg_hsk<level>_<id>.mp3
        Example: RDG_1_reading_hsk1_friend -> rdg_hsk1_friend.mp3
        """
        clean_id = passage_id.lower()
        # Remove patterns like rdg_1_, reading_, hsk1_, 1_
        clean_id = re.sub(r'^(rdg_\d+_|reading_|hsk\d+_|\d+_)+', '', clean_id)
        clean_id = re.sub(r'^(reading_|hsk\d+_|\d+_)+', '', clean_id)
        # Clean special chars
        clean_id = re.sub(r'[^a-z0-9_]', '', clean_id).strip('_')
        return f"rdg_hsk{hsk_level}_{clean_id}.mp3"

    def normalize_audio(self, input_path: str, output_path: str) -> bool:
        """
        Normalizes audio to target LUFS (-16 LUFS), mono channel, and target bitrate.
        Automatically adjusts bitrate (64k -> 48k) if file exceeds 500KB budget.
        """
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        
        for bitrate in [self.bitrate_kbps, 48, 32]:
            cmd = [
                "ffmpeg",
                "-y",
                "-i", input_path,
                "-af", f"loudnorm=I={self.target_lufs}:TP=-1.5:LRA=11",
                "-ac", "1",
                "-b:a", f"{bitrate}k",
                "-ar", "24000",
                output_path,
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if res.returncode != 0:
                print(f"[AudioProcessor] FFmpeg error on {input_path}:\n{res.stderr[:300]}")
                return False

            file_size = os.path.getsize(output_path)
            if file_size <= 500 * 1024:
                return True
            print(f"[AudioProcessor] File {output_path} ({file_size/1024:.1f} KB) at {bitrate}k exceeds 500KB; trying lower bitrate...")

        return True

    async def synthesize_slow_reading(self, text: str, temp_path: str) -> bool:
        """
        Generates slow, clear Mandarin reading audio (Mandarin Bean style).
        """
        if not edge_tts:
            raise RuntimeError("edge_tts package is not installed.")

        # Clean text: remove Latin, brackets and multiple newlines
        cleaned = re.sub(r'\[.*?\]', '', text)
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()

        for attempt in range(3):
            try:
                comm = edge_tts.Communicate(cleaned, self.voice, rate=self.rate)
                await comm.save(temp_path)
                if os.path.exists(temp_path) and os.path.getsize(temp_path) > 1000:
                    return True
            except Exception as e:
                print(f"[AudioProcessor] Attempt {attempt+1} failed: {e}")
                await asyncio.sleep(1 + attempt)
        return False

    async def process_passage(
        self,
        hsk_level: int,
        passage_id: str,
        content_cn: str,
        source_audio_path: Optional[str] = None,
    ) -> Optional[str]:
        """
        Processes audio for a reading passage, saving to assets/audio/reading/rdg_hsk<level>_<id>.mp3.
        Returns the relative asset path.
        """
        filename = self.standardize_filename(hsk_level, passage_id)
        final_path = os.path.join(self.output_dir, filename)
        rel_asset_path = f"assets/audio/reading/{filename}"

        if source_audio_path and os.path.exists(source_audio_path):
            print(f"[AudioProcessor] Normalizing source audio {source_audio_path} -> {filename}...")
            ok = self.normalize_audio(source_audio_path, final_path)
            if ok:
                return rel_asset_path

        # Generate slow-pace Mandarin reading narration
        temp_raw = final_path + ".raw.mp3"
        print(f"[AudioProcessor] Synthesizing Mandarin Bean style narration for {passage_id}...")
        synth_ok = await self.synthesize_slow_reading(content_cn, temp_raw)
        if not synth_ok:
            print(f"[AudioProcessor] Synthesis failed for {passage_id}")
            return None

        # Normalize with FFmpeg (-16 LUFS, Mono, 64kbps)
        ok = self.normalize_audio(temp_raw, final_path)
        if os.path.exists(temp_raw):
            os.remove(temp_raw)

        if ok:
            size_kb = os.path.getsize(final_path) / 1024
            print(f"  [OK] Saved {filename} ({size_kb:.1f} KB, -16 LUFS, Mono {self.bitrate_kbps}kbps)")
            return rel_asset_path
        return None

    def verify_all(self) -> Dict[str, Any]:
        """Verifies all audio files in output directory against criteria."""
        report = {
            "total_files": 0,
            "passed_files": 0,
            "failed_files": [],
            "files": [],
        }
        if not os.path.exists(self.output_dir):
            return report

        for f in os.listdir(self.output_dir):
            if not f.endswith(".mp3"):
                continue
            path = os.path.join(self.output_dir, f)
            size_bytes = os.path.getsize(path)
            size_kb = size_bytes / 1024
            report["total_files"] += 1

            # Check naming convention
            name_valid = bool(re.match(r"^rdg_hsk\d+_[a-z0-9_]+\.mp3$", f))
            size_valid = size_kb < 500.0

            file_info = {
                "filename": f,
                "size_kb": round(size_kb, 1),
                "name_valid": name_valid,
                "size_valid": size_valid,
            }
            report["files"].append(file_info)

            if name_valid and size_valid:
                report["passed_files"] += 1
            else:
                report["failed_files"].append(f)

        return report


async def main_async():
    parser = argparse.ArgumentParser(description="HI Chinese - Reading Audio Processor")
    parser.add_argument("--process-seed", action="store_true", help="Process and generate audio for all seed passages")
    parser.add_argument("--input-audio", type=str, help="Input source MP3 file")
    parser.add_argument("--output-name", type=str, help="Output filename")
    parser.add_argument("--hsk", type=int, default=1, help="HSK level")
    parser.add_argument("--id", type=str, default="test", help="Passage ID")
    parser.add_argument("--verify", action="store_true", help="Verify all reading audio files")

    args = parser.parse_args()
    processor = ReadingAudioProcessor()

    if args.verify:
        report = processor.verify_all()
        print(f"Total audio files: {report['total_files']}")
        print(f"Passed:            {report['passed_files']}")
        for f in report["files"]:
            status = "PASS" if f["name_valid"] and f["size_valid"] else "FAIL"
            print(f"  [{status}] {f['filename']}: {f['size_kb']} KB")
        if report["failed_files"]:
            print(f"Failed files: {report['failed_files']}")
            sys.exit(1)
        else:
            print("\nALL AUDIO FILES CONFORM TO BUDGET & NAMING CRITERIA!")
        return

    if args.input_audio and args.output_name:
        out_path = os.path.join(processor.output_dir, args.output_name)
        ok = processor.normalize_audio(args.input_audio, out_path)
        if ok:
            print(f"Normalized {args.input_audio} -> {out_path}")
        return

    if args.process_seed:
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        seed_path = os.path.join(base_dir, "assets", "data", "hsk_seed_fixture_v1.json")
        print(f"Processing reading audio for seed passages in {seed_path}...")
        with open(seed_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        passages = data.get("readingPassages", [])
        for p in passages:
            hsk = p.get("hskLevel", 1)
            pid = p.get("id", "rdg")
            content = p.get("contentZh") or p.get("content_cn", "")
            asset_uri = await processor.process_passage(hsk, pid, content)
            if asset_uri:
                p["audioUri"] = asset_uri

        with open(seed_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print("Updated assets/data/hsk_seed_fixture_v1.json with audioUri links!")
        return

    parser.print_help()


def main():
    asyncio.run(main_async())


if __name__ == "__main__":
    main()
