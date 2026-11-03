# MODULE INVENTORY – HI CHINESE SYSTEM

Tài liệu này liệt kê toàn bộ các module trong hệ thống HI Chinese, trách nhiệm, các file chủ chốt, quan hệ phụ thuộc và trạng thái triển khai thực tế.

---

## 1. PHÂN BỔ TRẠNG THÁI TRIỂN KHAI

| Trạng thái | Định nghĩa |
| :--- | :--- |
| **IMPLEMENTED** | Đã triển khai đầy đủ mã nguồn, tích hợp dữ liệu, có kiểm thử hoặc luồng thực thi hoạt động thực tế. |
| **PARTIALLY IMPLEMENTED** | Đã có một số thành phần (ví dụ UI hoặc model) nhưng còn thiếu logic nghiệp vụ sâu hoặc tích hợp đầy đủ. |
| **MOCKED** | Đang sử dụng dữ liệu giả lập hoặc API mô phỏng (ví dụ `MockAiProvider`). |
| **PLANNED** | Được định hướng hoặc nhắc đến trong thiết kế nhưng chưa có code. |
| **NOT IMPLEMENTED** | Hoàn toàn chưa tồn tại trong mã nguồn dự án. |
| **BROKEN** | Có mã nguồn nhưng đang gặp lỗi hoặc không thể vận hành bình thường. |

---

## 2. DANH SÁCH TOÀN BỘ CÁC MODULE

### 2.1. Nhóm Core Infrastructure

#### `core/database`
- **Mục đích:** Quản lý kết nối SQLite, cấu hình WAL & bộ nhớ đệm, thực thi Migration tự động từ v1 đến v11.
- **File chính:** `app_database.dart`, `database_constants.dart`, `migrations/migration_engine.dart`, `migrations/migration_v1.dart` đến `migration_v11.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** Đã có bộ test `test/core/database/database_migration_test.dart` và `app_database_test.dart` chạy qua 11 phiên bản schema.

#### `core/audio`
- **Mục đích:** Cung cấp dịch vụ phát và ghi âm thanh đơn nhất, quản lý vòng đời ứng dụng khi chuyển background.
- **File chính:** `unified_audio_playback_service.dart`, `audio_player_service.dart`, `audio_recorder_service.dart`, `audio_models.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** Đã kiểm thử với `test/core/audio/audio_services_test.dart` và `test/features/audio_management/audio_management_offline_test.dart`.

#### `core/network/ai`
- **Mục đích:** Kết nối với mô hình ngôn ngữ lớn (Gemini REST API & Live API) và lưu trữ khóa bí mật API an toàn.
- **File chính:** `gemini_rest_ai_provider.dart`, `mock_ai_provider.dart`, `ai_credential_storage.dart`, `ai_model_config.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/core/network/ai/ai_service_test.dart`, lưu API Key vào `FlutterSecureStorage`.

#### `core/theme`
- **Mục đích:** Cung cấp Design System theo phong cách Clean Modern, bảng màu White & Light Blue, RubyText (chữ Hán kèm Pinyin), và lưới mễ tự Mǐzìgé.
- **File chính:** `tokens/app_colors.dart`, `tokens/app_typography.dart`, `tokens/app_spacing.dart`, `components/ruby_text.dart`, `app_theme.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** Toàn bộ UI tuân thủ thiết kế, kiểm thử qua `test/core/theme/ruby_text_test.dart` và `design_system_test.dart`.

#### `core/startup`
- **Mục đích:** Điều phối chuỗi khởi động ứng dụng trước khi nạp giao diện chính.
- **File chính:** `app_startup_provider.dart`, `app_startup_state.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** Được nạp tại `AppShell`, xử lý lỗi khởi tạo SQLite có cơ chế retry.

---

### 2.2. Nhóm Học liệu & Giáo trình Cốt lõi

#### `features/curriculum`
- **Mục đích:** Quản lý giáo trình chuẩn HSK, chia nhỏ thành Units, Lessons, Segments (Warmup, Vocab, Grammar, Dialogue, Practice, Mastery).
- **File chính:** `curriculum_repository.dart`, `content_pack_loader.dart`, `curriculum_syllabus_screen.dart`, `lesson_study_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/curriculum/hsk1_content_integrity_test.dart`, `lesson_flow_and_exercise_test.dart`.

#### `features/content_packs`
- **Mục đích:** Quản trị các gói học liệu chuẩn hóa dạng JSON (HSK 1, HSK 2, HSK 3), tải từ CDN hoặc nạp sẵn trong asset, cài đặt nguyên tử và chống trùng lặp.
- **File chính:** `content_pack_manager.dart`, `content_pack_remote_service.dart`, `content_pack_manager_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/content_packs/content_pack_service_test.dart`, `content_pack_normalization_test.dart`.

#### `features/audio_management`
- **Mục đích:** Quản lý tệp âm thanh phát âm HSK 3–6 và Pinyin ngoại tuyến, tải theo khối (chunked/staged), kiểm toán độ phủ âm thanh thực tế, giải phóng đĩa an toàn.
- **File chính:** `audio_storage_manager.dart`, `audio_pack_downloader.dart`, `audio_coverage_auditor.dart`, `audio_asset_dao.dart`, `audio_pack_manager_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/audio_management/audio_management_offline_test.dart` (Tests C–H).

#### `features/pinyin_foundation`
- **Mục đích:** Khóa học ngữ âm tiếng Trung từ con số 0 với 6 Unit chuyên đề, biểu đồ cao độ 5 bậc thanh điệu, động cơ chấm điểm 10 dạng bài tập xác định.
- **File chính:** `pinyin_curriculum_catalog.dart`, `pinyin_exercise_engine.dart`, `pinyin_repository.dart`, `pinyin_tone_contour_chart.dart`, `pinyin_overview_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/pinyin_foundation/pinyin_foundation_test.dart` (Tests A & B).

#### `features/learning_pipeline`
- **Mục đích:** Cầu nối dữ liệu trung tâm, nhận sự kiện hoàn thành bài học, kết quả làm bài tập, kết quả ôn tập SRS để cập nhật đồng bộ sang `mastery_snapshots`, `learner_evidence`, và `srs_items`.
- **File chính:** `learning_pipeline_coordinator.dart`, `mastery_evaluator.dart`, `srs_intake_rules.dart`, `learning_evidence.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/learning_pipeline/learning_pipeline_coordinator_test.dart`.

---

### 2.3. Nhóm Kỹ năng & Thực hành

#### `features/vocabulary_srs`
- **Mục đích:** Ôn tập từ vựng ngắt quãng bằng thuật toán SuperMemo-2 (SM-2), quản lý flashcard, tính toán `interval` và `ease_factor`.
- **File chính:** `srs_repository.dart`, `sm2_engine.dart`, `srs_models.dart`, `flashcard_card.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/vocabulary_srs/srs_integration_test.dart`.

#### `features/practice`
- **Mục đích:** Ngân hàng câu hỏi thích ứng (trắc nghiệm, điền từ, pinyin), chấm điểm cục bộ có bảo vệ chống double submit.
- **File chính:** `practice_repository.dart`, `practice_scoring_engine.dart`, `practice_session_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/practice/practice_scoring_engine_test.dart`.

#### `features/roadmap`
- **Mục đích:** Lập kế hoạch học tập thích ứng, gợi ý bài học tiếp theo, quản lý mục tiêu học tập (HSK 1-6, thời gian hằng ngày).
- **File chính:** `roadmap_repository.dart`, `adaptive_roadmap_engine.dart`, `curriculum_catalog.dart`, `roadmap_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/roadmap/adaptive_roadmap_engine_test.dart`.

#### `features/placement_test`
- **Mục đích:** Đánh giá năng lực đầu vào bằng trắc nghiệm thích ứng trên máy tính (CAT) theo mô hình 2PL IRT, phân loại trình độ và gợi ý vượt cấp Pinyin.
- **File chính:** `placement_test_repository.dart`, `cat_engine.dart`, `cat_item_bank.dart`, `cat_assessment_result.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/placement_test/cat_engine_test.dart`.

#### `features/hanzi_writing`
- **Mục đích:** Luyện viết chữ Hán trên canvas mễ tự, nhận diện và đánh giá thứ tự nét bút, hướng nét và độ khớp.
- **File chính:** `hanzi_writing_repository.dart`, `stroke_evaluator.dart`, `hanzi_canvas.dart`, `hanzi_writing_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/hanzi_writing/stroke_evaluator_test.dart`.

#### `features/dictionary`
- **Mục đích:** Tra cứu từ điển Hán-Việt offline hỗ trợ chữ Giản thể, Phồn thể, Pinyin, lưu từ vựng yêu thích.
- **File chính:** `dictionary_repository.dart`, `dictionary_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/dictionary/dictionary_search_test.dart`.

#### `features/grammar`
- **Mục đích:** Tra cứu và học ngữ pháp tiếng Trung phân loại theo cấp độ HSK, ví dụ đối sánh và bài tập kiểm tra.
- **File chính:** `grammar_repository.dart`, `grammar_evaluation_engine.dart`, `grammar_list_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/grammar/grammar_repository_test.dart`.

#### `features/reading`
- **Mục đích:** Luyện đọc hiểu đoạn văn có tương tác chạm từ xem nghĩa và hỏi bình giảng học thuật từ AI.
- **File chính:** `reading_repository.dart`, `reading_detail_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/reading/reading_repository_test.dart`.

#### `features/listening`
- **Mục đích:** Luyện nghe hiểu đoạn hội thoại và trả lời câu hỏi trắc nghiệm ngữ cảnh.
- **File chính:** `listening_repository.dart`, `listening_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/listening/listening_test.dart`.

#### `features/pronunciation`
- **Mục đích:** Phòng lab luyện phát âm, thu âm giọng nói học viên và phân tích ngữ âm.
- **File chính:** `pronunciation_repository.dart`, `pronunciation_analysis_service.dart`, `pronunciation_lab_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/pronunciation/pronunciation_analysis_test.dart`.

#### `features/shadowing`
- **Mục đích:** Luyện nói đuổi theo mẫu âm thanh bản xứ với thanh hiển thị RubyText và tùy chỉnh tốc độ.
- **File chính:** `shadowing_repository.dart`, `shadowing_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/shadowing/shadowing_repository_test.dart`.

---

### 2.4. Nhóm AI & Quản trị Hệ thống

#### `features/ai_tutor`
- **Mục đích:** Gia sư AI hỗ trợ trò chuyện bằng văn bản và đàm thoại âm thanh hai chiều (Live voice conversation), đưa vào ngữ cảnh học tập thực tế và đề xuất bằng chứng tiếp thu.
- **File chính:** `ai_tutor_repository.dart`, `learner_context_service.dart`, `tutor_context_builder.dart`, `tutor_response_parser.dart`, `voice_conversation_service.dart`.
- **Trạng thái:** **IMPLEMENTED** (Voice Live Mode sử dụng simulated speech recognition pipeline kết hợp kiểm tra phân quyền micro và mô hình kết nối).
- **Bằng chứng:** `test/features/ai_tutor/ai_tutor_text_chat_test.dart`, `ai_tutor_voice_chat_test.dart`.

#### `features/profile`
- **Mục đích:** Quản lý thông tin hồ sơ học viên cục bộ, thay đổi mục tiêu HSK và ghi vết lịch sử thay đổi mục tiêu.
- **File chính:** `profile_repository.dart`, `profile_screen.dart`, `user_profile.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/profile/profile_and_settings_test.dart`.

#### `features/settings`
- **Mục đích:** Quản lý sao lưu cơ sở dữ liệu nguyên tử (SQLite VACUUM INTO), xuất/nhập file JSON, kiểm tra tính toàn vẹn và reset dữ liệu học tập an toàn.
- **File chính:** `data_management_service.dart`, `data_management_sheet.dart`, `ai_settings_screen.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/settings/ai_settings_test.dart`, `test/features/profile/profile_and_settings_test.dart`.

#### `features/home`
- **Mục đích:** Màn hình chính điều hướng toàn cục, hiển thị chuỗi ngày học liên tục (streak), thẻ bài học khuyến nghị, số thẻ cần ôn tập trong ngày và phím tắt nhanh.
- **File chính:** `home_repository.dart`, `home_screen.dart`, `learning_streak.dart`.
- **Trạng thái:** **IMPLEMENTED**
- **Bằng chứng:** `test/features/home/home_screen_widget_test.dart`.

---

### 2.5. Các Chức năng Ngoại vi Được Khảo sát

| Chức năng | Trạng thái | Ghi chú & Bằng chứng thực tế |
| :--- | :---: | :--- |
| **Hệ thống Đăng nhập / Đăng ký từ xa (Remote Auth)** | **NOT IMPLEMENTED** | Ứng dụng là 100% Offline-first cục bộ, không có server user session hay OAuth/JWT. |
| **Server Đồng bộ 2 chiều (Bidirectional Sync Engine)** | **NOT IMPLEMENTED** | Không có backend API hay hàng đợi sync hai chiều. |
| **Cloudflare Tunnel** | **NOT IMPLEMENTED** | Không có file cấu hình hoặc dịch vụ kết nối tunnel trong codebase. |
| **Phân phối nội dung tĩnh từ CDN** | **IMPLEMENTED** | Nạp file qua HTTP GET từ GitHub Raw repo (`ContentPackRemoteService`, `ContentSourceConfig`). |
| **Nhập/Xuất tiến độ thủ công (JSON/Backup)** | **IMPLEMENTED** | Triển khai trong `DataManagementService` qua file cục bộ. |
