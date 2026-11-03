# HI CHINESE – BÁO CÁO VÁ LỖI DỮ LIỆU DASHBOARD TRANG CHỦ, KHỬ CỘNG TRÙNG THỜI GIAN HỌC & ĐỒNG BỘ THỐNG KÊ SRS THEO HSK

**Mã tài liệu:** `F11_HOME_REPOSITORY_STATISTICS`  
**Ngày thực hiện:** 03/11/2026  
**Vai trò:** Senior Flutter Engineer & Data Analytics Engineer  
**Phạm vi:** `lib/features/home/data/home_repository.dart`, `lib/features/home/domain/models/`, `lib/features/vocabulary_srs/`, `lib/features/profile/`

---

## 1. TỔNG QUAN HIỆN TRẠNG & NGUYÊN NHÂN LỖI

Trước khi thực hiện bản vá, trang chủ (`HomeScreen` & `HomeRepository`) tồn tại 3 khiếm khuyết dữ liệu nghiêm trọng:

| Mã lỗi | Mô tả hiện trạng | Nguyên nhân kỹ thuật | Hậu quả |
| :--- | :--- | :--- | :--- |
| **Lỗi A** | Tên người học bị hardcode `'Học viên'` | `HomeRepository.getDashboardData()` trả về `learnerName: 'Học viên'` cố định, không truy vấn `user_profiles` hay `app_settings`. | Người dùng dù đã đổi tên thành "Minh", "Phạm An" thì trang chủ vẫn chào "Chào buổi sáng! ☀️, Học viên". |
| **Lỗi B** | Thời gian học bị cộng gấp đôi (Double-Counting) | `calculateStreak()` duyệt cả 2 bảng `learner_evidence` (cộng `duration_ms`) và `learning_activities` (cộng `duration_seconds`). Hầu hết các tính năng (Lesson, SRS, Practice, Shadowing) đều ghi vào cả 2 bảng cho cùng một phiên học. | Học 15 phút bị ghi nhận thành 30 phút; số mục học bị nhân đôi; số liệu thống kê sai lệch nghiêm trọng. |
| **Lỗi C** | SRS không lọc theo cấp độ HSK đang học | `SrsRepository.getDueCardsCount()` chỉ đếm theo `content_type` mà không `JOIN` với `vocabularies.hsk_level`. | Người học HSK 1 nhưng dashboard hiển thị gộp cả thẻ HSK 2, 3... đến hạn; số đếm trên trang chủ lệch với hàng đợi ôn tập thực tế. |

---

## 2. GIẢI PHÁP KIẾN TRÚC & TRIỂN KHAI CHI TIẾT

### 2.1. Lỗi A – Truy xuất tên người học động & Fallback đa tầng

Xây dựng phương thức `getLearnerDisplayName()` trong `HomeRepository` với thứ tự ưu tiên:
1. **Nguồn 1 – `tableUserProfiles`**:
   - Truy vấn `SELECT display_name FROM user_profiles ORDER BY updated_at DESC LIMIT 1`.
   - Cắt tỉa khoảng trắng thừa (`trim()`).
   - Nếu chuỗi rỗng (`''`), chỉ chứa khoảng trắng (`'   '`) hoặc `null`, tự động chuyển sang tầng kế tiếp.
2. **Nguồn 2 – `tableAppSettings`**:
   - Truy vấn các khóa cài đặt người dùng: `display_name`, `user_name`, `profile_name`, `learner_name`.
   - Cắt tỉa khoảng trắng thừa và lấy giá trị hợp lệ đầu tiên.
3. **Nguồn 3 – Fallback an toàn**:
   - Trả về `'Học viên'` duy nhất khi cả hai bảng đều không có dữ liệu người dùng.
4. **Phản ứng Realtime (Reactive Updates)**:
   - Trong `HomeDashboardNotifier`, theo dõi `ref.watch(userProfileProvider)`.
   - Trong `EditProfileSheet`, hỗ trợ chỉnh sửa `displayName` và lưu xuống SQLite. Ngay khi lưu, `userProfileProvider` phát sinh trạng thái mới, `HomeDashboardNotifier` tự động build lại và cập nhật tên người học ngay lập tức mà không cần khởi động lại ứng dụng.

---

### 2.2. Lỗi B – Khử cộng trùng thời gian học, Lọc bất thường & Thống kê đa chu kỳ

#### A. Phân định vai trò hai bảng dữ liệu
- **`learning_activities` (Canonical Primary Source)**: Nguồn chuẩn duy nhất đại diện cho các phiên học hoàn chỉnh (`lesson`, `srs_review`, `ai_tutor`, `practice`, `hanzi_writing`, `shadowing`, `reading`). Cung cấp `duration_seconds` và `items_count` của từng phiên.
- **`learner_evidence` (Granular Audit & Micro-interaction Source)**: Nguồn bằng chứng chi tiết của từng lượt tương tác nhỏ (từng thẻ từ vựng, từng câu hỏi, từng đoạn thu âm phát âm) nhằm phục vụ Bayesian Knowledge Tracing và SM-2 history.

#### B. Cơ chế Deduplication phi trùng lặp
- Lấy toàn bộ các phiên học từ `learning_activities`. Mỗi phiên $S_i$ có mốc thời gian $T_i$ và thời lượng $D_i$.
- Cửa sổ thời gian hoạt động của phiên $S_i$ là:
  $$[T_i - D_i - 30\text{s},\; T_i + 30\text{s}]$$
- Khi duyệt `learner_evidence`, bất kỳ bản ghi bằng chứng nào có mốc thời gian rơi vào cửa sổ hoạt động của một phiên `learning_activities` trong cùng ngày cục bộ sẽ được đánh dấu là **Enclosed (thuộc về phiên đó)** và **KHÔNG cộng dồn thời lượng** vào tổng thời gian học nữa.
- Chỉ những bản ghi `learner_evidence` đơn lẻ mồ côi (Orphan / Standalone evidence) không có phiên cha `learning_activities` bao bọc mới được tính bổ sung.

#### C. Lọc dữ liệu dị thường (Anomaly Sanitization)
- **Thời lượng âm**: Ép về $0$ (`rawSec.clamp(0, maxSessionDurationSeconds)`).
- **Thời lượng bất thường (> 4 giờ)**: Trường hợp người dùng treo máy hoặc tiến trình nền không tắt, thời lượng phiên được chặn trên tại $14.400$ giây ($4$ giờ / $240$ phút).
- **Trùng lặp Sync / Retry**: Các bản ghi trùng lặp loại hoạt động, thời lượng, số mục hoàn thành trong cửa sổ $2$ giây (tính theo `epochBucket`) được tự động gom nhóm và loại trừ.

#### D. Tính toán đúng các chỉ số thời gian học
Tạo model bất biến `StudyTimeStats` và phương thức `getStudyTimeStats()`:
- **Thời gian hôm nay (`todayDurationSeconds`)**: Tổng thời gian học hợp lệ trong ngày lịch hiện tại (tính theo múi giờ địa phương `todayLocal`).
- **Thời gian tuần này (`weekDurationSeconds`)**: Tổng thời gian học từ thứ Hai đầu tuần (`todayLocal.subtract(Duration(days: todayLocal.weekday - 1))`) đến thời điểm hiện tại.
- **Tổng thời gian học (`totalDurationSeconds`)**: Tổng tích lũy toàn bộ thời gian học hợp lệ từ trước đến nay.
- **Streak ngày học (`LearningStreak`)**: Đồng bộ sử dụng `todayDurationSeconds` và `todayItemsCompleted` đã khử trùng, tránh mọi mâu thuẫn giữa các widget.

---

### 2.3. Lỗi C – Thống kê SRS có điều kiện theo cấp độ HSK hiện tại

#### A. Mở rộng `SrsRepository.getDueCardsCount`
Bổ sung tham số `int? hskLevel`:
```sql
SELECT COUNT(DISTINCT s.id) as count 
FROM srs_items s
INNER JOIN vocabularies v ON (s.content_id = v.id OR s.content_id = v.simplified)
WHERE s.content_type = 'vocabulary' 
  AND s.due_at <= ? 
  AND s.deleted_at IS NULL 
  AND v.deleted_at IS NULL 
  AND v.hsk_level = ?
```
- Khi `hskLevel != null`: `INNER JOIN` với bảng `vocabularies`, loại bỏ hoàn toàn các thẻ thuộc cấp độ HSK khác, thẻ không gắn HSK, hoặc thẻ có `due_at` trong tương lai.
- Khi `hskLevel == null`: Đếm toàn bộ thẻ từ vựng đến hạn (dùng cho tổng quan hệ thống nếu cần).
- Bộ nhớ đệm TTL trong RAM được phân tách theo khóa `'$contentType:${hskLevel ?? "all"}'`.

#### B. Đồng bộ hiển thị và Hàng đợi ôn tập
- `HomeRepository.getCurrentHskLevel()`: Lấy cấp độ HSK đang học từ `user_profiles.current_hsk_level`, fallback qua `app_settings.current_hsk_level`, mặc định cấp 1.
- `HomeRepository.getDashboardData()`: Truyền `activeHskLevel` vào `_srsRepository.getDueCardsCount(hskLevel: activeHskLevel, ...)` và `getRoadmapProgress(hskLevel: activeHskLevel)`.
- `SrsDueCountNotifier`: Đọc `userProfileProvider.value?.currentHskLevel`.
- `SrsStudySessionNotifier`: Khởi tạo hàng đợi flashcard bằng `repo.getDueFlashcards(limit: 25, hskLevel: profile?.currentHskLevel)`.
- `EditProfileSheet`: Bổ sung bộ chọn cấp độ HSK đang học (HSK 1 - 6) trực quan cho học viên. Khi người học chuyển đổi cấp độ HSK, cả thẻ đếm trên Trang chủ, huy hiệu trên thanh Review, và danh sách flashcard ôn tập đều đồng bộ 100%.

---

## 3. CÁC TẬP TIN THAY ĐỔI

| Tập tin | Loại thay đổi | Chi tiết |
| :--- | :--- | :--- |
| `lib/features/home/data/home_repository.dart` | Refactor & Fix | Triển khai `getLearnerDisplayName()`, `getCurrentHskLevel()`, `getSanitizedStudySessionsAndStats()`, khử cộng trùng thời gian, lọc bất thường, truyền `activeHskLevel` vào SRS count. |
| `lib/features/home/domain/models/home_dashboard_data.dart` | Enhancement | Bổ sung class `StudyTimeStats` và trường `studyStats` trong `HomeDashboardData`. |
| `lib/features/home/presentation/providers/home_providers.dart` | Refactor | `HomeDashboardNotifier` lắng nghe `userProfileProvider`, truyền động tên và cấp độ HSK. |
| `lib/features/vocabulary_srs/data/srs_repository.dart` | Enhancement | Bổ sung `int? hskLevel` vào `getDueCardsCount()` với câu truy vấn `INNER JOIN vocabularies`. |
| `lib/features/vocabulary_srs/presentation/providers/srs_providers.dart` | Enhancement | `SrsDueCountNotifier` và `SrsStudySessionNotifier` lọc theo `profile?.currentHskLevel`. |
| `lib/features/profile/presentation/widgets/edit_profile_sheet.dart` | UI Feature | Thêm bộ chọn `Cấp độ HSK đang học` (HSK 1–6) và lưu `currentHskLevel`. |
| `lib/features/profile/presentation/screens/profile_screen.dart` | Fix | Truyền `currentHskLevel` khi cập nhật hồ sơ trong `onSave`. |
| `test/features/home/home_repository_statistics_test.dart` | New Test Suite | Bộ test tích hợp SQLite hoàn chỉnh gồm 12 bài kiểm tra cho 3 nhóm lỗi A, B, C. |

---

## 4. KẾT QUẢ KIỂM THỬ & MINH CHỨNG XÁC THỰC

### 4.1. Kiểm thử tĩnh (Static Analysis)
```bash
dart analyze lib test
```
**Kết quả:** `Analyzing lib, test... No issues found!` (0 cảnh báo, 0 lỗi).

### 4.2. Kiểm thử đơn vị & Tích hợp (Unit & Integration Tests)
```bash
flutter test test/features/home/
```
**Kết quả:**
- `test/features/home/home_repository_statistics_test.dart`: 12/12 tests PASSED.
  - Lỗi A: Lấy đúng tên từ `user_profiles`, cắt tỉa khoảng trắng, fallback qua `app_settings`, fallback về `'Học viên'`, cập nhật động khi sửa hồ sơ.
  - Lỗi B: Phiên học đồng thời trong 2 bảng được đếm đúng 1 lần (900s, không bị nhân đôi lên 1800s), bằng chứng mồ côi được tính, thời lượng âm bị ép về 0, thời lượng > 4h bị chặn tại 14.400s, bản ghi trùng lặp do sync được khử, tính đúng ngày / tuần / tổng.
  - Lỗi C: Đếm chính xác thẻ HSK 1 đến hạn, loại trừ thẻ HSK 2, loại trừ thẻ chưa đến hạn, loại trừ thẻ mồ côi không gắn HSK, cập nhật tức thì khi chuyển cấp độ HSK.
- `test/features/home/home_repository_test.dart`: 7/7 tests PASSED.
- `test/features/home/home_screen_widget_test.dart`: 7/7 tests PASSED.
- `test/features/vocabulary_srs/` & `test/features/profile/`: 31/31 tests PASSED.
- **Tổng cộng 57/57 tests PASS tuyệt đối.**
