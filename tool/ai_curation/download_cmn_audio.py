#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HI Chinese - AI Curation Tool
Real Human Audio Acquisition & Normalization from audio-cmn
File: tool/ai_curation/download_cmn_audio.py

Features:
- Downloads authentic native Mandarin pronunciation recordings from the open-source
  `audio-cmn` project (hugolpz / Wikimedia Commons, Yue Tan, CC BY-SA).
- Targets HSK 4, HSK 5, and HSK 6 vocabularies from `assets/data/hsk[4-6]_vocabularies.json`.
- Normalizes all audio with FFmpeg to professional broadcasting standards:
  - Format: MP3 (MPEG-1 Audio Layer 3)
  - Sample rate: 24,000 Hz
  - Channels: Mono (1)
  - Bitrate: 64 kbps
  - Loudness: -16 LUFS (EBU R128 standard via loudnorm filter)
- Saves audio to: `assets/audio/vocab/hsk<level>_{simplified}.mp3`.
- Exports comprehensive coverage matrix to: `data_pipeline/reports/audio_coverage_report.json`.
"""

import sys
import os
import json
import time
import argparse
import urllib.request
import urllib.parse
import subprocess
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Any, Optional, Set, Tuple

# Enable static_ffmpeg if available
try:
    import static_ffmpeg
    static_ffmpeg.add_paths()
except ImportError:
    pass

CMN_WORDS_LIST_URL = "https://raw.githubusercontent.com/hugolpz/audio-cmn/master/lists/cmn-audios_words.txt"
CMN_RAW_AUDIO_URL_64K = "https://raw.githubusercontent.com/hugolpz/audio-cmn/master/64k/hsk/cmn-{word}.mp3"
CMN_RAW_AUDIO_URL_96K = "https://raw.githubusercontent.com/hugolpz/audio-cmn/master/96k/hsk/cmn-{word}.mp3"


class CmnAudioDownloader:
    """Acquires, normalizes, and reports on native Mandarin pronunciations from audio-cmn."""

    def __init__(
        self,
        base_dir: Optional[str] = None,
        output_dir: Optional[str] = None,
        report_path: Optional[str] = None,
        workers: int = 12,
        sample_rate: int = 24000,
        bitrate_kbps: int = 64,
        target_lufs: float = -16.0,
    ):
        if base_dir is None:
            # Detect project root from tool/ai_curation
            self.base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        else:
            self.base_dir = base_dir

        self.output_dir = output_dir or os.path.join(self.base_dir, "assets", "audio", "vocab")
        self.report_path = report_path or os.path.join(self.base_dir, "data_pipeline", "reports", "audio_coverage_report.json")
        self.cache_dir = os.path.join(self.base_dir, "data_pipeline", "cache")
        self.workers = workers
        self.sample_rate = sample_rate
        self.bitrate_kbps = bitrate_kbps
        self.target_lufs = target_lufs

        os.makedirs(self.output_dir, exist_ok=True)
        os.makedirs(os.path.dirname(self.report_path), exist_ok=True)
        os.makedirs(self.cache_dir, exist_ok=True)

        self._cmn_word_set: Optional[Set[str]] = None

    def get_cmn_word_set(self) -> Set[str]:
        """Loads or fetches the list of available words in audio-cmn."""
        if self._cmn_word_set is not None:
            return self._cmn_word_set

        cache_file = os.path.join(self.cache_dir, "cmn-audios_words.txt")
        if os.path.exists(cache_file) and os.path.getsize(cache_file) > 1000:
            with open(cache_file, "r", encoding="utf-8") as f:
                self._cmn_word_set = set(line.strip() for line in f if line.strip())
            print(f"[CmnAudioDownloader] Loaded {len(self._cmn_word_set)} cmn words from local cache.")
            return self._cmn_word_set

        print(f"[CmnAudioDownloader] Fetching cmn-audios_words index from {CMN_WORDS_LIST_URL}...")
        req = urllib.request.Request(CMN_WORDS_LIST_URL, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                content = resp.read().decode("utf-8")
                words = [line.strip() for line in content.splitlines() if line.strip()]
                with open(cache_file, "w", encoding="utf-8") as f:
                    f.write("\n".join(words))
                self._cmn_word_set = set(words)
                print(f"[CmnAudioDownloader] Cached {len(self._cmn_word_set)} cmn words.")
                return self._cmn_word_set
        except Exception as e:
            print(f"[CmnAudioDownloader] Warning: Could not fetch cmn word list: {e}")
            self._cmn_word_set = set()
            return self._cmn_word_set

    def load_vocabularies(self, hsk_level: int) -> List[Dict[str, Any]]:
        """Loads vocabulary list for a given HSK level."""
        path = os.path.join(self.base_dir, "assets", "data", f"hsk{hsk_level}_vocabularies.json")
        if not os.path.exists(path):
            print(f"[CmnAudioDownloader] File not found: {path}")
            return []

        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        if isinstance(data, list):
            return data
        return data.get("vocabularies", [])

    def download_and_normalize_word(
        self,
        hsk_level: int,
        simplified: str,
        temp_dir: str,
    ) -> Tuple[bool, str]:
        """
        Downloads a single word from audio-cmn and normalizes it to:
        `assets/audio/vocab/hsk<level>_{simplified}.mp3`
        """
        output_filename = f"hsk{hsk_level}_{simplified}.mp3"
        final_path = os.path.join(self.output_dir, output_filename)

        # Skip if already exists and valid size
        if os.path.exists(final_path) and os.path.getsize(final_path) > 1000:
            return True, "already_exists"

        encoded_word = urllib.parse.quote(simplified)
        urls_to_try = [
            CMN_RAW_AUDIO_URL_64K.format(word=encoded_word),
            CMN_RAW_AUDIO_URL_96K.format(word=encoded_word),
        ]

        raw_path = os.path.join(temp_dir, f"raw_hsk{hsk_level}_{simplified}_{os.getpid()}_{time.time_ns()}.mp3")
        downloaded = False

        for url in urls_to_try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            for attempt in range(3):
                try:
                    with urllib.request.urlopen(req, timeout=12) as resp:
                        audio_bytes = resp.read()
                        if len(audio_bytes) > 500:
                            with open(raw_path, "wb") as f:
                                f.write(audio_bytes)
                            downloaded = True
                            break
                except Exception:
                    time.sleep(0.5 + attempt * 0.5)
            if downloaded:
                break

        if not downloaded:
            return False, "download_failed"

        # FFmpeg normalization to -16 LUFS, 24kHz, Mono, 64kbps
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

        if res.returncode == 0 and os.path.exists(final_path) and os.path.getsize(final_path) > 500:
            return True, "downloaded_and_normalized"
        else:
            return False, f"ffmpeg_error: {res.stderr[:100]}"

    def process_level(
        self,
        hsk_level: int,
        limit: Optional[int] = None,
        verify_only: bool = False,
    ) -> Dict[str, Any]:
        """Processes vocabularies for a single HSK level."""
        vocabs = self.load_vocabularies(hsk_level)
        if not vocabs:
            return {
                "hsk_level": hsk_level,
                "total": 0,
                "human_audio_count": 0,
                "coverage_pct": 0.0,
                "missing_for_tts_count": 0,
                "missing_words": [],
            }

        cmn_words = self.get_cmn_word_set()
        total_count = len(vocabs)

        if limit is not None:
            vocabs = vocabs[:limit]

        print(f"\n[HSK {hsk_level}] Processing {len(vocabs)}/{total_count} vocabularies...")
        
        words_in_cmn = []
        missing_for_tts = []

        for v in vocabs:
            simplified = v.get("simplified", "")
            if simplified in cmn_words:
                words_in_cmn.append(v)
            else:
                missing_for_tts.append({
                    "id": v.get("id", ""),
                    "simplified": simplified,
                    "pinyin": v.get("pinyin", ""),
                    "meaning_vi": (v.get("senses") or [{}])[0].get("meaning_vi", ""),
                })

        print(f"[HSK {hsk_level}] Found in audio-cmn: {len(words_in_cmn)}/{len(vocabs)} ({len(words_in_cmn)/len(vocabs)*100:.1f}%)")
        print(f"[HSK {hsk_level}] Missing (routed to TTS): {len(missing_for_tts)}")

        success_count = 0
        if not verify_only:
            temp_dir = os.path.join(self.cache_dir, f"temp_hsk{hsk_level}")
            os.makedirs(temp_dir, exist_ok=True)

            print(f"[HSK {hsk_level}] Downloading and normalizing {len(words_in_cmn)} audio files with {self.workers} workers...")
            with ThreadPoolExecutor(max_workers=self.workers) as executor:
                future_to_word = {
                    executor.submit(
                        self.download_and_normalize_word,
                        hsk_level,
                        v["simplified"],
                        temp_dir,
                    ): v["simplified"]
                    for v in words_in_cmn
                }

                completed = 0
                for future in as_completed(future_to_word):
                    word = future_to_word[future]
                    try:
                        ok, status = future.result()
                        if ok:
                            success_count += 1
                    except Exception as e:
                        print(f"  Error on {word}: {e}")
                    completed += 1
                    if completed % 100 == 0 or completed == len(words_in_cmn):
                        print(f"  [{completed}/{len(words_in_cmn)}] Downloaded & normalized ({success_count} success)")

            # Clean temp directory
            try:
                os.rmdir(temp_dir)
            except OSError:
                pass
        else:
            success_count = len(words_in_cmn)

        coverage_pct = round((len(words_in_cmn) / len(vocabs)) * 100, 2) if vocabs else 0.0

        return {
            "hsk_level": hsk_level,
            "total_vocabularies": len(vocabs),
            "human_audio_available": len(words_in_cmn),
            "human_audio_downloaded": success_count,
            "coverage_pct": coverage_pct,
            "missing_for_tts_count": len(missing_for_tts),
            "missing_words_for_tts": missing_for_tts,
        }

    def run(
        self,
        levels: List[int],
        limit: Optional[int] = None,
        verify_only: bool = False,
    ) -> Dict[str, Any]:
        """Runs the entire pipeline across requested levels and exports the coverage report."""
        start_time = time.time()
        print(f"=== HI Chinese: audio-cmn Acquisition Pipeline ===")
        print(f"Levels: {levels} | Target LUFS: {self.target_lufs} | Format: Mono {self.bitrate_kbps}kbps @ {self.sample_rate}Hz")

        level_reports = {}
        total_vocab = 0
        total_human = 0
        total_missing = 0

        for lvl in levels:
            rep = self.process_level(lvl, limit=limit, verify_only=verify_only)
            level_reports[f"hsk{lvl}"] = rep
            total_vocab += rep["total_vocabularies"]
            total_human += rep["human_audio_available"]
            total_missing += rep["missing_for_tts_count"]

        overall_coverage = round((total_human / total_vocab) * 100, 2) if total_vocab else 0.0

        report = {
            "report_name": "HI Chinese Audio Acquisition & Coverage Matrix",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "source": "hugolpz/audio-cmn (Yue Tan / Wikimedia Commons, CC BY-SA 4.0)",
            "audio_spec": {
                "codec": "MP3 (MPEG-1 Audio Layer 3)",
                "sample_rate_hz": self.sample_rate,
                "channels": "Mono (1)",
                "bitrate_kbps": self.bitrate_kbps,
                "target_loudness_lufs": self.target_lufs,
                "naming_convention": "assets/audio/vocab/hsk<level>_{simplified}.mp3",
            },
            "summary": {
                "total_vocabularies": total_vocab,
                "total_human_audio_acquired": total_human,
                "total_missing_routed_to_tts": total_missing,
                "overall_coverage_pct": overall_coverage,
                "pipeline_duration_seconds": round(time.time() - start_time, 2),
            },
            "levels": level_reports,
        }

        with open(self.report_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

        print(f"\n=======================================================")
        print(f"Coverage Report saved to: {self.report_path}")
        print(f"Total Vocabularies:     {total_vocab}")
        print(f"Real Human Audio:       {total_human} ({overall_coverage}%)")
        print(f"Missing (To TTS):       {total_missing}")
        print(f"=======================================================\n")

        return report


def main():
    parser = argparse.ArgumentParser(description="HI Chinese - Real Human Audio Acquisition from audio-cmn")
    parser.add_argument("--hsk", type=int, nargs="+", default=[4, 5, 6], help="HSK levels to process (e.g. 4 5 6)")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of words per level (for testing)")
    parser.add_argument("--workers", type=int, default=12, help="Number of download/normalization workers")
    parser.add_argument("--verify-only", action="store_true", help="Only verify coverage without downloading audio files")
    parser.add_argument("--sample-rate", type=int, default=24000, help="Output audio sample rate (Hz)")
    parser.add_argument("--bitrate", type=int, default=64, help="Output MP3 bitrate (kbps)")

    args = parser.parse_args()

    downloader = CmnAudioDownloader(
        workers=args.workers,
        sample_rate=args.sample_rate,
        bitrate_kbps=args.bitrate,
    )
    downloader.run(
        levels=args.hsk,
        limit=args.limit,
        verify_only=args.verify_only,
    )


if __name__ == "__main__":
    main()
