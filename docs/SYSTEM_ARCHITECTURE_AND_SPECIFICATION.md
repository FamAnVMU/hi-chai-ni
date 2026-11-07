# 📘 TÀI LIỆU KIẾN TRÚC & ĐẶC TẢ TOÀN DIỆN HỆ THỐNG HI CHINESE (v1.0.16+16)

> **Mục đích tài liệu:** Bản mô tả kỹ thuật đầy đủ 100% về toàn bộ hệ thống ứng dụng HI Chinese. Tài liệu này được thiết kế để bất kỳ AI Agent hoặc kỹ sư phần mềm nào khi tiếp nhận dự án đều có thể hiểu tường tận cấu trúc, luồng nghiệp vụ, cơ sở dữ liệu SQLite Schema v20, các thuật toán lõi và toàn bộ phân hệ chức năng mà không bị thiếu sót bất kỳ chi tiết nào.

---

## 1. TỔNG QUAN DỰ ÁN & NGUYÊN TẮC THIẾT KẾ CỐT LÕI

### 1.1. Thông tin chung
- **Tên ứng dụng:** **HI Chinese**
- **Tên gói (Package Name):** `hi_chinese`
- **Phiên bản hiện tại:** `v1.0.16+16`
- **Hệ điều hành mục tiêu:** Android (Hỗ trợ từ Android 7.0 / API Level 24 đến Android 14+ / API Level 34+)
- **Kho mã nguồn:** GitHub (`https://github.com/FamAnVMU/hi-chai-ni.git`)

### 1.2. Triết lý thiết kế (Core Design Philosophy)
1. **Offline-First làm trung tâm:** Toàn bộ giáo trình HSK (từ vựng, điểm ngữ pháp, bài tập, phát âm mẫu, dữ liệu bút thuận, bài đọc hiểu và đề thi tốt nghiệp) được lưu trữ và vận hành cục bộ trên thiết bị thông qua SQLite Schema v20 và các gói nội dung JSON độc lập. Học viên có thể tự học 100% mà không phụ thuộc vào kết nối mạng Internet.
2. **Auxiliary AI Pattern (Mô hình AI Bổ Trợ):** 
   - Cơ sở dữ liệu SQLite cục bộ là **Nguồn Chân Lý Duy Nhất (Single Source of Truth)**.
   - Mô hình ngôn ngữ lớn (Google Gemini API) chỉ đóng vai trò **Trợ giảng bổ trợ (Auxiliary Assistant)**: giải thích ngữ cảnh chuyên sâu, hỗ trợ đàm thoại tình huống tự nhiên và phân tích lỗi sai khi có Internet.
   - **Rào chắn an toàn (Safety Boundary):** AI tuyệt đối không can thiệp trực tiếp vào việc ghi đè giáo trình, không tự tạo đáp án chuẩn trong bài tập và không sửa đổi trạng thái tiến độ người học.
3. **Clean Architecture kết hợp Feature-First:** Mã nguồn được tổ chức theo module chức năng độc lập (Feature-First), bên trong mỗi module tuân thủ phân lớp Clean Architecture:
   - `data`: Repository implementation, DAO, Remote services, Loaders.
   - `domain`: Entities, Value objects, Domain engines, Business validators.
   - `presentation`: Riverpod Providers, Screens, Custom Widgets.
4. **Bảo toàn dữ liệu tuyệt đối (Zero Progress Loss Guarantee):** Các bản cập nhật phiên bản ứng dụng và cơ chế nâng cấp Schema Migration tuyệt đối không bao giờ làm mất lịch sử học, tiến độ bài học, dữ liệu ôn tập SRS hay chuỗi ngày học của học viên.

---

## 2. NGĂN XẾP CÔNG NGHỆ (TECH STACK)

| Phân tầng | Công nghệ / Thư viện | Phiên bản | Vai trò & Mục đích sử dụng |
| :--- | :--- | :--- | :--- |
| **Framework** | Flutter | `>= 3.24.0` | Nền tảng xây dựng UI di động native 60fps/120fps |
| **Ngôn ngữ** | Dart | `>= 3.5.0 < 4.0.0` | Ngôn ngữ phát triển chính |
| **State Management** | `flutter_riverpod` | `^2.5.1` | Dependency Injection, StateNotifier, AsyncNotifier, Reactive Provider |
| **Cơ sở dữ liệu** | `sqflite`, `sqlite3` | `^2.3.3+1` | SQLite cục bộ Schema v20, chế độ WAL (Write-Ahead Logging) |
| **Mã hóa an toàn** | `flutter_secure_storage`| `^9.2.2` | Lưu trữ an toàn Gemini API Key và khóa nhạy cảm trên Keystore Android |
| **Âm thanh (Audio)** | `audioplayers` | `^6.0.0` | Phát tập tin âm thanh MP3 từ local asset hoặc file storage |
| **Thu âm (Recording)** | `record` | `^5.1.2` | Thu âm giọng nói người học phục vụ Luyện phát âm & Shadowing |
| **Giọng đọc (TTS)** | `flutter_tts` | `^4.0.2` | Chuyển văn bản thành giọng đọc tiếng Trung Bắc Kinh chuẩn (`zh-CN`) |
| **Trí tuệ nhân tạo** | `google_generative_ai` | `^0.4.0` | Kết nối Google Gemini API (Gemini 1.5 Flash / Pro) |
| **Biểu đồ & Đồ thị** | `fl_chart` | `^0.68.0` | Vẽ biểu đồ cao độ thanh điệu Pinyin, phân tích kỹ năng Radar CAT |
| **Hệ thống Design** | Material 3 Tokens | Tự dựng | Bảng màu Lime Green / Dark Forest / Primary Blue, WCAG 2.2 AA |

---

## 3. CƠ SỞ DỮ LIỆU SQLITE SCHEMA v20 (CHI TIẾT 48 BẢNG DỮ LIỆU)

Ứng dụng sử dụng tệp SQLite `hi_chinese.db`, quản lý thông qua [`AppDatabase`](file:///C:/Users/phama/Downloads/hi_chinese/lib/core/database/app_database.dart) và chuỗi di chuyển [`MigrationEngine`](file:///C:/Users/phama/Downloads/hi_chinese/lib/core/database/migrations/migration_engine.dart). Dưới đây là danh sách đầy đủ **48 bảng dữ liệu** (được kiểm chứng tự động 100% giữa `DatabaseConstants`, `onCreate(0 -> v20)` và `onUpgrade(v1 -> v20)` trong `database_migration_test.dart`):

### 3.1. Phân hệ Giáo trình & Nội dung HSK (Schema v9)
1. **`curriculums`**: Quản lý cấp độ giáo trình tổng thể (`curr_hsk1` đến `curr_hsk6`).
2. **`curriculum_units`**: Các chủ đề/chương học thuộc từng cấp độ giáo trình.
3. **`curriculum_lessons`**: Danh sách bài học chi tiết.
   - Các cột: `id`, `unit_id`, `order_index`, `title_vi`, `title_zh`, `pinyin`, `status` (`notStarted`, `inProgress`, `completed`, `mastered`), `is_locked`, `prerequisites` (danh sách ID bài tiên quyết).
4. **`lesson_segments`**: Các phân đoạn nội dung của bài học (`warmup`, `vocabulary`, `grammar`, `dialogue`, `practice`, `mastery_check`). Chứa cột `content_payload` (JSON).
5. **`content_items`**: Lưu trữ các thực thể kiến thức nguyên tử để tham chiếu chéo giữa các phân hệ.
6. **`curriculum_mastery`**: Bảng tổng hợp mức độ thành thạo của người học theo từng kỹ năng và bài học.
7. **`level_exit_exams`**: Đề thi tốt nghiệp cấp độ HSK chuẩn quốc tế (40 câu hỏi, thang điểm 200, thời gian 35 phút).
8. **`content_packs`**: Quản lý phiên bản và trạng thái cài đặt của các gói học liệu mở rộng (`hsk1_pack_v1.json` -> `hsk6_pack_v1.json`).

### 3.2. Phân hệ Chuẩn hóa Tri thức & Ánh xạ ID (Schema v10)
9. **`knowledge_registry`**: Sổ đăng ký tri thức chuẩn hóa liên kết với mã chuẩn HSK 3.0.
10. **`lesson_knowledge_items`**: Bảng ánh xạ quan hệ nhiều-nhiều giữa bài học và mã tri thức.
11. **`content_id_mappings`**: Ánh xạ ID nội dung cũ sang ID chuẩn hóa để chống phân mảnh khi nâng cấp.

### 3.3. Phân hệ Hoạt động Học tập, Tiến độ & Chuỗi Ngày Học (Streak)
12. **`learning_activities`**: Lưu trữ từng phiên học tập thực tế.
    - Các cột: `id`, `activity_type` (`lesson_completion`, `srs_review`, `practice_session`, `reading`, v.v.), `duration_seconds`, `items_count`, `activity_date` (định dạng `YYYY-MM-DD` theo giờ địa phương), `timezone_offset_minutes` (Schema v16), `created_at` (Schema v17 index).
    - Đây là bảng nguồn duy nhất quyết định việc tính chuỗi ngày học liên tục (**Streak 🔥**) trên Trang chủ.
13. **`lesson_progress`**: Lưu tiến trình chi tiết của từng bài học: `lesson_id`, `step_index`, `score`, `is_passed`, `completed_at`, `source` (`curriculum_self_study`, `placement_test_unlock` - Schema v18).
14. **`learner_goals`**: Lưu cấu hình mục tiêu học tập cá nhân hóa của học viên (mục tiêu HSK, thời lượng mỗi ngày, lộ trình ưu tiên - Schema v5).
15. **`learner_evidence`**: Lưu vết chi tiết từng câu trả lời đúng/sai của người học làm bằng chứng cho Mastery Engine.
16. **`mastery_snapshots`**: Ảnh chụp trạng thái năng lực tổng thể theo từng mốc thời gian.
17. **`roadmap_snapshots`**: Lưu ảnh chụp cây lộ trình cá nhân hóa của học viên.
18. **`seed_history`**: Lưu vết các tệp học liệu mẫu đã được nạp tự động (idempotent seed tracker - Schema v2).

### 3.4. Phân hệ Ôn tập Lặp lại Ngắt quãng (SRS SM-2)
19. **`srs_items`**: Quản lý từng thẻ từ vựng trong hàng đợi ôn tập SM-2.
    - Các cột: `id`, `word_id`, `hanzi`, `pinyin`, `meaning_vi`, `interval_days`, `repetition_count`, `ease_factor` (mặc định 2.5, sàn 1.3), `due_date`, `last_reviewed_at`, `state` (`newCard`, `learning`, `review`, `relearning`).

### 3.5. Phân hệ Khảo sát Đầu vào (CAT Placement Test - Schema v3)
20. **`placement_test_sessions`**: Lưu phiên thi phân lớp: năng lực ước lượng ban đầu ($\theta$), độ sai số chuẩn $SE$, cấp độ khuyến nghị.
21. **`placement_test_responses`**: Từng câu trả lời của thí sinh, độ khó câu hỏi ($b$), phân biệt câu hỏi ($a$), thời gian phản hồi.

### 3.6. Phân hệ Từ vựng & Từ điển Tra cứu (Dictionary)
22. **`vocabularies`**: Bảng từ vựng trung tâm (Hán tự, Pinyin, nghĩa chính, âm Hán-Việt, cấp độ HSK).
23. **`vocabulary_senses`**: Các tầng nghĩa mở rộng của từ vựng theo từng ngữ cảnh.
24. **`vocabulary_examples`**: Câu ví dụ mẫu đi kèm từ vựng (Hán tự, Pinyin, nghĩa tiếng Việt, audio URI).
25. **`dictionary_entries`**: Dữ liệu từ điển tra cứu offline (đánh chỉ mục Pinyin và chữ Phồn thể - Schema v19; truy vấn tách bước ưu tiên index `pinyin_clean` trước khi fallback sang `meaning_vi`).
26. **`dictionary_history`**: Lịch sử các từ người dùng đã tra cứu gần đây (Schema v4).
27. **`user_saved_words`**: Sổ tay từ vựng yêu thích/cần ghi nhớ được người học đánh dấu sao (Schema v4).

### 3.7. Phân hệ Ngữ pháp Tiếng Trung (Grammar - Schema v6 & v13)
28. **`grammar_items`**: Điểm ngữ pháp (Tên, cấu trúc công thức, giải thích lý thuyết, đối chiếu L1 tiếng Việt).
29. **`grammar_examples`**: Câu ví dụ khẳng định, phủ định, nghi vấn cho từng điểm ngữ pháp.
30. **`grammar_topics`**: Phân loại ngữ pháp theo chủ đề chuyên đề.
31. **`grammar_progress`**: Tiến độ học và điểm làm chủ từng cấu trúc ngữ pháp.

### 3.8. Phân hệ Đọc hiểu & Đoạn văn (Reading - Schema v4 & v20)
32. **`reading_passages`**: Đoạn văn đọc hiểu phân cấp (Hán tự, tokenized words, pinyin, bản dịch tiếng Việt, audio). Đã tối ưu hóa chỉ mục kép - Schema v20.
33. **`reading_progress`**: Lưu trữ câu hỏi đã trả lời, điểm đọc hiểu và trạng thái đọc của người học.

### 3.9. Phân hệ Luyện tập Thực hành (Practice Engine - Schema v7)
34. **`practice_exercises`**: Ngân hàng bài tập 7 loại hình.
35. **`practice_sessions`**: Phiên làm bài tập luyện tập.
36. **`practice_attempts`**: Lịch sử chi tiết từng lần thử chọn đáp án.

### 3.10. Phân hệ Chữ Hán & Bút Thuận (Hanzi Stroke Engine - Schema v14)
37. **`hanzi_characters`**: Dữ liệu vector tọa độ các nét vẽ chuẩn của chữ Hán, số nét, bộ thủ.
38. **`hanzi_writing_progress`**: Lịch sử luyện viết, điểm số đánh giá độ chuẩn nét vẽ của học viên.

### 3.11. Phân hệ Câu Đàm Thoại & Luyện Nói Đuổi (Sentences & Shadowing - Schema v15)
39. **`sentences`**: Kho mẫu câu đàm thoại giao tiếp thực tế.
40. **`sentence_audio`**: Ánh xạ audio giọng đọc bản ngữ cho từng câu mẫu.
41. **`sentence_practice_progress`**: Lịch sử luyện nói đuổi (Shadowing) và độ khớp nhịp điệu.

### 3.12. Phân hệ Âm vị Pinyin & Quản lý Audio Asset (Schema v11)
42. **`audio_assets`**: Quản lý tập tin âm thanh offline (đường dẫn lưu trữ, mã hash, kích thước).
43. **`pinyin_progress`**: Tiến độ làm chủ hệ thống thanh mẫu, vận mẫu và thanh điệu Pinyin.

### 3.13. Phân hệ Hồ sơ Người dùng, Trợ giảng AI & Cài đặt (Schema v8)
44. **`user_profiles`**: Thông tin học viên: Tên, avatar emoji, mục tiêu học tập hàng ngày, cấp độ HSK mục tiêu.
45. **`goal_history`**: Lịch sử các lần thay đổi mục tiêu học tập.
46. **`app_settings`**: Cài đặt ứng dụng không nhạy cảm: Chế độ sáng/tối, hiển thị Pinyin, cỡ chữ Hán, tốc độ đọc TTS. *(Lưu ý bảo mật AUD-001: Gemini API Key tuyệt đối KHÔNG lưu trong `app_settings` mà chỉ lưu duy nhất trong `AiCredentialStorage` qua `flutter_secure_storage` / Android Keystore; `DatabaseBackupHelper` cũng tự động lọc sạch mọi khóa nhạy cảm trước khi tạo bản sao lưu).*
47. **`chat_sessions`**: Quản lý danh sách các phiên hội thoại với AI Tutor.
48. **`chat_messages`**: Lưu trữ chi tiết các tin nhắn văn bản trong từng phiên hội thoại với AI Tutor.

---

## 4. LUỒNG KHỞI ĐỘNG, ĐIỀU HƯỚNG & SHELL CHÍNH

### 4.1. Chu trình Khởi Động & Phục Hồi Học Liệu (`AppStartupNotifier`)
- Khi ứng dụng khởi động, `AppStartupNotifier` thực thi quy trình xác thực toàn vẹn:
  1. Kiểm tra SQLite Schema v20 và kết nối database.
  2. **Cơ chế Self-Healing Ingestion:** Đếm số bản ghi trong `tableLessonSegments`. Nếu số segment của HSK 1 hoặc HSK 2 dưới 90 (do nâng cấp phiên bản cũ bị thiếu dữ liệu), hệ thống tự động tái nạp toàn bộ 90 segments chuẩn từ file JSON mà vẫn **giữ nguyên 100% dữ liệu tiến độ và streak** của học viên.
  3. Tải cài đặt hệ thống và kiểm tra trạng thái Onboarding.

### 4.2. Route Guard & Luồng Chào Mừng 3 Bước (`OnboardingFlowScreen`)
Nếu người dùng chưa hoàn thành Onboarding, `AppRouteGuard` sẽ tự động chuyển hướng vào quy trình 3 bước:
- **Bước 1 - Khởi tạo API Key (`OnboardingApiKeyScreen`):** Nhập Google Gemini API Key hoặc chọn "Bỏ qua" để học chế độ Offline 100%.
- **Bước 2 - Chọn xuất phát điểm (`OnboardingPlacementScreen`):** Bắt đầu từ HSK 1 hoặc tham gia bài kiểm tra thích ứng CAT để tự động phân lớp.
- **Bước 3 - Cá nhân hóa mục tiêu (`OnboardingPersonalizationScreen`):** Thiết lập thời gian học mỗi ngày (15 phút, 30 phút...), kỹ năng trọng tâm và biểu tượng đại diện.

### 4.3. Cấu trúc Vỏ ứng dụng 5 Tab (`AppShell`)
1. **Tab 1 - Trang chủ (`HomeScreen`):**
   - Chào mừng & Chuỗi ngày học liên tục (`HomeWelcomeStreakCard`).
   - Tiếp tục bài học giáo trình dang dở (`HomeLessonAccessCard`).
   - Thẻ nhắc nhở từ vựng đến hạn ôn tập SRS (`HomeSrsDueCard`).
   - Lưới phím tắt nhanh (`HomeQuickActionsGrid`) và Lịch sử hoạt động gần đây (`HomeRecentActivitiesCard`).
2. **Tab 2 - Lộ trình học tập (`LearningScreen`):** Trung tâm học tập mở rộng, chuyển đổi đầy đủ giữa các cấp độ **HSK 1–6**, truy cập cẩm nang giáo trình và 8 phòng thực hành kỹ năng.
3. **Tab 3 - Trợ giảng AI (`AiTutorTabScreen`):** Trung tâm đàm thoại văn bản và giọng nói thời gian thực với các Persona giảng viên AI.
4. **Tab 4 - Ôn tập ngắt quãng (`ReviewScreen`):** Hàng đợi ôn tập Flashcard SM-2.
5. **Tab 5 - Cá nhân (`ProfileScreen`):** Quản lý hồ sơ, điều chỉnh mục tiêu, cài đặt âm thanh, giao diện và sao lưu cơ sở dữ liệu.

---

## 5. ĐẶC TẢ CHI TIẾT CÁC PHÂN HỆ NGHIỆP VỤ (MODULE SPECIFICATIONS)

---

### 5.1. PHÂN HỆ GIÁO TRÌNH & TRÌNH HỌC TƯƠNG TÁC (CURRICULUM)

#### A. Trình học vi mô Gamified Micro-Learning (`GamifiedLessonPlayer`)
- **Nguyên lý hoạt động:** Thay thế luồng học cứng nhắc bằng hành trình tương tác liền mạch 5–7 phút gồm **15–18 thẻ vi mô** (`MicroCardModel`), chuyển đổi tự động từ dữ liệu bài học qua [`LessonMicroCardAdapter`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/curriculum/domain/engine/lesson_micro_card_adapter.dart):
  1. **Thẻ Khám phá (Reveal Card - 4 đến 5 thẻ):** Chữ Hán cỡ lớn 54px, Pinyin, âm Hán-Việt, phát âm âm thanh, định nghĩa tiếng Việt và câu ví dụ minh họa.
  2. **Thẻ Nghe & Chọn Chữ Hán (Audio Choice Card - 3 đến 4 thẻ):** Nút loa phát âm thanh; người học chọn 1 trong 4 chữ Hán tương ứng.
  3. **Thẻ Ghép Câu Hoàn Chỉnh (Sentence Builder Card - 2 đến 3 thẻ):** Cung cấp câu nghĩa tiếng Việt; người học chạm các từ chip chữ Hán để xếp thành câu đúng.
  4. **Thẻ Nối Cặp Từ Hán - Việt (Matching Pairs Card - 1 đến 2 thẻ):** Giao diện 2 cột tương tác; chạm cặp chữ Hán và nghĩa tiếng Việt tương ứng kèm phản hồi rung Haptic.
  5. **Thẻ Trắc nghiệm Nhanh (Mini Quiz Card - 3 đến 4 thẻ):** Ôn tập nghĩa từ vựng hoặc điểm ngữ pháp cốt lõi.
- **Tính năng trò chơi hóa:**
  - **Chuỗi Combo (`🔥 Combo 2`, `🔥 Combo 3`...):** Tăng hưng phấn khi trả lời đúng liên tiếp.
  - **Hàng đợi làm lại không phạt tim (Zero-Penalty Retry Queue):** Trả lời sai không trừ tim, hiển thị giải thích và tự động đưa thẻ về cuối bài học để làm lại cho đến khi thuộc bài 100%.
  - **Cập nhật phản ứng (`didUpdateWidget`):** Khi `lessonDetailProvider` tải xong dữ liệu từ SQLite, player tự động nạp thẻ mà không bao giờ bị đơ hay hiện màn hình trống.

#### B. Cẩm nang tra cứu bài học nhanh (`LessonQuickNotesSheet`)
- Nút Sổ tay 📖 trên thanh AppBar cho phép mở BottomSheet tra cứu bất kỳ lúc nào với 3 tab:
  - **Từ vựng trọng tâm:** Danh sách từ mới, Pinyin, nghĩa tiếng Việt, nút loa phát âm trực tiếp.
  - **Bí kíp ngữ pháp:** Công thức đóng khung (ví dụ: `A + 是 + B`), giải thích lý thuyết và câu ví dụ đối chiếu.
  - **Hội thoại mẫu:** Đoạn hội thoại thực tế giữa người A và B dạng bong bóng chat.

#### C. Màn hình ăn mừng hoàn thành bài học (`LessonCelebrationView`)
- Xuất hiện sau khi hoàn thành toàn bộ thẻ vi mô:
  - Cúp chiến thắng có hiệu ứng chuyển động nảy (Scale animation).
  - Khối chỉ số thành tích: Thưởng `+25 XP` và chuỗi `Streak 🔥`.
  - Thẻ thông báo mở khóa bài học kế tiếp.
  - Nút "TIẾP TỤC HỌC ➔" gọi `completeLesson()`, đồng bộ dữ liệu và thoát về danh sách bài học.

#### D. Trình học 6 chặng truyền thống (Classic 6-Step Player)
- Được duy trì cho bài học ít từ vựng hoặc khi người dùng tiếp tục bài học dang dở (`resumeStep`):
  - Chặng 1: Khởi động (`LessonWarmupView`)
  - Chặng 2: Từ vựng mới (`LessonVocabView`)
  - Chặng 3: Điểm ngữ pháp (`LessonGrammarView`)
  - Chặng 4: Hội thoại ứng dụng (`LessonDialogueView`)
  - Chặng 5: Luyện tập thích ứng (`LessonPracticeView`)
  - Chặng 6: Đánh giá hoàn thành (`LessonMasteryView`)
- Toàn bộ các chặng được bọc bởi [`LessonStepErrorBoundary`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart) cung cấp nút "Bỏ qua bước này" hoặc "Thử lại", ngăn chặn hoàn toàn lỗi màn hình trắng.

#### E. Đề thi tốt nghiệp cấp độ HSK (`LevelExitExamScreen`)
- Phòng thi mô phỏng 35 phút chuẩn quốc tế:
  - 20 câu hỏi Nghe hiểu (Listening).
  - 20 câu hỏi Đọc hiểu (Reading).
  - Bảng điều hướng câu hỏi nhảy nhanh (Jump palette), cảnh báo khi nộp bài chưa làm hết.
  - Điều kiện đỗ: Đạt $\ge 120 / 200$ điểm thì tốt nghiệp cấp độ và mở khóa cấp độ HSK tiếp theo.

---

### 5.2. ĐỒNG BỘ TIẾN ĐỘ & ĐỘNG CƠ THÀNH THẠO (LEARNING PIPELINE)

- **Quy trình hoàn thành bài học nguyên tử (Single SQLite Transaction):**
  Khi người học hoàn thành bài học qua [`LessonFlowNotifier.completeLesson()`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/curriculum/presentation/providers/lesson_flow_providers.dart) -> [`LearningPipelineCoordinator.recordLessonCompletion()`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart), toàn bộ các bước cập nhật dưới đây được thực thi bên trong **một `db.transaction((txn) async { ... })` nguyên tử duy nhất**:
  1. Tính điểm hoàn thành thực nghiệm (`empiricalAccuracy = (totalUniqueCards - firstAttemptFailures) / totalUniqueCards`, nằm trong khoảng `[0.80, 1.0]`, hoặc dùng ngưỡng chuẩn `0.85` nếu bài học không có thẻ đánh giá).
  2. Ghi nhận cập nhật bảng `curriculum_lessons` (chuyển sang `completed` hoặc `mastered`).
  3. Ghi nhận bảng `lesson_progress` và `curriculum_mastery`.
  4. Ghi nhận 1 bản ghi vào bảng `learning_activities` với `activity_type = 'lesson'`, `created_at` (UTC) và `timezone_offset_minutes` kèm `activity_date` cục bộ `YYYY-MM-DD`.
  5. Kích hoạt [`SrsIntakeRules`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/learning_pipeline/domain/engine/srs_intake_rules.dart) tự động nạp toàn bộ từ mới vào bảng `srs_items` để xếp lịch ôn tập ngắt quãng vào ngày mai.
  6. Tự động mở khóa bài học kế tiếp thỏa mãn điều kiện tiên quyết (`prerequisites`).
  7. Làm mới tức thì các Riverpod Providers (`ref.invalidate`) của Giáo trình và Trang chủ.

- **Giải nén Content Packs an toàn không khóa Database (`ContentPackLoader`):**
  Background Isolate (`Isolate.run`) chỉ thực hiện giải nén và phân tích cú pháp (JSON parsing) trên bộ nhớ RAM, sau đó trả đối tượng Dart về Main Isolate để ghi thông qua **kết nối SQLite duy nhất** bên trong một `db.transaction` + `Batch`, loại bỏ hoàn toàn nguy cơ lỗi `SQLiteDatabaseLockedException`.

- **Động cơ đánh giá nhận thức 6 bậc (`MasteryEvaluator`):**
  - `unseen`: Chưa từng học.
  - `exposed`: Đã nhìn thấy qua trong bài khởi động/đọc hiểu.
  - `learning`: Đang trong quá trình học và làm bài tập.
  - `unstable`: Trả lời sai bài tập, cần củng cố lại.
  - `familiar`: Trả lời đúng nhiều lần trong các bài tập ngắn hạn.
  - `mastered`: Đạt tỷ lệ đúng cao và ghi nhớ bền vững qua các phiên ôn tập ngắt quãng SRS.

---

### 5.3. HỆ THỐNG ÔN TẬP LẶP LẠI NGẮT QUÃNG (SPACED REPETITION SYSTEM - SM-2)

- **Vị trí:** Tab **Ôn Tập** ([`ReviewScreen`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/review/presentation/screens/review_screen.dart)).
- **Động cơ thuật toán:** [`Sm2Engine`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/vocabulary_srs/domain/sm2_engine.dart).
- **Quy tắc tính toán:**
  $$\text{EF}' = \max\left(1.3, \text{EF} + (0.1 - (5 - q) \times (0.08 + (5 - q) \times 0.02))\right)$$
  - Lần ôn 1 ($n=1$): Khoảng cách $I_1 = 1$ ngày.
  - Lần ôn 2 ($n=2$): Khoảng cách $I_2 = 6$ ngày.
  - Lần ôn $n > 2$: Khoảng cách $I_n = I_{n-1} \times \text{EF}'$.
- **4 mức đánh giá phản trực quan:**
  - `Again` (Điểm 1): Quên hoàn toàn $\rightarrow$ Reset về bước học ban đầu ($I = 1$ ngày).
  - `Hard` (Điểm 3): Nhớ khó khăn $\rightarrow$ Giữ nguyên hoặc giảm nhẹ EF.
  - `Good` (Điểm 4): Nhớ tốt $\rightarrow$ Tăng khoảng cách theo công thức SM-2 chuẩn.
  - `Easy` (Điểm 5): Nhớ rất dễ $\rightarrow$ Tăng mạnh khoảng cách và hệ số EF.
- **Thẻ Flashcard 3D:** Mặt trước hiển thị chữ Hán, phát âm; lật mặt sau hiển thị Pinyin, âm Hán-Việt, định nghĩa và câu ví dụ thực tế.

---

### 5.4. PHÂN HỆ TRỢ GIẢNG AI & HỘI THOẠI THỜI GIAN THỰC (AI TUTOR)

- **Vị trí:** Tab **Gia sư AI** ([`AiTutorTabScreen`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart)).
- **Các thành phần cốt lõi:**
  1. **Hệ thống Persona Giảng Viên (`TutorPersona`):** Lý Lão Sư (nghiêm túc, chuẩn sư phạm), Tiểu Vũ (bạn học trẻ trung), Minh Minh (chuyên gia luyện phát âm).
  2. **Ngân hàng kịch bản tình huống (`TutorScenario`):** Gọi món ăn, đặt phòng khách sạn, phỏng vấn xin việc, hỏi đường, mua sắm mặc cả...
  3. **Trò chuyện văn bản (Text Chat):** Giao diện chat trực quan; AI phân tích lỗi ngữ pháp L1-L2, đưa ra gợi ý cách diễn đạt tự nhiên của người bản xứ.
  4. **Hội thoại giọng nói (Voice Chat):** Tích hợp thu âm qua `AudioRecorderService`, chuyển giọng nói thành văn bản, nhận phản hồi từ AI và phát âm qua `TtsService`.
  5. **Bảo vệ ngữ cảnh & Token:** System prompt tự động nhúng cấp độ HSK hiện tại của người học, giới hạn độ dài phản hồi để tối ưu chi phí token và đảm bảo thời gian phản hồi dưới 2 giây.

---

### 5.5. BÀI THI THÍCH ỨNG TRÊN MÁY TÍNH (CAT PLACEMENT TEST)

- **Vị trí:** [`PlacementTestFlowScreen`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/placement_test/presentation/screens/placement_test_flow_screen.dart).
- **Thuật toán IRT (Item Response Theory):**
  - Mô hình Logit ước lượng năng lực:
    $$P_i(\theta) = \frac{1}{1 + e^{-a_i(\theta - b_i)}}$$
    Trong đó: $\theta$ là năng lực học viên, $b_i$ là độ khó câu hỏi, $a_i$ là độ phân biệt câu hỏi.
  - Tự động chọn câu hỏi tiếp theo sao cho thông tin câu hỏi cực đại tại mức năng lực $\theta$ hiện tại.
  - Dừng bài thi khi sai số chuẩn $SE(\theta) < 0.35$ hoặc đạt tối đa 25 câu hỏi.
- **Kết quả & Tác vụ tự động:**
  - Vẽ biểu đồ Radar 6 kỹ năng (Nghe, Đọc, Từ vựng, Ngữ pháp, Chữ Hán, Giao tiếp).
  - Tự động mở khóa toàn bộ các bài học thuộc các cấp độ HSK thấp hơn trình độ đo được của học viên trong SQLite.

---

### 5.6. PHÒNG THỰC HÀNH CÁC KỸ NĂNG CHUYÊN SÂU

1. **Luyện viết chữ Hán (`HanziWritingScreen`):**
   - Khung vẽ cảm ứng ô Mễ (**米字格**).
   - Động cơ [`StrokeEvaluator`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/hanzi_writing/domain/engine/stroke_evaluator.dart) đối chiếu từng nét vẽ của học viên với dữ liệu vector nét chuẩn trong `tableHanziCharacters` theo thứ tự nét, hướng vẽ và tỷ lệ tọa độ.
2. **Luyện phát âm & Thanh điệu (`PronunciationLabScreen`):**
   - Biểu đồ sóng âm thời gian thực (`WaveformVisualizer`).
   - Phân tích và đối chiếu cao độ 4 thanh điệu tiếng Trung (`55`, `35`, `214`, `51`).
3. **Nền tảng ngữ âm Pinyin (`PinyinOverviewScreen`):**
   - Bảng ma trận 21 Thanh mẫu, 36 Vận mẫu và 4 Thanh điệu kèm âm thanh bản ngữ.
   - Luyện tập phân biệt các cặp phụ âm ma sát/tắc ma sát dễ nhầm: `z/zh`, `c/ch`, `s/sh`, `j/q/x`.
4. **Luyện đọc hiểu phân cấp (`ReadingPassageListScreen`):**
   - Kho bài đọc phân cấp từ HSK 1 đến HSK 6.
   - **Interactive Token Tap:** Chạm trực tiếp vào từng chữ Hán trong bài để hiện popup tra từ điển nhanh mà không cần rời màn hình đọc.
   - Đọc audio câu chuyện tốc độ chậm và làm bài tập đọc hiểu C3.
5. **Luyện nói đuổi (Shadowing) & Thư viện câu (`ShadowingScreen`):**
   - Phát câu mẫu ở tốc độ 0.8x, 1.0x, 1.2x.
   - Người học thu âm nói đuổi theo câu mẫu; hệ thống so khớp độ trễ và nhịp điệu.
6. **Từ điển Offline 2 chiều (`DictionaryScreen`):**
   - Tra cứu Hán tự, Pinyin, Tiếng Việt.
   - Hiển thị bộ thủ, số nét, âm Hán-Việt, ví dụ và hỗ trợ lưu vào sổ tay cá nhân.
7. **Ngữ pháp chuyên sâu (`GrammarListScreen`):**
   - Cung cấp thẻ đối chiếu L1-L2 (`ContrastiveExampleCard`), cảnh báo các lỗi sai ngữ pháp kinh điển mà người Việt Nam hay mắc phải do dịch từng từ.
8. **Động cơ thực hành đa dạng (`PracticeSessionScreen`):**
   - 7 loại bài tập: Trắc nghiệm, Ghép cặp, Điền khuyết, Sắp xếp câu, Đúng/Sai, Trả lời ngắn, Nghe chọn đáp án.

---

### 5.7. QUẢN LÝ GÓI HỌC LIỆU NGOẠI TUYẾN (CONTENT PACKS)

- Quản lý qua [`ContentPackManagerScreen`](file:///C:/Users/phama/Downloads/hi_chinese/lib/features/content_packs/presentation/screens/content_pack_manager_screen.dart).
- Cho phép tải và giải nén các gói học liệu HSK 1 đến HSK 6.
- **Xử lý trên Dart Isolate:** Quá trình giải nén và chèn hàng ngàn bản ghi vào SQLite được chạy trên Isolate nền (`compute`), đảm bảo giao diện luôn mượt mà 60fps/120fps (Zero UI Janks).

---

### 5.8. HỒ SƠ NGƯỜI HỌC & CÀI ĐẶT HỆ THỐNG

- **Hồ sơ cá nhân (`ProfileScreen`):** Tùy chỉnh avatar emoji, thay đổi mục tiêu học tập (số phút học/ngày), xem thống kê tổng XP và lịch sử thay đổi mục tiêu (`goal_history`).
- **Cài đặt (`SettingsScreen` & `AiSettingsScreen`):** 
  - Bật/tắt thanh Pinyin trên toàn bộ bài học.
  - Tùy chỉnh cỡ chữ Hán (Nhỏ / Vừa / Lớn).
  - Điều chỉnh tốc độ giọng đọc TTS (0.8x, 1.0x, 1.2x).
  - Quản lý bộ nhớ đệm âm thanh (`AudioTempCleaner`).
  - Sao lưu và phục hồi database ra file ngoài (`DatabaseBackupHelper`).
  - Cấu hình Gemini API Key và kiểm tra quyền Micro.

---

## 6. HỆ THỐNG DESIGN SYSTEM & KHẢ NĂNG TRỢ NĂNG (ACCESSIBILITY)

- **Màu sắc chủ đạo (`AppColors`):**
  - *Primary Blue Dark* (`#0A2540`): Màu thương hiệu chính, sang trọng, tương phản cao.
  - *Primary Blue* (`#1976D2`) & *Primary Blue Light* (`#E3F2FD`): Màu điểm nhấn và nền phụ trợ.
  - *Success* (`#2E7D32`): Màu xanh biểu thị câu đúng, hoàn thành bài, mở khóa.
  - *Error* (`#D32F2F`): Màu đỏ cảnh báo, làm sai.
  - *Streak Orange* (`#FF6D00`): Màu ngọn lửa Streak 🔥 và điểm XP.
- **Thư viện thành phần (`lib/core/theme/components/`):**
  - `HiButton`, `HiCard`, `HiChip`, `HiDialog`, `HiLoadingIndicator`, `HiErrorState`, `HiSnackBar`.
- **Tiêu chuẩn WCAG 2.2 Level AA:**
  - Tỷ lệ tương phản chữ trên nền luôn đạt $\ge 4.5:1$.
  - Diện tích chạm cảm ứng của tất cả các nút bấm tối thiểu đạt $48 \times 48\text{ dp}$.

---

## 7. QUY TRÌNH KIỂM THỬ, ĐÓNG GÓI & PHÁT HÀNH (RELEASE SPECIFICATION)

### 7.1. Tiêu chuẩn Kiểm thử & Phân tích tĩnh
Mỗi bản phát hành bắt buộc phải vượt qua 100% các điều kiện:
```bash
# 1. Phân tích tĩnh: Bắt buộc 0 errors, 0 warnings
flutter analyze lib/ test/

# 2. Toàn bộ các bộ kiểm thử hồi quy: Bắt buộc 100% PASS
flutter test test/features/learning_pipeline/
flutter test test/features/curriculum/
flutter test test/features/content_packs/
flutter test test/features/onboarding/
flutter test
```

### 7.2. Lệnh đóng gói bản phát hành Split APKs
```bash
flutter clean
flutter build apk --split-per-abi --release --android-skip-build-dependency-validation
```
- Các tệp đầu ra được lưu trữ tại `release-apk/`:
  - `hi-chinese-v1.0.16-arm64-v8a.apk` (Dung lượng: ~44.3 MB - cho smartphone Android hiện đại).
  - `hi-chinese-v1.0.16-armeabi-v7a.apk` (Dung lượng: ~42.18 MB - cho máy đời cũ).
  - `app-release.apk` (Dung lượng: ~44.3 MB - bản mặc định).
- Tất cả các bản build đều tuân thủ nghiêm ngặt giới hạn dung lượng tải về $\le 45\text{ MB}$.

---

## 8. HƯỚNG DẪN DÀNH CHO CÁC AI AGENT KHI TIẾP QUẢN DỰ ÁN

1. **Luôn giữ vững tính Offline-First:** Tuyệt đối không thêm bất kỳ logic nào bắt buộc phải có kết nối mạng mới cho phép học bài hoặc mở khóa bài học.
2. **Không phá vỡ Schema SQLite v20:** Khi cần lưu thêm dữ liệu, phải tạo Migration mới kế thừa `Migration` (ví dụ `MigrationV21`) và đăng ký vào `MigrationEngine`. Tuyệt đối không chèn các cột không tồn tại vào các bảng hiện có (đặc biệt là `learning_activities`).
3. **Bảo toàn chuỗi ngày học (Streak):** Mọi hành động học hoàn thành bài đều phải gọi qua `LearningPipelineCoordinator.recordLessonCompletion` để bảo đảm ghi nhận đúng `activity_date` theo giờ địa phương vào `learning_activities`.
4. **Giữ vững kiến trúc Gamified Micro-Learning:** Mọi cải tiến bài giảng HSK cần đi qua `LessonMicroCardAdapter` và `GamifiedLessonPlayer` để duy trì trải nghiệm học vi mô 15–18 thẻ giàu dopamine.
