# Báo Cáo Task 3: Nâng Cấp Kiểm Tra Toàn Vẹn & Tự Nạp Lại Khi Nâng Cấp Ứng Dụng

## 1. Thông Tin Chung
- **Task**: Task 3 - Nâng Cấp Kiểm Tra Toàn Vẹn & Tự Nạp Lại Khi Nâng Cấp Ứng Dụng
- **Trạng thái**: Hoàn thành xuất sắc (Completed)
- **Git Commit**: `6c89036`
- **Commit Message**: `fix(startup): ensure full segment and content item integrity check on app upgrade`

---

## 2. Các Tệp Tin Đã Chỉnh Sửa & Tạo Mới

### 2.1. Modified: `lib/core/startup/app_startup_provider.dart`
- **Kiểm tra sự tồn tại của `lesson_segments` khi khởi động**:
  - Trong `_checkPackNeedsImport(Database db, MandatoryPackInfo pack)` (và method `@visibleForTesting static checkPackNeedsImport`):
    Bổ sung truy vấn đếm số lượng segments liên kết với các bài học thuộc giáo trình:
    ```dart
    final segmentsRes = await db.rawQuery('''
      SELECT COUNT(*) as cnt 
      FROM ${DatabaseConstants.tableLessonSegments} 
      WHERE lesson_id IN (
        SELECT l.id FROM ${DatabaseConstants.tableCurriculumLessons} l
        INNER JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
        WHERE u.curriculum_id = ?
      )
    ''', [pack.curriculumId]);
    final segmentCount = Sqflite.firstIntValue(segmentsRes) ?? 0;
    if (segmentCount == 0) {
      return true; // Buộc nạp lại pack có sẵn để khôi phục các segments bị thiếu khi nâng cấp app
    }
    ```
- **Xác minh toàn vẹn dữ liệu giáo trình chuẩn (`_verifyDataIntegrity`)**:
  - Trong `_verifyDataIntegrity(Database db)` (và method `@visibleForTesting static verifyDataIntegrity`):
    Đảm bảo cả `curr_hsk1` và `curr_hsk2` đều có ít nhất 90 segments (tương ứng 15 bài học × 6 chặng sư phạm). Nếu số lượng segments < 90, ném `StateError` cảnh báo rõ ràng thay vì bỏ qua lỗi âm thầm.

### 2.2. Modified: `lib/core/database/dao/curriculum_dao.dart`
- **Khớp nối học liệu không phân biệt chữ hoa/thường & loại bỏ khoảng trắng**:
  - Trong `getSegmentsByLessonId(String lessonId)`:
    Thay thế phép nối bằng biểu thức chuẩn hoá:
    ```sql
    SELECT ls.*, ci.content_json AS content_payload
    FROM ${DatabaseConstants.tableLessonSegments} ls
    LEFT JOIN ${DatabaseConstants.tableContentItems} ci ON UPPER(TRIM(ls.content_ref_id)) = UPPER(TRIM(ci.content_id))
    WHERE ls.lesson_id = ?
    ORDER BY ls.step_order ASC
    ```
    Đảm bảo dù mã tham chiếu học liệu có sự khác biệt về chữ in hoa/thường hoặc khoảng trắng (vd: `'ci_vocab_apple'` vs `'CI_VOCAB_APPLE'`, `'  CI_GRAMMAR_LE   '`), câu lệnh SQL vẫn ánh xạ chính xác `content_payload`, loại bỏ triệt để nguy cơ màn hình bài học bị rỗng do lệch chuỗi ID.

### 2.3. Created: `test/features/content_packs/pack_upgrade_integrity_test.dart`
Xây dựng 3 bài kiểm thử TDD tự động:
1. `checkPackNeedsImport returns true when pack has lessons but 0 segments`: Kiểm tra tính năng tự động kích hoạt nạp lại khi bài học có nhưng segments rỗng, và trả về `false` khi dữ liệu đã đầy đủ.
2. `verifyDataIntegrity fails when curriculum has lessons but missing segments (< 90)`: Kiểm tra cơ chế gatekeeper của startup ném `StateError` chứa thông điệp `'segments'` khi số segments không đạt chuẩn 90.
3. `CurriculumDao.getSegmentsByLessonId joins content_items case-insensitively with trimmed refs`: Kiểm tra truy vấn lấy segments khớp thành công `content_payload` từ `content_items` khi `content_ref_id` có chữ hoa/thường hoặc khoảng trắng, đồng thời xử lý an toàn giá trị `null`.

---

## 3. Quá Trình Thực Hiện TDD & Kết Quả Kiểm Thử

1. **Giai đoạn RED (Thất bại trước khi sửa đổi)**:
   - Viết test `test/features/content_packs/pack_upgrade_integrity_test.dart`.
   - Kết quả: Cả 3 test đều thất bại chính xác theo đúng giả thuyết:
     - Test 1: `Expected: true, Actual: <false>` (do logic cũ chỉ đếm `lessons`).
     - Test 2: `Expected: throws <Instance of 'StateError'>, Actual: returned a Future that emitted <null>` (do logic cũ không kiểm tra `segments`).
     - Test 3: `Expected: not null, Actual: <null>` (do SQL JOIN phân biệt hoa thường và không trim).

2. **Giai đoạn GREEN (Vượt qua sau khi triển khai)**:
   - Triển khai logic nâng cấp trong `app_startup_provider.dart` và `curriculum_dao.dart`.
   - Chạy kiểm thử:
     ```bash
     cd C:\Users\phama\Downloads\hi_chinese; flutter test test/features/content_packs/pack_upgrade_integrity_test.dart
     ```
     **Kết quả**: `00:01 +3: All tests passed!`

3. **Giai đoạn REGRESSION CHECK (Kiểm tra tương thích ngược)**:
   - Chạy toàn bộ 7 integration tests của quy trình startup:
     ```bash
     cd C:\Users\phama\Downloads\hi_chinese; flutter test test/core/startup/app_startup_integration_test.dart
     ```
     **Kết quả**: `00:24 +7: All tests passed!`

---

## 4. Kết Luận
Task 3 đã giải quyết hoàn toàn vấn đề phát hiện và tự động nạp lại học liệu bị thiếu khi ứng dụng nâng cấp hoặc xảy ra sự cố nạp gián đoạn trong phiên bản cũ, đồng thời tăng cường khả năng chống lỗi (fault tolerance) cho toàn bộ truy vấn dữ liệu học liệu của giáo trình.
