# BỘ PROMPT NÂNG CẤP TRẢI NGHIỆM HỌC TƯƠNG TÁC VI MÔ (GAMIFIED MICRO-LEARNING) & VÁ LỖI LƯU TIẾN ĐỘ HỌC TẬP (v1.0.16)

> **Mã dự án:** `HI-CHINESE-v1.0.16`  
> **Kiến trúc áp dụng:** Clean Architecture, Offline-First SQLite (Schema v20), Riverpod State Management, Material 3 Design Tokens.  
> **Nguyên tắc xuyên suốt:** Zero Progress Loss, No Heart Penalty, Instant Feedback Loop, Anti-Hallucination.

---

## MỤC LỤC & PHÂN CHIA THREAD

| Thread | Tên Nhiệm Vụ | Trọng Tâm Kỹ Thuật |
| :---: | :--- | :--- |
| **THREAD 1** | **Core Data Pipeline, Activity Logging & Progress Sync** | Sửa `LearningPipelineCoordinator`, `LessonFlowNotifier`, lưu `learning_activities` chuẩn Schema v20, mở khóa bài mới, và invalidate Riverpod providers. |
| **THREAD 2** | **Gamified Interactive Micro-Widgets** | Xây dựng bộ tương tác: `InteractiveWordTileBuilder` (ghép câu chip từ), `InteractiveMatchingPairs` (ghép cặp từ), `InteractiveAudioChoice` (nghe chọn chữ Hán). |
| **THREAD 3** | **Quick Notes Sheet & Celebratory Milestone View** | Xây dựng `LessonQuickNotesSheet` (cẩm nang tra cứu tóm tắt) và `LessonCelebrationView` (màn hình chiến thắng +25 XP, Streak 🔥, mở khóa bài). |
| **THREAD 4** | **Gamified Lesson Player & Data Adapter Integration** | Xây dựng `LessonMicroCardAdapter` (chuyển đổi bài học thành 15–18 thẻ vi mô) và tích hợp `GamifiedLessonPlayer` vào `LessonStudyScreen`. |
| **THREAD 5** | **QA Integration, Release APK Build & GitHub Release v1.0.16** | Chạy toàn bộ test suites, kiểm tra `flutter analyze` 0 issues, build Split APKs, cập nhật `README.md` và phát hành tag `v1.0.16`. |

---

## 1. PROMPT THREAD 1: CORE DATA PIPELINE, ACTIVITY LOGGING & PROGRESS SYNC

```markdown
# THREAD 1 – CORE DATA PIPELINE, ACTIVITY LOGGING & PROGRESS SYNC
VAI TRÒ: Senior Database & Backend Architecture Lead (Thread 1)
PHỐI HỢP: Thread 4 (Integration), Thread 5 (QA)

BỐI CẢNH & NGUYÊN NHÂN GỐC RỄ:
Hiện tại khi người học hoàn thành bài học:
1. `LearningPipelineCoordinator.recordLessonCompletion` chỉ cập nhật `curriculum_lessons` và `curriculum_mastery` nhưng KHÔNG insert vào `tableLearningActivities` (nguồn chính mà `HomeRepository` dùng để tính streak hàng ngày và hiển thị hoạt động gần đây).
2. Trong `LessonFlowNotifier.completeLesson`, nếu người học học tự học mà không có bài kiểm tra trắc nghiệm độc lập (`userAnswers.isEmpty`), code tự gán `candidateScore = 0.0`, khiến bài học bị chấm là 'failed', không mở khóa bài học kế tiếp.
3. Khi đóng `LessonStudyScreen` trở về Lộ trình (`CurriculumSyllabusScreen`) và Trang chủ (`HomeScreen`), các provider Riverpod không được invalidate, khiến giao diện giữ nguyên trạng thái cũ (chưa xong, bài sau vẫn khóa, streak chưa tăng).

NHIỆM VỤ CHI TIẾT:
1. Sửa `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`:
   - Trong phương thức `recordLessonCompletion(DatabaseExecutor txn)`:
     Thêm lệnh ghi nhận phiên học vào `tableLearningActivities` tuân thủ nghiêm ngặt Schema v20:
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
   - Đảm bảo transaction ghi nhận đồng thời cả 4 bảng: `curriculum_lessons`, `curriculum_mastery`, `lesson_progress`, `learning_activities`.

2. Sửa `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart`:
   - Trong `LessonFlowNotifier.completeLesson({double defaultScorePercent = 0.85})`:
     Sửa logic tính điểm benchmark: Khi người học đã tham gia tương tác hoàn tất bài học, `candidateScore` luôn nhận tối thiểu `defaultScorePercent` (0.85) thay vì bị ép về 0.0 khi `state.userAnswers.isEmpty`. Đảm bảo `isPassed: true` và kích hoạt mở khóa bài tiếp theo.

3. Sửa `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart`:
   - Khi mở `LessonStudyScreen`:
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

4. Viết TDD Integration Test:
   - Tệp: `test/features/learning_pipeline/progress_sync_and_streak_test.dart`
   - Kịch bản 1: Hoàn thành bài học ghi nhận đúng 1 dòng trong `learning_activities` với ngày hôm nay.
   - Kịch bản 2: `HomeRepository.calculateStreak` và `HomeRepository.getDashboardData` ghi nhận streak >= 1 và `hasCompletedLessons == true`.
   - Kịch bản 3: Bài học kế tiếp tự động chuyển từ `is_locked = 1` sang `is_locked = 0`.

RÀNG BUỘC KỸ THUẬT:
- Tuân thủ triệt để Schema v20: Tuyệt đối không thêm trường không có trong schema (như `xp_earned` hay `score`) vào câu lệnh insert của `tableLearningActivities`.
- Bảo toàn 100% dữ liệu tiến độ SQLite cũ.

TIÊU CHÍ NGHIỆM THU:
- `flutter test test/features/learning_pipeline/progress_sync_and_streak_test.dart` -> 100% PASS.
- Commit: `fix(pipeline): record learning_activities on lesson completion and invalidate UI providers`.
```

---

## 2. PROMPT THREAD 2: GAMIFIED INTERACTIVE MICRO-WIDGETS

```markdown
# THREAD 2 – GAMIFIED INTERACTIVE MICRO-WIDGETS
VAI TRÒ: Senior Flutter UI/UX & Gamification Specialist (Thread 2)
PHỐI HỢP: Thread 3 (Celebration), Thread 4 (Player Integration)

BỐI CẢNH & MỤC TIÊU:
Thay thế các slide đọc văn bản thụ động bằng các widget tương tác vi mô (Learn-by-doing) lấy cảm hứng từ Duolingo & HelloChinese. Người học tương tác bằng thao tác chạm, kéo thả, nghe âm thanh và nhận phản hồi tức thì.

NHIỆM VỤ CHI TIẾT:
1. Xây dựng `InteractiveWordTileBuilder` (`lib/features/curriculum/presentation/widgets/interactive_word_tile_builder.dart`):
   - Đề bài: Một câu dịch hoặc ngữ cảnh (ví dụ: *"Tôi là học sinh"*).
   - Vùng trả lời (Target Area): Các dòng kẻ gạch đứt để chứa các chip từ được chọn.
   - Vùng từ vựng (Source Pool): Các chip từ tiếng Trung xáo trộn (ví dụ: `[我]`, `[是]`, `[学生]`, kèm các chip gây nhiễu `[不]`, `[老师]`).
   - Tương tác:
     - Chạm vào chip nguồn ➔ chip bay lên vùng trả lời.
     - Chạm vào chip trên vùng trả lời ➔ hoàn tác trả về pool nguồn.
   - Nút "Kiểm tra":
     - Nếu đúng: Viền xanh lá, âm thanh "Ting!" chúc mừng, rung nhẹ `HapticFeedback.lightImpact()`.
     - Nếu sai: Viền đỏ rung nhẹ, hiển thị đáp án đúng bên dưới để người học ghi nhớ, rung `HapticFeedback.mediumImpact()`.

2. Xây dựng `InteractiveMatchingPairs` (`lib/features/curriculum/presentation/widgets/interactive_matching_pairs.dart`):
   - Lưới gồm 4 chữ Hán và 4 nghĩa tiếng Việt xáo trộn.
   - Chạm vào 1 chữ Hán và 1 nghĩa tương ứng:
     - Nếu khớp: Cặp thẻ đổi màu xanh lá và biến mất (hoặc mờ đi).
     - Nếu sai: Thẻ rung nhẹ đổi màu đỏ rồi trở lại bình thường.
   - Khi ghép thành công cả 4 cặp: Kích hoạt callback `onCompleted()`.

3. Xây dựng `InteractiveAudioChoice` (`lib/features/curriculum/presentation/widgets/interactive_audio_choice.dart`):
   - Biểu tượng loa phát âm lớn màu xanh dương `AppColors.primaryBlueDark` ở trung tâm.
   - Danh sách 3–4 thẻ lựa chọn chữ Hán kèm Pinyin/nghĩa.
   - Chạm vào thẻ lựa chọn để kiểm tra ngay lập tức.

4. Viết Widget Tests:
   - Tệp: `test/features/curriculum/interactive_widgets_test.dart`
   - Test 1: `InteractiveWordTileBuilder` chọn chip, bỏ chọn, submit đúng/sai.
   - Test 2: `InteractiveMatchingPairs` triệt tiêu các cặp từ đúng, gọi `onCompleted` khi hết thẻ.
   - Test 3: `InteractiveAudioChoice` phản hồi đúng khi bấm chọn.

RÀNG BUỘC KỸ THUẬT:
- Dùng Clean Modern White & Light Blue tokens (`AppColors`, `AppSpacing`, `AppTypography`, `HiButton`, `HiCard`).
- Tokenization an toàn: Giữ nguyên từ ghép tiếng Trung (ví dụ `[学生]` là 1 chip, không tách thành `[学]` và `[生]`).
- Hiệu ứng âm thanh và haptic phải nhẹ nhàng, không gây ồn hay khó chịu.

TIÊU CHÍ NGHIỆM THU:
- `flutter test test/features/curriculum/interactive_widgets_test.dart` -> 100% PASS.
- Commit: `feat(curriculum): implement interactive word tile, matching pairs, and audio choice widgets`.
```

---

## 3. PROMPT THREAD 3: QUICK NOTES SHEET & CELEBRATORY MILESTONE VIEW

```markdown
# THREAD 3 – QUICK NOTES SHEET & CELEBRATORY MILESTONE VIEW
VAI TRÒ: Senior Mobile Product & Animation Designer (Thread 3)
PHỐI HỢP: Thread 2 (Widgets), Thread 4 (Player)

BỐI CẢNH & MỤC TIÊU:
1. **Cẩm nang bài học (Quick Notes)**: Cung cấp tài liệu tra cứu nhanh (từ mới, cấu trúc ngữ pháp, hội thoại mẫu) mở bằng nút 📖 trên AppBar để người học có thể xem trước hoặc tra cứu bất kỳ lúc nào mà không làm gián đoạn bài tập.
2. **Màn hình ăn mừng (Celebration Milestone)**: Khi hoàn thành bài học, người học được tưởng thưởng bằng hiệu ứng chiến thắng rực rỡ, hiển thị `+25 XP`, chuỗi Streak, tỷ lệ chính xác và thẻ xanh mở khóa bài mới.

NHIỆM VỤ CHI TIẾT:
1. Xây dựng `LessonQuickNotesSheet` (`lib/features/curriculum/presentation/widgets/lesson_quick_notes_sheet.dart`):
   - Mở dưới dạng `DraggableScrollableSheet` hoặc `ModalBottomSheet` bo góc 20px.
   - Header: Tiêu đề `"Cẩm nang bài học: ${lesson.titleVi}"` kèm nút đóng.
   - Thẻ Tab / Segmented Control gồm 3 mục:
     1. **Từ vựng trọng tâm**: Danh sách từ mới của bài (Hán tự to, Pinyin, nghĩa tiếng Việt, nút loa phát âm).
     2. **Bí kíp ngữ pháp**: Công thức rút gọn dễ nhớ (ví dụ: `A + 是 + B = A là B`), 1 ví dụ cụ thể có dịch nghĩa.
     3. **Hội thoại mẫu**: Toàn văn đoạn hội thoại tình huống dạng chat bubble.

2. Xây dựng `LessonCelebrationView` (`lib/features/curriculum/presentation/widgets/lesson_celebration_view.dart`):
   - Biểu tượng chúc mừng lớn `🎉` hoặc cup vàng nổi bật.
   - Tiêu đề: `"Chúc mừng bạn đã hoàn thành bài học!"`.
   - Khối chỉ số thành tích (2 cột):
     - Ô 1: `+25 XP` (Huy hiệu vàng ấm áp).
     - Ô 2: `🔥 Chuỗi Streak: X ngày liên tục` (Ngọn lửa cam rực rỡ).
   - Thẻ trạng thái mở khóa bài mới:
     - Khung màu xanh lá `AppColors.successContainerLight`: `"✓ Đã mở khóa: Bài tiếp theo"`.
   - Nút bấm chính: `HiButton` lớn màu xanh dương `"TIẾP TỤC HỌC ➔"`, kích hoạt callback `onContinue` để lưu tiến độ và chuyển bài.

3. Viết Unit & Widget Tests:
   - Tệp: `test/features/curriculum/lesson_celebration_and_quick_notes_test.dart`
   - Test 1: Mở `LessonQuickNotesSheet` hiển thị đầy đủ 3 phần từ vựng, ngữ pháp, hội thoại.
   - Test 2: `LessonCelebrationView` hiển thị đúng XP, streak và gọi `onContinue` khi nhấn nút tiếp tục.

RÀNG BUỘC KỸ THUẬT:
- Giao diện thân thiện, độ tương phản cao, tối ưu hiển thị mượt mà trên mọi kích thước màn hình Android.
- Không gây mất trạng thái của bài học khi mở/đóng Cẩm nang tra cứu.

TIÊU CHÍ NGHIỆM THU:
- `flutter test test/features/curriculum/lesson_celebration_and_quick_notes_test.dart` -> 100% PASS.
- Commit: `feat(curriculum): add lesson quick notes sheet and celebratory milestone view`.
```

---

## 4. PROMPT THREAD 4: GAMIFIED LESSON PLAYER & DATA ADAPTER INTEGRATION

```markdown
# THREAD 4 – GAMIFIED LESSON PLAYER & DATA ADAPTER INTEGRATION
VAI TRÒ: Senior Curriculum Engine & Screen Integration Lead (Thread 4)
PHỐI HỢP: Thread 1 (Data Sync), Thread 2 (Widgets), Thread 3 (Celebration)

BỐI CẢNH & MỤC TIÊU:
Thay thế hoàn toàn 6 màn hình tĩnh cũ trong `LessonStudyScreen` bằng Trình học tương tác vi mô `GamifiedLessonPlayer` theo **Phương án 1 (Hành trình học trọn vẹn 5–7 phút)**. Sử dụng `LessonMicroCardAdapter` để chuyển hóa tự động dữ liệu Content Pack có sẵn thành 15–18 thẻ vi mô.

NHIỆM VỤ CHI TIẾT:
1. Xây dựng `LessonMicroCardAdapter` (`lib/features/curriculum/domain/engine/lesson_micro_card_adapter.dart`):
   - Nhận vào `CurriculumLesson` (với các segment `warmup`, `vocabulary`, `grammar`, `dialogue`, `practice`).
   - Tự động sinh danh sách `List<MicroCardModel>` (tổng cộng 15–18 thẻ):
     - 4–5 thẻ Reveal từ mới (Hán tự + Pinyin + Audio + nghĩa).
     - 3–4 thẻ Audio Choice (Nghe phát âm chọn Hán tự).
     - 2–3 thẻ Sentence Builder (Ghép chip từ thành câu hội thoại/ngữ pháp).
     - 1–2 thẻ Matching Pairs (Ghép 4 cặp từ Hán - Việt).
     - 3–4 thẻ Mini Quiz trắc nghiệm nhanh từ segment practice.

2. Xây dựng `GamifiedLessonPlayer` (`lib/features/curriculum/presentation/widgets/gamified_lesson_player.dart`):
   - Quản lý hàng đợi thẻ: `activeDeck` và `retryQueue`.
   - Thanh tiến độ viên nang xanh lá trên cùng lấp đầy theo tỷ lệ thẻ hoàn thành.
   - Bộ đếm Combo: Hiển thị `🔥 Combo X` khi trả lời đúng liên tiếp; reset về 0 khi trả lời sai.
   - Hàng đợi làm lại (Retry Queue): Câu trả lời sai được đưa về cuối bài để làm lại cho đến khi thành thạo (No Heart Penalty).
   - Khi hoàn thành hết toàn bộ thẻ: Tự động chuyển sang `LessonCelebrationView`.

3. Tích hợp vào `LessonStudyScreen` (`lib/features/curriculum/presentation/screens/lesson_study_screen.dart`):
   - Thanh AppBar:
     - Nút đóng `✕` bên trái.
     - Thanh tiến độ viên nang ở giữa.
     - Nút icon 📖 mở `LessonQuickNotesSheet` bên phải.
   - Thân bài học: Hiển thị `GamifiedLessonPlayer` được bọc trong `LessonStepErrorBoundary`.
   - Khi hoàn thành bài học từ `LessonCelebrationView`:
     - Gọi `await ref.read(lessonFlowNotifierProvider(lesson.id).notifier).completeLesson()`.
     - Đóng màn hình trả về `Navigator.pop(context, true)`.

4. Viết TDD Integration Test:
   - Tệp: `test/features/curriculum/gamified_lesson_player_test.dart`
   - Test 1: Adapter sinh đủ 15–18 thẻ vi mô từ một bài học HSK chuẩn.
   - Test 2: Trả lời đúng tăng combo 🔥 và thanh tiến độ.
   - Test 3: Trả lời sai đưa thẻ vào retry queue và xuất hiện lại ở cuối.
   - Test 4: Hoàn thành bài học kích hoạt màn hình ăn mừng và gọi `completeLesson`.

RÀNG BUỘC KỸ THUẬT:
- Không gây lỗi lặp thẻ vô tận nếu người học làm sai nhiều lần.
- Đảm bảo tương thích ngược: Các bài học chưa có đủ 15 thẻ sẽ tự động co giãn số lượng thẻ linh hoạt mà không crash.

TIÊU CHÍ NGHIỆM THU:
- `flutter test test/features/curriculum/gamified_lesson_player_test.dart` -> 100% PASS.
- `flutter test test/features/curriculum/` -> Toàn bộ tests cũ và mới đều PASS.
- Commit: `feat(curriculum): integrate gamified micro-learning player into lesson study screen`.
```

---

## 5. PROMPT THREAD 5: QA INTEGRATION, RELEASE APK BUILD & GITHUB RELEASE v1.0.16

```markdown
# THREAD 5 – QA INTEGRATION, RELEASE APK BUILD & GITHUB RELEASE v1.0.16
VAI TRÒ: Lead QA & Release Manager (Thread 5)
PHỐI HỢP: Toàn bộ Thread 1, 2, 3, 4

NHIỆM VỤ CHI TIẾT:
1. Kiểm tra toàn diện chất lượng mã nguồn & Hồi quy:
   - Chạy toàn bộ các suites kiểm thử:
     ```bash
     flutter test test/features/learning_pipeline/
     flutter test test/features/curriculum/
     flutter test test/features/content_packs/
     flutter test test/features/onboarding/
     flutter test
     ```
   - Chạy phân tích mã nguồn tĩnh:
     ```bash
     flutter analyze lib/ test/
     ```
     Bắt buộc: 0 errors, 0 warnings.

2. Nâng phiên bản ứng dụng lên `v1.0.16+16`:
   - Tệp: `pubspec.yaml` -> `version: 1.0.16+16`.

3. Biên dịch bản phát hành Split APKs Release:
   ```bash
   flutter clean
   flutter build apk --split-per-abi --release --android-skip-build-dependency-validation
   ```
   - Đổi tên và sao chép các tệp đầu ra vào thư mục `release-apk/`:
     - `release-apk/hi-chinese-v1.0.16-arm64-v8a.apk` (ARM 64-bit)
     - `release-apk/hi-chinese-v1.0.16-armeabi-v7a.apk` (ARM 32-bit)
     - `release-apk/app-release.apk` (Bản release mặc định)
   - Kiểm tra dung lượng cài đặt: Đảm bảo không vượt quá 45MB mỗi bản.

4. Cập nhật `README.md` & Báo cáo QA:
   - Cập nhật bảng tải APK lên phiên bản v1.0.16.
   - Cập nhật mục "Điểm mới ở bản v1.0.16":
     - Trình học tương tác vi mô Gamified Micro-Learning chuẩn HelloChinese/Duolingo.
     - Cẩm nang tra cứu bài học nhanh (Quick Notes Sheet).
     - Khắc phục triệt để lỗi không lưu tiến độ học tập và chuỗi Streak.
     - Màn hình ăn mừng hoàn thành bài học (+25 XP, Streak 🔥, mở khóa bài mới).
   - Tạo báo cáo nghiệm thu: `audit/GAMIFIED_LEARNING_AND_PROGRESS_QA_REPORT.md`.

5. Git Commit, Tag & Xuất bản GitHub Release:
   ```bash
   git add .
   git commit -m "chore(release): bump version to v1.0.16+16 and release gamified learning update"
   git tag -a v1.0.16 -m "Release v1.0.16: Gamified Micro-Learning Experience and Instant Progress Sync"
   git push origin main
   git push origin v1.0.16
   ```

TIÊU CHÍ NGHIỆM THU:
- Bộ tệp APK v1.0.16 sẵn sàng trong `release-apk/`.
- Toàn bộ test suites đạt 100% PASS, `flutter analyze` 0 issues.
- GitHub Release tag `v1.0.16` được xuất bản thành công.
```
