# HI CHINESE – MASTER DATA INTEGRATION AUDIT
**Tài liệu Khảo sát & Đánh giá Toàn diện 4 Giai đoạn Dữ liệu Học tập**
*Ngày lập: 03/11/2026 | Phiên bản: 1.0.0 | Tác giả: Principal Software Architect & Senior Data Engineer*

---

## 1. TỔNG QUAN KHẢO SÁT

HI Chinese đã trải qua 4 giai đoạn xây dựng và chuẩn hóa dữ liệu học tập HSK 1–6 độc lập từ các nguồn dữ liệu mở (Open Source):
1. **Giai đoạn 1**: Từ vựng và từ điển HSK 1–6 (Nguồn `clem109/hsk-vocabulary`, `CC-CEDICT`, `hanviet.csv`).
2. **Giai đoạn 2**: Ngữ pháp tiếng Trung HSK 1–6 (Nguồn `AllSet Learning Chinese Grammar Wiki`, `HSK 3.0 Grammar Syllabus - Gushi`).
3. **Giai đoạn 3**: Chữ Hán, thứ tự nét và đồ họa vector (Nguồn `Make Me a Hanzi`, `Hanzi Writer`).
4. **Giai đoạn 4**: Câu ví dụ, âm thanh bản ngữ và hệ thống luyện nghe/shadowing (Nguồn `Tatoeba Project`, ngữ liệu HSK đối sánh).

Báo cáo này kiểm tra thực tế trên mã nguồn, cơ sở dữ liệu SQLite, các tệp asset JSON, script ETL và hệ thống kiểm thử nhằm thiết lập nền tảng cho việc hợp nhất thành **Hệ tri thức học tập thống nhất (Unified Learning Knowledge Base)**.

---

## 2. BẢNG PHÂN LOẠI TRẠNG THÁI CÁC THÀNH PHẦN HỆ THỐNG

| Thành phần / Module | Trạng thái | Bằng chứng mã nguồn (File & Symbol) | Đánh giá & Ghi chú |
| :--- | :---: | :--- | :--- |
| **HSK 1–6 Vocabulary Data** | `IMPLEMENTED` | `assets/data/hsk_seed_fixture_v2.json` (5.000 từ)<br>`lib/core/database/migrations/migration_v12.dart`<br>`lib/core/database/dao/vocabulary_dao.dart` | 5.000 từ vựng đã được chuẩn hóa Pinyin có dấu, Pinyin số, Hán-Việt, phân nghĩa nhiều senses và ví dụ. |
| **Offline Smart Dictionary** | `IMPLEMENTED` | `lib/features/dictionary/presentation/screens/dictionary_screen.dart`<br>`lib/features/dictionary/data/dictionary_repository.dart` | Tra cứu đa chế độ (Hanzi, Pinyin, nghĩa tiếng Việt), lưu từ vựng, ghi chú và lịch sử tìm kiếm. |
| **HSK 1–6 Grammar Catalog** | `IMPLEMENTED` | `assets/data/hsk_grammar_all.json` (1.027 điểm, 6.174 ví dụ)<br>`lib/core/database/migrations/migration_v13.dart`<br>`lib/features/grammar/data/grammar_repository.dart` | Đối chiếu song song HSK 3.0 và AllSet Wiki A1–B2, phân loại theo danh mục `grammar_topics`. |
| **Grammar Exercise Engine** | `IMPLEMENTED` | `lib/features/grammar/domain/engine/grammar_exercise_generator.dart`<br>`lib/features/grammar/domain/engine/grammar_evaluation_engine.dart` | Sinh bài tập trắc nghiệm cấu trúc, phát hiện lỗi sai, sắp xếp câu theo quy tắc ngôn ngữ học thực tế. |
| **Make Me a Hanzi Stroke Data** | `IMPLEMENTED` | `assets/data/hanzi_stroke_data.json` (2.632 chữ)<br>`lib/core/database/migrations/migration_v14.dart`<br>`lib/features/hanzi/data/hanzi_dao.dart` | Đồ họa vector SVG đường nét, trung tuyến nét (medians), số nét, bộ thủ và phân rã chữ. |
| **Hanzi Handwriting Engine** | `IMPLEMENTED` | `lib/features/hanzi/presentation/screens/hanzi_writing_screen.dart`<br>`lib/features/hanzi/presentation/widgets/hanzi_writer_widget.dart` | Vẽ hoạt hình nét chữ mượt mà qua CustomPainter, chế độ tập viết kiểm tra dung sai tọa độ thực tế. |
| **Sentence Corpus Data** | `IMPLEMENTED` | `assets/data/sentences_corpus.json` (1.500 câu chuẩn)<br>`data_pipeline/processed/sentences_all.json` (10.656 câu)<br>`lib/core/database/migrations/migration_v15.dart` | Phân đoạn từ vựng (tokenization), gắn thẻ ngữ pháp, 100% câu trong asset có âm thanh người thật. |
| **Audio Playback & TTS Engine** | `IMPLEMENTED` | `lib/features/sentences/domain/services/sentence_audio_manager.dart`<br>`lib/features/sentences/domain/services/native_tts_service.dart` | Tách biệt minh bạch: Giọng người thật Tatoeba vs Giọng tổng hợp OS TTS vs Giọng Studio CosyVoice2. |
| **Listening & Shadowing Practice** | `IMPLEMENTED` | `lib/features/sentences/presentation/screens/sentence_listening_screen.dart`<br>`lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart` | Nghe chỉnh tốc độ, ẩn hiện Pinyin/Hán tự, thu âm giọng người học kèm sóng âm (amplitude) và tự đánh giá. |
| **Audio Pack Manager** | `IMPLEMENTED` | `lib/features/sentences/data/audio_pack_manager.dart`<br>`lib/features/sentences/presentation/screens/audio_pack_manager_screen.dart` | Quản lý tải và xóa các gói audio theo cấp độ HSK 1–6 ngoại tuyến kèm mã băm SHA-256. |
| **Canonical Knowledge Registry** | `PARTIALLY_IMPLEMENTED` | `lib/core/database/dao/knowledge_registry_dao.dart`<br>`lib/core/database/migrations/migration_v10.dart` | Đã thiết lập bảng và ghi nhận Vocabulary khi seed, nhưng chưa tự động đăng ký liên thông cho Grammar, Hanzi và Sentence. |
| **Cross-Domain Relational Hub** | `PARTIALLY_IMPLEMENTED` | `lib/features/dictionary/presentation/widgets/dictionary_detail_sheet.dart` | Giao diện đã có nút gọi chéo (Từ vựng -> Luyện viết chữ; Câu ví dụ -> Luyện nghe), nhưng tầng dữ liệu chưa có Facade Service tập trung. |
| **Offline SRS Progress Preserver** | `IMPLEMENTED` | `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`<br>`lib/core/database/dao/learner_evidence_dao.dart` | Ghi nhận bằng chứng học tập (append-only), tính toán độ bền trí nhớ, bảo toàn tiến độ qua các bản cập nhật Content Pack. |
| **Server Sync & Cloud Backup** | `PLANNED` | `docs/system-documentation/07-server-and-sync.md` | Đã thiết kế giao thức đồng bộ phân tầng (Content vs Progress), chưa triển khai endpoint cloud production. |

---

## 3. THỐNG KÊ SỐ LIỆU ĐÃ KIỂM TRA THỰC TẾ TRONG REPOSITORY

Các số liệu dưới đây được trích xuất trực tiếp qua lệnh kiểm toán Python trên các tệp dữ liệu đã đóng gói trong dự án:

| Nhóm dữ liệu | HSK 1 | HSK 2 | HSK 3 | HSK 4 | HSK 5 | HSK 6 | **Tổng cộng** |
| :--- | ---:| ---:| ---:| ---:| ---:| ---:| ---:|
| **Từ vựng đã chuẩn hóa (Vocabularies)** | 150 | 150 | 299 | 601 | 1.300 | 2.500 | **5.000** |
| **Điểm ngữ pháp (Grammar Points)** | 115 | 156 | 152 | 180 | 217 | 207 | **1.027** |
| **Câu ví dụ ngữ pháp (Grammar Examples)** | 836 | 1.177 | 1.111 | 1.203 | 1.215 | 632 | **6.174** |
| **Chữ Hán có nét vector (Hanzi Characters)**| 178 | 168 | 272 | 453 | 639 | 922 | **2.632** |
| **Câu ví dụ đóng gói sẵn (Corpus Sentences)**| 250 | 250 | 250 | 250 | 250 | 250 | **1.500** |
| **Câu có giọng người thật trong Asset** | 250 | 250 | 250 | 250 | 250 | 250 | **1.500** |
| **Toàn bộ kho câu mở rộng (All Sentences)** | 1.524 | 1.566 | 1.689 | 1.970 | 2.243 | 1.664 | **10.656** |
| **Toàn bộ câu có giọng người thật (All Audio)**| 1.167 | 943 | 861 | 1.043 | 1.131 | 545 | **5.690** |

---

## 4. ĐÁNH GIÁ CÁC VẤN ĐỀ CẦN KHẮC PHỤC KHI HỢP NHẤT

1. **Tính rời rạc giữa các Repository**:
   - `DictionaryRepository`, `GrammarRepository`, `HanziRepository`, `SentenceRepository` đang hoạt động độc lập.
   - Khi người học mở 1 từ vựng (ví dụ: `学习`), tầng dữ liệu cần truy xuất tức thời:
     - Các chữ Hán cấu thành (`学`, `习`) và tọa độ nét từ `hanzi_characters`.
     - Các câu ví dụ chứa từ `学习` có giọng đọc người thật từ `sentences` và `sentence_audio`.
     - Các cấu trúc ngữ pháp liên quan.
2. **Đồng bộ hóa Knowledge Registry**:
   - Bảng `knowledge_registry` (tạo từ Migration v10) mới chỉ đăng ký các mục `vocabulary`.
   - Cần bổ sung cơ chế đăng ký tự động và đồng bộ cho `grammar` và `hanzi` để làm đầu mối duy nhất liên kết với `learner_evidence`, `mastery_progress` và `srs_items`.
3. **Quản lý ID và Ánh xạ chéo**:
   - Cần chuẩn hóa tiền tố ID thống nhất:
     - Vocabulary: `voc_hsk{lvl}_{code}` hoặc `KNOW_VOCAB_{hanzi}`
     - Grammar: `gram_hsk{lvl}_{code}`
     - Hanzi: `char_{unicode_hex}`
     - Sentence: `tat_{source_id}` hoặc `sent_hsk{lvl}_{idx}`
     - Audio: `aud_tat_{id}` hoặc `aud_tts_{id}`
4. **Bảo toàn 100% tiến độ học tập của người dùng**:
   - Không được phép sửa đổi khóa ngoại hoặc ID gây mồ côi (orphan) dữ liệu trong các bảng:
     - `learner_evidence`
     - `mastery_snapshots`
     - `sentence_practice_progress`
     - `hanzi_writing_progress`
     - `grammar_progress`
     - `user_saved_words`
