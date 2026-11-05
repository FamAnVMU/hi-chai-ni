# T2 — Security Audit

**Auditor:** security (T2) · **Task:** task-2 · **Mode:** read-only static audit + artifact inspection (no `flutter`/`dart` build, analyze or test commands were run by T2, per task constraints — the Lead runs analyze, config-test runs the suite)
**Repo:** `C:\Users\phama\Downloads\hi_chinese` · **Snapshot:** working tree at `5c099ba` (version 1.0.9+10), git status clean
**Output:** this file only. No application source, pubspec, tests, `android/**`, or `data_pipeline/**` files were modified.

---

## 1. Scope summary

**In scope (read line-by-line where listed):**

| Area | Files |
|---|---|
| AI network / credentials | `lib/core/network/ai/ai_service.dart`, `interfaces/ai_provider.dart`, `providers/gemini_rest_ai_provider.dart`, `providers/mock_ai_provider.dart`, `security/ai_credential_storage.dart`, `models/ai_request.dart`, `ai_response.dart`, `ai_errors.dart`, `ai_model_config.dart`, `cancel_token.dart`, `connection_test_result.dart` |
| Android config | `android/app/src/main/AndroidManifest.xml`, `src/debug|profile/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/build.gradle.kts`, `gradle.properties`, `settings.gradle.kts`, `proguard-rules.pro`, **merged release manifest** in `build/app/intermediates/merged_manifests/release/…`, **built release APKs** in `release-apk/` (apksigner) |
| Content packs | `lib/features/content_packs/**` (`content_pack_manager.dart`, `content_pack_remote_service.dart`, providers/screen), `lib/features/curriculum/data/content_pack_loader.dart`, `content_packs_cdn/**`, `tool/generate_hsk3_cdn_pack.dart` |
| Audio packs / downloads | `lib/features/audio_management/**` (`audio_pack_downloader.dart`, `audio_storage_manager.dart`, `content_source_config.dart`, `audio_coverage_auditor.dart`, `audio_asset_dao.dart`, manifest models), plus the **live** zip path `lib/features/sentences/data/audio_pack_manager.dart` (reachable from `sentence_browser_screen.dart`) |
| Misc scoped files | `lib/core/utils/permission_helper.dart`, `lib/core/constants/app_constants.dart`, `lib/core/database/database_backup_helper.dart`, `lib/features/settings/data/services/data_management_service.dart` (backup/export/import), `.github/workflows/release.yml` |
| Python pipeline | all `data_pipeline/*.py` (46 scripts) — downloads, bz2 handling, zip creation, path joins, subprocess/eval/deserialization, secrets |
| Repo-wide | secret scan over working tree + **all 87 git commits** + release APK contents; SQL raw-query scan; WebView/deep-link/exported-component scan |

**Method:** `read` of every in-scope file with line-level re-verification of each quoted snippet; `grep` for dangerous sinks (`rawQuery`/`rawInsert`, `LIKE`, `eval`/`pickle`/`subprocess`, `WebView`, `wss://`, secret regexes); `apksigner verify --print-certs`; SHA-256 recomputation (Python `hashlib`) of committed CDN packs vs declared manifest values; git blob/history inspection.

> **Snippet convention:** every evidence block is verbatim source at the cited lines. Where a block intentionally omits intermediate lines it is labelled `(abridged, gaps marked …)`. Any `// ← …` or `<-- …` note inside a block is an auditor annotation, not source text.

**Limitations:** no emulator/device execution, no dynamic traffic capture, no fuzzing of pack parsers. "CONFIRMED" below = code path and evidence verified in source/artifact; "LIKELY" = framework/OS behaviour plus code, not executed; "RISK" = residual exposure that depends on third-party or user action. Line numbers are for the snapshot above.

---

## 2. Trust model (assets, adversaries, boundaries)

| Asset | Where it lives | Relevant adversary |
|---|---|---|
| User's Gemini API key (BYOK = the learner's own money/quota) | `flutter_secure_storage`; copied per request into `x-goog-api-key` header | malicious proxy operator / social engineering; local app via exported UI; anyone with the device (backup/memory) |
| Learner PII + learning history (profile, chat, evidence, SRS) | `hi_chinese.db` (app-private), `.hibak` backup copies, "export JSON" → **clipboard** | cloud/OS backup, other apps on old Android reading clipboard, device thief |
| Curriculum content + exam answers ("source of truth" for grading) | bundled JSON assets (APK-signed) + remote packs from `raw.githubusercontent.com/FamAnVMU/hi-chai-ni` | compromised/abusive CDN repo, TLS interception with a trusted CA |
| APK signing identity / update channel | GitHub Releases for sideload; Play future | attacker who obtains the debug keystore; fake-update/phishing distribution |

No backend server, no auth server, no WebView, no registered deep-link intent filter, no native code beyond `FlutterActivity` — those attack surfaces were checked and are absent (see §6).

---

## 3. Top 5 priority order

1. **[T2-F02] Content-pack integrity control is a hard-coded no-op; the published HSK-3 pack already fails its own SHA-256 and is force-accepted** — the app silently installs any JSON claiming that hash, from a third-party GitHub repo with no signature. Curriculum DB rows + exam content are writable by that JSON. *High / CONFIRMED.*
2. **[T2-F01] Release APKs shipped to users are signed with the Android debug certificate** (`CN=Android Debug`, verified with `apksigner`) and are published via README links + GitHub Releases (`.github/workflows/release.yml`). *High / CONFIRMED.*
3. **[T2-F05] The Gemini key is forwarded to any user-typed proxy host; the "no loopback/private IP + HTTPS" validation is incomplete and is bypassed entirely by `verifyCredentials()`/`testConnection()`** (which don't call `_resolveSecureBaseUrl`). *Medium / CONFIRMED (code) / LIKELY (exploit).*
4. **[T2-F03] Downloaded audio-pack ZIPs have no effective integrity verification and no size/time bounds** — verification is conditional on a manifest file that cannot exist on-device; harness still extracts with full memory buffering. *Medium / CONFIRMED (live UI path; checksum silently skipped).*
5. **[T2-F06] Android Auto Backup is enabled (no `allowBackup`, no extraction rules): the unencrypted learner DB and unencrypted `.hibak` DB copies are eligible for cloud backup / device-to-device transfer.** *Medium / CONFIRMED.*

---

## 4. Severity / confidence counts

| Severity | Count | IDs |
|---|---|---|
| Critical | 0 | — |
| High | 2 | F01, F02 |
| Medium | 4 | F03, F04, F05, F06 |
| Low | 9 | F07–F15 |
| **Total** | **15** | |

Confidence: F01, F02, F03, F05, F06, F09, F10, F11, F13, F14, F15 = CONFIRMED code/artifact evidence; F04 = CONFIRMED code defect with **latent** reachability (no production caller today); F07 = CONFIRMED; F12 = CONFIRMED (user action required); F08 = LIKELY (Flutter framework default deep-link behaviour + exported activity; in-app route code is otherwise dead — cross-check Lead signal L-06).

---

## 5. Findings

### [T2-F01] Release APK is signed with the Android debug certificate and published to end users

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `android/app/build.gradle.kts:26-35`; `.github/workflows/release.yml:40-42`; artifacts `release-apk/app-release.apk`, `release-apk/hi-chinese-v1.0.9-arm64.apk`; `README.md:15-16`
- **CWE:** CWE-321 (Use of Hard-coded Cryptographic Key — Android debug signing key fallback); chain also violates release-integrity requirements (MASVS-RESILIENCE)
- **Evidence:**

```kotlin
// android/app/build.gradle.kts:26-35
    buildTypes {
        release {
            // Configure signing config: fall back to debug signing only when release keystore is not yet set up
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
```

The file defines **no** `signingConfigs { create("release") { … } }` block at all, so `findByName("release")` is always `null` → the debug config is always used. Verified against the shipped artifacts (not just config):

```
> apksigner verify --print-certs release-apk/app-release.apk
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 20f6ccb1afa034fdd71be65c1cb6cbca56845bc3ee1e8c51ab3b6388de90567a
> apksigner verify --print-certs release-apk/hi-chinese-v1.0.9-arm64.apk   → same certificate

// .github/workflows/release.yml:40-42
          files: |
            release-apk/hi-chinese-v1.0.9-arm64.apk
            release-apk/app-release.apk
```

- **Attack scenario / root cause:** A release build silently degrades to the well-known public debug signing identity (`CN=Android Debug`, default alias/password `androiddebugkey`/`android`) instead of failing. The project then (a) commits the APKs to git, (b) `README.md:15-16` links them as direct downloads, and (c) the release workflow attaches the same files to GitHub Releases. Consequences: Google Play will reject the package; users who sideload receive an app whose update identity is a debug cert, and anyone who ever obtains/copies the developer's `~/.android/debug.keystore` can sign a malicious APK with the same package name and a higher `versionCode` that Android accepts as an in-place update; debug certs are also not managed as durable release keys (limited validity / no rotation discipline) and the identity is shared with any other build made on the same machine. The doc `docs/agent-coordination/reports/thread-5/apk-build-report.md:37` openly admits *"Standard Flutter debug/release default keystore applied for local distribution"*, so this is not a hidden side-effect — it is the shipped status quo.
- **Impact:** Broken update trust chain for all sideloaded users; store distribution blocked; account/data compromise of users if the debug key material ever leaks; supply-chain phishing of "new version" APKs impossible to distinguish by signature.
- **Fix:** Create a real release keystore outside the repo (`*.jks` is already gitignored) and require it:
  ```kotlin
  android {
      signingConfigs {
          create("release") {
              val props = java.util.Properties().apply {
                  val f = rootProject.file("key.properties"); if (f.exists()) f.inputStream().use { load(it) }
              }
              storeFile = file(props.getProperty("storeFile") ?: error("release keystore missing"))
              storePassword = props.getProperty("storePassword")
              keyAlias = props.getProperty("keyAlias")
              keyPassword = props.getProperty("keyPassword")
          }
      }
      buildTypes { release { signingConfig = signingConfigs.getByName("release") } }
  }
  // delete the `?: signingConfigs.getByName("debug")` fallback; the build must FAIL when unsigned
  ```
  Add an `apksigner verify --print-certs | grep -q "CN=Android Debug" && exit 1` CI gate, stop committing `release-apk/*.apk`, and sign builds in CI with an encrypted keystore. If any debug-signed build ever reached users, rotate distribution identity (new `applicationId` or explicit migration instructions).
- **Verification status:** Config read + `apksigner` on both release artifacts + release workflow + README links verified. Cross-team note: T5 (config/test) also owns Android release config; this is independently reproduced here because it is a security release-integrity defect.

---

### [T2-F02] Remote content-pack "SHA-256 integrity check" is a hard-coded no-op; shipped HSK-3 pack is already mismatched and force-accepted

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/content_packs/data/content_pack_manager.dart:109-121`; `lib/features/content_packs/data/content_pack_remote_service.dart:83-105, 120-148`; generator `tool/generate_hsk3_cdn_pack.dart:169-177`; artifact `content_packs_cdn/hsk3_pack_v1.json`; test `test/features/content_packs/content_pack_service_test.dart:84-116`
- **CWE:** CWE-345 (Insufficient Verification of Data Authenticity); CWE-494 (Download of Code Without Integrity Check)
- **Evidence — the bypass itself:**

```dart
// lib/features/content_packs/data/content_pack_manager.dart:109-121
    // 3. Checksum check if specified
    if (rawJson != null && manifest.sha256.isNotEmpty) {
      final actualSha = computeChecksum(rawJson);
      final isKnownValid = manifest.packId == 'hsk3_pack_v1' &&
          manifest.sha256.toLowerCase() ==
              '434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2';
      if (actualSha.toLowerCase() != manifest.sha256.toLowerCase() && !isKnownValid) {
        throw ContentPackManagerException(
          'Mã băm SHA-256 không hợp lệ (kỳ vọng: ${manifest.sha256}, thực tế: $actualSha). Dữ liệu có thể bị hư hỏng.',
          packId: manifest.packId,
        );
      }
    }
```

**Evidence — the shipped pack does not match its declared hash** (recomputed from the committed blob that GitHub serves as `main`):

| Value | SHA-256 |
|---|---|
| Actual bytes of committed `content_packs_cdn/hsk3_pack_v1.json` (8,885 B) | `22e69bcc7686019a05282d2afbbe0ddeb659a5b7e186723c785efdb1d4b67626` |
| `manifest.sha256` declared inside that same file | `434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2` |
| Hash hard-coded in `isKnownValid` | `434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2` ← **equals the declared value, not the actual value** |

So the only reason installation succeeds today is the whitelist: the integrity signal is inverted into an allow-list of *the same stale hash the file declares*. The real content hash never matches.

**Evidence — no transport-level check either:** the download catalog leaves checksums empty for the remote packs:

```dart
// lib/features/content_packs/data/content_pack_remote_service.dart:83-105 (abridged, gaps marked …)
      const RemoteContentPackInfo(
        packId: 'hsk3_pack_v1',
        hskLevel: 3,
        ...
        downloadUrl: '$cdnBaseUrl/hsk3_pack_v1.json',
        sha256Checksum: '',          // ← annotation: no expected hash
        isBundled: false,
      ),
      const RemoteContentPackInfo(
        packId: 'hsk4_pack_v1',
        ...
        sha256Checksum: '',          // ← annotation: no expected hash
```
```dart
// lib/features/content_packs/data/content_pack_remote_service.dart:137-148 (abridged, gaps marked …)
      final rawJson = utf8.decode(response.bodyBytes);

      // Verify checksum if provided
      if (packInfo.sha256Checksum.isNotEmpty) {
        final computed = sha256.convert(response.bodyBytes).toString();
        if (computed != packInfo.sha256Checksum) { ... failure ... }
      }
      ...
      final loader = ContentPackLoader(db);
      final result = await loader.loadPackFromJson(rawJson);   // installs into SQLite
```

**Evidence — root cause is a generator self-reference bug:** the generator computes the hash of the JSON **before** inserting the hash (and size) into that same JSON, then writes the modified bytes:

```dart
// tool/generate_hsk3_cdn_pack.dart:169-177
  final rawJson = json.encode(fullPack);
  final sha = sha256.convert(utf8.encode(rawJson)).toString();
  (fullPack['manifest'] as Map<String, dynamic>)['sha256'] = sha;
  (fullPack['manifest'] as Map<String, dynamic>)['size_bytes'] = utf8.encode(rawJson).length;
  final finalJson = json.encode(fullPack);
  final targetFile = File('content_packs_cdn/hsk3_pack_v1.json');
  targetFile.writeAsStringSync(finalJson);
```

**Evidence — a regression test now codifies the bypass:** `test/features/content_packs/content_pack_service_test.dart:84-116` mocks the CDN with the mismatched JSON and asserts `result.isSuccess == true`. The project's own bug register (`docs/agent-coordination/reports/thread-5/bug-register.md:22-41`, BUG-CORE-001) documents this exact test failing on a SHA-256 mismatch before the `isKnownValid` exception existed (`expected fd7acdb8…, actual 43444269…`); with the currently-shipped file the actual hash has since drifted again to `22e69bcc…`, so the exception is now the only thing keeping the test green. That is the opposite of a security fix: it makes the check accept content whose hash is known-wrong.

- **Attack scenario / root cause:** A remote pack is plain JSON fetched over HTTPS from a third-party GitHub account (`https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/…`). Verification is self-referential (the pack declares its own hash) and then explicitly disabled for the one pack that matters. An attacker who can modify the GitHub repo/branch (account takeover, maintainer coercion, malicious PR) — or who can intercept TLS with a CA trusted by the device (corporate MDM profile, user-installed root) — serves an arbitrary `hsk3_pack_v1` JSON. It sets `manifest.sha256` to the hard-coded value (or to the hash of its own payload — also accepted), and the app installs it transactionally on top of the existing data. `ContentPackManager` then writes attacker-controlled `curriculum_units`, `curriculum_lessons`, `lesson_segments`, `content_items`, `knowledge_registry` rows and exit-exam JSON (`content_pack_manager.dart:213-764`); vocab/grammar rows use deterministic IDs (`vocab_<simplified>`, `GRAM_<contentId>_<order>`) and are `UPDATE`d when they exist, so the attacker can rewrite already-installed HSK 1–3 learning content and exam answer keys for every user who taps "download HSK 3". Flutter text rendering means no code execution, but the poisoned curriculum/answer-key is exactly the data the app grades the learner against, and is indistinguishable from official content in the UI.
- **Impact:** Loss of content authenticity/integrity for all remote content; a MITM-with-trusted-CA or repo compromise becomes persistent, silent curriculum/answer-key injection. The "SHA-256 verified" claim in docs (see §7) is false, and the project's stale-hash workaround is itself an anti-pattern (it *guarantees* acceptance of content whose hash is wrong).
- **Fix:** Do not accept self-declared hashes as authenticity. Concrete minimal fix:
  ```dart
  // content_pack_remote_service.dart: fill real published hashes and require them
  // (regenerate packs deterministically, publish a detached <file>.sha256 over the exact bytes)
  if (packInfo.sha256Checksum.isEmpty) {
    return ContentPackInstallResult.failure(packId: packInfo.packId,
      message: 'Missing integrity metadata for ${packInfo.packId}');
  }
  // drop the isKnownValid exception entirely; for a circular hash field compute the
  // digest over the payload with manifest.sha256 removed, or better: sign detached:
  // canonical = jsonEncode({...decoded, 'manifest': {...manifestMap..remove('sha256')}});
  // if (sha256.convert(utf8.encode(canonical)) != packInfo.sha256Checksum) reject;
  ```
  Preferred: publish `pack_v1.json.sig` (Ed25519, public key pinned in the app / in `RemoteContentPackInfo`) and verify signature before `ContentPackLoader`; add a build-time check that regenerates the packed bytes and asserts catalog hashes; add a negative test: tamper one byte of the pack and assert install fails. Also fix the generator so `manifest.sha256`/`size_bytes` are computed over final bytes (or drop the embedded sha entirely in favour of the detached hash).
- **Verification status:** Quoted bypass line; both checksum-less catalog entries; recomputed actual vs declared SHA from the committed git blob; generator self-hash bug; test that asserts success on the mismatched payload. Caller traced: `ContentPacksNotifier.installPack` (`content_packs_providers.dart:100-139`) → `ContentPackRemoteService.downloadAndInstallPack` → `ContentPackLoader.loadPackFromJson` → `ContentPackManager.installOrUpdatePack` → `validateManifest` (line 173) → SQL writes.

---

### [T2-F03] Audio-pack ZIP download: SHA-256 verification is effectively disabled in production and the archive is unbounded (zip-bomb / RAM / disk exhaustion)

- **Severity:** Medium
- **Confidence:** CONFIRMED (code + reachable UI); device-side extraction caveat noted below
- **Location:** `lib/features/sentences/data/audio_pack_manager.dart:64-74, 111-191, 209-228`; caller `lib/features/sentences/presentation/screens/audio_pack_manager_screen.dart:41-52`
- **CWE:** CWE-494 (Download of Code Without Integrity Check), CWE-409 (Improper Handling of Highly Compressed Data / decompression bomb), CWE-400 (Uncontrolled Resource Consumption)
- **Evidence:**

```dart
// lib/features/sentences/data/audio_pack_manager.dart:64-74
  /// Resolves expected archive SHA-256 hash from local CDN manifest if available.
  String? _resolveManifestExpectedSha256(int level) {
    try {
      final manifestFile = File('content_packs_cdn/manifests/audio_pack_hsk${level}_manifest.json');
      if (manifestFile.existsSync()) {
        final jsonMap = json.decode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
        return jsonMap['archive_sha256'] as String?;
      }
    } catch (_) {}
    return null;
  }
```
```dart
// audio_pack_manager.dart:131-138 (abridged, gaps marked …)
    final targetSha256 = (expectedSha256 != null && expectedSha256.isNotEmpty)
        ? expectedSha256
        : _resolveManifestExpectedSha256(level);
    ...
    final tempZipFile = File(p.join(_storageDirectory, 'temp_audio_pack_$level.zip'));
```
```dart
// audio_pack_manager.dart:141-168 (abridged, gaps marked …) — no timeout, no content-length cap; streams arbitrary size to disk
      final request = http.Request('GET', Uri.parse(zipUrl));
      final response = await _client.send(request);
      ...
        final totalLength = response.contentLength ?? (3500000);
        ...
        await for (final chunk in response.stream) { sink.add(chunk); receivedBytes += chunk.length; ... }
```
```dart
// audio_pack_manager.dart:170-191 (abridged, gaps marked …)
        final digest = await sha256.bind(tempZipFile.openRead()).first;
        ...
        if (targetSha256 != null && targetSha256.isNotEmpty) {
          if (computedSha256.toLowerCase() != targetSha256.toLowerCase()) { ...reject... }
        }
        await Isolate.run(() => _extractZipFileSafely({...}));
```
And inside the isolate, the entire archive is decoded into RAM: `final bytes = zipFile.readAsBytesSync(); final archive = ZipDecoder().decodeBytes(bytes);` (`:22-23`).

The UI caller never supplies `expectedSha256`:
```dart
// lib/features/sentences/presentation/screens/audio_pack_manager_screen.dart:47-52
    await widget.packManager.downloadPack(
      pack.id,
      onProgress: (prog) { if (mounted) setState(() => _downloadProgress = prog); },
    );
```
`content_packs_cdn/manifests/` is **not** declared in `pubspec.yaml` assets, is not downloaded by any code path (`ContentSourceConfig.getManifestUrl()` at `content_source_config.dart:17-19` has no callers — verified by grep), and cannot exist at the relative path `content_packs_cdn/…` on a real device. Therefore `targetSha256 == null` and the entire verification block is skipped: the live app extracts any bytes served for `…/packages/audio_pack_hsk3.zip`.
- **Attack scenario / root cause:** (a) **Integrity:** a network attacker able to terminate TLS with a trusted CA (MDM profile / user CA) or a compromised `FamAnVMU/hi-chai-ni` repo serves a malicious `audio_pack_hskN.zip`; the app writes it into app storage and marks all sentence audio `downloaded` without any integrity decision. Zip-Slip is correctly blocked (see F04 note), so impact is content substitution/disk consumption rather than file overwrite — e.g. replace listening audio with arbitrary audio/text payloads, or package valid MP3s padded to huge sizes. (b) **Resource exhaustion:** `response.stream` is written with no size cap and the whole archive is then read into memory for `ZipDecoder`; a decompression bomb (e.g. 10 MB zip → multi-GB inflated files, thousands of entries) can OOM the isolate or fill the app's storage. `hasSufficientStorage()` is also a stub (F13), so the “disk space check” doc claim provides no protection.
- **Impact:** Integrity of offline audio (learner hears attacker-supplied content), denial of service / storage exhaustion. Note: `_storageDirectory` defaults to the relative path `'audio_packs'` (`:61`); on Android the process CWD is `/`, so directory creation likely throws before download (the `catch` then fakes progress) — this makes the missing verification **latent on-device** today, but the feature is UI-exposed and the defect remains once the storage path is fixed (and is directly exercised by tests). Severity kept Medium for that reason.
- **Fix:** Make the expected hash mandatory and sourced from app-shipped, signed metadata: embed per-pack `archive_sha256` as constants in `audio_pack_providers.dart` (or fetch the manifest over TLS and pin it) and `if (targetSha256 == null) throw …` before downloading; stream with a hard cap (`if (receivedBytes > 64 * 1024 * 1024) abort`), check `Content-Length`, and enforce a declared uncompressed-size budget per entry in `_extractZipFileSafely` (skip/reject when `sum(entry.size) > limit` or `archive.length > maxEntries`); add `.timeout(const Duration(seconds: 60))` around `_client.send` and the stream.
- **Verification status:** All call sites grepped (`downloadPack` has one caller; `expectedSha256` never passed; `getManifestUrl` unused). `pubspec.yaml:76-81` confirms the manifests are not bundled. Extraction code read; Zip-Slip guard confirmed working (see §6).

---

### [T2-F04] Manifest-driven audio-pack downloads trust remote paths: path-traversal file write + empty-checksum acceptance

- **Severity:** Medium (latent — no production caller today)
- **Confidence:** CONFIRMED (code); RISK (exploitability gated on wiring)
- **Location:** `lib/features/audio_management/data/audio_pack_downloader.dart:101-121, 138-144`; `lib/features/audio_management/data/audio_storage_manager.dart:38-84`; model `lib/features/audio_management/domain/models/audio_asset_manifest.dart:151-167`
- **CWE:** CWE-22 (Improper Limitation of a Pathname to a Restricted Directory — 'Path Traversal')
- **Evidence:**

```dart
// audio_pack_downloader.dart:101-105
      final existing = existingMap[asset.audioId];
      final targetRelative = asset.relativePath.isNotEmpty ? asset.relativePath : '${asset.audioId}.${asset.fileFormat}';
      final expectedPath = p.join(storageManager.getPackAudioDirectory(manifest.packId), targetRelative);
      final targetFile = File(expectedPath);
```
```dart
// audio_pack_downloader.dart:118-121
      final tempFileName = 'temp_${asset.audioId}_${DateTime.now().millisecondsSinceEpoch}.tmp';
      final stagingFilePath = p.join(storageManager.getPackStagingDirectory(manifest.packId), tempFileName);
```
```dart
// audio_storage_manager.dart:38-55 — empty checksum is treated as valid
  Future<bool> verifyFileIntegrity(File file, String expectedSha256) async {
    ...
    // If expected checksum is empty, only check existence and non-empty
    if (expectedSha256.isEmpty) return true;
```
```dart
// audio_storage_manager.dart:73-83 — no p.isWithin()/canonicalize() before write
    final targetPath = p.join(getPackAudioDirectory(packId), relativeTargetFilePath);
    final targetFile = File(targetPath);
    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    // Atomic move / rename
    await tempFile.rename(targetPath);
    return targetPath;
```
`AudioAssetItem.fromMap` takes `relative_path`, `id`, `checksum_sha256` verbatim from JSON with no validation (`audio_asset_manifest.dart:47-69`).
- **Attack scenario / root cause:** `AudioPackManifest`/`AudioAssetItem` are designed to be built from a remote manifest (`AudioPackManifest.fromJson`, `ContentSourceConfig.getManifestUrl()`). If/when the v11 downloader is wired to a fetched manifest (the UI already has a download button), an attacker-controlled manifest sets `relative_path = "../../databases/hi_chinese.db"` or `"../../shared_prefs/x.xml"`, or `audio_id = "../../foo"` (temp file path). `AudioStorageManager.promoteFromStaging` joins the remote string to the pack audio dir and renames the staged file there with no containment check; the staged temp file path is likewise built from `audioId` inside `.tmp`. Combined with `verifyFileIntegrity()` returning `true` for empty checksums, a manifest that omits checksums gets arbitrary-path file writes inside the app sandbox (e.g. overwrite `../databases/hi_chinese.db`, `../shared_prefs/…`, or the `backups/` directory), and can then trigger destructive effects. Today **no production code instantiates `AudioPackDownloader`** (grep: only `test/features/audio_management/audio_management_offline_test.dart`), so the defect is latent — but it is exactly the pattern the project doc claims was fixed for archives (see §7 Zip-Slip claim).
- **Impact:** If wired: arbitrary in-sandbox file write from a remote-supplied path (overwrite DB/config; data integrity/availability; combined with loader ordering, potential data corruption). Even before wiring, tests construct manifests with attacker-shaped fields, so any future caller inherits the vulnerability.
- **Fix:** Mirror the proven `_extractZipFileSafely` approach:
  ```dart
  final base = p.canonicalize(getPackAudioDirectory(packId));
  final resolved = p.canonicalize(p.join(base, relativeTargetFilePath));
  if (!p.isWithin(base, resolved)) {
    throw AudioDownloadException('Blocked path traversal in manifest path', packId: packId);
  }
  // and validate identifiers: RegExp(r'^[A-Za-z0-9._-]+$') on audioId and relativePath,
  // reject '/' and '..' before URL building / staging
  ```
  Reject empty `checksumSha256` (fail closed) instead of `return true`.
- **Verification status:** All writes and joins quoted; `AudioPackDownloader` instantiation grepped across `lib/` (0 hits) and `test/` (3 test constructions). Manifest model read to confirm no sanitisation. Cross-check: `_extractZipFileSafely` in `audio_pack_manager.dart:28-37` *does* implement the correct canonicalise+`isWithin` check — the same control is missing here.

---

### [T2-F05] Gemini API key is forwarded to an arbitrary user-configured proxy host; validation is incomplete and bypassed on the verify/test paths

- **Severity:** Medium
- **Confidence:** CONFIRMED (code paths/bugs); LIKELY (exfiltration needs a user action or a pre-existing stored value)
- **Location:** `lib/core/network/ai/security/ai_credential_storage.dart:318-333, 351-361`; `lib/core/network/ai/providers/gemini_rest_ai_provider.dart:41-62, 64-106, 441-453`; UI `lib/features/settings/presentation/screens/ai_settings_screen.dart:456-504`
- **CWE:** CWE-918 (Server-Side Request Forgery) primary; CWE-201 (Insertion of Sensitive Information Into Sent Data — API key in header to third party), CWE-319 (Cleartext Transmission) for the verify/test bypass
- **Evidence — only partial host validation, and only in the getter used by generate/stream:**

```dart
// ai_credential_storage.dart:323-332
    if (url != null && url.trim().isNotEmpty) {
      final cleanUrl = url.trim();
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
        throw ArgumentError('Custom Proxy URL bắt buộc phải sử dụng giao thức HTTPS bảo mật.');
      }
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.') || host.startsWith('10.')) {
        throw ArgumentError('Không được sử dụng địa chỉ loopback hoặc IP nội bộ cho AI Proxy.');
      }
    }
```
```dart
// gemini_rest_ai_provider.dart:441-453 — https+host check lives ONLY here (used by generateText/streamText)
  Future<String> _resolveSecureBaseUrl() async {
    final providerType = await credentialStorage.getProviderType();
    if (providerType == AiProviderType.customProxy) {
      final customProxy = await credentialStorage.getCustomProxyUrl();
      if (customProxy != null && customProxy.trim().isNotEmpty) {
        final parsed = Uri.tryParse(customProxy.trim());
        if (parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty) {
          return customProxy.trim().replaceAll(RegExp(r'/+$'), '');
        }
      }
    }
    return _baseUrl;
  }
```
```dart
// gemini_rest_ai_provider.dart:46-56 — verifyCredentials does NOT use _resolveSecureBaseUrl
      final customProxy = await credentialStorage.getCustomProxyUrl();
      final base = customProxy?.isNotEmpty == true ? customProxy! : _baseUrl;
      final uri = Uri.parse('$base/models?pageSize=1');

      final response = await _client.get(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
```
```dart
// gemini_rest_ai_provider.dart:81-106 — testConnection likewise (the Settings “Test” button path); (abridged, gaps marked …)
      final customProxy = await credentialStorage.getCustomProxyUrl();
      final base = customProxy?.isNotEmpty == true ? customProxy! : _baseUrl;
      final uri = Uri.parse('$base/models/$effectiveModel:generateContent');
      …
      final response = await _client.post(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 15));
```
- **Bypass analysis (what the validation actually stops):**
  - It does stop `http://` values (at save time), uppercase-scheme bypasses are not exploitable (Dart `Uri` normalises the scheme, plus `toLowerCase()` is used), and userinfo tricks do not bypass the host check (`https://localhost@evil.com` has `host == evil.com`; `https://evil.com@localhost` has `host == localhost` and is blocked).
  - It does **not** stop: IPv6 loopback `https://[::1]:8443` (`uri.host == '::1'`), other loopback addresses `https://127.0.0.2`, RFC1918 `172.16.0.0/12` (`host.startsWith('172.')` is unchecked), link-local/metadata `169.254.169.254`, `0.0.0.0`, trailing-dot `https://localhost.:8443`, or any DNS name that resolves to a private address (e.g. `foo.internal`, rebinding-capable domains). Any such URL is accepted and receives requests carrying the learner's Gemini key.
  - The **verify/test paths bypass the https+host guard entirely**: they read the secure-storage value raw. A proxy URL stored by an older build (before this validation existed), or restored/imported by any future code path, is used for a key-bearing request even if it is `http://…`. On Android the application-level `android:usesCleartextTraffic="false"` currently blocks plain HTTP at the OS layer, so this is a latent guard-consistency defect there (it would be live on a desktop/CI target or if the manifest/network-security config changes); the mismatch is still a real defect because the code *intends* to enforce HTTPS and applies that check to only two of four request paths.
  - The UI never warns that the proxy receives the Gemini key (`ai_settings_screen.dart:456-504` contains only a URL field + save button, while the key card at `:356-361` promises "Khóa KHÔNG bao giờ … chia sẻ ra ngoài").
- **Attack scenario:** (1) Social engineering: a "faster/cheaper Gemini proxy" tutorial or in-app support instruction tells the learner to paste `https://proxy.example` → the app sends the user's live Gemini key to the operator on every AI request, allowing key theft/quota abuse/billing. (2) In-app SSRF: with a user-entered internal HTTPS endpoint (valid cert), requests to `/models` and `:generateContent` are made from the phone into the LAN/intranet, and the key is forwarded inside them. (3) If a pre-hardening `http://` proxy value survives in `flutter_secure_storage`, the Settings "Test connection" button will attempt to send the key over cleartext (currently blocked by `usesCleartextTraffic=false`, so the guard omission is latent on Android but real wherever that OS-level backstop is absent/changed).
- **Impact:** Integrity/confidentiality of the highest-value asset in the app is protected by only partial, inconsistently-applied checks: key forwarding to an arbitrary third-party host is possible by design (social-engineering precondition), SSRF into user networks is only partially blocked, and the HTTPS guard is missing from two of four request paths. The code guard is real but only partially effective — exactly the failure mode the docs claim is prevented.
- **Fix:** Centralise resolution and enforce on every request:
  ```dart
  Future<String> resolveBaseUrl() async {
    final v = (await credentialStorage.getCustomProxyUrl())?.trim();
    if (v == null || v.isEmpty) return _baseUrl;
    final u = Uri.tryParse(v);
    if (u == null || u.scheme.toLowerCase() != 'https' || u.host.isEmpty) {
      throw const AiAuthenticationException('Insecure proxy URL rejected.');
    }
    // use the parser, not string prefixes:
    final host = u.host.toLowerCase();
    if (host == 'localhost.' || host.endsWith('.local') || host.endsWith('.internal')) reject;
    final ip = InternetAddress.tryParse(host);
    // Dart exposes isLoopback/isLinkLocal only; add the RFC1918 checks explicitly:
    if (ip != null && (ip.isLoopback || ip.isLinkLocal || _isRfc1918(ip))) reject;
    // optionally require an allowlist of configured enterprise hosts / pinned cert
    return v.replaceAll(RegExp(r'/+$'), '');
  }
  ```
  Use it in `verifyCredentials`, `testConnection`, `generateText`, `streamText`; re-validate on read (not only on save); show a one-time explicit warning ("Requests will be sent to this server and include your Gemini API key") before saving a proxy; consider dropping the proxy feature for the BYOK flow or requiring user-imported pinned certificates.
- **Verification status:** All four header-construction sites traced; `_resolveSecureBaseUrl` call sites confirmed only in `generateText:223` and `streamText:312`; `verifyCredentials:46`/`testConnection:81` read raw storage; UI card read. Blocklist gaps listed above were derived from the `Uri.host` values Dart produces for each literal URL (e.g. `Uri.parse('https://[::1]:8443').host == '::1'`), which is the standard way the package parses them; the exploit chain itself (user pasting a hostile proxy) was not executed.

---

### [T2-F06] Android Auto Backup enabled with no extraction rules: learner database, chat history and unencrypted `.hibak` copies are eligible for cloud/device transfer

- **Severity:** Medium (privacy / data-at-rest)
- **Confidence:** CONFIRMED (manifest state), LIKELY (what the OS actually ships to Google Drive depends on device account settings)
- **Location:** `android/app/src/main/AndroidManifest.xml:11-15`; merged release manifest `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml:43-49`; unencrypted backups `lib/features/settings/data/services/data_management_service.dart:79-95`; helper `lib/core/database/database_backup_helper.dart:39-90`
- **CWE:** CWE-312 (Cleartext Storage of Sensitive Information), CWE-922 (Insecure Storage of Sensitive Information)
- **Evidence:**

```xml
<!-- android/app/src/main/AndroidManifest.xml:11-15 — no android:allowBackup / dataExtractionRules -->
    <application
        android:label="HI Chinese"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">
```
```xml
<!-- merged RELEASE manifest actually packaged into the APK: also no allowBackup / fullBackupContent -->
<application android:name="android.app.Application" ... android:usesCleartextTraffic="false">
```
```dart
// data_management_service.dart:79-95 — .hibak files are raw/complete SQLite copies, never encrypted
  Future<File> createBackup({String? customName}) async {
    final now = DateTime.now().toUtc();
    ...
    final backupDir = Directory(p.join(p.dirname(_dbPath), 'backups'));
    ...
    final destPath = p.join(backupDir.path, backupFileName);
    return await DatabaseBackupHelper.createBackup(db: _db, dbPath: _dbPath, destinationBackupPath: destPath);
  }
```
- **Attack scenario / root cause:** With `targetSdk 36` and `android:allowBackup` absent, the default is `true`; without `android:dataExtractionRules` (API 31+) / `android:fullBackupContent` there is no exclusion list. Android Auto Backup therefore considers the app's private data — `databases/hi_chinese.db` (profile display name, goal history, **AI Tutor chat messages**, learner evidence, dictionary history), the `backups/*.hibak` full DB copies, and the exported `files/` — for upload to the user's Google Drive backup and for device-to-device transfer. The `.hibak` copies are not encrypted or password-protected. (The `flutter_secure_storage` blob is also backup-eligible, but its Keystore-wrapped key isn't restorable — combined with `AndroidOptions(resetOnError: true)` (`ai_credential_storage.dart:53-57`) a restored device silently drops the stored API key. That is a data-loss issue, not a leak.) Threat: a compromised Google account or forensic access to a cloud backup yields plaintext learner PII/learning history; on pre-Android-12 D2D transfers the data moves to the new device in the clear.
- **Impact:** Unconsented cloud retention/exposure of learner PII and AI chat transcripts; violates the "100% local, no cloud account" privacy posture the docs advertise (`docs/system-documentation/07-server-and-sync.md:5-21` — "Zero-Account / 100% Local Profile"). Also undermines delete-on-device expectations: a "reset" (`clearAllUserData`) does not remove already-uploaded backup generations.
- **Fix:**
  ```xml
  <application android:allowBackup="false"
               android:fullBackupContent="false"
               android:dataExtractionRules="@xml/data_extraction_rules" ...>
  ```
  or, if backup should be kept for convenience, provide `res/xml/data_extraction_rules.xml` with `<exclude domain="database" path="."/>` + `<exclude domain="file" path="backups/"/>` and encrypt `.hibak` (e.g. SQLCipher or AES-GCM with a KeyStore-derived key) before it is eligible. Document the choice in the privacy policy; add an instrumentation assertion in CI that the merged manifest contains the expected backup attributes.
- **Verification status:** Source manifest and the actual merged **release** manifest read (both lack backup attributes); backup path/code verified; data inventory of the DB tables from `exportUserDataJson` (`data_management_service.dart:190-228`) confirms PII content. Cross-team note: Lead signal L-09 independently flags the same manifest gap.

---

### [T2-F07] Remote packs are persisted as `bundled`, erasing the trusted/remote distinction

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/data/content_pack_loader.dart:16-18`; consumer `lib/features/content_packs/data/content_pack_remote_service.dart:151-154`
- **CWE:** CWE-345 (Insufficient Verification of Data Authenticity — trust-state confusion)
- **Evidence:**

```dart
// lib/features/curriculum/data/content_pack_loader.dart:16-18
  Future<ContentPackInstallResult> loadPackFromJson(String rawJson) async {
    return _manager.installOrUpdatePack(rawJson, isBundled: true);
  }
```
- **Attack scenario / root cause:** `ContentPackLoader` is used for both (a) APK-shipped assets and (b) downloaded CDN packs (`ContentPackRemoteService.downloadAndInstallPack:151-152`). It hard-codes `isBundled: true`, so `ContentPackManager` stores the downloaded remote pack with `status='bundled'` and `is_bundled=1` (`content_pack_manager.dart:214-219`). Downstream logic that treats "bundled" as "shipped inside the signed APK" (UI labels in `content_pack_manager_screen.dart`, `_checkPackNeedsImport` in `app_startup_provider.dart:223-241`, uninstall semantics in `content_pack_manager.dart:796-931`) then mis-trusts remotely fetched content. Combined with F02, untrusted remote content is indistinguishable from APK-verified content.
- **Impact:** Trust-state confusion / weakened provenance; operators and future code cannot tell whether a pack's content came from the signed APK or from the network; uninstall/reset UI paths may behave incorrectly. No direct exploit on its own.
- **Fix:** Pass the real origin: `installOrUpdatePack(rawJson, isBundled: isBundled)` and set `false` from `downloadAndInstallPack`; or derive status from a trusted field (`downloadUrl.startsWith('bundled:')`). Add a regression test asserting a remote install stores `is_bundled = 0`.
- **Verification status:** Both call paths of `loadPackFromJson` traced (`content_packs_providers.dart:79-82` bundled, `content_pack_remote_service.dart:151-152` remote), DB status write verified.

---

### [T2-F08] Exported `MainActivity` + default Flutter deep-link handling accepts an arbitrary `route` extra (intent redirection to AI Settings / debug screens)

- **Severity:** Low
- **Confidence:** LIKELY (framework default + code; not executed on device)
- **Location:** `android/app/src/main/AndroidManifest.xml:16-37`; `lib/main.dart:70-71`; `lib/core/router/app_router.dart:43-58, 60-171`; `lib/core/router/app_routes.dart:10-12`
- **CWE:** CWE-926 (Improper Export of Android Application Components); CWE-940 (Improper Verification of Source of a Communication Channel)
- **Evidence:**

```xml
<!-- AndroidManifest.xml:16-27 — launcher activity is exported (required) and no flutter_deeplinking_enabled=false meta-data exists -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            ...
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
```
```dart
// app_router.dart:43-58 — external route strings (incl. "hichinese://…") are normalised, not allow-listed before routing
  static String normalizeRouteName(String? raw) {
    ...
      if (uri.scheme == 'hichinese') { ... return combined.isEmpty ? AppRoutes.root : combined; }
  ...
// app_routes.dart:11-12 — sensitive-looking destinations reachable by name
  static const String designSystem = '/design-system';
  static const String aiSettings = '/ai-settings';
```
- **Attack scenario / root cause:** No deep-link `<intent-filter>` is declared, but `MainActivity` is exported (necessary for the launcher), and Flutter's default (no `flutter_deeplinking_enabled=false` meta-data) lets the platform pass an `initial route` / `route` extra from an explicit `Intent`. Any installed app can `startActivity(ComponentName("com.hichinese.hi_chinese", "…MainActivity"), intent with extras route="/ai-settings")`, force-navigating to the AI settings screen (or `/design-system`, a demo screen that ships in release) without going through the launcher. On `singleTop`, an `onNewIntent` route push is also possible. Note: the project's in-app navigation never calls `pushNamed` (grep: 0 hits; Lead signal L-06 calls this router "dead code"), so the route guard is only reachable through this external path — no auth boundary is bypassed, and sensitive actions still require user interaction (the settings screen shows only a masked key and requires typing to change the proxy).
- **Impact:** Low: unsolicited UI navigation / deeplink-driven confusion; exposure of a debug/demo screen in release; no confirmed sensitive data read or state change without user interaction. Relevant mainly because the docs/commit history advertise "route guard & deep-link protection" that does not actually gate in-app navigation.
- **Fix:** Add `<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />` (or declare an explicit allow-listed deep-link `<intent-filter>` with `android:autoVerify` if deep links are a product requirement); remove `/design-system` routing (and the 320-line skeleton screen) from release builds; ensure any externally reachable destination performs its own authorization. Add a test that a bad route falls to a safe home route.
- **Verification status:** Manifest read (source + merged), absence of `flutter_deeplinking_enabled` confirmed, routing code read. Framework default of Flutter deep linking is standard Flutter behaviour (not executed here, hence LIKELY). Cross-check: Lead signal L-06 states the route guard is never exercised in-app.

---

### [T2-F09] Python data pipeline downloads are not integrity-verified before feeding shipped assets

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `data_pipeline/download_grammar_sources.py:14-36`; `data_pipeline/download_raw_sources.py:30-76`; `data_pipeline/download_tatoeba_sources.py:17-30`; `data_pipeline/download_hanzi_sources.py:12-39`; (secure-FD helper `data_pipeline/pipeline_config.py:69-86`)
- **CWE:** CWE-494 (Download of Code Without Integrity Check)
- **Evidence:**

```python
# data_pipeline/download_raw_sources.py:6-11, 34-39 — no hash/size/signature check after download
def download_file(url, dest_path):
    ...
    with urllib.request.urlopen(req) as resp, open(dest_path, 'wb') as out:
        ... write chunks ...
# ...
    clem_base = "https://raw.githubusercontent.com/clem109/hsk-vocabulary/master/hsk-vocab-json"
    for l in range(1, 7):
        dest = os.path.join(raw_dir, "clem109", f"hsk-level-{l}.json")
        if not os.path.exists(dest):
            download_file(f"{clem_base}/hsk-level-{l}.json", dest)
```
- **Attack scenario / root cause:** Ten-plus datasets are pulled from mutable third-party `master`/`main` branches (raw.githubusercontent.com, gushi-chinese.online, downloads.tatoeba.org) and are parsed/built into the exact JSON assets shipped inside the APK (`assets/data/*.json`, `assets/audio/hsk1|hsk2`). The pipeline only checks "file exists and size >1000 bytes" before use — no pinned commit, SHA-256, GPG or provenance check — and TLS alone does not cover repo-owner compromise or upstream content replacement (`master` moves). A compromised upstream repo can therefore inject curriculum/vocabulary/grammar content that is baked into a later release (and the F14 report itself celebrates only that TLS verification was re-enabled, not data authenticity).
- **Impact:** Supply-chain content poisoning of the shipped learning data (integrity of curriculum/exam content), with no way to detect tampering after the build. Dev-workstation scope, but the output is the production APK assets.
- **Fix:** Pin each source to an immutable commit and record expected SHA-256 in a checked-in lockfile (`data_pipeline/sources.lock.json`), verify after download and fail the build on mismatch; when updating, review the diff and update the lockfile in the same commit. Prefer `secure_open_url`/`download_file_secure` everywhere. Add a CI step that re-verifies the lockfile.
- **Verification status:** Writers/builders traced: `download_*` → `data_pipeline/raw/**` → `build_*_dataset.py`/`generate_all_audio.py` → `assets/...`; all download helpers read; no hash checks present. F14 doc claims TLS hardening (true) but makes no integrity-authenticity claim.

---

### [T2-F10] Python pipeline download scripts without timeouts can hang forever (dev/CI DoS)

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `data_pipeline/download_hanzi_sources.py:16`; `data_pipeline/download_raw_sources.py:11`; `data_pipeline/inspect_wiki_files.py:15`
- **CWE:** CWE-400 (Uncontrolled Resource Consumption)
- **Evidence:**

```python
# download_hanzi_sources.py:14-16
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    start_time = time.time()
    with urllib.request.urlopen(req) as response, open(target_path, 'wb') as out_file:
```
```python
# download_raw_sources.py:9-11
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    start = time.time()
    with urllib.request.urlopen(req) as resp, open(dest_path, 'wb') as out:
```
- **Attack scenario / root cause:** `urllib.request.urlopen` has no default timeout (`socket._GLOBAL_DEFAULT_TIMEOUT` = block). A hung upstream (or an attacker who can black-hole the connection) makes the pipeline/CI job hang indefinitely instead of failing. The project's own `pipeline_config.py:66,69-76` provides `DEFAULT_TIMEOUT = 30` and `secure_open_url(..., timeout=...)`, but these two scripts bypass it — inconsistent with the F14 hardening report which claims "explicit socket timeouts".
- **Impact:** Availability of the offline build pipeline (CI stall / developer workstation hang); no runtime impact on users.
- **Fix:** Route every call through `pipeline_config.secure_open_url(url, timeout=30)` (or `download_file_secure`); add a lint/test that greps for bare `urllib.request.urlopen(` in `data_pipeline/`.
- **Verification status:** Grep of all 46 scripts; three bare-`urlopen` call sites listed above (two shown); the remaining download scripts already pass `timeout=`.

---

### [T2-F11] Pipeline builds filesystem names and ZIP entry names from corpus-controlled `audio_id` without sanitisation

- **Severity:** Low
- **Confidence:** CONFIRMED (code); RISK (requires poisoned upstream/corpus)
- **Location:** `data_pipeline/generate_all_audio.py:71-76, 103-108, 118-124`
- **CWE:** CWE-22 (Path Traversal — zip entry name / output filename)
- **Evidence:**

```python
# generate_all_audio.py:71-76
        for s in sents:
            text = s.get("chinese", "")
            audios = s.get("audios", [])
            audio_id = audios[0]["audio_id"] if audios else str(s["id"]).replace("tat_", "")
            out_file = os.path.join(target_dir, f"{audio_id}.mp3")
            tasks.append((s, audio_id, out_file, generate_single_audio(text, out_file)))
```
```python
# generate_all_audio.py:120-124
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for (s, audio_id, out_file, _), ok in zip(tasks, results):
                if ok and os.path.exists(out_file):
                    arcname = f"{audio_id}.mp3"
                    zf.write(out_file, arcname)
```
- **Attack scenario / root cause:** `sentences_corpus.json` is built from remote Tatoeba exports (`build_sentences_dataset.py`); `audio_id` is copied from that data and used verbatim in `os.path.join(...f"{audio_id}.mp3")` and as a ZIP `arcname`. If an upstream/corpus `audio_id` contains `/`, `\` or `..` (e.g. `../../../../x`), the generator writes outside the intended stage directory and/or creates a ZIP with traversal entry names. The Flutter extractor used by this app blocks `../` (see §6), so the shipped-app impact is contained — but the generated ZIP is also a distributable artifact (`content_packs_cdn/packages/*.zip`) consumed by other tooling, and generator-side traversal writes are unrestricted.
- **Impact:** Dev-machine file write outside the staging tree; ZIP archives containing traversal entries (portfolio risk if consumed by a less careful extractor). No in-app exploit path found.
- **Fix:** Validate `audio_id = re.sub(r'[^A-Za-z0-9._-]', '', audio_id)` and reject `""`, `"."`, `".."`, and anything containing `/`/`\`; assert `os.path.commonpath` containment for `out_file`; assert the zip arcname has no path separators.
- **Verification status:** Generator and corpus-builder read; the app's `_extractZipFileSafely` guard verified separately (§6) — hence Low.

---

### [T2-F12] Personal learner export is copied to the system clipboard (plaintext PII in shared buffer)

- **Severity:** Low
- **Confidence:** CONFIRMED (user action required)
- **Location:** `lib/features/settings/presentation/widgets/data_management_sheet.dart:47-55`; data source `lib/features/settings/data/services/data_management_service.dart:190-228`
- **CWE:** CWE-200 (Exposure of Sensitive Information to an Unauthorized Actor)
- **Evidence:**

```dart
// data_management_sheet.dart:47-55
  Future<void> _handleExportJson() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      final jsonStr = await service.exportUserDataJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      ... 'Đã xuất dữ liệu cá nhân ra JSON & sao chép vào Clipboard!'
```
The exported payload includes `user_profiles` (display name, goals, purpose), `goal_history`, `user_saved_words`, `dictionary_history`, `reading_progress`, `srs_items` (`:209-225`).
- **Attack scenario / root cause:** The app's only "export" feature places the full learner profile/history JSON on the system clipboard with no expiration, no size warning and no secure share target. On API 24–29 (minSdk 24) other apps can read the clipboard when in the foreground (and historically in the background), so a malicious app can silently harvest the learner's PII after the user performs an export; clipboard managers/keyboards may also retain it. The UI describes this as a safe local export.
- **Impact:** Low–Medium privacy leak of learner PII (no credentials — the export filter drops `api_key/token/secret/password` keys). Depends on a second malicious app and user action.
- **Fix:** Write the export to an app-private file and share it via `FileProvider`/`Share` intent (user-selected recipient); or clear the clipboard after a short delay and warn the user; never include `user_profiles`-level PII without an explicit consent screen.
- **Verification status:** UI action + export payload read; no other import/export UI exists (grep).

---

### [T2-F13] `hasSufficientStorage()` always returns `true` — the “disk space check” is a stub

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/audio_management/data/audio_storage_manager.dart:120-133`; caller `lib/features/audio_management/data/audio_pack_downloader.dart:64-71`
- **CWE:** CWE-400 (Uncontrolled Resource Consumption)
- **Evidence:**

```dart
// audio_storage_manager.dart:120-133
  /// Checks if device has sufficient storage available for estimated bytes.
  Future<bool> hasSufficientStorage(int requiredBytes) async {
    try {
      // In standard desktop / unit tests or non-rooted mobile, stat fs
      // We check if target base storage exists and is writable
      final dir = Directory(baseStoragePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
```
- **Attack scenario / root cause:** The function ignores `requiredBytes` entirely — it never statfs/queries free space. The v11 `AudioPackDownloader` gates a download on it (`:65-71`), and the documentation claims a real space check (`docs/system-documentation/08-content-and-audio.md:81`). A large pack (or an attacker-inflated manifest `totalSizeBytes`) proceeds until the filesystem fills, causing write failures and potential DB/SQLite corruption on a full disk.
- **Impact:** Disk-exhaustion DoS / partial-write inconsistency; doc claim false. No direct data theft.
- **Fix:** Use `StatFs`-based free-space query (e.g. `path_provider` + a small platform channel, or `FileStat`/`disk_space` package), compare with `requiredBytes * 1.2` and fail closed; on iOS/macOS similar APIs. Add a unit test that stubs a tiny free-space value and asserts refusal.
- **Verification status:** Function body read; only call site traced to the downloader; docs section quoted in §7.

---

### [T2-F14] Restore path deletes the live database before the backup file is validated; a corrupt/incompatible `.hibak` is an irreversible data-loss event

- **Severity:** Low (data availability/integrity; no confidentiality impact)
- **Confidence:** CONFIRMED
- **Location:** `lib/features/settings/data/services/data_management_service.dart:117-188`; `lib/core/database/database_backup_helper.dart:34-90`; UI `lib/features/settings/presentation/widgets/data_management_sheet.dart:130-161`
- **CWE:** CWE-665 (Improper Initialization — restore without validation), CWE-400-adjacent availability
- **Evidence:**

```dart
// data_management_service.dart:143-150 — live DB file deleted, then backup copied; no pre-validation
    await AppDatabase.instance.close();
    final targetDbFile = File(_dbPath);
    if (await targetDbFile.exists()) {
      await targetDbFile.delete();
    }
    await backupFile.copy(_dbPath);
```
```dart
// data_management_service.dart:181-185 — integrity check AFTER overwrite; only warns, no rollback
    final issues = await DatabaseBackupHelper.checkIntegrity(_db);
    if (issues.isNotEmpty) {
      debugPrint('[DataManagement] Warning: Integrity check issues after restore: $issues');
    }
```
`DatabaseBackupHelper.createBackup` docstring claims *"Verifies the integrity of the created backup file"* (`database_backup_helper.dart:34-38`) but no post-creation verification exists in the body (`:39-90`); `VACUUM INTO`/copy writes directly to the destination with no temp file + rename (`:68-87`), so a process kill/power loss mid-backup leaves a corrupt `.hibak`.
- **Attack scenario / root cause:** A user with a corrupted/partial backup (e.g. device shut down during backup, or a backup whose schema predates the current app version) taps Restore. The app closes and deletes the current DB, copies the bad file into place, then only *logs* the integrity failure — the pre-restore safety snapshot was best-effort and its own creation failure is swallowed (`:122-127`). One tap turns recoverable user data into permanent loss (and the previous `.hibak` safety copy lives on the same failing filesystem). This is not attacker-triggerable remotely (files come from the internal `backups/` dir), hence Low.
- **Impact:** Availability/data-integrity: permanent loss of learner progress on a bad restore; contradicts the "safe restore" claims in docs.
- **Fix:** Before touching the live DB: open the backup read-only, run `PRAGMA integrity_check` and read `user_version`, refuse if invalid/newer/older-without-migration; write the restored file to `<db>.restore.tmp`, fsync, then atomic `rename` over the live path while the DB is closed; keep the pre-restore snapshot mandatory (abort restore if it cannot be created); verify created backups after `VACUUM INTO` (they are on the same disk, cheap) and use `PRAGMA quick_check`.
- **Verification status:** Restore and backup code fully read; UI confirm path read. Cross-team note: Lead signal L-03 flags the same restore ordering from the data-integrity side; kept here as an explicit security/availability finding because the file is in T2 scope.

---

### [T2-F15] Content-pack and audio-zip HTTP requests have no timeout (app can hang on a stalled CDN)

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/content_packs/data/content_pack_remote_service.dart:126-127`; `lib/features/sentences/data/audio_pack_manager.dart:141-142`; contrast `lib/core/network/ai/providers/gemini_rest_ai_provider.dart:56,106`
- **CWE:** CWE-400 (Uncontrolled Resource Consumption)
- **Evidence:**

```dart
// content_pack_remote_service.dart:126-127
      final uri = Uri.parse(packInfo.downloadUrl);
      final response = await _httpClient.get(uri);          // no .timeout()
```
```dart
// audio_pack_manager.dart:141-142
      final request = http.Request('GET', Uri.parse(zipUrl));
      final response = await _client.send(request);          // no .timeout()
```
- **Attack scenario / root cause:** If the CDN (GitHub raw) stalls or an on-path attacker throttles/black-holes the TCP stream, the content-pack download spinner and audio-pack download stay “in progress” indefinitely with no cancellation; the AI provider by contrast correctly applies `.timeout(...)` on the same `http.Client` type. A malicious proxy/CDN can also keep the socket open with an endless trickle inside no timeout at all. Low severity (UI hang / resource retention) but trivially fixable.
- **Impact:** Availability/UX DoS of content download; no data exposure.
- **Fix:** Add `.timeout(const Duration(seconds: 30))` to `get`/`send` and to the stream-consumption loop (per-chunk idle timeout); expose cancel buttons; reuse the provider's timeout constant.
- **Verification status:** Both call sites and the contrasting AI timeout lines read.

---

## 6. Verified-secure / no-finding checks (calibration against false positives)

These were specifically hunted and came back clean or correctly implemented — recorded so the Lead does not re-report them (and to bound confidence in the findings above):

1. **SQL injection (CWE-89): none found.** Every `rawQuery`/`rawInsert` site was reviewed. User strings are sent as `whereArgs`; `LIKE` searches use `?` placeholders (`lib/core/database/dao/vocabulary_dao.dart:200-349`, `hanzi_dao.dart:63`, `sentence_dao.dart:78`). The only interpolated raw-SQL fragments are compile-time constants, table names from `DatabaseConstants`, or **integers** (`srs_repository.dart:250-310` interpolates `$limit`/`$remaining`, both `int`). `ActivityDao`, `home_repository`, `curriculum_dao`, `seed_loader` all use bind arguments. Docs claim `11-security-and-data-management.md:18-39` holds.
2. **API key never in URL / query string:** the Gemini key is always `x-goog-api-key` header (`gemini_rest_ai_provider.dart:53,102,237,327`); the key is never interpolated into a URL, and `_baseUrl`/proxy are the only URL inputs.
3. **No logging of key material:** grep for `print(`/`debugPrint` in `lib/core/network/ai/**` finds only label/format messages (`ai_credential_storage.dart:488-515`, `gemini_rest_ai_provider.dart:421`). `sanitizeSecret` is used on the error paths that can carry response/exception text (`:141,171` + `ai_settings_providers.dart:154`). Residual weakness: `sanitizeSecret` only redacts the `AIza…` pattern plus an optional caller-supplied key (`:372-382`), and `_handleStatusCode` embeds server-controlled error text verbatim into exception messages (`:466-497`) that are `debugPrint`-ed at `ai_tutor_repository.dart:370` — a malicious custom proxy could echo the key into its own error body and get it logged. Because the proxy already receives the key (F05), this adds no new exposure today; keep an eye on it if the proxy feature becomes multi-tenant.
4. **No WebView, no JS bridge, no custom-scheme intent filter:** grep for `WebView|InAppWebView|loadUrl|JavaScriptChannel|addJavascriptInterface` in `lib/` → 0 hits. Only `MAIN`/`LAUNCHER` intent filter exists (`AndroidManifest.xml:33-36`); `hichinese://` is handled in dead router code only (F08).
5. **Cleartext traffic disabled:** `android:usesCleartextTraffic="false"` in source and **merged release** manifest; all production endpoints are `https://` (`generativelanguage.googleapis.com`, `raw.githubusercontent.com`) and the Gemini Live WebSocket never exists in code (`web_socket_channel` dependency is unused — grep `wss://|WebSocketChannel` in `lib/` → only enum/comment mentions). F05 is a residual *guard-consistency* gap (HTTPS check omitted on verify/test); Android's cleartext block means a stored `http://` URL would currently fail at the network layer rather than transmit in clear.
6. **Zip Slip in the archive extractor is correctly implemented:** `lib/features/sentences/data/audio_pack_manager.dart:14-47` canonicalises the target and applies `if (!p.isWithin(canonicalTargetDir, resolvedPath)) throw FileSystemException(...)`, skips hidden/empty basenames, extracts in an `Isolate`. This is a genuine fix of the class of issue in P1_08 — the gap is only that the *manifest-driven writer* (F04) never got the same control. I found no bypass for this extractor (`file.name` with `../` or absolute paths is rejected by `isWithin`).
7. **Secure storage implementation is credible:** `flutter_secure_storage 11.2.0` (+ `pubspec.lock`), `AndroidOptions(resetOnError: true)` uses the package's default Android KeyStore-backed RSA-OAEP key wrap + AES-GCM storage cipher (package source `lib/options/android_options.dart`). Note: docs' “EncryptedSharedPreferences / hardware-backed” wording is an overclaim (§7), but the key is not stored in `SharedPreferences` in plaintext, and there is no code path writing it to SQLite (`AppSettingsDao.setSetting` blocks `api_key/secret_key/auth_token` at `app_settings_dao.dart:22-31`; migration at startup: `app_startup_provider.dart:280-296` → `migrateLegacyCredentials`, plaintext deleted only after read-back verification at `ai_credential_storage.dart:393-524`).
8. **Export filter drops credential-named settings:** `data_management_service.dart:200-207` filters `api_key`, `token`, `secret`, `password` (called out in docs claim §7 row 6: the *key* claim holds; the *clipboard* aspect is F12).
9. **Bounded retries / no retry on auth errors:** `gemini_rest_ai_provider.dart:288-299` rethrows all `AiException` (incl. 401/403/400/429) and retries only generic network failures, max 2, exponential backoff — matches the docs claim.
10. **Microphone privacy:** permission is requested only from user-triggered flows via `PermissionHelper.requestMicrophoneWithRationale` (`permission_helper.dart:30-73`; no startup call — grep), recordings go to `getTemporaryDirectory()` and are deleted after analysis (`pronunciation_repository.dart:77`, `shadowing_repository.dart:76`), and `AppLifecycleManager` stops registered sessions on `paused/inactive/hidden/detached` (`app_lifecycle_manager.dart:47-78`). No over-requested permissions: manifest has only `INTERNET` + `RECORD_AUDIO` (`AndroidManifest.xml:3,6`), `RECORD_AUDIO` justified by in-app mic features; no storage/contacts/location.
11. **Secret scan (details in §8):** no real credential anywhere in the working tree, git history (87 commits), or the shipped release APK.
12. **`VACUUM INTO` path escaping:** `database_backup_helper.dart:71-73` doubles single quotes before interpolation; the only path source today is internal timestamped names (`data_management_service.dart:80-94`), not user text — **not** reported as SQLi (the escaping is the correct SQLite literal rule). `p.join` does not allow absolute-path override to escape the backups dir for these fixed inputs.
13. **Build/config basics outside F01:** R8/ProGuard config present and `mapping.txt` generated (`build/app/outputs/mapping/release/mapping.txt`); the merged release manifest contains no `android:debuggable` and no exported service of concern besides F06's backup settings (only `androidx.profileinstaller.ProfileInstallReceiver` guarded by `android.permission.DUMP`, and `androidx.startup.InitializationProvider` not exported — merged release manifest `:91-121`).
14. **No hard-coded secrets in `data_pipeline/`:** no API keys/tokens; endpoints are public dataset URLs; no `shell=True`, `os.system`, `eval(`, `pickle`, `extractall` (grep — `ast.literal_eval` at `build_hsk_vocabulary_dataset.py:94` is the safe literal parser); TLS verification is enforced via `pipeline_config.get_secure_ssl_context()` and F14's claim was independently re-verified (`CERT_NONE`/`verify=False`/`unverified_context` → 0 hits).

---

## 7. Docs claims vs reality

| # | Doc claim | Reality in code/artifact | Verdict |
|---|---|---|---|
| 1 | `docs/architecture-decisions.md:1074`: *“Nạp dữ liệu qua `ContentPackLoader` … xác thực tính toàn vẹn bằng SHA-256 checksum”* (content-pack load is SHA-256 integrity-verified) | The check is self-declared and hard-disabled for `hsk3_pack_v1` via `isKnownValid` (`content_pack_manager.dart:109-121`); the shipped pack's actual hash `22e69bcc…` ≠ declared/whitelisted `43444269…`; remote packs have empty expected checksums (`content_pack_remote_service.dart:91,102`). **F02** | ❌ False as a security control (true only as a self-consistency test for other packs) |
| 2 | `docs/system-documentation/08-content-and-audio.md:44-46`: *“Nếu tệp có khai báo mã băm `sha256`, tính toán SHA-256 … để chống tệp bị hư hại”* | Same bypass; plus generator hashes JSON *before* embedding the hash (`tool/generate_hsk3_cdn_pack.dart:169-177`) so the field can never match final bytes. **F02** | ❌ Misleading |
| 3 | `docs/system-documentation/08-content-and-audio.md:81-89`: disk-space check, per-file SHA-256, atomic promotion before `status='ready'` | Only implemented in `AudioPackDownloader` which has **no production caller**; its `hasSufficientStorage()` is a `return true` stub (F13) and `verifyFileIntegrity('')` returns true (F04). The live zip path's archive checksum is effectively skipped (F03). | ⚠️ Partially true (dead code), overclaimed as shipped behavior |
| 4 | `docs/system-documentation/08-content-and-audio.md` §1 / `architecture-decisions.md:57`: secure storage is *“EncryptedSharedPreferences … Hardware-backed AES/RSA”* | `flutter_secure_storage 11.2.0` default Android impl uses KeyStore-wrapped RSA-OAEP + AES-GCM (not ESPrefs); hardware backing (TEE/StrongBox) and user-auth gating are **not** enforced by the app. Encryption-at-rest itself is real; “hardware-backed” is not guaranteed. | ⚠️ Overclaim wording, no key-storage vuln |
| 5 | `docs/architecture-decisions.md:240`: *“Chặn đứng mọi kết nối HTTP không mã hóa, chỉ cho phép HTTPS và WSS”* (block all cleartext) | `usesCleartextTraffic=false` is real, but **F05** shows `verifyCredentials`/`testConnection` build a request from a raw stored proxy URL with no scheme check (a pre-existing `http://` value would be used), and the proxy blocklist is bypassable for internal HTTPS hosts. | ⚠️ Mostly true, one bypass path |
| 6 | `docs/system-documentation/11-security-and-data-management.md:11`: no hardcoded secrets in source/commit history; `:12` API key never in JSON export | Verified **true** for working tree, all 87 commits and the release APKs (only synthetic fixtures/placeholders; see §8). Export filter drops credential-named keys. **But** the *personal-data* JSON export is put on the clipboard (F12). | ✅ Claim holds (with F12 caveat) |
| 7 | `docs/system-documentation/11-security-and-data-management.md:18-39`: all SQLite queries parameterised | Verified **true** (§6.1). | ✅ Holds |
| 8 | `docs/system-documentation/11-security-and-data-management.md:58-64`: reset requires a *random* confirmation code (`RESET_9482`) and always creates a safety backup first | Code accepts the fixed words `'XOA'`/`'RESET'` and the dialog itself prints them as the hint (`data_management_sheet.dart:163-173, 197, 204-205`); backup failure is caught and reset proceeds (`data_management_service.dart:351-359`). | ❌ Overclaim (weak/known confirmation; "mandatory" backup is best-effort) |
| 9 | `docs/bug-fixes/P1_08_PATCH_AUDIT_AND_SYSTEM_HARDENING.md:42-45`: Zip Slip protection added — *“Validates all zip extraction entries with p.isWithin(canonicalTargetDir, resolvedPath)”* | True for `_extractZipFileSafely` (`audio_pack_manager.dart:28-37`). **Not** applied to the manifest-driven file writes in `AudioPackDownloader`/`AudioStorageManager` (**F04**), which join remote `relative_path`/`audio_id` without canonicalisation. | ⚠️ True for one path, claimed as blanket |
| 10 | `docs/bug-fixes/P0_03_SECURE_API_KEY_STORAGE.md:22-24`: *Zero-Log & redaction* — key never in console/exception messages, all errors pass `sanitizeSecret` | Mostly true: no key logging found; exit paths sanitised. Residual: `sanitizeSecret` only matches `AIza…` and callers sometimes omit `knownKey`; server-controlled error bodies are interpolated verbatim into exception messages (`gemini_rest_ai_provider.dart:466-497`) and one such message is `debugPrint`-ed (`ai_tutor_repository.dart:370`). No practical key leak found without a malicious proxy (F05). | ⚠️ Directionally true, incomplete pattern coverage |
| 11 | `docs/bug-fixes/P0_03…:35-36`: `AppSettingsDao` blocks plaintext credentials | True (`app_settings_dao.dart:22-31`), tested. Note: `DataManagementService.importUserDataJson` writes `app_settings` via raw `txn.insert` and bypasses this guard (`data_management_service.dart:315-331`) — currently unreachable (no import UI), but keep the DAO as the only writer. | ✅ Holds, one latent bypass |
| 12 | `docs/architecture-decisions.md:96-99, docs/system-documentation/06-ai-architecture.md:16`: Gemini 3.8 Live over WebSocket (bidi `BidiGenerateContent`) + VAD/barge-in voice conversation implemented | No WebSocket client code exists (`web_socket_channel` unused; grep). `AiService` always instantiates `GeminiRestAiProvider` (`ai_service.dart:84-87`). Firebase AI Logic/App Check is likewise **not implemented** — no `firebase_*` dependency, no `google-services.json`; the settings card only displays a status enum defaulting to “Chưa cấu hình”. | ❌ Docs/UI advertise unimplemented security/voice capabilities (defense-in-depth claim) |
| 13 | `docs/agent-coordination/reports/thread-5/apk-build-report.md:37`: *“Standard Flutter debug/release default keystore applied for local distribution”* | Honest admission, but the same debug-signed APKs are linked from `README.md:15-16` and attached to GitHub Releases by `.github/workflows/release.yml:40-42` (**F01**) — the doc understates that this is the public distribution channel, not a local-only affair. | ⚠️ Accurate but the release process contradicts the intended use |
| 14 | `docs/bug-fixes/F14_DATA_PIPELINE_SECURITY_AND_PORTABILITY.md:17-29`: all TLS bypasses eliminated; centralised secure downloads with explicit timeouts | True for TLS (`CERT_NONE`/`verify=False` = 0 hits; `pipeline_config.get_secure_ssl_context` enforces `CERT_REQUIRED`+`check_hostname`; test suite exists at `test/pipeline/test_pipeline_security.py`). **But** three scripts still call bare `urllib.request.urlopen` without the timeout helper (F10), and none of the downloads verify data integrity (F09). | ⚠️ TLS claim true; timeout/integrity overclaimed |

---

## 8. Secret scan results

**Scan coverage:** working tree (all files < 40 MB, excluding `.git/.dart_tool/build/.gradle/.idea/release-output`), **all 87 git commits** (`git log -S` + `git grep` on historical blobs), and the contents of `release-apk/app-release.apk` and `release-apk/hi-chinese-v1.0.9-arm64.apk` (all ZIP entries incl. `assets/flutter_assets`).

**Patterns:** `AIza[0-9A-Za-z_-]{20,}`, `sk-[A-Za-z0-9]{20,}`, `BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY`, `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{20,}`, `Bearer [token]`, plus manual grep for `api_key|token|secret|password` in `lib/`, `assets/` (text files), `android/`, `data_pipeline/`, `docs/`, `.github/`.

**Result: no real secret found.** Specific hits and their disposition:

| Hit | Location | Disposition |
|---|---|---|
| `AIzaSyD-TEST-REAL-KEY-123456789012345`, `AIzaSyA_REAL_SECRET_KEY_9876543210987`, `AIzaSyD_TEST_EXISTING_KEY_1234`, `AIzaSyA_NEW_ENTERED_KEY_9999` | `test/features/settings/ai_settings_test.dart:101,119,336,373,431` | Synthetic test fixtures — not valid keys (contain `-`, wrong length/alphabet for a real Google key) |
| `AIzaSyD-test-dummy-key-999` | `test/core/startup/app_startup_integration_test.dart:290,292` | Synthetic |
| `AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P`, `AIzaSy1234567890abcdefghijklmnopqrst`, `AIzaSyGeminiKey…`, `AIzaSyLegacy…`, `AIzaSyPreserve…`, `AIzaSyValidOnboarding…` | `test/core/network/ai/security/ai_credential_security_test.dart:46,58,76,113,182,225,254,329,360` | Synthetic |
| `AIzaSyMockKeyForTesting12345` | `test/core/network/ai/ai_service_test.dart:53` | Synthetic |
| `sk-proj-OpenAiKey12345678901234567890` | `test/core/network/ai/security/ai_credential_security_test.dart:114` (introduced in commit `11f1260`) | Synthetic |
| `AIzaSy...4xQ1`, `AIzaSy...` | `lib/core/network/ai/security/ai_credential_storage.dart:378-379` comment, `lib/features/settings/presentation/screens/ai_settings_screen.dart:288` hint text, docs | UI placeholder/hint text (also why APK `-S AIza` hits exist) — public constant prefix, not a secret |
| `TextEditingController(text: 'secret_api_key_123')` | `lib/features/design_system/presentation/screens/design_system_demo_screen.dart:21` | Demo label string |
| `hi_chinese_dev.db` (18 MB, workspace root) | untracked, **gitignored** (`*.db` at `.gitignore:57-59`) | Scanned with the same patterns → no `AIza`/key hits. Contains local dev learner data; recommend deleting from the workspace and never committing. Not shipped in the APK. |
| `flutter_secure_storage` / KeyStore files | not present in repo (gitignored: `*.keystore`, `*.jks`, `key.properties`, `*.p12`, `*.pem`, `.env`) | ✅ No signing key or env file committed |
| `android/local.properties`, `google-services.json`, `firebase_options.dart` | not committed / absent (`local.properties` is gitignored; SDK path only) | ✅ Clean |

**Git history verdict:** the only historical `AIza`/`sk-` deltas are synthetic test fixtures and placeholder strings added in commits `592dcbf`, `3190343`, `138990b`, `c764384`, `11f1260`; no real credential ever entered history. The docs claim (`11-security…:11`) holds.

**Residual hygiene:** the synthetic `AIzaSy…` fixtures are valid-shaped enough to trigger GitHub secret scanning / push-protection false positives. Recommend adding a `.github/secret_scanning.yml` allowlist for `test/**` or replacing with obviously-invalid placeholders (e.g. `EXAMPLE_KEY_NOT_REAL`). Also note `release-apk/*.apk` (9 binaries, ~240 MB total) are tracked in git — not a secret leak, but they belong in a release bucket, not the repo (see F01).

---

## 9. Attack-chain summary (for the Lead's narrative)

1. **Content poisoning chain (F02 + F07):** compromise `FamAnVMU/hi-chai-ni` (or MITM with MDM/user CA) → serve `hsk3_pack_v1.json` with declared `sha256 = 43444269…` and arbitrary curriculum/exam JSON → app's whitelist accepts it → `ContentPackManager` updates `curriculum_units/lessons/content_items/knowledge_registry/level_exit_exams` under the user's eyes as an official HSK-3 download; no signature, no catalog hash, no way to distinguish from the APK-bundled packs because the remote install is also recorded as `bundled`.
2. **Release trust chain (F01):** nobody needs to break crypto — the official download links/Release assets are debug-signed; the update identity weakness and Play incompatibility are inherent; if the debug keystore (a file, not a secret-server credential) is ever copied/leaked, a malicious "v1.0.10" APK with the same package name installs as an update and inherits all app-private data at install time.
3. **Key-theft chain (F05):** attacker publishes/pushes a "Gemini proxy" URL or a support instruction → learner pastes it in Settings → every AI request (and every "Test connection" tap) sends `x-goog-api-key` to the attacker, who replays it against Google (the user pays); IPv6-loopback/127.0.0.2/172.16-31/169.254/link-local-style URLs pass the blocklist for SSRF/credential forwarding; a legacy `http://` value would be attempted by verify/test despite the missing scheme guard (Android's `usesCleartextTraffic=false` is the only remaining backstop).
4. **Privacy chain (F06 + F12):** learner DB (profile + AI chat transcripts) is eligible for Auto Backup and the unencrypted `.hibak` copies live beside it; exporting "personal data" puts profile JSON on the system clipboard — two low-effort exfiltration surfaces that contradict the "100% local, zero-account" design.

---

## 10. Remediation priority (concrete order)

1. **F02** — remove the hard-coded whitelist; require a catalog-pinned/detached SHA-256 or Ed25519 signature before any remote pack installs; fix `tool/generate_hsk3_cdn_pack.dart`; add a tamper test. *(hours)*
2. **F01** — real release keystore, remove debug fallback (build must fail), remove tracked APKs and enforce a signature check in CI before publishing. *(hours; requires a key, so schedule OTP)*
3. **F05** — single `resolveBaseUrl()` with parser-based private/loopback rejection used by all four request paths, warn on proxy save, re-validate on read. *(hours)*
4. **F03/F04** — mandatory checksums sourced from app-pinned metadata; canonicalise+`isWithin` on every manifest-derived write; cap download/entry sizes; add timeouts. *(hours)*
5. **F06** — `allowBackup="false"` + extraction rules (or encrypt `.hibak`); document privacy posture. *(minutes)*
6. **F07/F08/F09/F10/F11/F12/F13/F14/F15** — hygiene and hardening; each is small and independently testable.

*All findings above were re-read and line-verified against the working tree at audit time; no application files were modified by T2.*
