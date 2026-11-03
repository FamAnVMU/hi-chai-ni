# DANH SÁCH NGUỒN DỮ LIỆU & BẢN QUYỀN MÃ NGUỒN MỞ (SOURCES & LICENSES)
**Dự án: HI Chinese • Dữ liệu Từ vựng & Từ điển Ngoại tuyến**
*Tuân thủ bản quyền và quy định ghi công (Attribution Compliance)*

---

## 1. NGUYÊN TẮC QUẢN TRỊ BẢN QUYỀN

Toàn bộ dữ liệu từ vựng HSK 1–6, từ điển ngoại tuyến, âm Hán–Việt và câu ví dụ trong ứng dụng HI Chinese đều được trích xuất hợp pháp từ các dự án mã nguồn mở uy tín.

Ứng dụng cam kết:
1. **Minh bạch xuất xứ:** Lưu trữ thông tin `source` và `license` trực tiếp trong cấu trúc bản ghi SQLite Schema v12 và hiển thị trực tiếp cho người học tại giao diện chi tiết từ điển.
2. **Tuân thủ giấy phép:** Đáp ứng đầy đủ các điều kiện về ghi công (Attribution) và chia sẻ tương tự (ShareAlike) theo quy định của từng giấy phép.
3. **Phân tách rõ ràng:** Lưu trữ dữ liệu gốc tải về (Raw Data) riêng biệt tại `data_pipeline/raw/` trước khi tiến hành chuẩn hóa sang định dạng nội bộ ứng dụng tại `data_pipeline/processed/`.

---

## 2. BẢNG DANH MỤC CÁC NGUỒN HỌC LIỆU

| Nguồn Dữ liệu | Tác giả / Tổ chức | Giấy phép (License) | URL Kho lưu trữ (Repository) | Dữ liệu được Khai thác |
| :--- | :--- | :--- | :--- | :--- |
| **`clem109/hsk-vocabulary`** | Clément San | **MIT License** | [github.com/clem109/hsk-vocabulary](https://github.com/clem109/hsk-vocabulary) | Danh sách từ vựng HSK 1–6 (5.000 từ), Hán tự giản thể, Pinyin có dấu thanh, nghĩa tiếng Anh và ID gốc. |
| **`drkameleon/complete-hsk-vocabulary`** | drkameleon (Tudor) | **MIT License** | [github.com/drkameleon/complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) | Bộ thủ chữ Hán (Radicals), số nét bút, xếp hạng tần suất (SUBTLEX-CH), từ loại ngữ pháp (POS), chữ Hán phồn thể, lượng từ (Classifiers). |
| **`CC-CEDICT`** | MDBG & Denisowski Community | **CC BY-SA 4.0** | [cc-cedict.org](https://cc-cedict.org/) | Cơ sở dữ liệu từ điển Hán - Anh toàn diện (~122.000 mục từ), quy chuẩn Pinyin số và phân loại đa âm. |
| **`ph0ngp/CVDICT`** | Phong Phan | **CC BY-SA 4.0** | [github.com/ph0ngp/CVDICT](https://github.com/ph0ngp/CVDICT) | Từ điển Trung - Việt chuyển dịch từ CC-CEDICT với hơn 122.500 mục từ; giải nghĩa tiếng Việt chuẩn xác cho 5.000 từ HSK và 119.044 từ ngoại tuyến. |
| **`ph0ngp/hanviet-pinyin-wordlist`** | Phong Phan | **MIT License** | [github.com/ph0ngp/hanviet-pinyin-wordlist](https://github.com/ph0ngp/hanviet-pinyin-wordlist) | Bảng ánh xạ hơn 10.500 chữ Hán kèm phiên âm Pinyin sang âm Hán - Việt tương ứng (dựa trên các bộ tự điển Hán Việt cổ điển). |
| **`no7z/hsk-sentences-audio`** | no7z Contributors | **Apache-2.0 / MIT** | [github.com/no7z/hsk-sentences-audio](https://github.com/no7z/hsk-sentences-audio) | 4.354 câu ví dụ chuẩn HSK phân cấp độ, câu chữ Hán, Pinyin phiên âm, bản dịch tiếng Anh và siêu dữ liệu âm thanh phát âm. |

---

## 3. CHI TIẾT ĐIỀU KHOẢN GIẤY PHÉP

### 3.1. MIT License (`clem109`, `drkameleon`, `hanviet-pinyin-wordlist`)
> Cho phép tự do sử dụng, sao chép, sửa đổi, hợp nhất, xuất bản, phân phối và sử dụng cho cả mục đích thương mại và phi thương mại, với điều kiện duy nhất là giữ nguyên thông báo bản quyền gốc.

### 3.2. Creative Commons Attribution-ShareAlike 4.0 International - CC BY-SA 4.0 (`CC-CEDICT`, `CVDICT`)
> **Attribution (Ghi công):** Phải cung cấp thông tin ghi nhận công lao thích hợp, cung cấp đường link dẫn đến giấy phép và chỉ rõ nếu có những thay đổi được thực hiện.  
> **ShareAlike (Chia sẻ tương tự):** Nếu bạn phối lại, chuyển đổi hoặc xây dựng dựa trên tài liệu này, bạn phải phân phối các đóng góp của mình theo cùng một giấy phép với bản gốc.

*Cách thức thực hiện trong HI Chinese:*
- Bản quyền của tác giả Phong Phan và dự án CC-CEDICT được công bố công khai trong màn hình **Cài đặt -> Thông tin ứng dụng và Giấy phép** (`AboutAndPrivacyDialog`).
- Tại màn hình **Chi tiết từ vựng**, mỗi mục từ đều hiển thị huy hiệu ghi công: `Nguồn: CVDICT;CC-CEDICT • Giấy phép: CC BY-SA 4.0`.

### 3.3. Apache License 2.0 (`no7z/hsk-sentences-audio`)
> Cấp phép sử dụng, sửa đổi và phân phối mã nguồn và dữ liệu kèm quyền bảo lưu sáng chế và tuyên bố miễn trừ trách nhiệm bảo hành.

---

## 4. QUY TRÌNH LƯU TRỮ VÀ TOÀN VẸN HỌC LIỆU

1. **Thư mục Dữ liệu Thô (Raw Sources):**  
   - `data_pipeline/raw/clem109/`: Giữ nguyên vẹn 6 tệp JSON từ `clem109`.
   - `data_pipeline/raw/cvdict/CVDICT.u8`: Giữ nguyên vẹn tệp 10.8 MB phân phối chính thức của Phong Phan.
   - `data_pipeline/raw/drkameleon/`: Giữ nguyên tệp HSK 1–6 gốc.
   - `data_pipeline/raw/hanviet/hanviet.csv`: Giữ nguyên bảng ánh xạ âm Hán - Việt.
   - `data_pipeline/raw/sentences/sentences.json`: Giữ nguyên bộ 4.354 câu ví dụ.
2. **Thư mục Dữ liệu Đã Xử lý (Processed Data):**  
   - `data_pipeline/processed/hsk_all_vocab.json`: Tệp tổng hợp 5.000 từ vựng đã chuẩn hóa Unicode NFC, bổ sung âm Hán Việt và câu ví dụ.
   - `data_pipeline/processed/hsk_seed_fixture_v2.json`: Bản fixture chính thức phục vụ nạp vào ứng dụng SQLite.
   - `data_pipeline/processed/offline_dictionary_entries.json`: Bản từ điển 119.044 mục từ tra cứu ngoại tuyến.
