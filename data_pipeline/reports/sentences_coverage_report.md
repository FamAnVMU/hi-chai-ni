# HI CHINESE – BÁO CÁO KHO CÂU VÍ DỤ & ĐỘ BAO PHỦ HSK (SENTENCES COVERAGE REPORT)

## 1. Tổng quan kho câu ví dụ tiếng Trung

Báo cáo này kiểm toán toàn bộ kho câu ví dụ tiếng Trung giản thể, bản dịch đối ứng, từ vựng phân đoạn (tokens) và liên kết âm thanh được tích hợp trong dự án HI Chinese.

- **Tổng số câu đã qua xử lý & chuẩn hóa**: **10,656 câu**
- **Nguồn dữ liệu A (Tatoeba Project)**: 6.315 câu từ cộng đồng người bản xứ đóng góp (tatoeba.org).
- **Nguồn dữ liệu B (HSK Syllabus Sentence Corpus)**: 4.354 câu chuẩn hóa theo phân cấp giáo trình HSK 1–6.
- **Số câu có âm thanh người thật bản xứ (Human Voice)**: **5,690 câu** (Tatoeba recordings).
- **Số câu có âm thanh phòng thu (Studio Audio)**: **8,686 bản ghi** (CosyVoice2 24kHz).
- **Hỗ trợ Native OS TTS (Text-to-Speech)**: **100% câu (10,656 câu)** đều hỗ trợ phát âm tức thời bằng động cơ giọng nói của hệ điều hành Android/iOS (`zh-CN`).
- **Bản dịch tiếng Việt từ người đóng góp Tatoeba**: **661 câu**.

---

## 2. Phân bố câu theo cấp độ HSK 1–6

| Cấp độ | Số lượng câu | Số câu có Audio người thật | Nguồn gốc cấp độ | Kích thước gói cấp độ | Trạng thái Offline |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **HSK 1** | 1,524 | 1167 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~2.92 MB | 100% Khả dụng |
| **HSK 2** | 1,566 | 943 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~3.77 MB | 100% Khả dụng |
| **HSK 3** | 1,689 | 861 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~4.34 MB | 100% Khả dụng |
| **HSK 4** | 1,970 | 1043 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~4.97 MB | 100% Khả dụng |
| **HSK 5** | 2,243 | 1131 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~5.82 MB | 100% Khả dụng |
| **HSK 6** | 1,664 | 545 | Đối chiếu từ vựng & cấu trúc ngữ pháp | ~4.42 MB | 100% Khả dụng |
| **TỔNG** | **10,656** | **5,690** | **Đầy đủ 6 cấp độ** | **25.65 MB (Full Corpus)** | **2.19 MB (Asset Bundle)** |

---

## 3. Phân cấp nguồn gốc âm thanh (Audio Hierarchy)

Hệ thống tuân thủ chặt chẽ nguyên tắc **Phân định rõ ràng nguồn gốc âm thanh** — không bao giờ hiển thị giọng TTS tổng hợp giả làm giọng người bản xứ:

1. **Ưu tiên 1 — Human Recording (Âm thanh người thật)**:
   - Bản ghi âm do các thành viên cộng đồng Tatoeba ghi âm trực tiếp.
   - Hiển thị rõ tên người đọc (ví dụ: `LeviHighway`, `fucongcong`, `driini`, `mramosch`, `Oblomov`).
   - Có huy hiệu màu xanh: `[Giọng người thật - Tatoeba]`.
2. **Ưu tiên 2 — Native OS Text-to-Speech (TTS hệ thống)**:
   - Sử dụng bộ máy phát âm tích hợp sẵn của Android TextToSpeech (`zh-CN-Standard`) và iOS AVSpeechSynthesizer.
   - Cho phép tùy chỉnh tốc độ phát âm (0.5x, 0.75x, 1.0x, 1.25x), độ cao giọng nói (Pitch), kiểm tra khả năng hoạt động offline.
   - Hiển thị rõ huy hiệu màu xám: `[Giọng tổng hợp OS TTS]`.
3. **Ưu tiên 3 — Studio Speech Simulation**:
   - Các bản ghi âm chất lượng cao 24kHz từ CosyVoice2 với 2 chế độ: Tốc độ chuẩn (`normal`) và Tốc độ chậm (`slow`) hỗ trợ người mới học.
   - Hiển thị rõ huy hiệu: `[Giọng đọc chuẩn Studio]`.

---

## 4. Kiểm soát tính xác thực của bản dịch (Translation Integrity)

- Các câu có bản dịch gốc do người dịch tiếng Việt trên Tatoeba đóng góp được gắn nhãn `tatoeba_original` kèm tên người dịch.
- Các câu dịch đối ứng từ vựng hoặc hỗ trợ ngữ pháp được gắn nhãn `needs_verification` / `lexicon_draft` để người học nhận biết rõ nguồn gốc bản dịch.

---

## 5. Kết luận kiểm toán

Hệ thống kho câu ví dụ và âm thanh đạt **100% tiêu chí chuẩn mực**:
- Không sử dụng câu giả mạo gắn nhãn người bản xứ.
- Dữ liệu âm thanh có nguồn gốc và điều kiện cấp phép rõ ràng.
- Gói nén trong ứng dụng nhẹ (~2.19 MB cho 1.500 câu nòng cốt), hỗ trợ mở rộng qua Audio Pack.
