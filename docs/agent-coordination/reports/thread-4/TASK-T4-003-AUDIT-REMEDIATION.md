# Task Report: TASK-T4-003-AUDIT-REMEDIATION — Presentation Layer & Settings Remediation (F-05, F-21, F-31, F-32)

- **Task ID**: `TASK-T4-003-AUDIT-REMEDIATION`
- **Thread**: Thread 4 (Presentation Layer, Design System & Mobile UX)
- **Branch**: `feature/thread-4-ui`
- **Base Commit**: `5c099ba`
- **Date**: 2026-11-05
- **Reference**: `audit/BAO_CAO_KIEM_TOAN_HI_CHINESE.md` (Thread 5)

---

## 1. Nội Dung Yêu Cầu & Giải Pháp Thực Hiện

### 1.1. [CRITICAL] Khắc phục lỗi nạp Cài đặt người dùng (Theme, Font, Pinyin) khi khởi động (F-05)
- **Vấn đề**: `AppSettingsNotifier` trước đây chỉ chạy bất đồng bộ tách biệt trong hàm `build()`, dẫn đến việc UI bị giật về chế độ mặc định hoặc Dark mode trước khi DB kịp tải xong.
- **Giải pháp**:
  1. Tích hợp trực tiếp việc đồng bộ `AppSettings` và `ThemeMode` vào **Bước 9/10 của chu trình khởi động ứng dụng** tại `lib/core/startup/app_startup_provider.dart`.
  2. Tại bước 9, sau khi tạo user profile mặc định, `AppStartupNotifier` nạp toàn bộ cấu hình từ `AppSettingsDao(db)` và đồng bộ ngay lập tức vào `themeModeProvider` và `appSettingsProvider`.
  3. Bổ sung phương thức `reloadSettings()` trong `AppSettingsNotifier` và đặt giá trị theme mặc định là `ThemeMode.light` (Clean Modern White & Light Blue) đồng bộ với toàn hệ thống.
  4. Nhờ đó, trong suốt quá trình `AppShell` hiển thị màn hình Loading/Splash, mọi cài đặt người dùng đã được nạp sẵn vào bộ nhớ trước khi màn hình chính render, loại bỏ hoàn toàn hiện tượng giật màu (flash of wrong theme).

### 1.2. [MEDIUM] Cấu hình bảo mật AndroidManifest và Chặn rò rỉ dữ liệu (F-21)
- **Vấn đề**: `android/app/src/main/AndroidManifest.xml` trước đó chưa có cấu hình `dataExtractionRules` hay `fullBackupContent`, khiến SQLite database và tệp `.hibak` có thể bị sao lưu tự động không mã hóa lên đám mây.
- **Giải pháp**:
  1. Tạo tệp `android/app/src/main/res/xml/data_extraction_rules.xml` cấu hình cả `cloud-backup` và `device-transfer` loại trừ đường dẫn `databases/` và các tệp định dạng `*.hibak`.
  2. Tạo tệp `android/app/src/main/res/xml/backup_rules.xml` cho các phiên bản Android cũ loại trừ domain `database` và các tệp `*.hibak`.
  3. Khai báo `android:allowBackup="true"`, `android:dataExtractionRules="@xml/data_extraction_rules"`, `android:fullBackupContent="@xml/backup_rules"` trong `AndroidManifest.xml`.

### 1.3. [LOW] Dọn dẹp Dead Code và Chuẩn hóa Phiên bản Ứng dụng (F-31, F-32)
- **Vấn đề**: Phiên bản ứng dụng bị hardcode `1.0.0` tại nhiều nơi; `main.dart` chứa class rác `HiChineseSkeletonScreen` dài hơn 300 dòng không được sử dụng.
- **Giải pháp**:
  1. Tích hợp thư viện `package_info_plus` (`^10.2.2`) và tạo `lib/core/constants/app_info_provider.dart` để lấy động thông tin phiên bản từ runtime (`PackageInfo.fromPlatform()`).
  2. Cập nhật `AppConstants`: `appVersion = '1.0.9'`, `appBuildNumber = '10'`, `appVersionWithBuild = '1.0.9+10'`.
  3. Cập nhật `AboutAndPrivacyDialog` và `ProfileScreen` hiển thị phiên bản động theo `appInfoProvider` (fallback mượt mà sang `AppConstants.appVersionWithBuild`).
  4. Xóa bỏ hoàn toàn widget dead code `HiChineseSkeletonScreen` (325 dòng) trong `lib/main.dart`, giúp code tinh gọn, rõ ràng.

---

## 2. File Thay Đổi
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/data_extraction_rules.xml` (Tạo mới)
- `android/app/src/main/res/xml/backup_rules.xml` (Tạo mới)
- `pubspec.yaml` & `pubspec.lock` (Thêm `package_info_plus: ^10.2.2`)
- `lib/core/constants/app_constants.dart`
- `lib/core/constants/app_info_provider.dart` (Tạo mới)
- `lib/core/startup/app_startup_provider.dart`
- `lib/features/settings/presentation/providers/settings_providers.dart`
- `lib/features/settings/presentation/widgets/about_and_privacy_dialog.dart`
- `lib/features/settings/data/services/data_management_service.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/main.dart`
- `docs/agent-coordination/status/thread-4.md`
- `docs/agent-coordination/reports/thread-4/TASK-T4-003-AUDIT-REMEDIATION.md`

---

## 3. Kết Quả Kiểm Thử Thực Tế
- `flutter analyze lib/core/startup lib/features/settings lib/features/profile lib/main.dart`: **0 issues found** (Không có bất kỳ lỗi hoặc cảnh báo linter nào).
- `flutter test test/features/profile/profile_and_settings_test.dart test/core/startup/app_startup_integration_test.dart`: **26/26 tests PASSED (100% PASS)**.
