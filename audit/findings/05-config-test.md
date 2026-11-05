# T5 — Build/Test/Docs Audit

**Task:** task-5 — Build/release config, test-suite credibility & docs-vs-code drift
**Auditor:** teammate `config-test` (T5)
**Date:** 2026-11-04
**Workspace HEAD:** `5c099ba` (`main`), working tree clean
**Detected environment:** Flutter **3.47.9** stable / Dart **3.13.7** (from `C:\src\flutter\bin\cache\flutter.version.json`), Android SDK platforms `android-34/35/36/37`, build-tools `34.0.0/35.0.0/36.0.0`
**Method:** read-only inspection + local static verification: Gradle/manifest/CI/pubspec reads; `apksigner`/`aapt2` on committed APKs; SHA-256 of content packs; `git ls-files`; `flutter test` attempted (see section D). No source/build/test/artifact files were modified.

Legend: **[CONFIRMED]** = proven from files/tool output; **[LIKELY]** = strongly indicated by config/behavior; **[RISK]** = credible risk not directly reproducible.

---

## Top 5 priority order

1. **[T5-F01] Critical — Release APKs are signed with the public Android *debug* certificate.** Every "release" artifact and the CI-published APK are update-hijackable and Google-Play-rejectable.
2. **[T5-F02] Critical — HSK-3 content-pack SHA-256 verification is hard-bypassed in code, and the committed HSK-3 pack hash is now wrong.** The original P1 blocker `BUG-CORE-001` was masked, not fixed, and remote content installation runs without integrity verification.
3. **[T5-F03] High — Android toolchain is below Flutter 3.47.9's minimum (AGP 8.7.0 < 8.11.1) and `compileSdk` 37 is outside AGP 8.7's support.** Release builds only succeed with `--android-skip-build-dependency-validation`, so the shipped APK is produced by an unsupported toolchain.
4. **[T5-F04] High — The release workflow publishes pre-built APKs committed to git, with no build/test/sign/checksum step and hard-coded `v1.0.9` paths.** Tagging any future release republishes stale debug-signed binaries.
5. **[T5-F10] High — The 16-step SQLite migration chain is not tested; only a synthetic v1→v2 mock is.** Existing users' upgrade (v11/v15/v16 etc.) is unproven, which is a data-loss class of risk for a store update.

---

# A) Build & Release

## [T5-F01] Release build type signs with the debug keystore; no release signing config exists

- Severity: Critical
- Confidence: CONFIRMED
- Location: `android/app/build.gradle.kts:26-35` (artifact: `release-apk/app-release.apk`, `release-apk/hi-chinese-v1.0.9-arm64.apk`)
- Evidence:
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
  There is **no `signingConfigs { create("release") { … } }` block anywhere** in `android/app/build.gradle.kts`, therefore `findByName("release")` is always `null` and the debug key is always used. No `key.properties`/`*.jks`/`*.keystore` exists in the workspace (recursive search returned zero files).
  Tool proof on the shipped artifact:
```text
$ apksigner verify --print-certs --verbose release-apk\app-release.apk
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Number of signers: 1
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 20f6ccb1afa034fdd71be65c1cb6cbca56845bc3ee1e8c51ab3b6388de90567a
```
  The repo's own audit report confirms this is known and unresolved: `docs/agent-coordination/reports/thread-5/apk-build-report.md:37` — *"Standard Flutter debug/release default keystore applied for local distribution. Official Google Play upload keystore signing remains pending Project Owner credential provisioning."*
- Root cause: A scaffolded release build type with a "fallback to debug" convenience line, and no release keystore provisioning process. The fallback can never fall back to anything else because no `release` signing config is ever defined.
- Impact: (a) Google Play rejects any AAB/APK signed with the debug certificate; (b) the public `androiddebugkey`/`android` credential is known to everyone, so a third party can sign a malicious update that Android will accept over the installed app on users who sideload the GitHub-release APK; (c) if the project later switches to a real upload key, already-installed users cannot receive an update unless Play App Signing key migration is set up; (d) release provenance is meaningless.
- Fix: define a `signingConfigs.create("release")` block that reads `storeFile`/`storePassword`/`keyAlias`/`keyPassword` from `key.properties` (already git-ignored at `.gitignore:43-49`), fail the build (`throw GradleException`) when `key.properties` is missing instead of falling back to debug, inject secrets via CI (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`), then delete the `?: signingConfigs.getByName("debug")` line. Rebuild every `release-apk/*` artifact and verify with `apksigner verify --print-certs` that `CN` is not `Android Debug`. Add a CI assertion for this.
- Verification status: `apksigner` executed on both v1.0.9 APKs (CD `CN=Android Debug`); absence of any release signing config confirmed by full read of `android/app/build.gradle.kts` and filesystem search for keystores/`key.properties`. Build report corroborates.

---

## [T5-F02] HSK-3 checksum validation is hard-bypassed in production code; committed pack hash does not match content

- Severity: Critical
- Confidence: CONFIRMED
- Location: `lib/features/content_packs/data/content_pack_manager.dart:110-121`; `content_packs_cdn/hsk3_pack_v1.json:10`; `lib/features/content_packs/data/content_pack_remote_service.dart:91`
- Evidence:
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
```
```json
// content_packs_cdn/hsk3_pack_v1.json:9-10
"size_bytes": 8885,
"sha256": "434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2"
```
  The actual file on disk hashes to a different value, so this exemption is the only reason installation succeeds:
```text
manifest.size_bytes = 8885
manifest.sha256     = 434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2
actual SHA-256      = 22E69BCC7686019A05282D2AFBBE0DDEB659A5B7E186723C785EFDB1D4B67626   <-- MISMATCH
```
  The remote catalog additionally turns verification off for the same pack:
```dart
// lib/features/content_packs/data/content_pack_remote_service.dart:83-92
const RemoteContentPackInfo(
  packId: 'hsk3_pack_v1',
  ...
  downloadUrl: '$cdnBaseUrl/hsk3_pack_v1.json',
  sha256Checksum: '',          // <-- empty => the `if (packInfo.sha256Checksum.isNotEmpty)` check at :140 is skipped
```
  The former release blocker is recorded in `docs/agent-coordination/reports/thread-5/bug-register.md:22-41` (`BUG-CORE-001`, P1) and still listed as unresolved in `release-output/HI-Chinese-v1.0.0/release-manifest.json:20`.
- Root cause: Instead of regenerating the pack (as `tool/generate_hsk3_cdn_pack.dart` already exists to do) and fixing the manifest hash, the validation was patched with a hard-coded "known valid" escape hatch for one pack id, and the remote catalog checksum was blanked. The pack file then changed again after the hash update (commit `56edb7a`), leaving the on-disk hash `22E6…` vs manifest `4344…`.
- Impact: Remote content packs are installed with **no integrity or authenticity verification** for HSK-3 (and any future pack with an empty checksum). A corrupted or MITM-replaced `hsk3_pack_v1.json` will be parsed and installed into user databases. It also means `BUG-CORE-001` is not actually resolved — it was silenced — and the test that should catch it (`content_pack_service_test.dart`, see T5-F13) now passes for the wrong reason. This is a supply-chain integrity defect in a release artifact.
- Fix: (1) delete the `isKnownValid` exemption block (`content_pack_manager.dart:112-115`) entirely and keep a single strict comparison; (2) regenerate `content_packs_cdn/hsk3_pack_v1.json` deterministically with `tool/generate_hsk3_cdn_pack.dart`, update `manifest.sha256`/`size_bytes` to the generated bytes; (3) set a real `sha256Checksum` in `ContentPackRemoteService.getAvailablePacks()` (line 91) computed from the same file; (4) add a test that a tampered payload is rejected (`expect(result.isSuccess, isFalse)`), and a CI step that recomputes and compares every `content_packs_cdn/**` hash.
- Verification status: Read the source verbatim; recomputed SHA-256 with `Get-FileHash` (22E69BCC…), compared to the in-file manifest value (43444269…) and the hard-coded exemption literal; confirmed empty hash in the remote catalog. `flutter test` could not run here (section D) but the branch is statically unambiguous.

---

## [T5-F03] Android toolchain is below Flutter 3.47.9 minimums; release builds require a validation-bypass flag

- Severity: High
- Confidence: CONFIRMED
- Location: `android/settings.gradle.kts:20-24`, `android/gradle/wrapper/gradle-wrapper.properties:5`, `android/app/build.gradle.kts:9`
- Evidence:
```kotlin
// android/settings.gradle.kts:20-24
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```
```properties
# android/gradle/wrapper/gradle-wrapper.properties:5
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-all.zip
```
```kotlin
// android/app/build.gradle.kts:9
compileSdk = 37
```
  Flutter 3.47.9 enforces (SDK source `C:\src\flutter\packages\flutter_tools\gradle\src\main\kotlin\DependencyVersionChecker.kt:94-109`):
```kotlin
internal val errorGradleVersion: Version = Version(8, 14, 0)     // Gradle >= 8.14.0 required
internal val errorAGPVersion: AndroidPluginVersion = AndroidPluginVersion(8, 11, 1)  // AGP >= 8.11.1 required
internal val errorKGPVersion: Version = Version(2, 2, 20)       // Kotlin >= 2.2.20 required
internal val warnAGPVersion: AndroidPluginVersion = AndroidPluginVersion(9, 0, 1)
```
  Flutter 3.47.9 project template targets AGP `9.1.0`, Gradle `9.3.1`, Kotlin `2.4.0`, `compileSdk = 36` (`C:\src\flutter\packages\flutter_tools\lib\src\android\gradle_utils.dart:36,44,52,61`).
  The repo's own build record confirms the bypass was needed for the shipped v1.0.9 build — `docs/agent-coordination/reports/thread-5/apk-build-report.md:13`:
  `| **Build Command** | flutter build apk --release --android-skip-build-dependency-validation |`
  (The earlier `BUG-RELEASE-001` at `docs/agent-coordination/reports/thread-5/bug-register.md:67-86` only mentioned Gradle 8.10.2; after the Gradle bump the **AGP** is now the binding violation.)
- Root cause: The Flutter template was generated with an older toolchain and only Gradle was bumped (commit `56edb7a`), not AGP/Kotlin/compileSdk. `compileSdk = 37` was raised manually, but AGP 8.7.0's tested compileSdk ceiling is 35 and Flutter's own default for 3.47.9 is 36; the project therefore builds Android-17-preview metadata (`platformBuildVersionCode='37'`) with an AGP that knows nothing about API 37.
- Impact: The published APK is produced by a **configuration that Flutter 3.47.9 officially rejects**; any Flutter upgrade, Android Studio/Gradle upgrade or clean CI machine can fail the build, and R8/manifest-merger behavior for API 37 with AGP 8.7 is untested (silent build regressions, resource shrinker rules, future `targetSdk` rollout). Reviews of the shipped APK can't rely on AGP support statements. `compileSdk 37` also forces API-37 preview SDK installation, which is not available on standard CI images.
- Fix: Align to the Flutter 3.47.9 template: AGP `9.1.0`, Gradle `9.3.1`, Kotlin `2.4.0` in `settings.gradle.kts`/wrapper, `compileSdk = 36` (or `36`-plus AGP 9.x if 37 is truly needed), Java 17 target kept. Rebuild with plain `flutter build apk --release` (no bypass flag) and make that a CI gate; keep `--android-skip-build-dependency-validation` out of documentation.
- Verification status: Versions read verbatim; Flutter minima read from the installed SDK source; bypass flag confirmed in the repo's apk-build-report; APK metadata `compileSdkVersion='37', targetSdkVersion='36'` confirmed with `aapt2 dump badging`; AGP ceiling for 8.7 (35) from AGP's published compatibility notes ([LIKELY] exact warning wording, [CONFIRMED] toolchain drift itself).

---

## [T5-F04] Release workflow publishes committed APKs with no build, test, signing, or checksum verification

- Severity: High
- Confidence: CONFIRMED
- Location: `.github/workflows/release.yml:3-7,16-20,40-42`
- Evidence:
```yaml
# .github/workflows/release.yml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
...
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Create GitHub Release with Assets
        uses: softprops/action-gh-release@v2
...
          files: |
            release-apk/hi-chinese-v1.0.9-arm64.apk
            release-apk/app-release.apk
```
  There is no `flutter build`, no `flutter test`, no `flutter analyze`, no signing step, no checksum generation and no secret usage in the workflow. The two asset paths are hard-coded to `v1.0.9` and both files are tracked binaries in git (see T5-F05). Tags `v1.0.0`…`v1.0.9` already exist locally.
- Root cause: The "release" pipeline was written to attach whatever binaries happen to be committed, assuming a human replaced the files before tagging. There is no linkage between tag/commit and artifact provenance.
- Impact: Tagging `v1.1.0` publishes the `v1.0.9` binaries under the new tag (or fails if files renamed) while claiming the new version; users/tests get a debug-signed, unreproducible artifact with no checksum; a compromised checkout can exfiltrate any APK as an official release. Combined with T5-F01 this means official releases are debug-signed and unverifiable.
- Fix: Build inside CI from the tagged commit (`flutter test`, `flutter build apk --release --split-per-abi`, `flutter build appbundle --release`), inject keystore from encrypted secrets, generate `SHA256SUMS`, attach both APK/AAB and checksums, and fail the job if `apksigner` shows `CN=Android Debug`. Remove the committed `release-apk/*` from the release `files:` list.
- Verification status: Workflow file read completely (42 lines); repo `git tag` output includes v1.0.0–v1.0.9; `git ls-files` confirms both referenced APKs are tracked.

---

## [T5-F05] Nine release APKs (224.1 MB) are committed to git; the "arm64" APK is a universal 3-ABI build

- Severity: Medium
- Confidence: CONFIRMED
- Location: `release-apk/` (9 tracked files), `.gitignore:64-69`
- Evidence:
```text
# git ls-files | grep release-apk
release-apk/app-release.apk
release-apk/hi-chinese-v1.0.2-arm64.apk
... (v1.0.3 … v1.0.9)
# total: count=9, 224.1 MB
```
```text
# aapt2 dump badging release-apk/hi-chinese-v1.0.9-arm64.apk
package: name='com.hichinese.hi_chinese' versionCode='10' versionName='1.0.9'
native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'
```
```gitignore
# .gitignore:64-69
# Data pipeline scrapings
data_pipeline/raw/
data_pipeline/processed/
data_pipeline/audio_staging/
release-output/
```
  `release-apk/` is **not** ignored (only `release-output/` is), so every debug-signed binary is versioned forever.
- Root cause: Manual copy-to-`release-apk/` workflow documented at `docs/system-documentation/12-build-test-deployment.md:80-85`, with no `.gitignore` entry for the output folder.
- Impact: ~224 MB of unreproducible binaries in the repository (clone/push cost, secret/artifact scanning blind spot); artifact naming lies (`hi-chinese-v1.0.9-arm64.apk` actually contains `armeabi-v7a` and `x86_64`, contradicting README:11/15 and docs:12:18,71-73 "arm64 only / never build fat APK"); `app-release.apk` and `hi-chinese-v1.0.9-arm64.apk` are byte-identical duplicates (35,866,699 bytes each).
- Fix: `git rm --cached release-apk/*` and add `release-apk/` to `.gitignore`; publish artifacts only through CI Releases; if a size-limited `arm64` APK is the goal, build with `flutter build apk --release --target-platform android-arm64` (the actual output will then show only `arm64-v8a`).
- Verification status: `git ls-files`, `Measure-Object` totals, `aapt2 dump badging`, and byte-size comparison all executed. A ZIP central-directory scan of `app-release.apk` (934 entries) found **no** keystore/`key.properties`/`.env`/`.db`/`.git` entries, so no secret material is accidentally bundled in the shipped APK (the risk is the signing key instead — T5-F01).

---

## [T5-F06] The only release manifest says the release gate is BLOCKED, yet v1.0.9 is published and shipped

- Severity: Medium
- Confidence: CONFIRMED
- Location: `release-output/HI-Chinese-v1.0.0/release-manifest.json:1-23`
- Evidence:
```json
// release-output/HI-Chinese-v1.0.0/release-manifest.json
  "version": "1.0.0",
  "version_code": 1,
  "build_timestamp": "2026-11-04T13:24:05Z",
  "git_commit": "394bb5d",
  ...
  "release_gate_status": "BLOCKED",
  "gate_blockers": [
    "BUG-CORE-001 (P1): SHA-256 hash mismatch in hsk3_pack_v1.json blocks remote content pack downloading",
    "BUG-VOICE-001 (P1): Null overallScore on invalid audio path in DefaultPronunciationAnalysisService breaks master regression suite"
  ]
```
  `README.md:9-16` advertises v1.0.9 APKs and `.github/workflows/release.yml` publishes them, although the last recorded gate is BLOCKED at commit `394bb5d` (a commit older than the v1.0.9 build commit `e419d62`). Post-blocker code state: `BUG-VOICE-001` *is* fixed (`lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart:95-113` now returns `overallScore: 0.0`), but `BUG-CORE-001` is only masked (T5-F02), and no new gate record exists.
- Root cause: Gate metadata is hand-maintained, not generated/checked by CI, and was never regenerated after the v1.0.9 build. `release-output/` is git-ignored, so even this stale record is invisible to reviewers.
- Impact: The repository simultaneously claims "BLOCKED" and "download v1.0.9"; there is no auditable release-approval record for the artifact that users install, and a P1 blocker was effectively waived without a documented risk-acceptance decision (explicitly required by the project's own gate policy quoted in `docs/agent-coordination/reports/thread-5/release-readiness-report.md:12-16`).
- Fix: Generate the release manifest from CI at build time (version, commit, hashes of artifacts, gate status); make tag creation depend on `release_gate_status == "PASSED"`; re-run the gate on the current commit and record the decision (including the HSK-3 checksum fix) in a tracked file under `docs/`.
- Verification status: Read manifest/report/README/workflow; confirmed v1.0.9 commit ordering via `git log`; confirmed the pronunciation fix in source.

---

## [T5-F07] Version is defined in three places and one of them is stale (1.0.0 vs 1.0.9)

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/core/constants/app_constants.dart:5`, `lib/features/content_packs/data/content_pack_manager.dart:20`, `pubspec.yaml:19`
- Evidence:
```dart
// lib/core/constants/app_constants.dart:5
static const String appVersion = '1.0.0';
```
```dart
// lib/features/content_packs/data/content_pack_manager.dart:20
static const String currentAppVersion = '1.0.9';
```
```yaml
# pubspec.yaml:19
version: 1.0.9+10
```
- Root cause: No single source of truth/generated build constant; three hand-maintained copies drifted (`appVersion` stayed at 1.0.0; content-pack gating has a separate hard-coded 1.0.9).
- Impact: Any "About/version" surface using `AppConstants.appVersion` (currently unused, so latent) would display 1.0.0 on a 1.0.9 app; more seriously, `ContentPackManager.isAppVersionSatisfied()` uses a hard-coded `currentAppVersion` that will block all future remote packs requiring ≥1.1.0 until a developer remembers to edit line 20 — a release-time landmine that no test covers.
- Fix: Add `package_info_plus` (or generate `lib/generated/build_info.dart` from `pubspec.yaml` in CI) and use it for both the About screen and pack gating; delete `AppConstants.appVersion` and `ContentPackManager.currentAppVersion`. Add a test asserting the gating version equals `PackageInfo.version`.
- Verification status: Grep for `appVersion` across `lib/` (only definition + unrelated locals) and read both constants plus pubspec/APK badging (`versionCode 10`, `versionName 1.0.9`).

---

## [T5-F08] Release manifest lacks backup/data-extraction hardening

- Severity: Low
- Confidence: CONFIRMED
- Location: `android/app/src/main/AndroidManifest.xml:11-15`
- Evidence:
```xml
<application
    android:label="HI Chinese"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="false">
```
  There is no `android:allowBackup`, no `android:fullBackupContent`, and no `android:dataExtractionRules` (Android 12+), which means the platform default is `allowBackup="true"` and cloud/ADB backup includes the SQLite learning DB (`hi_chinese.db`, WAL) and shared-preferences.
- Root cause: Template manifest was never reviewed for release hardening.
- Impact: Learner progress/profile data is eligible for automatic cloud backup and `adb backup` extraction on debuggable builds; backup/restore of a live SQLite WAL DB can also produce a torn snapshot when restored on another device. Not store-blocking, but a privacy/data-integrity gap for a "100% offline local data" app, and it contradicts the offline/local-data positioning in README:5/23.
- Fix: Add `android:allowBackup="false"` (or explicit `dataExtractionRules`/`fullBackupContent` XML that includes only the DB via a transaction-safe backup), and if backups are wanted, hook the existing `DatabaseBackupHelper`/`.hibak` export instead of OS auto-backup. Add a manifest assertion to a CI check (`aapt2 dump xmltree`).
- Verification status: Manifest read in full; no backup attributes present; app DB path/backup helper confirmed at `lib/core/database/app_database.dart:51-58,116-126`.

---

## [T5-F09] Bundled pack metadata is inconsistent with the actual asset bytes (empty/wrong checksums and wrong size)

- Severity: Medium
- Confidence: CONFIRMED
- Location: `assets/data/content_packs/hsk1/hsk1_pack_v1.json` (manifest object), `assets/data/content_packs/hsk2/hsk2_pack_v1.json`, `lib/features/content_packs/data/content_pack_remote_service.dart:80`
- Evidence:
```text
hsk1_pack_v1.json  manifest.size_bytes = 15728640   actual file size = 170878
hsk1_pack_v1.json  manifest.sha256     = ""         actual sha256    = 6B8FB75451CBE7E0DFF62EF8DC0893947E4C6702A6F8B7F2769F78F0F5F41D7E
hsk2_pack_v1.json  manifest.size_bytes = 176358     actual size = 176358 (OK)
hsk2_pack_v1.json  actual sha256       = 6C6DFF583589995BC34164591634779CA830C5C43863C808E132765DE8F26A20
remote catalog hsk2 sha256Checksum      = 78f92b4baeb9931b37df8b6998fe76014ba80e68459c367b6119261e06057fcb  <-- MISMATCH
```
- Root cause: Pack files were regenerated/adjusted after the manifest was written; the manifest metadata is not generated from the final file bytes. `ContentPackManager.validateManifest()` only checks a checksum when `manifest.sha256.isNotEmpty` (`content_pack_manager.dart:110`), so empty hsk1 hash = silently unchecked.
- Impact: The "integrity" tests (`test/features/curriculum/hsk1_content_integrity_test.dart:25-146`) never assert `size_bytes`/`sha256`, so a wrong or missing checksum ships unnoticed; the hsk2 catalog checksum is guaranteed to reject a correctly-downloaded file if that path is ever enabled. Tampered/corrupted bundled packs would be installed.
- Fix: Generate manifests programmatically (`tool/generate_hsk1_pack.dart` / `hsk2`) to stamp `size_bytes` and `sha256` from the exact emitted bytes; extend the integrity test to recompute SHA-256 and compare with manifest and remote-catalog values; make empty checksums a validation error for non-bundled packs.
- Verification status: `ConvertFrom-Json` on both pack files + `Get-FileHash`; compared with catalog constants at `content_pack_remote_service.dart:69,80`.

---

# B) Test Credibility

## B.0 Suite metrics (measured, not claimed)

| Metric | Value | Method |
|---|---|---|
| Test `.dart` files under `test/` | **92** (91 test files + 1 helper `test/helpers/mock_audio_platform.dart`) | `Get-ChildItem -Recurse test -Filter *.dart` |
| Lines of test code | **20,431** | `Measure-Object -Line` |
| Declared cases (`test(` + `testWidgets(` at line start) | **622** (481 + 141) | anchored regex over all test files |
| `expect()` calls | **2,976** (~4.8 per case; ~32.7 per test file) | anchored `expect\(` count |
| Files containing at least one `expect` | **91 / 91** test files | same |
| Skipped tests (`skip:` on a test declaration) | **0** (the two `skip:` hits are `onSkip:` callbacks: `ai_credential_security_test.dart:304`, `onboarding_flow_test.dart:21`) | grep |
| Widget-test files / `pumpWidget` calls | **32 files / 140 pumps** | grep |
| Tests genuinely executing SQLite | **50 files import `sqflite_common_ffi`**, DB opened in-memory or temp file | grep |
| Mocktail mocks of the DB/repository layer | **0** — only **1** mocktail import and a single `MockHttpClient extends Mock implements http.Client` (`content_pack_service_test.dart:11`) | grep |
| `rowsAffected` assertions | **0** | grep over `test/**` |
| Real-clock waits in tests (`Future.delayed`) | **12 occurrences in 4 files** | grep |
| Files using `DateTime.now()` | **42** test files | grep |
| `fake_async` / controllable clock | **0 references** | grep |
| `catch` blocks in tests | **9** (mostly teardown; 3 swallow errors mid-test) | grep |
| `assert(true)`-style filler | **none found** | grep |

**Positive (important for credibility):** the common hypothesis "DB tests mock away SQLite with mocktail repositories" is **false** in this repo. 50 test files boot a real FFI SQLite database; only the HTTP client and native audio platform are mocked/faked. Assertion density is high (2,976 expects), no test is skipped, and the HSK-1 content-integrity test does verify the headline curriculum counts (15 lessons / 150 words / 45 grammar points / 150 exercises / exit exam 20+20) against the real asset JSON — i.e., the docs' curriculum numbers are backed by a test.

**Negative:** the suite never exercises *upgrade* migrations, production DB PRAGMAs in its master regression, the platform-channel secure store, the remote-download/checksum branch, or Zip-Slip rejection; and it uses real clocks. These are detailed below.

## [T5-F10] The 16-step migration chain is untested; only a synthetic v1→v2 mock migration is

- Severity: High
- Confidence: CONFIRMED
- Location: `test/core/database/database_migration_test.dart:6-27,65-127`; `lib/core/database/migrations/migration_engine.dart:36-54`
- Evidence:
```dart
// test/core/database/database_migration_test.dart:6-27 — the "v2" under test is a fixture, not production code
// Test migration v2 adding a new audio cache table
class MockMigrationV2 implements Migration {
  @override
  int get version => 2;
  ...
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE audio_cache ( ... );
```
```dart
// test/core/database/database_migration_test.dart:66-70 — engine is constructed with only V1 + MockV2
final engine = MigrationEngine(
  migrations: [
    MigrationV1(),
    MockMigrationV2(),
  ],
);
```
```dart
// lib/core/database/migrations/migration_engine.dart:37-54 — production registers MigrationV1..V16
: _migrations = migrations ?? [
    const MigrationV1(),
    const MigrationV2(),
    ...
    const MigrationV16(),
  ];
```
  The entire suite contains **no test that upgrades a real database from an older version to the current one**: grep for `MigrationV13/14/15/16`, `oldVersion`, upgrade loops in `test/**` finds only (a) fresh `executeMigrations(db, 0, currentDatabaseVersion)` in ~20 files, (b) one direct `MigrationV14` unit test and one `MigrationV15` unit test, (c) the mock-v2 test above. There is no `for (int v = 1; v <= 16; …)` progression, no seeded v11/v15 fixture, and no assertion that `PRAGMA user_version` ends at 16 for upgrade paths.
- Root cause: Tests were written to create a fresh DB with the *current* schema rather than to simulate an existing user DB at an older `user_version`.
- Impact: The riskiest code path in a store update — upgrading an installed v1.0.x user's `hi_chinese.db` through `MigrationV2…V16` inside `onUpgrade` — is unproven. A single non-idempotent `ALTER TABLE`/`CREATE INDEX` in the 16-step chain, or an ordering error, would be discovered only by users after a release (data loss / startup crash). The one real v14/v15 tests validate table creation on an empty DB, not the `vN → vN+1` transition.
- Fix: Add a parameterized migration-matrix test: for each `from in 1..15`, copy a seeded fixture DB (`hi_chinese_v$from.db` or programmatically built at `from`), open via `AppDatabase.open`, assert no throw, `PRAGMA user_version == 16`, `PRAGMA foreign_key_check` empty, row counts of sentinel rows preserved, and `integrity_check == ok`. Keep a v1 fixture and a recent v15 fixture generated once by the migrations themselves. Gate CI on it.
- Verification status: Full read of `database_migration_test.dart` (185 lines), `migration_engine.dart` (92 lines), `database_constants.dart:5`; grep for upgrade-path patterns across `test/**` returned none.

## [T5-F11] Two test harnesses build databases that do not match production configuration

- Severity: Medium
- Confidence: CONFIRMED
- Location: `test/regression/full_app_regression_test.dart:36-44`; `test/core/database/upsert_safety_test.dart:31-45`; production `lib/core/database/app_database.dart:62-83`
- Evidence:
```dart
// test/regression/full_app_regression_test.dart:39-43 — raw factory, no onConfigure, migrations applied after open
db = await databaseFactory.openDatabase(dbPath);
// Apply migrations v0 -> v8
final engine = MigrationEngine();
await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);
```
```dart
// production guarantees: lib/core/database/app_database.dart:66-68
onConfigure: (db) async {
  // 1. Enable SQLite Foreign Keys constraint enforcement
  await db.execute('PRAGMA foreign_keys = ON;');
```
```dart
// test/core/database/upsert_safety_test.dart:32-44 — schema built as "version: 1"
db = await openDatabase(
  inMemoryDatabasePath,
  version: 1,
  onConfigure: (d) async { await d.execute('PRAGMA foreign_keys = ON;'); },
  onCreate: (d, v) async {
    await const MigrationV1().up(d);
    await const MigrationV5().up(d);
    await const MigrationV9().up(d);
    await const MigrationV10().up(d);
    await const MigrationV12().up(d);
  },
);
```
- Root cause: Test authors bootstrapped just the tables each test needs, not the production `AppDatabase` lifecycle; the master regression test's comment ("migrations v0 -> v8") is two schema generations stale.
- Impact: `full_app_regression_test.dart` runs the "master regression" with **foreign keys disabled** — FK violations that production would reject can silently pass here (and its `DatabaseBackupHelper.checkIntegrity` only runs `PRAGMA integrity_check`, which does not test FKs). `upsert_safety_test.dart` validates upserts against a schema that is *not* v16 (no v13–v16 tables/columns/indexes) and leaves `user_version` at 1 while running v12 DDL; a change in production migrations that breaks this scenario would not be caught. Both harnesses weaken the tests that are supposed to prove data safety.
- Fix: Replace every ad-hoc `databaseFactory.openDatabase(...)` in tests with `AppDatabase.instance.open(customPath: …, customFactory: databaseFactoryFfi)` so `onConfigure` (FK=ON, WAL, synchronous=NORMAL) and the full migration engine are always used, then assert `PRAGMA foreign_keys == 1` and `user_version == 16` in `setUp`. Delete the partial-migration bootstraps and let `onCreate` build v16.
- Verification status: Read both test files and `app_database.dart`; grep of `foreign_keys` shows only 10 of the DB-booting tests set it (the rest rely on defaults/off).

## [T5-F12] Upsert safety never asserts `rowsAffected`; silent no-op updates would pass

- Severity: Medium
- Confidence: CONFIRMED
- Location: `test/core/database/upsert_safety_test.dart:315-397`; `lib/features/content_packs/data/content_pack_manager.dart:25-51`
- Evidence (grep result, entire `test/**`):
```text
=== rowsAffected in tests ===
(no output — 0 occurrences)
```
```dart
// test/core/database/upsert_safety_test.dart:339-354 — re-insert "updates" but only reads values
await vocabDao.insertVocabulary({ 'id': 'VOC_TEST_1', ... 'hanviet': 'Khán', ... });
// 4. Verify sense WAS NOT cascade deleted!
final senses = await vocabDao.getSensesByVocabularyId('VOC_TEST_1');
expect(senses.length, equals(1));
...
```
- Root cause: Tests assert final row content, never the written-row count or that a second import did not create duplicate/no-op writes.
- Impact: The "P0-04 non-destructive upsert" fix (claimed in `docs/bug-fixes/P0_04_SQLITE_UPSERT_SAFETY.md`) is only half-proven: `_safeUpsert` uses `query → update | insert(ignore)` (`content_pack_manager.dart:25-51`) and discards the `update`/`insert` return value, so an accidentally-empty `values` map, a wrong `where` clause, or a conflicting unique index would silently pass every test. Idempotency assertions (re-import → exactly 1 row, unchanged unchanged-fields) are present in a couple of places but not the update-count.
- Fix: Assert `rowsAffected == 1` on updates and `== 1` (or `0` for ignore) on inserts by changing DAOs/`_safeUpsert` to return `int` and asserting it; add a test that re-importing a pack leaves `COUNT(*)` unchanged and `updated_at`/progress fields preserved, plus a test where `_safeUpsert` receives a stale/missing PK and must not create duplicates.
- Verification status: Grep over all 92 test files for `rowsAffected` returned zero matches; read the upsert test and the `_safeUpsert` implementation.

## [T5-F13] Remote download / checksum / extraction paths are not actually tested (test relies on production dev-fallback)

- Severity: Medium
- Confidence: CONFIRMED
- Location: `test/features/content_packs/content_pack_service_test.dart:84-116`; `test/features/sentences/audio_pack_cdn_test.dart:89-120`; production `lib/features/sentences/data/audio_pack_manager.dart:140-228`
- Evidence:
```dart
// test/features/content_packs/content_pack_service_test.dart:92-102
final targetPack = const RemoteContentPackInfo(
  packId: 'hsk3_pack_v1',
  ...
  sha256Checksum: '',            // <-- checksum branch in the service is skipped entirely
```
```dart
// test/features/sentences/audio_pack_cdn_test.dart:89-99
test('HSK 3 downloads and auto-extracts zip archive from GitHub CDN', () async {
  double lastProgress = 0.0;
  await packManager.downloadPack(
    'audio_pack_hsk3',
    onProgress: (prog) { lastProgress = prog; },
  );
  expect(lastProgress, 1.0);
```
```dart
// lib/features/sentences/data/audio_pack_manager.dart:192-227 — when the HTTP call fails, production code
// silently simulates progress and extracts a repo-local zip if present
} catch (e) {
  ...
  for (int step = 1; step <= 10; step++) {
    await Future.delayed(const Duration(milliseconds: 20));
    onProgress?.call(step / 10.0);
  }
...
if (targetDir.listSync().isEmpty) {
  final localFallbackZip = File('content_packs_cdn/packages/audio_pack_hsk$level.zip');
  if (localFallbackZip.existsSync()) { ... await Isolate.run(() => _extractZipFileSafely(...)); }
```
- Root cause: The "CDN" tests run with no network; the HTTP failure path falls through to a dev-only local-file fallback that is compiled into production code, and the content-pack test explicitly disables the checksum under test.
- Impact: The two most security/robustness-sensitive paths — (1) SHA-256 rejection of a tampered remote pack, (2) real zip download + extraction from a remote archive — have **no passing coverage**. Worse, the test certifies behavior that in production would report `onProgress: 1.0` and "installed" even when nothing was downloaded and no local fallback exists (offline user). The Zip-Slip defence (`audio_pack_manager.dart:14-47`) is never fed a malicious archive, so its claim (F-05 in docs) is unverified.
- Fix: In `content_pack_service_test.dart`, test with a non-empty `sha256Checksum` for both matching and mismatching payloads (assert failure for mismatch) and remove the hard-coded exemption first (T5-F02). In `audio_pack_cdn_test.dart`, inject `http.Client` (constructor already accepts `client:`) with a `MockClient` returning a locally built in-memory zip; add a malicious-zip fixture (`../evil` entry) asserting `FileSystemException`; move the repo-local fallback behind `kDebugMode` or a test-only injection so the test cannot pass through production code.
- Verification status: Read both tests and the production manager; no `MockClient` used in the audio test despite `AudioPackManager(client:)` existing; `sha256Checksum: ''` read verbatim.

## [T5-F14] Secure credential storage / Android Keystore platform channel has no test

- Severity: Medium
- Confidence: CONFIRMED
- Location: `test/core/network/ai/security/ai_credential_security_test.dart:42-52` (and repeated in 20+ tests); production `lib/core/network/ai/security/ai_credential_storage.dart:53`
- Evidence:
```dart
// test/core/network/ai/security/ai_credential_security_test.dart:42-52
test('1. Save new API key with instant read-back verification', () async {
  final inMemory = <String, String>{};
  final storage = AiCredentialStorage(inMemoryStore: inMemory);   // <-- entire suite uses the in-memory seam
  ...
```
```text
# grep "FlutterSecureStorage" over test/** (92 files): 1 hit — a group() title string (line 179).
# production: lib/core/network/ai/security/ai_credential_storage.dart:53
const FlutterSecureStorage( ... )
```
- Root cause: `AiCredentialStorage` exposes an `inMemoryStore` test seam, so unit tests never touch the `flutter_secure_storage` MethodChannel or EncryptedSharedPreferences/Keystore. No integration test (`integration_test/`) exists in the repo (`test/` only).
- Impact: The release-critical promise "API keys are stored in Android Keystore-backed secure storage" (P0-03 fix, README/AI feature) is untested end-to-end: a plugin-version/regression or Android-encryption failure would only surface at runtime on device. The legacy-SQLite→secure-store migration test (`ai_credential_security_test.dart:179+`) also runs against the in-memory seam, so migration behavior on a real Keystore is unproven.
- Fix: Add an `integration_test/secure_storage_test.dart` that runs on an emulator/device and exercises `saveApiKey → getApiKey → delete`, plus the legacy migration path; alternatively add a MethodChannel mock test that records `write`/`read`/`delete` calls for the `plugins.it_nomads.com/flutter_secure_storage` channel and verifies the exact key names and that no plaintext key reaches `app_settings`.
- Verification status: Grep over `test/**`; read the storage implementation; confirmed absence of `integration_test/` directory.

## [T5-F15] Real-clock dependent tests (flakiness) — 12 real waits, 42 files use `DateTime.now()`, one wall-clock debounce assertion

- Severity: Medium
- Confidence: [CONFIRMED] pattern; [LIKELY] flake frequency
- Location: `test/features/vocabulary_srs/srs_integration_test.dart:26,215-233`; `test/core/audio/audio_services_test.dart:78,141,148,154`; 42 files using `DateTime.now()`; docs admission `docs/system-documentation/14-known-issues-and-technical-debt.md:56-61`
- Evidence:
```dart
// test/features/vocabulary_srs/srs_integration_test.dart:26
repository = SrsRepository(db, debounceCooldownMs: 100);
// :215-233
test('5. Rejects duplicate rapid review taps within debounce threshold', () async {
  await repository.recordReviewAndProgress(item: card, rating: SrsRating.good);
  expect(
    () => repository.recordReviewAndProgress(item: card, rating: SrsRating.good),
    throwsA(isA<DuplicateReviewException>()),
  );
```
  (Both calls use the repository's internal `DateTime.now()`; if the machine stalls >100 ms between the two awaits, no exception is thrown and the test fails. This is the exact class of flake the repo documents, albeit with different numbers — docs say "500ms / srs_integration_test.dart" whereas the code uses 100 ms there and 800 ms injected cooldown in `test/srs_test.dart:282`.)
```dart
// test/core/audio/audio_services_test.dart:78 — real clock used to wait for async audio state
await Future.delayed(const Duration(milliseconds: 250));
```
  `fake_async` is not used anywhere (0 references); 42 test files call `DateTime.now()` directly (streaks, SRS due dates, CAT latency, activity timestamps).
- Root cause: Time is taken from the ambient clock instead of being injected; only `reviewTime`-style parameters are sometimes injectable, but the debounce guard falls back to `DateTime.now()` (`SrsRepository`).
- Impact: Suite can be green locally and red on loaded CI / low-end dev machines (the full-suite serial compile/IO load is exactly when it breaks). The documented run already shows the suite is close to flaky at 99.68% pass; a flaky release gate trains teams to re-run until green, destroying test credibility.
- Fix: Use `package:fake_async`/`FakeAsync().run(...)` or `fake_clock` with an injected `Clock`/`DateTime Function()` in `SrsRepository`, streak calculator and activity DAO; make the debounce test pass explicit `reviewTime` values 0 ms/100 ms apart instead of relying on wall time; replace real `Future.delayed` with `tester.pump(duration)`/`fakeAsync.elapse`. Add `dart_test.yaml`/CI `--concurrency` stability runs.
- Verification status: Grep counts and files quoted; docs admission read; the debounce implementation path and test call sequence read.

## [T5-F16] No coverage measurement/CI quality gate; weak spots: smoke-only widget asserts, 3 swallowed errors, fake audio platform

- Severity: Low
- Confidence: LIKELY
- Location: `.github/workflows/release.yml` (no test step); `test/widget_test.dart:53-59`; `test/core/audio/audio_services_test.dart:41,118,131`; `test/helpers/mock_audio_platform.dart:205-225`
- Evidence:
```dart
// test/widget_test.dart:53-59 — presence-only smoke assertions
expect(find.text(AppConstants.appName), findsOneWidget);
expect(find.text('Trang chủ'), findsOneWidget);
expect(find.text('Học tập'), findsOneWidget);
expect(find.text('AI Tutor'), findsAtLeastNWidgets(1));
```
```dart
// test/core/audio/audio_services_test.dart:41 — errors swallowed inside test setup/teardown
} catch (_) {}
```
```dart
// test/helpers/mock_audio_platform.dart:205-209 — record fake returns a 512-byte dummy file
case 'stop':
  final testFile = File('${tempDir.path}/test_rec_output.m4a');
  testFile.writeAsBytesSync(List.filled(512, 0x01));
  return testFile.path;
```
- Root cause: Tests were added by feature area without a coverage gate or review checklist; 32 of 91 test files are widget tests whose assertions are mostly `find.text(...)` presence; the audio platform fake (used by audio/pronunciation/shadowing tests) returns synthetic bytes so "real playback/recording" behavior is never validated; `MockJustAudioPlatform` never asserts which calls were made.
- Impact: High assertion count creates an illusion of depth, but several core flows are only smoke-tested (app shell, many screens) and the "real audio" docs claims rely on fakes. No coverage report means the 6 untested critical modules (see below) are invisible to reviewers; no CI gate means regressions are not blocked before a release tag.
- Fix: Add `flutter test --coverage` in CI with a floor (e.g. 60% lines) and `lcov` summary; introduce golden tests for design-system screens; in the audio fake, record channel-call sequences and assert them (e.g. `play` called once with asset URI, `stop` called on lifecycle pause); add negative tests for the missing modules: Zip-Slip rejection, v16 migration, secure storage (T5-F14), restore-from-corrupt-backup, `ContentPackManager` version gating.
  Coverage gaps found (no direct test anywhere in `test/**`): Android `flutter_secure_storage` channel (T5-F14), Zip-Slip/malicious archive (T5-F13), upgrade migrations v1→v16 (T5-F10), `MigrationV16` (timezone column + compound index only exercised indirectly by fresh-create), genuine remote HTTP fetch, and `allowBackup`/manifest config.
- Verification status: Workflow read; greps for coverage/CI; read the helper and sample tests; cross-checked with `test/` tree (no `integration_test/`, no `coverage/` artifacts).

---

# C) Docs-vs-code drift

All rows verified by reading both the doc claim and the referenced code/artifact. Vietnamese quotes translated where needed.

| # | Claim (file:line) | Documented | Actual (source of truth) | Verdict |
|---|---|---|---|---|
| 1 | `README.md:5`, `README.md:37`, `README.md:47` | "SQLite Schema **v9**", "CMS **v9**: 8 SQLite tables" | `lib/core/database/database_constants.dart:5` → `currentDatabaseVersion = 16`; 16 migration files (v1…v16); 33+ table constants | **FALSE / very stale** |
| 2 | `README.md:15-16` | v1.0.9 APK is **20.2 MB** | `release-apk/hi-chinese-v1.0.9-arm64.apk` = **35,866,699 B (34.2 MiB)**; only v1.0.2–v1.0.7 are ≈20.3 MiB; v1.0.8/v1.0.9 jumped to 33.8/34.2 MiB | **FALSE** |
| 3 | `README.md:9,11,15` | "64-bit ARM64 only" app/APK | `aapt2 dump badging` on both v1.0.9 artifacts: `native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'` — universal fat APK; the two files are byte-identical | **FALSE / misleading** |
| 4 | `README.md:22` | 15 lessons, 150 vocab, 45 grammar points, 15 dialogues, 150 exercises | Verified in `assets/data/content_packs/hsk1/hsk1_pack_v1.json`: 3 units/15 lessons/6 segments each, 150 unique words, **45** grammar points (15 grammar items × 3), 150 exercises, exit exam 20 Listening + 20 Reading | **TRUE** (and covered by `test/features/curriculum/hsk1_content_integrity_test.dart`) |
| 5 | `README.md:9`, `README.md:15` | v1.0.9 | `pubspec.yaml:19` `1.0.9+10`; `android/local.properties:4-5` `1.0.9 / 10`; APK badging `versionCode='10' versionName='1.0.9'` | **TRUE** |
| 6 | `README.md:92` | Flutter SDK `>= 3.24.0` (min) | `pubspec.yaml:22` `sdk: ^3.13.7` and `pubspec.lock:890` `flutter: ">=3.44.0"`; Flutter 3.24 ships Dart 3.5 and cannot meet `^3.13.7` — the real minimum is Flutter **3.47.9** (installed) | **FALSE (claimed minimum)** |
| 7 | `README.md:93` | Dart SDK `>= 3.5.0` (min) | `pubspec.yaml:22` `^3.13.7`; `pubspec.lock:889` `dart: ">=3.13.7 <4.0.0"` | **FALSE (claimed minimum)** |
| 8 | `docs/system-documentation/12-build-test-deployment.md:10` | Flutter SDK `3.29.x` | Detected Flutter **3.47.9** stable | **FALSE** |
| 9 | `docs/system-documentation/12-build-test-deployment.md:14-17` | `compileSdkVersion 35`, `targetSdkVersion 34`, `ndkVersion 27.0.12077973` | `android/app/build.gradle.kts:9` `compileSdk = 37`; `targetSdk = flutter.targetSdkVersion` → APK badging `targetSdkVersion:'36'`; `ndkVersion = flutter.ndkVersion` = `28.2.13676358` (Flutter 3.47.9) | **FALSE** |
| 10 | `docs/system-documentation/12-build-test-deployment.md:18,71-73` | "arm64 is the only target", "never build fat 32-bit APK", "current size ~20.4 MB" | shipped v1.0.9 is universal 3-ABI, 34.2 MiB (see row 3) | **FALSE** |
| 11 | `docs/system-documentation/12-build-test-deployment.md:40`; `docs/system-documentation/14-known-issues-and-technical-debt.md:59-60` | "64 test suites"/"64 test files" | **92** files under `test/` (91 test files + 1 helper), 622 declared cases | **FALSE** |
| 12 | `docs/system-documentation/14-known-issues-and-technical-debt.md:30-31` | `DatabaseConstants.currentDatabaseVersion = 11`, `AppConstants.databaseVersion = 1` | both are **16** (`database_constants.dart:5`, `app_constants.dart:8`) | **FALSE / stale** |
| 13 | `docs/system-documentation/14-known-issues-and-technical-debt.md:56-61` | Flaky test described as "two taps within **500 ms**" in `srs_integration_test.dart` (due to `Future.delayed` jitter) | `srs_integration_test.dart:26` uses `debounceCooldownMs: 100` and contains no `Future.delayed`; the 800 ms debounce test is `test/srs_test.dart:282,333` and uses injected `reviewTime` | **PARTIAL / stale** |
| 14 | `docs/system-documentation/14-known-issues-and-technical-debt.md:9` | "CRITICAL: **0 issues**" | Release is debug-signed (`T5-F01`), checksum verification hard-bypassed (`T5-F02`), the only release gate record says **BLOCKED** (`T5-F06`) | **FALSE / misleading** |
| 15 | `docs/architecture-decisions.md:1068,1071` | "CMS Catalog SQLite Schema v9" | v16 (`database_constants.dart:5`) | **FALSE** |
| 16 | `docs/data-integration/DATA_INTEGRATION_FINAL_REPORT.md:7`; `docs/data-integration/README.md:5` | "SQLite Schema **v15**" | v16 | **FALSE** |
| 17 | `docs/system-documentation/04-database-schema.md:1`; `docs/system-documentation/README.md:57` | "SQLITE SCHEMA **V11**" | v16 | **FALSE** |
| 18 | `docs/system-documentation/12-build-test-deployment.md:30-35` | `dart analyze lib test` must yield "No issues found! (0 errors, 0 warnings, 0 infos)" | Repo's own audit at `docs/agent-coordination/reports/thread-5/test-execution-report.md:19,57-61` recorded **48 issues** (2 warnings + 46 infos); cannot re-run here (see D) | **CONTRADICTED by repo's own report** |
| 19 | `release-output/HI-Chinese-v1.0.0/release-manifest.json:18-22` | `release_gate_status: BLOCKED`, 2 P1 blockers | `README.md:9-16` advertises v1.0.9 download + `.github/workflows/release.yml` publishes it; `BUG-VOICE-001` fixed in code, `BUG-CORE-001` only masked | **CONTRADICTION / stale** |
| 20 | `README.md:23` | "Tự Học Ngoại Tuyến 100%" — all curriculum/audio bundled locally | HSK1/2 are truly offline (500 audio files, 6.7 MB under `assets/audio/`, packs 171 KB/176 KB), but HSK3–6 content packs and audio packs are network downloads from a hard-coded third-party GitHub repo (`content_pack_remote_service.dart:50-105`, `audio_pack_manager.dart:54-136`) | **PARTIAL** |
| 21 | `docs/agent-coordination/reports/thread-5/test-execution-report.md:14-17` | 618 cases executed / 616 passed / 2 failed / 0 skipped | Static declaration count is 622 (`481 test` + `141 testWidgets`); result can't be re-verified here (D); the 2 documented failures map to one fixed bug and one **masked** bug | **UNVERIFIED / stale numbers** |
| 22 | `docs/bug-fixes/P0_01_STARTUP_SEED_LOADING.md:5` | "RESOLVED & VERIFIED (7/7 Integration Tests Passed, 17/17 Curriculum Tests Passed)" | `test/core/startup/app_startup_integration_test.dart` declares exactly 7 `test(` cases — claim is at least internally consistent; not re-run | **PLAUSIBLE** |

---

# D) Actual `flutter test` result

**Status: NOT OBTAINED — the sandboxed session cannot execute the Flutter test runner.** This is an environment limitation, not a test failure.

Attempts (the only Flutter command issued was `flutter test`; `flutter analyze` was NOT run, per assignment):

1. Background `flutter test --reporter compact 2>&1 | Tee-Object audit\_t5_flutter_test.log` — started 22:31 local (Flutter updated `C:\src\flutter\bin\cache\lockfile` at 22:31:10 and created `build/unit_test_assets/` at 22:31:14), then produced **no output for ~20 minutes**; killed.
2. Background `Start-Process … -RedirectStandardOutput audit\_t5_test_out.log` — 0-byte logs after wait; killed.
3. Background `cmd /c "…\flutter.bat test --reporter compact > audit\_t5_test_out.log 2>&1"` — 0-byte log after >6 minutes, `cache/lockfile` mtime never advanced past 22:31:10; killed. Temp attempt logs were deleted afterwards (no workspace artifacts left).

Likely cause: the session file/process sandbox blocks the nested `dart`/`flutter_tester` subprocess stdio pipes that the Flutter tool needs, so the runner stalls before emitting its first reporter byte. This must be re-run outside the sandbox (`flutter test --reporter compact` on a normal shell or CI) to get the current 622-case pass/fail/skip ledger.

**What is known from the repository's own last recorded run** (not reproducible here): `docs/agent-coordination/reports/thread-5/test-execution-report.md:12-19` at commit `394bb5d`: 618 executed / 616 passed (99.68 %) / **2 failed** / 0 skipped / 4 m 10 s. The two failures were:
- `ContentPackRemoteService can download and install remote HSK 3 pack from CDN mock` — `BUG-CORE-001` (SHA-256 mismatch). **This bug is still present in the data but is now statically masked** by the hard-coded exemption (T5-F02) and the blank catalog checksum (line 91) — so a fresh run would likely go **green while integrity checking remains disabled**.
- `pronunciation … overallScore isNotNull` — `BUG-VOICE-001`. **Fixed in code**: `lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart:95-113` returns `overallScore: 0.0` for a missing file.

**Verdict on release evidence:** There is currently **no trustworthy green test run** for the shipped commit. Even if the suite passes, it does not prove: upgrade safety (T5-F10/F11), checksum enforcement (T5-F02/F13), secure-store behavior on device (T5-F14), or real audio recording/playback (T5-F16). The release should not be called test-verified until `flutter test` is run on an unblocked machine/CI and the migration-matrix + negative-path tests above are added.

---

## Appendix — Key verification commands used (read-only)

```powershell
# build/test config
Get-Content android\app\build.gradle.kts, android\settings.gradle.kts, android\gradle\wrapper\gradle-wrapper.properties
# signing proof
& C:\Android\sdk\build-tools\36.0.0\apksigner.bat verify --print-certs --verbose release-apk\app-release.apk
& C:\Android\sdk\build-tools\36.0.0\aapt2.exe dump badging release-apk\hi-chinese-v1.0.9-arm64.apk
# pack integrity
(Get-FileHash content_packs_cdn\hsk3_pack_v1.json -Algorithm SHA256).Hash      # 22E69BCC… ≠ manifest 43444269…
# tracked artifacts
git ls-files | Select-String 'release-apk'        # 9 tracked APKs, 224.1 MB
# test metrics
$files = Get-ChildItem -Recurse test -Filter *.dart
($files | Select-String 'expect\(' -AllMatches | % { $_.Matches.Count } | Measure-Object -Sum).Sum  # 2976
($files | Select-String '^\s*test\(' -AllMatches | % { $_.Matches.Count } | Measure-Object -Sum).Sum # 481
($files | Select-String '^\s*testWidgets\(' ...).Sum                                                # 141
# migration coverage
Select-String -Path test\**\*.dart -Pattern 'MigrationV1[3-6]|oldVersion'   # no upgrade-path tests
# environment
Get-Content C:\src\flutter\bin\cache\flutter.version.json                   # 3.47.9 / Dart 3.13.7
```

*End of T5 report.*
