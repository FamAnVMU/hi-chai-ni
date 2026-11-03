# Báo cáo Kỹ thuật & Bàn giao: Fix Curriculum Content Payload & Curriculum ID (P0_02)

## 1. Nguyên nhân gốc rễ (Root Cause Analysis)

Trước khi thực hiện bản vá P0_02, hệ thống học tập của **HI Chinese** gặp 2 vấn đề trọng yếu khiến người học không thể xem hoặc tương tác với nội dung giáo trình HSK 1:

1. **Lỗi truy vấn thiếu Content Payload (Issue A):**
   - Trước đây, `CurriculumDao.getSegmentsByLessonId(lessonId)` chỉ thực hiện câu lệnh:
     ```sql
     SELECT * FROM lesson_segments WHERE lesson_id = ? ORDER BY step_order ASC
     ```
   - Trong kiến trúc chuẩn hóa cơ sở dữ liệu học tập của HI Chinese, bảng `lesson_segments` chỉ lưu trữ cấu trúc điều hướng (`lesson_id`, `step_order`, `segment_type`, `title`, `content_ref_id`), trong khi nội dung bài học thực tế (danh sách từ vựng, điểm ngữ pháp, kịch bản hội thoại, câu hỏi trắc nghiệm) lại được lưu trữ dưới dạng JSON trong cột `content_json` của bảng `content_items`.
   - Vì không thực hiện phép nối giữa `lesson_segments` và `content_items`, trường `contentPayload` trong `LessonSegment` luôn mang giá trị `null`. Hệ quả là các màn hình bước học (Warmup, Vocab, Grammar, Dialogue, Practice, Mastery) không có dữ liệu để hiển thị, dẫn đến tình trạng treo màn hình nạp hoặc màn hình trống.

2. **Lỗi Curriculum ID không chính xác và phân mảnh (Issue B):**
   - Màn hình giáo trình `CurriculumSyllabusScreen` sử dụng hardcoded default `curriculumId: 'hsk_1_official'`.
   - Trong khi đó, bộ dữ liệu HSK 1 chính thức (`hsk1_pack_v1.json`) và schema chuẩn hóa quy ước ID giáo trình là `'curr_hsk1'` (mã chuẩn: `HSK_2012_L1`).
   - Do sai lệch định danh, các truy vấn `getUnitsByCurriculumId('hsk_1_official')` luôn trả về danh sách rỗng (0 units), khiến giao diện giáo trình hoàn toàn trống trơn đối với người dùng mới.

---

## 2. Schema thực tế & Giải pháp Join

### 2.1. Cấu trúc Schema

- **Bảng `lesson_segments`:**
  - `id` (TEXT PRIMARY KEY): Mã định danh segment (ví dụ: `seg_1_1`, `seg_1_2`).
  - `lesson_id` (TEXT NOT NULL): Khóa ngoại liên kết `curriculum_lessons.id`.
  - `step_order` (INTEGER NOT NULL): Thứ tự bước (1 = Warmup, 2 = Vocab, 3 = Grammar, 4 = Dialogue, 5 = Practice, 6 = Mastery).
  - `segment_type` (TEXT NOT NULL): Phân loại bước (`warmup`, `vocabulary`, `grammar`, `dialogue`, `practice`, `mastery_check`).
  - `title` (TEXT NOT NULL): Tiêu đề hiển thị của bước học.
  - `content_ref_id` (TEXT): Khóa tham chiếu ngoại vi đến `content_items.content_id` (ví dụ: `VOCAB_L1`, `GRAMMAR_L1`).

- **Bảng `content_items`:**
  - `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
  - `content_id` (TEXT UNIQUE NOT NULL): Mã định danh nội dung (ví dụ: `WARMUP_L1`, `VOCAB_L1`).
  - `curriculum_id` (TEXT NOT NULL): ID giáo trình (ví dụ: `curr_hsk1`).
  - `hsk_level` (INTEGER NOT NULL).
  - `knowledge_type` (TEXT NOT NULL): `warmup`, `vocabulary`, `grammar`, `dialogue`, `exercise`.
  - `title` (TEXT NOT NULL).
  - `content_json` (TEXT NOT NULL): Chuỗi JSON chứa toàn bộ payload kiến thức chi tiết.
  - `objectives_json` (TEXT).
  - `source_reference` (TEXT).

### 2.2. Giải pháp Query qua LEFT JOIN
Quan hệ giữa `lesson_segments` và `content_items` là quan hệ lỏng (cho phép segment tồn tại ngay cả khi content item chưa được nạp hoặc đang cập nhật pack). Do đó, giải pháp tối ưu là sử dụng **`LEFT JOIN`**:

```sql
SELECT 
  ls.*, 
  ci.content_json AS content_payload
FROM lesson_segments ls
LEFT JOIN content_items ci ON ls.content_ref_id = ci.content_id
WHERE ls.lesson_id = ?
ORDER BY ls.step_order ASC
```

---

## 3. Cơ chế mapping `content_json` -> `content_payload`

Trong model `LessonSegment.fromMap()` (`lib/features/curriculum/domain/models/curriculum_models.dart`), cơ chế giải mã hỗ trợ cả 2 trường hợp:
1. Trường hợp chuỗi JSON thô từ SQLite: Tự động chạy `json.decode(payloadString)` để chuyển thành `Map<String, dynamic>`.
2. Trường hợp Map đã được giải mã từ memory / mock fixtures: Nhận trực tiếp đối tượng Map mà không decode hai lần.
3. Xử lý an toàn: Bọc trong khối `try-catch` để nếu JSON format bất thường, `contentPayload` sẽ gán `null` thay vì văng crash runtime.

---

## 4. Danh sách các file và dòng code đã sửa

| File | Thay đổi chính |
| :--- | :--- |
| `lib/core/database/dao/curriculum_dao.dart` | Sửa `getSegmentsByLessonId()` sử dụng `LEFT JOIN ${DatabaseConstants.tableContentItems} ci ON ls.content_ref_id = ci.content_id` và alias `ci.content_json AS content_payload`. |
| `lib/features/curriculum/domain/constants/curriculum_constants.dart` | **Tạo mới**: Định nghĩa tập trung `CurriculumConstants` với `currHsk1..currHsk6`, hàm tiện ích `curriculumIdForLevel(level)` và `levelFromCurriculumId(id)`. |
| `lib/features/curriculum/domain/models/curriculum_models.dart` | Export `CurriculumConstants`. Cập nhật `LessonSegment.fromMap()` decode an toàn `content_payload` & `content_json`. |
| `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart` | Đổi giá trị mặc định của `curriculumId` thành `CurriculumConstants.currHsk1`. |
| `lib/features/curriculum/presentation/widgets/lesson_content_empty_state.dart` | **Tạo mới**: Widget hiển thị giao diện fallback chuyên nghiệp khi segment thiếu payload hoặc rỗng, kèm nút cho phép người học tiếp tục mà không bị kẹt. |
| `lib/features/curriculum/presentation/widgets/lesson_warmup_view.dart` | Hỗ trợ nạp cả trường `intro` lẫn `objective`. Ghi log kỹ thuật nếu thiếu payload. |
| `lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart` | Thay thế giao diện loading treo bằng `LessonContentEmptyState` khi `words.isEmpty`. |
| `lib/features/curriculum/presentation/widgets/lesson_grammar_view.dart` | Thay thế giao diện loading treo bằng `LessonContentEmptyState` khi `points.isEmpty`. |
| `lib/features/curriculum/presentation/widgets/lesson_dialogue_view.dart` | Thay thế giao diện loading treo bằng `LessonContentEmptyState` khi `lines.isEmpty`. |
| `lib/features/curriculum/presentation/widgets/lesson_practice_view.dart` | Hỗ trợ nạp cả `exercises` lẫn `questions`, hiển thị `LessonContentEmptyState` khi rỗng. |
| `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart` | Thay thế text chờ bằng `LessonContentEmptyState` cho phép hoàn thành bài học khi bài test chưa có dữ liệu. |
| `test/features/curriculum/curriculum_payload_and_id_test.dart` | **Tạo mới**: Bộ 8 bài kiểm thử chuyên sâu cho toàn bộ luồng JOIN payload, default curriculum ID, empty states, và khả năng tương tác. |

---

## 5. Danh sách Curriculum ID chuẩn trong hệ thống

Tất cả các định danh đã được chuẩn hóa thống nhất theo chuẩn quốc tế HSK:

| Cấp độ HSK | Canonical Curriculum ID | Official Code | Pack ID |
| :---: | :---: | :---: | :---: |
| HSK 1 | `curr_hsk1` | `HSK_2012_L1` | `hsk1_pack_v1` |
| HSK 2 | `curr_hsk2` | `HSK_2012_L2` | `hsk2_pack_v1` |
| HSK 3 | `curr_hsk3` | `HSK_2012_L3` | `hsk3_pack_v1` |
| HSK 4 | `curr_hsk4` | `HSK_2012_L4` | `hsk4_pack_v1` |
| HSK 5 | `curr_hsk5` | `HSK_2012_L5` | `hsk5_pack_v1` |
| HSK 6 | `curr_hsk6` | `HSK_2012_L6` | `hsk6_pack_v1` |

> [!IMPORTANT]
> Toàn bộ các định danh legacy cũ (như `hsk_1_official`) đã bị loại bỏ hoàn toàn khỏi mã nguồn sản phẩm.

---

## 6. Xử lý các trường hợp ngoại lệ (Payload thiếu, ID sai)

1. **Khi `content_items` chưa có mục tương ứng với `content_ref_id`:**
   - DAO trả về dòng segment với `content_payload = NULL`.
   - Model tạo đối tượng `LessonSegment` hợp lệ với `contentPayload: null`.
   - UI hiển thị thẻ thông báo `LessonContentEmptyState`:
     - Biểu tượng đồng hồ cát / trạng thái nội dung đang chuẩn bị.
     - Tiêu đề thông báo rõ ràng (ví dụ: *"Nội dung từ vựng đang được chuẩn bị"*).
     - Nút hành động *"Tiếp tục bài học"* hoặc *"Hoàn thành bài học"* giúp học viên tiến tới bước tiếp theo hoặc kết thúc bài học, không bị kẹt hay màn hình trắng.
     - Ghi log kỹ thuật `debugPrint('[CurriculumUI] Missing/empty content payload: lessonId=..., segmentId=..., ...')` không chứa bất kỳ thông tin nhạy cảm (PII) nào của học viên.
   - **Tuyệt đối không sinh nội dung giả mạo (hallucinated fake content).**

2. **Khi truy vấn với Curriculum ID không tồn tại:**
   - `CurriculumRepository.getUnits(invalidId)` trả về danh sách rỗng `[]` an toàn, không ném exception.
   - `CurriculumSyllabusScreen` hiển thị trạng thái danh sách bài học rỗng kèm thông báo nhẹ nhàng cho người dùng.

---

## 7. Kết quả kiểm thử

Tất cả các bài kiểm thử đơn vị, kiểm thử tích hợp DAO và widget tests đều đã vượt qua 100%:

- **`test/features/curriculum/curriculum_payload_and_id_test.dart` (8/8 PASSED):**
  - Test 1: `CurriculumDao.getSegmentsByLessonId` trả về segment kèm `content_payload` qua LEFT JOIN.
  - Test 2: `CurriculumDao.getSegmentsByLessonId` xử lý an toàn segment không có content tương ứng (LEFT JOIN NULL).
  - Test 3: `LessonSegment.fromMap` giải mã chính xác cả chuỗi JSON lẫn Map object.
  - Test 4: `CurriculumConstants` xác nhận đúng canonical ID và cơ chế chuyển đổi cấp độ.
  - Test 5: `CurriculumRepository.getUnits` với ID không tồn tại trả về danh sách rỗng an toàn.
  - Test 6: `CurriculumSyllabusScreen` mặc định là `curr_hsk1` và render đầy đủ units/lessons.
  - Test 7: `LessonStudyScreen` hiển thị fallback UI `LessonContentEmptyState` khi thiếu payload mà không crash.
  - Test 8: Người học có thể nhấn nút trên `LessonContentEmptyState` để tiếp tục học mà không bị nghẽn.

- **Toàn bộ suite `test/features/curriculum/`:** Vượt qua toàn bộ các bài test hiện có (UI widget tests, content pack loader, mastery engine, prerequisite engine).
