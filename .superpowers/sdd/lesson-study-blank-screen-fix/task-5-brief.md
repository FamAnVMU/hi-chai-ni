# Task 5 Brief: Kiểm Thử E2E Toàn Diện, Build Release APKs & Đẩy GitHub Release v1.0.15

**Files:**
- Modify: `pubspec.yaml`
- Modify: `README.md`
- Create: `audit/LESSON_BLANK_FIX_FINAL_REPORT.md`
- Target outputs:
  - `release-apk/hi-chinese-v1.0.15-arm64-v8a.apk`
  - `release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk`
  - `release-apk/app-release.apk`

**Exact Requirements:**
1. **Full Test Suite Run**:
   `cd C:\Users\phama\Downloads\hi_chinese; flutter test`
   Confirm 100% pass without failures.
2. **Bump Version**:
   In `pubspec.yaml`:
   `version: 1.0.15+15`
3. **Build Split-per-ABI Release APK**:
   ```powershell
   flutter clean
   flutter build apk --split-per-abi --release --android-skip-build-dependency-validation
   ```
   Copy outputs into `release-apk/`:
   - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` -> `release-apk/hi-chinese-v1.0.15-arm64-v8a.apk`
   - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` -> `release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk`
   - `build/app/outputs/flutter-apk/app-release.apk` (or universal if built, or copy arm64-v8a as default `app-release.apk`).
4. **Update README.md & Create QA Report**:
   - Update `README.md` with version 1.0.15 release highlights and download links.
   - Document verification in `audit/LESSON_BLANK_FIX_FINAL_REPORT.md`.
5. **Git Commit, Tag & Push**:
   ```bash
   git add .
   git commit -m "chore(release): bump version to v1.0.15+15 and release fixed APKs"
   git tag -a v1.0.15 -m "Release v1.0.15: Hotfix for blank lesson study screen and enhanced content recovery"
   git push origin main
   git push origin v1.0.15
   ```
6. **Publish GitHub Release**:
   Using `gh release create v1.0.15 release-apk/hi-chinese-v1.0.15-arm64-v8a.apk release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk release-apk/app-release.apk --title "Hi Chinese v1.0.15 - Hotfix Lesson Blank Screen & Content Ingestion" --notes "..."`.
