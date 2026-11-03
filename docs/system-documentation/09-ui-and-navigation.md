# 09. GIAO DIỆN NGƯỜI DÙNG, ĐIỀU HƯỚNG & DESIGN SYSTEM

---

## 1. TRIẾT LÝ THIẾT KẾ: CLEAN MODERN – WHITE & LIGHT BLUE

Giao diện HI Chinese được chuẩn hóa toàn diện theo phong cách:

**Clean Modern – Professional Learning – Minimal UI**

### Mục tiêu cảm quan:
- Chuyên nghiệp, gọn gàng, thanh lịch và tạo cảm giác tin cậy của một nền tảng học tập bài bản.
- Ưu tiên khoảng trắng hợp lý (Whitespace), phân cấp thông tin rõ ràng, loại bỏ hoàn toàn các trang trí rối mắt như gradient xuất hiện tràn lan, bóng đổ đậm (heavy shadows), hiệu ứng kính mờ (glassmorphism) quá đà hoặc góc bo tròn kỳ dị.

### Bảng màu chủ đạo (Theme Tokens):
Định nghĩa tại `lib/core/theme/tokens/app_colors.dart`:

- **Primary Colors:**
  - Primary Blue: `#5B9BE6`
  - Primary Blue Dark: `#3979C7`
  - Primary Blue Light: `#EAF3FF`
  - Secondary Blue: `#B9D7F5`
  - Accent Blue: `#8CC4F2`
- **Background Colors:**
  - Main Background: `#F7FAFE`
  - Secondary Background: `#F0F6FC`
  - Card Background: `#FFFFFF`
  - Input Background: `#F5F8FC`
- **Text Colors:**
  - Primary Text: `#1E293B`
  - Secondary Text: `#64748B`
  - Muted Text: `#94A3B8`
  - Disabled Text: `#B6C2D0`
- **Borders & Dividers:**
  - Border Light: `#E3EBF4`
  - Border Focus: `#5B9BE6`
- **Feedback & Semantics:**
  - Success Green: `#22C55E`
  - Warning Orange: `#F59E0B`
  - Error Red: `#EF4444`

---

## 2. KIẾN TRÚC ĐIỀU HƯỚNG VÀ APP SHELL (NAVIGATION)

### 2.1. 5 Tab Điều hướng Chính
Định nghĩa tại `AppShell` (`lib/features/app_shell/presentation/screens/app_shell.dart`) sử dụng `IndexedStack` để giữ nguyên trạng thái và vị trí cuộn khi chuyển đổi giữa các màn hình:

```text
[Tab 0] Trang chủ (HomeScreen) 
        ├── Lộ trình học tổng quan
        ├── Thẻ Streak học tập liên tục
        ├── Số lượng thẻ flashcard cần ôn trong ngày
        └── Lưới phím tắt nhanh vào các phòng Lab kỹ năng
[Tab 1] Học tập (LearningScreen)
        ├── Giáo trình HSK chi tiết (Units -> Lessons)
        ├── Khóa Pinyin Foundation
        └── Lộ trình thích ứng (Adaptive Roadmap)
[Tab 2] Gia sư AI (AiTutorTabScreen) - Tab trung tâm nổi bật
        ├── Trò chuyện văn bản (Text Chat với Qiaoqiao, Daming...)
        └── Đàm thoại giọng nói hai chiều thời gian thực (Voice Chat)
[Tab 3] Ôn tập (ReviewScreen)
        ├── Luyện flashcard từ vựng theo thuật toán SM-2
        └── Thống kê tỷ lệ ghi nhớ và số thẻ quá hạn
[Tab 4] Hồ sơ & Cài đặt (ProfileScreen)
        ├── Thông tin cấp độ HSK và chuỗi Streak
        ├── Đổi mục tiêu học tập & xem lịch sử mục tiêu
        ├── Quản lý dữ liệu, sao lưu VACUUM INTO, khôi phục
        ├── Quản lý gói học liệu & tải audio ngoại tuyến
        └── Cài đặt phím tắt API Key AI
```

### 2.2. Kiểm soát Nút Back Hệ thống Android (Android Back Button Interception)
- Được bọc bằng widget `PopScope(canPop: false)`.
- **Logic xử lý:**
  1. Nếu màn hình hiện tại có dữ liệu đang nhập dở (`hasUnsavedChanges == true`), hệ thống hiển thị hộp thoại xác nhận rời đi để bảo vệ người dùng không bị mất dữ liệu.
  2. Nếu người dùng đang ở Tab khác Tab 0 (Trang chủ), nhấn Back sẽ tự động chuyển về Tab 0 trước.
  3. Chỉ khi đang ở Tab 0 và nhấn Back, ứng dụng mới kích hoạt đóng ứng dụng an toàn.

---

## 3. CÁC THÀNH PHẦN GIAO DIỆN CHUYÊN DỤNG (REUSABLE COMPONENTS)

1. **`RubyText` (`lib/core/theme/components/ruby_text.dart`):**
   - Thành phần bắt buộc cho việc học tiếng Trung: hiển thị chữ Hán lớn bên dưới và phiên âm Pinyin nhỏ hơn căn giữa ngay trên đầu từng chữ.
   - Hỗ trợ căn chỉnh tự động theo tỷ lệ kích thước font chữ mà không bị lệch hàng.
2. **`MizigePainter` & `HanziCanvas` (`lib/features/hanzi_writing/`):**
   - Canvas vẽ lưới ô vuông mễ tự (米字格) chuẩn với các đường kẻ nét đứt phụ trợ.
   - Hỗ trợ điều khiển nét bút mượt mà, phản hồi cảm ứng nhạy và xóa nét tức thì.
3. **`PinyinToneContourChart` (`lib/features/pinyin_foundation/`):**
   - Biểu đồ cao độ 5 bậc được dựng bằng Flutter `CustomPainter`, trực quan hóa 4 thanh điệu chuẩn và thanh nhẹ.
4. **`HiButton`, `HiCard`, `HiDialog`, `HiLoadingIndicator` (`lib/core/theme/`):**
   - Hệ thống các widget cơ bản tuân thủ kích thước vùng chạm tối thiểu (Touch Target >= 48dp) theo tiêu chuẩn WCAG và Google Material Design.
5. **Khóa Chiều dọc Màn hình (Portrait Mode Enforcement):**
   - Cố định `DeviceOrientation.portraitUp` và `DeviceOrientation.portraitDown` trong `main.dart` để tối ưu trải nghiệm học chữ Hán và đàm thoại trên thiết bị di động.
