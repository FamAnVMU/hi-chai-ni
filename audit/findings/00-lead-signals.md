# LEAD — tín hiệu kiểm toán độc lập (scratch, chưa phải báo cáo cuối)

## Môi trường
- `dart analyze lib test` → **No issues found!** (exit 0). Static analysis sạch, nhưng không chứng minh logic đúng.
- Repo: Flutter app 63.842 dòng lib (346 file), 20.431 dòng test (92 file), 46 script Python, docs rất nhiều và có dấu hiệu "overclaim".
- Git: main tại 5c099ba, version pubspec 1.0.9+10.

## L-01 [HIGH] Cài đặt người dùng KHÔNG được nạp khi khởi động (silent catch + provider khởi tạo trước khi DB mở)
- `lib/features/settings/presentation/providers/settings_providers.dart:24-33` (`AppSettingsNotifier.build()` gọi `_loadSettingsAsync()`, `ref.read(appSettingsDaoProvider)`), `:30-64` catch nuốt lỗi.
- `lib/features/settings/presentation/providers/settings_providers.dart:12-15` `appSettingsDaoProvider` dùng `ref.watch(appDatabaseProvider).database` → getter ném `StateError` nếu DB chưa mở (`lib/core/database/app_database.dart:28-34`).
- `lib/main.dart:53-54` MaterialApp watch `themeModeProvider` + `fontScaleProvider` (→ appSettingsProvider) trong frame đầu, TRƯỚC khi `AppStartupNotifier.initialize()` mở DB (`lib/core/startup/app_startup_provider.dart:62-71, 96`; `lib/features/app_shell/presentation/screens/app_shell.dart:20`).
- Không có `ref.invalidate(appSettingsProvider)` nào sau startup (grep toàn lib).
- Hệ quả: theme/fontScale/showPinyin/speechRate/autoPlay/haptic luôn về default mỗi lần mở app; thay đổi ở Profile UI ghi DB nhưng không được đọc lại.
- Split default: `themeModeProvider` default `ThemeMode.light` (`lib/core/theme/app_theme.dart:448-453`) vs `AppSettings.themeMode` default `ThemeMode.dark` (`lib/features/settings/domain/models/app_settings.dart:79-89`).

## L-02 [HIGH] Hoàn tất onboarding nuốt lỗi transaction, UI vẫn báo thành công
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart:299-446`: set `state.isCompleted=true` TRƯỚC, toàn bộ transaction nằm trong `try { ... } catch (_) {}` (dòng 446).
- `lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart:84-98`: `await notifier.completePersonalization(...)` rồi gọi `onOnboardingComplete()` vô điều kiện.
- Hệ quả: nếu ghi DB thất bại (FK, disk full, DB đóng), app vào Home nhưng `onboarding_completed` không được lưu, unlock/roadmap init không chạy → lần mở sau onboarding lặp lại; hồ sơ/mục tiêu không lưu.

## L-03 [HIGH] Restore backup xóa DB sống TRƯỚC khi xác thực bản backup; fallback mở DB không chạy migration
- `lib/features/settings/data/services/data_management_service.dart:117-188`.
  - dòng 122-127: pre-restore snapshot lỗi chỉ log warning, vẫn tiếp tục.
  - dòng 146-150: `delete()` file DB hiện tại rồi mới `copy(backupFile)`.
  - dòng 167-179: fallback `databaseFactory.openDatabase(_dbPath, ...)` KHÔNG truyền `version` → không chạy migration, schema lệch version.
  - dòng 181-185: integrity check sau khi đã ghi đè; nếu hỏng chỉ log warning, không rollback.
- Cũng: `lib/core/database/database_backup_helper.dart:34-90` docstring nói "Verifies the integrity of the created backup file" nhưng không hề verify sau khi tạo.

## L-04 [MED] Split-brain user_profiles: 3 quy ước ID + UPDATE không WHERE
- `lib/core/startup/app_startup_provider.dart:305` `user_default`; `lib/features/onboarding/presentation/providers/onboarding_providers.dart:363` `profile_default`; `lib/features/profile/domain/models/user_profile.dart:62` `default_learner`.
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart:350-358`: `txn.update(tableUserProfiles, {...})` KHÔNG có `where` → cập nhật mọi dòng.
- `lib/features/profile/data/repositories/profile_repository.dart:24-37`: `query(..., limit: 1)` không ORDER BY → đọc dòng bất kỳ nếu có nhiều dòng (nhập JSON từ máy khác có thể tạo nhiều dòng).

## L-05 [MED] Nhấp nháy Onboarding với người dùng cũ + reset cờ khi lỗi DB
- `lib/features/app_shell/presentation/screens/app_shell.dart:58-66` + `onboarding_providers.dart:134-143`: build() trả `isCompleted=false` mặc định, `_loadState()` chạy microtask sau → frame đầu sau startup hiển thị onboarding.
- `onboarding_providers.dart:217-224`: `catch (_)` → `isCompleted=false` (mất trạng thái onboarding khi lỗi đọc DB tạm thời).

## L-06 [MED] Route guard & deep-link là dead code
- Không có `pushNamed` nào trong lib (grep). `MaterialApp` dùng `home:` (`lib/main.dart:71`) + `onGenerateRoute` (`:70`).
- `lib/core/router/app_router.dart:60-171` không bao giờ được gọi; `AppRoutes.protectedRoutes` (`lib/core/router/app_routes.dart:14`) không dùng; normalize scheme `hichinese` (`app_router.dart:47-51`) không có intent-filter tương ứng trong `android/app/src/main/AndroidManifest.xml:33-36` (chỉ MAIN/LAUNCHER).
- Docs/commit claim "route guard, deep link protection" → sai thực tế.

## L-07 [LOW] Version hiển thị hardcode sai
- `lib/core/constants/app_constants.dart:5` `appVersion='1.0.0'` (pubspec 1.0.9+10); `lib/features/settings/presentation/widgets/about_and_privacy_dialog.dart:43` "1.0.0+1"; `lib/features/profile/presentation/screens/profile_screen.dart:510` "v1.0.0+1"; `data_management_service.dart:213` export metadata `app_version:'1.0.0+1'`.

## L-08 [LOW] main.dart còn màn hình skeleton chết ~320 dòng + demo design system trong release
- `lib/main.dart:76-398` `HiChineseSkeletonScreen` không được route nào dùng; `design_system_demo_screen` vẫn build release (docs Issue #04 thừa nhận).

## L-09 [MED] Manifest thiếu allowBackup=false/fullBackupContent; exported MAIN activity chuẩn
- `android/app/src/main/AndroidManifest.xml:11-15` không có `android:allowBackup` (default true), không `android:fullBackupContent` → DB học tập bị auto-backup; flutter_secure_storage (Keystore) không backup key → restore có thể lỗi giải mã.

## L-10 [MED] UserProfileNotifier.updateProfile optimistic update không rollback
- `lib/features/profile/presentation/providers/profile_providers.dart:29-44`: gán `state = AsyncData(updated)` trước `await repo.saveProfile(updated)`; lỗi ghi DB không được bắt → UI báo đã lưu.

## L-11 [MED] Import dữ liệu JSON không kiểm tra version/schema, ghi trực tiếp map thô
- `lib/features/settings/data/services/data_management_service.dart:231-339`: chỉ check `app_name`; insert row thô từ JSON (có thể thiếu cột/kiểu sai) với `ConflictAlgorithm.replace`; export chỉ 7 bảng (thiếu practice/chat/grammar/hanzi/sentence/pinyin...) → "backup" không đầy đủ.

## L-12 [MED] Back button trên tab Home gọi Navigator.pop() trên route gốc
- `lib/features/app_shell/presentation/screens/app_shell.dart:72-102`: PopScope canPop:false; nhánh C gọi `Navigator.of(context).pop()` thay vì `SystemNavigator.pop()`; test `test/features/app_shell/app_shell_test.dart:135+` chỉ test nhánh B (non-home tab), không test nhánh C.

## Đã verify từ source thư viện
- sqflite 2.4.5 (sqflite_common 2.5.14) wrap onCreate/onUpgrade trong transaction exclusive (`database_mixin.dart:1138-1176`) → KHÔNG được kết luận "migration thiếu transaction" một cách máy móc.
- `PRAGMA foreign_keys=ON` nằm trong onConfigure (trước transaction) → hợp lệ.
