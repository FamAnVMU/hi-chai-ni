# BÁO CÁO NGHIỆM THU: ONBOARDING DOWNLOAD INTERCEPTOR & LESSON FLOW LIFECYCLE
**Mã nhiệm vụ:** TASK-T2-006  
**Thread phụ trách:** Thread 2 – Pedagogy & Learning Experience  
**Phối hợp:** Thread 1 (Data API & CDN Assets), Thread 4 (Presentation & UI/UX), Thread 5 (Independent QA)  
**Thời gian hoàn thành:** 2026-11-06  
**Trạng thái:** COMPLETED & TEST PASSING (100%)

---

## 1. MỤC TIÊU & BỐI CẢNH

Khi học viên mới khởi động ứng dụng Hi Chinese và lựa chọn xuất phát từ trình độ HSK 3 trở lên (thông qua khảo sát cá nhân hóa hoặc bài kiểm tra năng lực đầu vào Placement Test), hệ thống cần:
1. **Chặn luồng Onboarding (Interceptor)** một cách sư phạm, kiểm tra trạng thái cài đặt của gói học liệu (`hsk3_pack_v1` đến `hsk6_pack_v1`).
2. Cung cấp tùy chọn rõ ràng cho học viên: Tải ngay gói học liệu hoặc để sau mà không làm mất cấu hình cấp độ đã chọn.
3. Chuẩn hóa vòng đời `LessonFlowNotifier` với `autoDispose` và `resetToStep(LessonStep step)` để đảm bảo mọi bài học khi mở mới luôn khởi động chuẩn tại Chặng 1 (`LessonStep.warmup` - Khởi động).

---

## 2. CHI TIẾT THAY ĐỔI KIẾN TRÚC & MÃ NGUỒN

### 2.1. Quản lý trạng thái cài đặt HSK Pack (`content_packs_providers.dart`)
- Bổ sung `isHskLevelInstalledProvider`:
  - Trả về `true` tức thì với HSK 1 & HSK 2 (học liệu tích hợp sẵn trong ứng dụng).
  - Với HSK 3–6: truy vấn bảng `content_packs` trong cơ sở dữ liệu SQLite để xác nhận đã cài đặt.
- Mở rộng danh mục Catalog trong `ContentPackRemoteService` bao quát đầy đủ HSK 1 đến HSK 6.
- Bổ sung cơ chế Fallback Offline trong `ContentPacksNotifier.installPack`: Nếu tải qua CDN GitHub gặp sự cố mất mạng hoặc môi trường kiểm thử không có Internet, ứng dụng tự động nạp từ asset gói JSON cục bộ (`assets/data/content_packs/hsk{N}/...`).
- Cập nhật `pubspec.yaml` đồng bộ các thư mục asset HSK 4, HSK 5, HSK 6.

### 2.2. Onboarding Interceptor (`onboarding_flow_screen.dart` & `onboarding_personalization_screen.dart`)
- **Bộ chọn cấp độ HSK trong Personalization**: Bổ sung `initialHskLevel`, ChoiceChip HSK 1–6 và truyền `targetHskLevel` qua `PersonalizationData`.
- **Hộp thoại Chặn Onboarding chuẩn sư phạm**:
  - **Tiêu đề:** `"Bạn đã sẵn sàng học HSK $currentHsk!"`
  - **Nội dung:** `"Để học ngay giáo trình và từ vựng chuẩn HSK $currentHsk, ứng dụng cần tải gói học liệu (~350KB - 1.5MB). Bạn muốn tải ngay bây giờ không?"`
  - **Nút hành động 1 ("Tải ngay & Bắt đầu"):** Hiển thị Modal tiến trình tải trực quan (Circular + LinearProgressIndicator kèm phần trăm %), thực thi nạp gói và lưu cấu hình.
  - **Nút hành động 2 ("Để sau"):** Giữ nguyên cấu hình HSK $currentHsk, điều hướng vào màn hình Lộ trình học kèm SnackBar hướng dẫn trực quan.

### 2.3. Chuẩn hóa vòng đời bài học (`lesson_flow_providers.dart` & `lesson_study_screen.dart`)
- Chuyển đổi provider sang dạng `autoDispose`:
  ```dart
  final lessonFlowNotifierProvider =
      NotifierProvider.autoDispose.family<LessonFlowNotifier, LessonFlowState, String>(
    (lessonId) => LessonFlowNotifier(lessonId),
  );
  ```
- Thêm phương thức `resetToStep(LessonStep step)` vào `LessonFlowNotifier`.
- Trong `LessonStudyScreen`: Mặc định mở luôn xuất phát từ `LessonStep.warmup` (Chặng 1). Nếu học viên nhấn nút "Tiếp tục" hoặc truyền `resumeStep`, hệ thống mới kích hoạt chuyển sang chặng tương ứng.

---

## 3. KẾT QUẢ KIỂM THỬ TỰ ĐỘNG

| Bộ kiểm thử | File test | Số ca kiểm thử | Kết quả |
|---|---|---|---|
| **Lifecycle & Anti-Cheating** | `test/features/curriculum/lesson_flow_providers_test.dart` | 9/9 tests | **PASS** |
| **Download Interceptor & HSK Selection** | `test/features/onboarding/onboarding_download_interceptor_test.dart` | 3/3 tests | **PASS** |
| **Onboarding Flow Integration** | `test/features/onboarding/onboarding_flow_test.dart` | 6/6 tests | **PASS** |
| **Phân tích tĩnh Lint/Static Analysis** | `flutter analyze lib/` | 0 errors, 0 warnings | **PASS** |

### Các ca kiểm thử tiêu biểu đã thẩm định:
1. `Standardized Lifecycle: Opening lesson always starts at Stage 1 (warmup)` -> PASS.
2. `Standardized Lifecycle: resetToStep allows programmatic step switching` -> PASS.
3. `Standardized Lifecycle: autoDispose resets state when subscriber is disposed` -> PASS.
4. `OnboardingPersonalizationScreen displays HSK chips and allows HSK 3+ selection` -> PASS.
5. `Interceptor Dialog displays when currentHsk >= 3 and pack is uninstalled` -> PASS.
6. `isHskLevelInstalledProvider returns true for HSK 1 and HSK 2 without DB check` -> PASS.

---

## 4. BẢN ĐỒ FILE THAY ĐỔI

1. `pubspec.yaml`
2. `lib/features/content_packs/data/content_pack_remote_service.dart`
3. `lib/features/content_packs/presentation/providers/content_packs_providers.dart`
4. `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart`
5. `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
6. `lib/features/onboarding/presentation/providers/onboarding_providers.dart`
7. `lib/features/onboarding/presentation/screens/onboarding_personalization_screen.dart`
8. `lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart`
9. `test/features/curriculum/lesson_flow_providers_test.dart`
10. `test/features/onboarding/onboarding_download_interceptor_test.dart`
