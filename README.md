# HI Chinese

Ứng dụng học tiếng Trung AI thông minh dành riêng cho hệ điều hành Android, được phát triển độc lập 100% bằng Flutter Native.

HI Chinese hoạt động theo mô hình **Offline-First**, lưu trữ dữ liệu học tập và tiến độ cục bộ trên thiết bị bằng SQLite, kết hợp AI Tutor tương tác qua Google Gemini SDK khi thiết bị có kết nối mạng.

---

## 📦 Tải Ứng Dụng (Download Release APK v1.0.0)

Người học có thể tải trực tiếp file APK cài đặt cho điện thoại Android:

| Phiên Bản APK | Kích Thước | Thiết Bị Phù Hợp | Tải Về Trực Tiếp |
| :--- | :---: | :--- | :--- |
| **`hi-chinese-v1.0.0-arm64.apk`** | **19.7 MB** | **Khuyên dùng** cho hầu hết smartphone Android hiện đại (64-bit) | [⬇️ Tải APK ARM64](release-apk/hi-chinese-v1.0.0-arm64.apk) |
| **`hi-chinese-v1.0.0-universal.apk`** | **56.2 MB** | Bản tổng hợp chạy trên mọi cấu hình điện thoại / máy tính bảng Android | [⬇️ Tải APK Universal](release-apk/hi-chinese-v1.0.0-universal.apk) |
| **`hi-chinese-v1.0.0-arm32.apk`** | **17.3 MB** | Dành cho các thiết bị Android thế hệ cũ (32-bit armeabi-v7a) | [⬇️ Tải APK ARM32](release-apk/hi-chinese-v1.0.0-arm32.apk) |

---

## 🌟 Đặc Điểm Nổi Bật

- **Độc lập 100% Mobile:** Toàn bộ dữ liệu từ vựng, ngữ pháp, bài đọc, flashcard SRS và tiến độ học tập được lưu trữ và xử lý trực tiếp trên điện thoại. Không phụ thuộc máy tính cá nhân, server Node.js hay Cloudflare Tunnel.
- **Offline-First:** Sử dụng cơ sở dữ liệu SQLite cục bộ (`sqflite`), người học có thể học tập liên tục mọi lúc mọi nơi ngay cả khi không có kết nối mạng.
- **AI Tutor Trực Tiếp:** Tích hợp trực tiếp SDK Google Gemini (`google_generative_ai`), cung cấp gia sư tiếng Trung thông minh giải thích ngữ pháp, sửa lỗi phát âm và luyện đàm thoại theo ngữ cảnh.
- **Giao Diện Material 3 Chuẩn Android:** Bảng màu Lime Green / Dark Forest hiện đại, tối ưu hóa giao diện cho mọi kích thước màn hình cảm ứng, tránh hoàn toàn các lỗi tràn màn hình hay co giãn không đồng đều.

---

## 🏛️ Kiến Trúc Hệ Thống

HI Chinese tuân thủ triệt để kiến trúc:
- **Clean Architecture kết hợp Feature-First:** Tách biệt rõ ràng giữa Core foundation và các tính năng nghiệp vụ.
- **Repository Pattern:** Đảm bảo nguồn dữ liệu trừu tượng, cách ly giữa tầng Data (SQLite, Local Storage) và tầng Domain.
- **State Management:** Sử dụng `flutter_riverpod` cho việc quản lý trạng thái phản ứng (reactive state) và tiêm phụ thuộc (Dependency Injection).

### Cấu Trúc Thư Mục

```text
lib/
├── core/                       # Thành phần dùng chung toàn ứng dụng
│   ├── constants/              # Hằng số hệ thống, cấu hình app, database name
│   ├── database/               # Quản lý SQLite, migrations, DAO
│   ├── network/                # Client kết nối Gemini API & kiểm tra kết nối
│   ├── theme/                  # Định nghĩa Material 3, bảng màu Lime/Dark Forest
│   └── utils/                  # Tiện ích định dạng ngày tháng, chuỗi pinyin, v.v.
│
├── features/                   # Các module chức năng (Feature-First)
│   ├── home/                   # Màn hình chính, tổng quan lộ trình & tiến độ
│   ├── placement_test/         # Khảo sát & kiểm tra năng lực đầu vào
│   ├── roadmap/                # Lộ trình học cá nhân hóa HSK 1-6
│   ├── dictionary/             # Từ điển tra cứu Hán tự, Pinyin, nghĩa tiếng Việt
│   ├── vocabulary_srs/         # Flashcard lặp lại ngắt quãng (SRS)
│   ├── grammar/                # Ngữ pháp tiếng Trung theo cấp độ
│   ├── practice/               # Bài tập trắc nghiệm, điền từ, ghép câu
│   ├── pronunciation/          # Luyện phát âm Pinyin & thanh điệu
│   ├── shadowing/              # Luyện nói theo mẫu câu chuẩn giọng Bắc Kinh
│   ├── hanzi_writing/          # Luyện viết chữ Hán, mô phỏng thứ tự nét vẽ
│   ├── reading/                # Luyện đọc hiểu đoạn văn kèm Pinyin tương tác
│   ├── listening/              # Luyện nghe hội thoại và câu đàm thoại
│   ├── ai_tutor/               # Gia sư AI đàm thoại & giải đáp ngữ pháp
│   └── profile/                # Hồ sơ cá nhân, thống kê & cài đặt
│
└── main.dart                   # Điểm khởi chạy ứng dụng (ProviderScope & App Theme)
```

---

## ⚙️ Yêu Cầu Môi Trường

- **Flutter SDK:** `>= 3.24.0` (Khuyến nghị Flutter 3.47.x stable)
- **Dart SDK:** `>= 3.5.0` (Khuyến nghị Dart 3.13.x)
- **Java JDK:** JDK 17 hoặc JDK 21 LTS
- **Android SDK:** API Level 24+ (Android 7.0 trở lên, Target SDK 34+)

---

## 🚀 Hướng Dẫn Cài Đặt & Phát Triển

### 1. Cài đặt các gói phụ thuộc (Dependencies)
```bash
flutter pub get
```

### 2. Kiểm tra chất lượng mã nguồn (Static Analysis)
```bash
flutter analyze
```

### 3. Chạy kiểm thử tự động (Unit & Widget Tests)
```bash
flutter test
```

### 4. Khởi chạy ứng dụng ở chế độ Debug
```bash
# Liệt kê danh sách thiết bị Android / Emulator
flutter devices

# Chạy ứng dụng trên thiết bị chỉ định
flutter run -d <device-id>
```

---

## 📦 Quy Trình Đóng Gói (Build)

### 1. Đóng gói file cài đặt Android APK (Release)
```bash
flutter build apk --release
```
*Tệp APK đầu ra sẽ nằm tại:* `build/app/outputs/flutter-apk/app-release.apk`

### 2. Đóng gói file Android App Bundle (Google Play)
```bash
flutter build appbundle --release
```
*Tệp AAB đầu ra sẽ nằm tại:* `build/app/outputs/bundle/release/app-release.aab`

---

## 📄 Bản Quyền & Định Danh

- **Application ID:** `com.hichinese.hi_chinese`
- **Database Cục bộ:** `hi_chinese.db`
- **Bản quyền:** © 2026 HI Chinese Team. Độc quyền phát triển cho Android.
