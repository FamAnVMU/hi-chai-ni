# Báo Cáo Task 4: Bọc Error Boundary & Chống Lỗi Giao Diện Trắng (Fail-Safe UI)

## 1. Thông Tin Chung
- **Task**: Task 4 - Bọc Error Boundary & Chống Lỗi Giao Diện Trắng (Fail-Safe UI)
- **Trạng thái**: Hoàn thành xuất sắc (Completed)
- **Git Commit**: `3d97994`
- **Commit Message**: `feat(curriculum): add fail-safe error boundary for lesson study steps`

---

## 2. Bối Cảnh & Vấn Đề Giải Quyết
Trong Flutter ở chế độ Release, khi xảy ra ngoại lệ không được bắt (unhandled exception) trong quá trình `build()` của widget, cơ chế mặc định `ErrorWidget.builder` của Flutter trả về `SizedBox.shrink()`. Điều này khiến toàn bộ màn hình trở thành một vùng màu trắng hoàn toàn trống rỗng, người học không biết chuyện gì đã xảy ra, không thể tương tác hay nhấn nút để tiếp tục học các bước tiếp theo.

Task 4 triển khai một cơ chế Error Boundary chuyên dụng cho học liệu bài học (`LessonStepErrorBoundary`), bắt trọn vẹn mọi ngoại lệ dựng giao diện hoặc lỗi phân tích dữ liệu, hiển thị giao diện thông báo lỗi trang nhã theo chuẩn Clean Modern White & Light Blue, đồng thời cung cấp nút "Bỏ qua bước này" để người học không bao giờ bị kẹt lại trên màn hình trắng.

---

## 3. Các Tệp Tin Đã Tạo Mới & Chỉnh Sửa

### 3.1. Created: `lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart`
- **Widget `LessonStepErrorBoundary`**:
  - Hỗ trợ cả 2 tham số `child` và `builder: WidgetBuilder?` linh hoạt (có assert `child != null || builder != null`).
  - Trong phương thức `build()`, thực thi `widget.builder!(context)` hoặc trả về `child` được bọc an toàn trong khối `try-catch`. Bất kỳ lỗi parse dữ liệu, lỗi ép kiểu JSON, hay lỗi khởi tạo view nào đều được bắt gọn và chuyển hướng sang giao diện dự phòng (Fallback UI).
  - Quản lý trạng thái lỗi qua `_caughtError`:
    - Khi người học nhấn "Thử lại", `_handleRetry()` xóa trạng thái lỗi (`setState(() => _caughtError = null)`) và gọi callback `onRetry` để kích hoạt dựng lại dữ liệu.
    - Trong `didUpdateWidget`, tự động reset lỗi khi bước học thay đổi (`oldWidget.stepName != widget.stepName`).
  - **Giao diện Fallback thân thiện (`_LessonStepErrorFallback`)**:
    - Tuân thủ thiết kế Clean Modern White & Light Blue tokens (`HiCard`, `HiButton`, `AppColors`, `AppSpacing`).
    - Biểu tượng học tập `Icons.school_outlined` trong nền tròn xanh nhạt `AppColors.primaryBlueLight`.
    - Tiêu đề rõ ràng: `"Bước này gặp gián đoạn dữ liệu học liệu"`.
    - Phụ đề thông tin: `"Nội dung bước $stepName đang được đồng bộ hoặc gặp lỗi hiển thị."`.
    - Nút "Thử lại" (`HiButtonVariant.secondary`) gọi `onRetry`.
    - Nút "Bỏ qua bước này" (`HiButtonVariant.primary`) gọi `onSkip`.
  - **Hỗ trợ Static Helper**:
    - `buildErrorFallback`: Cho phép render trực tiếp giao diện dự phòng bất kỳ lúc nào.
    - `createErrorWidgetBuilder`: Tạo hàm callback chuẩn cho `ErrorWidget.builder` toàn cục, đảm bảo ngay cả khi có widget cấp dưới ném lỗi trong element tree, ứng dụng không bao giờ bị rơi vào màn hình trắng.

### 3.2. Modified: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Tách việc khởi tạo widget của các chặng sư phạm thành `_buildStepContent(index, flowNotifier, currentLesson)`.
- Cập nhật phương thức `_buildCurrentStep(safeIndex, flowNotifier, currentLesson)`:
  - Bọc view của chặng hiện tại trong `LessonStepErrorBoundary`:
    ```dart
    return LessonStepErrorBoundary(
      stepName: _stepTitles[safeIndex],
      onSkip: safeIndex < 5 ? () => flowNotifier.nextStep() : () => Navigator.of(context).pop(true),
      onRetry: () => setState(() {}),
      child: stepWidget,
      builder: (ctx) => _buildStepContent(safeIndex, flowNotifier, currentLesson),
    );
    ```
  - `onSkip`: Cho phép chuyển sang bước tiếp theo (`safeIndex < 5`), hoặc đóng màn hình trở về giáo trình nếu đang ở bước cuối (`safeIndex == 5`), đảm bảo luồng học tập thông suốt.
  - `onRetry`: Kích hoạt `setState(() {})` trên `LessonStudyScreen` để nạp lại dữ liệu.

### 3.3. Created: `test/features/curriculum/lesson_step_error_boundary_test.dart`
Bao gồm bộ kiểm thử toàn diện 6 ca kiểm thử:
1. **Test 1**: Khi child dựng bình thường, nội dung child được hiển thị chính xác, không hiển thị giao diện báo lỗi.
2. **Test 2**: Khi builder ném ngoại lệ (Exception), `LessonStepErrorBoundary` bắt lỗi an toàn, hiển thị giao diện dự phòng chứa đúng tên bước học (`stepName`) và không làm sập ứng dụng/test harness.
3. **Test 3**: Nhấn nút "Bỏ qua bước này" kích hoạt callback `onSkip` chính xác.
4. **Test 4**: Nhấn nút "Thử lại" kích hoạt callback `onRetry` chính xác.
5. **Test 5**: Kiểm tra cơ chế tự phục hồi: Sau khi nhấn "Thử lại" và builder thành công, giao diện tự động khôi phục hiển thị nội dung bài học và ẩn card báo lỗi.
6. **Test 6**: Các hàm helper `buildErrorFallback` và `createErrorWidgetBuilder` hoạt động đúng tiêu chuẩn.

---

## 4. Kết Quả Kiểm Thử & Xác Minh

### 4.1. Unit Test Mới (`lesson_step_error_boundary_test.dart`)
```
00:01 +6: All tests passed!
```
Tất cả 6/6 tests đều vượt qua hoàn hảo.

### 4.2. Regression Test Suites
1. **`test/features/curriculum/lesson_study_lifecycle_test.dart`**:
   ```
   00:01 +4: All tests passed!
   ```
2. **`test/features/curriculum/lesson_detail_reactive_test.dart`**:
   ```
   00:01 +2: All tests passed!
   ```
3. **`test/features/curriculum/lesson_study_empty_boundary_test.dart`**:
   ```
   00:02 +7: All tests passed!
   ```

### 4.3. Phân Tích Mã Nguồn (`flutter analyze`)
```bash
flutter analyze lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart lib/features/curriculum/presentation/screens/lesson_study_screen.dart test/features/curriculum/lesson_step_error_boundary_test.dart
```
Kết quả:
```
No issues found! (ran in 56.6s)
```

---

## 5. Kết Luận
Task 4 đã hoàn thành toàn bộ mục tiêu đề ra theo đúng kiến trúc Clean Modern:
- Loại bỏ hoàn toàn rủi ro người học gặp màn hình trắng vô vọng khi dữ liệu bước học gặp lỗi.
- Đảm bảo người học luôn có thể bấm "Bỏ qua bước này" hoặc "Thử lại".
- Không phát sinh lỗi hồi quy trên bất kỳ luồng nào của `LessonStudyScreen`.
