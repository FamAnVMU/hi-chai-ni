# Task 1 Brief: Khắc Phục Vòng Đời Flow State & AppBar Trong LessonStudyScreen

**Files:**
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_study_lifecycle_test.dart`

**Exact Requirements:**
1. **Flow Reset**: Trong `initState()` của `_LessonStudyScreenState`:
   ```dart
   @override
   void initState() {
     super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
         final targetStep = widget.resumeStep ?? LessonStep.warmup;
         ref.read(lessonFlowNotifierProvider(widget.lesson.id).notifier).resetToStep(targetStep);
       }
     });
   }
   ```
2. **Safe Clamping**: Trong `build()`:
   `final safeIndex = currentIndex.clamp(0, _stepTitles.length - 1);`
   Thay thế mọi chỗ dùng `currentIndex` để truy xuất `_stepTitles` và tính toán tiến độ bằng `safeIndex`.
3. **AppBar Contrast & Text Color**:
   - Tiêu đề: `Text(widget.lesson.titleVi, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryText))`
   - Phụ đề: `Text('${_stepTitles[safeIndex]} (${safeIndex + 1}/6)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))`
   - `LinearProgressIndicator`: `value: (safeIndex + 1) / 6`
4. **Test Driven Development**:
   Tạo `test/features/curriculum/lesson_study_lifecycle_test.dart`:
   - Test 1: Khởi tạo với notifier đang ở Step 5 (`masteryCheck`), mở `LessonStudyScreen` (không có resumeStep) -> xác nhận sau post frame callback màn hình hiển thị Step 0 (`Khởi động`).
   - Test 2: AppBar hiển thị rõ ràng titleVi và tiến độ `(1/6)`.
   - Test 3: Clamping an toàn với index bất kỳ.
5. Chạy `flutter test test/features/curriculum/lesson_study_lifecycle_test.dart` đạt 100% PASS.
6. Commit với message: `fix(curriculum): enforce warmup step reset and safe bounds in lesson study screen`.
