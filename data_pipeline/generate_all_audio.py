import asyncio
import os
import json
import zipfile
import hashlib
import edge_tts
from pipeline_config import (
    get_assets_data_dir,
    get_data_pipeline_dir,
    get_project_root,
)

PROJECT_ROOT = get_project_root()
CORPUS_PATH = str(get_assets_data_dir() / "sentences_corpus.json")
ASSETS_AUDIO_DIR = str(PROJECT_ROOT / "assets" / "audio")
CDN_DIR = str(PROJECT_ROOT / "content_packs_cdn")
PACKAGES_DIR = str(PROJECT_ROOT / "content_packs_cdn" / "packages")
MANIFESTS_DIR = str(PROJECT_ROOT / "content_packs_cdn" / "manifests")
STAGING_DIR = str(get_data_pipeline_dir() / "audio_staging")

os.makedirs(os.path.join(ASSETS_AUDIO_DIR, "hsk1"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_AUDIO_DIR, "hsk2"), exist_ok=True)
os.makedirs(PACKAGES_DIR, exist_ok=True)
os.makedirs(MANIFESTS_DIR, exist_ok=True)
os.makedirs(STAGING_DIR, exist_ok=True)

VOICE = "zh-CN-XiaoxiaoNeural"
SEM = asyncio.Semaphore(8)

async def generate_single_audio(text: str, output_path: str):
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True
    async with SEM:
        for attempt in range(3):
            try:
                comm = edge_tts.Communicate(text, VOICE)
                await comm.save(output_path)
                if os.path.exists(output_path) and os.path.getsize(output_path) > 500:
                    return True
            except Exception as e:
                await asyncio.sleep(1 + attempt * 2)
        return False

def compute_sha256(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

async def main():
    print("[Audio Pipeline] Loading sentences corpus...")
    with open(CORPUS_PATH, "r", encoding="utf-8") as f:
        corpus = json.load(f)

    sentences = corpus.get("sentences", [])
    print(f"Loaded {len(sentences)} sentences.")

    # Group sentences by HSK level
    by_level = {}
    for s in sentences:
        lvl = s["hsk_level"]
        by_level.setdefault(lvl, []).append(s)

    # 1. Process HSK 1 and HSK 2 directly into assets/audio/hsk[1-2]/
    for lvl in [1, 2]:
        target_dir = os.path.join(ASSETS_AUDIO_DIR, f"hsk{lvl}")
        sents = by_level.get(lvl, [])
        print(f"\n[HSK {lvl}] Generating {len(sents)} bundled audio files in {target_dir}...")
        tasks = []
        for s in sents:
            text = s.get("chinese", "")
            audios = s.get("audios", [])
            audio_id = audios[0]["audio_id"] if audios else str(s["id"]).replace("tat_", "")
            out_file = os.path.join(target_dir, f"{audio_id}.mp3")
            tasks.append((s, audio_id, out_file, generate_single_audio(text, out_file)))

        results = await asyncio.gather(*(t[3] for t in tasks))
        success_count = sum(1 for r in results if r)
        print(f"[HSK {lvl}] Successfully generated {success_count}/{len(tasks)} files.")

        # Update metadata for HSK 1 and 2
        for (s, audio_id, out_file, _), ok in zip(tasks, results):
            if ok:
                fsize = os.path.getsize(out_file)
                sha = compute_sha256(out_file)
                if s.get("audios"):
                    s["audios"][0]["status"] = "bundled"
                    s["audios"][0]["local_path"] = f"assets/audio/hsk{lvl}/{audio_id}.mp3"
                    s["audios"][0]["file_size_bytes"] = fsize
                    s["audios"][0]["checksum_sha256"] = sha
                    s["audios"][0]["audio_type"] = "studio_simulation"
                    s["audios"][0]["contributor"] = "Microsoft Edge TTS (XiaoxiaoNeural)"

    # 2. Process HSK 3, 4, 5, 6 into staging, create zip packages and manifests
    for lvl in [3, 4, 5, 6]:
        lvl_staging = os.path.join(STAGING_DIR, f"hsk{lvl}")
        os.makedirs(lvl_staging, exist_ok=True)
        sents = by_level.get(lvl, [])
        print(f"\n[HSK {lvl}] Generating {len(sents)} audio files in staging: {lvl_staging}...")

        tasks = []
        for s in sents:
            text = s.get("chinese", "")
            audios = s.get("audios", [])
            audio_id = audios[0]["audio_id"] if audios else str(s["id"]).replace("tat_", "")
            out_file = os.path.join(lvl_staging, f"{audio_id}.mp3")
            tasks.append((s, audio_id, out_file, generate_single_audio(text, out_file)))

        results = await asyncio.gather(*(t[3] for t in tasks))
        success_count = sum(1 for r in results if r)
        print(f"[HSK {lvl}] Successfully generated {success_count}/{len(tasks)} files in staging.")

        # Create Zip archive
        zip_filename = f"audio_pack_hsk{lvl}.zip"
        zip_path = os.path.join(PACKAGES_DIR, zip_filename)
        manifest_assets = []
        total_bytes = 0

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for (s, audio_id, out_file, _), ok in zip(tasks, results):
                if ok and os.path.exists(out_file):
                    arcname = f"{audio_id}.mp3"
                    zf.write(out_file, arcname)
                    fsize = os.path.getsize(out_file)
                    total_bytes += fsize
                    sha = compute_sha256(out_file)
                    manifest_assets.append({
                        "audio_id": audio_id,
                        "sentence_id": s["id"],
                        "relative_path": arcname,
                        "file_size_bytes": fsize,
                        "checksum_sha256": sha,
                        "status": "ready"
                    })
                    if s.get("audios"):
                        s["audios"][0]["status"] = "remote"
                        s["audios"][0]["file_size_bytes"] = fsize
                        s["audios"][0]["checksum_sha256"] = sha
                        s["audios"][0]["audio_type"] = "studio_simulation"
                        s["audios"][0]["contributor"] = "Microsoft Edge TTS (XiaoxiaoNeural)"

        pack_sha256 = compute_sha256(zip_path)
        pack_size = os.path.getsize(zip_path)
        print(f"[HSK {lvl}] Created {zip_filename}: {pack_size/(1024*1024):.2f} MB, SHA-256: {pack_sha256[:16]}...")

        # Write manifest
        manifest_data = {
            "pack_id": f"audio_pack_hsk{lvl}",
            "title": f"Gói âm thanh AI Studio HSK {lvl}",
            "hsk_level": lvl,
            "version": "1.0.0",
            "sentence_count": len(manifest_assets),
            "archive_filename": zip_filename,
            "archive_size_bytes": pack_size,
            "archive_sha256": pack_sha256,
            "total_uncompressed_bytes": total_bytes,
            "download_url": f"https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/packages/{zip_filename}",
            "assets": manifest_assets
        }

        manifest_path = os.path.join(MANIFESTS_DIR, f"audio_pack_hsk{lvl}_manifest.json")
        with open(manifest_path, "w", encoding="utf-8") as mf:
            json.dump(manifest_data, mf, ensure_ascii=False, indent=2)

    # 3. Save updated sentences_corpus.json
    print("\n[Audio Pipeline] Saving updated sentences_corpus.json...")
    with open(CORPUS_PATH, "w", encoding="utf-8") as f:
        json.dump(corpus, f, ensure_ascii=False, indent=2)

    print("[Audio Pipeline] All audio generated, zipped, and manifests created successfully!")

if __name__ == "__main__":
    asyncio.run(main())
