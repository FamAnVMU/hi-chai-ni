# Task 1 Report: Khắc Phục Vòng Đời Flow State & AppBar Trong LessonStudyScreen

## 1. Executive Summary
- **Status**: Completed (100% PASS)
- **Commit**: `71cf981` (`fix(curriculum): enforce warmup step reset and safe bounds in lesson study screen`)
- **Modified File**: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- **Test File**: `test/features/curriculum/lesson_study_lifecycle_test.dart`

---

## 2. Problem & Root Cause Analysis
1. **Flow State Retention Across Sessions**:
   - Khi người học mở một bài học trước đó từng làm dở hoặc hoàn thành (ví dụ dừng ở bước 5 - `masteryCheck`), `_LessonStudyScreenState.initState` trước đây chỉ thực hiện `resetToStep` nếu `widget.resumeStep != null`.
   - Khi người học nhấn "Bắt đầu" từ syllabus/home (không có `resumeStep`), provider flow `lessonFlowNotifierProvider(lesson.id)` không được reset về `warmup`, dẫn đến việc màn hình nhảy thẳng vào bước cuối (`masteryCheck`), gây hoang mang hoặc màn hình trắng nếu segment tương ứng thiếu dữ liệu.
2. **Unclamped Index Risk**:
   - `currentIndex` lấy từ `flowState.currentStep.index` có nguy cơ out-of-bounds (hoặc giá trị âm / lớn hơn 5) khi state provider chưa sẵn sàng, gây lỗi truy xuất mảng `_stepTitles` hoặc hiển thị trắng do `_buildCurrentStep` rơi vào nhánh default `SizedBox.shrink()`.
3. **AppBar Text Contrast Issue**:
   - Tiêu đề AppBar không gán màu chữ cụ thể, phụ đề và thanh tiến độ phụ thuộc vào `currentIndex` không được kẹp giới hạn, dẫn đến việc chữ mờ/khó đọc trong một số cấu hình theme và tính toán tiến độ không an toàn.

---

## 3. TDD Execution
- **Red Phase (Failing Tests)**:
  - Khởi tạo test suite `test/features/curriculum/lesson_study_lifecycle_test.dart` với 4 test cases.
  - Chạy `flutter test test/features/curriculum/lesson_study_lifecycle_test.dart` và ghi nhận 2 thất bại đúng như dự kiến:
    1. *Test 1 (Flow Reset)*: Nhận `Actual: LessonStep.masteryCheck` thay vì `LessonStep.warmup`.
    2. *Test 2 (AppBar Contrast)*: Nhận `Actual: <null>` thay vì `AppColors.primaryText`.
- **Green Phase (Implementation)**:
  - Đã cập nhật `_LessonStudyScreenState` trong `lesson_study_screen.dart`:
    1. Trong `initState`: Lập lịch `addPostFrameCallback` luôn reset flow state về `widget.resumeStep ?? LessonStep.warmup`.
    2. Trong `build`: Khai báo `final safeIndex = currentIndex.clamp(0, _stepTitles.length - 1);`.
    3. Áp dụng `safeIndex` cho mọi vị trí: truy xuất `_stepTitles[safeIndex]`, thanh tiến độ `(safeIndex + 1) / 6`, widget con `_buildCurrentStep(safeIndex, flowNotifier)`, và các nút điều hướng/step dots ở thanh dưới.
    4. Chuẩn hóa TextStyle AppBar: Tiêu đề dùng `theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryText)`, phụ đề dùng `TextStyle(fontSize: 12, color: AppColors.secondaryText)`.
  - Chạy lại test suite: 4/4 test cases đạt **100% PASS**.

---

## 4. Verification Output
```
00:00 +0: loading test/features/curriculum/lesson_study_lifecycle_test.dart
00:00 +0: LessonStudyScreen Lifecycle & AppBar Tests Test 1: Khởi tạo với notifier đang ở Step 5 (masteryCheck), mở LessonStudyScreen (không resumeStep) -> reset về Step 0 (Khởi động)
00:00 +1: LessonStudyScreen Lifecycle & AppBar Tests Test 2: AppBar hiển thị rõ ràng titleVi và tiến độ (1/6)
00:01 +2: LessonStudyScreen Lifecycle & AppBar Tests Test 3: Clamping an toàn với index bất kỳ
00:01 +3: LessonStudyScreen Lifecycle & AppBar Tests Test bổ sung: Nếu truyền resumeStep cụ thể thì tôn trọng resumeStep đó
00:01 +4: All tests passed!
```

---

## 5. Git Commit Details
- Staged and committed:
  - `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
  - `test/features/curriculum/lesson_study_lifecycle_test.dart`
- Commit SHA: `71cf981`
- Commit Message: `fix(curriculum): enforce warmup step reset and safe bounds in lesson study screen`
