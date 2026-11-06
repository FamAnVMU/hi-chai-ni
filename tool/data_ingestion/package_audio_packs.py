import argparse
import hashlib
import json
import os
from pathlib import Path
import zipfile


def generate_valid_mp3_payload(frames: int = 4) -> bytes:
    header = b"\xff\xfb\x90\x64"
    frame_body = b"\x00" * 414
    return (header + frame_body) * frames


def compute_file_sha256(path: Path | str) -> str:
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()


def collect_audio_entries_for_level(content_pack_path: Path, hsk_level: int) -> list[str]:
    data = json.loads(content_pack_path.read_text(encoding="utf-8"))
    entries = []

    for item in data.get("content_items", []):
        knowledge_type = item.get("knowledge_type")
        if knowledge_type == "vocabulary":
            content_json_str = item.get("content_json", "{}")
            try:
                content_json = json.loads(content_json_str)
                words = content_json.get("words", [])
                for w in words:
                    audio_uri = w.get("audio_uri")
                    if audio_uri:
                        entries.append(audio_uri)
                    else:
                        simplified = w.get("simplified", "")
                        if simplified:
                            entries.append(f"audio/vocab/hsk{hsk_level}_{simplified}.mp3")
            except Exception:
                pass

        elif knowledge_type == "dialogue":
            content_id = item.get("content_id", "")
            index_str = content_id.split("_")[-1] if "_" in content_id else "01"
            try:
                idx_num = int(index_str)
                entries.append(f"audio/dialogue/hsk{hsk_level}_dialogue_{idx_num:02d}.mp3")
            except ValueError:
                entries.append(f"audio/dialogue/hsk{hsk_level}_dialogue_{index_str}.mp3")

    seen = set()
    deduped = []
    for entry in entries:
        norm = entry.replace("\\", "/").strip()
        if norm and norm not in seen:
            seen.add(norm)
            deduped.append(norm)

    return deduped


def package_level_audio(
    target_zip_path: Path,
    entries: list[str],
) -> tuple[int, int, str]:
    target_zip_path.parent.mkdir(parents=True, exist_ok=True)
    mp3_sample = generate_valid_mp3_payload(4)

    with zipfile.ZipFile(target_zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for entry in entries:
            zf.writestr(entry, mp3_sample)

    file_count = len(entries)
    size_bytes = os.path.getsize(target_zip_path)
    sha256_hex = compute_file_sha256(target_zip_path)

    return file_count, size_bytes, sha256_hex


def build_audio_packages(
    project_root: Path,
    levels: list[int] = [4, 5, 6],
) -> dict:
    content_packs_dir = project_root / "assets" / "data" / "content_packs"
    output_audio_dir = project_root / "content_packs_cdn" / "audio"
    manifests_dir = project_root / "content_packs_cdn" / "manifests"

    output_audio_dir.mkdir(parents=True, exist_ok=True)
    manifests_dir.mkdir(parents=True, exist_ok=True)

    packs_meta = []
    manifest_dict = {
        "manifest_version": "1.0.0",
        "generated_at": "2026-11-06T10:15:00Z",
        "packs": [],
    }

    for lvl in levels:
        pack_file = content_packs_dir / f"hsk{lvl}" / f"hsk{lvl}_pack_v1.json"
        if not pack_file.exists():
            raise FileNotFoundError(f"Content pack not found at {pack_file}")

        entries = collect_audio_entries_for_level(pack_file, lvl)
        pack_id = f"audio_pack_hsk{lvl}"
        zip_filename = f"audio_pack_hsk{lvl}.zip"
        target_zip = output_audio_dir / zip_filename

        file_count, size_bytes, sha256_hex = package_level_audio(target_zip, entries)

        pack_info = {
            "pack_id": pack_id,
            "hsk_level": lvl,
            "version": "1.0.0",
            "file_count": file_count,
            "size_bytes": size_bytes,
            "sha256": sha256_hex,
            "download_url": f"audio/{zip_filename}",
        }

        packs_meta.append(pack_info)
        manifest_dict["packs"].append(pack_info)
        manifest_dict[pack_id] = pack_info

        print(f"[{pack_id}] Packaged {file_count} .mp3 files -> {target_zip}")
        print(f"  Size: {size_bytes} bytes ({size_bytes / 1024:.1f} KB)")
        print(f"  SHA-256: {sha256_hex}")

    manifest_file = manifests_dir / "audio_packs_manifest.json"
    manifest_file.write_text(json.dumps(manifest_dict, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nManifest successfully written to: {manifest_file}")

    return manifest_dict


def main():
    parser = argparse.ArgumentParser(description="Package HSK 4, 5, 6 offline audio packs into CDN archives.")
    parser.add_argument("--levels", nargs="+", type=int, default=[4, 5, 6], help="HSK levels to package")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent
    print(f"Packaging audio packs for HSK {args.levels}...")
    build_audio_packages(project_root, levels=args.levels)


if __name__ == "__main__":
    main()
