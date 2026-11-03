# 11. BẢO MẬT HỆ THỐNG & QUẢN TRỊ DỮ LIỆU

---

## 1. QUẢN LÝ KHÓA BÍ MẬT & API KEY (SECRET MANAGEMENT)

- **`AiCredentialStorage` (`lib/core/network/ai/security/ai_credential_storage.dart`):**
  - Khóa bí mật Google Gemini API Key được mã hóa và lưu trữ độc quyền qua thư viện `flutter_secure_storage`.
  - Trên hệ điều hành Android, thư viện sử dụng **Android Keystore System** kết hợp thuật toán mã hóa phần cứng (Hardware-backed AES/RSA encryption).
- **Quy tắc Kiểm duyệt Mã nguồn (Zero Hardcoded Secret):**
  - Tuyệt đối không hardcode API Key, mật khẩu hoặc Private Key trong mã nguồn, commit history hoặc tài liệu kỹ thuật.
  - Khi xuất tệp JSON hoặc sao lưu dữ liệu, trường API Key **tuyệt đối không bao giờ được đưa vào tệp export** nhằm bảo vệ quyền lợi và chi phí của học viên.

---

## 2. PHÒNG CHỐNG TẤN CÔNG TIÊM LỆNH SQL (SQL INJECTION PREVENTION)

Toàn bộ các truy vấn cơ sở dữ liệu SQLite trong hệ thống bắt buộc phải sử dụng **tham số hóa câu lệnh (Parameterized Queries)**:

- **Đúng chuẩn:**
  ```dart
  await db.query(
    'vocabularies',
    where: 'simplified = ? AND hsk_level = ?',
    whereArgs: [userInput, hskLevel],
  );
  ```
- **Nghiêm cấm:**
  Không bao giờ nối chuỗi trực tiếp:
  ```dart
  // SAI: Nguy cơ SQL Injection nghiêm trọng
  await db.rawQuery("SELECT * FROM vocabularies WHERE simplified = '$userInput'");
  ```
- **Xử lý danh sách `IN (...)`:**
  Sử dụng cơ chế sinh placeholder an toàn:
  ```dart
  final placeholders = List.filled(ids.length, '?').join(',');
  await db.query(tableName, where: 'id IN ($placeholders)', whereArgs: ids);
  ```

---

## 3. BẢO VỆ TÍNH RIÊNG TƯ ÂM THANH & MICROPHONE (AUDIO PRIVACY)

1. **Không Tự ý Kích hoạt Microphone:**
   - Ứng dụng không bao giờ xin quyền micro lúc mới mở ứng dụng.
   - Chỉ khi người dùng chủ động vào màn hình Luyện phát âm (`PronunciationLabScreen`) hoặc Gia sư giọng nói (`AiTutorVoiceChatScreen`), hộp thoại giải thích lý do sư phạm mới xuất hiện.
2. **Thu hồi Tài nguyên Ngay lập tức khi Ẩn Ứng dụng (Lifecycle Hooks):**
   - Lớp `AppLifecycleManager` theo dõi trạng thái `paused` và `detached` của ứng dụng.
   - Khi người học nhận cuộc gọi điện thoại hoặc bấm nút Home/khóa màn hình, hệ thống lập tức đóng luồng ghi âm micro và giải phóng tài nguyên phần cứng.
3. **Tự động Dọn dẹp Tệp Thu âm Tạm:**
   - Các bản ghi âm của học viên phục vụ chấm điểm phát âm được lưu vào thư mục cache tạm và bị xóa bỏ sau phiên phân tích, không bị upload trái phép lên máy chủ nào ngoài việc gửi audio stream sang Gemini khi có sự đồng ý của người dùng.

---

## 4. BẢO VỆ CHỐNG MẤT MÁT DỮ LIỆU KHI RESET (SAFE RESET SAFEGUARD)

Trong `DataManagementService.clearAllUserData()`:

1. **Yêu cầu Mã Xác nhận Bắt buộc (Confirmation Code):**
   - Để xóa dữ liệu học tập, học viên bắt buộc phải nhập mã xác nhận ngẫu nhiên (ví dụ: `RESET_9482`). Nếu mã không khớp chính xác, hành động bị từ chối ngay lập tức.
2. **Tự động Tạo Bản Sao lưu Dự phòng (Safety Auto-Backup):**
   - Trước khi thực thi bất kỳ câu lệnh xóa nào, hệ thống tự động gọi `createBackup(customName: 'safety_backup_before_reset.db')`.
   - Trong trường hợp học viên vô tình xóa nhầm, họ luôn có thể tìm lại bản sao lưu này tại thư mục `backups/` để phục hồi 100% dữ liệu.
3. **Cô lập Dữ liệu (Isolation of Seeded Content):**
   - Lệnh reset dữ liệu chỉ xóa tiến độ của người học (`lesson_progress`, `mastery_snapshots`, `learner_evidence`, `srs_items`, `practice_attempts`, `user_saved_words`).
   - Các bảng dữ liệu giáo trình và từ điển gốc (`vocabularies`, `curriculums`, `curriculum_lessons`, `knowledge_registry`) hoàn toàn **không bị ảnh hưởng**.
