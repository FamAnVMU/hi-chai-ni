# TEST INVENTORY – BỘ BẢO ĐẢM CHẤT LƯỢNG VÀ KIỂM THỬ

Toàn bộ hệ thống kiểm thử gồm **64 file test** chạy độc lập trên môi trường `sqflite_common_ffi` và Flutter Test Harness.  
Tỷ lệ vượt qua hiện tại: **100% PASS** trên toàn bộ các bộ test nghiệp vụ cốt lõi.

---

## 1. PHÂN LOẠI TEST THEO TẦNG KIẾN TRÚC

```text
test/
├── benchmark/       (Kiểm tra hiệu năng khởi động SQLite, WAL mode, nạp JSON Isolate)
├── core/            (Kiểm thử Database, Migrations v1-v11, Audio Services, AI Network, Theme)
├── features/        (Kiểm thử logic nghiệp vụ chuyên sâu từng tính năng)
└── regression/      (Bộ kiểm thử hồi quy toàn diện E2E và Safeguards)
```

---

## 2. DANH MỤC CHI TIẾT CÁC FILE TEST

### 2.1. Kiểm thử Core & Nền tảng (Database, Audio, AI, Theme)
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/core/database/database_migration_test.dart` | Integration | Thực thi tuần tự các bản di chuyển dữ liệu từ v1 đến v11, kiểm tra rollback khi gặp lỗi cú pháp cố ý. | **PASSED** |
| `test/core/database/app_database_test.dart` | Unit / DB | Khởi tạo kết nối SQLite, cấu hình WAL mode và kiểm tra bộ nhớ đệm cache size. | **PASSED** |
| `test/core/database/curriculum_schema_v9_test.dart`| Unit / DB | Xác thực cấu trúc phân cấp giáo trình (Packs -> Curriculums -> Units -> Lessons -> Segments). | **PASSED** |
| `test/core/database/seed/seed_loader_test.dart` | Unit / DB | Nạp dữ liệu mồi fixture JSON vào SQLite với cơ chế idempotent (chống trùng lặp). | **PASSED** |
| `test/core/audio/audio_services_test.dart` | Unit | Trình phát và ghi âm thanh, kiểm soát trạng thái Stream và ngắt khi chuyển vòng đời. | **PASSED** |
| `test/core/network/ai/ai_service_test.dart` | Unit / Mock | Kết nối Gemini REST Provider, xử lý timeout, lỗi 429 và lưu trữ bảo mật API Key. | **PASSED** |
| `test/core/theme/design_system_test.dart` | Widget | Kiểm tra bảng màu Clean Modern White & Light Blue, typography, spacing và border radius. | **PASSED** |
| `test/core/theme/ruby_text_test.dart` | Widget | Hiển thị chữ Hán kèm phiên âm Pinyin căn chỉnh chính xác theo tỉ lệ font. | **PASSED** |
| `test/benchmark/performance_benchmark_test.dart` | Benchmark | Đo lường độ trễ mở database SQLite, kích hoạt WAL, phân tích JSON trên background Isolate. | **PASSED** |

### 2.2. Kiểm thử Học liệu & Khóa học Pinyin & Âm thanh Ngoại tuyến
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/features/pinyin_foundation/pinyin_foundation_test.dart` | Integration | **Test A & B**: Học viên học 6 Unit Pinyin, hoàn thành 10 dạng bài tập, ghi nhận `pinyin_progress`, Placement Test đánh giá và cho phép vượt cấp không làm sai lệch từ vựng. | **PASSED** |
| `test/features/audio_management/audio_management_offline_test.dart` | Integration | **Tests C–H**: Tải âm thanh theo khối, xác thực SHA-256, staging nguyên tử, phát hoàn toàn offline, cập nhật vi sai, giải phóng đĩa, kiểm toán độ phủ âm thanh trung thực. | **PASSED** |
| `test/features/content_packs/content_pack_normalization_test.dart` | Integration | **Tests A–G**: Chuẩn hóa Schema v10, chuyển đổi sang `knowledge_registry`, nạp gói HSK 1-3, rollback khi lỗi checksum, cập nhật phiên bản không mất tiến độ. | **PASSED** |
| `test/features/content_packs/content_pack_service_test.dart` | Integration | Nạp gói HSK 2 đóng gói sẵn trong APK và tải gói HSK 3 trực tuyến qua CDN mock. | **PASSED** |
| `test/features/curriculum/hsk1_content_integrity_test.dart` | Integration | Toàn vẹn học liệu HSK 1: đủ 15 bài học, từ vựng, ngữ pháp, bài tập và đề thi tốt nghiệp. | **PASSED** |
| `test/features/curriculum/lesson_flow_and_exercise_test.dart` | Widget / Flow | Luồng đi qua 6 bước bài học (Warmup -> Vocab -> Grammar -> Dialogue -> Practice -> Mastery). | **PASSED** |
| `test/features/curriculum/prerequisite_mastery_engine_test.dart` | Unit | Kiểm tra mở khóa bài học dựa trên điều kiện tiên quyết và phát hiện lỗ hổng tri thức. | **PASSED** |

### 2.3. Kiểm thử Learning Pipeline & Spaced Repetition (SRS)
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/features/learning_pipeline/learning_pipeline_coordinator_test.dart` | Integration | **Tests 1–5**: Hoàn thành bài học cập nhật đồng bộ status, evidence, mastery và nạp thẻ SRS; bài tập củng cố tri thức; ôn tập SRS nâng cấp độ thành thạo; chống nộp lặp; tổng hợp thống kê. | **PASSED** |
| `test/features/vocabulary_srs/srs_integration_test.dart` | Integration | Thuật toán SM-2: xếp hạng Good/Again/Easy, tính khoảng cách ngày, bảo vệ chống chạm đúp liên tiếp (debounce threshold). | **PASSED** |
| `test/features/vocabulary_srs/flashcard_review_widget_test.dart` | Widget | Lật thẻ flashcard, hiển thị nghĩa tiếng Việt, câu ví dụ và các nút đánh giá 4 mức độ. | **PASSED** |

### 2.4. Kiểm thử Kỹ năng Thực hành (Skills & Labs)
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/features/practice/practice_scoring_engine_test.dart` | Unit | Động cơ chấm điểm bài tập xác định, tính điểm bộ phận và mã hóa attempt hash. | **PASSED** |
| `test/features/practice/practice_repository_test.dart` | Integration | Tự động nạp ngân hàng bài tập, lọc theo kỹ năng và loại bài tập. | **PASSED** |
| `test/features/grammar/grammar_evaluation_engine_test.dart` | Unit | Chấm điểm bài tập ngữ pháp, đánh giá lỗi trật tự từ và trợ từ. | **PASSED** |
| `test/features/grammar/grammar_repository_test.dart` | Integration | Tra cứu ngữ pháp, lọc theo chủ đề và bảo vệ trung thực học thuật (Academic Honesty). | **PASSED** |
| `test/features/hanzi_writing/stroke_evaluator_test.dart` | Unit | Thuật toán so khớp nét bút chữ Hán, kiểm tra hướng nét, số lượng nét và sai số tọa độ. | **PASSED** |
| `test/features/hanzi_writing/hanzi_writing_widget_test.dart` | Widget | Tương tác vẽ trên canvas mễ tự Mǐzìgé, nút xóa nét, vẽ lại và hiển thị bảng chấm điểm. | **PASSED** |
| `test/features/dictionary/dictionary_search_test.dart` | Unit / DB | Tra cứu từ điển Hán-Việt, tìm kiếm chính xác và tiền tố (Giản thể / Phồn thể), lưu từ vựng. | **PASSED** |
| `test/features/reading/reading_repository_test.dart` | Integration | Tải bài đọc HSK, lưu tiến độ đọc, hỏi bình giảng học thuật từ AI. | **PASSED** |
| `test/features/reading/reading_interactive_widget_test.dart` | Widget | Chạm vào từ trong đoạn văn để mở popup tra từ điển nhanh. | **PASSED** |
| `test/features/listening/listening_test.dart` | Integration | Luyện nghe đoạn văn và trả lời câu hỏi trắc nghiệm ngữ cảnh. | **PASSED** |
| `test/features/pronunciation/pronunciation_analysis_test.dart` | Unit | Phân tích tệp âm thanh học viên, đánh giá cao độ và thanh điệu. | **PASSED** |
| `test/features/shadowing/shadowing_evaluator_test.dart` | Unit | Đánh giá độ khớp giọng đọc theo mẫu và tính điểm tiến độ. | **PASSED** |

### 2.5. Kiểm thử Đánh giá CAT & Lộ trình & Gia sư AI
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/features/placement_test/cat_engine_test.dart` | Unit | Thuật toán thích ứng 2PL IRT: tính hàm thông tin Fisher, chọn câu hỏi thích ứng theo Theta. | **PASSED** |
| `test/features/placement_test/placement_test_repository_test.dart` | Integration | Ghi nhận phiên test, lưu câu trả lời chi tiết và tính toán kết quả phân loại HSK. | **PASSED** |
| `test/features/roadmap/adaptive_roadmap_engine_test.dart` | Unit | Tạo lộ trình động dựa trên năng lực hiện tại, bài học đã xong và mục tiêu người học. | **PASSED** |
| `test/features/ai_tutor/ai_tutor_text_chat_test.dart` | Widget | Gửi tin nhắn, hiển thị chip gợi ý kịch bản và phản hồi có RubyText. | **PASSED** |
| `test/features/ai_tutor/ai_tutor_voice_chat_test.dart` | Widget / State | Máy trạng thái đàm thoại giọng nói, VAD, ngắt lời và hiển thị pill chẩn đoán Live API. | **PASSED** |
| `test/features/ai_tutor/learner_context_test.dart` | Unit | Trích xuất các lỗi sai lặp lại >= 2 lần và từ vựng yếu để đưa vào context AI. | **PASSED** |
| `test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart` | Unit | Kiểm tra hàng rào an toàn: AI chỉ đóng vai trò hỗ trợ, không tự ý ghi đè dữ liệu học tập cốt lõi. | **PASSED** |

### 2.6. Kiểm thử Toàn diện & Hồi quy Master (Master Regression Suites)
| File Test | Loại test | Phạm vi kiểm tra | Trạng thái |
| :--- | :--- | :--- | :---: |
| `test/regression/full_app_regression_test.dart` | Master E2E | Kiểm thử 15 bài kiểm tra hồi quy tổng hợp toàn ứng dụng từ Database, SM-2, AI Parser, CAT IRT, Roadmap, Practice, Backup đến Permission. | **PASSED** |
| `test/regression/hsk_self_study_platform_master_test.dart` | Master E2E | Kiểm thử tích hợp toàn bộ nền tảng tự học HSK ngoại tuyến: nạp gói học liệu, học bài, kiểm tra tốt nghiệp, gia sư AI hỗ trợ. | **PASSED** |
