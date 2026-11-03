# P0-04 FIX REPORT: SQLITE UPSERT, FOREIGN KEY CASCADE & LEARNING PROGRESS DATA LOSS

## 1. Tóm tắt nguyên nhân gốc rễ (Root Cause Analysis)
- **Vấn đề trong SQLite với `ConflictAlgorithm.replace`:**
  - `ConflictAlgorithm.replace` trong SQLite hoạt động theo cơ chế `INSERT OR REPLACE` (thực chất là thực thi ngầm `DELETE` dòng cũ vi phạm ràng buộc UNIQUE/PRIMARY KEY, sau đó mới `INSERT` dòng mới).
  - Khi một bảng cha bị xóa ngầm (implicit DELETE) do `ConflictAlgorithm.replace`, SQLite với cờ `PRAGMA foreign_keys = ON` sẽ tự động kích hoạt mệnh đề `ON DELETE CASCADE` trên toàn bộ các bảng con phụ thuộc.
  - Hậu quả nghiêm trọng:
    - Khi cài đặt lại hoặc nâng cấp một gói học liệu (`ContentPackManager`), các bảng `curriculum_lessons`, `curriculum_units`, `content_items` bị xóa ngầm -> Xóa sạch các tiến độ học tập liên kết trong `lesson_segments`, `lesson_knowledge_items`, và làm lệch ID của `curriculum_mastery`, `lesson_progress`, `srs_items`.
    - Khi cập nhật từ điển qua `VocabularyDao` hoặc nạp gói seed, việc sử dụng REPLACE đối với bảng `vocabularies` sẽ kích hoạt cascade delete xóa sạch toàn bộ nghĩa (`vocabulary_senses`) và các thẻ SRS liên quan.
    - Trong `SrsRepository.getOrCreateCardState`: Việc gọi `ConflictAlgorithm.replace` mỗi khi khởi tạo thẻ tiềm ẩn rủi ro ghi đè/reset thẻ nếu xuất hiện xung đột khóa.

---

## 2. Các vị trí đã rà soát và chuyển đổi sang Upsert an toàn

| STT | File / Lớp | Bảng bị ảnh hưởng | Hành vi trước khi sửa | Cơ chế Upsert mới đã triển khai |
|:---|:---|:---|:---|:---|
| 1 | `ContentPackManager` | `curriculum_units`, `curriculum_lessons`, `curriculum_mastery`, `lesson_progress` | Chỉ giữ trạng thái khóa/tiến độ khi `isUpgrade = true`, tiềm ẩn rủi ro khi cài lại cùng version hoặc cập nhật lặp lại. | Chuyển toàn bộ các bước lưu `curriculum_units`, `curriculum_lessons` sang kiểm tra tồn tại và bảo tồn trạng thái `is_locked`, `status`, `completed_at`, `credited_reason` trong mọi trường hợp. Thay thế toàn bộ REPLACE bằng in-place `_safeUpsert` (UPDATE nếu tồn tại, INSERT OR IGNORE nếu mới). |
| 2 | `VocabularyDao` | `vocabularies`, `vocabulary_senses`, `vocabulary_examples` | Các phương thức `insertVocabulary`, `insertSense`, `insertExample` trước đây có nguy cơ xóa cascade các bản ghi con. | Đã triển khai `_safeUpsert` kiểm tra tồn tại theo ID -> Chạy UPDATE in-place các trường nội dung; bảo tồn liên kết khóa ngoại tới `vocabulary_senses`, `srs_items`, `curriculum_mastery`. |
| 3 | `ContentItemDao` | `content_items` | `insertContentItem` và `insertContentItemsBatch` sử dụng `ConflictAlgorithm.replace`. | Thay thế bằng `_safeUpsert` theo `content_id`: Bảo tồn nguyên vẹn `id` nội bộ ban đầu, cập nhật payload nội dung mới (`content_json`, `title`, `audit_status`). |
| 4 | `KnowledgeRegistryDao` | `knowledge_registry`, `lesson_knowledge_items`, `content_id_mappings` | Sử dụng `ConflictAlgorithm.replace` trên bảng kiến thức chuẩn hóa, kích hoạt xóa cascade bảng `lesson_knowledge_items`. | Triển khai `_safeUpsert` theo cặp `(entity_type, canonical_id)` và theo `id`: Bảo tồn nguyên vẹn khóa chính, chỉ cập nhật metadata và tiêu đề. |
| 5 | `GrammarDao` | `grammar_items` | `insertGrammar` dùng `ConflictAlgorithm.replace`. | Triển khai `_safeUpsert` kiểm tra cả khóa `id` và ràng buộc `code UNIQUE` để UPDATE in-place, không kích hoạt cascade delete. |
| 6 | `MasteryDao` | `curriculum_mastery` | `upsertMastery` dùng `ConflictAlgorithm.replace`. | Triển khai `_safeUpsert` theo `item_id`: Giữ nguyên khóa chính ban đầu, cập nhật điểm và trạng thái học tập. |
| 7 | `SrsDao` | `srs_items` | `upsertSrsItem` dùng `ConflictAlgorithm.replace`. | Triển khai `_safeUpsert` theo cặp `(content_id, content_type)` và `id`: Cập nhật các chỉ số SM-2 (`state`, `interval_days`, `ease_factor`, `repetitions`, `lapses`, `due_at`) mà không xóa/tạo lại dòng. |
| 8 | `ReadingDao` | `reading_passages`, `reading_progress` | Dùng `ConflictAlgorithm.replace` trong `insertPassage` và `saveProgress`. | Triển khai `_safeUpsert` bảo tồn khóa chính và tiến độ đọc. |
| 9 | `SrsRepository` | `srs_items` | `getOrCreateCardState` chèn thẻ với `ConflictAlgorithm.replace`. | Đổi sang `ConflictAlgorithm.ignore` để không bao giờ ghi đè thẻ đang học. |

---

## 3. Kiểm thử Bảo toàn Dữ liệu Thực tế (Database Verification)

Đã tạo bộ kiểm thử tích hợp thực tế: [`test/core/database/upsert_safety_test.dart`](file:///c:/Users/phama/Downloads/hi_chinese/test/core/database/upsert_safety_test.dart) chạy trực tiếp trên SQLite Engine với `PRAGMA foreign_keys = ON`:

1. **Kịch bản Full Lifecycle:**
   - Bước 1: Import Content Pack HSK 1 v1.0.0.
   - Bước 2: Học viên mở khóa Unit, hoàn thành Lesson, tạo `lesson_progress` (score: 0.95), tạo `curriculum_mastery` (mastered, 5 attempts), tạo thẻ SRS và thực hiện ôn tập (repetitions: 1).
   - Bước 3: Nâng cấp Content Pack lên v1.1.0 (cùng pack_id, payload mới, tiêu đề mới).
   - Bước 4: Kiểm tra xác minh:
     - Tiêu đề Unit và Lesson được cập nhật nội dung mới.
     - Trạng thái `is_locked: 0` của Unit được bảo toàn.
     - Trạng thái `status: completed`, `completed_at`, `credited_reason` của Lesson được bảo toàn.
     - Dòng `lesson_progress` không bị xóa.
     - Dòng `curriculum_mastery` không bị reset.
     - Thẻ `srs_items` giữ nguyên ID và `repetitions: 1`.
     - Kiểm tra `PRAGMA foreign_key_check;` -> Kết quả **0 vi phạm**.
   - Bước 5: Re-import lại cùng gói v1.1.0 -> Xác minh tính Idempotent, không sinh dòng trùng lặp.

2. **Kịch bản VocabularyDao Cascade Prevention:**
   - Chèn `v_test` và `s_test` có quan hệ `ON DELETE CASCADE`.
   - Gọi `insertVocabulary` với dữ liệu mới giàu thuộc tính hơn.
   - Xác minh nghĩa `s_test` **KHÔNG** bị xóa cascade.
   - Kiểm tra `PRAGMA foreign_key_check;` sạch 100%.

3. **Kịch bản ContentItemDao ID Stability:**
   - Chèn item với `id: ci_original` và `content_id: CID_100`.
   - Cố gắng chèn lại với `id: ci_new_attempt` và `content_id: CID_100`.
   - Xác minh `id` gốc `ci_original` được bảo toàn nguyên vẹn, nội dung JSON được cập nhật chính xác.

---

## 4. Kết quả nghiệm thu
- `dart analyze lib test`: **0 errors, 0 warnings (No issues found!)**
- `flutter test test/core/database/upsert_safety_test.dart`: **3/3 passed**
- `flutter test test/core/database/app_database_test.dart`: **6/6 passed**
- `flutter test test/features/content_packs/content_pack_normalization_test.dart`: **7/7 passed**
