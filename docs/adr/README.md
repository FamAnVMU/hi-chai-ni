# Architecture Decision Records (ADRs)

Tài liệu lưu trữ các Quyết định Kiến trúc (Architecture Decision Records) của dự án **HI Chinese**.  
Mỗi quyết định mô tả bối cảnh kỹ thuật, các phương án cân nhắc, quyết định được chọn và hệ quả kiến trúc đối với hệ thống.

---

## Danh Sách Quyết Định Kiến Trúc (ADR Index)

| ID | Tiêu Đề | Trạng Thái | Ngày | Người Phụ Trách | Phân Hệ |
|---|---|---|---|---|---|
| [ADR-0001](../architecture-decisions.md#21-quản-lý-trạng-thái-state-management--di) | Chọn Flutter Riverpod cho State Management | Accepted | 2026-11-04 | Architecture Board | Core Architecture |
| [ADR-0002](../architecture-decisions.md#22-cơ-sở-dữ-liệu-cục-bộ-local-database) | Chọn SQLite (sqflite) cho Offline-First Storage | Accepted | 2026-11-04 | Architecture Board | Database |
| [ADR-0003](../architecture-decisions.md#23-mạng-api-client-network--sync) | Chọn Dio cho HTTP/REST API & Interceptors | Accepted | 2026-11-04 | Architecture Board | Network |
| [ADR-0004](../architecture-decisions.md#24-xử-lý-âm-thanh-audio-processing) | Chọn audioplayers & record cho Audio Pipeline | Accepted | 2026-11-04 | Thread 3 Lead | Audio & Voice |
| [ADR-0005](../architecture-decisions.md#25-tổng-hợp-giọng-nói-text-to-speech) | Chọn flutter_tts cho Offline Chinese Pronunciation | Accepted | 2026-11-04 | Thread 3 Lead | Speech & TTS |
| [ADR-0006](../architecture-decisions.md#26-tích-hợp-ai--llm-ai-tutor) | Tích hợp Google Gemini REST API v1beta | Accepted | 2026-11-04 | Thread 3 Lead | AI Tutor |
| [ADR-0007](../architecture-decisions.md#27-hiển-thị-văn-bản-tiếng-trung-chinese-text--pinyin) | Tự xây dựng RubyText Widget cho Pinyin Annotations | Accepted | 2026-11-04 | Architecture Board | Presentation |
| [ADR-0008](../architecture-decisions.md#28-lưu-trữ-key-value-nhẹ-key-value-storage) | Chọn shared_preferences cho App Settings | Accepted | 2026-11-04 | Architecture Board | Core Storage |
| [ADR-0009](../architecture-decisions.md#29-bảo-mật-khóa-api--secrets-secure-storage) | Chọn flutter_secure_storage cho API Keys | Accepted | 2026-11-04 | Architecture Board | Security |
| [ADR-0010](../architecture-decisions.md#210-quản-lý-quyền-truy-cập-permissions) | Chọn permission_handler cho Hardware Permissions | Accepted | 2026-11-04 | Architecture Board | Hardware/OS |
| [ADR-0011](../architecture-decisions.md#211-quản-lý-vòng-đời-và-kết-nối-lifecycle--connectivity) | Tích hợp connectivity_plus cho Offline Awareness | Accepted | 2026-11-04 | Architecture Board | System |
| [ADR-0012](../architecture-decisions.md#212-thư-viện-tiện-ích-nền-tảng-utilities) | Sử dụng uuid, path, path_provider, crypto | Accepted | 2026-11-04 | Architecture Board | Utilities |
| [ADR-0013](../architecture-decisions.md#213-đánh-giá-các-package-bị-loại-bỏ-rejected-packages) | Danh sách và lý do loại bỏ các package không đạt chuẩn | Accepted | 2026-11-04 | Architecture Board | Dependencies |
| [ADR-0014](../bug-fixes/F04_F17_UNIFIED_ID_AND_SRS.md) | Chuẩn hóa Unified ID và Độc lập thuật toán SM-2 SRS | Accepted | 2026-11-04 | Thread 2 & QA | Learning System |
| [ADR-0015](../bug-fixes/F10_REAL_PRONUNCIATION_LISTENING_EXIT_EXAM.md) | Thẩm định Phát âm Thực tế và Bài thi Đầu ra Chuẩn hóa | Accepted | 2026-11-04 | Thread 3 Lead | Pronunciation |
| [ADR-0016](ADR-0016-sliding-window-context-limit.md) | Giới hạn Sliding Window Context cho AI Tutor Session | Accepted | 2026-11-05 | Thread 3 Lead | AI Tutor / LLM |
| [ADR-0017](ADR-0017-voice-ai-asr-integration-strategy.md) | Chiến lược Tích hợp ASR Hai Tầng cho Voice AI (BUG-NEW-003) | Accepted | 2026-11-05 | Thread 3 Lead | AI & Voice Lab |
