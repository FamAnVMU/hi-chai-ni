# HI CHINESE – GIẤY PHÉP VÀ NGUỒN GỐC DỮ LIỆU CHỮ HÁN (HANZI LICENSES & ATTRIBUTION)

Báo cáo này đặc tả nguồn gốc, bản quyền, điều khoản cấp phép và các biến đổi kỹ thuật của các bộ dữ liệu chữ Hán và thư viện được sử dụng trong dự án HI Chinese.

---

## 1. Nguồn dữ liệu Make Me a Hanzi

- **Tên dự án**: Make Me a Hanzi
- **Tác giả**: Shaun Kishore (skishore)
- **Repository**: [https://github.com/skishore/makemeahanzi](https://github.com/skishore/makemeahanzi)
- **Các tệp khai thác**: `graphics.txt`, `dictionary.txt`
- **Phiên bản / Commit khảo sát**: Master branch (9,574 ký tự)
- **Giấy phép bản quyền**:
  - Dữ liệu nét viết (Stroke data trong `graphics.txt`): Phát triển dựa trên Arphic PL fonts và WenQuanYi Zen Hei, tuân thủ **Arphic Public License** và **GPL v3 with Font Exception**.
  - Dữ liệu từ điển (`dictionary.txt`): Trích xuất từ Unihan, CEDICT và Kaikki, tuân thủ **Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0)** và **Unihan License Terms**.
- **Các phần tinh chỉnh trong HI Chinese**:
  - Trích lọc 2.632 ký tự thuộc giáo trình HSK 1–6 để tối ưu dung lượng cho thiết bị di động.
  - Ánh xạ liên kết với danh mục từ vựng tiếng Trung HSK 1–6 bằng ID ổn định `hanzi_{unicode_hex}`.
  - Bổ sung phát âm Hán-Việt và nghĩa tiếng Việt tương ứng.

---

## 2. Nguồn dữ liệu & Thuật toán Hanzi Writer

- **Tên dự án**: Hanzi Writer
- **Tác giả**: Chanin Dong (chanind)
- **Repository**: [https://github.com/chanind/hanzi-writer](https://github.com/chanind/hanzi-writer) & [https://github.com/chanind/hanzi-writer-data](https://github.com/chanind/hanzi-writer-data)
- **Giấy phép thư viện**: **MIT License**
  - Bản quyền: Copyright (c) 2017 Chanin Dong
- **Giải thuật được chuyển giao sang Flutter Native (Pure Dart)**:
  - Hệ tọa độ chuẩn Bounding Box `[0, -124]` đến `[1024, 900]`.
  - Thuật toán so khớp nét vẽ người dùng với đường trung tâm (Median points):
    - Kiểm tra khoảng cách điểm đầu và điểm cuối (Start & End points distance threshold: 250 units).
    - So khớp hướng nét bằng Cosine Similarity của các vector đoạn thẳng (`cosineSimilarity > 0`).
    - Kiểm tra độ dài nét tương đối (`lengthMatches >= 0.35`).
    - Tính toán độ lệch khoảng cách trung bình Fréchet giữa đường vẽ của người dùng và Median chuẩn.
    - Phát hiện nét vẽ ngược chiều (`isStrokeBackwards`).
    - Phát hiện lỗi sai thứ tự nét khi đường vẽ khớp với một nét nằm ở vị trí sau trong chuỗi nét.

---

## 3. Nguồn Từ điển Hán-Việt & Âm vựng

- **hanviet.csv**: Nguồn tổng hợp phát âm Hán-Việt tiêu chuẩn.
- **CVDICT**: Bản quyền mở từ dự án Từ điển Trung - Việt mã nguồn mở.
- **Bộ từ vựng HSK 1–6 HI Chinese**: Giấy phép MIT / Open Data.

---

## 4. Tuyên bố tuân thủ & Không can thiệp dữ liệu AI

1. Dự án **HI Chinese** cam kết **100% dữ liệu hình học nét chữ (SVG curves) và thứ tự nét (stroke order medians)** được trích xuất nguyên trạng từ Make Me a Hanzi và Hanzi Writer Data.
2. Tuyệt đối **không sử dụng AI để tự sinh, suy đoán hoặc sửa đổi tọa độ hình học nét chữ**.
3. Các cải tiến kỹ thuật chỉ bao gồm:
   - Chuẩn hóa định dạng JSON tinh gọn (minified JSON bundle).
   - Tối ưu hóa bộ nạp dữ liệu offline trên nền Flutter SQLite.
   - Triển khai động cơ render vector và nhận dạng cảm ứng 60fps trên Flutter CustomPainter.
