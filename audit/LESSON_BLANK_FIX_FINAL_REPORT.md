# Báo Cáo Nghiệm Thu Toàn Diện: Khắc Phục Lỗi Màn Hình Bài Học Không Hiển Thị & Tự Động Phục Hồi Học Liệu (v1.0.15)

- **Ngày thực hiện**: 2026-11-06
- **Phiên bản phát hành**: `v1.0.15+15`
- **Mục tiêu**: Xóa bỏ vĩnh viễn lỗi màn hình bài học trắng (Blank Screen), chống kẹt trạng thái vòng đời, bảo vệ giao diện bằng Error Boundary, tự phục hồi học liệu ngoại tuyến (Self-Healing Ingestion) khi nâng cấp ứng dụng.

---

## 1. Bảng Tổng Hợp Các Điểm Nghẽn Kỹ Thuật & Giải Pháp Triệt Để

| # | Điểm Nghẽn / Nguyên Nhân Gốc Rễ | Hiện Tượng Quan Sát Được | Giải Pháp Đã Triển Khai | Trạng Thái |
|---|---|---|---|:---:|
| 1 | **Stale Flow State**: `LessonStudyScreen` chỉ gọi `resetToStep` khi có `resumeStep != null`. Khi bấm "Bắt đầu" từ Lộ trình / Trang chủ, nếu bài học trước đó đã xong hoặc dở dang, provider giữ nguyên `masteryCheck` (chặng 5/6). | Màn hình nhảy thẳng vào bước cuối hoặc không khớp dữ liệu của chặng đầu tiên. | Bổ sung `WidgetsBinding.addPostFrameCallback` trong `initState` luôn reset về `widget.resumeStep ?? LessonStep.warmup`. | ✅ Đã khắc phục & verified |
| 2 | **Unbounded Bottom Navigation Layout Bug**: `Container` bọc `bottomNavigationBar` trong `LessonStudyScreen` không gán chiều cao cố định, khiến widget con (`Center` trong `HiButton`) nở rộng chiếm toàn bộ chiều cao màn hình (`2400.0`). | Thân màn hình `Scaffold.body` bị chèn ép / đè khuất hoàn toàn, tạo cảm giác trắng tinh từ tọa độ Y=38 đến Y=504. | Gán cố định `height: 64` cho `Container` của `bottomNavigationBar`, giải phóng 100% không gian hiển thị cho `body`. | ✅ Đã khắc phục & verified |
| 3 | **Stale Lesson Passing**: `LessonStudyScreen` chỉ nhận `CurriculumLesson` tĩnh ban đầu, không truy vấn lại SQLite khi các segments chưa kịp load hoặc danh sách segments bị rỗng. | Khi người dùng mở bài học từ danh sách tóm tắt, các view con nhận 0 segments và render `LessonContentEmptyState`. | Xây dựng `lessonDetailProvider = FutureProvider.family` nạp dữ liệu phản ứng thời gian thực từ SQLite; truyền `currentLesson` vào toàn bộ 6 view chặng học. | ✅ Đã khắc phục & verified |
| 4 | **Startup Ingestion Blindspot**: `_checkPackNeedsImport` trong `AppStartupNotifier` chỉ đếm số bài học (`tableCurriculumLessons`). Nếu phiên bản cũ đã tạo bài học nhưng chưa nạp segments, lần nâng cấp sau bỏ qua việc nạp lại gói. | Các bản cài đặt nâng cấp từ bản cũ có bài học nhưng 0 segments trong SQLite. | Bổ sung điều kiện kiểm tra `tableLessonSegments`. Nếu số segments = 0, ứng dụng tự động kích hoạt nạp lại gói bundled mà không làm mất tiến độ học tập. | ✅ Đã khắc phục & verified |
| 5 | **SQL Join Casing & Whitespace Mismatch**: Câu lệnh JOIN giữa `lesson_segments` và `content_items` dùng so khớp chuỗi tuyệt đối `ls.content_ref_id = ci.content_id`. | Nếu có khoảng trắng thừa hoặc khác biệt chữ hoa/thường, `content_payload` trả về NULL. | Cập nhật câu lệnh: `LEFT JOIN tableContentItems ci ON UPPER(TRIM(ls.content_ref_id)) = UPPER(TRIM(ci.content_id))`. | ✅ Đã khắc phục & verified |
| 6 | **Release Mode Silent Blank Screen**: Trong chế độ Release của Flutter, khi có bất kỳ ngoại lệ nào phát sinh trong `build()`, Flutter hiển thị `SizedBox.shrink()` thay vì báo lỗi. | Màn hình hiển thị màu trắng xoá hoàn toàn, người dùng bị kẹt không thoát được. | Tạo `LessonStepErrorBoundary` bao bọc từng chặng học, hiển thị thẻ cảnh báo thân thiện và nút "Bỏ qua bước này" để tiếp tục học. | ✅ Đã khắc phục & verified |
| 7 | **AppBar Contrast**: Tiêu đề bài học và phụ đề tiến độ không gán màu chữ tương phản rõ rệt. | Chữ bị mờ trên nền sáng của một số giao diện máy. | Chuẩn hóa màu chữ theo Clean Modern White tokens: `AppColors.primaryText` và `AppColors.secondaryText`. | ✅ Đã khắc phục & verified |

---

## 2. Kết Quả Kiểm Thử Tự Động (Automated Testing Evidence)

- **Curriculum Suite (`test/features/curriculum/`)**: **75/75 tests PASS (100%)**
  - `lesson_study_lifecycle_test.dart`: 4/4 PASS
  - `lesson_detail_reactive_test.dart`: 2/2 PASS
  - `lesson_step_error_boundary_test.dart`: 6/6 PASS
  - `lesson_study_empty_boundary_test.dart`: 7/7 PASS
  - `curriculum_syllabus_download_card_test.dart`: 1/1 PASS
  - `curriculum_ui_widget_test.dart`: 5/5 PASS
  - `curriculum_payload_and_id_test.dart`: 6/6 PASS
  - `content_pack_loader_test.dart`: 4/4 PASS
  - `real_level_exit_exam_test.dart`: 5/5 PASS
- **Content Packs & Onboarding Suites**: **57/57 tests PASS (100%)**
  - `pack_upgrade_integrity_test.dart`: 3/3 PASS
  - `content_pack_normalization_test.dart`: 7/7 PASS
  - `onboarding_integration_and_route_guard_test.dart`: 12/12 PASS
  - `hsk456_pack_install_test.dart`: 6/6 PASS
- **Kiểm tra mã nguồn tĩnh (`flutter analyze lib/ test/`)**: **0 issues found** (Hoàn toàn sạch cảnh báo).

---

## 3. Bản Phân Phối Build Release APK v1.0.15

1. `release-apk/hi-chinese-v1.0.15-arm64-v8a.apk` (Dành cho điện thoại Android 64-bit hiện đại)
2. `release-apk/hi-chinese-v1.0.15-armeabi-v7a.apk` (Dành cho thiết bị Android 32-bit)
3. `release-apk/app-release.apk` (Bản cài đặt release mặc định)
