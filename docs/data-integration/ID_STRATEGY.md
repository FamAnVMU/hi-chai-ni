# HI CHINESE – UNIFIED ID STRATEGY & ALIAS ARCHITECTURE
**Chiến lược Định danh Thống nhất, Quản lý Bí danh và Tương thích Ngược**
*Ngày lập: 03/11/2026 | Phiên bản: 1.0.0 | Tác giả: Principal Software Architect & Senior Data Engineer*

---

## 1. NGUYÊN TẮC THIẾT KẾ ĐỊNH DANH (ID PRINCIPLES)

1. **Bất biến (Immutability)**: ID không thay đổi qua các đợt phát hành, cập nhật dữ liệu hoặc bổ sung trường thông tin.
2. **Không phụ thuộc vào vị trí dòng**: Không dùng số thứ tự index trong mảng JSON/CSV làm ID.
3. **Phản ánh nguồn gốc minh bạch**: Tiền tố ID mang mã định danh nguồn (như `tat_` cho Tatoeba, `as_` cho AllSet Wiki, `gushi_` cho Gushi HSK 3.0).
4. **Phân tách thực thể học tập và đơn vị tri thức**:
   - ID bản ghi vật lý (Primary Key trong các bảng SQLite `vocabularies`, `grammar_items`, `hanzi_characters`, `sentences`).
   - ID đơn vị tri thức chuẩn hóa (Canonical Knowledge ID trong `knowledge_registry`), là khóa ngoại neo giữ tiến độ học tập của người dùng.

---

## 2. QUY CHUẨN TIỀN TỐ VÀ CẤU TRÚC ID

| Thực thể (Entity) | Mẫu ID vật lý (Physical PK) | Mẫu ID Tri thức chuẩn hóa (Knowledge ID) | Ví dụ minh họa |
| :--- | :--- | :--- | :--- |
| **Từ vựng (Vocabulary)** | `voc_hsk{lvl}_{hash/code}` | `KNOW_VOCAB_{simplified}_{pinyin_clean}` | PK: `voc_hsk1_001`<br>Canonical: `KNOW_VOCAB_老师_laoshi` |
| **Nghĩa từ vựng (Sense)** | `sns_{vocab_id}_{index}` | N/A (thuộc Vocabulary) | `sns_voc_hsk1_001_1` |
| **Chữ Hán (Character)** | `char_{unicode_hex}` | `KNOW_HANZI_{character}` | PK: `char_674e` (chữ 李)<br>Canonical: `KNOW_HANZI_李` |
| **Điểm ngữ pháp (Grammar)**| `gram_{source}_{code}` | `KNOW_GRAM_{code}` | PK: `gram_as_a1_001`<br>Canonical: `KNOW_GRAM_as_a1_001` |
| **Ví dụ ngữ pháp (Example)**| `gex_{grammar_id}_{index}` | N/A (thuộc Grammar) | `gex_gram_as_a1_001_1` |
| **Câu ví dụ (Sentence)** | `tat_{source_id}` / `sent_hsk{lvl}_{idx}` | `KNOW_SENT_{id}` | PK: `tat_100123`<br>Canonical: `KNOW_SENT_tat_100123` |
| **Âm thanh (Audio)** | `aud_tat_{id}` / `aud_tts_{id}` | N/A (thuộc Sentence) | `aud_tat_100123` |
| **Bài tập (Exercise)** | `ex_{type}_{entity_id}_{idx}` | N/A (gắn với Knowledge ID) | `ex_mc_as_a1_001_1` |

---

## 3. XỬ LÝ TRÙNG HỢP VÀ TỪ ĐỒNG ÂM / ĐA ÂM (POLYPHONE & HOMOGRAPH)

### 3.1. Từ Đa Âm (Polyphone)
- Một chữ Hán có nhiều cách đọc và nghĩa khác nhau (ví dụ: `行` có thể đọc là `xíng` hoặc `háng`).
- **Giải pháp**: Phân biệt Canonical ID bằng sự kết hợp giữa chữ Hán và `pinyin_clean`:
  - `KNOW_VOCAB_行_xing` (nghĩa: được, đi lại, tiến hành)
  - `KNOW_VOCAB_行_hang` (nghĩa: hàng ngũ, ngân hàng)
- Cờ `is_polyphone = 1` được đánh dấu trong bảng `vocabularies`.

### 3.2. Chữ Giản Thể và Phồn Thể
- Lưu trữ song song trong cùng bản ghi `vocabularies` (`simplified` và `traditional`).
- Không tạo 2 bản ghi riêng biệt gây phân mảnh từ điển và trùng lặp tiến độ của người học.

---

## 4. QUẢN LÝ BÍ DANH VÀ TƯƠNG THÍCH NGƯỢC (CONTENT ID MAPPINGS)

Khi hệ thống tái cấu trúc học liệu hoặc đổi mã điểm ngữ pháp, bảng `content_id_mappings` (tạo từ Migration v10) lưu trữ lịch sử chuyển đổi:

```sql
CREATE TABLE content_id_mappings (
  id TEXT PRIMARY KEY,
  old_id TEXT NOT NULL,
  new_id TEXT NOT NULL,
  mapping_type TEXT NOT NULL, -- 'rename', 'merge', 'split', 'deprecate'
  package_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL
);
```

### Cơ chế bảo vệ tiến độ học tập:
Khi `LearningPipelineCoordinator` hoặc SRS truy vấn lịch sử học tập của một ID cũ:
1. Truy vấn trực tiếp `learner_evidence` và `mastery_progress` theo ID.
2. Nếu không tìm thấy, kiểm tra `content_id_mappings.new_id` theo `old_id` để nối tiếp tiến độ mà không bao giờ reset số lần ôn tập hay điểm mastery của người dùng.
