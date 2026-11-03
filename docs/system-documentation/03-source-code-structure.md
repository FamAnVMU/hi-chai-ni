# 03. BẢN ĐỒ CẤU TRÚC MÃ NGUỒN

---

## 1. CÂY THƯ MỤC TỔNG THỂ DỰ ÁN

```text
hi_chinese/
├── android/                             # Cấu hình dự án Android Native (Gradle, Manifest, NDK)
├── assets/                              # Tài nguyên tĩnh đóng gói vào APK
│   ├── audio/                           # Tệp âm thanh mẫu phát âm
│   └── data/                            # Fixture nạp ban đầu và gói học liệu HSK đóng gói
│       ├── content_packs/
│       │   ├── hsk1/hsk1_pack_v1.json   # Gói học liệu chuẩn HSK 1 (15 bài học, 150 từ vựng)
│       │   └── hsk2/hsk2_pack_v1.json   # Gói học liệu chuẩn HSK 2 (15 bài học, 150 từ vựng)
│       └── hsk_seed_fixture_v1.json     # Fixture mồi dữ liệu từ điển ban đầu
├── content_packs_cdn/                   # Tệp gói học liệu mô phỏng tải qua CDN trực tuyến
│   └── hsk3_pack_v1.json                # Gói học liệu chuẩn HSK 3
├── docs/                                # Hồ sơ kỹ thuật và tài liệu kiến trúc
│   ├── system-documentation/            # Bộ hồ sơ bàn giao toàn diện cho AI Agent
│   │   ├── diagrams/                    # Các sơ đồ Mermaid (.mmd)
│   │   └── inventories/                 # Danh mục Module, Database, API, Màn hình, Service, Test
│   ├── architecture-decisions.md        # Bản ghi các quyết định kiến trúc (ADR)
│   └── design-tokens.md                 # Quy chuẩn Design System & Theme Tokens
├── lib/                                 # Mã nguồn Dart chính của ứng dụng
│   ├── main.dart                        # Điểm khởi động ứng dụng (Entry point)
│   ├── core/                            # Thành phần hạ tầng dùng chung toàn ứng dụng
│   │   ├── audio/                       # Trình phát và ghi âm đơn nhất, Audio Focus
│   │   ├── constants/                   # Hằng số toàn cục (AppConstants)
│   │   ├── database/                    # Quản lý SQLite, DatabaseConstants, Migrations v1-v11
│   │   ├── network/                     # Kết nối AI REST / Live WebSocket, Credential Storage
│   │   ├── startup/                     # AppStartupNotifier & AppStartupState
│   │   ├── theme/                       # Design System Tokens, AppTheme, RubyText
│   │   └── utils/                       # AppLifecycleManager, PermissionHelper
│   └── features/                        # 25 thư mục tính năng (Feature-First Architecture)
│       ├── ai_tutor/                    # Gia sư AI (Text Chat & Voice Conversation)
│       ├── app_shell/                   # Shell điều hướng 5 Tab, Android Back Intercept
│       ├── audio_management/            # Quản trị tệp âm thanh ngoại tuyến HSK 3-6 & Pinyin
│       ├── content_packs/               # Cài đặt và cập nhật gói học liệu JSON
│       ├── curriculum/                  # Giáo trình HSK, nạp bài học, cấu trúc bài
│       ├── design_system/               # Màn hình demo các components giao diện
│       ├── dictionary/                  # Tra cứu từ điển Hán-Việt, lưu từ vựng
│       ├── grammar/                     # Danh bạ ngữ pháp HSK, ví dụ đối sánh
│       ├── hanzi_writing/               # Luyện viết chữ Hán trên canvas mễ tự
│       ├── home/                        # Màn hình chính Dashboard, tính chuỗi Streak
│       ├── learning/                    # Tab Học tập trung gian
│       ├── learning_pipeline/           # Điều phối dữ liệu học tập (Mastery, Evidence, SRS)
│       ├── listening/                   # Phòng luyện nghe hiểu
│       ├── onboarding/                  # Quy trình giới thiệu & nhập API Key
│       ├── pinyin_foundation/           # Khóa học Pinyin nền tảng từ số 0
│       ├── placement_test/              # Đánh giá trình độ đầu vào CAT 2PL IRT
│       ├── practice/                    # Ngân hàng câu hỏi thích ứng & Chấm điểm
│       ├── profile/                     # Quản lý hồ sơ người dùng & Lịch sử mục tiêu
│       ├── pronunciation/               # Phòng lab phân tích phát âm
│       ├── reading/                     # Đọc hiểu tương tác đoạn văn
│       ├── review/                      # Tab Ôn tập trung gian
│       ├── roadmap/                     # Cây lộ trình học tập thích ứng
│       ├── settings/                    # Quản lý dữ liệu, sao lưu VACUUM INTO, Reset
│       ├── shadowing/                   # Luyện nói đuổi theo giọng bản xứ
│       └── vocabulary_srs/              # Ôn tập flashcard theo thuật toán SM-2
├── release-apk/                         # Tệp APK phát hành chính thức
│   ├── app-release.apk                  # Bản release mới nhất
│   └── hi-chinese-v1.0.7-arm64.apk      # Bản release v1.0.7 64-bit Android
├── test/                                # 64 file kiểm thử tự động toàn diện
├── pubspec.yaml                         # Cấu hình dependencies và assets
└── analysis_options.yaml                # Cấu hình linter nghiêm ngặt (0 warnings policy)
```

---

## 2. QUY CHUẨN NỘI TẠI CỦA TỪNG FEATURE (`features/<feature_name>/`)

Mỗi module trong `lib/features/` được tổ chức đồng nhất theo 3 tầng con:

```text
lib/features/<feature_name>/
├── data/
│   ├── <feature>_repository.dart        # Hiện thực hóa interface truy xuất dữ liệu SQLite
│   └── <feature>_dao.dart               # Lớp truy cập bảng cơ sở dữ liệu chuyên biệt
├── domain/
│   ├── models/
│   │   └── <entity>_models.dart         # Data class thuần túy (immutable, copyWith, toMap)
│   └── engine/ (hoặc services/)
│       └── <feature>_engine.dart        # Thuật toán nghiệp vụ xác định không phụ thuộc UI
└── presentation/
    ├── providers/
    │   └── <feature>_providers.dart     # Riverpod Notifiers & State Providers
    ├── screens/
    │   └── <feature>_screen.dart        # Giao diện màn hình chính của tính năng
    └── widgets/
        └── <feature>_card.dart          # Các widget con tái sử dụng trong màn hình
```

### Nguyên tắc liên kết giữa các file:
- **Relative Imports:** Tuân thủ đường dẫn tương đối chuẩn xác (`../../data/...`, `../../domain/...`), không dùng import chéo sai cấp.
- **Provider Injection:** Các màn hình UI lắng nghe trạng thái qua `ref.watch(provider)` và kích hoạt hành động qua `ref.read(provider.notifier).method()`.
- **Pure Models:** Các model trong Domain Layer không phụ thuộc vào thư viện `flutter/material.dart` trừ các thành phần đồ họa đặc biệt (như Canvas Painter).
