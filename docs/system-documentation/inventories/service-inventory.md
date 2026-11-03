# SERVICE INVENTORY – REPOSITORIES, SERVICES & ENGINES

Tài liệu này tổng hợp toàn bộ các lớp nghiệp vụ, kho dữ liệu (Repositories), lớp truy cập dữ liệu (DAOs) và các động cơ tính toán (Pedagogical Engines) trong HI Chinese.

---

## 1. DANH MỤC CÁC REPOSITORY (DATA REPOSITORIES)

| Tên Repository | Interface | File Path | Bảng Database truy xuất | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `CurriculumRepository` | `CurriculumRepository` | `lib/features/curriculum/data/curriculum_repository.dart` | `curriculums`, `curriculum_units`, `curriculum_lessons`, `lesson_segments` | **IMPLEMENTED** |
| `LearningPipelineCoordinator` | `LearningPipelineCoordinator` | `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart` | `lesson_progress`, `learner_evidence`, `mastery_snapshots`, `srs_items` | **IMPLEMENTED** |
| `SrsRepository` | `SrsRepository` | `lib/features/vocabulary_srs/data/srs_repository.dart` | `srs_items`, `vocabularies`, `learner_evidence` | **IMPLEMENTED** |
| `PinyinRepository` | `PinyinRepository` | `lib/features/pinyin_foundation/data/pinyin_repository.dart` | `pinyin_progress`, `knowledge_registry` | **IMPLEMENTED** |
| `PlacementTestRepository` | `PlacementTestRepository` | `lib/features/placement_test/data/placement_test_repository.dart` | `placement_test_sessions`, `placement_test_responses` | **IMPLEMENTED** |
| `RoadmapRepository` | `RoadmapRepository` | `lib/features/roadmap/data/roadmap_repository.dart` | `learner_goals`, `lesson_progress`, `roadmap_snapshots` | **IMPLEMENTED** |
| `ProfileRepository` | `ProfileRepository` | `lib/features/profile/data/repositories/profile_repository.dart` | `user_profiles`, `goal_history` | **IMPLEMENTED** |
| `DictionaryRepository` | `DictionaryRepository` | `lib/features/dictionary/data/dictionary_repository.dart` | `vocabularies`, `vocabulary_senses`, `dictionary_history`, `user_saved_words` | **IMPLEMENTED** |
| `GrammarRepository` | `GrammarRepository` | `lib/features/grammar/data/grammar_repository.dart` | `grammar_items`, `grammar_progress`, `learner_evidence` | **IMPLEMENTED** |
| `PracticeRepository` | `PracticeRepository` | `lib/features/practice/data/practice_repository.dart` | `practice_exercises`, `practice_sessions`, `practice_attempts` | **IMPLEMENTED** |
| `HanziWritingRepository` | `HanziWritingRepository` | `lib/features/hanzi_writing/data/hanzi_writing_repository.dart` | `vocabularies`, `learner_evidence` | **IMPLEMENTED** |
| `ListeningRepository` | `ListeningRepository` | `lib/features/listening/data/repositories/listening_repository.dart` | `practice_exercises`, `learner_evidence` | **IMPLEMENTED** |
| `PronunciationRepository` | `PronunciationRepository` | `lib/features/pronunciation/data/pronunciation_repository.dart` | `vocabularies`, `learner_evidence` | **IMPLEMENTED** |
| `ReadingRepository` | `ReadingRepository` | `lib/features/reading/data/reading_repository.dart` | `reading_passages`, `reading_progress`, `learner_evidence` | **IMPLEMENTED** |
| `ShadowingRepository` | `ShadowingRepository` | `lib/features/shadowing/data/shadowing_repository.dart` | `reading_passages`, `learner_evidence` | **IMPLEMENTED** |
| `AiTutorRepository` | `AiTutorRepository` | `lib/features/ai_tutor/data/repositories/ai_tutor_repository.dart` | `chat_sessions`, `chat_messages`, `learner_evidence` | **IMPLEMENTED** |
| `HomeRepository` | `HomeRepository` | `lib/features/home/data/home_repository.dart` | `learning_activities`, `learner_goals`, `srs_items` | **IMPLEMENTED** |

---

## 2. DANH MỤC CÁC DATA ACCESS OBJECTS (DAOS)

| Tên DAO | File Path | Bảng quản lý | Trách nhiệm chính | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `AudioAssetDao` | `lib/features/audio_management/data/audio_asset_dao.dart` | `audio_assets` | CRUD metadata tệp âm thanh, kiểm tra trạng thái tải và lọc theo cấp độ HSK. | **IMPLEMENTED** |
| `KnowledgeRegistryDao` | `lib/features/curriculum/data/curriculum_repository.dart` | `knowledge_registry`, `lesson_knowledge_items` | Quản lý định danh tri thức chuẩn hóa, liên kết bài học với đơn vị kiến thức. | **IMPLEMENTED** |

---

## 3. DANH MỤC CÁC SERVICE NỀN TẢNG (CORE SERVICES)

| Tên Service | File Path | Trách nhiệm | Trạng thái |
| :--- | :--- | :--- | :---: |
| `UnifiedAudioPlaybackService` | `lib/core/audio/unified_audio_playback_service.dart` | Singleton phát audio ngoại tuyến, quản lý single-audio focus, chỉnh tốc độ đọc 0.5x-2.0x. | **IMPLEMENTED** |
| `AudioStorageManager` | `lib/features/audio_management/data/audio_storage_manager.dart` | Quản trị thư mục lưu trữ `content_packs/{pack_id}/audio/`, staging `.tmp/`, tính dung lượng đĩa. | **IMPLEMENTED** |
| `AudioPackDownloader` | `lib/features/audio_management/data/audio_pack_downloader.dart` | Tải audio theo khối có kiểm tra SHA-256, hỗ trợ pause/resume/cancel/retry và cập nhật vi sai. | **IMPLEMENTED** |
| `AudioCoverageAuditor` | `lib/features/audio_management/data/audio_coverage_auditor.dart` | Kiểm toán tỷ lệ phủ âm thanh thực tế giữa tài nguyên cần và tệp khả dụng (không dùng số liệu giả). | **IMPLEMENTED** |
| `ContentPackManager` | `lib/features/content_packs/data/content_pack_manager.dart` | Cài đặt, cập nhật, gỡ bỏ và xác thực tính toàn vẹn gói học liệu JSON. | **IMPLEMENTED** |
| `ContentPackRemoteService` | `lib/features/content_packs/data/content_pack_remote_service.dart` | Tải gói học liệu trực tuyến từ CDN/GitHub Raw và kích hoạt `ContentPackManager`. | **IMPLEMENTED** |
| `LearnerContextService` | `lib/features/ai_tutor/domain/context/learner_context_service.dart` | Trích xuất điểm yếu ngữ pháp, từ vựng chưa thành thạo để đưa vào prompt Gia sư AI. | **IMPLEMENTED** |
| `VoiceConversationService` | `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart` | Quản lý trạng thái đàm thoại giọng nói, VAD, ngắt lời, phân quyền microphone. | **IMPLEMENTED** |
| `DataManagementService` | `lib/features/settings/data/services/data_management_service.dart` | Sao lưu an toàn bằng `VACUUM INTO`, kiểm tra tính toàn vẹn SQLite, xuất/nhập tiến độ JSON. | **IMPLEMENTED** |
| `AiCredentialStorage` | `lib/core/network/ai/security/ai_credential_storage.dart` | Mã hóa và lưu trữ Gemini API Key vào `FlutterSecureStorage` (Keystore/Keyring). | **IMPLEMENTED** |
| `AppLifecycleManager` | `lib/core/utils/app_lifecycle_manager.dart` | Giám sát trạng thái Foreground/Background của Android để tự động ngắt micro và audio. | **IMPLEMENTED** |
| `PermissionHelper` | `lib/core/utils/permission_helper.dart` | Kiểm tra quyền micro theo ngữ cảnh (Contextual Rationale Dialog) không xin quyền khi mở app. | **IMPLEMENTED** |

---

## 4. DANH MỤC CÁC ĐỘNG CƠ TÍNH TOÁN NGHIỆP VỤ (PEDAGOGICAL ENGINES)

| Tên Engine | File Path | Thuật toán / Nguyên tắc | Trạng thái |
| :--- | :--- | :--- | :---: |
| `Sm2Engine` | `lib/features/vocabulary_srs/domain/sm2_engine.dart` | Thuật toán SuperMemo-2 tinh chỉnh: tính toán khoảng thời gian (Interval), Hệ số dễ dàng (Ease Factor: 1.3 - 3.2), số lần quên (Lapses). | **IMPLEMENTED** |
| `CatEngine` | `lib/features/placement_test/domain/engine/cat_engine.dart` | Đánh giá thích ứng theo mô hình Item Response Theory (2PL IRT): cập nhật năng lực Theta (\(\theta\)) và Sai số chuẩn (SE), chọn câu hỏi có Fisher Information tối đa. | **IMPLEMENTED** |
| `AdaptiveRoadmapEngine` | `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart` | Phân tích bài học đã xong, thẻ SRS quá hạn và kết quả Placement Test để dựng cây lộ trình động. | **IMPLEMENTED** |
| `PinyinExerciseEngine` | `lib/features/pinyin_foundation/domain/engine/pinyin_exercise_engine.dart` | Động cơ chấm điểm xác định (Deterministic Rule Engine) cho 10 dạng bài tập Pinyin, chuẩn hóa Unicode diacritics, không gọi AI. | **IMPLEMENTED** |
| `PracticeScoringEngine` | `lib/features/practice/domain/engine/practice_scoring_engine.dart` | Chấm điểm bài tập trắc nghiệm/điền từ, bảo vệ chống nộp lặp (Idempotent Attempt Hash). | **IMPLEMENTED** |
| `GrammarEvaluationEngine` | `lib/features/grammar/domain/engine/grammar_evaluation_engine.dart` | Đánh giá trắc nghiệm nhận diện cấu trúc ngữ pháp và phân biệt lỗi sai đối sánh. | **IMPLEMENTED** |
| `StrokeEvaluator` | `lib/features/hanzi_writing/domain/engine/stroke_evaluator.dart` | So sánh nét vẽ của học viên với quỹ đạo chuẩn: kiểm tra hướng nét, thứ tự nét và độ sai lệch tọa độ. | **IMPLEMENTED** |
| `TutorResponseParser` | `lib/features/ai_tutor/domain/parsers/tutor_response_parser.dart` | Phân tích chuỗi JSON trả về từ Gemini, bóc tách `reply_zh`, `pinyin`, `reply_vi`, danh sách sửa lỗi `corrections` và đề xuất bằng chứng `evidence_proposal`. | **IMPLEMENTED** |
