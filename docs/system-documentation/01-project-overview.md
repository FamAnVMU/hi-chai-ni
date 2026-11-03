# 01. TỔNG QUAN DỰ ÁN & PHẠM VI NGHIỆP VỤ

---

## 1. THÔNG TIN DỰ ÁN

- **Tên sản phẩm:** HI Chinese (Phiên hiệu mã nguồn: `hi_chinese`).
- **Namespace ứng dụng:** `com.hichinese.hi_chinese`.
- **Phiên bản hiện tại:** `1.0.7` (Build `8`).
- **Mục đích:** Xây dựng một nền tảng tự học tiếng Trung hoàn chỉnh, tự cung tự cấp (Self-contained), hoạt động ngoại tuyến (Offline-First), định hình lộ trình học theo chuẩn HSK 2.0 (mở rộng HSK 3.0), lấy học liệu có cấu trúc làm trung tâm và sử dụng AI như một trợ lý tương tác bổ trợ.
- **Đối tượng sử dụng:**
  - Người học bắt đầu từ con số 0 (chưa biết gì về tiếng Trung, cần học phát âm Pinyin).
  - Người tự học HSK 1 đến HSK 6 cần lộ trình bài bản, tra từ điển, luyện viết chữ Hán và ôn tập thẻ nhớ ngắt quãng.
  - Người luyện nói và giao tiếp phản xạ thực tế cần luyện đọc mẫu (Shadowing) và đàm thoại ngữ cảnh với Gia sư AI.
- **Phạm vi sản phẩm:**
  - Nền tảng di động: **Android 64-bit (`android-arm64`)** là nền tảng mục tiêu chính thức.
  - Hỗ trợ màn hình cảm ứng, hiển thị dạng dọc (Portrait Locked).
  - Không bắt buộc kết nối Internet trong quá trình học hằng ngày nếu đã tải trước dữ liệu bài học và âm thanh.
- **Mô hình hoạt động:**
  - **Local-First / Offline-First:** Dữ liệu học viên, tiến độ bài học, flashcard và từ điển lưu 100% trong SQLite cục bộ.
  - **One-Way Static Content Distribution:** Nạp gói học liệu HSK và tài nguyên âm thanh qua HTTP GET từ GitHub Raw CDN hoặc static mirror.
  - **On-Demand Auxiliary AI:** Chỉ kết nối API Google Gemini khi người dùng chủ động vào tab Gia sư AI hoặc yêu cầu AI giải thích chuyên sâu.

---

## 2. PHÂN NHÓM CHỨC NĂNG VÀ TRẠNG THÁI TRIỂN KHAI

Bảng dưới đây khảo sát toàn diện mọi chức năng trong hệ thống kèm trạng thái triển khai thực tế dựa trên chứng cứ mã nguồn:

| Phân nhóm chức năng | Tên tính năng cụ thể | Trạng thái thực tế | Bằng chứng mã nguồn |
| :--- | :--- | :---: | :--- |
| **Quản lý người học** | Hồ sơ người dùng cục bộ | **IMPLEMENTED** | `lib/features/profile/data/repositories/profile_repository.dart` |
| | Cấu hình mục tiêu học tập (Cấp độ, thời gian) | **IMPLEMENTED** | `lib/features/profile/presentation/widgets/edit_goal_dialog.dart` |
| | Lịch sử thay đổi mục tiêu | **IMPLEMENTED** | Bảng `goal_history`, `GoalHistoryRecord` |
| | Hệ thống tài khoản từ xa / Đăng nhập từ xa | **NOT IMPLEMENTED** | Không có remote authentication server hay user database tập trung. |
| **Pinyin Foundation** | Khóa học ngữ âm 6 Unit từ số 0 | **IMPLEMENTED** | `lib/features/pinyin_foundation/domain/curriculum/pinyin_curriculum_catalog.dart` |
| | Biểu đồ cao độ thanh điệu 5 bậc | **IMPLEMENTED** | `lib/features/pinyin_foundation/presentation/widgets/pinyin_tone_contour_chart.dart` |
| | Động cơ chấm 10 dạng bài tập Pinyin xác định | **IMPLEMENTED** | `lib/features/pinyin_foundation/domain/engine/pinyin_exercise_engine.dart` |
| | Theo dõi tiến độ âm vị | **IMPLEMENTED** | Bảng `pinyin_progress`, `PinyinRepository` |
| **Giáo trình HSK** | Cấu trúc phân cấp Curriculum / Unit / Lesson | **IMPLEMENTED** | `lib/features/curriculum/domain/models/curriculum_models.dart` |
| | 6 Phân đoạn bài học (Warmup, Vocab, Grammar, Dialogue, Practice, Mastery) | **IMPLEMENTED** | `lib/features/curriculum/presentation/screens/lesson_study_screen.dart` |
| | Đề thi tốt nghiệp cấp độ HSK | **IMPLEMENTED** | `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart` |
| **Từ vựng & Flashcards**| Tra cứu từ điển Hán - Việt offline | **IMPLEMENTED** | `lib/features/dictionary/data/dictionary_repository.dart` |
| | Lưu từ vựng yêu thích & ghi chú | **IMPLEMENTED** | Bảng `user_saved_words` |
| | Ôn tập lặp lại ngắt quãng (SM-2) | **IMPLEMENTED** | `lib/features/vocabulary_srs/domain/sm2_engine.dart`, bảng `srs_items` |
| **Ngữ pháp & Luyện tập** | Danh bạ ngữ pháp HSK & ví dụ đối sánh | **IMPLEMENTED** | `lib/features/grammar/data/grammar_repository.dart` |
| | Ngân hàng câu hỏi thích ứng | **IMPLEMENTED** | `lib/features/practice/data/practice_repository.dart` |
| | Chấm điểm bài tập có chống double submit | **IMPLEMENTED** | `lib/features/practice/domain/engine/practice_scoring_engine.dart` |
| **Kỹ năng Chuyên sâu** | Luyện viết chữ Hán trên canvas mễ tự | **IMPLEMENTED** | `lib/features/hanzi_writing/domain/engine/stroke_evaluator.dart` |
| | Luyện đọc hiểu tương tác từ vựng | **IMPLEMENTED** | `lib/features/reading/presentation/screens/reading_detail_screen.dart` |
| | Luyện nghe hiểu bài đọc | **IMPLEMENTED** | `lib/features/listening/presentation/screens/listening_screen.dart` |
| | Phòng lab luyện phát âm | **IMPLEMENTED** | `lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart` |
| | Luyện nói đuổi (Shadowing) theo giọng bản xứ | **IMPLEMENTED** | `lib/features/shadowing/presentation/screens/shadowing_screen.dart` |
| **Lộ trình & Đánh giá**| Đánh giá thích ứng máy tính (CAT 2PL IRT) | **IMPLEMENTED** | `lib/features/placement_test/domain/engine/cat_engine.dart` |
| | Vượt cấp Pinyin tự động khi làm CAT | **IMPLEMENTED** | `CatAssessmentResult.shouldBypassPinyinFoundation` |
| | Lập lộ trình học tập thích ứng | **IMPLEMENTED** | `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart` |
| **Gia sư AI** | Trò chuyện văn bản với Gia sư AI (REST) | **IMPLEMENTED** | `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart` |
| | Đàm thoại âm thanh hai chiều (Live API Mode)| **IMPLEMENTED** | `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart` |
| | Trích xuất ngữ cảnh học tập đưa vào AI | **IMPLEMENTED** | `lib/features/ai_tutor/domain/context/learner_context_service.dart` |
| | Hàng rào bảo vệ (Guardrails) chống bịa đặt | **IMPLEMENTED** | `test/features/ai_tutor/ai_tutor_auxiliary_guardrail_test.dart` |
| **Gói học liệu & Âm thanh**| Gói học liệu chuẩn hóa JSON (HSK 1-3) | **IMPLEMENTED** | `lib/features/content_packs/data/content_pack_manager.dart` |
| | Quản lý tệp âm thanh ngoại tuyến (HSK 3-6) | **IMPLEMENTED** | `lib/features/audio_management/data/audio_storage_manager.dart` |
| | Kiểm toán độ phủ âm thanh thực tế | **IMPLEMENTED** | `lib/features/audio_management/data/audio_coverage_auditor.dart` |
| | Trình phát âm thanh đơn nhất (0.5x - 2.0x) | **IMPLEMENTED** | `lib/core/audio/unified_audio_playback_service.dart` |
| **Quản trị & Bảo mật** | Sao lưu SQLite nguyên tử (`VACUUM INTO`) | **IMPLEMENTED** | `lib/features/settings/data/services/data_management_service.dart` |
| | Xuất / Nhập tiến độ ra file JSON | **IMPLEMENTED** | `DataManagementService.exportUserDataJson` |
| | Lưu trữ an toàn Gemini API Key | **IMPLEMENTED** | `lib/core/network/ai/security/ai_credential_storage.dart` |
| | Cloudflare Tunnel / Server Sync 2 chiều | **NOT IMPLEMENTED** | Không có máy chủ đồng bộ dữ liệu riêng. |

---

## 3. NGUYÊN TẮC THIẾT KẾ SẢN PHẨM (PRODUCT PRINCIPLES)

1. **Học liệu là Nền tảng (Curriculum-First):**
   - Mọi hoạt động học tập đều bám sát khung năng lực HSK (từ vựng, ngữ pháp, mẫu câu chuẩn).
   - Nội dung học tập được chuẩn hóa bằng mã định danh ổn định (`knowledge_registry`) để không bị xáo trộn khi nâng cấp ứng dụng.
2. **AI là Trợ lý Bổ trợ, Không phải Nguồn Dữ liệu Tuyệt đối (Auxiliary AI):**
   - Không để AI tự ý chấm điểm tùy tiện hoặc ghi đè tiến độ học tập.
   - Các bài kiểm tra ngữ âm, từ vựng, trắc nghiệm được đánh giá bằng thuật toán quy tắc xác định (Deterministic Rule Engines).
   - Mọi đề xuất bằng chứng tiếp thu của AI phải tuân thủ schema JSON và kiểm duyệt hợp lệ trước khi ghi vào cơ sở dữ liệu.
3. **Ngoại tuyến Hoàn toàn (Offline-First):**
   - Ứng dụng phải mở được, học được bài, tra được từ điển và ôn tập được thẻ nhớ ngay cả khi điện thoại ở chế độ máy bay.
   - Khi có kết nối mạng, người dùng chỉ dùng mạng để tải thêm gói học liệu tĩnh hoặc trò chuyện với Gia sư AI.
4. **Không Đánh đố hay Gây rối mắt (Clean Modern Minimalism):**
   - Tuân thủ bảng màu chủ đạo Trắng & Xanh lam (`#5B9BE6`), loại bỏ gradient dày đặc, glassmorphism quá mức hoặc animation không cần thiết.
   - Mọi ký tự chữ Hán đều được hỗ trợ kèm phiên âm Pinyin căn chỉnh chính xác (`RubyText`).
