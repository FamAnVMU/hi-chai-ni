# KNOWLEDGE EXPANSION – QA REPORT (Thread 5 · Prompt 5.1)

- **Ngày:** 2026-11-06
- **Nhánh:** `main` (HEAD `67e09fc` + các thay đổi của báo cáo này)
- **Phạm vi:** Kiểm thử tích hợp HSK 4–6, kịch bản nâng cấp Zero Progress Loss, toàn vẹn tham chiếu.

## 1. Kết luận

| Tiêu chí nghiệm thu | Kết quả |
|---|---|
| `flutter analyze lib/ test/` | ✅ **No issues found** |
| 8 test suites bắt buộc | ✅ **219/219 pass** |
| Chạy lặp lại để phát hiện test chập chờn (flaky) | ✅ 2 lần liên tiếp đều 219/219 (01:49 và 02:02) |
| Zero Progress Loss khi cài gói HSK 4–6 | ✅ Pass **sau khi sửa 1 lỗi lệch cấp độ (xem §3)** |
| Toàn vẹn tham chiếu (segment → content_id, từ vựng có Pinyin + nghĩa Việt) | ✅ 9/9 hạng mục quan trọng đạt |

**Kết luận: ĐẠT.** Có 2 cảnh báo về chất lượng nội dung (không chặn phát hành) được chuyển cho Thread 2 (§5).

## 2. Kết quả test suites

Lệnh chạy:
```
flutter test test/features/reading/ test/features/curriculum/ test/features/content_packs/ \
  test/features/vocabulary_srs/ test/features/home/ test/features/hanzi_writing/ \
  test/features/sentences/ test/features/dictionary/
```
- Lần 1: `+219: All tests passed!`
- Lần 2: `+219: All tests passed!`

Các dòng log `Operation failed … MASTERY_L2_1`, `SHA-256 không hợp lệ (kỳ vọng 000…)` và `FormatException` trong output là **kiểm thử âm (negative test) cố ý** (`content_pack_service_test.dart` test 4, 8, 9; `content_pack_normalization_test.dart` Test E). Đây không phải lỗi.

## 3. Kịch bản nâng cấp & Zero Progress Loss

**Test mới:** [`test/features/content_packs/zero_progress_loss_upgrade_test.dart`](../test/features/content_packs/zero_progress_loss_upgrade_test.dart) (3 test)

**Dữ liệu người học giả lập** (cài trên DB thật v20 sau khi đã nạp các gói HSK 1, 2, 3):
- 50 thẻ SRS ở trạng thái `review` (interval, ease, lapses, due_at khác nhau), kèm 50 bản ghi `learner_evidence`.
- 10 bài học HSK 1–3 đã hoàn thành (`lesson_progress` + `curriculum_lessons.status = completed`).
- 1 mục tiêu đang hoạt động (`learner_goals`), 1 hồ sơ người dùng (`user_profiles`).
- Chuỗi học 7 ngày (`learning_activities`), kiểm bằng `StreakCalculator` thật.
- 20 bản ghi `curriculum_mastery`.

**Thao tác:** Cài lần lượt `hsk4_pack_v1.json`, `hsk5_pack_v1.json`, `hsk6_pack_v1.json`.

**Kết quả kiểm tra (so sánh snapshot từng dòng trước và sau):**

| Dữ liệu | Kết quả |
|---|---|
| `srs_items` (50 dòng) | ✅ Giống hệt |
| `learner_evidence` | ✅ Giống hệt |
| `lesson_progress` (10 dòng) + trạng thái bài đã hoàn thành | ✅ Giống hệt |
| `learner_goals`, `user_profiles` | ✅ Giống hệt |
| `learning_activities` + chuỗi ngày học (7 ngày) | ✅ Giống hệt |
| `curriculum_mastery` | ✅ Giống hệt |
| 50/50 thẻ SRS vẫn JOIN được với `vocabularies` | ✅ |
| Cả 6 curriculum HSK 1–6 cùng tồn tại | ✅ |

### 🐞 Lỗi phát hiện & đã sửa: lệch cấp độ từ vựng (Level Drift)

- **Hiện tượng:** 5 từ có mặt trong cả gói HSK 1–3 và gói HSK 4 (`往`, `等`, `对`, `过`, `爱情`). Khi cài gói HSK 4, `ContentPackManager` ghi đè dòng `vocab_<chữ Hán>`: `hsk_level` bị đổi từ 2/3 thành **4**, và `meaning_vi` của HSK 2 bị thay bằng nghĩa của HSK 4.
- **Tác động:** `SrsRepository` lọc thẻ ôn tập theo `v.hsk_level = ?`, nên người đang học HSK 2 sẽ **mất các thẻ này khỏi bộ ôn HSK 2** dù dữ liệu SRS vẫn còn. Đây là mất tiến độ ở phía hiển thị.
- **Cách tái hiện:** Test `Cross-level words learned at HSK 1–3 keep their original level…`, thất bại trước khi sửa (`"往" drifted from HSK 2 after HSK 4 install: hsk_level 4 instead of 2`).
- **Cách sửa:** Trong [`content_pack_manager.dart`](../lib/features/content_packs/data/content_pack_manager.dart), nếu từ đã thuộc một cấp HSK **thấp hơn** gói đang cài, thì giữ nguyên `vocabularies`, `vocabulary_senses` và `metadata_json` trong `knowledge_registry`, chỉ thêm liên kết `lesson_knowledge_items` tới bài học mới. Cài lại cùng cấp hoặc cập nhật phiên bản gói thì vẫn ghi đè như cũ.
- **Không ảnh hưởng mã băm:** Chỉ sửa code, không động vào file JSON nào, nên SHA-256 của các gói không đổi.

## 4. Toàn vẹn tham chiếu

**Script mới (chỉ đọc):** [`tool/qa/audit_referential_integrity.py`](../tool/qa/audit_referential_integrity.py). Kết quả JSON: [`audit/referential_integrity_result.json`](referential_integrity_result.json)

| Mã | Kiểm tra | Kết quả |
|---|---|---|
| C1 | ID unit / lesson / segment duy nhất trên cả 6 gói | ✅ 0 trùng |
| C2 | `content_id` duy nhất trên cả 6 gói | ✅ 0 trùng |
| C3 | Mọi `segment.content_ref_id` đều trỏ tới `content_item` có thật | ✅ 0 tham chiếu treo |
| C4 | `content_item.curriculum_id` khớp với curriculum của gói | ✅ |
| C5 | Từ vựng có Pinyin và `meaning_vi` (hsk4/5/6 + fixture 5.000 từ) | ✅ 0 thiếu |
| C6 | Từ trong `content_json` của gói có đủ chữ Hán, Pinyin, nghĩa Việt | ✅ 0 thiếu |
| C7 | `answer_index` của đề Exit Exam nằm trong phạm vi các đáp án | ✅ |

Kiểm tra bổ sung trên DB thật sau khi cài cả 6 gói (test 3): không có segment treo, không có `lesson_knowledge_items` treo, `PRAGMA foreign_key_check` rỗng, `verifyIntegrity()` trả về true cho cả 6 gói, và không có từ vựng nào thiếu Pinyin hoặc nghĩa Việt.

**Quy mô gói:**

| Gói | Units | Lessons | Segments | Content items | Câu hỏi Exit Exam |
|---|---|---|---|---|---|
| HSK 1–3 | 3 / gói | 15 / gói | 90 / gói | 90 / gói | dạng `sections` (đề cũ) |
| HSK 4 | 5 | 30 | 180 | 180 | 20 |
| HSK 5 | 6 | 36 | 216 | 216 | 25 |
| HSK 6 | 10 | 50 | 300 | 300 | 30 |

## 5. Cảnh báo nội dung (không chặn phát hành, chuyển Thread 2)

> Tuân thủ nguyên tắc dự án: **không tự dịch, không bịa nội dung**. Các mục dưới đây chỉ ghi nhận, không sửa.

1. **W1 – Câu ví dụ có phần giải nghĩa bằng tiếng Anh thay vì tiếng Việt** trong `content_json` của gói (ví dụ `这是一个爱情故事。 (This is a love story.)`):
   HSK 4: **572** · HSK 5: **1.016** · HSK 6: **752** · HSK 1: 2.
   Nguyên nhân: câu Tatoeba chỉ có bản dịch Anh. Cần nguồn bản dịch Việt có thẩm định, hoặc ẩn phần giải nghĩa tiếng Anh trên giao diện.
2. **W2 – Từ vựng chưa có câu ví dụ:** HSK 5: **17** · HSK 6: **558** (HSK 4: 0).
3. **Cần đối chiếu nguồn:** `爱情` đang nằm trong gói **HSK 3** (`VOCAB_L3_15`), trong khi file `hsk4_vocabularies.json` xếp từ này ở HSK 4. Cần Thread 2 đối chiếu với danh sách HSK 2.0 chính thức để quyết định giữ ở cấp nào.
4. **Lặp trong cùng cấp (thông tin):** HSK 2 có `懂`, `已经`, `真` xuất hiện ở 2 bài khác nhau. Gói HSK 4 có `等`, `对`, `过` lặp 2 lần trong cùng một content item; khi cài, mục sau ghi đè nghĩa của mục trước (cùng `sense_<chữ>_1`). Nên gộp lại thành một mục có nhiều nghĩa.

## 6. Tệp thay đổi

| Tệp | Loại |
|---|---|
| `lib/features/content_packs/data/content_pack_manager.dart` | Sửa lỗi Level Drift |
| `test/features/content_packs/zero_progress_loss_upgrade_test.dart` | Test mới (3 test) |
| `tool/qa/audit_referential_integrity.py` | Script kiểm toán mới (chỉ đọc) |
| `audit/referential_integrity_result.json` | Kết quả kiểm toán |
| `audit/KNOWLEDGE_EXPANSION_QA_REPORT.md` | Báo cáo này |
