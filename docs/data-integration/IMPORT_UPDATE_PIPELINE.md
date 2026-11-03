# HI CHINESE – IMPORT & UPDATE PIPELINE SPECIFICATION
**Quy Trình Nhập Liệu, Cập Nhật Phiên Bản và Cơ Chế Rollback An Toàn**
*Ngày lập: 03/11/2026 | Phiên bản: 1.0.0 | Tác giả: Principal Software Architect & Senior Data Engineer*

---

## 1. CÁC CÔNG CỤ NHẬP LIỆU (IMPORT CLI TOOLS)

Dự án cung cấp 4 script CLI chuyên biệt tại thư mục `tool/`:

1. **`tool/import_vocabulary.dart`**:
   - Nhập 5.000 từ vựng HSK 1–6 từ `assets/data/hsk_seed_fixture_v2.json`.
   - Nạp các bảng `vocabularies`, `vocabulary_senses`, `vocabulary_examples` và `dictionary_entries`.
2. **`tool/import_grammar.dart`**:
   - Nhập 1.027 điểm ngữ pháp và 6.174 ví dụ từ `assets/data/hsk_grammar_all.json`.
   - Nạp các bảng `grammar_items`, `grammar_examples` và `grammar_topics`.
3. **`tool/import_hanzi.dart`**:
   - Nhập 2.632 chữ Hán với dữ liệu vector nét từ `assets/data/hanzi_stroke_data.json`.
   - Nạp bảng `hanzi_characters`.
4. **`tool/import_sentences.dart`**:
   - Nhập 1.500 câu ví dụ kèm audio metadata từ `assets/data/sentences_corpus.json`.
   - Nạp các bảng `sentences` và `sentence_audio`.

---

## 2. NGUYÊN TẮC IDEMPOTENCY VÀ AN TOÀN DỮ LIỆU

Mọi script import đều tuân thủ các nguyên tắc nghiêm ngặt:
- **Giao dịch nguyên tử (Atomic SQLite Transactions)**: Toàn bộ quá trình nạp theo batch được bọc trong `db.transaction()`. Nếu có bất kỳ lỗi cú pháp hoặc vi phạm khóa ngoại nào xảy ra, toàn bộ giao dịch tự động Rollback về trạng thái cũ.
- **Tính Idempotent (Chạy lặp lại an toàn)**: Sử dụng cú pháp `INSERT INTO ... ON CONFLICT(id) DO UPDATE SET ...`. Chạy lại script nhiều lần không sinh ra dữ liệu trùng lặp (duplicate rows) và không làm tăng dung lượng database vô ích.
- **Bảo toàn dữ liệu người dùng (Zero User Data Loss)**: Các bảng tiến độ của người học (`learner_evidence`, `mastery_snapshots`, `sentence_practice_progress`, `hanzi_writing_progress`) **không bao giờ bị `DROP` hoặc `TRUNCATE`** trong quá trình import học liệu mới.
