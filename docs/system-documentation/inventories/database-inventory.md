# DATABASE INVENTORY – BẢNG QUẢN LÝ DỮ LIỆU SCHEMA V11

Cơ sở dữ liệu: **SQLite**  
Tên tệp: `hi_chinese.db`  
Phiên bản Schema hiện tại: **11** (Định nghĩa tại `DatabaseConstants.currentDatabaseVersion`)  
Chế độ hoạt động: **WAL (Write-Ahead Logging)** kết hợp bộ nhớ đệm `cache_size = -8000` (8MB)

---

## DANH MỤC TOÀN BỘ 39 BẢNG TRONG HỆ THỐNG

| STT | Tên bảng | Schema Version | Module sở hữu | Mục đích |
| :---: | :--- | :---: | :--- | :--- |
| 1 | `vocabularies` | v1 | `features/dictionary`, `features/curriculum` | Lưu trữ từ vựng cốt lõi tiếng Trung, cấp độ HSK, số nét, phát âm. |
| 2 | `vocabulary_senses` | v1 | `features/dictionary` | Các nghĩa, từ loại và câu ví dụ của từ vựng (quan hệ 1-N). |
| 3 | `grammar_items` | v1, v6 | `features/grammar` | Cấu trúc ngữ pháp, quy tắc, giải thích và ví dụ đối sánh. |
| 4 | `reading_passages` | v1 | `features/reading` | Đoạn văn bài đọc phân loại theo HSK kèm câu hỏi trắc nghiệm. |
| 5 | `srs_items` | v1 | `features/vocabulary_srs` | Thẻ nhớ ôn tập lặp lại ngắt quãng (SM-2: interval, ease factor, lapses, due date). |
| 6 | `learner_evidence` | v1 | `features/learning_pipeline` | Nhật ký bất biến ghi nhận mọi bằng chứng học tập và điểm số. |
| 7 | `mastery_snapshots` | v1 | `features/learning_pipeline` | Trạng thái thành thạo tri thức (`unseen`, `exposed`, `practicing`, `mastered`). |
| 8 | `chat_sessions` | v1 | `features/ai_tutor` | Phiên trò chuyện với Gia sư AI theo kịch bản và nhân vật. |
| 9 | `chat_messages` | v1 | `features/ai_tutor` | Từng tin nhắn trong cuộc trò chuyện kèm phản hồi sửa lỗi và đề xuất bằng chứng. |
| 10 | `learning_activities` | v1 | `features/home` | Nhật ký hoạt động theo ngày dùng tính streak và biểu đồ thời gian học. |
| 11 | `seed_history` | v2 | `core/database/seed` | Đánh dấu các bản fixture JSON đã được nạp để tránh nạp trùng lặp (idempotent). |
| 12 | `placement_test_sessions`| v3 | `features/placement_test` | Phiên kiểm tra trình độ đầu vào CAT IRT. |
| 13 | `placement_test_responses`| v3 | `features/placement_test` | Câu trả lời chi tiết và ước tính năng lực (theta, SE) của từng câu test. |
| 14 | `dictionary_history` | v4 | `features/dictionary` | Lịch sử từ khóa người học đã tra cứu trong từ điển. |
| 15 | `user_saved_words` | v4 | `features/dictionary` | Danh sách từ vựng người học đánh dấu lưu lại kèm ghi chú cá nhân. |
| 16 | `reading_progress` | v4 | `features/reading` | Tiến độ đọc đoạn văn (đã hoàn thành, điểm số câu hỏi). |
| 17 | `learner_goals` | v5 | `features/roadmap` | Cấu hình mục tiêu học tập (cấp độ HSK mục tiêu, thời gian mỗi ngày). |
| 18 | `lesson_progress` | v5 | `features/roadmap`, `features/curriculum` | Trạng thái hoàn thành từng bài học (`not_started`, `in_progress`, `completed`, `skipped`). |
| 19 | `roadmap_snapshots` | v5 | `features/roadmap` | Bản chụp lộ trình thích ứng và gợi ý bài học kế tiếp. |
| 20 | `grammar_progress` | v6 | `features/grammar` | Tiến độ học và điểm làm chủ từng điểm ngữ pháp. |
| 21 | `practice_exercises` | v7 | `features/practice` | Ngân hàng câu hỏi bài tập trắc nghiệm, điền từ, nghe hiểu. |
| 22 | `practice_sessions` | v7 | `features/practice` | Phiên làm bài tập luyện tập thích ứng. |
| 23 | `practice_attempts` | v7 | `features/practice` | Lịch sử nộp câu trả lời kèm chống gian lận nộp kép (double submit). |
| 24 | `user_profiles` | v8 | `features/profile` | Thông tin người dùng cục bộ, cấp độ hiện tại, streak, sở thích. |
| 25 | `goal_history` | v8 | `features/profile` | Lịch sử các lần thay đổi mục tiêu kèm lý do bắt buộc. |
| 26 | `app_settings` | v8 | `features/settings` | Cài đặt ứng dụng dạng key-value (chủ đề, âm thanh, API key metadata). |
| 27 | `content_packs` | v9 | `features/content_packs` | Thông tin gói học liệu (HSK 1, 2, 3), phiên bản, trạng thái nạp, checksum. |
| 28 | `curriculums` | v9 | `features/curriculum` | Cấu trúc giáo trình chuẩn (ví dụ HSK 2.0 Level 1). |
| 29 | `curriculum_units` | v9 | `features/curriculum` | Các phần / chương lớn trong giáo trình. |
| 30 | `curriculum_lessons` | v9 | `features/curriculum` | Danh sách bài học kèm điều kiện mở khóa và thời lượng ước tính. |
| 31 | `lesson_segments` | v9 | `features/curriculum` | 6 phân đoạn trong mỗi bài học (Warmup, Vocab, Grammar, Dialogue, Practice, Mastery). |
| 32 | `content_items` | v9 | `features/curriculum` | Bảng nội dung bài học liên kết theo `content_id`. |
| 33 | `curriculum_mastery` | v9 | `features/curriculum` | Điểm tổng kết thành thạo theo từng giáo trình. |
| 34 | `level_exit_exams` | v9 | `features/curriculum` | Đề thi tốt nghiệp đánh giá năng lực hoàn thành cấp độ HSK. |
| 35 | `knowledge_registry` | v10 | `features/learning_pipeline` | Danh bạ tri thức chuẩn hóa (ID ổn định: `KNOW_VOCAB_...`, `KNOW_GRAMMAR_...`). |
| 36 | `lesson_knowledge_items`| v10| `features/learning_pipeline` | Bảng quan hệ nhiều-nhiều liên kết bài học với các tri thức chuẩn hóa. |
| 37 | `content_id_mappings` | v10 | `features/content_packs` | Bản đồ tương thích ngược giữa mã định danh cũ và mã chuẩn hóa. |
| 38 | `audio_assets` | v11 | `features/audio_management` | Quản trị tài nguyên âm thanh ngoại tuyến, đường dẫn local, checksum SHA-256. |
| 39 | `pinyin_progress` | v11 | `features/pinyin_foundation` | Theo dõi mức độ thông thạo từng âm vị Pinyin (thanh mẫu, vận mẫu, thanh điệu). |

---

## CHI TIẾT CẤU TRÚC TỪNG BẢNG

### 1. `vocabularies`
- **Columns:**
  - `id` (TEXT, PK): Mã từ vựng (`v_hsk1_001`).
  - `simplified` (TEXT, NOT NULL): Chữ Hán Giản thể.
  - `traditional` (TEXT): Chữ Hán Phồn thể.
  - `pinyin` (TEXT, NOT NULL): Phiên âm có dấu thanh.
  - `hsk_level` (INTEGER, NOT NULL): 1 đến 6.
  - `stroke_count` (INTEGER): Số nét bút.
  - `radicals` (TEXT): Bộ thủ.
  - `frequency_rank` (INTEGER): Xếp hạng tần suất sử dụng.
  - `audio_uri` (TEXT): Đường dẫn âm thanh phát âm.
  - `created_at` (TEXT, NOT NULL): ISO8601 UTC.
  - `updated_at` (TEXT, NOT NULL): ISO8601 UTC.
  - `deleted_at` (TEXT): Đánh dấu xóa mềm.
- **Indexes:** `idx_vocab_simplified`, `idx_vocab_hsk_level`, `idx_vocab_deleted_at`.

### 2. `vocabulary_senses`
- **Columns:**
  - `id` (TEXT, PK)
  - `vocabulary_id` (TEXT, NOT NULL, FK -> `vocabularies.id` ON DELETE CASCADE)
  - `part_of_speech` (TEXT): Từ loại (danh từ, động từ...).
  - `meaning_vi` (TEXT, NOT NULL): Nghĩa tiếng Việt.
  - `example_cn` (TEXT): Câu ví dụ tiếng Trung.
  - `example_pinyin` (TEXT): Pinyin của câu ví dụ.
  - `example_vi` (TEXT): Bản dịch tiếng Việt câu ví dụ.
  - `created_at`, `updated_at`, `deleted_at`
- **Indexes:** `idx_vocab_senses_vocab_id`.

### 3. `knowledge_registry` (Chuẩn hóa Schema v10)
- **Columns:**
  - `id` (TEXT, PK): Định danh chuẩn hóa (`KNOW_VOCAB_你`, `KNOW_GRAMMAR_ba_structure`).
  - `entity_type` (TEXT, NOT NULL): `vocabulary`, `grammar`, `hanzi`, `phonics`.
  - `canonical_id` (TEXT, NOT NULL): Mã định danh gốc của thực thể.
  - `hsk_level` (INTEGER, NOT NULL): 1 đến 6.
  - `title` (TEXT, NOT NULL): Tiêu đề hiển thị.
  - `is_deprecated` (INTEGER, DEFAULT 0): Cờ đánh dấu đã thay thế.
  - `replaced_by_id` (TEXT): ID thay thế nếu deprecated.
  - `package_id` (TEXT): Gói học liệu phát hành.
  - `metadata_json` (TEXT, DEFAULT '{}'): Dữ liệu ngữ âm, ngữ nghĩa phụ.
  - `created_at`, `updated_at`
- **Constraints & Indexes:** `UNIQUE(entity_type, canonical_id)`, `idx_knowledge_hsk_level`, `idx_knowledge_package_id`.

### 4. `lesson_knowledge_items` (Quan hệ Bài học - Tri thức)
- **Columns:**
  - `id` (TEXT, PK)
  - `lesson_id` (TEXT, NOT NULL, FK -> `curriculum_lessons.id` ON DELETE CASCADE)
  - `knowledge_item_id` (TEXT, NOT NULL, FK -> `knowledge_registry.id` ON DELETE CASCADE)
  - `role` (TEXT, DEFAULT 'instruction'): `instruction`, `reinforcement`, `assessment`.
  - `sequence_order` (INTEGER, DEFAULT 1)
  - `is_mandatory` (INTEGER, DEFAULT 1)
  - `created_at` (TEXT)
- **Constraints & Indexes:** `UNIQUE(lesson_id, knowledge_item_id)`, `idx_lki_lesson_id`, `idx_lki_knowledge_id`.

### 5. `audio_assets` (Schema v11)
- **Columns:**
  - `id` (TEXT, PK): ID âm thanh (`audio_hsk3_v001`).
  - `package_id` (TEXT, NOT NULL, FK -> `content_packs.id`): Gói chứa âm thanh.
  - `content_id` (TEXT, NOT NULL): Mã nội dung tương ứng (`KNOW_VOCAB_打算`).
  - `audio_type` (TEXT, NOT NULL): `vocab`, `pinyin`, `dialogue`, `passage`.
  - `hsk_level` (INTEGER, NOT NULL)
  - `checksum_sha256` (TEXT, NOT NULL): Mã băm SHA-256 xác minh toàn vẹn.
  - `local_path` (TEXT, NOT NULL): Đường dẫn tuyệt đối lưu trên thiết bị.
  - `file_size_bytes` (INTEGER, DEFAULT 0)
  - `duration_ms` (INTEGER, DEFAULT 0)
  - `speaker_gender` (TEXT, DEFAULT 'standard')
  - `audio_format` (TEXT, DEFAULT 'mp3')
  - `license_type` (TEXT, DEFAULT 'proprietary')
  - `transcript_zh`, `transcript_pinyin`, `transcript_vi` (TEXT)
  - `status` (TEXT, DEFAULT 'ready'): `pending`, `ready`, `corrupted`.
  - `created_at`, `updated_at`
- **Indexes:** `idx_audio_assets_pkg`, `idx_audio_assets_content`, `idx_audio_assets_level`.

### 6. `pinyin_progress` (Schema v11)
- **Columns:**
  - `id` (TEXT, PK)
  - `pinyin_item_id` (TEXT, NOT NULL, UNIQUE): Mã âm vị (`pinyin_init_b`, `pinyin_tone_1`).
  - `category` (TEXT, NOT NULL): `initial`, `final`, `tone`, `rule`.
  - `mastery_level` (TEXT, DEFAULT 'unseen'): `unseen`, `learning`, `mastered`.
  - `accuracy_score` (REAL, DEFAULT 0.0): Tỷ lệ chính xác (0.0 đến 1.0).
  - `total_attempts` (INTEGER, DEFAULT 0)
  - `correct_attempts` (INTEGER, DEFAULT 0)
  - `last_studied_at` (TEXT)
  - `next_review_at` (TEXT)
  - `created_at`, `updated_at`
- **Indexes:** `idx_pinyin_progress_cat`, `idx_pinyin_progress_mastery`.
