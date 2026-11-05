# QA Thread Action Items – HI Chinese
> **Thread 5 – Quality Assurance, Testing & System Optimization**
> Audit Date: 2026-11-05 | Commit: `ac677f1` | Branch: `main`

---

## Tổng quan

Danh sách công việc cụ thể cho từng Thread dựa trên kết quả kiểm toán QA Round 3 (2026-11-05). Tất cả action items đã được xác nhận bằng bằng chứng mã nguồn thực tế.

---

## Thread 1 – Core Engine, Database, Content Platform & Integration

### OPEN Items

#### T1-001 🔴 HIGH – Fix N+1 query trong `getLessonProgressMap()`

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-004 |
| File | `lib/features/roadmap/data/roadmap_repository.dart:75-121` |
| Mức độ | P3 – Low (nhưng ảnh hưởng UX rõ rệt với data lớn) |
| Deadline | Sprint tiếp theo |

**Việc cần làm**:
1. Refactor `getLessonProgressMap()` để batch load toàn bộ `knowledge_registry` trong 1 query
2. Build in-memory Map `aliasId → canonicalId` và `canonicalId → List<aliasId>`
3. Resolve tất cả lessonIds in-memory thay vì per-row queries
4. Viết unit test cho batch resolution (đảm bảo kết quả giống sequential)

Tham khảo: `QA_OPTIMIZATION_REPORT.md` – OPT-001 (mã ví dụ có sẵn).

---

#### T1-002 🟡 MEDIUM – Thêm size guard và logging cho JSON decode

| Trường | Giá trị |
|---|---|
| Optimization ID | OPT-003, OPT-005 |
| File | `lib/features/content_packs/data/content_pack_manager.dart` |
| Mức độ | P3 |
| Deadline | Sprint tiếp theo |

**Việc cần làm**:
1. Thêm kiểm tra kích thước `rawJson` (>20MB → dùng `compute()` với pure function)
2. Thay các `catch (_) {}` bằng `catch (e, stack) { debugPrint(...) }`
3. Đảm bảo nếu dùng `compute()`, chỉ dùng top-level static function (không capture DB state)

---

### COMPLETED Items (phiên kiểm toán này)

#### T1-003 ✅ FIXED – Isolate.run() non-sendable DatabaseExecutor

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-001 |
| File | `lib/features/content_packs/data/content_pack_manager.dart:165` |
| Fix | Thay `await Isolate.run(...)` → `json.decode(rawJson)` trực tiếp |
| Test | Startup Integration Test: 7/7 PASS ✅ |

---

## Thread 2 – Pedagogy & Learning System

### OPEN Items

#### T2-001 🔴 HIGH – Fix `skipLesson()` hardcode completion_score = 1.0

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-002 |
| File | `lib/features/roadmap/data/roadmap_repository.dart:256` |
| Mức độ | P2 – Medium |
| Deadline | Sprint tiếp theo |

**Việc cần làm**:
1. Thay `'completion_score': 1.0` bằng `'completion_score': 0.0` hoặc `null`
2. Xem xét thêm field `'skipped_at'` và xóa `'completed_at'` cho trạng thái skip
3. Viết test: `skipLesson()` không được tạo ra `completion_score >= threshold`
4. Kiểm tra tác động đến Roadmap UI (hiển thị icon skip vs complete khác nhau?)

---

#### T2-002 🟡 MEDIUM – Fix LessonDetailSheet bypass anti-cheating

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-005 |
| File | `lib/features/roadmap/presentation/widgets/lesson_detail_sheet.dart:340` |
| Mức độ | P3 – Low |
| Deadline | Sprint tiếp theo |

**Việc cần làm**:
1. Disable nút "Xác nhận hoàn thành" khi `progress == null` hoặc `progress.status == 'not_started'`
2. Nếu giữ nút, route qua `completeLesson()` với score phản ánh thực tế (không default 0.8)
3. Xem xét: có cần manual complete từ Roadmap sheet không? Nếu không, remove hẳn flow này.
4. Viết test: manual complete không tạo ra score > actual study score

---

## Thread 3 – AI Intelligence & Voice Lab

### INFORMATIONAL Items

#### T3-001 🔵 NOTED – Voice Chat không có STT/ASR thực

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-003 |
| File | `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart` |
| Mức độ | P4 – Info (design decision) |
| Action | Cần communicate rõ trong UI |

**Việc cần làm (UX fix, không phải bug fix)**:
1. **Ngắn hạn**: Cập nhật UI để hiển thị rõ "Text Mode" – không có real voice input
   - Thêm subtitle: `"Chế độ nhập văn bản (Voice AI sẽ có trong phiên bản tới)"`
   - Ẩn recording animation/indicator khi không ghi âm thực
2. **Dài hạn (Roadmap)**: Tích hợp `speech_to_text` package hoặc Gemini Live API
   - Đánh giá: `speech_to_text` (offline) vs Gemini Live API (online, chính xác hơn)
   - Thêm vào `pubspec.yaml` khi ready

**Lưu ý**: TTS (Text-to-Speech output) hoạt động tốt qua `flutter_tts`. Chỉ STT (input) là chưa có.

---

## Thread 4 – UI/UX & Mobile Presentation

### COMPLETED Items (phiên kiểm toán này)

#### T4-001 ✅ FIXED – pubspec.yaml version không khớp

| Trường | Giá trị |
|---|---|
| Bug ID | BUG-NEW-006 |
| File | `pubspec.yaml:19` |
| Fix | `version: 1.0.9+10` → `version: 1.0.11+11` |
| Trạng thái | ✅ FIXED |

---

### OPEN Items

#### T4-002 🟡 MEDIUM – Voice Chat UX indicator

| Trường | Giá trị |
|---|---|
| Optimization ID | OPT-006 |
| Mức độ | P3 |
| Deadline | Sprint tiếp theo |

Phối hợp với Thread 3 để thêm text-mode indicator trong Voice Chat screen.

---

## Thread 5 – Quality Assurance (self-items)

### Next Sprint Actions

#### T5-001 – Viết test cho skipLesson() score validation

Sau khi Thread 2 fix BUG-NEW-002:
- Viết test: `skip_lesson_score_test.dart`
- Verify: `completion_score` của skipped lesson ≠ 1.0 và ≠ default mastery threshold

#### T5-002 – Viết test cho LessonDetailSheet complete guard

Sau khi Thread 2/4 fix BUG-NEW-005:
- Viết widget test: manual complete từ sheet không bypass F-05
- Verify: button disabled khi `progress == null`

#### T5-003 – Performance test cho getLessonProgressMap()

Sau khi Thread 1 fix BUG-NEW-004:
- Viết benchmark test với 50+ lesson progress records
- Verify: query count = O(1) thay vì O(n)

#### T5-004 – Regression suite update

Thêm test cases mới vào `test/regression/full_app_regression_test.dart`:
- Startup sequence với ContentPackManager fix (đã pass)
- skipLesson score validation
- LessonDetailSheet complete guard
- N+1 query batch resolution verification

---

## Action Items Summary Dashboard

| Thread | ID | Mô tả | Mức độ | Trạng thái |
|---|---|---|---|---|
| T1 | T1-001 | N+1 query getLessonProgressMap | P3 | 🔴 OPEN |
| T1 | T1-002 | Size guard + logging JSON decode | P3 | 🔴 OPEN |
| T1 | T1-003 | Fix Isolate.run() bug | P1 | ✅ FIXED |
| T2 | T2-001 | skipLesson() score = 0.0 | P2 | 🔴 OPEN |
| T2 | T2-002 | LessonDetailSheet anti-cheat | P3 | 🔴 OPEN |
| T3 | T3-001 | Voice Chat text mode UI | P4 | 🔵 NOTED |
| T4 | T4-001 | pubspec.yaml version | P3 | ✅ FIXED |
| T4 | T4-002 | Voice Chat UX indicator | P3 | 🔴 OPEN |
| T5 | T5-001 | Test skipLesson score | P3 | ⏳ PENDING |
| T5 | T5-002 | Test LessonDetailSheet guard | P3 | ⏳ PENDING |
| T5 | T5-003 | Perf test getLessonProgressMap | P3 | ⏳ PENDING |
| T5 | T5-004 | Regression suite update | P3 | ⏳ PENDING |

---
*Thread Action Items by Thread 5 – QA Engineer | 2026-11-05*
