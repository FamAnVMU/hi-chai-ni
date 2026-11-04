# Task Report: TASK-001-REPO-SURVEY
## Thread 1: Core Engine, Database & Content Platform

- **Task ID**: `TASK-001-REPO-SURVEY`
- **Mục tiêu**: Khảo sát toàn diện mã nguồn repository HI Chinese, lập bản đồ trạng thái thực tế của Database, Content Platform, Offline Data Infrastructure, thiết lập nhánh làm việc `feature/thread-1-core` và cấu trúc điều phối liên Thread (`docs/agent-coordination/`).
- **Trạng thái**: COMPLETED
- **Branch**: `feature/thread-1-core` (tạo từ base commit `89b1c54` trên `main`)

---

### 1. Source Code Đã Khảo Sát

1. **Framework & Runtime**:
   - Flutter 3.x / Dart SDK `^3.13.7`.
   - SQLite client: `sqflite: ^2.4.5`, `sqflite_common_ffi: ^2.4.5`.
   - State management: `flutter_riverpod: ^3.4.3`.
   - Local Secure Storage: `flutter_secure_storage: ^11.2.0`.
   - Audio Playback & Recording: `just_audio: ^0.10.6`, `record: ^7.1.2`, `flutter_tts: ^4.2.5`.

2. **Cơ sở dữ liệu & Migrations (`lib/core/database/`)**:
   - Quản lý phiên bản: `AppDatabase` singleton (`DatabaseConstants.currentDatabaseVersion = 16`).
   - Cấu hình SQLite engine:
     - `PRAGMA foreign_keys = ON;`
     - `PRAGMA journal_mode = WAL;`
     - `PRAGMA synchronous = NORMAL;`
     - `PRAGMA cache_size = -8000;` (8MB in-memory page cache)
     - `PRAGMA temp_store = MEMORY;`
     - Quản lý đóng mở an toàn: `wal_checkpoint(TRUNCATE)` và `PRAGMA optimize;`.
   - Động cơ migration: `MigrationEngine` hỗ trợ chuỗi di chuyển tuần tự v1 $\rightarrow$ v16:
     - `v1`: Core schema (vocabularies, grammar, reading, srs_items, evidence, chat, activities).
     - `v2`: Bảng `seed_history` theo dõi idempotency của seed data.
     - `v3`: `placement_test_sessions`, `placement_test_responses` phục vụ CAT Engine.
     - `v4`: `dictionary_history`, `user_saved_words`, `reading_progress`.
     - `v5`: `learner_goals`, `lesson_progress`, `roadmap_snapshots`.
     - `v6`: Bổ sung contrastive examples và `grammar_progress`.
     - `v7`: `practice_exercises`, `practice_sessions`, `practice_attempts`.
     - `v8`: `user_profiles`, `goal_history`, `app_settings`.
     - `v9`: Chuẩn hóa Curriculum, Content Catalog, `content_packs`, `curriculums`, `curriculum_units`, `curriculum_lessons`, `lesson_segments`, `content_items`, `curriculum_mastery`, `level_exit_exams`.
     - `v10`: `knowledge_registry`, `lesson_knowledge_items`, `content_id_mappings`.
     - `v11`: `audio_assets`, `pinyin_progress`.
     - `v12`: Bổ sung Han-Viet & clean Pinyin cho vocabularies, `vocabulary_examples`, `dictionary_entries`.
     - `v13`: Chuẩn hóa grammar HSK 3.0 & AllSet Wiki, `grammar_examples`, `grammar_topics`.
     - `v14`: `hanzi_characters`, `hanzi_writing_progress` với vector stroke paths.
     - `v15`: `sentences`, `sentence_audio`, `sentence_practice_progress`.
     - `v16`: Bổ sung `timezone_offset_minutes` vào `learning_activities`, index hợp thành `idx_activities_user_date_type`.
   - Backup & Phục hồi: `DatabaseBackupHelper` kiểm tra toàn vẹn `PRAGMA integrity_check`, sao chép an toàn qua checkpoint WAL.

3. **Content Platform & Seed Assets**:
   - `SeedLoader`: Nạp 5,000 từ vựng hạt nhân chuẩn HSK 1–6 từ `assets/data/hsk_seed_fixture_v2.json`.
   - Gói học liệu nội bộ: `assets/data/content_packs/hsk1/hsk1_pack_v1.json`, `assets/data/content_packs/hsk2/hsk2_pack_v1.json`.
   - File âm thanh MP3 thực tế: Hàng trăm file phát âm trong `assets/audio/hsk1/` và `assets/audio/hsk2/`.
   - Gói học liệu CDN: `content_packs_cdn/` chứa `hsk3_pack_v1.json` và các zip audio pack HSK 3–6.

4. **Phân loại hiện trạng theo quy định**:
   - **IMPLEMENTED**: SQLite Schema v1–v16, WAL lifecycle, Backup/Restore helper, Seed loader v2, Content pack manager (HSK 1-2 bundled), Knowledge registry, Sentence & Audio DAO, Timezone local streak calculation, Route Guard.
   - **PARTIALLY IMPLEMENTED**: Remote Content Pack CDN Downloader (đã có client loader và CDN stub, cần hoàn thiện download background resume).
   - **PLANNED**: Remote Server Sync Queue (đã có model và contract dữ liệu, chưa gắn sync worker lên cloud server).

---

### 2. File Đã Thay Đổi / Tạo Mới

- `docs/agent-coordination/status/thread-1.md` (Khởi tạo trạng thái Thread 1).
- `docs/agent-coordination/reports/thread-1/TASK-001-REPO-SURVEY.md` (Báo cáo khảo sát).

---

### 3. Schema / Migration Bị Ảnh Hưởng

- Không có thay đổi schema trong tác vụ khảo sát ban đầu. Schema v16 hiện tại hoàn toàn nguyên vẹn và ổn định.

---

### 4. Data Integrity Risk Assessment

- **Rủi ro**: Không có rủi ro mất dữ liệu. Nhánh `feature/thread-1-core` tách biệt độc lập với nhánh `main`.

---

### 5. Interface Bị Ảnh Hưởng & Thread Cần Phối Hợp

- **Thread 2 (Learning System)**: Cung cấp DAO và schema liên quan đến `curriculum_lessons`, `mastery_progress`, `learner_evidence`, `learner_goals`.
- **Thread 3 (AI & Voice)**: Cung cấp `AiCredentialStorage` (FlutterSecureStorage, cấm lưu key vào SQLite) và `AudioAssets` schema.
- **Thread 4 (UI/UX & Mobile)**: Cung cấp `AppRouter`, `AppRouteGuard`, và các Repository query interfaces an toàn không blocking main thread.

---

### 6. Test Đã Chạy & Kết Quả Thực Tế

1. `dart analyze lib test`: **PASS (0 issues)**.
2. Master Unit & Integration Tests:
   - `test/core/startup/app_startup_integration_test.dart`
   - `test/core/network/ai/security/ai_credential_security_test.dart`
   - `test/features/onboarding/onboarding_integration_and_route_guard_test.dart`
   - `test/features/placement_test/placement_test_repository_test.dart`
   - `test/widget_test.dart`
   - **Kết quả**: **44/44 tests PASS (100%)**.

---

### 7. Vấn Đề Còn Lại

- Sẵn sàng tiếp nhận các task tiếp theo thuộc phạm vi Thread 1 (tối ưu hóa Database, Content Platform, hoặc mở rộng Migration).
