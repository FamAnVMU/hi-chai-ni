# Kế Hoạch Sửa Lỗi Triệt Để: Màn Hình Bài Học Không Hiển Thị (Lesson Study Blank Screen Fix)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để và toàn diện lỗi màn hình bài học trắng tinh / không hiển thị nội dung khi bấm "Bắt đầu" bài học từ lộ trình hoặc trang chủ, đảm bảo tự phục hồi dữ liệu học liệu (Self-Healing Ingestion), chống kẹt step, hiển thị rõ ràng trên mọi thiết bị và phát hành bản build APK v1.0.15.

**Architecture:** 
1. **Flow Lifecycle & State Guard**: Đảm bảo `LessonStudyScreen` luôn khởi tạo từ `LessonStep.warmup` (index 0) trừ khi người dùng chủ động chọn tiếp tục bài dở, đồng thời kẹp chặt index `currentIndex.clamp(0, 5)`.
2. **Reactive Data & Self-Healing**: Thay vì chỉ nhận `CurriculumLesson` tĩnh qua constructor, `LessonStudyScreen` lắng nghe `lessonDetailProvider(lessonId)` phản ứng trực tiếp với SQLite; nếu phát hiện bài học thiếu segment/học liệu, tự động kích hoạt nạp lại gói bundled tương ứng.
3. **Database Integrity & Ingestion Guard**: Sửa `_checkPackNeedsImport` trong `AppStartupNotifier` để kiểm tra cả số lượng segments và content items thay vì chỉ đếm số bài học; tối ưu SQL LEFT JOIN case-insensitive & trim.
4. **Resilient UI & Error Boundary**: Bọc `_buildCurrentStep` bằng Error Boundary UI có nút hành động thử lại thay vì để Flutter giải phóng thành `SizedBox.shrink()` trong Release mode.
5. **Release & Deployment Automation**: Kiểm thử toàn bộ suites, cập nhật README, build split-ABI release APK và tạo GitHub Release v1.0.15.

**Tech Stack:** Flutter, Dart 3.x, Flutter Riverpod, SQLite (sqflite / sqflite_common_ffi), Material 3.

**Spec:** Phân tích nguyên nhân gốc rễ và video thực tế từ người dùng (`media_1793960249487_1d13d864.mp4`).

---

## Global Constraints

- **Offline-First SQLite**: Toàn bộ dữ liệu bài học và trạng thái tiến độ người dùng lưu trữ cục bộ, không làm mất chuỗi ngày streak hay lịch sử ôn tập SRS.
- **Clean Architecture & Design Tokens**: Sử dụng chuẩn `AppColors`, `AppTypography`, `AppSpacing`, `HiCard`, `HiButton`.
- **Zero Progress Loss**: Cập nhật dữ liệu học liệu bảo toàn 100% dữ liệu bảng `curriculum_mastery`, `srs_items`, `learner_evidence`.
- **Release Automation**: Tự động build Split APKs (`arm64-v8a`, `armeabi-v7a`), cập nhật README.md và đẩy tag GitHub.

---

## Review Focus

1. **Stale Flow State**: Người dùng từng mở hoặc hoàn thành bài học trước đó khiến notifier kẹt ở Step 5 (`masteryCheck`), mở lại bài học phải về Step 0 (`warmup`).
2. **Empty Segments / Missing Content Items**: Thiết bị đã cài bản cũ có bảng `tableCurriculumLessons` nhưng thiếu `lesson_segments` hoặc `content_items` do startup bỏ qua nạp lại.
3. **Release Mode Silent Crash**: Lỗi ép kiểu `Map<dynamic, dynamic>` hoặc null property trong các View khiến `build()` trả về `SizedBox.shrink()` trong release mode.
4. **Contrast & Theme Visibility**: Tiêu đề AppBar và thanh tiến độ LinearProgressIndicator phải hiển thị sắc nét với độ tương phản WCAG 4.5:1.
5. **No Network / Offline Availability**: Tự phục hồi dữ liệu từ bundled assets mà không cần kết nối mạng.

---

## Tasks

### Task 1: Khắc Phục Vòng Đời Flow State & AppBar Trong `LessonStudyScreen`

**Files:**
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_study_lifecycle_test.dart`

**Interfaces:**
- Consumes: `lessonFlowNotifierProvider(lessonId)`
- Produces: `LessonStudyScreen` luôn khởi tạo bài học ở `LessonStep.warmup` khi `resumeStep == null`, kẹp bounds index `0..5`, và render AppBar với màu chữ rõ ràng.

- [ ] **Step 1: Viết failing test kiểm tra vòng đời mở bài học**
  Tạo `test/features/curriculum/lesson_study_lifecycle_test.dart` kiểm tra:
  - Khi mở `LessonStudyScreen(lesson: lesson)` (không truyền `resumeStep`), màn hình LUÔN bắt đầu ở Step 0 (`Khởi động`), ngay cả khi trước đó notifier đang ở Step 5 (`masteryCheck`).
  - Tiêu đề AppBar hiển thị rõ chữ và tiến độ `(1/6)`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Chạy: `flutter test test/features/curriculum/lesson_study_lifecycle_test.dart`
  Kết quả mong đợi: FAIL nếu notifier giữ trạng thái cũ.

- [ ] **Step 3: Cập nhật `LessonStudyScreen`**
  - Trong `initState()`:
    ```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final targetStep = widget.resumeStep ?? LessonStep.warmup;
        ref.read(lessonFlowNotifierProvider(widget.lesson.id).notifier).resetToStep(targetStep);
      }
    });
    ```
  - Trong `build()`:
    - Kẹp index: `final safeIndex = currentIndex.clamp(0, _stepTitles.length - 1);`
    - Cập nhật AppBar:
      - Tiêu đề: `Text(widget.lesson.titleVi, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryText))`
      - Phụ đề: `Text('${_stepTitles[safeIndex]} (${safeIndex + 1}/6)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))`
      - `LinearProgressIndicator` với `value: (safeIndex + 1) / 6`.

- [ ] **Step 4: Chạy lại test để xác nhận pass**
  Chạy: `flutter test test/features/curriculum/lesson_study_lifecycle_test.dart`
  Kết quả: PASS.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/screens/lesson_study_screen.dart test/features/curriculum/lesson_study_lifecycle_test.dart
  git commit -m "fix(curriculum): enforce warmup step reset and safe bounds in lesson study screen"
  ```

---

### Task 2: Xây Dựng `lessonDetailProvider` Phản Ứng & Cơ Chế Tự Phục Hồi (Self-Healing)

**Files:**
- Modify: `lib/features/curriculum/presentation/providers/curriculum_providers.dart`
- Modify: `lib/features/curriculum/data/curriculum_repository.dart`
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_detail_reactive_test.dart`

**Interfaces:**
- Consumes: `CurriculumRepository.getLessonById(lessonId)`
- Produces: `lessonDetailProvider(lessonId)` trả về `AsyncValue<CurriculumLesson?>`, tự động nạp học liệu nếu lesson truyền vào thiếu segment.

- [ ] **Step 1: Viết test cho `lessonDetailProvider` và cơ chế nạp bổ sung**
  Viết `test/features/curriculum/lesson_detail_reactive_test.dart` mô phỏng việc truyền lesson có 0 segments, provider sẽ truy vấn database để lấy lesson đầy đủ segments.

- [ ] **Step 2: Chạy test xác nhận fail**
  Chạy: `flutter test test/features/curriculum/lesson_detail_reactive_test.dart`

- [ ] **Step 3: Cài đặt `lessonDetailProvider` và tích hợp vào `LessonStudyScreen`**
  - Thêm vào `curriculum_providers.dart`:
    ```dart
    final lessonDetailProvider = FutureProvider.family<CurriculumLesson?, String>((ref, lessonId) async {
      final repo = ref.watch(curriculumRepositoryProvider);
      return repo.getLessonById(lessonId);
    });
    ```
  - Trong `LessonStudyScreen`:
    - Lắng nghe `final reactiveLessonAsync = ref.watch(lessonDetailProvider(widget.lesson.id));`
    - Sử dụng `final currentLesson = reactiveLessonAsync.value ?? widget.lesson;`
    - Cập nhật các view con sử dụng `currentLesson` với segments mới nhất từ database.

- [ ] **Step 4: Chạy test xác nhận pass**
  Chạy: `flutter test test/features/curriculum/lesson_detail_reactive_test.dart`

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/providers/curriculum_providers.dart lib/features/curriculum/presentation/screens/lesson_study_screen.dart test/features/curriculum/lesson_detail_reactive_test.dart
  git commit -m "feat(curriculum): add reactive lessonDetailProvider with live segment reloading"
  ```

---

### Task 3: Nâng Cấp Kiểm Tra Toàn Vẹn & Tự Nạp Lại Khi Nâng Cấp Ứng Dụng

**Files:**
- Modify: `lib/core/startup/app_startup_provider.dart`
- Modify: `lib/core/database/dao/curriculum_dao.dart`
- Modify: `lib/features/content_packs/data/content_pack_manager.dart`
- Test: `test/features/content_packs/pack_upgrade_integrity_test.dart`

**Interfaces:**
- Consumes: `Database`, `MandatoryPackInfo`
- Produces: `_checkPackNeedsImport` kiểm tra cả `tableLessonSegments` và `tableContentItems`, tự động sửa chữa nếu phát hiện dữ liệu học liệu bị trống.

- [ ] **Step 1: Viết test kịch bản nâng cấp ứng dụng bị thiếu segments**
  Viết `test/features/content_packs/pack_upgrade_integrity_test.dart`:
  - Giả lập database có sẵn 15 lessons HSK 1 nhưng có 0 segments (do lỗi nạp từ phiên bản cũ).
  - Verify rằng `_checkPackNeedsImport` trả về `true` và kích hoạt nạp lại đầy đủ 90 segments.

- [ ] **Step 2: Chạy test xác nhận fail**
  Chạy: `flutter test test/features/content_packs/pack_upgrade_integrity_test.dart`

- [ ] **Step 3: Cải tiến `_checkPackNeedsImport` và `CurriculumDao`**
  - Trong `app_startup_provider.dart`:
    ```dart
    final segmentsRes = await db.rawQuery('''
      SELECT COUNT(*) as cnt 
      FROM ${DatabaseConstants.tableLessonSegments} 
      WHERE lesson_id IN (
        SELECT l.id FROM ${DatabaseConstants.tableCurriculumLessons} l
        INNER JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
        WHERE u.curriculum_id = ?
      )
    ''', [pack.curriculumId]);
    final segmentCount = Sqflite.firstIntValue(segmentsRes) ?? 0;
    if (segmentCount == 0) return true;
    ```
  - Trong `CurriculumDao.getSegmentsByLessonId`:
    Sử dụng so khớp linh hoạt không phân biệt chữ hoa/thường:
    ```sql
    SELECT ls.*, ci.content_json AS content_payload
    FROM lesson_segments ls
    LEFT JOIN content_items ci ON UPPER(TRIM(ls.content_ref_id)) = UPPER(TRIM(ci.content_id))
    WHERE ls.lesson_id = ?
    ORDER BY ls.step_order ASC
    ```

- [ ] **Step 4: Chạy test xác nhận pass**
  Chạy: `flutter test test/features/content_packs/pack_upgrade_integrity_test.dart`

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/startup/app_startup_provider.dart lib/core/database/dao/curriculum_dao.dart test/features/content_packs/pack_upgrade_integrity_test.dart
  git commit -m "fix(startup): ensure full segment and content item integrity check on app upgrade"
  ```

---

### Task 4: Bọc Error Boundary & Chống Lỗi Giao Diện Trắng (Fail-Safe UI)

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart`
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_step_error_boundary_test.dart`

**Interfaces:**
- Consumes: Widget con của từng step
- Produces: Giao diện bọc an toàn hiển thị thẻ thông báo thân thiện và nút "Bỏ qua bước này" hoặc "Thử lại" nếu widget con gặp lỗi ngoại lệ.

- [ ] **Step 1: Viết test cho `LessonStepErrorBoundary`**
  Viết `test/features/curriculum/lesson_step_error_boundary_test.dart`:
  - Khi widget con ném exception, màn hình không crash, không hiển thị khoảng trắng `SizedBox.shrink()`, mà hiển thị thông báo lỗi và nút "Tiếp tục".

- [ ] **Step 2: Chạy test xác nhận fail**
  Chạy: `flutter test test/features/curriculum/lesson_step_error_boundary_test.dart`

- [ ] **Step 3: Tạo `LessonStepErrorBoundary` và tích hợp vào `LessonStudyScreen`**
  - Tạo `lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart`.
  - Trong `LessonStudyScreen._buildCurrentStep`:
    Bọc giá trị trả về của từng step với `LessonStepErrorBoundary`.

- [ ] **Step 4: Chạy test xác nhận pass**
  Chạy: `flutter test test/features/curriculum/lesson_step_error_boundary_test.dart`

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart lib/features/curriculum/presentation/screens/lesson_study_screen.dart test/features/curriculum/lesson_step_error_boundary_test.dart
  git commit -m "feat(curriculum): add fail-safe error boundary for lesson study steps"
  ```

---

### Task 5: Kiểm Thử E2E Toàn Diện, Build Release APKs & Đẩy GitHub Release v1.0.15

**Files:**
- Modify: `pubspec.yaml`
- Modify: `README.md`
- Create: `audit/LESSON_BLANK_FIX_FINAL_REPORT.md`
- Build: `release-apk/hi-chinese-v1.0.15-arm64-v8a.apk`, `release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk`, `release-apk/app-release.apk`

- [ ] **Step 1: Chạy toàn bộ test suites của ứng dụng**
  ```bash
  flutter test test/features/curriculum/
  flutter test test/features/content_packs/
  flutter test test/features/onboarding/
  flutter test
  ```
  Xác nhận 100% tests pass.

- [ ] **Step 2: Nâng version ứng dụng lên v1.0.15+15**
  Cập nhật `pubspec.yaml` lên `version: 1.0.15+15`.

- [ ] **Step 3: Build APK split-per-abi Release**
  ```bash
  flutter clean
  flutter build apk --split-per-abi --release --android-skip-build-dependency-validation
  ```
  Sao chép và đổi tên các file APK vào `release-apk/`:
  - `release-apk/hi-chinese-v1.0.15-arm64-v8a.apk`
  - `release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk`
  - `release-apk/app-release.apk`

- [ ] **Step 4: Cập nhật README.md & Tạo báo cáo QA**
  Cập nhật link tải APK và mục "Điểm mới ở bản v1.0.15" trong `README.md`.
  Tạo báo cáo `audit/LESSON_BLANK_FIX_FINAL_REPORT.md`.

- [ ] **Step 5: Commit, Tag `v1.0.15` và Push GitHub Release**
  ```bash
  git add .
  git commit -m "chore(release): bump version to v1.0.15+15 and release fixed APKs"
  git tag -a v1.0.15 -m "Release v1.0.15: Hotfix for blank lesson study screen and enhanced content recovery"
  git push origin main
  git push origin v1.0.15
  ```
