# HI CHINESE – BÁO CÁO GIẤY PHÉP VÀ NGUỒN GỐC ÂM THANH (AUDIO SOURCES & LICENSES)

Báo cáo này đặc tả nguồn gốc, bản quyền, điều khoản cấp phép và trách nhiệm ghi công đối với toàn bộ dữ liệu câu ví dụ và tệp âm thanh trong ứng dụng HI Chinese.

---

## 1. Nguồn dữ liệu Tatoeba Project

- **Website**: [https://tatoeba.org/](https://tatoeba.org/)
- **Bản quyền câu văn bản (Text Content)**:
  - Tất cả các câu tiếng Trung và bản dịch tiếng Việt trích xuất từ Tatoeba được cấp phép theo điều khoản **Creative Commons Attribution 2.0 France (CC BY 2.0 FR)** hoặc **Creative Commons CC0 (Public Domain)**.
  - Điều kiện sử dụng: Được phép sao chép, phân phối và sử dụng cho mục đích giáo dục với điều kiện ghi rõ nguồn Tatoeba Project và tác giả câu gốc.
- **Bản quyền âm thanh (Audio Recordings)**:
  - Bản ghi âm do các thành viên cộng đồng Tatoeba tải lên.
  - Giấy phép phân phối: Đa số tuân thủ **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** hoặc **CC BY-SA 3.0**.
  - Các tác giả đóng góp giọng đọc tiêu biểu: `LeviHighway`, `fucongcong`, `driini`, `mramosch`, `Oblomov`, `BraveSentry`.
  - Link trích dẫn: `https://tatoeba.org/sentences/show/{id}` và hồ sơ tác giả `https://tatoeba.org/user/profile/{username}`.

---

## 2. Nguồn dữ liệu HSK Syllabus & CosyVoice2

- **Giáo trình HSK Syllabus (GF0025-2021)**: Dữ liệu phân cấp từ vựng và ngữ pháp mở.
- **Mô hình âm thanh CosyVoice2-0.5B**:
  - Giấy phép: **Apache License 2.0**.
  - Cho phép phân phối và sử dụng tự do kèm theo thông báo bản quyền của Alibaba Tongyi Lab.
  - Tần số lấy mẫu: 24.000 Hz, giọng đọc nữ phổ thông chuẩn (`zh-female-studio`).

---

## 3. Native OS Text-to-Speech (TTS)

- **Android TextToSpeech API**: Sử dụng trực tiếp engine của hệ điều hành Android (Google TTS / Samsung TTS / Xiaomi TTS).
  - Ngôn ngữ: `Locale.SIMPLIFIED_CHINESE` (`zh-CN`).
  - Chạy ngoại tuyến hoàn toàn khi người dùng đã cài gói giọng đọc tiếng Trung trong phần cài đặt của máy (Android Settings -> Language -> Text-to-Speech).
- **iOS AVSpeechSynthesizer**: Giọng đọc hệ thống Apple (`zh-CN`).
- **Trạng thái bản quyền**: Thuộc quyền sở hữu của hệ điều hành, ứng dụng chỉ gọi API mà không đóng gói mã nhị phân TTS riêng.

---

## 4. Chính sách bảo vệ bản quyền & Tuyên bố miễn trừ

1. Mọi bản ghi âm và câu văn bản đều lưu giữ metadata tác giả (`contributor`, `speaker`) và giấy phép (`license`).
2. HI Chinese cung cấp chức năng tải theo Content Pack/Audio Pack giúp người dùng kiểm soát dung lượng bộ nhớ thiết bị, không lưu trữ âm thanh ngoài phạm vi học tập cá nhân phi thương mại.
3. Ứng dụng cam kết ghi nhận công khai nguồn mở tại màn hình *"Giới thiệu & Bản quyền"* theo đúng các điều khoản CC BY.
