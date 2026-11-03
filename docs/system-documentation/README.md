# HI CHINESE – MASTER SYSTEM DOCUMENTATION & HANDOVER DOSSIER

> **Dành cho AI Agent tiếp nhận và phát triển dự án HI Chinese.**  
> Bộ hồ sơ kỹ thuật này phản ánh **100% hiện trạng mã nguồn thực tế**, cấu trúc cơ sở dữ liệu Schema v11, các động cơ sư phạm và hệ thống học liệu ngoại tuyến của ứng dụng HI Chinese (Phiên bản phát hành: `v1.0.7`, build `8`).

---

## 1. HI CHINESE LÀ GÌ?

**HI Chinese** là một ứng dụng di động độc lập (nền tảng Flutter Android), được thiết kế như một **Nền tảng Tự học Tiếng Trung Toàn diện Ngoại tuyến (Offline-First Comprehensive Chinese Self-Study Platform)** theo khung chuẩn HSK 2.0 (mở rộng HSK 3.0), bao phủ toàn bộ lộ trình từ con số 0 (Pinyin Foundation) lên đến các cấp độ HSK 1–6.

### Sứ mệnh & Vấn đề giải quyết:
- **Tự học độc lập không phụ thuộc Internet:** Người học có thể tải gói bài học và âm thanh ngoại tuyến để học mọi lúc mọi nơi; toàn bộ dữ liệu tiến độ, từ điển, nét chữ, ngữ pháp và hàng đợi ôn tập đều nằm trong cơ sở dữ liệu SQLite cục bộ.
- **Học tập có hệ thống theo chuẩn sư phạm:** Thay vì chỉ là một ứng dụng chat AI chung chung dễ bịa đặt thông tin, HI Chinese xây dựng hệ thống học liệu định lượng chặt chẽ (Structured Curriculum), liên kết tri thức chuẩn hóa (Knowledge Registry) và quy trình củng cố ngắt quãng (SM-2 Spaced Repetition).
- **Gia sư AI đóng vai trò bổ trợ an toàn:** AI (Google Gemini REST & Live WebSocket) đóng vai trò người bạn luyện nói và giải thích học thuật, có hàng rào bảo vệ (Guardrails) nghiêm ngặt để không thể tự ý làm sai lệch dữ liệu tiến độ học tập.

---

## 2. BẢNG TỔNG QUAN KỸ THUẬT (TECH STACK SUMMARY)

| Thành phần | Công nghệ / Thư viện | Phiên bản thực tế | Mục đích |
| :--- | :--- | :---: | :--- |
| **Ngôn ngữ** | Dart | `^3.13.7` | Ngôn ngữ phát triển ứng dụng duy nhất. |
| **Framework** | Flutter SDK | `3.29.x` | Xây dựng UI cho nền tảng Android (64-bit target). |
| **Cơ sở dữ liệu** | SQLite (`sqflite`) | `^2.4.5` | Lưu trữ 39 bảng dữ liệu quan hệ cục bộ, WAL mode, 8MB cache. |
| **State Management** | Riverpod (`flutter_riverpod`)| `^3.4.3` | Quản lý trạng thái phân tầng, Provider & Notifier reactive. |
| **Bảo mật Secret** | `flutter_secure_storage` | `^11.2.0` | Lưu trữ khóa mã hóa Gemini API Key trong Android Keystore. |
| **Cài đặt nhẹ** | `shared_preferences` | `^2.5.6` | Lưu cờ onboarding, thiết lập theme và tùy chỉnh hiển thị. |
| **Mạng & Live API** | `http`, `web_socket_channel` | `^1.6.0`, `^3.0.3` | Tải gói học liệu tĩnh từ CDN và đàm thoại Live với AI. |
| **Phân quyền** | `permission_handler` | `^13.0.2` | Kiểm tra quyền Microphone theo ngữ cảnh khi mở Voice Chat. |
| **Mã hóa băm** | `crypto` | `^3.0.8` | Xác thực tính toàn vẹn SHA-256 của Content Pack & Audio Asset. |
| **Kiểm thử** | `flutter_test`, `sqflite_common_ffi` | `^2.4.5` | Chạy 64 bộ test độc lập trên môi trường máy tính không cần máy ảo. |

---

## 3. CÁC ĐỘNG CƠ CỐT LÕI (CORE PEDAGOGICAL ENGINES)

1. **Learning Pipeline Coordinator (`features/learning_pipeline`)**: Điều phối luồng dữ liệu học tập trung tâm, đảm bảo mỗi khi hoàn thành một bài học hoặc bài tập, hệ thống ghi nhận đồng thời sang:
   - `lesson_progress`: Cập nhật trạng thái bài học.
   - `learner_evidence`: Nhật ký bất biến lưu trữ bằng chứng và điểm số.
   - `mastery_snapshots`: Đánh giá trạng thái thành thạo (`unseen` -> `exposed` -> `practicing` -> `mastered`).
   - `srs_items`: Tự động nạp từ vựng hoặc điểm ngữ pháp yếu vào hàng đợi ôn tập flashcard.
2. **SM-2 Spaced Repetition Engine (`features/vocabulary_srs`)**: Tính toán chính xác thời điểm ôn tập lặp lại ngắt quãng theo 4 mức đánh giá (Again, Hard, Good, Easy) với biên độ Ease Factor an toàn [1.3, 3.2].
3. **CAT 2PL IRT Engine (`features/placement_test`)**: Động cơ kiểm tra trình độ thích ứng máy tính (Computerized Adaptive Testing) dựa trên hàm thông tin Fisher và ước lượng năng lực Theta (\(\theta\)).
4. **Deterministic Pinyin Engine (`features/pinyin_foundation`)**: Động cơ chấm điểm 10 dạng bài tập ngữ âm xác định bằng quy tắc so khớp chuẩn hóa, 100% không gọi AI.
5. **Content Pack & Audio Storage Engine (`features/content_packs`, `features/audio_management`)**: Nạp và cập nhật gói học liệu JSON nguyên tử, tải tệp âm thanh theo khối vào `.tmp/`, xác thực SHA-256 trước khi lưu chính thức vào `content_packs/{pack_id}/audio/`.

---

## 4. HỆ THỐNG TÀI LIỆU CHI TIẾT (DOCUMENTATION INDEX)

Bộ tài liệu được tổ chức thành các chuyên đề độc lập tại thư mục `docs/system-documentation/`:

- [01. Tổng quan Dự án & Phạm vi Nghiệp vụ](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/01-project-overview.md)
- [02. Kiến trúc Tổng thể & Vòng đời Khởi động](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/02-architecture.md)
- [03. Bản đồ Cấu trúc Mã nguồn](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/03-source-code-structure.md)
- [04. Kiến trúc Cơ sở dữ liệu SQLite Schema v11](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/04-database-schema.md)
- [05. Kiến trúc Hệ thống Sư phạm & Học liệu](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/05-learning-system.md)
- [06. Kiến trúc Trí tuệ Nhân tạo (AI & Live API)](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/06-ai-architecture.md)
- [07. Máy chủ, Tài khoản & Cơ chế Ngoại tuyến](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/07-server-and-sync.md)
- [08. Hệ thống Gói Học liệu & Quản lý Âm thanh Ngoại tuyến](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/08-content-and-audio.md)
- [09. Giao diện Người dùng, Điều hướng & Design System](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/09-ui-and-navigation.md)
- [10. Danh mục API, Dịch vụ & Giao tiếp Ngoại vi](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/10-api-and-services.md)
- [11. Bảo mật Hệ thống & Quản trị Dữ liệu](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/11-security-and-data-management.md)
- [12. Hướng dẫn Môi trường, Kiểm thử & Đóng gói Phát hành](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/12-build-test-deployment.md)
- [13. Ma trận Phụ thuộc & Luồng Nghiệp vụ Liên Module](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/13-module-dependencies.md)
- [14. Danh mục Tồn đọng Kỹ thuật & Rủi ro Cần Lưu ý](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/14-known-issues-and-technical-debt.md)
- [15. Cẩm nang Bàn giao Kỹ thuật cho AI Agent Kế tiếp](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/15-ai-agent-handover-guide.md)

### Thư mục Sơ đồ & Danh mục:
- `diagrams/`: [system-architecture.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/system-architecture.mmd), [database-er.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/database-er.mmd), [learning-data-flow.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/learning-data-flow.mmd), [ai-request-flow.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/ai-request-flow.mmd), [client-server-sync.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/client-server-sync.mmd), [module-dependencies.mmd](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/diagrams/module-dependencies.mmd).
- `inventories/`: [module-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/module-inventory.md), [database-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/database-inventory.md), [api-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/api-inventory.md), [screen-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/screen-inventory.md), [service-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/service-inventory.md), [test-inventory.md](file:///c:/Users/phama/Downloads/hi_chinese/docs/system-documentation/inventories/test-inventory.md).

---

## 5. THỨ TỰ ĐỌC TÀI LIỆU KHUYẾN NGHỊ CHO AI AGENT MỚI

Khi tiếp quản dự án, bạn nên đọc tài liệu theo trình tự sau để nắm bắt bức tranh toàn cảnh trước khi đi vào mã nguồn:

1. Đọc **README.md** (Tài liệu này) để hiểu mục đích và công nghệ.
2. Đọc **01-project-overview.md** và **02-architecture.md** để nắm kiến trúc tổng thể.
3. Đọc **04-database-schema.md** để hiểu 39 bảng dữ liệu và quan hệ giữa chúng.
4. Đọc **05-learning-system.md** để nắm nghiệp vụ học tập cốt lõi (đây là phần quan trọng nhất).
5. Đọc **13-module-dependencies.md** để biết module nào phụ thuộc module nào, tránh sửa làm đứt gãy hệ thống.
6. Đọc **15-ai-agent-handover-guide.md** để tuân thủ các nguyên tắc vàng khi viết mã, kiểm thử và commit.

---

## 6. HƯỚNG DẪN CHẠY DỰ ÁN NHANH (QUICKSTART)

```bash
# 1. Di chuyển vào thư mục dự án
cd "c:\Users\phama\Downloads\hi_chinese"

# 2. Cài đặt các thư viện phụ thuộc
flutter pub get

# 3. Chạy phân tích cú pháp tĩnh (Đảm bảo 0 lỗi, 0 cảnh báo)
dart analyze lib test

# 4. Chạy toàn bộ các bài kiểm thử tự động
flutter test

# 5. Biên dịch bản phát hành Android 64-bit APK
flutter build apk --release --target-platform android-arm64
```
Tệp APK hoàn chỉnh được tạo tại: `release-apk/hi-chinese-v1.0.7-arm64.apk` (Dung lượng: ~20.4 MB).
