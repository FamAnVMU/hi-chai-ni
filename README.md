# HI Chinese

Nền tảng tự học tiếng Trung HSK chuẩn quốc tế hoàn chỉnh và có hệ thống dành cho hệ điều hành Android, được phát triển độc lập 100% bằng Flutter Native.

HI Chinese hoạt động theo mô hình **Offline-First**, lưu trữ toàn bộ giáo trình, từ vựng, ngữ pháp, bài tập, ngân hàng câu hỏi và dữ liệu đánh giá cục bộ trên thiết bị bằng SQLite Schema v9. AI đóng vai trò **trợ giảng bổ trợ (Auxiliary Assistant)** giải thích chuyên sâu và phân tích lỗi sai khi có mạng, tuyệt đối không làm gián đoạn hay thay đổi tiến trình học tập cốt lõi.

---

## 📦 Tải Ứng Dụng (Download Release APK v1.0.0)

Người học có thể tải trực tiếp file APK cài đặt cho điện thoại Android:

| Phiên Bản APK | Kích Thước | Thiết Bị Phù Hợp | Tải Về Trực Tiếp |
| :--- | :---: | :--- | :--- |
| **`hi-chinese-v1.0.0-arm64.apk`** | **19.9 MB** | **Khuyên dùng** cho hầu hết smartphone Android hiện đại (64-bit arm64-v8a) | [⬇️ Tải APK ARM64](release-apk/hi-chinese-v1.0.0-arm64.apk) |
| **`hi-chinese-v1.0.0-universal.apk`** | **56.4 MB** | Bản tổng hợp chạy trên mọi cấu hình điện thoại / máy tính bảng Android | [⬇️ Tải APK Universal](release-apk/hi-chinese-v1.0.0-universal.apk) |
| **`hi-chinese-v1.0.0-arm32.apk`** | **17.5 MB** | Dành cho các thiết bị Android thế hệ cũ (32-bit armeabi-v7a) | [⬇️ Tải APK ARM32](release-apk/hi-chinese-v1.0.0-arm32.apk) |

---

## 🌟 Đặc Điểm Nổi Bật & Cải Tiến Đột Phá

- **Nền Tảng Tự Học HSK Hoàn Chỉnh:** Giáo trình chuẩn quốc tế 15 bài học tuần tự (HSK 1), 150 từ vựng cốt lõi duy nhất có Pinyin/nghĩa/ví dụ, 45 điểm ngữ pháp, 15 bài hội thoại và 150 bài tập xác định có giải thích chuẩn.
- **Tự Học Ngoại Tuyến 100% (Offline-First):** Toàn bộ giáo trình, bài đọc, âm thanh, ngân hàng bài tập và đề thi tốt nghiệp cấp độ được đóng gói độc lập (`hsk1_pack_v1.json`) và lưu trữ trong SQLite cục bộ, học tập mượt mà mọi lúc mọi nơi mà không cần Internet hay Gemini API.
- **Quy Trình Học 6 Chặng Chuẩn Sư Phạm:** Khởi động $\rightarrow$ Từ vựng mới $\rightarrow$ Điểm ngữ pháp $\rightarrow$ Hội thoại $\rightarrow$ Luyện tập thích ứng $\rightarrow$ Kiểm tra hoàn thành bài.
- **Đánh Giá & Mở Khóa Có Điều Kiện (Prerequisite & Mastery Engine):** Bài học chỉ mở khi bài trước đạt $\ge 80\%$, theo dõi 5 trạng thái năng lực, tự động đề xuất ôn tập SRS khi phát hiện kiến thức yếu.
- **Trắc Nghiệm Thích Ứng CAT & Tự Động Phân Lớp:** Khảo sát đầu vào xác định năng lực và tự động ghi nhận đạt chuẩn các bài học trước đó, đưa người học đến đúng chặng phù hợp.
- **Đề Thi Tốt Nghiệp Cấp Độ HSK Chuẩn Quốc Tế:** Phòng thi mô phỏng 35 phút gồm 20 câu Nghe và 20 câu Đọc, tính điểm chuẩn thang 200 (điểm đạt $\ge 120$).
- **AI Trợ Giảng Bổ Trợ An Toàn (Auxiliary AI Tutor):** AI giải thích ngữ cảnh và hỗ trợ mở rộng ví dụ khi có mạng; được bảo vệ bởi rào chắn nghiêm ngặt cấm can thiệp giáo trình hoặc tự tạo đáp án chuẩn.
- **Giao Diện Material 3 Chuẩn Android:** Bảng màu Lime Green / Dark Forest sắc nét, tối ưu hóa 60fps/120fps trên Android.

---

## 🏛️ Kiến Trúc Hệ Thống

HI Chinese tuân thủ triệt để kiến trúc:
- **Clean Architecture kết hợp Feature-First:** Tách biệt rõ ràng giữa Core foundation và các tính năng nghiệp vụ.
- **Content Management System (CMS) v9:** 8 bảng SQLite độc lập quản lý giáo trình, học liệu, bài tập và tiến độ hoàn thành.
- **Repository Pattern:** Đảm bảo nguồn dữ liệu trừu tượng, cách ly giữa tầng Data (SQLite, Local Storage) và tầng Domain.
- **State Management:** Sử dụng `flutter_riverpod` cho việc quản lý trạng thái phản ứng (reactive state) và tiêm phụ thuộc (Dependency Injection).

### Cấu Trúc Thư Mục

```text
lib/
├── core/                       # Thành phần dùng chung toàn ứng dụng
│   ├── constants/              # Hằng số hệ thống, cấu hình app, database name
│   ├── database/               # Quản lý SQLite Schema v9, migrations, DAO
│   ├── network/                # Client kết nối Gemini API & kiểm tra kết nối
│   ├── theme/                  # Định nghĩa Material 3, bảng màu Lime/Dark Forest
│   └── utils/                  # Tiện ích định dạng ngày tháng, chuỗi pinyin, v.v.
│
├── features/                   # Các module chức năng (Feature-First)
│   ├── curriculum/             # [MỚI] Giáo trình HSK, CMS Loader, 6-Step Player, Thi tốt nghiệp
│   ├── onboarding/             # [MỚI] Luồng chào mừng 3 bước: API key, Placement, Cá nhân hóa
│   ├── home/                   # Màn hình chính, tổng quan lộ trình & tiến độ
│   ├── placement_test/         # Khảo sát & kiểm tra năng lực đầu vào (CAT)
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
│   ├── ai_tutor/               # Gia sư AI trợ giảng bổ trợ & giải đáp ngữ pháp
│   └── profile/                # Hồ sơ cá nhân, thống kê & cài đặt
│
└── main.dart                   # Điểm khởi chạy ứng dụng (ProviderScope & App Theme)
```
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
