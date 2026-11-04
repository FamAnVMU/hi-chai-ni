# BUG REGISTER - THREAD 5 INDEPENDENT AUDIT
**Project**: HI Chinese  
**Auditor**: Thread 5 (Independent QA & Release Engineer)  
**Date**: 2026-11-04  
**Policy**: Read-Only Source Code Policy (Strict Adherence)

---

### BUG SUMMARY TABLE

| Bug ID | Severity | Affected Thread | Affected Module | Status | Summary |
|---|---|---|---|---|---|
| BUG-CORE-001 | P1 | Thread 1 | Content Packs / CDN | UNRESOLVED | Checksum mismatch in `hsk3_pack_v1.json` causing install failure in `ContentPackRemoteService` |
| BUG-VOICE-001 | P1 | Thread 3 | Pronunciation Assessment | UNRESOLVED | `DefaultPronunciationAnalysisService.evaluatePronunciation` returns null `overallScore` when audio file is missing or invalid |
| BUG-RELEASE-001 | P2 | Thread 1 / DevOps | Android Gradle Build | UNRESOLVED | Gradle 8.10.2 is below Flutter minimum 8.14.0, requiring `--android-skip-build-dependency-validation` |
| BUG-CORE-002 | P3 | Thread 1 | Tooling / Import Scripts | UNRESOLVED | 2 unused local variables in `tool/import_vocabulary.dart` and 46 `avoid_print` info lints |

---

### DETAILED BUG REPORTS

#### BUG-CORE-001
- **Bug ID**: BUG-CORE-001
- **Title**: Mismatch in `hsk3_pack_v1.json` SHA-256 checksum prevents remote pack installation
- **Severity**: P1 - HIGH
- **Affected Thread**: Thread 1 (Core Engine, Database & Content Platform)
- **Affected Module**: `lib/features/content_packs/data/content_pack_manager.dart` & `content_packs_cdn/hsk3_pack_v1.json`
- **Environment**: Flutter 3.47.9 / Dart SDK 3.13.7 (windows_x64)
- **Commit/Branch**: `feature/thread-1-core` (`394bb5d`)
- **Preconditions**: Test executes `test/features/content_packs/content_pack_service_test.dart`.
- **Steps to Reproduce**:
  1. Run `flutter test test/features/content_packs/content_pack_service_test.dart`
  2. Observe test #3: `ContentPackRemoteService can download and install remote HSK 3 pack from CDN mock`.
- **Expected Result**: Downloaded JSON passes `validateManifest` and installs into SQLite successfully.
- **Actual Result**: `ContentPackManagerException(hsk3_pack_v1): Mã băm SHA-256 không hợp lệ (kỳ vọng: fd7acdb8fb098398c5a344ecc2e0bcfb95225691f310737c56cc310a7fe8c101, thực tế: 434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2). Dữ liệu có thể bị hư hỏng.`
- **Root Cause**: The raw content of `content_packs_cdn/hsk3_pack_v1.json` has been updated or formatted, changing its actual SHA-256 to `43444269...`, while `manifest.sha256` remains hardcoded to `fd7acdb8...`.
- **Data Loss Risk**: None (transaction safely rolls back), but blocks user from downloading HSK 3 content.
- **Security Risk**: None.
- **Reproduction Rate**: 100%.
- **Suggested Owner**: Thread 1.
- **Suggested Fix Direction**: Update `manifest.sha256` in `content_packs_cdn/hsk3_pack_v1.json` to match the exact SHA-256 hash of the content payload, or re-run the generator script `tool/generate_hsk3_cdn_pack.dart`.

---

#### BUG-VOICE-001
- **Bug ID**: BUG-VOICE-001
- **Title**: `DefaultPronunciationAnalysisService` returns null `overallScore` on missing audio file, breaking master regression contract
- **Severity**: P1 - HIGH
- **Affected Thread**: Thread 3 (AI Intelligence & Voice Lab)
- **Affected Module**: `lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart` & `test/regression/full_app_regression_test.dart`
- **Environment**: Flutter 3.47.9 / Dart SDK 3.13.7 (windows_x64)
- **Commit/Branch**: `feature/thread-1-core` (`394bb5d`)
- **Preconditions**: Test calls `evaluatePronunciation` with a dummy or unrecorded path (`dummy.wav`).
- **Steps to Reproduce**:
  1. Run `flutter test test/regression/full_app_regression_test.dart --name "Pronunciation"`
- **Expected Result**: `pronResult.overallScore` is non-null (e.g. `0.0` with status `failed` or `insufficientAudio`), or test accommodates the error contract.
- **Actual Result**: `expect(pronResult.overallScore, isNotNull)` fails because `overallScore` is `<null>`.
- **Root Cause**: In `pronunciation_analysis_service.dart` line 101, when `!file.existsSync()`, `overallScore` is explicitly set to `null` while the regression test expects a non-null numeric score (e.g. 0.0) or expects status handling.
- **Data Loss Risk**: Low.
- **Security Risk**: Low.
- **Reproduction Rate**: 100%.
- **Suggested Owner**: Thread 3 (coordinating with Thread 1 on test assertion).
- **Suggested Fix Direction**: Align the evaluation contract between Thread 3 and Thread 1: Either return `overallScore: 0.0` when audio file is not found, or provide a valid dummy audio fixture in `full_app_regression_test.dart`.

---

#### BUG-RELEASE-001
- **Bug ID**: BUG-RELEASE-001
- **Title**: Gradle wrapper version (8.10.2) is incompatible with Flutter's AGP requirements (minimum 8.14.0)
- **Severity**: P2 - MEDIUM
- **Affected Thread**: Thread 1 (DevOps / Infrastructure)
- **Affected Module**: `android/gradle/wrapper/gradle-wrapper.properties`
- **Environment**: Flutter 3.47.9 / Dart SDK 3.13.7 (windows_x64)
- **Commit/Branch**: `feature/thread-1-core` (`394bb5d`)
- **Preconditions**: Run standard build command `flutter build apk --release`.
- **Steps to Reproduce**:
  1. Execute `flutter build apk --release` without additional flags.
- **Expected Result**: Clean build of Release APK.
- **Actual Result**: Build fails at `android/app/build.gradle.kts:1`: `Error: Your project's Gradle version (8.10.2) is lower than Flutter's minimum supported version of 8.14.0. Please upgrade your Gradle version.`
- **Root Cause**: Android Gradle Wrapper is configured with `gradle-8.10.2-all.zip`, which is rejected by Flutter 3.47.9's Gradle plugin without `--android-skip-build-dependency-validation`.
- **Data Loss Risk**: None.
- **Security Risk**: Low.
- **Reproduction Rate**: 100%.
- **Suggested Owner**: Thread 1.
- **Suggested Fix Direction**: Update `distributionUrl` in `android/gradle/wrapper/gradle-wrapper.properties` to `gradle-8.14-all.zip` or the version recommended by Flutter toolchain.

---

#### BUG-CORE-002
- **Bug ID**: BUG-CORE-002
- **Title**: Compiler warnings and lint issues in data import tool scripts
- **Severity**: P3 - LOW
- **Affected Thread**: Thread 1 (Core Engine & Tooling)
- **Affected Module**: `tool/import_vocabulary.dart`
- **Environment**: Flutter 3.47.9 / Dart SDK 3.13.7 (windows_x64)
- **Commit/Branch**: `feature/thread-1-core` (`394bb5d`)
- **Preconditions**: Run `flutter analyze`.
- **Steps to Reproduce**:
  1. Execute `flutter analyze`
- **Expected Result**: 0 errors, 0 warnings.
- **Actual Result**: 2 warnings:
  - `tool\import_vocabulary.dart:122:9 - unused_local_variable (importDict)`
  - `tool\import_vocabulary.dart:123:9 - unused_local_variable (checkStats)`
  - 46 info lints (`avoid_print`).
- **Root Cause**: Unreferenced variables in import script.
- **Data Loss Risk**: None.
- **Security Risk**: None.
- **Reproduction Rate**: 100%.
- **Suggested Owner**: Thread 1.
- **Suggested Fix Direction**: Remove unused local variables in `tool/import_vocabulary.dart`.
