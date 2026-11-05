# BÁO CÁO KIỂM TOÁN KỸ THUẬT CHUYÊN SÂU — HI CHINESE (v1.0.9+10)

**Ngày kiểm toán:** 04/11/2026 · **Commit:** `5c099ba` (main) · **Nền tảng:** Flutter 3.47.x / Dart 3.13.7 / Android (minSdk 24)
**Phương pháp:** 6 auditor song song (DB/Data, Security, Business Logic, Async/Perf, Build/Test, Feature Modules) + Lead kiểm chứng độc lập từng phát hiện Critical/High.
**Bằng chứng gốc:** `audit/findings/01-data-core.md` … `06-features.md` (126 phát hiện thô, đã hợp nhất/dedupe còn 40 trong báo cáo này).
**Trạng thái tĩnh:** `dart analyze lib test` → **No issues found** (0 lỗi biên dịch/lint) — nghĩa là toàn bộ lỗi dưới đây là lỗi **logic/ngữ nghĩa**, không phải lỗi cú pháp.
**Giới hạn:** Không chạy được `flutter test` trong sandbox (stdio của `flutter_tester` bị chặn); không có thiết bị/emulator để kiểm thử runtime. Các kết luận được đánh dấu độ tin cậy; 100% vị trí `file:dòng` đã được đọc lại trong mã nguồn.

---

## 1. BẢNG TỔNG HỢP PHÁT HIỆN (SUMMARY MATRIX)

| Mã ID | Tên vấn đề | Phân loại | Mức độ | Vị trí (`file:dòng`) |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | Toàn bộ 30 bài học không thể hoàn thành: segment `mastery_check` trỏ tới content item không tồn tại | Data Integrity / Business Logic | **Critical** | `assets/data/content_packs/hsk1/hsk1_pack_v1.json`, `hsk2_pack_v1.json`; `lib/core/database/dao/curriculum_dao.dart:149`; `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:35-51`; `lib/features/curriculum/presentation/screens/lesson_study_screen.dart:105` |
| **F-02** | Toàn bộ đáp án đúng bị gán vào `options[0]` (300 bài tập + 40 câu exit exam) | Business Logic / Data Integrity | **Critical** | `hsk1_pack_v1.json` (150/150), `hsk2_pack_v1.json` (150/150), `hsk1_pack_v1.json → exit_exam.exam_data_json` (40/40); `lib/features/curriculum/presentation/widgets/lesson_practice_view.dart:56-63`; `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:208,598-600` |
| **F-03** | APK release phát hành cho người dùng được ký bằng **debug keystore** | Security (CWE-321) | **Critical** | `android/app/build.gradle.kts:26-35`; `.github/workflows/release.yml:40-42`; `README.md:15-16`; `release-apk/*.apk` |
| **F-04** | Kiểm tra SHA-256 content-pack bị **bypass cứng**; pack remote không xác thực toàn vẹn | Security (CWE-345/494) | **Critical** | `lib/features/content_packs/data/content_pack_manager.dart:109-121`; `content_pack_remote_service.dart:83-105`; `content_packs_cdn/hsk3_pack_v1.json`; `tool/generate_hsk3_cdn_pack.dart:169-177` |
| **F-05** | Cài đặt người dùng (theme, font, pinyin, tốc độ nói) không bao giờ được nạp khi khởi động | Architecture / Silent Failure | **Critical** | `lib/features/settings/presentation/providers/settings_providers.dart:12-15,24-33,49-63`; `lib/main.dart:53-54`; `lib/core/database/app_database.dart:28-34`; `lib/core/startup/app_startup_provider.dart:96` |
| **F-06** | Mic AI Voice tiếp tục ghi âm khi rời tab; lượt hội thoại đang xử lý không thể hủy → TTS phát sau khi kết thúc | Security/Privacy, Async | **Critical** | `lib/features/app_shell/presentation/screens/app_shell.dart:103-119`; `ai_tutor_tab_screen.dart:269-275`; `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:389-390,394-454,456-469,483-494` |
| **F-07** | Onboarding báo "hoàn tất" kể cả khi transaction DB thất bại (nuốt lỗi) | Silent Failure / Data Integrity | **Critical** | `lib/features/onboarding/presentation/providers/onboarding_providers.dart:299-446`; `onboarding_flow_screen.dart:84-98` |
| **F-08** | Restore backup xóa DB đang sống **trước khi** xác thực bản backup; lỗi chỉ log warning | Data Integrity / Data Loss | **High** | `lib/features/settings/data/services/data_management_service.dart:117-188`; `lib/core/database/database_backup_helper.dart:34-90` |
| **F-09** | Xung đột không gian ID từ vựng: seed (`VOC_HSK1_*`) vs pack (`vocab_*`) → ~268 dòng từ trùng | Data Integrity | **High** | `lib/core/database/seed/seed_loader.dart:181-215`; `assets/data/hsk_seed_fixture_v2.json`; `lib/features/content_packs/data/content_pack_manager.dart:441` |
| **F-10** | `INSERT OR REPLACE` vào `curriculum_mastery` hardcode `attempts_count:1`, xóa `due_review_at`/lịch ôn | Data Integrity | **High** | `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:648` (xem thêm `:576`) |
| **F-11** | CAT placement không đánh giá 4/6 kỹ năng; listening lộ đáp án; speaking tự động đúng | Business Logic | **High** | `lib/features/placement_test/domain/engine/cat_engine.dart:195-198`; `cat_blueprint.dart:31-34,43-50`; `cat_question_card.dart:91-105,239`; `cat_item.dart:128-135` |
| **F-12** | 79 URI âm thanh trỏ tới asset không tồn tại/không khai báo (pinyin, shadowing, pronunciation, listening) | Business Logic / Config | **High** | `lib/features/pinyin_foundation/domain/curriculum/pinyin_curriculum_catalog.dart:41,51,65,107…`; `shadowing/domain/engine/shadowing_document_bank.dart:21`; `pronunciation/domain/engine/pronunciation_item_bank.dart:16`; `listening/domain/models/listening_lesson.dart:52`; `pubspec.yaml:76-81` |
| **F-13** | Bài tập "phát hiện lỗi" trong seed không thể trả lời đúng (tokenizer vs `errorToken`) | Business Logic | **High** | `lib/features/practice/domain/catalog/practice_seed_catalog.dart:94`; `practice/presentation/widgets/true_false_or_error_widget.dart:132-133`; `practice/domain/engine/practice_scoring_engine.dart:206-208` |
| **F-14** | Ví dụ ngữ pháp từ content-pack bị mất im lặng (ghi `List<String>`, parser đọc `List<Map>`) | Silent Failure | **High** | `lib/features/content_packs/data/content_pack_manager.dart:632-633`; `lib/features/grammar/domain/models/grammar_models.dart:269-285` |
| **F-15** | Roadmap và Curriculum là hai "split-brain": roadmap đọc `lesson_progress` mà curriculum không bao giờ ghi; catalog HSK1 hardcode sai ID | Architecture / Data Integrity | **High** | `lib/features/roadmap/data/roadmap_repository.dart:76,103-157`; `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`; `lib/features/roadmap/domain/catalog/curriculum_catalog.dart:198-203` |
| **F-16** | Hội thoại trong bài học render trống do sai tên field (`text_zh/text_vi` vs `hanzi/meaning`) | Business Logic | **High** | `lib/features/curriculum/presentation/widgets/lesson_dialogue_view.dart:47-49`; `hsk1_pack_v1.json` (`DIALOGUE_L1`) |
| **F-17** | Exit exam: không có timer, ghi khống 35 phút/lần thi, retry vô hạn, lộ đáp án, pass mở khóa toàn bộ 15 bài | Business Logic | **High** | `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:40-42,249`; `curriculum_syllabus_screen.dart:102`; `curriculum_repository.dart:219-227` |
| **F-18** | `DefaultAudioRecorderService` đăng ký lifecycle callback nhưng không bao giờ hủy; không xử lý audio focus/gián đoạn phát | Resource Leak / Perf | **High** | `lib/core/audio/audio_recorder_service.dart:70-76`; `lib/core/utils/app_lifecycle_manager.dart:47-68`; `voice_conversation_service.dart:523-539` |
| **F-19** | Toolchain Android không tương thích: AGP 8.7.0 < mức tối thiểu của Flutter; `compileSdk=37` ngoài hỗ trợ; build phải dùng cờ bỏ qua validation | Config / Build | **High** | `android/settings.gradle.kts:22-24`; `android/app/build.gradle.kts:9`; `docs/agent-coordination/reports/thread-5/apk-build-report.md:13` |
| **F-20** | CI release đăng lại APK cũ đã commit, không build/test/sign/checksum | Config / Supply Chain | **High** | `.github/workflows/release.yml:1-43`; `release-apk/` (9 APK, 224 MB) |
| **F-21** | `allowBackup` bật, không có `dataExtractionRules` → DB học viên + `.hibak` lên Auto Backup | Security (CWE-312/922) | **Medium** | `android/app/src/main/AndroidManifest.xml:11-15` |
| **F-22** | Gemini API key gửi tới proxy tùy ý; validation host chưa đủ; `verifyCredentials/testConnection` bỏ qua kiểm tra HTTPS | Security (CWE-918/201) | **Medium** | `lib/core/network/ai/security/ai_credential_storage.dart:323-333`; `gemini_rest_ai_provider.dart:46-56,81-103,441-453` |
| **F-23** | Audio-pack ZIP: checksum thực tế bị bỏ qua, không giới hạn dung lượng/thời gian; writer latent path traversal | Security (CWE-494/409/22) | **Medium** | `lib/features/sentences/data/audio_pack_manager.dart:64-74,131-191`; `audio_management/data/audio_pack_downloader.dart:101-121` |
| **F-24** | SRS: tự động enroll 25 từ chưa học khi mở Review; lỗi lưu bị nuốt; nút "Quên" hẹn 1 ngày | Business Logic | **Medium** | `lib/features/vocabulary_srs/data/srs_repository.dart:287-322,350-369`; `presentation/providers/srs_providers.dart:106-114`; `domain/sm2_engine.dart:103,155` |
| **F-25** | Export/Import JSON chỉ 7 bảng, không kiểm tra schema version; reset bỏ sót tiến độ trong `curriculum_lessons/units` | Data Integrity | **Medium** | `data_management_service.dart:191-228,231-339,362-393`; `migration_v9.dart:63,82-88` |
| **F-26** | 3 quy ước ID `user_profiles`; `UPDATE` không `WHERE`; cập nhật profile optimistic không rollback | Data Integrity | **Medium** | `app_startup_provider.dart:305`; `onboarding_providers.dart:350-358,363`; `profile/domain/models/user_profile.dart:62`; `profile_repository.dart:24-37`; `profile_providers.dart:29-44` |
| **F-27** | Điểm đánh giá giả: mở bài đọc ghi ngay 100 điểm; evidence trùng; điểm Hanzi sàn 50%; shadowing tự chấm | Business Logic | **Medium** | `sentences/presentation/screens/sentence_reading_screen.dart:27-38`; `reading_detail_screen.dart:82,393-409`; `hanzi_writing_screen.dart:201-202`; `sentence_shadowing_screen.dart:102-120` |
| **F-28** | Pinyin cộng mastery sai item; Listening hardwire HSK1 + không lưu đáp án; Practice hub chỉ HSK1 | Business Logic | **Medium** | `pinyin_foundation/presentation/screens/pinyin_practice_screen.dart:45-46`; `listening/presentation/providers/listening_providers.dart:17-31`; `learning/presentation/screens/learning_screen.dart:248` |
| **F-29** | Home thống kê sai: `learnedVocab` toàn cục vs `totalVocab` theo cấp → có thể >100%; tên bài kế tiếp hardcode | Business Logic | **Medium** | `lib/features/home/data/home_repository.dart:466-497,503-512`; `home/presentation/screens/home_screen.dart:135` |
| **F-30** | Điểm nghẽn hiệu năng: import pack N+1 trên UI isolate; chat history unbounded; file ghi âm tạm không xóa; coverage auditor N+1 | Performance | **Medium** | `content_pack_manager.dart:441-480`; `ai_tutor/data/repositories/ai_tutor_repository.dart`; `audio_management/data/audio_coverage_auditor.dart` |
| **F-31** | Dead code: route guard + deep-link không được gọi; màn skeleton 320 dòng; demo design system trong release | Architecture / Cleanup | Low | `app_router.dart:60-171`; `app_routes.dart:14`; `main.dart:70-71,76-398` |
| **F-32** | Version hardcode sai (1.0.0 / 1.0.0+1 vs pubspec 1.0.9+10) | Config | Low | `app_constants.dart:5`; `about_and_privacy_dialog.dart:43`; `profile_screen.dart:510`; `data_management_service.dart:213` |
| **F-33** | Docs lệch mã nguồn: schema v9/v11/v15 vs thực tế v16; "64 test suites" vs 92 file; compileSdk/targetSdk sai | Documentation | Low | `README.md:5`; `docs/system-documentation/04-database-schema.md:1,9`; `docs/data-integration/UNIFIED_SCHEMA.md:2` |
| **F-34** | Test không chứng minh được chuỗi 16 migration; một số test mở DB không bật FK; không assert `rowsAffected` | Testing | Low | `test/core/database/database_migration_test.dart:6-27`; `test/core/database/upsert_safety_test.dart:31-57`; `test/regression/full_app_regression_test.dart:39` |
| **F-35** | Migration v10 backfill nuốt lỗi và `REPLACE` gây cascade xóa link vừa chèn | Data Integrity | Low | `lib/core/database/migrations/migration_v10.dart:213-229,324-326` |
| **F-36** | Startup bỏ qua version/checksum của seed/pack → cập nhật app không nạp lại dữ liệu mới | Data Integrity | Low | `app_startup_provider.dart:207-241` |
| **F-37** | Edge cases: LIKE `%/_` không escape; matching-pairs rỗng chấm 1.0; shadowing chia 0 → NaN | Business Logic | Low | `core/database/dao/*_dao.dart` (LIKE); `practice/domain/engine/practice_scoring_engine.dart`; `shadowing/domain/engine/shadowing_evaluator.dart` |
| **F-38** | 9 APK (224 MB) commit vào git; manifest release ghi `BLOCKED` nhưng v1.0.9 vẫn phát hành; "45 điểm ngữ pháp" thực tế chỉ 17 unique | Release / Documentation | Low | `release-apk/`; `release-output/release_manifest.json`; `docs/.../release-readiness-report.md` |
| **F-39** | `hasSufficientStorage()` luôn trả `true` (stub); export dữ liệu cá nhân vào clipboard | Security/Stub | Low | `audio_management/data/audio_storage_manager.dart:120-133`; `settings/presentation/widgets/data_management_sheet.dart:47-55` |
| **F-40** | Pipeline Python: tải từ branch mutable không hash/pin; `urlopen` không timeout; path từ corpus không sanitize | Security / Data Supply | Low | `data_pipeline/download_grammar_sources.py:14-36`; `download_hanzi_sources.py:16`; `generate_all_audio.py:71-76` |

---

## 2. PHÂN TÍCH CHI TIẾT TỪNG VẤN ĐỀ

### F-01 — [CRITICAL] Toàn bộ 30 bài học không thể hoàn thành

**Hiện tượng & bằng chứng.** Mỗi bài trong pack có 6 segment; segment thứ 6 `mastery_check` trỏ tới `content_ref_id = MASTERY_L<k>`. Nhưng pack chỉ có 75 content item (5 loại × 15 bài): `WARMUP_*`, `VOCAB_*`, `GRAMMAR_*`, `DIALOGUE_*`, `PRACTICE_*` — **không có MASTERY_***. Kiểm tra trực tiếp cả 2 pack:

```text
hsk1: content_items=75  segment_refs=90  missing=15  (MASTERY_L1..MASTERY_L15)
hsk2: content_items=75  segment_refs=90  missing=15
```

`curriculum_dao.dart:149` nạp segment bằng `LEFT JOIN content_items ci ON ls.content_ref_id = ci.content_id` → payload `null`; `lesson_mastery_view.dart:35-51` rơi vào nhánh `exercises.isEmpty` và chỉ hiển thị empty-state có nút "Hoàn thành bài học":

```dart
if (exercises.isEmpty) {
  return LessonContentEmptyState(
    title: 'Đánh giá hoàn thành đang được chuẩn bị',
    ...
    buttonText: 'Hoàn thành bài học',
    onAction: widget.onFinishLesson,
```
Và `lesson_study_screen.dart:105` truyền `onFinishLesson: () => Navigator.of(context).pop(true)` — **chỉ đóng màn hình**, không ghi nhận hoàn thành. Đường duy nhất ghi nhận là `lesson_flow_providers.dart:40-79` (`submitPractice` → `masteryEngine.recordLessonAttempt`), nằm sau `LessonMasteryView.onSubmit` — nhánh không bao giờ được kích hoạt khi không có câu hỏi.

**Nguyên nhân gốc rễ.** Generator nội dung sinh segment `mastery_check` nhưng quên sinh content item tương ứng; bộ import pack không kiểm tra tính toàn vẹn tham chiếu (referential integrity) giữa `lesson_segments.content_ref_id` và `content_items.content_id`; UI "fail-soft" biến lỗi dữ liệu thành màn hình trống + nút thoát, che giấu lỗi.

**Hậu quả & phạm vi.** 30/30 bài HSK1+HSK2 không thể hoàn thành ⇒ không mở được bài tiếp theo (điều kiện prerequisite dựa trên mastery), toàn bộ "Quy trình học 6 chặng" trong README không hoạt động, `curriculum_mastery`/`lesson_progress`/streak không bao giờ được ghi từ luồng học chính.

**Giải pháp khắc phục.**
1) Bổ sung 30 content item `MASTERY_L1..L15` cho mỗi pack (câu hỏi tổng hợp cuối bài), hoặc bỏ segment này khỏi pack và map sang `PRACTICE_L*`.
2) Thêm validation bắt buộc lúc import: `SELECT` các `content_ref_id` không tồn tại → **rollback + báo lỗi**, không cài pack.
3) Sửa empty-state: nếu thiếu mastery hợp lệ thì gọi thẳng `recordLessonAttempt(lessonId, scorePercent: từ practice)` trước khi pop; không cho phép pop mà không ghi nhận.
4) Thêm integration test: học xong `lesson_1_1` → `lesson_1_2.isLocked == false`.

---

### F-02 — [CRITICAL] Toàn bộ đáp án đúng nằm ở phương án A

**Hiện tượng & bằng chứng.** Phân tích toàn bộ JSON pack:

```text
hsk1 PRACTICE_*: 150 exercises, correct_answer == options[0]: 150/150
hsk2 PRACTICE_*: 150 exercises, correct_answer == options[0]: 150/150
exit_exam (40 câu): correct_answer == options[0] ở toàn bộ câu kiểm tra được
```

UI hiển thị đúng thứ tự lưu, không shuffle: `lesson_practice_view.dart:56-63` lấy `options` nguyên thứ tự và so sánh `selected == correctAnswer`; `level_exit_exam_screen.dart:208,598-600` so sánh text đáp án. Module practice cũng không shuffle — `multiple_choice_widget.dart:34` dùng `definition.correctOptionIndex` lấy từ index của `correct_answer`.

**Nguyên nhân gốc rễ.** Bộ sinh nội dung đặt đáp án đúng ở vị trí đầu rồi mới thêm distractor, và không thực hiện bước shuffle + lưu `correct_index`; không có test phân bố đáp án.

**Hậu quả & phạm vi.** Toàn bộ đánh giá (luyện tập, mastery ≥80%, exit exam ≥120/200) bị vô hiệu: chọn A liên tục là đạt 100%. Đây là lỗi toàn vẹn đánh giá — người học không thực sự được kiểm tra; "mở khóa có điều kiện" và "thi tốt nghiệp" chỉ còn là hình thức.

**Giải pháp khắc phục.**
1) Trong generator: `options = [correct, ...distractors]..shuffle(seededRng)` rồi lưu `correct_option_index = options.indexOf(correct)`; với pack JSON text, thêm field `correct_index` thay vì so sánh text.
2) Trong runtime (defensive): nếu phát hiện tất cả `correctOptionIndex == 0` ở một pack, shuffle khi hiển thị và remap index.
3) Test bắt buộc: với mẫu ≥30 câu, phân bố index phải trải đều (ít nhất 3 vị trí khác nhau), và `P(đáp án đúng ở A) < 60%`.

---

### F-03 — [CRITICAL] APK release ký bằng debug keystore và được phát hành

**Hiện tượng & bằng chứng.** `android/app/build.gradle.kts:26-35`:

```kotlin
buildTypes {
    release {
        // fall back to debug signing only when release keystore is not yet set up
        signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        ...
```
File **không định nghĩa** `signingConfigs { create("release") { … } }` nào ⇒ `findByName("release")` luôn `null` ⇒ mọi bản release dùng debug key. Auditor T2 đã kiểm tra artifact phát hành bằng `apksigner verify --print-certs`: `CN=Android Debug, O=Android` (SHA-256 `20f6ccb1…`). Các APK này được commit vào `release-apk/`, dẫn link tải trực tiếp trong `README.md:15-16`, và workflow `.github/workflows/release.yml:40-42` đăng lại chính chúng lên GitHub Releases.

**Nguyên nhân gốc rễ.** Fallback "tiện cho local" bị đẩy nguyên vào pipeline phát hành; không có CI gate kiểm tra certificate; không có key.properties/keystore trong quy trình build.

**Hậu quả & phạm vi.** Google Play từ chối package; người dùng sideload nhận bản cập nhật có "danh tính" là debug cert công khai — bất kỳ ai có debug keystore (mặc định `androiddebugkey`/`android`) có thể ký APK cùng package name với versionCode cao hơn và Android chấp nhận như bản cập nhật hợp lệ; debug cert hết hạn sau 365 ngày. Toàn bộ chuỗi tin cậy cập nhật bị phá vỡ.

**Giải pháp khắc phục.**
```kotlin
signingConfigs {
    create("release") {
        val props = java.util.Properties().apply { rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use(::load) }
        storeFile = file(props.getProperty("storeFile") ?: error("Missing release keystore"))
        storePassword = props.getProperty("storePassword")
        keyAlias = props.getProperty("keyAlias")
        keyPassword = props.getProperty("keyPassword")
    }
}
buildTypes { release { signingConfig = signingConfigs.getByName("release") } } // KHÔNG fallback
```
Thêm CI gate `apksigner verify --print-certs | grep -q "CN=Android Debug" && exit 1`; xóa APK khỏi git; ký trong CI bằng secret.

---

### F-04 — [CRITICAL] Kiểm tra SHA-256 content-pack bị vô hiệu hóa bằng whitelist cứng

**Hiện tượng & bằng chứng.** `content_pack_manager.dart:109-121`:

```dart
if (rawJson != null && manifest.sha256.isNotEmpty) {
  final actualSha = computeChecksum(rawJson);
  final isKnownValid = manifest.packId == 'hsk3_pack_v1' &&
      manifest.sha256.toLowerCase() ==
          '434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2';
  if (actualSha.toLowerCase() != manifest.sha256.toLowerCase() && !isKnownValid) {
    throw ContentPackManagerException('Mã băm SHA-256 không hợp lệ...');
  }
}
```
Tôi đã tính lại trực tiếp trên file được phát hành:
- **Hash thực tế** của `content_packs_cdn/hsk3_pack_v1.json`: `22e69bcc7686019a05282d2afbbe0ddeb659a5b7e186723c785efdb1d4b67626`
- **Hash khai báo trong manifest** (và cũng là literal trong whitelist): `434442694a2fb1868bd11c54dd698af117f2ce755cee52ccce9918549b17a2c2`

Và catalog remote để trống checksum: `content_pack_remote_service.dart:91,102` (`sha256Checksum: ''`). Generator tự băm trước khi chèn hash vào JSON: `tool/generate_hsk3_cdn_pack.dart:169-177` → manifest tự tham chiếu vòng tròn.

**Nguyên nhân gốc rễ.** Hash được tính trước khi ghi lại chính nó vào JSON; khi test phát hiện sai lệch, "fix" được chọn là whitelist đúng giá trị khai báo thay vì sửa generator → biến cơ chế toàn vẹn thành allow-list mù.

**Hậu quả & phạm vi.** Bất kỳ JSON nào tải từ CDN (repo GitHub bên thứ ba, hoặc MITM có CA tin cậy — MDM/cài root) chỉ cần khai báo đúng hash `4344…` là được cài, ghi đè curriculum/lesson/exam/answer-key trong SQLite. Không có chữ ký số. "SHA-256 verified" trong docs là sai sự thật.

**Giải pháp khắc phục.** Xóa hoàn toàn whitelist; bắt buộc catalog phải có checksum của **byte thực tế** (tính sau khi sinh xong); lý tưởng nhất là chữ ký detached Ed25519 với public key pin trong app. Thêm test: sửa 1 byte pack → cài đặt phải fail.

---

### F-05 — [CRITICAL] Cài đặt người dùng không bao giờ được nạp khi khởi động

**Hiện tượng & bằng chứng.** `AppSettingsNotifier.build()` (`settings_providers.dart:24-33`) gọi `_loadSettingsAsync()` ngay khi provider được đọc lần đầu, và provider này được `main.dart:53-54` đọc trong **frame đầu tiên**:

```dart
final themeMode = ref.watch(themeModeProvider);
final fontScale = ref.watch(fontScaleProvider); // -> appSettingsProvider
```
Bên trong `_loadSettingsAsync` (`:30-33`):
```dart
try {
  final dao = ref.read(appSettingsDaoProvider);   // appSettingsDaoProvider:12-15
  final map = await dao.getAllSettings();
```
`appSettingsDaoProvider` tạo DAO bằng `ref.watch(appDatabaseProvider).database`; getter `database` (`app_database.dart:28-34`) **ném StateError nếu DB chưa mở**. DB chỉ được mở sau đó bởi `AppStartupNotifier.initialize()` (`app_startup_provider.dart:96`), vì `AppShell` watch `appStartupProvider` mới kích hoạt nó (`app_shell.dart:20`). Vì vậy lần đọc headless đầu tiên **luôn thất bại**, và lỗi bị `catch (_) {}` nuốt (`:63`). Không tồn tại `ref.invalidate(appSettingsProvider)` nào sau startup (đã grep toàn `lib/`), nên cài đặt không bao giờ được thử lại.

Thêm vào đó, hai nguồn mặc định mâu thuẫn: `ThemeModeNotifier.build()` = `ThemeMode.light` (`app_theme.dart:448-453`) vs `AppSettings.themeMode` = `ThemeMode.dark` (`app_settings.dart:79-89`).

**Nguyên nhân gốc rễ.** Provider phụ thuộc DB được khởi tạo trước khi có "readiness gate"; lỗi bị nuốt; không có dependency `appStartupProvider` trong `AppSettingsNotifier`.

**Hậu quả & phạm vi.** Mỗi lần mở app, theme/cỡ chữ/hiển thị pinyin/tốc độ TTS/auto-play/haptic đều trở về mặc định; người dùng chỉnh trong Profile thấy áp dụng ngay trong phiên nhưng **mất sau khi khởi động lại** (DB có giá trị nhưng không được đọc). Cài đặt từ onboarding (show_pinyin, speech_rate) cũng không có hiệu lực ở lần chạy sau.

**Giải pháp khắc phục.** Chuyển việc nạp cài đặt vào chuỗi startup (sau khi mở DB, trước `isReady = true`), hoặc cho `AppSettingsNotifier` `ref.watch(appStartupProvider)` và chỉ load khi `isReady`; thay `catch (_) {}` bằng log + trạng thái lỗi; bỏ default trùng lặp (dùng duy nhất `AppSettings.themeMode`).

---

### F-06 — [CRITICAL] Mic AI Voice tiếp tục ghi âm khi rời tab; lượt đang xử lý không thể hủy

**Hiện tượng & bằng chứng.** `AppShell` dùng `IndexedStack` mount vĩnh viễn cả 5 tab (`app_shell.dart:103-119`); tab AI Tutor lại mount vĩnh viễn cả text + voice (`ai_tutor_tab_screen.dart:269-275`). Trong `voice_conversation_service.dart:389-390`, trạng thái `listening` đồng nghĩa mic đang ghi:

```dart
await recorder.startRecording();
_setStatus(VoiceConversationStatus.listening);
```
Call site duy nhất của `endSession()` là nút "Kết thúc" trong màn hình voice (`ai_tutor_voice_chat_screen.dart:113-118`); `dispose()` của màn hình `:68-75` không gọi `endSession()`. Do đó chuyển tab Trang chủ khi đang ở trạng thái `listening` → mic (native `record`) vẫn ghi âm, timer 100 ms vẫn chạy, session DB vẫn mở.

Thêm nữa, `submitSpeechInput` (`:394-454`) không truyền `CancelToken` (repository hỗ trợ) và không kiểm tra thế hệ session sau `await`:
```dart
final tutorResponse = await repository.sendMessage(...);  // không cancel token
...
_setStatus(VoiceConversationStatus.speaking);
await player.play(...); / await tts!.speak(...)
_setStatus(VoiceConversationStatus.listening);
await recorder.resumeRecording();
```
`interrupt()` (`:456-469`) chỉ xử lý khi `speaking`, không hủy được lượt `processing`; `endSession()` (`:483-494`) chỉ dừng hardware, future đang chờ vẫn tiếp tục → phát TTS sau khi người dùng đã kết thúc/đã background, và đưa state machine về `listening` sai.

**Nguyên nhân gốc rễ.** Thiếu ràng buộc vòng đời giữa session voice (singleton provider) và vòng đời UI/host; thiếu generation token/CancelToken cho tác vụ bất đồng bộ.

**Hậu quả & phạm vi.** Vi phạm cam kết quyền riêng tư ("chỉ thu âm khi nhấn giữ", "tự ngắt khi background"): Android hiển thị chỉ báo mic trong khi người dùng đang ở màn hình khác; pin bị tiêu hao; AI trả lời vang lên ngoài ý muốn; trạng thái UI không khớp hardware.

**Giải pháp khắc phục.**
```dart
// 1) Hủy phiên khi đổi tab / đổi mode:
onTabSelected: (tab) {
  final prev = ref.read(selectedTabProvider);
  ref.read(selectedTabProvider.notifier).selectTab(tab);
  if (prev == AppTab.aiTutor && tab != AppTab.aiTutor) {
    ref.read(voiceConversationServiceProvider).endSession();
  }
}
// 2) Generation + CancelToken trong submitSpeechInput:
final gen = ++_turnGeneration;
_turnCancelToken = CancelToken();
final res = await repository.sendMessage(..., cancelToken: _turnCancelToken);
if (gen != _turnGeneration || _status == VoiceConversationStatus.ended) return;
// endSession/interrupt/background: _turnGeneration++; _turnCancelToken?.cancel();
```
3) Thêm điểm kiểm tra abort trong `startSession` (sau permission, sau delay, trước `recorder.startRecording()`), và `dispose()` của màn hình gọi `endSession()`.

---

### F-07 — [CRITICAL] Onboarding "thành công giả" khi ghi DB thất bại

**Hiện tượng & bằng chứng.** `onboarding_providers.dart:299-313` đặt `isCompleted: true` **trước**; toàn bộ transaction ghi settings/profile/goals/unlock nằm trong `try { … } catch (_) {}` kết thúc ở dòng 446. `onboarding_flow_screen.dart:84-98` chờ hàm này rồi gọi `onOnboardingComplete()` vô điều kiện:

```dart
await notifier.completePersonalization(...);
onOnboardingComplete();
```
Tương tự `completePlacementTest` (`:251-284`) và `setStep` (`:227-249`) đều nuốt lỗi.

**Nguyên nhân gốc rễ.** Trạng thái UI được cập nhật optimistic trước khi biết kết quả transaction; lỗi bị bỏ qua để "không chặn người dùng".

**Hậu quả & phạm vi.** Khi ghi DB thất bại (FK, disk full, DB transaction lỗi), người dùng vẫn vào Home nhưng `onboarding_completed` không được lưu, unlock/roadmap/goal không được tạo ⇒ lần mở sau onboarding lặp lại, hồ sơ và mục tiêu không lưu, có thể xuất hiện trạng thái nửa vời giữa UI và DB.

**Giải pháp khắc phục.** Cho `completePersonalization` trả `Future<bool>` (hoặc ném exception), chỉ set `isCompleted=true` sau khi transaction commit thành công; UI hiển thị lỗi + nút thử lại nếu thất bại; thêm test inject DB lỗi và assert onboarding không hoàn tất.

---

### F-08 — [HIGH] Restore backup xóa DB đang sống trước khi xác thực backup

**Hiện tượng & bằng chứng.** `data_management_service.dart:117-188`:
```dart
try { await createBackup(customName: 'pre_restore_safety_snapshot_...'); }
catch (e) { debugPrint('... Warning ...'); }          // (1) lỗi snapshot bị bỏ qua
...
await AppDatabase.instance.close();
final targetDbFile = File(_dbPath);
if (await targetDbFile.exists()) { await targetDbFile.delete(); }  // (2) XÓA DB THẬT
await backupFile.copy(_dbPath);                                      // (3) mới copy backup
...
try { _db = await AppDatabase.instance.open(customPath: _dbPath); }
catch (_) { _db = await databaseFactory.openDatabase(_dbPath, options: ...); } // (4) fallback KHÔNG version
final issues = await DatabaseBackupHelper.checkIntegrity(_db);
if (issues.isNotEmpty) debugPrint('Warning ...');                   // (5) chỉ warning
```
Không có bước mở thử/integrity_check/`user_version` **trước** khi xóa. Nếu copy lỗi giữa chừng hoặc file backup hỏng/không phải SQLite, DB gốc đã mất; fallback (4) mở DB không truyền `version` ⇒ không chạy migration, schema lệch version. `createBackup` cũng không verify file sau khi tạo dù docstring khẳng định có (`database_backup_helper.dart:34-90`).

**Nguyên nhân gốc rễ.** Thiếu giao dịch file atomic (write temp → validate → rename) và thiếu rollback khi restore thất bại.

**Hậu quả & phạm vi.** Một file `.hibak` hỏng/không tương thích khiến toàn bộ dữ liệu học tập không thể khôi phục, buộc người dùng xóa app data; trên thực tế "restore" có thể biến mất dữ liệu thay vì bảo vệ.

**Giải pháp khắc phục.**
```dart
// 1) Copy backup ra file tạm, mở bằng factory riêng, PRAGMA integrity_check + kiểm tra user_version <= current
// 2) Nếu hợp lệ: checkpoint + close, rename(dbPath, dbPath + '.bak_restore'), rename(temp, dbPath)
// 3) Reopen; nếu reopen lỗi -> rollback rename ngay, báo lỗi; tuyệt đối không debugPrint rồi coi là thành công
```
Đồng thời `createBackup` phải verify file vừa tạo trước khi trả về.

---

### F-09 — [HIGH] Hai không gian ID từ vựng song song → ~268 dòng trùng

**Hiện tượng & bằng chứng.** Seed canonical dùng ID `VOC_HSK1_爱_ai` (`assets/data/hsk_seed_fixture_v2.json`, 5.000 từ; `seed_loader.dart:181-215` insert `v.id`). Bộ import content-pack lại đặt PK `vocab_$simplified` (`content_pack_manager.dart:441`). Cùng một từ (ví dụ 爱/ài) tồn tại dưới 2 ID khác nhau trong `vocabularies`; T1 tính toán từ asset thực tế: **268 từ HSK1/HSK2 của pack trùng với seed** → 268 dòng dư.

**Nguyên nhân gốc rễ.** Chuẩn hóa ID không được áp dụng thống nhất giữa seed và pack; `knowledge_registry` dùng `KNOW_VOCAB_*` nhưng bảng `vocabularies` thì không.

**Hậu quả & phạm vi.** Từ điển hiển thị trùng; SRS/mastery bị chia đôi theo hai ID (học từ này không cập nhật tiến độ từ kia); thống kê số từ đã học sai; dung lượng DB tăng.

**Giải pháp khắc phục.** Chọn 1 quy ước canonical (ví dụ `VOC_HSK{level}_{simplified}_{pinyinClean}` của seed) và cho pack importer tra cứu theo `(simplified, pinyin_clean)` trước khi insert — nếu tồn tại thì UPDATE/alias; thêm migration dedupe một lần (merge SRS/evidence rồi xóa bản trùng).

---

### F-10 — [HIGH] `REPLACE` vào `curriculum_mastery` phá lịch sử ôn tập

**Hiện tượng & bằng chứng.** `learning_pipeline_coordinator.dart:648` (nhánh thành công) và `:576` (nhánh lapses):
```dart
await txn.insert(
  DatabaseConstants.tableCurriculumMastery,
  {
    'id': 'mastery_$targetId', 'item_id': targetId, 'item_type': 'vocabulary',
    'mastery_state': calculatedState.value, 'score': attempt.score,
    'attempts_count': 1,                 // <-- luôn = 1
    'last_attempt_at': nowIso, 'created_at': nowIso, 'updated_at': nowIso,
    // thiếu due_review_at / lapses / existing attempts
  },
  conflictAlgorithm: ConflictAlgorithm.replace,
);
```
`REPLACE` = DELETE + INSERT: mỗi câu trả lời luyện tập xóa dòng cũ (mất `attempts_count`, `created_at`, `due_review_at`, `lapses`).

**Nguyên nhân gốc rễ.** Dùng `REPLACE` thay cho UPSERT có cộng dồn; giá trị `attempts_count` hardcode.

**Hậu quả & phạm vi.** Bộ đếm số lần luyện tập luôn về 1; lịch ôn tập SRS gắn với mastery bị reset; mastery state nhảy sai (ví dụ từ mastered về learning) sau mỗi câu đúng; leaderboard/thống kê sai.

**Giải pháp khắc phục.**
```sql
INSERT INTO curriculum_mastery (id, item_id, item_type, mastery_state, score,
  attempts_count, last_attempt_at, due_review_at, lapses, created_at, updated_at)
VALUES (...)
ON CONFLICT(id) DO UPDATE SET
  mastery_state = excluded.mastery_state,
  score = excluded.score,
  attempts_count = curriculum_mastery.attempts_count + 1,
  last_attempt_at = excluded.last_attempt_at,
  due_review_at = excluded.due_review_at,
  updated_at = excluded.updated_at;
```

---

### F-11 — [HIGH] CAT placement: bỏ qua 4/6 kỹ năng, listening lộ đáp án, speaking tự đúng

**Hiện tượng & bằng chứng.** `cat_engine.dart:195-198` — khi cạn item của kỹ năng hiện tại:
```dart
if (nextItem == null) {
  final nextSkill = _findNextSkill(currentSkill, blueprint: activeBlueprint);
  if (nextSkill == null || updatedResponses.length >= activeBlueprint.minTotalItems) {
    // => hoàn tất bài test ngay
```
Với `minTotalItems = 12`, `minItemsPerSkill = 2`, `maxItemsPerSkill = 5` (`cat_blueprint.dart:31-34`) và item bank thực tế (`cat_item_bank.dart`): vocabulary 5, grammar 4, reading 3, listening 8, writing 9, speaking 2. Đường "happy path" 5+4+3 = **12 câu** kết thúc ngay sau reading → **listening/writing/speaking không bao giờ được đánh giá**; người trả lời sai 3 câu reading lại nhận đánh giá 6 kỹ năng (không nhất quán).

Listening: `cat_question_card.dart:91-105` nút audio chỉ hiện SnackBar; prompt lại chứa nguyên đáp án + pinyin (ví dụ "Nghe… [Audio: 谢谢 (xièxie)]") → thành bài đọc. Speaking: `cat_question_card.dart:239` gửi literal `'speech_sample_recorded'`, và `cat_item.dart:128-135` trả `true` cho literal này → 2 câu speaking luôn đúng, theta tăng.

**Nguyên nhân gốc rễ.** Luật dừng dùng `minTotalItems` cho nhánh cạn item thay vì yêu cầu mỗi kỹ năng đạt `minItemsPerSkill`; item bank mất cân bằng (3 item reading); câu hỏi speaking/listening là stub.

**Hậu quả & phạm vi.** Kết quả phân lớp sai: người mới hoàn toàn có thể được đánh giá HSK3-4; người yếu reading bị "đánh giá" cả 6 kỹ năng; roadmap/SRS khởi tạo theo level sai; mất tính công bằng của placement.

**Giải pháp khắc phục.** Chỉ kết thúc khi `mỗi skill đã đánh giá đủ minItemsPerSkill` (hoặc `maxTotalItems`); cân bằng item bank (tối thiểu 5 item/kỹ năng, bổ sung câu listening có audio thật); speaking phải chấm điểm thật (hoặc đánh dấu `skipped` không cộng theta); thêm test happy-path assert cả 6 kỹ năng có ≥2 response.

---

### F-12 — [HIGH] 79 URI âm thanh trỏ tới file không tồn tại

**Hiện tượng & bằng chứng.** Kiểm tra trực tiếp: `assets/audio/` chỉ có `hsk1/` và `hsk2/` (500 file `.mp3` dạng ID số); **không tồn tại** thư mục `pinyin/`, `shadowing/`, `pronunciation/`. `pubspec.yaml:76-81` chỉ khai báo `assets/audio/hsk1/`, `assets/audio/hsk2/`. Thống kê reference:
```text
79 URI duy nhất không tồn tại (84 lượt tham chiếu):
  pinyin 59, shadowing 9, pronunciation 9, listening 2
```
Ví dụ: `pinyin_curriculum_catalog.dart:41` → `assets/audio/pinyin/syllable_structure.mp3`; `shadowing_document_bank.dart:21`; `pronunciation_item_bank.dart:16`; `listening_lesson.dart:52` → `assets/audio/listening_hsk1_01.mp3`.

**Nguyên nhân gốc rễ.** Audio cho các module này chưa được generate/commit, nhưng UI và catalog đã tham chiếu; không có kiểm tra asset tồn tại trong CI.

**Hậu quả & phạm vi.** 4 module (pinyin, shadowing, pronunciation, listening) có nút phát nhưng không phát được gì; nhiều chỗ không await/catch nên lỗi im lặng, người học tưởng "app không có âm thanh"; với listening, bài nghe trở thành bài đọc.

**Giải pháp khắc phục.** Sinh và bundle audio (hoặc dùng TTS fallback có kiểm soát); thêm CI check: parse tất cả URI `assets/audio/**` trong code + assert `File.exists`; nếu thiếu thì fail build; ẩn nút audio khi asset vắng mặt.

---

### F-13 — [HIGH] Bài tập phát hiện lỗi không thể trả lời

**Hiện tượng & bằng chứng.** `practice_seed_catalog.dart:94`:
```dart
stimulus: '他在学校学中文在。',
errorToken: '在。',
```
Widget `true_false_or_error_widget.dart:132-133` tách token bằng regex dấu câu:
```dart
final tokens = text.split(RegExp(r'(?<=\s)|(?<=\p{P})|(?=\p{P})', unicode: true))
    .where((s) => s.trim().isNotEmpty).toList();
```
Với câu không có khoảng trắng, token thu được là `["他在学校学中文在", "。"]`; không token nào bằng `"在。"` ⇒ không thể chọn đúng. Scoring (`practice_scoring_engine.dart:206-208`) so sánh `selected == definition.errorToken` ⇒ luôn false. Validator chỉ kiểm tra `text.contains(errorToken)` (`exercise_validator.dart:141`) nên câu lỗi vẫn pass validation.

**Nguyên nhân gốc rễ.** Không đảm bảo `errorToken` là một phần tử sau tokenization; validator dùng `contains` thay vì cùng thuật toán tokenize với UI.

**Hậu quả & phạm vi.** Câu hỏi xuất hiện trong session luyện tập mặc định (seed HSK1) và luôn 0 điểm; người học không thể hiểu vì sao sai; ảnh hưởng mastery/điểm bài.

**Giải pháp khắc phục.** Sửa `errorToken` thành `在` (token hợp lệ) hoặc tách câu có khoảng trắng; validator phải chạy đúng tokenizer của widget và assert `tokens.contains(errorToken)`; thêm unit test cho mọi seed exercise kiểu `errorDetection`.

---

### F-14 — [HIGH] Ví dụ ngữ pháp bị mất do sai kiểu JSON (silent)

**Hiện tượng & bằng chứng.** Pack importer ghi ví dụ dạng **mảng chuỗi** (`content_pack_manager.dart:632-633`):
```dart
'examples_json': json.encode(posEx.isNotEmpty ? [posEx] : []),
'contrastive_examples_json': json.encode(conEx.isNotEmpty ? [conEx] : []),
```
Parser lại ép từng phần tử thành `Map` (`grammar_models.dart:270-285`) và nuốt lỗi:
```dart
final decoded = json.decode(raw);
if (decoded is List) {
  return decoded.map((e) => GrammarExample.fromMap(e as Map<String, dynamic>)).toList();
}
} catch (_) {}
return [];
```
`[posEx]` là `List<String>` → `as Map` ném `TypeError` → `catch (_)` → danh sách rỗng.

**Nguyên nhân gốc rễ.** Không có "content contract" thống nhất giữa generator/import và model parser; lỗi bị nuốt.

**Hậu quả & phạm vi.** Toàn bộ 90 điểm ngữ pháp từ pack mất ví dụ và ví dụ đối chiếu; tab ví dụ luôn trống; generator bài tập ngữ pháp chỉ tạo được 1/4 dạng (thiếu dữ liệu ví dụ); trải nghiệm học ngữ pháp nghèo nàn dù dữ liệu gốc có.

**Giải pháp khắc phục.** Ghi `examples_json` dạng `[{"zh": "...", "pinyin": "...", "vi": "..."}]`; parser hỗ trợ cả `String` (chuyển thành object) và không nuốt lỗi — log + surface; thêm test round-trip import→đọc.

---

### F-15 — [HIGH] Curriculum và Roadmap "split-brain"

**Hiện tượng & bằng chứng.** Curriculum hoàn thành bài ghi vào `curriculum_mastery` (`learning_pipeline_coordinator.dart` qua `MasteryEngine.recordLessonAttempt`), trong khi Roadmap đọc `lesson_progress` (`roadmap_repository.dart:76`):
```dart
final rows = await _db.query(DatabaseConstants.tableLessonProgress);
```
Grep toàn repo: chỉ `roadmap_repository.dart` ghi bảng này (`:103-157`), pipeline học không ghi. `completeLesson` (`:146`) không được gọi từ luồng curriculum. Ngoài ra catalog roadmap hardcode 6/15 bài HSK1 với ID sai (`LES_HSK1_*` thay vì `lesson_1_1`), HSK3-5 fallback về Pinyin level 0 (`curriculum_catalog.dart:198-203`), và đọc theta bằng key `'theta'` trong khi placement ghi `'estimated_theta'` (`roadmap_repository.dart:293-304`).

**Nguyên nhân gốc rễ.** Hai hệ thống tiến độ được phát triển song song với hai bảng khác nhau, không có adapter/event đồng bộ; catalog roadmap là dữ liệu tĩnh viết tay.

**Hậu quả & phạm vi.** Roadmap không bao giờ tiến bộ dù người học hoàn thành bài; nút hoàn thành bài trong roadmap không có tác dụng; prerequisite không được thỏa mãn → kẹt; hiển thị bài học không tồn tại; điểm năng lực placement không đến được roadmap.

**Giải pháp khắc phục.** Chọn một nguồn sự thật (khuyến nghị `lesson_progress` + `curriculum_mastery` qua cùng repository): pipeline ghi cả hai trong 1 transaction; roadmap lấy catalog từ content pack/DB thay vì hardcode; sửa key theta và scale [-3,3] → [0,1]; thêm integration test "hoàn thành bài trong curriculum → roadmap cập nhật".

---

### F-16 — [HIGH] Hội thoại bài học render trống do lệch field

**Hiện tượng & bằng chứng.** Pack lưu dữ liệu hội thoại dưới `text_zh`/`text_vi`:
```json
{"speaker":"A","text_zh":"A: 你，你好！","pinyin":"A: nǐ, Nǐ hǎo!","text_vi":"A: Xin chào bạn!"}
```
Nhưng view đọc `hanzi`/`meaning` (`lesson_dialogue_view.dart:47-49`):
```dart
final hanzi = (item['hanzi'] ?? item['chinese'] ?? '') as String;
...
final meaning = (item['meaning'] ?? item['vietnamese'] ?? '') as String;
```
⇒ 15 hội thoại HSK1 + 15 HSK2 chỉ hiển thị pinyin, phần chữ Hán/dịch trống.

**Nguyên nhân gốc rễ.** Không có contract test giữa nội dung pack và UI parser; trùng lặp schema field.

**Hậu quả & phạm vi.** Chặng "Hội thoại" — một trong 6 chặng học — mất nội dung chính; người học không thấy chữ Hán/nghĩa.

**Giải pháp khắc phục.** Cho parser đọc cả hai bộ key (`text_zh`/`hanzi`, `text_vi`/`meaning`) và bổ sung test `hsk1_content_integrity_test` kiểm tra render không rỗng.

---

### F-17 — [HIGH] Exit exam không có timer, ghi khống thời gian, retry vô hạn, lộ đáp án

**Hiện tượng & bằng chứng.**
- Không có `Timer` nào trong `level_exit_exam_screen.dart` (grep `Timer` = 0); nhưng khi kết thúc lại ghi `durationSeconds: _durationMinutes * 60` (`:249`) → mọi lượt thi đều được cộng **35 phút** vào thời gian học/streak, dù người dùng chỉ mở 2 giây.
- `curriculum_syllabus_screen.dart:102` mở `LevelExitExamScreen(level: '1')` mặc định → HSK2 syllabus cũng thi "HSK1"; exam HSK2 không thể truy cập.
- Đáp án hiển thị đầy đủ ở màn review (`:598-600,636-645`), retry không giới hạn, pass bao nhiêu điểm cũng được.
- Pass → `curriculum_repository.dart:219-227` (theo T3) cộng credit **toàn bộ 15 bài** với `score=1.0` và mở khóa cấp tiếp theo → bỏ qua toàn bộ lộ trình.

**Nguyên nhân gốc rễ.** Tính năng "phòng thi" mới mô phỏng UI, chưa có engine thi thật (timer, anti-cheat, chấm theo cấp); logic pass lấy credit hàng loạt.

**Hậu quả & phạm vi.** Thống kê học tập/streak bị bơm; người dùng thi lại nhiều lần để xem đáp án; toàn bộ gating của level bị vô hiệu; HSK2 không thi được.

**Giải pháp khắc phục.** Thêm `Timer.periodic` + auto-submit khi hết giờ; ghi `durationSeconds` = thời gian thực; giới hạn số lần thi/ngày hoặc cooldown; ẩn đáp án đến khi nộp; truyền đúng `level` từ syllabus; chỉ credit đúng các bài thuộc level khi pass với điểm ≥ ngưỡng.

---

### F-18 — [HIGH] Rò rỉ callback lifecycle của recorder + không xử lý audio focus

**Hiện tượng & bằng chứng.** `audio_recorder_service.dart:70-76`:
```dart
DefaultAudioRecorderService({ ... }) : ... {
  AppLifecycleManager.instance.registerAudioSession(_onLifecycleStop);
}
```
Không có `unregisterAudioSession` trong class này; grep toàn repo chỉ thấy `unregister` ở `main.dart:96` (màn skeleton chết) và `voice_conversation_service.dart:525`. Các màn `shadowing_screen.dart:45`, `pronunciation_lab_screen.dart:44`, `sentence_shadowing_screen.dart:43` tạo recorder mới mỗi lần vào màn → callback chết tích lũy vô hạn (giữ State object, không GC được) + mỗi lần background chạy lặp qua toàn bộ danh sách.

Đồng thời `AppLifecycleManager.didChangeAppLifecycleState` (`app_lifecycle_manager.dart:47-68`) chỉ dừng **ghi âm**; không có `audio_session`/audio focus nên `just_audio`/TTS vẫn phát khi app background hoặc có cuộc gọi đến (vi phạm doc P1_06 claim).

**Nguyên nhân gốc rễ.** Thiếu hàm hủy đăng ký trong API lifecycle; recorder được tạo theo màn thay vì singleton được quản lý; audio playback không được đăng ký vào lifecycle.

**Hậu quả & phạm vi.** Memory leak tăng dần theo số lần mở màn; callback chạy trên object đã dispose (có thể gây exception); âm thanh tiếp tục phát ngoài ý muốn (pin, quyền riêng tư, trải nghiệm).

**Giải pháp khắc phục.**
```dart
@override
void dispose() {
  AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleStop);
  _durationTimer?.cancel();
  _amplitudeSub?.cancel();
  if (_ownsRecorder) _recorder.dispose();
  // đóng các StreamController
  super.dispose?.call();
}
```
Và thêm `audio_session` (hoặc `AudioFocus` qua platform channel) cấu hình `AudioSessionConfiguration.speech()` + dừng/pause player & TTS khi `paused/inactive`.

---

### F-19 — [HIGH] Toolchain Android không tương thích, build phải bỏ qua validation

**Hiện tượng & bằng chứng.** `android/settings.gradle.kts:22-24` dùng AGP **8.7.0**; Flutter 3.47.9 yêu cầu tối thiểu AGP **8.11.1**. `android/app/build.gradle.kts:9` đặt `compileSdk = 37` — ngoài phạm vi hỗ trợ của AGP 8.7 (Flutter mặc định 36). Báo cáo nội bộ của repo (`docs/agent-coordination/reports/thread-5/apk-build-report.md:13`) xác nhận APK chỉ build được khi dùng `--android-skip-build-dependency-validation` — bỏ qua chính cảnh báo tương thích của Flutter.

**Nguyên nhân gốc rễ.** Nâng compileSdk/AGP/Gradle không đồng bộ và dùng cờ bỏ qua thay vì nâng toolchain.

**Hậu quả & phạm vi.** Build không tái lập được trên máy sạch/CI (người mới clone sẽ fail hoặc buộc dùng cờ); rủi ro runtime với plugin native; các bản build tương lai có thể lỗi ngầm.

**Giải pháp khắc phục.** Nâng AGP → 8.11.1+ (kèm Gradle 8.14+/Kotlin phù hợp), `compileSdk` theo Flutter default, bỏ cờ skip; thêm job CI build sạch `flutter build apk --release` để khóa hồi quy.

---

### F-20 — [HIGH] CI chỉ đăng lại APK cũ đã commit, không build/test/sign

**Hiện tượng & bằng chứng.** Toàn bộ `.github/workflows/release.yml` (43 dòng) chỉ có `actions/checkout` + `softprops/action-gh-release` với đường dẫn file cố định:
```yaml
files: |
  release-apk/hi-chinese-v1.0.9-arm64.apk
  release-apk/app-release.apk
```
Không có bước setup Flutter, build, test, ký, hay checksum. Mọi tag `v*` trong tương lai sẽ phát hành lại y nguyên 2 file APK của v1.0.9.

**Nguyên nhân gốc rễ.** Quy trình phát hành thủ công (build máy dev, commit artifact) được "tự động hóa" nửa vời.

**Hậu quả & phạm vi.** Bản phát hành không khớp source/tag; người dùng tải nhầm bản cũ; không có gate kiểm thử; chuỗi cung ứng phần mềm không kiểm chứng được.

**Giải pháp khắc phục.** Workflow chuẩn: setup Flutter → `flutter pub get` → `flutter analyze` → `flutter test` → build APK/AAB → ký bằng keystore từ GitHub Secrets → `sha256sum` + chữ ký → upload artifact; cấm commit binary.

---

### F-21 — [MEDIUM] Auto Backup bật, không có quy tắc loại trừ

**Bằng chứng.** `AndroidManifest.xml:11-15` — `<application …>` không có `android:allowBackup`, `android:fullBackupContent`, `android:dataExtractionRules` ⇒ mặc định `allowBackup=true`. DB `hi_chinese.db` (chat, hồ sơ, lịch sử học) và thư mục `backups/*.hibak` (bản sao DB **không mã hóa**) nằm trong vùng auto-backup. Ngoài ra flutter_secure_storage dùng Keystore không đi theo backup → khôi phục trên máy mới có thể lỗi giải mã.
**Hậu quả.** Dữ liệu cá nhân/hội thoại AI rời khỏi thiết bị qua Google Drive backup; nguy cơ lộ dữ liệu khi restore; lỗi credential sau restore.
**Fix.** `android:allowBackup="false"` (hoặc `dataExtractionRules` loại trừ `databases/`, `files/backups/`), thêm test/CI lint manifest.

---

### F-22 — [MEDIUM] API key gửi tới proxy tùy ý, validation chưa đủ

**Bằng chứng.** `ai_credential_storage.dart:323-333` chỉ chặn `localhost`, `127.0.0.1`, `192.168.*`, `10.*` — **bỏ sót** `::1`, `127.0.0.2`, `172.16.0.0/12`, `169.254.*`, `localhost.`, miền phân giải về IP nội bộ. `gemini_rest_ai_provider.dart:46-56` (`verifyCredentials`) và `:81-103` (`testConnection`) đọc `getCustomProxyUrl()` trực tiếp, **không** qua `_resolveSecureBaseUrl()` (nơi có kiểm tra https) và không xét `providerType` → có thể gửi key bằng HTTP/nội bộ. Key gửi qua header `x-goog-api-key` tới host người dùng nhập, không có cảnh báo.

**Hậu quả.** Người dùng bị dụ nhập proxy độc hại → mất API key (BYOK = quota/tiền của họ); SSRF vào mạng nội bộ qua proxy test; key có thể bị log ở proxy HTTP.
**Fix.** Validation tập trung tại thời điểm dùng (https bắt buộc, resolve DNS và chặn private/loopback/link-local, allowlist host tùy chọn); `verifyCredentials/testConnection` phải dùng cùng hàm resolve; thêm cảnh báo UI "khóa sẽ được gửi tới máy chủ proxy".

---

### F-23 — [MEDIUM] Audio-pack ZIP: checksum bị bỏ qua, không giới hạn

**Bằng chứng.** `sentences/data/audio_pack_manager.dart:64-74` — `_resolveManifestExpectedSha256` đọc file manifest cục bộ mà trên production không tồn tại (không bundled, không download) ⇒ checksum luôn rỗng; UI không truyền `expectedSha256`; toàn bộ ZIP được buffer vào RAM (`131-191`), không giới hạn số entry/kích thước sau giải nén. `audio_pack_downloader.dart:101-121` nối `relative_path`/`audio_id` từ manifest với thư mục đích mà **không canonicalize/check within-root**, `verifyFileIntegrity('')` trả `true` — hiện chưa có caller production nhưng sẽ thành Zip Slip/arbitrary write khi được nối vào.
**Hậu quả.** Zip-bomb/đầy bộ nhớ/đầy đĩa; nội dung pack không xác thực; tiềm ẩn ghi file ngoài thư mục.
**Fix.** Checksum lấy từ catalog tin cậy (không từ chính manifest tải về), bắt buộc có; giới hạn tổng uncompressed size + số entry; canonicalize `p.normalize` + `p.isWithin(root, target)`; giải nén streaming ra file tạm.

---

### F-24 — [MEDIUM] SRS: tự enroll khi mở Review, lỗi lưu im lặng, "Quên" hẹn 1 ngày

**Bằng chứng.** `srs_repository.dart:287-322`: nếu số thẻ due < limit, query bổ sung từ `vocabularies` các từ **chưa từng học** rồi `getOrCreateCardState` (ghi DB khi đọc) → mở tab Ôn tập lần đầu thấy ngay 25 thẻ "cần ôn hôm nay" dù chưa học. `srs_repository.dart:350-369` ghi activity/streak **ngoài** transaction review và `catch (_) {}`. `srs_providers.dart:106-114` lưu `errorMessage` nhưng UI không render; header luôn "Đã lưu SQLite". `sm2_engine.dart:103,155`: nút "Quên (<10 phút)" lại lên lịch 1 ngày.
**Hậu quả.** Due count sai, empty-state không bao giờ đạt; review bị mất khỏi streak mà không báo; lịch ôn không đúng kỳ vọng người học.
**Fix.** Tách "enroll" (chủ động/onboarding) khỏi "due queue"; bọc activity trong cùng transaction; hiển thị lỗi; sửa Again → requeue sau 10 phút (hoặc đổi nhãn thành "Ngày mai").

---

### F-25 — [MEDIUM] Export/Import JSON không đầy đủ, reset bỏ sót tiến độ

**Bằng chứng.** `data_management_service.dart:191-228` export 7 bảng (user_profiles, goal_history, saved_words, dictionary_history, reading_progress, srs_items, app_settings) — thiếu practice, chat, grammar_progress, hanzi, sentence/pinyin progress, learner_evidence, activities. Import (`:231-339`) chỉ kiểm tra `metadata.app_name == 'HI Chinese'`, không kiểm tra `export_version`/`schema_version`, insert map thô. `clearAllUserData` (`:362-393`) xóa nhiều bảng user nhưng **không** reset `curriculum_lessons.status/completed_at/is_locked`, `curriculum_units.is_locked` (T1-F07) → sau "đặt lại" app vẫn hiển thị bài đã hoàn thành/đã mở khóa.
**Hậu quả.** "Sao lưu" không phải bản sao lưu thật; chuyển máy mất tiến độ; import dữ liệu cũ/newer gây lỗi cột; reset không sạch.
**Fix.** Export toàn bộ bảng user + metadata version; import validate version rồi migrate; reset cập nhật các cột trạng thái curriculum trong cùng transaction; test round-trip export→clear→import.

---

### F-26 — [MEDIUM] `user_profiles`: 3 quy ước ID, UPDATE không WHERE, optimistic save

**Bằng chứng.** `user_default` (`app_startup_provider.dart:305`), `profile_default` (`onboarding_providers.dart:363`), `default_learner` (`user_profile.dart:62`). `onboarding_providers.dart:350-358`:
```dart
final updatedRows = await txn.update(tableUserProfiles, {...}); // KHÔNG where
```
`profile_repository.dart:24-37` đọc `query(..., limit: 1)` không ORDER BY → nếu có nhiều dòng thì đọc ngẫu nhiên. `profile_providers.dart:29-44` set state trước rồi `await repo.saveProfile`, không rollback nếu lỗi.
**Hậu quả.** Nguy cơ tạo/nhân bản hồ sơ (đặc biệt sau import JSON từ máy khác); update ghi đè mọi dòng; UI báo đã lưu khi DB lỗi.
**Fix.** Một ID canonical duy nhất (`user_default`), UPSERT theo ID, mọi update có `where: 'id = ?'`; đọc có ORDER BY; optimistic update phải try/catch + rollback state.

---

### F-27 — [MEDIUM] Điểm đánh giá giả ở reading/hanzi/shadowing

**Bằng chứng.** `sentence_reading_screen.dart:27-38` — trong `initState` ghi attempt `score: 100.0` khi **mở** màn hình đọc → mastery 'mastered' + SRS +3 ngày + streak, không cần đọc. `reading_detail_screen.dart:82` và `:393-409` ghi evidence cả ở submit và dispose (trùng). `hanzi_writing_screen.dart:201-202` sàn điểm 50% (viết sai vẫn 50). `sentence_shadowing_screen.dart:102-120` tự gán 100/75/50 và lưu mastery/SRS.
**Hậu quả.** Mastery/SRS/streak bị thổi phồng; người học "mastered" mà không hề luyện; dữ liệu phân tích sai.
**Fix.** Chỉ ghi điểm khi có hành vi thực (đọc hết/ghi âm/hoàn thành nét); không hardcode score; đánh dấu `isSelfAssessed`/`evidenceType` để downstream không coi là bằng chứng năng lực; test assert không ghi gì khi chỉ mở màn.

---

### F-28 — [MEDIUM] Pinyin/Listening/Practice hub lệch dữ liệu

**Bằng chứng.** `pinyin_practice_screen.dart:45-46`: mọi câu trong bài đều gán `widget.lesson.items.first.id`/`type` → chỉ item đầu tích lũy mastery, `getOverallCompletionRate` không thể đạt 100%. `listening_providers.dart:17-31` hardwire bài HSK1 đầu tiên, HSK2 không truy cập được, đáp án không lưu DB. `learning_screen.dart:248` Practice hub chỉ lấy HSK1 → dạng short-answer (seed hskLevel 2) không bao giờ xuất hiện.
**Hậu quả.** Hoàn thành bài pinyin kẹt; module listening gần như demo; hub bài tập thiếu dạng bài như README quảng cáo ("7 dạng bài tập").
**Fix.** Truyền item thực của câu hỏi; chọn bài listening theo level/tiến độ + lưu attempt; hub lấy theo `currentHskLevel`.

---

### F-29 — [MEDIUM] Home thống kê sai và tên bài hardcode

**Bằng chứng.** `home_repository.dart:466-497`: `totalVocab` lọc `hsk_level = ?`, nhưng `learnedVocab` lọc **toàn bộ** `srs_items` không lọc level → `learnedVocab/totalVocab` có thể >100%; phần trăm hiển thị sai. `:503-512` tên/snippet bài kế tiếp hardcode ("Bài 1: Chào hỏi…", "Bài 2: Con số…") bất kể dữ liệu curriculum; `home_screen.dart:135` nút "Tiếp tục bài học" luôn mở syllabus HSK1.
**Hậu quả.** Dashboard sai (quá 100% hoặc sai cấp), gợi ý bài học không tồn tại/không đúng level, điều hướng sai.
**Fix.** Lọc learned theo level (hoặc tính theo từ có `hsk_level` của tiến độ), clamp 0–100%, lấy bài kế tiếp từ `curriculum_lessons`/roadmap, điều hướng theo `currentHskLevel`.

---

### F-30 — [MEDIUM] Điểm nghẽn hiệu năng & tài nguyên

**Bằng chứng (từ T4, đã đối chiếu file:dòng).**
- Content-pack import: vòng lặp N+1 `SELECT`/`INSERT` + `json.decode` từng content item trên UI isolate trong lần chạy đầu (`content_pack_manager.dart:441-480`); seed 8.4 MB đã offload isolate (đúng), nhưng import pack thì chưa.
- Chat history: `getMessagesBySessionId` không `LIMIT`, mỗi lượt refetch toàn bộ + map lại; provider family không autoDispose → RAM tăng vô hạn; mỗi token streaming gọi `setState` + `animateTo` (kể cả tab ẩn).
- File ghi âm tạm `rec_*.m4a` không bao giờ xóa → phình cache.
- `AudioCoverageAuditor` gọi `File.exists()` hàng nghìn lần trên UI isolate; `AudioStorageManager` băm SHA-256 cả file đồng bộ.
**Hậu quả.** Khởi động lần đầu/giật lag khi import; RAM tăng theo thời gian sử dụng; jank khi streaming/chat; đầy bộ nhớ thiết bị yếu.
**Fix.** `batch()` + transaction cho import; parse JSON trong `Isolate.run`; `LIMIT`/pagination + `autoDispose` cho chat; dọn file tạm sau upload; chuyển IO/hash sang isolate; cache kết quả auditor.

---

### F-31 … F-40 — Nhóm phát hiện mức Low (tóm tắt bằng chứng)

- **F-31 (Dead code / kiến trúc):** `AppRouter.onGenerateRoute` + `AppRouteGuard` (`app_router.dart:60-171`) không có caller nào (`grep pushNamed` = 0); `MaterialApp` dùng `home:`; `AppRoutes.protectedRoutes` (`app_routes.dart:14`) không dùng; manifest không có intent-filter deep link. `main.dart:76-398` còn màn `HiChineseSkeletonScreen` ~320 dòng chết; `DesignSystemDemoScreen` vẫn nằm trong release. Docs/commit message quảng cáo "route guard, deep link protection" là không có thật.
- **F-32 (Version):** `AppConstants.appVersion = '1.0.0'` (`app_constants.dart:5`), About dialog "1.0.0+1" (`about_and_privacy_dialog.dart:43`), profile "v1.0.0+1" (`profile_screen.dart:510`), export metadata (`data_management_service.dart:213`) — trong khi pubspec là `1.0.9+10`. Nên đọc version từ `package_info_plus`/`--dart-define` một nguồn.
- **F-33 (Docs drift):** README ghi "SQLite Schema v9", docs ghi v11, UNIFIED_SCHEMA ghi v15, thực tế `currentDatabaseVersion = 16` (`database_constants.dart:5`); README "64 test suites" vs 92 file; yêu cầu môi trường Flutter ">=3.24" vs `sdk: ^3.13.7`; compileSdk/targetSdk trong docs sai so với code (37/36).
- **F-34 (Test credibility):** `database_migration_test.dart:6-27` chỉ test migration giả `MockMigrationV2`, không có test nâng cấp thật v1→v16; master regression mở SQLite không bật `PRAGMA foreign_keys=ON`; `upsert_safety_test.dart` không assert `rowsAffected`; nhiều widget test chỉ pump UI. Điểm tích cực: 50 file test thực sự chạy sqflite_common_ffi, 0 test bị skip, 2.976 `expect()`.
- **F-35 (Migration v10):** backfill bọc `try/catch` nuốt lỗi (`migration_v10.dart:213-229`) và dùng `REPLACE` trên `knowledge_registry` (`:324-326`) → cascade xóa các link vừa chèn; nửa migration không được retry.
- **F-36 (Seed/pack freshness):** `_checkSeedLoaded`/`_checkPackNeedsImport` (`app_startup_provider.dart:207-241`) chỉ kiểm tra status + số dòng, bỏ qua version/checksum → cập nhật app không nạp lại seed/pack mới (trái với P0-01).
- **F-37 (Edge cases):** tìm kiếm dictionary dùng `LIKE '%?%'` nhưng không escape `%`/`_` của input người dùng; matching-pairs rỗng cho điểm 1.0; shadowing evaluator chia 0 khi target 0 giây → NaN.
- **F-38 (Release artifacts / nội dung):** 9 APK (224 MB) commit trong `release-apk/`; `release-output` manifest ghi `release_gate_status: BLOCKED` nhưng v1.0.9 vẫn được quảng cáo; "45 điểm ngữ pháp" thực tế chỉ 17 unique (15 template trùng dạng "Cấu trúc sử dụng với X").
- **F-39 (Stub / privacy):** `hasSufficientStorage()` luôn `true` (`audio_storage_manager.dart:120-133`); export dữ liệu cá nhân copy JSON vào system clipboard (`data_management_sheet.dart:47-55`).
- **F-40 (Pipeline Python):** tải nguồn từ branch `master` mutable không hash/pin (`download_grammar_sources.py:14-36`); `urlopen` không timeout (`download_hanzi_sources.py:16`); tên file/zip lấy từ corpus không sanitize (`generate_all_audio.py:71-76`). Rủi ro chuỗi cung ứng dữ liệu (không ảnh hưởng runtime app).

---

## 3. KẾ HOẠCH KHẮC PHỤC (ACTION PLAN)

### P0 — Sửa ngay lập tức (chặn phát hành)
| ID | Việc cần làm | Ghi chú kiểm chứng |
| :--- | :--- | :--- |
| F-01 | Sinh `MASTERY_L*` + validate referential integrity khi import; sửa empty-state ghi nhận hoàn thành | Integration test: học bài 1 → bài 2 mở |
| F-02 | Shuffle đáp án + lưu `correct_index`; regenerate 2 pack + exit exam | Test phân bố index + không thể "chọn A toàn bộ" |
| F-03 | Release keystore thật, bỏ fallback debug; CI gate `apksigner` | `apksigner verify` phải ra CN≠Android Debug |
| F-04 | Xóa whitelist SHA; bắt buộc checksum/signature; regenerate hsk3 | Test sửa 1 byte → install fail |
| F-05 | Nạp settings sau khi DB mở (startup gate / watch isReady); bỏ catch nuốt | Test khởi động lần 2 → theme/cỡ chữ được restore |
| F-06 | `endSession()` khi rời tab/mode/dispose; CancelToken + generation guard | Test: rời tab → mic stopped; kết thúc khi đang processing → không phát TTS |
| F-07 | Onboarding chỉ complete khi transaction commit; surface lỗi | Test inject DB error → isCompleted=false |
| F-08 | Restore: validate backup trước, rename atomic + rollback | Test restore file hỏng → DB cũ nguyên vẹn |

### P1 — Ưu tiên cao (sprint kế tiếp)
F-09 (dedupe ID từ vựng + migration), F-10 (UPSERT mastery, giữ attempts/due), F-11 (CAT đủ 6 kỹ năng + audio/ speaking thật), F-12 (bundle audio hoặc ẩn UI + CI asset check), F-13 (sửa errorToken + validator), F-14 (schema examples + parser không nuốt lỗi), F-15 (hợp nhất nguồn tiến độ curriculum/roadmap), F-16 (parser dialogue), F-17 (timer thật, chống retry, đúng level, credit đúng bài), F-18 (unregister recorder + audio focus), F-19 (nâng AGP/Gradle/compileSdk), F-20 (CI build/sign/test thật).

### P2 — Trung bình (1–2 sprint)
F-21 (allowBackup/dataExtractionRules), F-22 (siết proxy + cảnh báo), F-23 (checksum ZIP + giới hạn + path guard), F-24 (tách enroll/sửa Again/hiện lỗi), F-25 (export đầy đủ + version), F-26 (canonical profile ID + WHERE + rollback), F-27 (bỏ điểm giả), F-28 (pinyin/listening/practice hub đúng dữ liệu), F-29 (Home stats level-scoped + bài thật), F-30 (batch/isolate/LIMIT/dọn file tạm).

### P3 — Cải tiến & nợ kỹ thuật (liên tục)
F-31 (xóa dead code, route guard thật hoặc bỏ), F-32 (một nguồn version), F-33 (đồng bộ docs/README + CI check docs drift), F-34 (test migration thật, bật FK trong test, assert rowsAffected, coverage gate), F-35…F-37 (migration v10, seed freshness, edge cases), F-38 (bỏ APK khỏi git, publish artifact đúng, chất lượng nội dung grammar), F-39 (storage check thật, bỏ clipboard → share file), F-40 (pin/hash + timeout + sanitize pipeline).

### Cổng kiểm chứng trước khi phát hành (đề xuất)
1. `flutter analyze` = 0 issue; `flutter test` xanh trên CI (hiện chưa xác minh được trong sandbox này).
2. Test bắt buộc mới: curriculum end-to-end (học → unlock), migration v1→v16 + fresh vs upgrade equivalence, content-contract (pack ↔ UI parser), CAT 6 kỹ năng, audio asset existence, backup/restore hỏng, checksum tamper.
3. `apksigner verify` + `sha256sum` cho artifact; `flutter build apk --release` không dùng cờ skip; test trên thiết bị thật (mic/AI voice/exit exam timer).

---

## 4. PHỤ LỤC

### A. Đánh giá tổng quan kiến trúc
- **Điểm mạnh thực sự:** hạ tầng DB tốt (WAL, FK ON, migration có transaction từ sqflite, seed offload isolate, không có SQL injection — mọi rawQuery đều tham số hóa; secret scan sạch; không có WebView; cleartext bị chặn; zip-slip guard của archive extractor đúng; API key nằm trong `flutter_secure_storage`, không log; xử lý mic/lifecycle cơ bản đúng ở tầng recorder). `dart analyze` sạch.
- **Điểm yếu hệ thống:** (1) nội dung pack và UI parser không có "content contract" → nhiều lỗi field/kiểu dữ liệu im lặng (F-01, F-14, F-16); (2) nhiều nguồn sự thật song song cho tiến độ/ID (F-09, F-15, F-26); (3) `catch (_) {}` xuất hiện rộng khắp ở các luồng ghi dữ liệu quan trọng (F-05, F-07, F-08, F-14, F-24); (4) kiểm thử mạnh về số lượng nhưng thiếu test tích hợp end-to-end cho luồng học cốt lõi và migration thật (F-34); (5) quy trình phát hành thủ công, artifact ký debug (F-03, F-20).

### B. Trạng thái kiểm thử
- `dart analyze lib test`: **No issues found**.
- `flutter test`: **không chạy được trong sandbox** (stdio `flutter_tester` bị chặn 3 lần; không có log). Báo cáo test gần nhất của repo (commit `394bb5d`): 618 executed / 616 pass / 2 fail. Một fail (pronunciation null score) đã được sửa trong code; fail còn lại (HSK-3 checksum) hiện bị **che bởi whitelist** (F-04) nên lần chạy tới có thể xanh trong khi toàn vẹn dữ liệu vẫn bị vô hiệu. Cần chạy lại trên CI/desktop trước khi coi là "verified".

### C. Bản đồ báo cáo chi tiết (audit/findings)
| File | Nội dung | Số phát hiện |
| :--- | :--- | :--- |
| `00-lead-signals.md` | Tín hiệu độc lập của Lead | 12 |
| `01-data-core.md` | DB, migration, seed, DAO, knowledge | 18 |
| `02-security.md` | Network/AI, packs, Android, Python, secrets | 15 |
| `03-business.md` | Curriculum, CAT, SRS, roadmap, home, onboarding | 30 |
| `04-perf-async.md` | Lifecycle, leaks, races, N+1, UI-thread | 25 |
| `05-config-test.md` | Build/release, test credibility, docs drift | 16 |
| `06-features.md` | Grammar, practice, hanzi, pinyin, reading, listening | 22 |

### D. Tuyên bố miễn trừ & độ tin cậy
Mọi trích dẫn `file:dòng` đã được đọc lại trong mã nguồn tại snapshot `5c099ba`. Các kết luận cần môi trường thật (hành vi OS/audio focus, exploit proxy, apksigner) được đánh dấu trong báo cáo chi tiết tương ứng. Báo cáo này **không sửa đổi mã nguồn** — chỉ tạo thư mục `audit/`.
