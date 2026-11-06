# HSK 4–6 Canonical Checksum Baseline & Integrity Specification

## 1. Specification Overview
- **Task ID:** CORE-HSK46-VI-001
- **Thread:** Thread 1 – Core Engine, Database & Content Platform
- **Scope:** Canonical SHA-256 baseline for HSK 4, HSK 5, and HSK 6 Content Packs.
- **Reference Code:**
  - Loader & Checksum Computation: [content_pack_manager.dart](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/content_packs/data/content_pack_manager.dart)
  - Remote Distribution & Trusted Catalog: [content_pack_remote_service.dart](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/content_packs/data/content_pack_remote_service.dart)
  - Content Pack Packager: [generate_hsk456_content_packs.py](file:///C:/Users/phama/Downloads/hi_chinese/tool/data_ingestion/generate_hsk456_content_packs.py)

---

## 2. Checksum Algorithm & Mathematical Rules

### 2.1 Cryptographic Primitive
- **Algorithm:** SHA-256 (FIPS 180-4, 256 bits, 32 bytes).
- **Output Encoding:** Hexadecimal lowercase string (64 characters).

### 2.2 Character Encoding & Normalization
- **Encoding:** UTF-8 (`utf8.encode()` in Dart, `.encode('utf-8')` in Python).
- **JSON Serialization Format:** Compact JSON representation:
  - Python: `json.dumps(data, ensure_ascii=False, separators=(',', ':'))`
  - Dart: `json.encode(data)`
- **Whitespace Handling:** Zero whitespace around delimiters (no spaces after colons `:` or commas `,`).
- **Unicode Escaping:** Unescaped UTF-8 characters (`ensure_ascii=False`). Chinese characters, Vietnamese diacritics, and punctuation are preserved as raw UTF-8 multibyte sequences.

### 2.3 Manifest Exclusion Rule
During hash computation and verification:
1. The JSON string is parsed into an in-memory dictionary/map.
2. The property `pack['manifest']['sha256']` is explicitly extracted and temporarily replaced with an empty string `""`:
   ```dart
   final normalizedManifest = Map<String, dynamic>.from(manifest);
   normalizedManifest['sha256'] = '';
   final copy = Map<String, dynamic>.from(decoded);
   copy['manifest'] = normalizedManifest;
   ```
3. The normalized structure is re-serialized using compact UTF-8 JSON.
4. SHA-256 is computed across the resulting bytes.
5. In Python verification:
   ```python
   pack["manifest"]["sha256"] = ""
   compact_json = json.dumps(pack, ensure_ascii=False, separators=(",", ":"))
   checksum = hashlib.sha256(compact_json.encode("utf-8")).hexdigest()
   ```

---

## 3. Production Content Pack Canonical Baseline Hashes

The following hashes represent the exact byte-level integrity baseline established in Phase 1:

| Content Pack ID | Level | File Path | File Size (Bytes) | Canonical SHA-256 Checksum |
|---|:---:|---|:---:|---|
| `hsk4_pack_v1` | HSK 4 | `assets/data/content_packs/hsk4/hsk4_pack_v1.json` | 683,297 | `0b4cbbcb3adeba1ae08d4b3b0952c0803923f3c007509736e7c66c2150bda492` |
| `hsk5_pack_v1` | HSK 5 | `assets/data/content_packs/hsk5/hsk5_pack_v1.json` | 1,036,492 | `fb9786804d342ac9e162a1c017a8a4eb87fbf8269f8e8308a19cc12fcd1b720d` |
| `hsk6_pack_v1` | HSK 6 | `assets/data/content_packs/hsk6/hsk6_pack_v1.json` | 1,544,224 | `0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf` |

### 3.1 CDN Mirror Parity
The mirrored packages located at:
- `content_packs_cdn/packages/hsk4_pack_v1.json`
- `content_packs_cdn/packages/hsk5_pack_v1.json`
- `content_packs_cdn/packages/hsk6_pack_v1.json`

possess 100% bitwise identity and identical SHA-256 signatures with the assets directory.

---

## 4. Trusted Catalog Pinning in Client Code

The client application enforces strict checksum verification in [content_pack_remote_service.dart](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/content_packs/data/content_pack_remote_service.dart#L39-L55):

```dart
ContentPackRemoteInfo(
  packId: 'hsk4_pack_v1',
  hskLevel: 4,
  version: '1.0.0',
  title: 'HSK 4 Content Pack',
  downloadUrl: 'https://cdn.hichinese.app/packs/hsk4_pack_v1.json',
  sizeBytes: 683297,
  sha256Checksum: '0b4cbbcb3adeba1ae08d4b3b0952c0803923f3c007509736e7c66c2150bda492',
),
ContentPackRemoteInfo(
  packId: 'hsk5_pack_v1',
  hskLevel: 5,
  version: '1.0.0',
  title: 'HSK 5 Content Pack',
  downloadUrl: 'https://cdn.hichinese.app/packs/hsk5_pack_v1.json',
  sizeBytes: 1036492,
  sha256Checksum: 'fb9786804d342ac9e162a1c017a8a4eb87fbf8269f8e8308a19cc12fcd1b720d',
),
ContentPackRemoteInfo(
  packId: 'hsk6_pack_v1',
  hskLevel: 6,
  version: '1.0.0',
  title: 'HSK 6 Content Pack',
  downloadUrl: 'https://cdn.hichinese.app/packs/hsk6_pack_v1.json',
  sizeBytes: 1544224,
  sha256Checksum: '0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf',
),
```

---

## 5. Phase 1 Checksum Invariance Rule

Under **READ-ONLY AUDIT** mode:
1. No production content pack has been altered or re-serialized.
2. All checksums remain invariant.
3. In Phase 3 (Ingestion), once Thread 2 completes sentence curation, any update to Content Packs will require a synchronized update to:
   - The file manifest `manifest.sha256`
   - The remote service catalog `sha256Checksum` in `content_pack_remote_service.dart`
   - The CDN mirror in `content_packs_cdn/packages/`
