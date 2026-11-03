# HI CHINESE – DATA PROVENANCE & LINEAGE SPECIFICATION
**Hệ Thống Truy Xuất Nguồn Gốc và Lịch Sử Dữ Liệu Học Thuật**
*Ngày lập: 03/11/2026 | Phiên bản: 1.0.0 | Tác giả: Principal Software Architect & Senior Data Engineer*

---

## 1. NGUYÊN TẮC TRUY XUẤT NGUỒN GỐC (DATA PROVENANCE)

**Không tự tạo dữ liệu học thuật bằng AI rồi gắn nhãn là dữ liệu bản xứ.** Mọi thực thể trong cơ sở dữ liệu HI Chinese đều phải có nguồn gốc xác định, kiểm chứng được và lưu vết qua các trường:
- `source`: Tên nguồn hoặc tổ hợp nguồn đóng góp.
- `license`: Giấy phép bản quyền của dữ liệu.
- `verification_status`: Trạng thái thẩm định (`verified`, `verified_open_source`, `lexicon_draft`, `needs_review`).

---

## 2. BẢNG PHẢ NGUYÊN DỮ LIỆU TOÀN DIỆN (DATA LINEAGE TABLE)

| Mã Nguồn | Tên Nguồn | Kho Lưu Trữ / Website | Bản quyền gốc | Ngày thu thập | Script ETL xử lý | Bảng SQLite đích | Trạng thái |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- | :---: |
| `SRC_CLEM` | HSK Vocabulary | `github.com/clem109/hsk-vocabulary` | MIT | 03/11/2026 | `build_hsk_vocabulary_dataset.py` | `vocabularies` | `VERIFIED` |
| `SRC_CEDICT`| CC-CEDICT | `mdbg.net/chinese/dictionary?page=cedict` | CC BY-SA 4.0 | 03/11/2026 | `build_hsk_vocabulary_dataset.py` | `vocabulary_senses`, `dictionary_entries` | `VERIFIED` |
| `SRC_HANVIET`| Hán-Việt Database | `github.com/pham/hanviet` | Public Domain | 03/11/2026 | `build_hsk_vocabulary_dataset.py` | `vocabularies.hanviet` | `VERIFIED` |
| `SRC_ALLSET`| Chinese Grammar Wiki | `github.com/krmanik/Chinese-Grammar` | CC BY-NC-SA 3.0 | 03/11/2026 | `build_hsk_grammar_dataset.py` | `grammar_items`, `grammar_examples` | `VERIFIED` |
| `SRC_GUSHI` | HSK 3.0 Grammar | `gushi-chinese.online` | CC BY-NC 4.0 | 03/11/2026 | `build_hsk_grammar_dataset.py` | `grammar_items`, `grammar_examples` | `VERIFIED` |
| `SRC_MMH` | Make Me a Hanzi | `github.com/skishore/makemeahanzi` | Arphic / OFL | 03/11/2026 | `build_hanzi_dataset.py` | `hanzi_characters` | `VERIFIED` |
| `SRC_TATOEBA_TXT`| Tatoeba Sentences | `downloads.tatoeba.org/exports` | CC BY 2.0 FR | 03/11/2026 | `build_sentences_dataset.py` | `sentences` | `VERIFIED` |
| `SRC_TATOEBA_AUD`| Tatoeba Audio | `tatoeba.org/audio/download/{id}` | CC BY-NC 4.0 / CC BY-SA 3.0 | 03/11/2026 | `build_sentences_dataset.py` | `sentence_audio` | `VERIFIED` |

---

## 3. PHÂN ĐỊNH TRẠNG THÁI CHẤT LƯỢNG (QUALITY STATUSES)

- `RAW`: Tệp dữ liệu gốc tải về từ Open Source chưa qua xử lý.
- `NORMALIZED`: Đã được làm sạch định dạng, phân đoạn từ vựng và đồng nhất Unicode.
- `VALIDATED`: Đã vượt qua các kiểm tra kỹ thuật (không null trường bắt buộc, không trùng khóa, JSON hợp lệ).
- `VERIFIED`: Đã đối chiếu chéo giữa ít nhất 2 nguồn dữ liệu độc lập (ví dụ: từ vựng Clem109 đối chiếu nghĩa với CC-CEDICT và âm Hán-Việt; ngữ pháp đối chiếu HSK 3.0 và AllSet Wiki).
- `NEEDS_REVIEW`: Dữ liệu có độ lệch hoặc mâu thuẫn cần giáo viên chuyên môn kiểm tra thủ công.
- `REJECTED`: Dữ liệu bị lỗi hoặc vi phạm bản quyền bị loại bỏ khỏi luồng đóng gói.
