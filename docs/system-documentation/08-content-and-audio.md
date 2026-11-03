# 08. HỆ THỐNG GÓI HỌC LIỆU & QUẢN LÝ ÂM THANH NGOẠI TUYẾN

---

## 1. CẤU TRÚC GÓI HỌC LIỆU CHUẨN HÓA (CONTENT PACKS)

Các gói học liệu trong HI Chinese được đóng gói thành các tệp JSON tự chứa (Self-contained Content Packs):

```json
{
  "manifest": {
    "pack_id": "hsk1_pack_v1",
    "hsk_level": 1,
    "version": "1.0.0",
    "title": "Giáo trình chuẩn HSK 1 (HSK 2.0)",
    "description": "150 từ vựng cốt lõi, 15 bài học, 45 điểm ngữ pháp, 150 bài tập xác định.",
    "is_bundled": true,
    "size_bytes": 170878,
    "sha256": ""
  },
  "curriculum": {
    "id": "curr_hsk1",
    "code": "HSK_2012_L1",
    "standard_name": "HSK 2.0 Level 1 Official Curriculum",
    "hsk_level": 1,
    "units": [ ... ]
  },
  "content_items": [ ... ],
  "exit_exam": { ... }
}
```

### Hiện trạng các Gói học liệu trong dự án:
- **HSK 1 (`assets/data/content_packs/hsk1/hsk1_pack_v1.json`):** Đóng gói sẵn trong APK (Bundled). Gồm 15 bài học, 150 từ vựng, 45 điểm ngữ pháp, 150 câu hỏi luyện tập và đề thi tốt nghiệp HSK 1.
- **HSK 2 (`assets/data/content_packs/hsk2/hsk2_pack_v1.json`):** Đóng gói sẵn trong APK (Bundled). Gồm 15 bài học, 150 từ vựng, 45 điểm ngữ pháp, 150 câu hỏi luyện tập và đề thi tốt nghiệp HSK 2.
- **HSK 3 (`content_packs_cdn/hsk3_pack_v1.json`):** Đặt tại CDN từ xa. Người học tải về theo nhu cầu thông qua `ContentPackRemoteService`.

---

## 2. QUY TRÌNH CÀI ĐẶT VÀ CẬP NHẬT GÓI HỌC LIỆU (ATOMIC INSTALLATION)

`ContentPackManager` (`lib/features/content_packs/data/content_pack_manager.dart`) chịu trách nhiệm nạp dữ liệu:

1. **Kiểm tra Tính toàn vẹn & Phiên bản:**
   - So sánh phiên bản ứng dụng tối thiểu (`minimumAppVersion`) với phiên bản hiện tại.
   - Nếu tệp có khai báo mã băm `sha256`, tính toán SHA-256 của chuỗi JSON thô để chống tệp bị hư hại trong quá trình truyền tải.
2. **Nạp dữ liệu trong Background Isolate:**
   - Tác vụ phân tích chuỗi JSON lớn được chạy bằng `compute` hoặc `Isolate.run` để không gây giật lag (frame drop) trên màn hình chính.
3. **Thực thi Giao dịch Nguyên tử (Database Transaction):**
   - Nạp thông tin vào bảng `content_packs`, `curriculums`, `curriculum_units`, `curriculum_lessons`, `lesson_segments`, `content_items`, `level_exit_exams`.
   - **Tự động Chuẩn hóa (Auto-Normalization):** Tự động bóc tách các từ vựng và điểm ngữ pháp trong `content_items` để ghi vào `knowledge_registry` và tạo liên kết trong `lesson_knowledge_items`.
   - **Bảo toàn Tiến độ:** Sử dụng phương thức `upsert` hoặc cập nhật trường thông tin học liệu, **tuyệt đối không xóa bảng `lesson_progress` hoặc `mastery_snapshots`**.

---

## 3. HỆ THỐNG QUẢN LÝ TÀI NGUYÊN ÂM THANH NGOẠI TUYẾN (AUDIO ASSET SUBSYSTEM)

Từ Schema v11, hệ thống âm thanh ngoại tuyến được tổ chức theo quy chuẩn chuyên nghiệp:

### 3.1. Cấu trúc Thư mục Lưu trữ Cục bộ
```text
<appSupportDirectory>/
└── content_packs/
    ├── audio_pinyin/
    │   ├── audio/
    │   │   ├── initials/b.mp3
    │   │   ├── finals/a.mp3
    │   │   └── tones/tone_1.mp3
    │   └── .tmp/             # Thư mục tạm trong lúc tải (Staging)
    ├── audio_hsk1/
    │   └── audio/
    └── audio_hsk3/
        └── audio/
            ├── v001.mp3
            └── v002.mp3
```

### 3.2. Quy trình Tải Âm thanh Nguyên tử (Staged Download Loop)
`AudioPackDownloader` (`lib/features/audio_management/data/audio_pack_downloader.dart`):

1. **Kiểm tra Dung lượng Trống:** Quét dung lượng còn lại trên bộ nhớ máy bằng `AudioStorageManager.hasSufficientStorage()`. Nếu không đủ chỗ, từ chối tải và báo lỗi cho người dùng.
2. **Tải về Thư mục Tạm (`.tmp/`):** Từng tệp âm thanh được tải về tệp tạm `staging_*.tmp`.
3. **Xác thực SHA-256:** Tính toán mã băm SHA-256 của tệp vừa tải. Nếu không khớp, tệp bị xóa ngay lập tức.
4. **Nâng cấp Nguyên tử (Atomic Promotion):** Khi mã băm hợp lệ, tệp được đổi tên và chuyển sang thư mục hoạt động chính thức `audio/`.
5. **Ghi nhận Metadata vào Cơ sở dữ liệu:** Cập nhật bản ghi trong bảng `audio_assets` với trạng thái `status = 'ready'`.
6. **Hỗ trợ Tạm dừng / Tiếp tục / Hủy an toàn:**
   - Nếu người dùng bấm Tạm dừng (`pause()`), tiến trình chờ lệnh tiếp tục.
   - Nếu người dùng bấm Hủy (`cancel()`), toàn bộ thư mục `.tmp/` lập tức bị dọn dẹp sạch sẽ, không để lại tệp rác.
7. **Cập nhật Vi sai (Incremental Update):** Nếu tệp âm thanh đã có sẵn trên đĩa và mã băm SHA-256 khớp với manifest, hệ thống sẽ bỏ qua và chỉ tải những tệp còn thiếu.

---

## 4. KIỂM TOÁN ĐỘ PHỦ ÂM THANH TRUNG THỰC (AUDIO COVERAGE AUDITOR)

`AudioCoverageAuditor` (`lib/features/audio_management/data/audio_coverage_auditor.dart`) loại bỏ hoàn toàn các con số phần trăm giả định:

- Quét số lượng từ vựng, bài đọc, câu ngữ pháp thực tế cần có âm thanh trong cơ sở dữ liệu.
- Quét số lượng tệp âm thanh có trạng thái `ready` trong bảng `audio_assets` và tệp tồn tại thực sự trên đĩa.
- Trả về báo cáo trung thực:
  - Khóa Pinyin: 100% độ phủ âm thanh cần thiết.
  - HSK 1: Độ phủ phát âm cơ bản đầy đủ.
  - HSK 2: Độ phủ bài học và từ vựng đầy đủ.
  - HSK 3–6: Phân loại rõ số lượng tệp đã tải ngoại tuyến so với tổng số lượng yêu cầu của cấp độ.
