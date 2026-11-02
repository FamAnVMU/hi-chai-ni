# HI Chinese: Nền Tảng Tự Học HSK Hoàn Chỉnh – Kế Hoạch Triển Khai (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi HI Chinese thành nền tảng tự học tiếng Trung HSK hoàn chỉnh, có cấu trúc thứ bậc sư phạm chuẩn mực, hoạt động ngoại tuyến 100% với gói học liệu HSK 1 tích hợp sẵn, ngân hàng bài tập xác định, cơ chế mở khóa bài học theo điều kiện tiên quyết và AI đóng vai trò trợ giảng bổ trợ.

**Architecture:** Áp dụng Clean Architecture kết hợp Feature-First và Offline-First: Tầng dữ liệu mở rộng với SQLite Schema v9 (Content Catalog & Modular Content Packs), tầng miền (Domain) quản lý điều kiện tiên quyết (Prerequisite Engine) và đánh giá thành thạo (Mastery Engine), tầng ứng dụng phân phối bài học 6 chặng chuẩn sư phạm kết hợp trọng tâm thích ứng (Adaptive Skill Practice), AI Tutor hoạt động dưới dạng phụ trợ theo yêu cầu.

**Tech Stack:** Flutter 3.x, Dart 3.x, `sqflite` (SQLite WAL mode), `flutter_riverpod`, `audioplayers`, `google_generative_ai` (phụ trợ khi có mạng).

**Spec:** [`docs/superpowers/specs/2026-11-02-hsk-self-study-platform-design.md`](file:///C:/Users/phama/Downloads/hi_chinese/docs/superpowers/specs/2026-11-02-hsk-self-study-platform-design.md)

---

## Global Constraints

- **Toàn vẹn ngoại tuyến (Offline-First):** Toàn bộ quy trình tự học, bài học 6 chặng, bài tập định lượng, chấm điểm và đề thi tốt nghiệp HSK 1 phải hoạt động 100% không cần kết nối mạng hay Gemini API.
- **Tiêu chuẩn giáo trình HSK 1:** HSK 2.0 (150 từ vựng cốt lõi, 15 bài học, 45 điểm ngữ pháp, 15 đoạn hội thoại, 150 bài tập định lượng, 1 đề thi thử tốt nghiệp cấp độ).
- **Chiến lược âm thanh:** Âm thanh người thật thu âm MP3/AAC chất lượng cao (chuẩn giọng Bắc Kinh, sư phạm), nén tối ưu đi kèm gói học liệu `hsk1_pack_v1`.
- **Cơ chế mở khóa Placement Test:** Tự động ghi nhận hoàn thành (`completed` với cờ `credited_by_placement_test`) cho các bài học trước đó theo kết quả xếp lớp, cho phép người học xem lại bài cũ bất cứ lúc nào.
- **Quy chuẩn bài tập:** 10 bài tập/bài học với 40% (4 câu) ưu tiên kỹ năng trọng tâm của người học; đáp án chính thức và rubric chấm tất định lưu sẵn trong dữ liệu máy, không gọi LLM để tạo đáp án.
- **Ràng buộc hiệu năng:** Frame budget $\le 16.66\text{ ms}$ (60Hz) và $\le 8.33\text{ ms}$ (120Hz); không nghẽn UI Isolate khi nạp seed data (`Isolate.run`); dọn dẹp controller âm thanh dứt điểm trong `dispose()`.
- **Chất lượng kiểm thử:** Kiểm thử độc lập trên SQLite in-memory/temp DB, cleanup sau test, duy trì 0 errors và 0 warnings trên `dart analyze lib test`.

---

## Review Focus

1. **Khởi chạy lần đầu không có mạng (Zero-network cold start):** Người học cài đặt app và mở lần đầu khi thiết bị hoàn toàn ở chế độ máy bay (Airplane mode) vẫn hoàn tất Onboarding, làm Placement Test và vào học ngay Bài 1 của HSK 1 với đầy đủ âm thanh và bài tập.
2. **Xử lý Placement Test nhảy cóc (Skip-ahead unlock consistency):** Khi người học đạt điểm vào thẳng Bài 8 HSK 1, các Bài 1–7 phải ở trạng thái đã mở khóa/hoàn thành, Bài 8 ở trạng thái sẵn sàng học, Bài 9 trở đi bị khóa theo điều kiện tiên quyết.
3. **Chấm điểm bài tập ngoại tuyến không có đáp án rỗng:** Tất cả 150 bài tập trong ngân hàng câu hỏi HSK 1 phải có cấu trúc đáp án rõ ràng (không null, không rỗng), chấm chính xác và phản hồi lý do ngay lập tức.
4. **Vòng đời audio khi chuyển nhanh giữa các chặng bài học:** Khi người học nghe phát âm từ vựng rồi lập tức chuyển sang bài đọc hoặc bài tập, luồng audio cũ phải dừng ngay lập tức, không phát đè và không rò rỉ audio session.
5. **Độ ổn định của hệ thống mở khóa bài học (Prerequisite lock enforcement):** Người học không thể can thiệp hoặc truy cập Bài $N+1$ khi chưa đạt $\ge 80\%$ điểm kiểm tra của Bài $N$.

---

## Kế Hoạch Các Tác Vụ Chi Tiết (Tasks)

### Task 1: Database Schema v9 & Content Catalog Migration

**Files:**
- Modify: `lib/core/database/database_constants.dart`
- Modify: `lib/core/database/migration_engine.dart`
- Create: `lib/core/database/dao/curriculum_dao.dart`
- Create: `lib/core/database/dao/content_item_dao.dart`
- Create: `lib/core/database/dao/mastery_dao.dart`
- Test: `test/core/database/curriculum_schema_v9_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `MigrationEngine` (v8).
- Produces: `CurriculumDao`, `ContentItemDao`, `MasteryDao` quản lý các bảng: `content_packs`, `curriculums`, `curriculum_units`, `curriculum_lessons`, `lesson_segments`, `content_items`, `mastery_records`, `level_exit_exams`.

- [ ] **Step 1: Write the failing test for Migration v9 and DAOs**
  Viết test kiểm tra migration từ v8 lên v9: xác nhận các bảng mới được tạo đầy đủ khóa chính, khóa ngoại, chỉ mục (indexes), và các phương thức CRUD của `CurriculumDao`, `ContentItemDao`, `MasteryDao` hoạt động chính xác.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/core/database/curriculum_schema_v9_test.dart`
  Expected: FAIL với lỗi bảng chưa tồn tại hoặc migration v9 chưa định nghĩa.
- [ ] **Step 3: Implement Migration v9 và các DAO**
  - Cập nhật `database_constants.dart` định nghĩa tên các bảng và cột của v9.
  - Cập nhật `migration_engine.dart` thêm bước `_migrateToV9(db)`.
  - Triển khai `CurriculumDao`, `ContentItemDao`, `MasteryDao`.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/core/database/curriculum_schema_v9_test.dart`
  Expected: PASS toàn bộ các bài test schema v9.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/database/ test/core/database/curriculum_schema_v9_test.dart
  git commit -m "feat(database): implement schema v9 migration and DAOs for curriculum and content catalog"
  ```

---

### Task 2: Content Pack Domain Models & Offline Loader

**Files:**
- Create: `lib/features/curriculum/domain/models/content_pack_models.dart`
- Create: `lib/features/curriculum/domain/models/curriculum_models.dart`
- Create: `lib/features/curriculum/domain/models/content_item_models.dart`
- Create: `lib/features/curriculum/data/content_pack_loader.dart`
- Create: `lib/features/curriculum/data/curriculum_repository.dart`
- Test: `test/features/curriculum/content_pack_loader_test.dart`

**Interfaces:**
- Consumes: `CurriculumDao`, `ContentItemDao`, SQLite database instance.
- Produces: `ContentPackLoader.loadPackFromJson(String rawJson)`, `CurriculumRepository.getCurriculumByLevel(int level)`.

- [ ] **Step 1: Write the failing test for Content Pack Loader**
  Tạo test fixture mock pack JSON, kiểm tra tính toán checksum SHA-256, parse cây dữ liệu Units $\to$ Lessons $\to$ Segments, và lưu trữ vào database trong Worker Isolate (`Isolate.run`).
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/curriculum/content_pack_loader_test.dart`
  Expected: FAIL do các class models và loader chưa tồn tại.
- [ ] **Step 3: Implement Domain Models, ContentPackLoader và CurriculumRepository**
  - Xây dựng các immutable data classes cho ContentPack, Curriculum, Unit, Lesson, Segment, ContentItem.
  - Xây dựng `ContentPackLoader` với hàm `installOrUpdatePack()` an toàn idempotent.
  - Xây dựng `CurriculumRepository` cung cấp API lấy danh sách bài học, chi tiết từng bài và trạng thái khóa.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/curriculum/content_pack_loader_test.dart`
  Expected: PASS (pack fixture parsed, validated and inserted into DB cleanly).
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/ test/features/curriculum/content_pack_loader_test.dart
  git commit -m "feat(curriculum): implement content pack models, isolate loader, and curriculum repository"
  ```

---

### Task 3: Biên Soạn Gói Học Liệu Chuẩn HSK 1 (`hsk1_pack_v1.json`) & Dữ Liệu Giáo Trình

**Files:**
- Create: `assets/data/content_packs/hsk1/hsk1_pack_v1.json`
- Modify: `pubspec.yaml` (khai báo thư mục assets mới)
- Test: `test/features/curriculum/hsk1_content_integrity_test.dart`

**Interfaces:**
- Consumes: Cấu trúc JSON Schema đã định nghĩa ở Task 2.
- Produces: Bộ dữ liệu giáo trình HSK 1 hoàn chỉnh 100%:
  - 15 bài học chuẩn HSK 2.0 (Chào hỏi, Giới thiệu, Gia đình, Thời gian, Mua sắm, v.v.).
  - 150 từ vựng với Hán tự, Pinyin, nghĩa tiếng Việt, phát âm bản xứ, câu ví dụ song ngữ.
  - 45 điểm ngữ pháp trọng điểm (Cấu trúc, vị trí trong câu, ví dụ chuẩn và ví dụ đối chiếu lỗi sai).
  - 15 đoạn hội thoại/văn bản thực tế có RubyText.
  - 150 chữ Hán kèm dữ liệu nét bút thuận (Stroke order, Vĩnh tự bát pháp).
  - 150 bài tập định lượng (10 câu/bài) bao gồm trắc nghiệm, chọn nghĩa, ghép cặp, sắp xếp câu, điền từ, đúng/sai kèm đáp án chuẩn và giải thích chi tiết.
  - 1 đề thi thử tốt nghiệp cấp HSK 1 (Nghe hiểu 20 câu + Đọc hiểu 20 câu).

- [ ] **Step 1: Write the failing integrity test for HSK 1 Content Pack**
  Viết test kiểm tra tệp `assets/data/content_packs/hsk1/hsk1_pack_v1.json`:
  - Phải chứa đủ 15 bài học liên tiếp.
  - Phải có đủ 150 từ vựng duy nhất thuộc danh mục HSK 1 chính thức.
  - Mỗi bài học phải có đủ 10 bài tập định lượng với `correct_answer` và `explanation` không rỗng.
  - Đề thi Exit Exam phải có đủ 40 câu hỏi chuẩn hóa HSK 1.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/curriculum/hsk1_content_integrity_test.dart`
  Expected: FAIL do file dữ liệu chưa được biên soạn.
- [ ] **Step 3: Biên soạn tệp học liệu `hsk1_pack_v1.json` và cập nhật `pubspec.yaml`**
  - Xây dựng dữ liệu học thuật chính xác, chuẩn sư phạm, không sao chép bừa bãi hay bịa đặt ngữ pháp.
  - Đăng ký asset path trong `pubspec.yaml`.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/curriculum/hsk1_content_integrity_test.dart`
  Expected: PASS 100% các tiêu chí kiểm tra tính toàn vẹn của học liệu HSK 1.
- [ ] **Step 5: Commit**
  ```bash
  git add assets/data/content_packs/ pubspec.yaml test/features/curriculum/hsk1_content_integrity_test.dart
  git commit -m "feat(content): curate and package complete official HSK 1 offline content pack v1"
  ```

---

### Task 4: Prerequisite & Mastery Engine (Auto-Credit & Progression)

**Files:**
- Create: `lib/features/curriculum/domain/engine/prerequisite_engine.dart`
- Create: `lib/features/curriculum/domain/engine/mastery_engine.dart`
- Create: `lib/features/curriculum/data/placement_unlock_handler.dart`
- Test: `test/features/curriculum/prerequisite_mastery_engine_test.dart`

**Interfaces:**
- Consumes: `MasteryDao`, `CurriculumDao`, `curriculum_lessons`, `mastery_records`.
- Produces:
  - `PrerequisiteEngine.evaluateUnlockStatus({required String lessonId, required String learnerId}) -> UnlockResult`
  - `MasteryEngine.recordLessonAttempt({required String lessonId, required double scorePercent}) -> MasteryUpdateResult`
  - `PlacementUnlockHandler.creditLessonsUpToLevel({required int hskLevel, required int lessonOrder}) -> int creditedCount`

- [ ] **Step 1: Write the failing tests for Prerequisite, Mastery and Placement Unlock**
  - Test bài học $N$ bị khóa nếu bài $N-1$ chưa hoàn thành hoặc điểm $< 80\%$.
  - Test mở khóa bài học $N$ khi bài $N-1$ đạt điểm $\ge 80\%$.
  - Test bài thi Placement xếp lớp vào Bài 6: tự động ghi nhận Bài 1–5 đạt chuẩn (`credited_by_placement_test`), mở khóa Bài 6, giữ khóa Bài 7+.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/curriculum/prerequisite_mastery_engine_test.dart`
  Expected: FAIL do các engine chưa được định nghĩa.
- [ ] **Step 3: Implement PrerequisiteEngine, MasteryEngine và PlacementUnlockHandler**
  - Xử lý 5 trạng thái: `not_started`, `in_progress`, `completed`, `needs_review`, `mastered`.
  - Tính toán lịch ôn tập SRS và phát hiện các kiến thức yếu để tạo khuyến nghị học bổ trợ.
  - Xử lý mở khóa an toàn với giao dịch cơ sở dữ liệu ACID.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/curriculum/prerequisite_mastery_engine_test.dart`
  Expected: PASS 100% các kịch bản kiểm tra điều kiện tiên quyết và mở khóa.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/ test/features/curriculum/prerequisite_mastery_engine_test.dart
  git commit -m "feat(curriculum): implement prerequisite unlocking, mastery progression, and placement auto-credit engine"
  ```

---

### Task 5: Adaptive 6-Step Lesson Flow & Deterministic Exercise Engine

**Files:**
- Create: `lib/features/curriculum/domain/models/lesson_flow_state.dart`
- Create: `lib/features/curriculum/domain/engine/adaptive_exercise_sampler.dart`
- Create: `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart`
- Test: `test/features/curriculum/lesson_flow_and_exercise_test.dart`

**Interfaces:**
- Consumes: `ContentItem`, `AdaptiveSkillFocus` (Listening, Speaking, Reading, Writing, Grammar), pre-authored exercise bank.
- Produces: `AdaptiveExerciseSampler.sampleQuestions(...)`, `LessonFlowNotifier` quản lý chu trình 6 bước: Warm-up $\to$ Vocabulary $\to$ Grammar $\to$ Dialogue/Text $\to$ Adaptive Skill Practice (10 câu, 40% trọng tâm) $\to$ Mastery Check & SRS intake.

- [ ] **Step 1: Write the failing test for Lesson Flow & Exercise Sampler**
  - Test chia tỷ trọng bài tập: khi chọn trọng tâm là "Nghe hiểu", 4/10 câu hỏi thuộc nhóm nghe; khi chọn "Viết", 4/10 câu thuộc nhóm viết/chữ Hán.
  - Test chấm điểm tất định: câu hỏi trắc nghiệm, nối cặp, điền từ chấm bằng đáp án có sẵn, trả lời đúng được cộng điểm, sai có giải thích chi tiết, 0 network calls.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/curriculum/lesson_flow_and_exercise_test.dart`
  Expected: FAIL do sampler và provider chưa tồn tại.
- [ ] **Step 3: Implement AdaptiveExerciseSampler and LessonFlowNotifier**
  - Thuật toán lấy mẫu câu hỏi 40% trọng điểm + 60% cân bằng kỹ năng.
  - Quản lý trạng thái chuyển chặng bài học mượt mà qua Riverpod.
  - Tích hợp tự động đẩy từ vựng và câu đã học vào SM-2 SRS sau khi vượt qua bước Mastery Check.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/curriculum/lesson_flow_and_exercise_test.dart`
  Expected: PASS 100% các bài test luồng bài học và chấm điểm thích ứng.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/ test/features/curriculum/lesson_flow_and_exercise_test.dart
  git commit -m "feat(curriculum): implement adaptive 6-step lesson flow and deterministic exercise scoring engine"
  ```

---

### Task 6: Cải Tiến Luồng Khởi Đầu (Onboarding Flow)

**Files:**
- Modify: `lib/features/placement_test/presentation/screens/placement_survey_screen.dart`
- Create: `lib/features/onboarding/presentation/screens/onboarding_api_key_screen.dart`
- Create: `lib/features/onboarding/presentation/screens/onboarding_personalization_screen.dart`
- Modify: `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- Test: `test/features/onboarding/onboarding_flow_test.dart`

**Interfaces:**
- Consumes: `AppSettingsDao`, `PlacementTestService`, `UserGoalDao`.
- Produces: Trải nghiệm onboarding 3 bước hoàn chỉnh:
  1. Cấu hình AI API Key (có nút "Bỏ qua để học tiêu chuẩn ngoại tuyến").
  2. Placement Test bắt buộc (hoặc tùy chọn "Bắt đầu từ con số 0 - HSK 1").
  3. Cá nhân hóa (Thời lượng học cam kết + Kỹ năng trọng tâm ưu tiên).

- [ ] **Step 1: Write the failing widget test for Onboarding Flow**
  Kiểm tra luồng chuyển màn hình từ Bước 1 (API key / Bỏ qua) $\to$ Bước 2 (Placement Test) $\to$ Bước 3 (Cá nhân hóa) $\to$ Vào màn hình chính giáo trình HSK 1.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/onboarding/onboarding_flow_test.dart`
  Expected: FAIL do các màn hình bước 1 & bước 3 chưa được cấu hình liên hoàn.
- [ ] **Step 3: Implement Onboarding Screens & Navigation State**
  - Xây dựng `OnboardingApiKeyScreen` với thông điệp minh bạch về việc học không cần AI.
  - Xây dựng `OnboardingPersonalizationScreen` thu thập cam kết học và kỹ năng trọng điểm.
  - Kết nối `PlacementUnlockHandler` tự động phân cấp và lưu hồ sơ người học.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/onboarding/onboarding_flow_test.dart`
  Expected: PASS 100% widget test luồng onboarding.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/onboarding/ lib/features/placement_test/ test/features/onboarding/onboarding_flow_test.dart
  git commit -m "feat(onboarding): implement 3-step pedagogical onboarding with optional API key and mandatory placement"
  ```

---

### Task 7: Xây Dựng Giao Diện Giáo Trình, Bài Học 6 Chặng & Đề Thi Tốt Nghiệp HSK 1

**Files:**
- Create: `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart`
- Create: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Create: `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_warmup_view.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_grammar_view.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_dialogue_view.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_practice_view.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart`
- Modify: `lib/features/home/presentation/screens/home_screen.dart` (liên kết vào tab Giáo trình)
- Test: `test/features/curriculum/curriculum_ui_widget_test.dart`

**Interfaces:**
- Consumes: `curriculumRepositoryProvider`, `lessonFlowNotifierProvider`, `strokeEvaluator`, `AudioPlayerService`.
- Produces: Toàn bộ trải nghiệm giao diện người dùng tương tác trực quan cho toàn bộ 15 bài học HSK 1 và đề thi tổng kết cấp độ.

- [ ] **Step 1: Write the failing widget tests for Syllabus, Lesson Study & Exit Exam**
  - Test hiển thị danh sách 15 bài học, trạng thái khóa của bài chưa đủ điều kiện, hiển thị badge tiến độ.
  - Test lật chuyển 6 chặng trong `LessonStudyScreen`.
  - Test hoàn thành bài tập thực hành và tính điểm bài kiểm tra Mastery Check.
  - Test giao diện đề thi tốt nghiệp cấp độ `LevelExitExamScreen`.
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/curriculum/curriculum_ui_widget_test.dart`
  Expected: FAIL do các màn hình và widget chưa được tạo.
- [ ] **Step 3: Implement CurriculumSyllabusScreen, LessonStudyScreen, ExitExamScreen and Widgets**
  - Xây dựng giao diện Material 3 với bảng màu Lime/Forest chuẩn của ứng dụng.
  - Tích hợp RubyText cho chữ Hán kèm Pinyin.
  - Tích hợp trình phát âm thanh thu âm người bản xứ và canvas luyện viết nét Hán tự.
  - Tích hợp đề thi tốt nghiệp HSK 1 với đồng hồ đếm giờ và bảng phân tích năng lực chi tiết sau thi.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/curriculum/curriculum_ui_widget_test.dart`
  Expected: PASS 100% widget test cho giao diện giáo trình và bài học.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/ lib/features/home/ test/features/curriculum/curriculum_ui_widget_test.dart
  git commit -m "feat(ui): implement syllabus roadmap, 6-step lesson player, and HSK 1 exit exam interface"
  ```

---

### Task 8: Thiết Lập Rào Chắn AI Tutor Thành Trợ Giảng Phụ Trợ (Auxiliary Modal)

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/ai_tutor_helper_sheet.dart`
- Modify: `lib/features/ai_tutor/domain/context_builder.dart`
- Modify: `lib/features/ai_tutor/presentation/screens/ai_tutor_chat_screen.dart`
- Test: `test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart`

**Interfaces:**
- Consumes: Gemini API client, bài học hiện tại (`currentLesson`), điểm ngữ pháp đang học, bài tập người dùng vừa làm sai.
- Produces: Nút trợ giảng "Hỏi AI giải thích thêm" xuất hiện đúng lúc trong bài học, rào chắn System Prompt ngăn cản AI thay đổi giáo trình hoặc ghi đè đáp án, xử lý thông báo thân thiện khi không có mạng.

- [ ] **Step 1: Write the failing guardrail test for AI Auxiliary Mode**
  - Test AI từ chối khi được yêu cầu tự sửa đáp án chính thức hoặc mở khóa bài học.
  - Test fallback khi thiết bị ngắt mạng: hiển thị thông báo "AI chỉ là trợ giảng bổ trợ khi có mạng. Bạn vẫn có thể tiếp tục tự học giáo trình ngoại tuyến 100%".
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart`
  Expected: FAIL do rào chắn prompt và sheet trợ giảng chưa được thiết lập.
- [ ] **Step 3: Implement AiTutorHelperSheet and Auxiliary Guardrails**
  - Cập nhật Context Builder với system instruction khẳng định rõ vị trí trợ giảng bổ trợ.
  - Tích hợp modal bottom sheet mở ra từ các chặng Ngữ pháp và Bài tập của bài học.
- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart`
  Expected: PASS 100% các bài test rào chắn và fallback ngoại tuyến.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/widgets/ai_tutor_helper_sheet.dart lib/features/ai_tutor/ test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart
  git commit -m "feat(ai): establish auxiliary AI tutor bottom sheet with anti-overwriting guardrails and offline fallback"
  ```

---

### Task 9: Master Regression Test Suite, Static Analysis & Release Build Verification

**Files:**
- Create: `test/regression/hsk_self_study_platform_master_test.dart`
- Modify: `docs/architecture-decisions.md` (bổ sung Section 26)
- Modify: `README.md`
- Test: Toàn bộ test suite dự án (`flutter test`)

**Interfaces:**
- Consumes: Toàn bộ mã nguồn và test của Tasks 1–8.
- Produces: Báo cáo kiểm định toàn diện 8/8 tiêu chí của User Request, cập nhật tài liệu kiến trúc, bản build APK Release mới.

- [ ] **Step 1: Write the master end-to-end integration test**
  Kiểm thử chuỗi hành trình hoàn chỉnh của người học từ con số 0 trong môi trường ngắt mạng hoàn toàn:
  1. Khởi động app ngoại tuyến.
  2. Bỏ qua nhập API Key.
  3. Làm bài test đầu vào xếp lớp.
  4. Nạp gói học liệu HSK 1.
  5. Học lần lượt qua các chặng của Bài 1: Dẫn nhập $\to$ Từ vựng $\to$ Ngữ pháp $\to$ Hội thoại $\to$ 10 bài tập thích ứng $\to$ Mastery check $\ge 80\%$.
  6. Kiểm tra mở khóa thành công Bài 2 và tự động đưa từ vựng vào SRS.
  7. Thi đề thi tốt nghiệp HSK 1 và nhận bảng đánh giá năng lực.
- [ ] **Step 2: Run master integration test**
  Run: `flutter test test/regression/hsk_self_study_platform_master_test.dart`
  Expected: PASS toàn bộ luồng tích hợp.
- [ ] **Step 3: Run full test suite & static analysis**
  Run: `flutter test`
  Expected: Tất cả các test (~400+ tests) đều PASS 100%.
  Run: `dart analyze lib test`
  Expected: 0 errors, 0 warnings.
- [ ] **Step 4: Rebuild release APKs and update README**
  Run: `flutter build apk --release --split-per-abi`
  Run: `flutter build apk --release`
  Cập nhật tài liệu kiến trúc Section 26 trong `docs/architecture-decisions.md`.
- [ ] **Step 5: Commit and push**
  ```bash
  git add .
  git commit -m "feat(release): complete transition to systematic offline-first HSK self-study platform"
  git push origin main
  ```
