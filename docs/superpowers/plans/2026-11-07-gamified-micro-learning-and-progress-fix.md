# Kế Hoạch Triển Khai: Học Tương Tác Vi Mô (Gamified Micro-Learning) & Khắc Phục Lưu Tiến Độ

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗi học xong không lưu tiến độ / streak trên Trang chủ & Lộ trình, đồng thời thay thế bài học tĩnh cũ bằng Trình học tương tác vi mô cuốn hút (Gamified Micro-Learning) chuẩn HelloChinese/Duolingo kết hợp Cẩm nang tra nhanh, và phát hành bản build APK v1.0.16.

**Architecture:** 
1. **Progress & Activity Sync**: Khi hoàn thành bài học, `LearningPipelineCoordinator` tự động ghi một phiên học vào `tableLearningActivities` (chuẩn Schema v20) và `tableLessonProgress`, cập nhật `curriculum_lessons.status = 'completed'` và mở khóa bài kế tiếp; `LessonStudyScreen` tự động invalidate các provider Riverpod (`curriculumUnitsWithLessonsProvider`, `homeDashboardProvider`, `roadmapProgressProvider`) để UI cập nhật tức thì.
2. **Gamified Micro-Learning Engine**: Bộ điều hợp dữ liệu (Data Adapter) chuyển đổi nội dung bài học thành chuỗi 15–18 thẻ vi mô tuần tự (Giới thiệu từ vựng kèm âm thanh $\rightarrow$ Nghe chọn chữ Hán $\rightarrow$ Ghép câu Word Tile $\rightarrow$ Ghép cặp từ $\rightarrow$ Hội thoại mini). Tích hợp phản hồi âm thanh, rung nhẹ haptic, bộ đếm 🔥 Combo và vòng lặp làm lại câu sai ở cuối bài.
3. **Quick Notes & Celebratory Milestone**: Cung cấp nút 📖 "Cẩm nang bài học" trên AppBar mở bảng tra cứu từ vựng & ngữ pháp tóm tắt; kết bài bằng màn hình ăn mừng rực rỡ với `+25 XP`, `🔥 Streak`, thông báo mở khóa bài mới và nút chuyển bài.
4. **Release Automation**: Chạy kiểm thử toàn diện, nâng version lên `v1.0.16+16`, build Split APKs và phát hành GitHub Release.

**Tech Stack:** Flutter, Dart 3.5+, Flutter Riverpod, SQLite (sqflite Schema v20), Material 3.

**Spec:** [`docs/superpowers/specs/2026-11-07-interactive-learning-and-progress-design.md`](file:///C:/Users/phama/Downloads/hi_chinese/docs/superpowers/specs/2026-11-07-interactive-learning-and-progress-design.md)

---

## Global Constraints

- **Offline-First SQLite**: Toàn bộ dữ liệu bài học và trạng thái tiến độ lưu trữ cục bộ, tuân thủ nghiêm ngặt Schema v20 (không thêm cột ngoài Schema vào `learning_activities`).
- **Clean Architecture & Design Tokens**: Sử dụng chuẩn `AppColors`, `AppTypography`, `AppSpacing`, `HiCard`, `HiButton`.
- **Zero Progress Loss**: Cập nhật hệ thống bảo toàn 100% dữ liệu tiến độ cũ trong `curriculum_mastery`, `srs_items`, `user_profiles`.
- **Handoff & Invalidation Integrity**: Mọi thay đổi trạng thái bài học phải được phản ánh ngay lập tức trên UI Trang chủ và Lộ trình mà không cần khởi động lại ứng dụng.
- **Release Automation**: Tự động build Split APKs (`arm64-v8a`, `armeabi-v7a`), cập nhật README.md và đẩy tag GitHub.

---

## Review Focus

1. **Activity Logging & Streak Integrity**: `tableLearningActivities` nhận bản ghi phiên học hợp lệ với ngày địa phương (`activity_date`), giúp `HomeRepository.calculateStreak` nhận diện hoạt động ngay trong ngày.
2. **Pedagogical Scoring Baseline**: `completeLesson` không bao giờ gán điểm `0.0` cho người học đã hoàn thành các tương tác tự học; đảm bảo bài học luôn đạt $\ge 85\%$ để kích hoạt mở khóa bài tiếp theo.
3. **Provider Invalidation Lifecycle**: Đóng `LessonStudyScreen` phải kích hoạt reload tức thì cho `curriculumUnitsProvider`, `curriculumLessonsProvider`, `curriculumUnitsWithLessonsProvider`, `homeDashboardProvider`.
4. **Tokenization Boundary**: Bộ ghép câu Word Tile tách từ chính xác dựa trên danh mục từ vựng bài học, không bị tách vụn từ ghép (ví dụ: `[学生]` thay vì `[学]` và `[生]`).
5. **Retry Queue Safety**: Thẻ trả lời sai được đẩy về cuối hàng đợi và có thể hoàn thành trọn vẹn, không gây lỗi vòng lặp vô tận (infinite loop).

---

## Tasks

### Task 1: Sửa Triệt Để Pipeline Đồng Bộ Tiến Độ, Hoạt Động & Streak Trong SQLite

**Files:**
- Modify: `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`
- Modify: `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart`
- Modify: `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart`
- Test: `test/features/learning_pipeline/progress_sync_and_streak_test.dart`

**Interfaces:**
- Consumes: `tableLearningActivities`, `tableLessonProgress`, `tableCurriculumLessons`, `tableCurriculumMastery`
- Produces: `recordLessonCompletion` tự động insert phiên học hợp lệ vào `tableLearningActivities`; `completeLesson` đảm bảo đạt chuẩn mở khóa bài mới; `CurriculumSyllabusScreen` invalidate providers khi pop.

- [ ] **Step 1: Viết failing test cho quy trình đồng bộ tiến độ và ghi nhận hoạt động**
  Tạo `test/features/learning_pipeline/progress_sync_and_streak_test.dart`:
  - Test 1: Khi gọi `recordLessonCompletion`, bảng `learning_activities` phải có ít nhất 1 bản ghi có `activity_type = 'lesson'` với `activity_date` trùng ngày hôm nay.
  - Test 2: Bảng `curriculum_lessons` được cập nhật `status = 'completed'`, bài học tiếp theo được mở khóa (`is_locked = 0`).
  - Test 3: `HomeRepository.getDashboardData` phản ánh đúng `hasCompletedLessons = true` và `streak.currentStreak >= 1`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Chạy: `flutter test test/features/learning_pipeline/progress_sync_and_streak_test.dart`
  Kết quả mong đợi: FAIL do `tableLearningActivities` chưa được insert.

- [ ] **Step 3: Cập nhật `LearningPipelineCoordinator` và `LessonFlowNotifier`**
  - Trong `LearningPipelineCoordinator.recordLessonCompletion`:
    Thêm đoạn code insert vào `tableLearningActivities`:
    ```dart
    final timeZoneOffset = DateTime.now().timeZoneOffset;
    await txn.insert(
      DatabaseConstants.tableLearningActivities,
      {
        'id': 'act_${lessonId}_${nowUtc.millisecondsSinceEpoch}',
        'activity_type': 'lesson',
        'duration_seconds': durationMs > 0 ? (durationMs / 1000).round() : 180,
        'items_count': questionResults?.length ?? 10,
        'activity_date': StreakCalculator.toLocalDate(nowUtc, timeZoneOffset: timeZoneOffset),
        'created_at': nowIso,
        'timezone_offset_minutes': timeZoneOffset.inMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    ```
  - Trong `LessonFlowNotifier.completeLesson`:
    Đảm bảo nếu người học hoàn thành bài tự học (hoặc `userAnswers.isEmpty`), điểm mặc định `candidateScore = defaultScorePercent` ($0.85$), tuyệt đối không gán `0.0`.
  - Trong `CurriculumSyllabusScreen`:
    Khi mở `LessonStudyScreen`, await kết quả pop và invalidate:
    ```dart
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonStudyScreen(lesson: lesson)),
    );
    if (result == true) {
      ref.invalidate(curriculumUnitsProvider);
      ref.invalidate(curriculumLessonsProvider);
      ref.invalidate(curriculumUnitsWithLessonsProvider);
      ref.invalidate(homeDashboardProvider);
    }
    ```

- [ ] **Step 4: Chạy lại test để xác nhận pass**
  Chạy: `flutter test test/features/learning_pipeline/progress_sync_and_streak_test.dart`
  Kết quả: PASS 100%.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart lib/features/curriculum/presentation/providers/lesson_flow_providers.dart lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart test/features/learning_pipeline/progress_sync_and_streak_test.dart
  git commit -m "fix(pipeline): record learning_activities on lesson completion and invalidate UI providers"
  ```

---

### Task 2: Xây Dựng Các Widget Tương Tác Vi Mô (Micro-Learning Widgets)

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/interactive_word_tile_builder.dart`
- Create: `lib/features/curriculum/presentation/widgets/interactive_matching_pairs.dart`
- Create: `lib/features/curriculum/presentation/widgets/interactive_audio_choice.dart`
- Test: `test/features/curriculum/interactive_widgets_test.dart`

**Interfaces:**
- Consumes: Audio pronunciation, Hanzi/Pinyin string arrays, word tokens
- Produces: Các component tương tác phản hồi xúc giác + âm thanh phục vụ trình học Gamified.

- [ ] **Step 1: Viết test cho các widget tương tác vi mô**
  Tạo `test/features/curriculum/interactive_widgets_test.dart`:
  - Test 1 (`InteractiveWordTileBuilder`): Chạm vào chip từ để đưa lên câu trả lời, chạm lại để hoàn tác, bấm "Kiểm tra" phát tín hiệu đúng/sai qua callback.
  - Test 2 (`InteractiveMatchingPairs`): Chạm vào 1 chữ Hán và 1 nghĩa tiếng Việt tương ứng làm biến mất cặp từ; khi ghép hết 4 cặp kích hoạt `onComplete`.
  - Test 3 (`InteractiveAudioChoice`): Hiển thị nút loa phát âm, chọn đáp án đúng kích hoạt callback chính xác.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Chạy: `flutter test test/features/curriculum/interactive_widgets_test.dart`

- [ ] **Step 3: Triển khai các widget tương tác vi mô**
  - Tạo `InteractiveWordTileBuilder`:
    Quản lý danh sách chip nguồn (Source Chips) và danh sách chip đã chọn (Target Chips). Hiệu ứng viền xanh / đỏ khi kiểm tra.
  - Tạo `InteractiveMatchingPairs`:
    Quản lý trạng thái chọn `selectedHanzi` và `selectedMeaning`, hiệu ứng triệt tiêu cặp ghép đúng.
  - Tạo `InteractiveAudioChoice`:
    Nút loa to tròn, danh sách thẻ lựa chọn có Pinyin/nghĩa.
  - Tích hợp `HapticFeedback.lightImpact()` và âm thanh phản hồi nhẹ.

- [ ] **Step 4: Chạy test để xác nhận pass**
  Chạy: `flutter test test/features/curriculum/interactive_widgets_test.dart`
  Kết quả: PASS 100%.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/widgets/interactive_word_tile_builder.dart lib/features/curriculum/presentation/widgets/interactive_matching_pairs.dart lib/features/curriculum/presentation/widgets/interactive_audio_choice.dart test/features/curriculum/interactive_widgets_test.dart
  git commit -m "feat(curriculum): implement interactive word tile, matching pairs, and audio choice widgets"
  ```

---

### Task 3: Xây Dựng Cẩm Nang Tra Nhanh & Màn Hình Ăn Mừng Hoàn Thành

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/lesson_quick_notes_sheet.dart`
- Create: `lib/features/curriculum/presentation/widgets/lesson_celebration_view.dart`
- Test: `test/features/curriculum/lesson_celebration_and_quick_notes_test.dart`

**Interfaces:**
- Consumes: `CurriculumLesson`, điểm số bài học, XP thưởng, streak count
- Produces: `LessonQuickNotesSheet` mở modal tra cứu tóm tắt; `LessonCelebrationView` hiển thị thành tích kết bài và nút mở khóa bài kế tiếp.

- [ ] **Step 1: Viết test cho Quick Notes và Celebration View**
  Tạo `test/features/curriculum/lesson_celebration_and_quick_notes_test.dart`:
  - Test 1: `LessonQuickNotesSheet` hiển thị tab/danh sách từ vựng trọng tâm, công thức ngữ pháp tóm tắt và hội thoại mẫu của bài học.
  - Test 2: `LessonCelebrationView` hiển thị `+25 XP`, chuỗi Streak, tỷ lệ câu đúng và gọi callback `onContinue` khi nhấn "Tiếp tục học".

- [ ] **Step 2: Chạy test để xác nhận fail**
  Chạy: `flutter test test/features/curriculum/lesson_celebration_and_quick_notes_test.dart`

- [ ] **Step 3: Triển khai `LessonQuickNotesSheet` & `LessonCelebrationView`**
  - Xây dựng `LessonQuickNotesSheet` dạng `DraggableScrollableSheet` với giao diện Clean Modern White, bố cục 3 phần rõ ràng: Từ mới, Ngữ pháp tinh gọn, Hội thoại.
  - Xây dựng `LessonCelebrationView` với hiệu ứng ăn mừng biểu tượng `🎉`, huy hiệu vàng `+25 XP`, ngọn lửa `🔥 Streak`, và thông báo xanh `✓ Đã mở khóa bài tiếp theo`.

- [ ] **Step 4: Chạy test để xác nhận pass**
  Chạy: `flutter test test/features/curriculum/lesson_celebration_and_quick_notes_test.dart`
  Kết quả: PASS 100%.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/widgets/lesson_quick_notes_sheet.dart lib/features/curriculum/presentation/widgets/lesson_celebration_view.dart test/features/curriculum/lesson_celebration_and_quick_notes_test.dart
  git commit -m "feat(curriculum): add lesson quick notes sheet and celebratory milestone view"
  ```

---

### Task 4: Tích Hợp Trình Học Tương Tác Vi Mô (GamifiedLessonPlayer) Vào `LessonStudyScreen`

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/gamified_lesson_player.dart`
- Create: `lib/features/curriculum/domain/engine/lesson_micro_card_adapter.dart`
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/gamified_lesson_player_test.dart`

**Interfaces:**
- Consumes: `CurriculumLesson` từ SQLite, chuyển hóa thành danh sách 15–18 micro-cards
- Produces: Trình học tương tác vi mô thay thế bài học tĩnh cũ, có thanh tiến độ xanh lá, đếm combo, hàng đợi thử lại, nút Cẩm nang trên AppBar và màn hình ăn mừng kết bài.

- [ ] **Step 1: Viết test cho `LessonMicroCardAdapter` và `GamifiedLessonPlayer`**
  Tạo `test/features/curriculum/gamified_lesson_player_test.dart`:
  - Test 1: Adapter phân tích bài học có 10 từ vựng và hội thoại thành chuỗi micro-cards hợp lệ.
  - Test 2: Trả lời đúng tăng thanh tiến độ và combo 🔥.
  - Test 3: Trả lời sai đưa thẻ vào hàng đợi làm lại cuối bài.
  - Test 4: Hoàn thành toàn bộ thẻ chuyển sang `LessonCelebrationView` và gọi `flowNotifier.completeLesson()`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Chạy: `flutter test test/features/curriculum/gamified_lesson_player_test.dart`

- [ ] **Step 3: Triển khai Adapter & Trình học Gamified**
  - Xây dựng `LessonMicroCardAdapter`:
    - Quét từ vựng trong segment `vocabulary` ➔ tạo thẻ Reveal + Audio Choice + Matching Pairs.
    - Quét câu trong segment `dialogue` và `grammar` ➔ tạo thẻ Word Tile Builder.
    - Quét câu hỏi trong segment `practice` ➔ tạo thẻ trắc nghiệm nhanh.
  - Xây dựng `GamifiedLessonPlayer`:
    - Thanh tiến độ mượt mà trên đỉnh màn hình.
    - Xử lý hàng đợi câu hỏi, bộ đếm combo 🔥.
  - Cập nhật `LessonStudyScreen`:
    - Thêm nút icon 📖 trên AppBar để mở `LessonQuickNotesSheet`.
    - Dựng `GamifiedLessonPlayer` làm giao diện học tập chính, bọc trong `LessonStepErrorBoundary`.

- [ ] **Step 4: Chạy test để xác nhận pass**
  Chạy: `flutter test test/features/curriculum/gamified_lesson_player_test.dart`
  Chạy regression tests: `flutter test test/features/curriculum/`
  Kết quả: PASS 100%.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/widgets/gamified_lesson_player.dart lib/features/curriculum/domain/engine/lesson_micro_card_adapter.dart lib/features/curriculum/presentation/screens/lesson_study_screen.dart test/features/curriculum/gamified_lesson_player_test.dart
  git commit -m "feat(curriculum): integrate gamified micro-learning player into lesson study screen"
  ```

---

### Task 5: Kiểm Thử Toàn Diện, Nâng Version v1.0.16, Build Split APKs & Đẩy GitHub Release

**Files:**
- Modify: `pubspec.yaml`
- Modify: `README.md`
- Create: `audit/GAMIFIED_LEARNING_AND_PROGRESS_QA_REPORT.md`
- Build outputs: `release-apk/hi-chinese-v1.0.16-arm64-v8a.apk`, `release-apk/hi-chinese-v1.0.16-armeabi-v7a.apk`, `release-apk/app-release.apk`

- [ ] **Step 1: Chạy kiểm thử toàn bộ dự án và phân tích mã nguồn tĩnh**
  ```bash
  flutter test test/features/learning_pipeline/
  flutter test test/features/curriculum/
  flutter analyze lib/ test/
  ```
  Xác nhận 100% tests pass và 0 issues found.

- [ ] **Step 2: Nâng version ứng dụng lên v1.0.16+16**
  Trong `pubspec.yaml`: cập nhật `version: 1.0.16+16`.

- [ ] **Step 3: Biên dịch Split APKs Release**
  ```bash
  flutter build apk --split-per-abi --release --android-skip-build-dependency-validation
  ```
  Sao chép các file APK vào `release-apk/`:
  - `release-apk/hi-chinese-v1.0.16-arm64-v8a.apk`
  - `release-apk/hi-chinese-v1.0.16-armeabi-v7a.apk`
  - `release-apk/app-release.apk`

- [ ] **Step 4: Cập nhật README.md & Tạo báo cáo QA**
  - Cập nhật mục "Điểm mới ở bản v1.0.16" và các link tải APK trong `README.md`.
  - Tạo báo cáo nghiệm thu `audit/GAMIFIED_LEARNING_AND_PROGRESS_QA_REPORT.md`.

- [ ] **Step 5: Commit, Tag `v1.0.16` và Đẩy lên GitHub**
  ```bash
  git add .
  git commit -m "chore(release): bump version to v1.0.16+16 and release gamified learning update"
  git tag -a v1.0.16 -m "Release v1.0.16: Gamified Micro-Learning Experience and Instant Progress Sync"
  git push origin main
  git push origin v1.0.16
  ```
