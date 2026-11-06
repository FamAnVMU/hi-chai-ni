# KNOWLEDGE EXPANSION – QA REPORT (Thread 5 · Prompt 5.1)

- **Ngày cập nhật:** 2026-11-06
- **Nhánh:** `main` (Sau `CORE-HSK46-VI-002` & `LEARN-HSK46-VI-002`, HEAD `14969bc`)
- **Phạm vi:** Kiểm thử tích hợp 8 bộ test suites, kịch bản nâng cấp Zero Progress Loss, kiểm toán toàn vẹn tham chiếu & đối soát pipeline làm giàu song ngữ Trung – Việt HSK 4–6.

---

## 1. Tổng hợp kết quả nghiệm thu

| Tiêu chí nghiệm thu | Kết quả | Chi tiết |
|---|---|---|
| `flutter analyze lib/ test/` | ✅ **PASS (0 issues)** | `No issues found! (ran in 13.3s)` |
| 8 test suites bắt buộc | ✅ **PASS (219/219)** | `01:55 +219: All tests passed!`, 0 flaky tests |
| Zero Progress Loss khi cài gói HSK 4–6 | ✅ **PASS (3/3)** | Bảo toàn 100% 50 thẻ SRS, 10 bài học HSK 1–3, mục tiêu, hồ sơ, chuỗi 7 ngày streak & chống lệch cấp độ (Level-Drift Guard) |
| Toàn vẹn tham chiếu (Referential Integrity) | ✅ **PASS (9/9)** | 0 segment treo, 0 thiếu Pinyin/nghĩa Việt, 100% SHA-256 canonical khớp 3 chiều |
| Pipeline nạp ngữ liệu Trung – Việt (`CORE-HSK46-VI-002`) | ✅ **PASS (17/17 Gates)** | Nạp 50 ứng viên `APPROVED`, chặn an toàn 1 ứng viên sót tiếng Anh (`简历`) và cách ly 3.764 ứng viên `TRANSLATION_REVIEW`/`SENSE_REVIEW` chờ người thật duyệt |

---

## 2. Kết quả chạy 8 bộ Test Suites bắt buộc

Lệnh thực thi:
```powershell
flutter test test/features/reading/ test/features/curriculum/ test/features/content_packs/ `
  test/features/vocabulary_srs/ test/features/home/ test/features/hanzi_writing/ `
  test/features/sentences/ test/features/dictionary/
```

| STT | Bộ kiểm thử (Test Suite) | Số lượng test | Trạng thái |
|---|---|---|---|
| 1 | `test/features/reading/` | 24 | ✅ PASS |
| 2 | `test/features/curriculum/` | 48 | ✅ PASS |
| 3 | `test/features/content_packs/` | 23 | ✅ PASS |
| 4 | `test/features/vocabulary_srs/` | 20 | ✅ PASS |
| 5 | `test/features/home/` | 50 | ✅ PASS |
| 6 | `test/features/hanzi_writing/` | 18 | ✅ PASS |
| 7 | `test/features/sentences/` | 17 | ✅ PASS |
| 8 | `test/features/dictionary/` | 19 | ✅ PASS |
| **Tổng** | **8 Feature Suites** | **219 / 219** | ✅ **100% PASS** |

---

## 3. Kiểm thử kịch bản nâng cấp & Zero Progress Loss

* **Tệp kiểm thử:** [`test/features/content_packs/zero_progress_loss_upgrade_test.dart`](../test/features/content_packs/zero_progress_loss_upgrade_test.dart)
* **Kịch bản mô phỏng trên SQLite v20 thực tế:**
  1. Cài đặt gói HSK 1, 2, 3.
  2. Khởi tạo dữ liệu học viên đang học:
     - **50 từ vựng SRS** ở trạng thái `review` (bao gồm cả 5 từ đa cấp `往`, `等`, `对`, `过`, `爱情`), kèm 50 bản ghi `learner_evidence`.
     - **10 bài học HSK 1–3 đã hoàn thành** (`lesson_progress` + `curriculum_lessons.status = 'completed'`).
     - **1 mục tiêu học tập** (`learner_goals`) và **1 hồ sơ cá nhân** (`user_profiles`).
     - **Chuỗi 7 ngày học liên tiếp (streak)** trong `learning_activities` được tính qua `StreakCalculator`.
     - **20 bản ghi thành thạo** trong `curriculum_mastery`.
  3. Nạp 3 Content Packs `hsk4_pack_v1.json`, `hsk5_pack_v1.json`, `hsk6_pack_v1.json`.
  4. **Kết quả đối chiếu Snapshot trước & sau khi nạp:**
     - Toàn bộ 7 bảng tiến độ học viên (`srs_items`, `learner_evidence`, `lesson_progress`, `learner_goals`, `user_profiles`, `learning_activities`, `curriculum_mastery`) **giống hệt 100% từng dòng và từng trường**.
     - Chuỗi streak giữ nguyên **7 ngày**.
     - 50/50 thẻ SRS vẫn JOIN chính xác với bảng `vocabularies`.
     - **Level-Drift Guard** trong [`content_pack_manager.dart`](../lib/features/content_packs/data/content_pack_manager.dart) bảo vệ các từ vựng đã học ở HSK 1–3 (`往`, `等`, `对`, `过`, `爱情`) không bị ghi đè `hsk_level` lên 4 khi nạp gói HSK 4.

---

## 4. Kiểm toán Toàn vẹn Tham chiếu & Checksum SHA-256

* **Script kiểm toán:** [`tool/qa/audit_referential_integrity.py`](../tool/qa/audit_referential_integrity.py)
* **Báo cáo JSON:** [`audit/referential_integrity_result.json`](referential_integrity_result.json) & [`audit/hsk46_vi_enrichment/final_checksum_report.json`](hsk46_vi_enrichment/final_checksum_report.json)

### 4.1. Các hạng mục kiểm toán bắt buộc (C1–C7)

| Mã | Hạng mục kiểm tra | Kết quả |
|---|---|---|
| `C1` | Tính duy nhất của `unit_id`, `lesson_id`, `segment_id` trên cả 6 gói HSK 1–6 | ✅ PASS (0 trùng) |
| `C2` | Tính duy nhất của `content_id` trên toàn bộ 966 `content_items` | ✅ PASS (0 trùng) |
| `C3` | Không có `segment` nào trỏ tới `content_ref_id` không tồn tại | ✅ PASS (0 tham chiếu treo) |
| `C4` | Mọi `content_item.curriculum_id` đều khớp với curriculum của gói | ✅ PASS (0 lệch) |
| `C5` | Mọi từ vựng trong `hsk{4,5,6}_vocabularies.json` & fixture 5.000 từ đều có Pinyin và `meaning_vi` | ✅ PASS (0 thiếu) |
| `C6` | Mọi từ vựng trong `content_json` của bài học đều có đủ `simplified`, `pinyin`, `meaning_vi` | ✅ PASS (0 thiếu) |
| `C7` | Mọi câu hỏi Exit Exam đều có `answer_index` hợp lệ trong mảng `options` | ✅ PASS (0 lỗi) |

### 4.2. Đối chiếu Canonical SHA-256 (3 chiều: Pack Manifest ↔ CDN ↔ `ContentPackRemoteService`)

| Gói học liệu | Số Units | Số Bài học | Số Segments | Dung lượng (Compact) | Canonical SHA-256 | Trạng thái |
|---|---:|---:|---:|---:|---|---|
| `hsk4_pack_v1.json` | 5 | 30 | 180 | 683.297 B | `0b4cbbcb3adeba1ae08d4b3b0952c0803923f3c007509736e7c66c2150bda492` | ✅ Khớp 100% |
| `hsk5_pack_v1.json` | 6 | 36 | 216 | 1.036.492 B | `fb9786804d342ac9e162a1c017a8a4eb87fbf8269f8e8308a19cc12fcd1b720d` | ✅ Khớp 100% |
| `hsk6_pack_v1.json` | 10 | 50 | 300 | 1.544.224 B | `0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf` | ✅ Khớp 100% |

---

## 5. Kết quả kiểm toán đợt làm giàu ngữ liệu Trung – Việt (`CORE-HSK46-VI-002` & `LEARN-HSK46-VI-002`)

Tuân thủ nguyên tắc **không tự bịa đặt, không dùng bản dịch máy chưa qua kiểm chứng**, Thread 1 và Thread 2 đã thiết lập cơ chế kiểm soát 17 chốt chặn (`tool/data_ingestion/replace_en_examples_with_vi.py`):

1. **Đã nạp thành công (50 mục `APPROVED`)**: Toàn bộ 50 câu song ngữ Trung – Việt có nguồn đối chiếu người thật từ Tatoeba (`cmn-vie`) đã được chuẩn hóa dấu câu Pinyin và nạp vào `assets/data/hsk{4,5,6}_vocabularies.json` cùng 3 Content Packs.
2. **Chặn tự động lỗi dữ liệu (`CHECK_16_RESIDUAL_ENGLISH_GLOSS`)**: Phát hiện và chặn 1 ứng viên (`简历` - `CAND_HSK5_lesson_5_14_seg_5_14_2_简历_9`) do còn sót câu tiếng Anh `"Prepare your résumé before the interview."`.
3. **Cách ly an toàn trong Staging (`human_review_required.json` & `unresolved_mappings.jsonl`)**:
   - **3.764 ứng viên** (`3.741 TRANSLATION_REVIEW` + `23 SENSE_REVIEW`) chưa có bản dịch người thật trong Tatoeba `cmn-vie` (và các nguồn TED2020 `CC BY-NC-ND`, OpenSubtitles, AnkiWeb bị loại ở cổng bản quyền OER) đã được giữ lại ở staging chờ duyệt, không tự động ghi đè bản dịch mẫu vào dữ liệu sản phẩm.
   - **575 từ vựng học thuật** (17 từ HSK 5, 558 từ HSK 6) chưa có câu ví dụ trong kho mở được ghi nhận rõ trong `unresolved_mappings.jsonl` (`NO_VALID_PARALLEL_EXAMPLE`).
   - Do đó, trong gói sản phẩm hiện tại, các câu chưa có bản dịch tiếng Việt từ người thật vẫn giữ nguyên câu ví dụ tiếng Trung chuẩn kèm giải nghĩa tiếng Anh gốc từ Tatoeba (`W1_english_gloss_in_pack_examples`: HSK 4: 572, HSK 5: 1.016, HSK 6: 752) — đảm bảo 0% nội dung bịa đặt hoặc dịch máy kém chất lượng lọt vào ứng dụng.
