# Task Report: TASK-002-ONBOARDING-WIZARD — Multi-Step Wizard Flow for Onboarding Personalization

- **Task ID**: `TASK-002-ONBOARDING-WIZARD`
- **Thread**: Thread 4 (Presentation Layer, Design System & Mobile UX)
- **Branch**: `feature/thread-4-ui`
- **Base Commit**: `89b1c54`
- **Date**: 2026-11-04

---

## 1. Vấn Đề Ban Đầu
- `OnboardingPersonalizationScreen` trước đây gộp toàn bộ 9 tùy chọn (mục tiêu, thời lượng, kỹ năng trọng điểm, phương pháp, nhắc nhở, pinyin, vị trí pinyin, giản/phồn thể, tốc độ phát âm) vào trong một `SingleChildScrollView` dài 543 dòng.
- Thiết kế cũ gây quá tải thông tin (cognitive overload) trên màn hình điện thoại 5-6 inch, người học phải cuộn trang liên tục và dễ nản lòng trước khi hoàn tất thiết lập.

---

## 2. Giải Pháp Triển Khai (Multi-Step Wizard Flow)
Tái cấu trúc `OnboardingPersonalizationScreen` thành quy trình 3 chặng mượt mà với `PageView` kết hợp thanh chỉ báo tiến trình phụ `Chặng 1/3`, `2/3`, `3/3`:

### 🎯 Chặng 1: Mục Tiêu & Thời Gian Cam Kết (Goals & Commitment)
- **Tiêu đề**: *"Thiết Lập Mục Tiêu Học Tập" - "Mục tiêu và thời gian học của bạn"*
- **Nội dung**:
  1. **Mục đích chính**: Luyện thi chứng chỉ HSK, Giao tiếp hàng ngày, Công việc & Thương mại, Du lịch & Văn hóa (kèm icon và thẻ chọn mềm mại).
  2. **Thời gian học mỗi ngày**: ChoiceChip (10, 15, 30, 45, 60 phút).
  3. **Kỹ năng ưu tiên**: Nghe hiểu, Nói / Phát âm, Đọc hiểu, Viết chữ Hán, Vốn từ vựng, Điểm ngữ pháp (tăng 40% tỷ trọng bài tập).
- **Điều hướng**: Nút *"Tiếp tục sang Chặng 2"* (chuyển sang bước tiếp theo với animation `easeInOutCubic`) và hỗ trợ *"Bắt đầu lộ trình ngay"* trực tiếp nếu người học muốn hoàn tất nhanh.

### 💡 Chặng 2: Phương Pháp & Thói Quen Học Tập (Method & Habit)
- **Tiêu đề**: *"Phương pháp và thói quen rèn luyện"*
- **Nội dung**:
  1. **Phương pháp học ưa thích**: Bài học theo ngữ cảnh, Ôn tập ngắt quãng (SRS SM-2), Đàm thoại với AI Tutor 1-1.
  2. **Nhắc nhở học tập hàng ngày**: Switch bật/tắt nhắc nhở + bộ chọn giờ học `showTimePicker` trực quan.
- **Điều hướng**: Nút *"Quay lại Chặng 1"* và *"Tiếp tục Chặng 3"*.

### 🇨🇳 Chặng 3: Trải Nghiệm Học & Hiển Thị (Display & Audio Preferences)
- **Tiêu đề**: *"Tùy chỉnh hiển thị và âm thanh"*
- **Nội dung**:
  1. **Pinyin & Phiên âm**: Switch bật/tắt + SegmentedButton vị trí (Trên chữ / Dưới chữ).
  2. **Bộ chữ Hán**: Giản thể (简体 - Đại lục & HSK) hoặc Phồn thể (繁體 - Đài Loan, HK).
  3. **Tốc độ đọc audio**: SegmentedButton (0.8x Chậm rõ, 1.0x Chuẩn, 1.2x Nhanh).
- **Điều hướng**: Nút *"Quay lại Chặng 2"* và nút *"Hoàn tất thiết lập & Vào học"* (Lưu `PersonalizationData` và kích hoạt khởi tạo Roadmap).

---

## 3. Cải Tiến Kỹ Thuật & Tương Thích UX
1. **Duy trì Data Contract & State**:
   - `PersonalizationData` được bảo toàn nguyên vẹn 100%, không làm ảnh hưởng đến `OnboardingNotifier` hay bảng `app_settings` trong SQLite.
2. **Android Back Navigation (PopScope)**:
   - Khi ấn phím Back phần cứng hoặc nút Back trên AppBar:
     - Nếu đang ở Chặng 2 hoặc Chặng 3: Lùi lại chặng trước đó mượt mà thay vì thoát app đột ngột.
     - Nếu đang ở Chặng 1: Gọi `widget.onBack?.call()` để quay lại bước Placement Test của Onboarding flow.
3. **Thích ứng Light & Dark Mode**:
   - Các card chọn, border, sub-step badge tự động điều chỉnh độ tương phản theo `Theme.of(context).brightness`.
4. **Tối ưu Mobile Screen (5-6 inch)**:
   - Mỗi chặng được đóng gói gọn gàng, nội dung nằm trọn trong tầm mắt, không gây tràn trang.

---

## 4. File Thay Đổi
- `lib/features/onboarding/presentation/screens/onboarding_personalization_screen.dart`
- `test/features/onboarding/onboarding_flow_test.dart`
- `docs/agent-coordination/status/thread-4.md`
- `docs/agent-coordination/reports/thread-4/TASK-002-ONBOARDING-WIZARD.md`

---

## 5. Kết Quả Kiểm Thử Thực Tế
- `flutter analyze lib/ test/`: **0 issues found** (Không có lỗi cú pháp hoặc cảnh báo linter).
- `flutter test test/features/onboarding/`: **17/17 tests PASSED** (100% tests pass, bao gồm cả widget flow test và route guard integration test).
