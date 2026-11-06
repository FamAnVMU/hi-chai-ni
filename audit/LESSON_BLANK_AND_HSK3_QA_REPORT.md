# LESSON BLANK & HSK 3+ DOWNLOAD UX – QA REPORT (Thread 5)

- **Ngày thực hiện:** 2026-11-06
- **Vai trò:** Senior QA & Test Automation Lead (Thread 5)
- **Mã tác vụ:** `BUG-CURRICULUM-BLANK-01`, `FEAT-HSK3-DOWNLOAD-NOTICE`, `FEAT-ONBOARDING-HSK3-GUIDE`
- **Phạm vi kiểm thử:**
  1. Kiểm thử biên & chống màn hình trắng trình học bài (`LessonStudyScreen` & `lessonFlowNotifierProvider`).
  2. Kiểm thử Hero Download Card trên giáo trình HSK 3–6 chưa tải (`CurriculumSyllabusScreen`).
  3. Kiểm thử Interceptor & Dialog hướng dẫn tải gói HSK 3+ ngay trong luồng Onboarding (`OnboardingFlowScreen`).
  4. Kiểm toán tĩnh toàn bộ mã nguồn (`flutter analyze lib/ test/`) & kiểm thử hồi quy toàn dự án (`flutter test`).

---

## 1. Tổng hợp kết quả nghiệm thu (Executive Summary)

| Hạng mục nghiệm thu | Kết quả | Chi tiết xác thực |
|---|---|---|
| `flutter analyze lib/ test/` | ✅ **PASS (0 issues)** | `No issues found!` — 0 lỗi biên dịch, 0 cảnh báo lint trên cả `lib/` và `test/` |
| `test/features/curriculum/lesson_study_empty_boundary_test.dart` | ✅ **PASS (7/7)** | Đảm bảo không crash với payload rỗng/thiếu trường/sai kiểu/`_Map<dynamic, dynamic>`, và tự động reset về bước Khởi động khi mở lại bài học |
| `test/features/curriculum/curriculum_syllabus_download_card_test.dart` | ✅ **PASS (5/5)** | Đảm bảo Hero Download Card hiển thị ngay đầu trang (trên thẻ Thi tốt nghiệp) cho HSK 3, 4, 5, 6 chưa tải và ẩn đi khi đã cài đặt |
| `test/features/onboarding/onboarding_hsk3_download_prompt_test.dart` | ✅ **PASS (4/4)** | Đảm bảo hộp thoại nhắc tải gói HSK 3+ xuất hiện trước khi hoàn tất Onboarding khi gói chưa cài, và tự bỏ qua cho HSK 1–2 hoặc khi gói đã cài |
| Toàn bộ Test Suites của dự án (`flutter test`) | ✅ **PASS (100%)** | **700/700 tests PASS** trên toàn bộ `test/core`, `test/features`, `test/pipeline`, `test/regression`, `test/benchmark` |

---

## 2. Chi tiết 3 Bộ Test Автоmation Mới

### 2.1. `test/features/curriculum/lesson_study_empty_boundary_test.dart` (7/7 PASS)

Kiểm thử toàn diện ranh giới dữ liệu và vòng đời trạng thái của `LessonStudyScreen`:

| STT | Kịch bản kiểm thử (Test Case) | Kỳ vọng | Kết quả |
|---|---|---|---|
| 1 | `Lesson with zero segments does not crash` | Bài học có `segments: []` không ném ngoại lệ, hiển thị fallback thân thiện trên cả 6 bước | ✅ PASS |
| 2 | `Segments with empty payloads do not crash on any step` | Cả 6 segment (`warmup`, `vocabulary`, `grammar`, `dialogue`, `practice`, `masteryCheck`) có `contentPayload: {}` đều render an toàn | ✅ PASS |
| 3 | `Payloads with wrong types or missing fields do not crash` | Payload chứa kiểu dữ liệu sai (`{'intro': 123}`, phần tử mảng không phải Map, `null`, thiếu trường bắt buộc) không gây `TypeError` | ✅ PASS |
| 4 | `Untyped Map<dynamic,dynamic> items (JSON from SQLite) still render` | Dữ liệu giải mã từ SQLite có kiểu runtime `_Map<dynamic, dynamic>` hiển thị đầy đủ từ vựng (`学` - `học`) và ngữ pháp (`Điểm ngữ pháp thử`) | ✅ PASS |
| 5 | `Re-opening a half-finished lesson starts again at the warmup step` | Học dở đến Bước 3 (Ngữ pháp) rồi thoát ra và mở lại bài học: tự động khởi đầu lại từ Bước 1 (Warmup) | ✅ PASS |
| 6 | `lessonFlowNotifierProvider is auto-disposed and starts at warmup` | Khi đóng listener cuối cùng, provider tự hủy state và khởi tạo lại ở `LessonStep.warmup` | ✅ PASS |
| 7 | `resumeStep opens the lesson at the requested step` | Truyền `resumeStep: LessonStep.vocabulary` mở đúng bước yêu cầu mà không lỗi | ✅ PASS |

> **Phát hiện & Vá lỗi bổ sung trong quá trình QA:**
> - Phát hiện `LessonWarmupView` ép kiểu cứng `segment?.contentPayload?['intro'] as String?` và `LessonVocabView` ép kiểu cứng `audio_uri as String?` có thể ném `_TypeError` nếu payload chứa kiểu nguyên thủy khác `String`. Đã vá an toàn bằng helper `_asText()` và kiểm tra `is String`.

---

### 2.2. `test/features/curriculum/curriculum_syllabus_download_card_test.dart` (5/5 PASS)

Kiểm thử hiển thị thông báo tải học liệu cho các cấp độ HSK 3–6 chưa cài đặt trên `CurriculumSyllabusScreen`:

| STT | Kịch bản kiểm thử (Test Case) | Kỳ vọng | Kết quả |
|---|---|---|---|
| 1–4 | `HSK {3, 4, 5, 6} without units shows download card above exit exam` | Hiển thị tiêu đề `"Chưa tải giáo trình HSK $level"`, nút `"Tải gói học liệu HSK $level ngay"`, icon `Icons.cloud_download_rounded`, và tọa độ `dy` của Card tải học liệu nằm **phía trên** thẻ `"Thi tốt nghiệp HSK $level"` | ✅ PASS (4/4) |
| 5 | `Installed curriculum hides the download card` | Khi `units` đã có dữ liệu bài học, ẩn hoàn toàn Card tải học liệu và hiển thị danh sách Chủ đề / Bài học bình thường | ✅ PASS |

---

### 2.3. `test/features/onboarding/onboarding_hsk3_download_prompt_test.dart` (4/4 PASS)

Kiểm thử luồng Interceptor tải gói học liệu khi người dùng chọn bắt đầu từ HSK 3+ ở lần đầu khởi động ứng dụng:

| STT | Kịch bản kiểm thử (Test Case) | Kỳ vọng | Kết quả |
|---|---|---|---|
| 1 | `Starting at HSK 3 shows download dialog before completing onboarding` | Chọn xuất phát HSK 3 (chưa cài gói) hiển thị Dialog `"Bạn đã sẵn sàng học HSK 3!"` với 2 hành động `"Tải ngay & Bắt đầu"` và `"Để sau"` **trước khi** `completePersonalization` kết thúc Onboarding | ✅ PASS |
| 2 | `Starting at HSK 5 also shows the prompt with the right level` | Chọn xuất phát HSK 5 hiển thị đúng thông điệp cho cấp độ HSK 5 (`"Bạn đã sẵn sàng học HSK 5!"`) | ✅ PASS |
| 3 | `Starting at HSK 1 completes without any download prompt` | Chọn xuất phát HSK 1 (gói có sẵn trong máy) hoàn tất thẳng vào ứng dụng mà không hiện hộp thoại tải gói | ✅ PASS |
| 4 | `Starting at HSK 3 with the pack already installed skips the prompt` | Khi `isHskLevelInstalledProvider(3)` trả về `true`, hệ thống bỏ qua hộp thoại và vào thẳng màn hình chính | ✅ PASS |

---

## 3. Đồng bộ Contract Liên Thread & Kiểm toán Toàn Dự Án

Trong quá trình kiểm thử tích hợp giữa Thread 1, Thread 2, Thread 4 và Thread 5, QA đã phát hiện và khắc phục triệt để các điểm lệch contract sau:

1. **`ContentPackRemoteService` & `content_packs_providers.dart` (Contract Thread 1 ↔ Thread 2):**
   - Khôi phục đầy đủ `isHskLevelInstalled(int hskLevel)`, `getHskPackManifest(int hskLevel)`, `contentPackRemoteServiceProvider`, `hskPackMetadataProvider` cùng cơ chế kiểm tra SHA-256 canonical cho các gói HSK 4–6.
2. **`OnboardingNotifier` & `LearningPathType` (Contract Thread 1 ↔ Thread 2 ↔ Thread 3):**
   - Hợp nhất tham số `targetHskLevel` (từ Thread 2) với `LearningPathType` và `keyLearningPathType` (từ Thread 1/3) trong `OnboardingState` và `OnboardingNotifier.completePersonalization`.
3. **`lesson_flow_providers.dart` (Contract Thread 3 ↔ Thread 4):**
   - Bổ sung import `hasCompletedLessonsProvider` và loại bỏ import dư thừa để đạt `0 issues` khi chạy `flutter analyze`.

### Bảng tổng hợp kết quả chạy Test toàn dự án

| Nhóm kiểm thử | Số lượng tests | Trạng thái |
|---|---:|---|
| Cụm Curriculum, Content Packs, Onboarding, Roadmap, Learning (bao gồm 3 file test mới) | 158 | ✅ 100% PASS |
| Cụm Core, Pipeline, Regression, Benchmark, Home, SRS, Reading, Dictionary, Hanzi, Sentences, Grammar, Practice, Listening, Pronunciation, Shadowing, Placement Test, Profile, Settings, AI Tutor, AppShell | 542 | ✅ 100% PASS |
| **Tổng cộng toàn dự án** | **700 / 700** | ✅ **100% PASS (0 Flaky)** |

---

## 4. Kết luận Nghiệm thu (Sign-off)

- **Trạng thái:** **PASSED — SẴN SÀNG PHÁT HÀNH (RELEASE READY)**.
- Toàn bộ 3 lỗi và yêu cầu trải nghiệm người dùng (Màn hình bài học trắng, Thông báo tải học liệu HSK 3+ trên giáo trình/lộ trình, Hướng dẫn tải học liệu khi chọn xuất phát từ HSK 3+ trong Onboarding) đã được xác minh tự động bằng Widget & Integration Tests với tỷ lệ **100% PASS** và **0 lỗi phân tích tĩnh**.
