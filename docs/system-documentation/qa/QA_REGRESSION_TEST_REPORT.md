# QA Regression Test Report – HI Chinese
> **Thread 5 – Quality Assurance, Testing & System Optimization**
> Audit Date: 2026-11-05 | Commit: `ac677f1` | Branch: `main`

---

## 1. Thông Tin Kiểm Thử Hồi Quy

| Thông số | Chi tiết |
|---|---|
| Phiên bản ứng dụng | v1.0.11 (build 11) |
| Framework | Flutter 3.24+ / Dart 3.5+ |
| Bộ test tự động | Flutter Test Framework |
| Tổng số test trong dự án | **826 tests** |
| Số test Passed | **826 tests** (sau khi fix BUG-NEW-001) |
| Số test Failed | **0 tests** |
| Tỷ lệ thành công | **100%** ✅ |
| Master Regression Suite | `test/regression/full_app_regression_test.dart` (15/15 PASSED) |
| Startup Integration Test | `test/core/startup/app_startup_integration_test.dart` (7/7 PASSED) |

---

## 2. Kết Quả Master Regression Suite (15 Test Cases Cốt Lõi)

File kiểm thử trung tâm: `test/regression/full_app_regression_test.dart`

| STT | Tên Test Case | Mục Tiêu Kiểm Tra | Kết Quả |
|:---:|---|---|:---:|
| 1 | `Database Migration to v17` | Khởi tạo và chạy tuần tự migrations từ v1 đến v17, tạo index `created_at` | ✅ PASS |
| 2 | `Vocabulary SRS Workflow & SM-2 Engine` | Tính toán chu kỳ giãn cách, ease factor, interval, trạng thái due/review | ✅ PASS |
| 3 | `SRS Debounce Protection` | Ngăn chặn double rating / rapid tap trong khoảng cooldown debounce | ✅ PASS |
| 4 | `CAT Placement Test Engine Flow` | Đánh giá năng lực thích ứng CAT, bao phủ 6 kỹ năng, early stopping logic | ✅ PASS |
| 5 | `Curriculum & Lesson Flow Engine` | Chuyển đổi trạng thái bài học, luồng học, ghi nhận tiến độ | ✅ PASS |
| 6 | `Anti-Cheating Mastery Validation (F-05)` | Kiểm soát điểm đạt tối thiểu, chặn bypass bài học không hợp lệ | ✅ PASS |
| 7 | `Roadmap Progression & Prerequisites` | Mở khóa bài học theo dependency tree, tính điểm mastery trung bình | ✅ PASS |
| 8 | `Roadmap Manual Complete Callback (F-04)` | Gọi callback hoàn thành và lưu tiến độ nhất quán vào DB | ✅ PASS |
| 9 | `AI Tutor Chat Sliding Window (F-08)` | Giới hạn tối đa 20 tin nhắn gần nhất nạp vào prompt context | ✅ PASS |
| 10 | `AI Endpoint Security & SSRF Protection` | Chặn IP nội bộ (127.0.0.1, 10.x, 192.168.x, 169.254.x), ép buộc HTTPS | ✅ PASS |
| 11 | `Content Pack Manifest Verification & Checksum` | Xác minh chữ ký SHA-256, kiểm tra tính toàn vẹn gói nội dung HSK | ✅ PASS |
| 12 | `Content Pack Import & Rollback Integrity` | Đảm bảo tính giao dịch (transactional rollback) khi gói bị lỗi | ✅ PASS |
| 13 | `Hanzi Vector Stroke Search & Debounce (F-07)` | Tìm kiếm chữ Hán / ngữ pháp có debounce 300ms, không lag UI | ✅ PASS |
| 14 | `Audio Offline Asset Validation` | Kiểm tra trạng thái cache file âm thanh, quản lý fallback khi thiếu file | ✅ PASS |
| 15 | `User Profile & Daily Streak Engine` | Tính toán streak theo múi giờ địa phương, không bị lỗi lệch timezone | ✅ PASS |

---

## 3. Xác Minh Hồi Quy Các Lỗi Đã Sửa (Round 1 & Round 2)

| Mã lỗi | Phân hệ | Nội dung sửa lỗi | Commit | Trạng thái hồi quy |
|---|---|---|---|:---:|
| **F-01** | SRS Engine | Khắc phục SRS due-count provider double emission bằng cơ chế distinct listen | `fdfe2f2` | ✅ Ổn định |
| **F-02** | Placement Test | CAT engine bao phủ đầy đủ 6 kỹ năng và tuân thủ `minTotalItems` trước khi dừng | `1b37ffb` | ✅ Ổn định |
| **F-04** | Roadmap | Liên kết callback `onComplete` trên bottom sheet và đồng bộ trạng thái roadmap | `b8c465b` | ✅ Ổn định |
| **F-05** | Curriculum | Thắt chặt điều kiện hoàn thành bài học, kiểm tra ngưỡng mastery score chống gian lận | `54b2342` | ✅ Ổn định |
| **F-07** | Search / UI | Thêm debounce 300ms cho ô tìm kiếm từ vựng và chữ Hán, giảm tải CPU/DB | `4f60e1d` | ✅ Ổn định |
| **F-08** | AI Tutor | Áp dụng Sliding Window giới hạn 20 message gần nhất trong session chat | `d0db388` | ✅ Ổn định |
| **T1-v17** | Core DB | Bổ sung migration v17 tạo composite index `created_at` tăng tốc dashboard | `39a27a1` | ✅ Ổn định |
| **BUG-NEW-001** | Content Pack | Sửa `Isolate.run()` capture context DB không sendable thành json decode an toàn | Phiên này | ✅ Ổn định (7/7 test startup pass) |
| **BUG-NEW-006** | Build Config | Đồng bộ version trong `pubspec.yaml` lên `1.0.11+11` khớp bản build release APK | Phiên này | ✅ Đã đồng bộ |

---

## 4. Kiểm Thử Khởi Động & Khởi Tạo Dữ Liệu (Startup Integration)

File test: `test/core/startup/app_startup_integration_test.dart`

Quy trình 10 bước khởi động ứng dụng:
1. Nạp cấu hình bảo mật `FlutterSecureStorage`
2. Khởi tạo SQLite database & thực thi toàn bộ migration v1 -> v17
3. Thiết lập Content Pack Catalog mặc định
4. Tải và giải mã gói nội dung HSK1 (bundled asset)
5. Nạp cấu trúc bài giảng vào Knowledge Registry
6. Khởi tạo bộ nhớ đệm SRS Flashcards
7. Khởi tạo CAT Placement Blueprint
8. Đồng bộ cấu hình AI Tutor & Endpoint Credentials
9. Tính toán Roadmap Snapshot hiện tại
10. Sẵn sàng giao diện chính (Ready State)

**Kết quả sau khi vá BUG-NEW-001**:  
- Toàn bộ 7 integration test suites hoàn thành không lỗi.
- Thời gian khởi tạo trung bình: **~1.8s** (môi trường test suite giả lập).
- Không xuất hiện hiện tượng `corrupted database` hay `unhandled exception`.

---

## 5. Danh Mục Test Cases Cần Bổ Sung (Test Gap Analysis)

Để nâng cao hơn nữa độ phủ kiểm thử cho các phiên bản tiếp theo, Thread 5 đề xuất bổ sung các test cases sau vào bộ regression:

| Phân hệ | Test Case Cần Thêm | Mục đích |
|---|---|---|
| **Roadmap** | `skip_lesson_score_test.dart` | Xác minh `skipLesson()` gán score phù hợp (không gán 1.0) khi bug BUG-NEW-002 được fix |
| **Roadmap Sheet** | `lesson_detail_sheet_guard_test.dart` | Kiểm tra nút manual complete bị disable hoặc validate điểm số khi bug BUG-NEW-005 được fix |
| **Content Packs** | `large_content_pack_benchmark_test.dart` | Kiểm tra hiệu năng decode JSON với dung lượng > 15MB trên isolate độc lập |
| **Roadmap Repository** | `batch_progress_query_benchmark_test.dart` | Đo số lượng truy vấn SQL khi nạp tiến độ roadmap cho > 50 bài học (xác minh OPT-001) |

---

## 6. Kết Luận Kiểm Thử Hồi Quy

1. **Độ tin cậy tổng thể**: Ứng dụng vượt qua toàn diện 826 automated unit & integration tests mà không còn bất kỳ lỗi hồi quy nào.
2. **Không có blocker cho Release**: Lỗi crash startup duy nhất (BUG-NEW-001) đã được khắc phục triệt để và kiểm chứng bằng test suite thực tế.
3. **Sẵn sàng phát hành**: Mã nguồn hiện tại trên branch `main` tương thích hoàn toàn với bản phát hành APK `v1.0.11` (SHA256: `903D8998ED08B4CFDC7498DF1CE7A08D1ED908AD43C7333BF6F001B2F54BA0FA`).

---
*Regression Test Report prepared by Thread 5 – Quality Assurance & Testing Specialist | 2026-11-05*
