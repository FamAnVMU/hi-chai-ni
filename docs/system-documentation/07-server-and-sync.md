# 07. MÁY CHỦ, TÀI KHOẢN & CƠ CHẾ NGOẠI TUYẾN

---

## 1. MÔ HÌNH TÀI KHOẢN NGƯỜI DÙNG (LOCAL USER ACCOUNT SYSTEM)

Khác với các ứng dụng web thông thường yêu cầu đăng ký bằng email/mật khẩu, HI Chinese được xây dựng theo mô hình **Zero-Account / 100% Local Profile**:

- **Không Yêu cầu Đăng ký / Đăng nhập từ xa:**
  - Không có máy chủ xác thực tài khoản tập trung (No Remote Authentication Server, No OAuth2, No JWT).
  - Ngay sau khi cài đặt ứng dụng, hệ thống tự động khởi tạo hồ sơ học viên mặc định trong bảng `user_profiles` (`id = 'default_user'`).
- **Thông tin Hồ sơ Cục bộ:**
  - Tên hiển thị (`display_name`).
  - Cấp độ HSK hiện tại (`current_hsk_level`).
  - Cấp độ HSK mục tiêu (`target_hsk_level`).
  - Thời gian học mục tiêu hằng ngày (`daily_target_minutes`).
  - Mục đích học tập (`learning_purpose`: Giao tiếp, Thi cử, Du lịch, Công việc).
  - Chuỗi ngày học liên tục (`streak_count`).
- **Lịch sử Thay đổi Mục tiêu (`goal_history`):**
  - Mọi thao tác thay đổi cấp độ hoặc thời gian học đều bắt buộc phải ghi rõ lý do và được lưu thành bản ghi lịch sử phục vụ phân tích sư phạm.

---

## 2. KIẾN TRÚC MÁY CHỦ VÀ PHÂN PHỐI NỘI DUNG TĨNH (STATIC CDN ARCHITECTURE)

Do ứng dụng là Offline-First, không có hệ thống Backend Application Server động (như Node.js/Python/Go Server riêng biệt). Việc phân phối dữ liệu từ xa tuân theo mô hình **Static CDN Pull**:

```text
[HI Chinese Mobile App]
       │
       ├─── (1) HTTP GET https://raw.githubusercontent.com/.../hsk3_pack_v1.json (Gói học liệu tĩnh)
       │
       ├─── (2) HTTP GET {cdnBaseUrl}/{pack_id}/{audio_file}.mp3 (Tệp âm thanh tĩnh)
       │
       └─── (3) HTTPS POST https://generativelanguage.googleapis.com/... (Dịch vụ AI bên thứ ba)
```

- **Điểm phân phối Gói học liệu:**
  - Kho lưu trữ GitHub Raw chính thức: `https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/`.
- **Cấu hình Nguồn Âm thanh (`ContentSourceConfig`):**
  - Cho phép thay đổi URL máy chủ CDN phân phối âm thanh linh hoạt, không cố định cứng trong code.

---

## 3. KIỂM CHỨNG CÁC TÍNH NĂNG ĐỒNG BỘ VÀ CLOUDFLARE TUNNEL

Dựa trên kết quả rà soát mã nguồn thực tế:

| Khái niệm khảo sát | Hiện trạng trong mã nguồn | Đánh giá & Khuyến nghị kỹ thuật |
| :--- | :---: | :--- |
| **Cloudflare Tunnel** | **NOT IMPLEMENTED** | Không có bất kỳ tệp cấu hình, file nhị phân `cloudflared` hay URL tunnel nào trong codebase. Ứng dụng không cần tunnel vì không có local backend server cần expose ra Internet. |
| **Hàng đợi Đồng bộ Hai chiều (Bidirectional Sync Queue)** | **NOT IMPLEMENTED** | Không có bảng `sync_queue` hay cơ chế giải quyết xung đột (conflict resolution) giữa Client và Server. Dữ liệu học viên tồn tại độc quyền trên thiết bị. |
| **Xuất / Nhập Tiến độ (Manual Progress Portability)** | **IMPLEMENTED** | Triển khai thông qua `DataManagementService` (`exportUserDataJson` và `importUserDataJson`), cho phép người học xuất toàn bộ tiến độ ra tệp JSON để chuyển đổi thiết bị thủ công. |

---

## 4. BẢO VỆ DỮ LIỆU & QUẢN LÝ DUNG LƯỢNG NGOẠI TUYẾN

Hệ thống cung cấp màn hình **Quản lý Dữ liệu & Bộ nhớ** (`DataManagementSheet`):

1. **Thống kê Phân bổ Bộ nhớ (Storage Breakdown):**
   - Dung lượng cơ sở dữ liệu SQLite (`hi_chinese.db`).
   - Dung lượng tệp âm thanh ngoại tuyến (`content_packs/{pack_id}/audio/`).
   - Dung lượng các bản sao lưu an toàn (`backups/`).
2. **Sao lưu Toàn diện Độc lập (Full Atomic SQLite Backup):**
   - Sử dụng lệnh `VACUUM INTO`, tạo tệp `.db` nén gọn hoàn chỉnh lưu tại thư mục sao lưu của ứng dụng.
3. **Phục hồi Dữ liệu:**
   - Cho phép học viên chọn bản sao lưu cũ để phục hồi toàn bộ tiến độ khi cần.
