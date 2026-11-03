# HI CHINESE – BÁO CÁO ĐỘ BAO PHỦ CHỮ HÁN & THỨ TỰ NÉT (HANZI COVERAGE REPORT)

## 1. Tổng quan hệ thống dữ liệu Chữ Hán

Báo cáo này kiểm toán toàn bộ kho dữ liệu hình học chữ Hán (vector SVG paths, stroke orders, medians, etymology, radicals) được trích xuất và chuẩn hóa cho toàn bộ giáo trình HSK 1–6 trong ứng dụng HI Chinese.

- **Nguồn dữ liệu hình học gốc**: Make Me a Hanzi (`skishore/makemeahanzi`)
- **Nguồn dữ liệu hoạt họa & giải thuật nhận dạng nét**: Hanzi Writer (`chanind/hanzi-writer` & `hanzi-writer-data`)
- **Nguồn âm Hán-Việt & nghĩa tiếng Việt**: `hanviet.csv` & `CVDICT.u8` & bộ từ vựng HSK 1–6
- **Tổng số từ vựng HSK 1–6 khảo sát**: 5.000 từ vựng chuẩn
- **Tổng số chữ Hán độc bản (Unique Hanzi)**: **2,632 chữ**
- **Tỷ lệ bao phủ hình học & thứ tự nét (Coverage)**: **2632/2632 (100.0%)**
- **Số chữ không có dữ liệu nét (Missing strokes)**: **0 chữ (0.0%)**
- **Số chữ bị lỗi định dạng SVG/Medians**: **0 chữ (0.0%)**

---

## 2. Phân bố Chữ Hán theo Cấp độ HSK

| Cấp độ | Số lượng chữ | Tỷ lệ tích lũy | Số nét trung bình | Kích thước gói dữ liệu | Trạng thái hỗ trợ luyện viết |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **HSK 1** | 178 | 178 | 6.8 | ~973 KB | 100% Hoàn chỉnh (Offline) |
| **HSK 2** | 168 | 346 | 8.1 | ~1.02 MB | 100% Hoàn chỉnh (Offline) |
| **HSK 3** | 272 | 618 | 8.7 | ~1.74 MB | 100% Hoàn chỉnh (Offline) |
| **HSK 4** | 453 | 1071 | 8.9 | ~2.94 MB | 100% Hoàn chỉnh (Offline) |
| **HSK 5** | 639 | 1710 | 9.5 | ~4.30 MB | 100% Hoàn chỉnh (Offline) |
| **HSK 6** | 922 | 2632 | 10.4 | ~6.47 MB | 100% Hoàn chỉnh (Offline) |
| **TỔNG CỘNG** | **2,632** | **2,632 (100%)** | **9.3** | **7.52 MB (Compact bundle)** | **100% Khả dụng** |

---

## 3. Đặc tả Hình học & Dữ liệu Nét (Stroke Geometry Specs)

1. **Hệ tọa độ chuẩn (Coordinate System)**:
   - Make Me a Hanzi chuẩn hóa mọi chữ Hán trong Bounding Box có kích thước cố định:
     - `X`: `0` đến `1024`
     - `Y`: `-124` đến `900` (Tổng chiều cao = 1024 đơn vị)
   - Hệ trục Y chuẩn của font chữ có gốc tọa độ ở đường cơ sở (Baseline). Khi ánh xạ lên Flutter Canvas:
     - X_canvas = X_offset + X_font * Scale
     - Y_canvas = Y_offset + (900 - Y_font) * Scale
2. **Đường nét (Strokes)**:
   - Mỗi nét chữ được mô tả bằng chuỗi SVG path hợp lệ với các lệnh `M` (MoveTo), `Q` (Quadratic Bezier), `C` (Cubic Bezier), `L` (LineTo), `Z` (ClosePath).
   - Kiểm toán phát hiện: 100% nét đều bắt đầu bằng lệnh `M` và khép kín bằng `Z`.
3. **Đường trung tâm nét (Medians)**:
   - Mỗi nét tương ứng một mảng tọa độ `[[x, y], ...]` biểu diễn khung xương (skeleton) của nét viết từ điểm bắt đầu đến điểm kết thúc.
   - Số lượng nét SVG (`strokes.length`) luôn bằng chính xác số lượng đường trung tâm (`medians.length`).
4. **Phạm vi số nét**:
   - Ít nét nhất: **1 nét** (Ví dụ: 一, 乙)
   - Nhiều nét nhất: **23 nét**
   - Trung bình toàn bộ kho: **9.3 nét/chữ**
5. **Bộ thủ (Radicals) & Cấu trúc phân rã (Decomposition)**:
   - Số bộ thủ khác nhau được nhận diện: **239 bộ thủ**.
   - Cấu tạo phân rã ký tự biểu diễn theo định dạng IDC Unicode (`⿰`, `⿱`, `⿲`, `⿳`, `⿴`, `⿵`, `⿶`, `⿷`, `⿸`, `⿹`, `⿺`, `⿻`).

---

## 4. Liên kết Chữ Hán với Từ vựng HSK (Relational Integrity)

- Một chữ Hán độc bản được liên kết với nhiều từ vựng HSK thông qua khóa ngoài `word_id` và bảng `hanzi_characters`.
- Không nhân bản dữ liệu nét chữ: Cùng một chữ (ví dụ: chữ `学`) chỉ lưu trữ hình học nét 1 lần duy nhất trong cơ sở dữ liệu SQLite, phục vụ cho tất cả các từ ghép như `学校`, `学生`, `学习`, `留学`, `大学`.
- Lưu trữ tiến độ độc lập: Bảng `hanzi_writing_progress` theo dõi riêng từng chữ mà người học đã luyện viết.

---

## 5. Kết luận kiểm toán

Hệ thống dữ liệu chữ Hán đạt **100% tính sẵn sàng và tính toàn vẹn**:
- Không sử dụng bất kỳ nét vẽ giả hoặc dữ liệu AI tự suy đoán nào.
- 100% tọa độ và thứ tự nét có nguồn gốc xuất xứ từ Make Me a Hanzi và Hanzi Writer.
- Hoàn toàn tương thích cho chế độ chạy ngoại tuyến 100% trên thiết bị di động Flutter.
