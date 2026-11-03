# HI CHINESE – BÁO CÁO KỸ THUẬT VÁ LỖI F-20
## Thay Thế Mock Learning UI, Sửa Audio Playback Thực Tế & Bổ Sung Accessibility (Semantics)

- **Mã lỗi**: `F-20` (Mock Learning UI, Fake Audio Playback & Missing Canvas Accessibility)
- **Mức độ nghiêm trọng**: High (User Experience, Educational Integrity & Accessibility Compliance)
- **Tác giả**: Senior Flutter UI Engineer & Senior Accessibility Engineer
- **Kho mã nguồn**: `https://github.com/FamAnVMU/hi-chai-ni.git` (Branch: `main`)
- **Ngày hoàn thành**: 03/11/2026

---

## 1. Tổng quan vấn đề & Hiện trạng trước khi sửa

1. **LearningScreen (`learning_screen.dart`)**:
   - Khai báo cứng các chương tĩnh (Chương 1, Chương 2) và 4 thẻ bài học mẫu.
   - Các chỉ số tiến độ bị gán cứng (`60%`, `1.0`, `0.0`) không phản ánh dữ liệu database.
   - Thao tác chạm vào bài học chỉ hiển thị SnackBar giả (`HiSnackBar.showInfo`) mà không điều hướng vào bài học thực tế.
2. **LessonVocabView (`lesson_vocab_view.dart`)**:
   - Nút loa phát âm từ vựng chỉ bật `ScaffoldMessenger.showSnackBar` thông báo văn bản mô phỏng, hoàn toàn không phát bất kỳ âm thanh nào.
3. **FlashcardCard (`flashcard_card.dart`)**:
   - Nếu parent widget không truyền `onPlayAudio`, nút loa chỉ kích hoạt `HiSnackBar.showSuccess` hoặc `HiSnackBar.showInfo` giả lập mà không phát âm thanh hoặc gọi TTS.
4. **Canvas luyện viết chữ Hán (`hanzi_canvas.dart`)**:
   - Chỉ có nhãn Semantics chung chung, không cung cấp thông tin về chữ đang viết, số nét đã vẽ, nét chuẩn hay chế độ viết.
   - Người khiếm thị sử dụng TalkBack / Screen Reader không thể nắm bắt được tiến trình vẽ nét và thiếu các Custom Semantics Action để thao tác.

---

## 2. Chi tiết các giải pháp kỹ thuật đã triển khai

### 2.1. Nhiệm vụ A – Kết nối LearningScreen với Curriculum thật & Tính toán tiến độ
- Chuyển `LearningScreen` thành `ConsumerStatefulWidget`.
- Ánh xạ chip cấp độ (`HSK 1` .. `HSK 5`) sang canonical `curriculumId` (`curr_hsk1` .. `curr_hsk5`) qua `CurriculumConstants.curriculumIdForLevel`.
- Tạo provider `curriculumUnitsWithLessonsProvider(curriculumId)` và hàm `getUnitsWithLessons` trong `CurriculumRepository` nạp toàn bộ cấu trúc: Curriculum → Units → Lessons → Segments kèm điểm mastery từ bảng `curriculum_mastery`.
- **Tính toán tiến độ thực tế (Deterministic Progress Calculation)**:
  - Nếu `lesson.isLocked`: `progress = 0.0`, trạng thái `Chưa mở khóa` (`HiChipStatus.neutral`).
  - Nếu `status == completed || status == mastered`: `progress = 1.0`, trạng thái `Đã hoàn thành` (`HiChipStatus.success`).
  - Nếu `status == inProgress`: `progress = (masteryScore > 0 ? masteryScore : 0.5)`, trạng thái `Đang học (X%)` (`HiChipStatus.warning`).
  - Nếu `status == notStarted`: `progress = 0.0`, trạng thái `Chưa học` (`HiChipStatus.info`).
- **Xử lý 4 trạng thái giao diện**:
  - `loading`: Hiển thị `HiLoadingIndicator`.
  - `error`: Hiển thị thông báo lỗi chi tiết kèm nút `Thử lại` (`ref.invalidate`).
  - `empty`: Hiển thị card trạng thái rỗng `Chưa có học liệu cho HSK X` kèm nút `Mở kho học liệu HSK` dẫn tới `ContentPackManagerScreen`.
  - `data available`: Render danh sách chương và bài học thực tế.
- **Điều hướng học tập**:
  - Tạp vào bài mở khóa: Điều hướng đến `LessonStudyScreen(lesson: lesson)`.
  - Quay lại màn hình: Tự động invalidate provider để đồng bộ tiến độ học vừa hoàn thành.
  - Tạp vào bài bị khóa: Hiển thị SnackBar cảnh báo điều kiện tiên quyết (≥ 80%).

### 2.2. Nhiệm vụ B – Sửa nút phát âm trong LessonVocabView
- Chuyển `LessonVocabView` thành `StatefulWidget` quản lý `AudioPlayerService` và `TtsService`.
- **Quy trình phát âm 3 tầng**:
  1. **Audio gốc**: Kiểm tra `audio_uri` trong payload từ vựng (ví dụ `assets/audio/hsk1/你.mp3`). Nếu file tồn tại hoặc là asset hợp lệ, phát bằng `AudioPlayerService`.
  2. **TTS Fallback**: Nếu không có file audio hoặc `AudioPlayerService` gặp lỗi (file thiếu), tự động chuyển sang `TtsService` với locale `zh-CN`.
  3. **Không khả dụng**: Nếu cả 2 đều không khả dụng, hiển thị SnackBar cảnh báo thực tế `Chưa có file âm thanh hoặc giọng đọc tiếng Trung cho từ "..."`. Tuyệt đối không hiển thị thông báo thành công giả.
- Dừng mọi âm thanh trước khi phát từ mới để chống phát đè âm (no overlapping).
- Quản lý Timer highlight và giải phóng tài nguyên sạch sẽ trong `dispose()`.

### 2.3. Nhiệm vụ C – Sửa nút phát âm trong FlashcardCard
- Bổ sung `AudioPlayerService` và `TtsService` tích hợp sẵn trong `FlashcardCardState`.
- Nếu widget cha truyền `onPlayAudio`, ủy quyền cho callback của widget cha.
- Nếu `onPlayAudio` là null:
  - Tự động phát `card.audioUri` bằng `AudioPlayerService`.
  - Nếu không có audio gốc hoặc phát thất bại, fallback sang `_ttsService.speak(card.simplified, language: 'zh-CN')`.
  - Dừng phát ngay lập tức khi lật thẻ hoặc chuyển thẻ (`didUpdateWidget` & `dispose`).
  - Nếu không thể phát, hiển thị cảnh báo, không báo thành công giả.

### 2.4. Nhiệm vụ D – Bổ sung Semantics cho Canvas luyện viết chữ Hán
- Bao bọc `HanziCanvas` trong `AnimatedBuilder(animation: controller)` kết hợp với `Semantics`:
  - **`label`**: `'Khung lưới tập viết chữ Hán ${character}.'`
  - **`value`**: Cung cấp thông tin chữ, pinyin, chế độ viết (`Tô mẫu` / `Tự viết`), số nét đã viết trên tổng số nét chuẩn (`Đã viết X nét trên tổng số Y nét chuẩn`). Cập nhật theo thời gian thực mỗi khi người dùng vẽ hoặc xóa nét.
  - **`hint`**: Hướng dẫn thao tác chạm/rê vẽ hoặc sử dụng các hành động trợ năng thay thế.
  - **`customSemanticsActions`**:
    - `CustomSemanticsAction(label: 'Xóa toàn bộ nét')`: Gọi `controller.reset()`.
    - `CustomSemanticsAction(label: 'Hoàn tác nét vừa vẽ')`: Gọi `controller.undo()`.
    - `CustomSemanticsAction(label: 'Xem mẫu nét tiếp theo')`: Gọi `onStepReplay()`.
- Giữ nguyên cử chỉ chạm cảm ứng đa điểm (`onPointerDown`, `onPointerMove`, `onPointerUp`) không gây xung đột với người dùng bình thường.

---

## 3. Ma trận kiểm thử & Kết quả nghiệm thu (Test Matrix)

### 3.1. Các bộ kiểm thử mới tạo:
1. [`test/features/learning/learning_screen_test.dart`](file:///C:/Users/phama/Downloads/hi_chinese/test/features/learning/learning_screen_test.dart) (5 ca kiểm thử):
   - Render bài học và chương thật, không có mock chapters.
   - Tính toán đúng tiến độ 100%, 65%, 0% từ database.
   - Tapping locked lesson hiển thị cảnh báo tiên quyết.
   - Tapping unlocked lesson chuyển sang `LessonStudyScreen`.
   - Empty state và Error state hoạt động chuẩn mực.
2. [`test/features/curriculum/lesson_vocab_audio_test.dart`](file:///C:/Users/phama/Downloads/hi_chinese/test/features/curriculum/lesson_vocab_audio_test.dart) (4 ca kiểm thử):
   - Từ có `audio_uri` phát trực tiếp qua `AudioPlayerService`.
   - Từ không có audio tự động fallback sang `TtsService`.
   - Từ có audio bị lỗi file tự động fallback sang `TtsService`.
   - Khi cả hai không khả dụng, hiển thị cảnh báo trung thực.
3. [`test/features/vocabulary_srs/flashcard_card_audio_test.dart`](file:///C:/Users/phama/Downloads/hi_chinese/test/features/vocabulary_srs/flashcard_card_audio_test.dart) (4 ca kiểm thử):
   - Callback của parent widget được ưu tiên cao nhất.
   - Fallback tự động phát `card.audioUri`.
   - Fallback tự động gọi `TtsService` khi thiếu audio.
   - Cảnh báo khi thiếu nguồn âm thanh, không báo thành công giả.
4. [`test/features/hanzi_writing/hanzi_canvas_semantics_test.dart`](file:///C:/Users/phama/Downloads/hi_chinese/test/features/hanzi_writing/hanzi_canvas_semantics_test.dart) (3 ca kiểm thử):
   - Xuất khẩu đầy đủ nhãn, giá trị và gợi ý Semantics cho TalkBack.
   - Cập nhật số nét động theo thời gian thực trên Accessibility Tree.
   - Kích hoạt thành công 3 Custom Accessibility Actions (Reset, Undo, Step Replay).

### 3.2. Kết quả chạy kiểm thử toàn hệ thống:
- Các bộ test F-20: **16/16 passed (100%)**.
- Toàn bộ các module liên quan (`learning`, `curriculum`, `vocabulary_srs`, `hanzi_writing`, `home`): **122/122 passed (100%)**.
- Phân tích tĩnh (`dart analyze lib test`): **No issues found (0 warnings, 0 errors)**.

---

## 4. Những chức năng chưa được hỗ trợ & Giới hạn kỹ thuật
- **Vẽ trực tiếp bằng TalkBack**: Người dùng khiếm thị hoàn toàn không thể vẽ các đường cong chữ Hán chính xác qua cử chỉ màn hình của TalkBack; ứng dụng cung cấp các hành động thay thế (xem mẫu nét, đọc tên nét, pinyin, nghe phát âm) để đảm bảo tính tiếp cận.
- **Giọng đọc địa phương / tiếng phổ thông nâng cao**: `DefaultTtsService` sử dụng engine TTS mặc định của hệ điều hành; nếu thiết bị người dùng chưa cài đặt voice data tiếng Trung (`zh-CN`), hệ thống sẽ thông báo rõ ràng để người dùng tải gói ngôn ngữ trong Cài đặt hệ điều hành.
