# 12. HƯỚNG DẪN MÔI TRƯỜNG, KIỂM THỬ & ĐÓNG GÓI PHÁT HÀNH

---

## 1. YÊU CẦU MÔI TRƯỜNG PHÁT TRIỂN (ENVIRONMENT SETUP)

Để thiết lập môi trường phát triển và biên dịch dự án HI Chinese, máy tính cần đáp ứng các thông số sau:

- **Hệ điều hành:** Windows 10/11, macOS, hoặc Linux x86_64/arm64.
- **Flutter SDK:** Phiên bản `3.29.x` (kênh `stable`).
- **Dart SDK:** Phiên bản `>=3.13.7 <4.0.0` (quy định tại `pubspec.yaml`).
- **Java Development Kit (JDK):** JDK 17 (OpenJDK hoặc Temurin).
- **Android SDK & Build Tools:**
  - `compileSdkVersion`: 35
  - `minSdkVersion`: 24 (Android 7.0 Nougat trở lên)
  - `targetSdkVersion`: 34
  - `ndkVersion`: 27.0.12077973
- **Android Target Platform:** **64-bit Android (`android-arm64`)** là nền tảng mục tiêu duy nhất theo thỏa thuận dự án.

---

## 2. CÁC LỆNH VẬN HÀNH CHUẨN XÁC (OPERATIONAL COMMANDS)

### 2.1. Cài đặt Thư viện Phụ thuộc
```bash
cd "c:\Users\phama\Downloads\hi_chinese"
flutter pub get
```

### 2.2. Kiểm tra Cú pháp & Linter (Chính sách 0 Warnings)
Quy tắc chất lượng nghiêm ngặt của dự án đòi hỏi kết quả phân tích cú pháp tĩnh phải hoàn toàn sạch:
```bash
dart analyze lib test
```
*Kết quả kỳ vọng:* `No issues found!` (0 errors, 0 warnings, 0 infos).

### 2.3. Chạy Toàn bộ Hệ thống Kiểm thử Tự động (Tests)
Các bài kiểm thử có thể chạy trực tiếp trên máy phát triển mà không cần mở máy ảo Android nhờ `sqflite_common_ffi`:

- **Chạy toàn bộ 64 bộ test:**
  ```bash
  flutter test
  ```
- **Chạy kiểm thử khóa Pinyin Foundation (Tests A & B):**
  ```bash
  flutter test test/features/pinyin_foundation/pinyin_foundation_test.dart
  ```
- **Chạy kiểm thử Quản lý Âm thanh Ngoại tuyến (Tests C–H):**
  ```bash
  flutter test test/features/audio_management/audio_management_offline_test.dart
  ```
- **Chạy kiểm thử Điều phối Dữ liệu Học tập (Learning Pipeline):**
  ```bash
  flutter test test/features/learning_pipeline/learning_pipeline_coordinator_test.dart
  ```
- **Chạy kiểm thử Chuẩn hóa Gói học liệu (Content Pack Normalization):**
  ```bash
  flutter test test/features/content_packs/content_pack_normalization_test.dart
  ```
- **Chạy bộ kiểm thử hồi quy Master E2E:**
  ```bash
  flutter test test/regression/hsk_self_study_platform_master_test.dart
  flutter test test/regression/full_app_regression_test.dart
  ```

---

## 3. BIÊN DỊCH VÀ ĐÓNG GÓI PHÁT HÀNH (RELEASE BUILD WORKFLOW)

### 3.1. Ràng buộc Biên dịch
- Chỉ build bản **Release 64-bit ARM64 (`--target-platform android-arm64`)**.
- Tuyệt đối không build fat APK 32-bit (tránh phình dung lượng).
- Giới hạn dung lượng APK tối đa: **< 100 MB** (Kích thước phát hành thực tế hiện tại là **~20.4 MB**).

### 3.2. Lệnh Biên dịch Release APK
```bash
flutter build apk --release --target-platform android-arm64
```

### 3.3. Sao chép và Quản lý Tệp Phát hành
Sau khi biên dịch thành công, sao chép tệp nhị phân từ thư mục build ra thư mục `release-apk/`:
```powershell
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "release-apk\hi-chinese-v1.0.7-arm64.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "release-apk\app-release.apk" -Force
```

### 3.4. Quy trình Gắn Tag và Đẩy lên Git Remote
1. Kiểm tra trạng thái: `git status`.
2. Đưa tệp vào khu vực chờ: `git add .`.
3. Commit với thông điệp rõ ràng theo chuẩn Conventional Commits:
   ```bash
   git commit -m "feat(pinyin-audio): implement pinyin foundation curriculum and offline audio management system (v1.0.7)"
   ```
4. Gắn thẻ phiên bản (Annotated Tag):
   ```bash
   git tag -a v1.0.7 -m "Release v1.0.7: Pinyin Foundation Curriculum & Offline Audio Asset Management"
   ```
5. Đẩy nhánh và tag lên GitHub:
   ```bash
   git push origin main --tags
   ```
