# 14. DANH MỤC TỒN ĐỌNG KỸ THUẬT & RỦI RO CẦN LƯU Ý (TECHNICAL DEBT)

Tài liệu này ghi nhận trung thực các điểm kỹ thuật cần lưu ý, mức độ ưu tiên và phương án cải tiến dành cho đội ngũ phát triển tiếp theo.

---

## 1. PHÂN LOẠI MỨC ĐỘ RỦI RO

- **CRITICAL:** Nguy cơ mất dữ liệu, lỗi bảo mật nghiêm trọng hoặc hỏng chức năng cốt lõi. (Hiện tại: **0 vấn đề**).
- **HIGH:** Ảnh hưởng đến trải nghiệm học tập nâng cao hoặc thiếu kết nối phần cứng thời gian thực.
- **MEDIUM:** Nợ kỹ thuật về kiến trúc, trùng lặp hằng số hoặc cấu trúc gói học liệu lớn.
- **LOW:** Tối ưu hóa hiệu năng nhỏ, giảm thiểu rác biên dịch hoặc làm mượt các bài test race condition.

---

## 2. DANH MỤC CHI TIẾT CÁC VẤN ĐỀ ĐƯỢC XÁC MINH

### Issue #01: Voice Chat Live Mode phụ thuộc vào Simulated Speech Input
- **Mức độ:** **HIGH**
- **Vị trí file:** `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart` (`DefaultVoiceConversationService`)
- **Nguyên nhân:** Lớp `VoiceConversationService` đã xây dựng hoàn chỉnh máy trạng thái (VAD, xin quyền micro, ngắt lời, giao diện sóng âm, hiển thị pill chẩn đoán), nhưng luồng truyền âm thanh PCM 16kHz trực tiếp từ mic qua WebSocket sang Gemini Live API hiện đang chuyển tiếp qua hàm `submitSpeechInput()` thay vì mở socket nhị phân trực tiếp từ luồng ghi âm phần cứng của Android.
- **Hậu quả:** Học viên có thể trải nghiệm Voice Chat đầy đủ trong các kịch bản mô phỏng, nhưng để đàm thoại rảnh tay tự nhiên 100% ngoài đời thực cần cắm trực tiếp stream microphone vào WebSocket channel.
- **Đề xuất khắc phục:** Tích hợp `flutter_sound` hoặc `record` stream listener để đưa mảng byte PCM thô trực tiếp vào `WebSocketChannel.sink.add()`.

---

### Issue #02: Lệch Hằng số Phiên bản Cơ sở dữ liệu giữa AppConstants và DatabaseConstants
- **Mức độ:** **MEDIUM**
- **Vị trí file:**
  - `lib/core/constants/app_constants.dart` (Dòng 8: `static const int databaseVersion = 1;`)
  - `lib/core/database/database_constants.dart` (Dòng 5: `static const int currentDatabaseVersion = 11;`)
- **Nguyên nhân:** `AppConstants` lưu giá trị phiên hiệu cũ từ phiên bản v1 ban đầu và không được sử dụng bởi `AppDatabase` (hệ thống sử dụng độc quyền `DatabaseConstants.currentDatabaseVersion = 11`).
- **Hậu quả:** Có thể gây hiểu nhầm cho lập trình viên mới khi đọc lướt hằng số trong `core/constants/`.
- **Đề xuất khắc phục:** Xóa bỏ trường `databaseVersion` trong `AppConstants` hoặc gán trỏ trực tiếp: `static const int databaseVersion = DatabaseConstants.currentDatabaseVersion;`.

---

### Issue #03: Kích thước Tệp Gói Học liệu Lớn khi Mở rộng HSK 4–6
- **Mức độ:** **MEDIUM**
- **Vị trí file:** `assets/data/content_packs/hsk1/hsk1_pack_v1.json` (~170KB), `hsk2_pack_v1.json` (~176KB).
- **Nguyên nhân:** Mỗi cấp độ HSK hiện tại đang được gom thành một tệp JSON khổng lồ duy nhất chứa cả mục lục giáo trình, danh sách từ vựng, ngữ pháp và toàn bộ bài tập.
- **Hậu quả:** Với HSK 1 và 2 (150 từ vựng), việc nạp mất <100ms trong background Isolate. Nhưng với HSK 4 (1200 từ), HSK 5 (2500 từ) và HSK 6 (5000 từ), việc phân tích một file JSON nặng hàng chục Megabyte cùng lúc có thể gây áp lực bộ nhớ tạm thời trên máy Android yếu.
- **Đề xuất khắc phục:** Chia nhỏ các gói HSK 4–6 theo từng Part / Unit (ví dụ: `hsk4_part1.json`, `hsk4_part2.json`) và nạp lười (Lazy loading) theo tiến độ của người học.

---

### Issue #04: Màn hình Demo Design System còn nằm trong Release Build
- **Mức độ:** **LOW**
- **Vị trí file:** `lib/features/design_system/presentation/screens/design_system_demo_screen.dart`
- **Nguyên nhân:** Màn hình này được tạo ra trong quá trình thiết kế lại giao diện để kỹ sư kiểm tra các component nút bấm, thẻ bài, bảng màu. Màn hình vẫn được giữ lại trong codebase để phục vụ bảo trì UI.
- **Hậu quả:** Tăng kích thước APK thêm một lượng rất nhỏ (~15KB mã nguồn), không ảnh hưởng người dùng vì không có liên kết trực tiếp trên giao diện chính.
- **Đề xuất khắc phục:** Bọc trong cờ `kDebugMode` hoặc đưa vào menu "Dành cho nhà phát triển" ẩn trong Cài đặt.

---

### Issue #05: Tranh chấp Thời gian (Timing Jitter) trong Bài test Debounce khi Chạy Song song
- **Mức độ:** **LOW**
- **Vị trí file:** `test/features/vocabulary_srs/srs_integration_test.dart` (Test 5: `Rejects duplicate rapid review taps within debounce threshold`)
- **Nguyên nhân:** Bài test kiểm tra việc từ chối hai cú chạm trong khoảng 500ms. Khi chạy toàn bộ 64 file test cùng lúc (`flutter test`), CPU bị quá tải đột ngột khiến độ trễ thực thi `Future.delayed` bị co giãn, đôi khi vượt qua ngưỡng 500ms.
- **Hậu quả:** Khi chạy kiểm thử độc lập (`flutter test test/features/vocabulary_srs/srs_integration_test.dart`), bài test luôn **PASS 100%**. Nhưng khi chạy song song 64 test suites, thỉnh thoảng có thể xuất hiện cảnh báo race condition.
- **Đề xuất khắc phục:** Sử dụng `fakeAsync` từ thư viện `package:fake_async` để điều khiển đồng hồ giả lập thay vì dựa vào thời gian thực tế của CPU hệ điều hành.
