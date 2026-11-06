# BÁO CÁO BÀN GIAO THREAD 1 → THREAD 2 & THREAD 5
## PHASE 1: HSK 4–6 VIETNAMESE ENRICHMENT BASELINE AUDIT & IMMUTABLE IDENTITY REGISTRY

- **Task Identifier:** `CORE-HSK46-VI-001`
- **Tác giả:** Thread 1 – Core Engine, Database & Content Platform Engineer
- **Bên nhận:** 
  - Thread 2 – Pedagogy & Learning Experience Engineer (Biên soạn & Cung cấp bản dịch câu ví dụ)
  - Thread 5 – Independent QA Engineer (Kiểm toán tính toàn vẹn)
- **Trạng thái:** **HOÀN THÀNH (PHASE 1 COMPLETED)**
- **Chế độ kiểm toán:** **READ-ONLY AUDIT – 100% Không thay đổi dữ liệu Production**

---

## 1. THÔNG BÁO QUAN TRỌNG DÀNH CHO THREAD 2

> [!IMPORTANT]
> **Quy tắc bắt buộc:**
> "Thread 2 chỉ được chọn câu thay thế dựa trên Identity Registry đã xác nhận. Không tự tạo hoặc sửa ID."
>
> Tuyệt đối **không** tạo mới hoặc chỉnh sửa bất kỳ `lesson_id`, `segment_id`, `content_id`, `vocab_id`, `sense_id`, hay `example_id` nào. Mọi câu ví dụ và bản dịch tiếng Việt khi biên soạn trong Phase 2 phải được neo chặt (anchored) vào `locator_id` tương ứng trong Identity Registry.

---

## 2. KẾT QUẢ KIỂM TOÁN BASELINE (ĐỐI SOÁT 100% SỐ LIỆU QA)

Kiểm toán độc lập của Thread 1 đã giải thích và đối soát chính xác 100% số liệu từ các báo cáo QA trước đây:

| Hạng mục dữ liệu | HSK 4 | HSK 5 | HSK 6 | Tổng cộng HSK 4-6 |
|---|:---:|:---:|:---:|:---:|
| **Từ vựng trong file rời (`assets/data/hsk*_vocabularies.json`)** | 601 | 1.300 | 2.500 | **4.401** |
| **Số từ vựng duy nhất (Standalone)** | 598 | 1.300 | 2.500 | **4.398** |
| **Số từ đa âm/trùng lặp (Standalone)** | 3 (`等`, `对`, `过`) | 0 | 0 | **3** |
| **Số Senses trong file rời (Tất cả đều có `sense_id`)** | 825 | 1.752 | 3.112 | **5.689** |
| **Số Ví dụ trong file rời (Tất cả đều có `example_id`)** | 908 | 1.609 | 2.032 | **4.549** |
| **Số Bài học trong Content Pack** | 30 | 36 | 50 | **116** |
| **Số Phân đoạn bài học (Segments, 6 seg/bài)** | 180 | 216 | 300 | **696** |
| **Số Content Items trong Content Pack** | 180 | 216 | 300 | **696** |
| **Tổng số lượt từ trong bài học Content Pack** | 600 (30 × 20) | 1.296 (36 × 36) | 2.500 (50 × 50) | **4.396** |
| **Câu ví dụ có đuôi giải nghĩa tiếng Anh (`W1`)** | **572** | **1.016** | **752** | **2.340** |
| **Từ thiếu câu ví dụ hoàn toàn (`W2`)** | **0** | **17** | **558** | **575** |
| **Câu ví dụ có ngoặc trống `()` (Thiếu bản dịch)** | **24** | **236** | **1.147** | **1.407** |
| **Câu ví dụ đã có sẵn tiếng Việt** | 4 | 27 | 43 | **74** |
| **Từ trong file rời chưa đưa vào bài học** | 1 (`作者`) | 4 (`遵守`, `作为`, `作品`, `作文`) | 0 | **5** |

### Giải thích các con số lịch sử:
1. **Con số "HSK 4 thiếu 28 ví dụ":** Thực chất HSK 4 có đủ 600 câu ví dụ cho 600 từ. Trong đó 572 câu có đuôi tiếng Anh, 4 câu đã có tiếng Việt, 24 câu kết thúc bằng ngoặc đơn rỗng `()`. 28 câu này ($4 + 24 = 28$) chính là các câu không có đuôi tiếng Anh ($600 - 572 = 28$).
2. **Khớp nối 100% giữa Content Pack và Standalone:** 
   - 17 từ thiếu ví dụ ở HSK 5 và 558 từ thiếu ví dụ ở HSK 6 trong Content Pack trùng khớp hoàn toàn từng từ một với 17 từ và 558 từ có mảng `examples: []` rỗng trong file từ vựng rời.
   - 100% câu chữ Hán trong Content Pack khớp từng ký tự với trường `example_cn` của file từ vựng rời.

---

## 3. CÁC TÀI LIỆU REGISTRY BÀN GIAO CHO THREAD 2

Toàn bộ 8 tệp JSON và 2 tài liệu chuẩn đã được tạo tại thư mục [audit/hsk46_vi_enrichment/](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/):

### 3.1 Báo cáo và Danh mục chính
1. [baseline_summary.md](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/baseline_summary.md): Báo cáo tổng thể kiểm toán Baseline và bảo toàn tiến độ người học.
2. [checksum_baseline.md](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/checksum_baseline.md): Đặc tả thuật toán Canonical SHA-256, chuẩn hóa UTF-8 compact và bảng mã băm gốc.
3. [immutable_identity_manifest.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/immutable_identity_manifest.json): Manifest trung tâm chứa toàn bộ mã băm SHA-256 của các registry để đảm bảo tính bất biến.

### 3.2 Bộ Registry định danh
4. [vocabulary_registry.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/vocabulary_registry.json): 4.401 mục từ vựng với đầy đủ `vocab_id`, `canonical_id`, `senses` (`sense_id`), `examples` (`example_id`).
5. [lesson_registry.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/lesson_registry.json): 116 bài học với `lesson_id`, `unit_id`, `order_index`, tiêu đề Hán - Việt.
6. [segment_registry.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/segment_registry.json): 696 phân đoạn bài học với `segment_id`, `lesson_id`, `segment_type`, `content_ref_id`.
7. [example_registry.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/example_registry.json): 4.396 bản ghi vị trí câu ví dụ với `locator_id` bất biến (dạng `LOC_HSK{lvl}_{lesson_id}_{segment_id}_{simplified}_{word_index}`), nguyên văn tiếng Trung, bản dịch cũ, loại bản dịch (`english`, `vietnamese`, `empty_parentheses`, `missing_example`), mã băm SHA-256 câu ví dụ.

### 3.3 Danh sách phục vụ trực tiếp cho Thread 2 biên dịch
8. [english_gloss_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/english_gloss_report.json): **2.340 câu** có đuôi tiếng Anh cần Thread 2 thay thế bằng tiếng Việt chuẩn sư phạm.
9. [missing_examples_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/missing_examples_report.json): 
   - Danh mục 1: **575 từ** thiếu hoàn toàn câu ví dụ (HSK 5: 17 từ, HSK 6: 558 từ).
   - Danh mục 2: **1.407 câu** có sẵn câu chữ Hán nhưng đuôi là ngoặc trống `()` cần bổ sung nghĩa tiếng Việt.
   - Danh mục 3: **5 từ** trong file rời chưa đưa vào bài học (`作者`, `遵守`, `作为`, `作品`, `作文`).
10. [ambiguous_mapping_report.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/ambiguous_mapping_report.json):
   - Danh mục 3 từ đa âm/trùng lặp tại HSK 4 (`等`, `对`, `过`) xuất hiện 2 lần trong bài học.
   - Danh mục 1.288 từ có nhiều hơn 1 sense trong từ điển.

---

## 4. QUY TRÌNH PHỐI HỢP DÀNH CHO THREAD 2 TRONG PHASE 2

Khi Thread 2 thực hiện biên soạn và làm giàu dữ liệu tiếng Việt (Phase 2):
1. **Tra cứu `locator_id`:** Sử dụng [example_registry.json](file:///C:/Users/phama/Downloads/hi_chinese/audit/hsk46_vi_enrichment/example_registry.json) để định vị đúng bài học và phân đoạn.
2. **Cấu trúc dữ liệu bàn giao của Thread 2:**
   Khi bàn giao danh sách câu ví dụ đã được biên soạn, Thread 2 cần cung cấp file JSON có cấu trúc tối thiểu như sau:
   ```json
   {
     "locator_id": "LOC_HSK4_lesson_4_1_seg_4_1_2_爱情_0",
     "vocab_id": "VOC_HSK4_爱情_aiqing",
     "word_simplified": "爱情",
     "example_cn": "这是一个爱情故事。",
     "example_vi": "Đây là một câu chuyện tình yêu.",
     "example_pinyin": "zhè shì yī ge ài qíng gù shì",
     "curation_status": "APPROVED"
   }
   ```
3. **Xử lý từ thiếu ví dụ:** Với 575 từ thiếu ví dụ, Thread 2 cung cấp câu tiếng Hán chuẩn HSK + pinyin + nghĩa tiếng Việt phù hợp ngữ cảnh bài học.
4. **Không sửa Content Pack trực tiếp:** Thread 2 **không tự sửa file Content Pack**. Thread 2 bàn giao bộ bản dịch sạch đã kiểm duyệt cho Thread 1. Thread 1 sẽ thực hiện nạp dữ liệu (Ingestion Pipeline) ở Phase 3 đảm bảo an toàn tuyệt đối và tính toán lại checksum.

---

## 5. THÔNG SỐ CANONICAL CHECKSUM HIỆN TẠI (BASELINE)

| Gói Content Pack | Kích thước | Canonical SHA-256 Checksum |
|---|:---:|---|
| `hsk4_pack_v1.json` | 683.297 B | `0b4cbbcb3adeba1ae08d4b3b0952c0803923f3c007509736e7c66c2150bda492` |
| `hsk5_pack_v1.json` | 1.036.492 B | `fb9786804d342ac9e162a1c017a8a4eb87fbf8269f8e8308a19cc12fcd1b720d` |
| `hsk6_pack_v1.json` | 1.544.224 B | `0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf` |

Mọi file production giữ nguyên 100% giá trị băm trên. Không triển khai Ingestion khi Thread 2 chưa hoàn thành Phase 2.
