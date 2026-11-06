# BÁO CÁO THỰC THI THREAD 1: PHASE 3 – CONTROLLED VIETNAMESE DATA INGESTION, RECALIBRATION & CANONICAL SHA-256

- **Task Identifier:** `CORE-HSK46-VI-002`
- **Tác giả:** Thread 1 – Core Engine, Database & Content Platform Engineer
- **Bên nhận:** 
  - Thread 2 – Pedagogy & Learning Experience Engineer
  - Thread 5 – Independent QA Engineer
  - Project Owner
- **Trạng thái:** **COMPLETED (CONTROLLED SUBSET INGESTION & PIPELINE OPERATIONAL)**
- **Latest Commit ID:** `309bba4`
- **Chế độ thực thi:** **CONTROLLED PRODUCTION DATA UPDATE & ZERO PROGRESS LOSS**

---

## 1. TỔNG QUAN KẾT QUẢ INGESTION & KIỂM SOÁT AN TOÀN

Tuân thủ nghiêm ngặt chỉ thị cốt lõi:
> "Thread 1 chỉ được ingestion Candidate có trạng thái APPROVED, đúng Registry Version và original_example_hash còn khớp. Không tự động dùng dữ liệu DISCOVERED hoặc TRANSLATION_REVIEW khi chưa có phê duyệt chính thức."

Thread 1 đã xây dựng thành công pipeline nạp dữ liệu kiểm soát [replace_en_examples_with_vi.py](file:///C:/Users/phama/Downloads/hi_chinese/tool/data_ingestion/replace_en_examples_with_vi.py) với 17 chốt chặn xác thực tự động (Automated Validation Gates), thực hiện Dry Run an toàn và áp dụng thành công tập ứng viên đã được phê duyệt chính thức.

### Bảng số liệu Ingestion Pipeline

| Hạng mục | HSK 4 | HSK 5 | HSK 6 | Tổng cộng | Ghi chú kỹ thuật |
|---|:---:|:---:|:---:|:---:|---|
| **Tổng số ứng viên đánh giá** | 594 | 1.279 | 1.942 | **3.815** | Toàn bộ ứng viên từ Phase 2 |
| **Ứng viên ĐÃ NẠP (APPROVED)** | **2** | **17** | **31** | **50** | Vượt qua 100% 17 chốt xác thực |
| **Ứng viên TỪ CHỐI (REJECTED)** | 0 | **1** | 0 | **1** | Bị từ chối do sót tiếng Anh (`简历`) |
| **Chờ thẩm định sư phạm (PENDING)** | 592 | 1.261 | 1.911 | **3.764** | 3.741 `TRANSLATION_REVIEW` + 23 `SENSE_REVIEW` |
| **Từ vựng thiếu ví dụ (UNRESOLVED)** | 0 | 17 | 558 | **575** | `NO_VALID_PARALLEL_EXAMPLE` |
| **Bản ghi Vocab cập nhật** | 2 | 17 | 31 | **50** | Cập nhật `example_vi`, `example_pinyin` |
| **Content Packs cập nhật** | 1 | 1 | 1 | **3** | Chuẩn hóa Compact JSON & Checksum |
| **Gói CDN đồng bộ** | 2 | 2 | 2 | **6** | `content_packs_cdn/packages/` & root |

---

## 2. CHI TIẾT 17 CHỐT CHẶN XÁC THỰC (VALIDATION GATES)

Mỗi Candidate trước khi nạp đều phải vượt qua 17 điều kiện logic nghiêm ngặt:

1. `CHECK_1_CANDIDATE_ID_NOT_UNIQUE`: Đảm bảo `candidate_id` duy nhất tuyệt đối.
2. `CHECK_2_STATUS_NOT_APPROVED`: Bắt buộc `curator_status == 'APPROVED'`. Toàn bộ 3.741 ứng viên `TRANSLATION_REVIEW` và 23 ứng viên `SENSE_REVIEW` bị chặn lại an toàn, đưa vào [ingestion_dry_run.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/ingestion_dry_run.json).
3. `CHECK_3_SOURCE_RECORD_ID_NOT_FOUND`: `source_record_id` phải tồn tại trong `example_registry.json`.
4. `CHECK_4_LICENSE_NON_COMPLIANT`: Giấy phép ngữ liệu phải là `COMPLIANT`.
5. `CHECK_5_VOCAB_ID_NOT_FOUND`: `vocab_id` phải tồn tại trong `vocabulary_registry.json`.
6. `CHECK_6_INVALID_SENSE_LOCATOR`: `sense_locator` phải hợp lệ và có `sense_id`.
7. `CHECK_7_LESSON_ID_NOT_FOUND`: `lesson_id` phải tồn tại trong `lesson_registry.json`.
8. `CHECK_8_SEGMENT_ID_NOT_FOUND`: `segment_id` phải tồn tại trong `segment_registry.json`.
9. `CHECK_9_SEGMENT_LESSON_MISMATCH`: `segment_id` phải thuộc đúng `lesson_id`.
10. `CHECK_10_CONTENT_ITEM_MISMATCH`: `content_item_id` phải khớp với phân đoạn.
11. `CHECK_11_INVALID_TARGET_FIELD`: Trường mục tiêu bắt buộc là `example_sentence`.
12. `CHECK_12_ORIGINAL_HASH_MISMATCH`: Mã băm `original_example_hash` phải khớp 100% với Baseline Phase 1.
13. `CHECK_13_EMPTY_REPLACEMENT_CHINESE`: Câu chữ Hán thay thế không được rỗng.
14. `CHECK_14_EMPTY_REPLACEMENT_VIETNAMESE`: Bản dịch tiếng Việt thay thế không được rỗng.
15. `CHECK_15_EMPTY_REPLACEMENT_PINYIN`: Phiên âm Pinyin không được rỗng.
16. `CHECK_16_RESIDUAL_ENGLISH_GLOSS`: Bản dịch tiếng Việt không được chứa tàn dư tiếng Anh.
17. `CHECK_17_AMBIGUOUS_MAPPING`: Chặn các từ đa âm chưa gỡ trùng ngoài chủ đích.

### Trường hợp bị phát hiện và từ chối:
- **Ứng viên `CAND_HSK5_lesson_5_14_seg_5_14_2_简历_9` (Từ `简历`):**
  - Mặc dù mang nhãn `APPROVED`, nhưng trường `replacement_vietnamese` lại chứa: `"Prepare your résumé before the interview."` (do từ `résumé` có dấu sắc `é` bị bộ lọc sơ bộ nhận nhầm là tiếng Việt).
  - Chốt chặn số 16 (`CHECK_16_RESIDUAL_ENGLISH_GLOSS`) đã phát hiện và tự động **REJECT** ứng viên này, ngăn chặn ô nhiễm dữ liệu tiếng Anh vào bản dịch tiếng Việt.

---

## 3. CANONICAL SHA-256 & BẢO ĐẢM TÍNH TOÀN VẸN CDN

Đã tính toán và hiệu chuẩn lại mã băm theo đúng đặc tả Canonical Compact JSON (`manifest.sha256 = ""`, không khoảng trắng, UTF-8 unescaped):

| Gói Content Pack | Dung lượng | Canonical SHA-256 (Khai báo & Thực tế) | Trạng thái Catalog & CDN |
|---|:---:|---|:---:|
| **`hsk4_pack_v1.json`** | 683.297 B | `0b4cbbcb3adeba1ae08d4b3b0952c0803923f3c007509736e7c66c2150bda492` | **100% KHỚP** |
| **`hsk5_pack_v1.json`** | 1.036.492 B | `fb9786804d342ac9e162a1c017a8a4eb87fbf8269f8e8308a19cc12fcd1b720d` | **100% KHỚP** |
| **`hsk6_pack_v1.json`** | 1.544.224 B | `0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf` | **100% KHỚP** |

### Đối chiếu tính toàn vẹn 3 chiều:
1. `pack.manifest.sha256` == `Canonical SHA-256` computed in-memory (Khớp 100%).
2. `content_packs_cdn/packages/hsk*_pack_v1.json` == `assets/data/content_packs/hsk*/hsk*_pack_v1.json` (Khớp 100% từng byte).
3. Trusted Catalog trong [content_pack_remote_service.dart](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/content_packs/data/content_pack_remote_service.dart#L39-L55) giữ vững giá trị băm chuẩn.

---

## 4. KẾT QUẢ KIỂM THỬ HỆ THỐNG & ZERO PROGRESS LOSS

Tất cả các bộ test kiểm toán yêu cầu đều chạy thực tế và **PASS 100%**:

### 4.1 Kiểm toán toàn vẹn tham chiếu (Referential Integrity Audit)
Lệnh: `python tool/qa/audit_referential_integrity.py --json audit/referential_integrity_result.json`
- `C1_unique_unit_ids`: **PASS** (0 lỗi)
- `C1_unique_lesson_ids`: **PASS** (0 lỗi)
- `C1_unique_segment_ids`: **PASS** (0 lỗi)
- `C2_unique_content_ids`: **PASS** (0 lỗi)
- `C3_dangling_segment_refs`: **PASS** (0 lỗi)
- `C4_content_item_curriculum_mismatch`: **PASS** (0 lỗi)
- `C5_vocab_missing_pinyin_or_meaning`: **PASS** (0 lỗi)
- `C6_pack_words_missing_fields`: **PASS** (0 lỗi)
- `C7_exit_exam_bad_answer_index`: **PASS** (0 lỗi)
- **Tổng kết: RESULT: PASS**

### 4.2 Kiểm thử Zero Progress Loss Upgrade
Lệnh: `flutter test test/features/content_packs/zero_progress_loss_upgrade_test.dart`
- Test 1: Cài đặt gói HSK 4, 5, 6 bảo toàn 100% trạng thái học viên HSK 1–3 (`lesson_progress`, `srs_items`, `curriculum_mastery`). -> **PASS**
- Test 2: Các từ vựng học chéo giữ nguyên cấp độ và tiến độ ban đầu. -> **PASS**
- Test 3: Tính toàn vẹn tham chiếu không có liên kết treo sau khi cài đặt cả 6 gói. -> **PASS**
- **Kết quả: 00:18 +3: All tests passed!**

### 4.3 Kiểm thử hồi quy các Feature Core
- `test/features/content_packs/`: **23/23 tests PASS** (00:24)
- `test/features/reading/`: **24/24 tests PASS** (00:44)
- `test/features/curriculum/`: **48/48 tests PASS** (00:17)
- `test/features/vocabulary_srs/`: **20/20 tests PASS** (00:17)
- `test/features/home/`: **50/50 tests PASS** (00:07)
- `test/features/hanzi_writing/`: **18/18 tests PASS** (00:07)
- `test/features/sentences/`: **17/17 tests PASS** (00:07)
- `test/features/dictionary/`: **19/19 tests PASS** (00:55)
- **Tổng số test Flutter đã PASS:** **222 / 222 tests (100% Passed)**

### 4.4 Phân tích mã nguồn tĩnh (Static Analysis)
Lệnh: `flutter analyze lib/ test/`
- **Kết quả:** `No issues found! (ran in 56.4s)` (**0 errors, 0 warnings, 0 infos**)

---

## 5. TÀI LIỆU VÀ REPORT ĐÃ XUẤT XƯỞNG

Các tệp kiểm toán và báo cáo mới đã được tạo tại thư mục [audit/hsk46_vi_enrichment/](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/):

1. [ingestion_dry_run.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/ingestion_dry_run.json): Chi tiết kết quả chạy thử nghiệm Dry Run và các chốt chặn thất bại.
2. [ingestion_result.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/ingestion_result.json): Bản ghi thực thi cập nhật Production Data có kiểm soát.
3. [final_checksum_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/final_checksum_report.json): Báo cáo đối chiếu băm Canonical SHA-256 ba chiều.
4. [identity_diff_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/identity_diff_report.json): Bằng chứng đối soát ID trước và sau khi nạp (0 ID bị mất hoặc thay đổi).
5. [english_gloss_final_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/english_gloss_final_report.json): Phân bổ 3.764 ứng viên chờ phê duyệt sư phạm theo từng cấp độ HSK.
6. [replace_en_examples_with_vi.py](file:///C:/Users/phama/Downloads/hi_chinese/tool/data_ingestion/replace_en_examples_with_vi.py): Công cụ Ingestion Pipeline kiểm soát sản phẩm.

---

## 6. DANH MỤC THAY ĐỔI GIT (GIT DIFF SUMMARY)

```
modified:   assets/data/content_packs/hsk4/hsk4_pack_v1.json
modified:   assets/data/content_packs/hsk5/hsk5_pack_v1.json
modified:   assets/data/content_packs/hsk6/hsk6_pack_v1.json
modified:   assets/data/hsk4_vocabularies.json (2 senses updated)
modified:   assets/data/hsk5_vocabularies.json (17 senses updated)
modified:   assets/data/hsk6_vocabularies.json (31 senses updated)
modified:   content_packs_cdn/hsk4_pack_v1.json
modified:   content_packs_cdn/hsk5_pack_v1.json
modified:   content_packs_cdn/hsk6_pack_v1.json
modified:   content_packs_cdn/packages/hsk4_pack_v1.json
modified:   content_packs_cdn/packages/hsk5_pack_v1.json
modified:   content_packs_cdn/packages/hsk6_pack_v1.json

Untracked files:
	audit/hsk46_vi_enrichment/backups/
	audit/hsk46_vi_enrichment/english_gloss_final_report.json
	audit/hsk46_vi_enrichment/final_checksum_report.json
	audit/hsk46_vi_enrichment/identity_diff_report.json
	audit/hsk46_vi_enrichment/ingestion_dry_run.json
	audit/hsk46_vi_enrichment/ingestion_result.json
	docs/agent-coordination/reports/thread-1/CORE-HSK46-VI-002.md
	tool/data_ingestion/replace_en_examples_with_vi.py
```

---

## 7. KIẾN NGHỊ BÀN GIAO TIẾP THEO

1. **Gửi Thread 2 (Pedagogy Lead):**
   - Đã nạp thành công 50 câu ví dụ đạt chuẩn.
   - Bản ghi từ `简历` cần được dịch lại sang tiếng Việt tự nhiên: `"面试前先准备好简历。(Hãy chuẩn bị sẵn sơ yếu lý lịch trước buổi phỏng vấn.)"`.
   - 3.741 câu đang ở trạng thái `TRANSLATION_REVIEW` cần chuyên gia sư phạm phê duyệt chính thức từng đợt để Thread 1 tiếp tục nạp vào hệ thống.
2. **Gửi Thread 5 (Independent QA):**
   - Toàn bộ cơ chế Ingestion Pipeline, sao lưu an toàn, Canonical Checksum và Zero Progress Loss đã sẵn sàng để kiểm toán độc lập nghiệm thu.
