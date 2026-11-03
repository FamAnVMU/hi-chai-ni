# HI CHINESE – REAL PRONUNCIATION, LISTENING & HSK EXIT EXAM IMPLEMENTATION

## 1. Executive Summary & Problem Scope

Trong quá trình đánh giá và hoàn thiện nền tảng học tiếng Trung HI Chinese, ba module học tập trọng yếu gồm **Phân tích phát âm (Pronunciation Analysis)**, **Luyện nghe hiểu (Listening Comprehension)** và **Đề thi tốt nghiệp cấp độ (HSK Level Exit Exam)** xuất hiện tình trạng sử dụng dữ liệu mô phỏng, điểm số giả lập và các luồng điều khiển chưa liên kết với phần cứng hoặc cơ sở dữ liệu thực tế:

1. **Phân tích phát âm (`pronunciation_analysis_service.dart`)**:
   - Sử dụng chuỗi transcript mô phỏng (`final recognizedText = target.text`), luôn nhận dạng trùng khớp 100% dù người học nói gì hoặc file âm thanh rỗng.
   - Trả về điểm số gán cứng (`0.85`, `0.92`, `0.95`).
   - Tự nhận có bộ phân tích cao độ âm học và chấm điểm thanh điệu (`toneAccuracy: 0.92`), vi phạm nguyên tắc liêm chính học thuật (Academic Honesty).
2. **Luyện nghe hiểu (`listening_screen.dart`, `listening_providers.dart`)**:
   - Nút lùi 5 giây (`Icons.replay_5_rounded`) để callback rỗng (`onPressed: () {}`).
   - Thanh trượt thời gian `Slider` gán cứng `value: 0.0` và `onChanged: (_) {}`.
   - Nút Play/Pause chỉ lật cờ boolean `isPlaying` trong state mà không phát âm thanh qua loa hay native audio hardware.
   - Chưa xử lý trạng thái buffer, tua audio hoặc lỗi tệp không tồn tại.
3. **Đề thi tốt nghiệp HSK (`level_exit_exam_screen.dart`)**:
   - Chứa 4 câu hỏi mẫu cố định (`exam_l1`, `exam_l2`, `exam_r1`, `exam_r2`).
   - Bỏ qua kho dữ liệu đề thi 40 câu chính thức (20 câu Nghe có audio URI + 20 câu Đọc) đã đóng gói trong Content Pack và SQLite `level_exit_exams`.
   - Không hỗ trợ nút nghe audio cho các câu hỏi phần thi Nghe.
4. **Đồng bộ tiến độ học tập và mở khóa lộ trình**:
   - Nộp bài thi tốt nghiệp chỉ tính điểm trong bộ nhớ RAM cục bộ, không lưu vào cơ sở dữ liệu (`curriculum_mastery`, `learning_activities`, `learner_evidence`).
   - Không kích hoạt mở khóa cấp độ kế tiếp (`PlacementUnlockHandler`) khi đạt chuẩn đầu ra ($\ge 120/200$).

---

## 2. Chi tiết các giải pháp kỹ thuật đã triển khai

### 2.1 Nhiệm vụ A – Chuẩn hóa Pronunciation Analysis Service (`DefaultPronunciationAnalysisService`)

Loại bỏ toàn bộ mã giả lập, triển khai quy trình thẩm định âm thanh thực nghiệm và tuân thủ tuyệt đối nguyên tắc liêm chính học thuật:

```
[Microphone Audio] -> [Kiểm tra thời lượng >= 300ms]
                   -> [Kiểm tra tệp tồn tại & Dung lượng >= 300 bytes]
                   -> [Kiểm tra thời lượng <= 30s]
                   -> [Đã cấu hình AiProvider STT?]
                         |-- Có -> Gửi payload Audio Multimodal Base64
                         |         -> Nhận diện chữ Hán ASR
                         |         -> So khớp ký tự với target.text
                         |         -> toneAccuracy: null (Trung thực: Không giả vờ đo F0)
                         |-- Không -> Trả status: unsupported, score: null
                                     (Bảo toàn file ghi âm để người học tự nghe lại)
```

1. **Thẩm định tệp âm thanh thực tế**:
   - Nếu `audioPath.isEmpty` hoặc `!File(audioPath).existsSync()`: trả về `status: PronunciationEvaluationStatus.failed`, `overallScore: null`.
   - Nếu `duration.inMilliseconds < 300` hoặc dung lượng tệp $< 300$ bytes: trả về `status: PronunciationEvaluationStatus.insufficientAudio`, `overallScore: 0.0` kèm hướng dẫn nói rõ ràng tối thiểu 0.5 giây.
   - Nếu thời lượng $> 30$ giây: từ chối xử lý quá tải, yêu cầu phát âm ngắn gọn.
2. **Tích hợp Cloud Speech Recognition (ASR)**:
   - Kết nối với `AiProvider` (Gemini API) thông qua `AiPromptRequest` với payload `AiContent.userMultimodal` chứa Base64 audio và MIME type (`audio/m4a` / `audio/aac`).
   - Thu nhận transcript thực tế từ giọng nói người học, đo độ tương đồng ký tự (`_calculateTranscriptSimilarity`) so với chữ Hán mục tiêu.
   - Xử lý timeout (`TimeoutException`, 12 giây) và lỗi mạng mà không làm crash ứng dụng.
3. **Liêm chính học thuật (Academic Honesty)**:
   - Tuyệt đối không sinh điểm thanh điệu giả tạo (`toneAccuracy = null`) khi chỉ có công nghệ STT nhận diện văn bản.
   - Ghi chú rõ ràng trong `feedbackList`: hệ thống nhận diện từ vựng qua STT và chưa tích hợp bộ cảm biến cao độ âm học $F_0$.
   - Khi ở chế độ ngoại tuyến (Offline): trả về `status: PronunciationEvaluationStatus.unsupported`, `overallScore = null`, bảo lưu file âm thanh tại chỗ để người học tự nghe lại và đối chiếu với phát âm mẫu.

---

### 2.2 Nhiệm vụ B – Hiện thực hóa Audio Player & Điều khiển Luyện Nghe (`ListeningPlaybackNotifier` & `ListeningScreen`)

Kết nối trực tiếp `ListeningPlaybackNotifier` với `AudioPlayerService` (`DefaultAudioPlayerService` chạy trên `just_audio`):

1. **Nút tua lùi 5 giây (`rewind5Seconds`)**:
   - Lấy mốc thời gian hiện tại: $\text{targetMs} = \text{currentMs} - 5000$.
   - Giới hạn cận dưới an toàn: `targetMs.clamp(0, totalMs)`. Nếu audio đang phát ở giây thứ 2, tua về chính xác `00:00`, không bao giờ bị âm thời gian.
   - Nếu audio đã phát xong (`status == AudioPlaybackStatus.completed`), tự động tua lùi 5 giây tính từ cuối bài học ($\text{totalMs} - 5000$).
2. **Thanh trượt thời gian (`Slider`) & Đồng hồ hiển thị**:
   - Lắng nghe luồng `positionStream` và `statusStream` phát ra từ native audio hardware.
   - Tính toán tỉ lệ trượt mượt mà: `sliderValue = (currentMs / totalMs).clamp(0.0, 1.0)`.
   - Hỗ trợ sự kiện kéo thả `onChanged`: tua ngay lập tức đến vị trí mili-giây tương ứng thông qua `_player.seek(Duration(milliseconds: targetMs))`.
   - Hiển thị thời gian định dạng chuẩn `mm:ss` cho cả thời gian hiện tại và tổng thời lượng bài nghe.
3. **Điều chỉnh tốc độ phát (`0.8x`, `1.0x`, `1.2x`)**:
   - Chuyển tiếp tốc độ được chọn trực tiếp vào hardware player: `_player.setPlaybackSpeed(speed)`.
4. **Chuẩn hóa URI và bảo toàn tài nguyên**:
   - Tự động chuẩn hóa các tiền tố URI `asset:///` và `asset://` về dạng chuẩn Flutter asset `assets/...` trong `DefaultAudioPlayerService`.
   - Xử lý buffering (hiển thị `CircularProgressIndicator` trên nút Play).
   - Tự động dừng và giải phóng player trong `dispose()` khi người học rời màn hình.

---

### 2.3 Nhiệm vụ C & D – Đề thi tốt nghiệp HSK thực tế & Đồng bộ dữ liệu tiến độ (`LevelExitExamScreen` & `CurriculumRepository`)

1. **Loại bỏ hoàn toàn 4 câu hỏi giả lập**:
   - Triệt tiêu hoàn toàn mảng mock 4 câu (`exam_l1`, `exam_l2`, `exam_r1`, `exam_r2`).
   - Tải đề thi chuẩn 40 câu (20 câu Nghe + 20 câu Đọc) từ Content Pack HSK 1 (`hsk1_pack_v1.json`) hoặc bảng cơ sở dữ liệu `level_exit_exams`.
   - Nếu kho dữ liệu rỗng: hiển thị trạng thái Honest Empty State (*"Chưa có dữ liệu đề thi tốt nghiệp cho HSK X. Vui lòng tải hoặc cập nhật Content Pack."*), số lượng câu hỏi = 0, vô hiệu hóa nút nộp bài.
2. **Trải nghiệm phần thi Nghe tương tác**:
   - Mỗi câu hỏi Listening có nút **"Nghe audio câu hỏi"** kết nối với `AudioPlayerService`, cho phép người học bấm nghe phát âm từ vựng tương ứng (ví dụ: `assets/audio/hsk1/请.mp3`) và bấm dừng bất cứ lúc nào.
3. **Chấm điểm theo tiêu chuẩn quốc tế HSK**:
   - Thang điểm phần Nghe: 100 điểm.
   - Thang điểm phần Đọc: 100 điểm.
   - Tổng điểm: 200 điểm. Điểm chuẩn đạt (Pass): $\ge 120$ điểm (tỉ lệ $60\%$).
4. **Đồng bộ giao dịch nguyên tử vào SQLite (`recordExitExamSubmission`)**:
   - `curriculum_mastery`: Ghi nhận bản ghi `item_id: 'exit_exam_hsk$level'`, `item_type: 'exit_exam'`, `mastery_state: isPassed ? 'mastered' : 'failed'`, điểm số và lịch ôn tập định kỳ.
   - `learning_activities`: Ghi nhận hoạt động hoàn thành bài thi với thời lượng thực tế và số lượng câu đã làm để nuôi dưỡng chuỗi học tập hàng ngày (`streak`) trên Trang Chủ.
   - `learner_evidence`: Lưu bằng chứng học tập có chữ ký thời gian và metadata JSON chi tiết.
   - **Mở khóa cấp độ tiếp theo**: Nếu người học thi đỗ ($\ge 120/200$), tự động gọi `PlacementUnlockHandler.unlockForRecommendedLevel(level + 1)` để hoàn tất level hiện tại và mở khóa bài học số 1 của level kế tiếp.
5. **Màn hình tổng kết và giải thích chi tiết**:
   - Hiển thị bảng điểm phân tách rõ ràng (Nghe / 100, Đọc / 100, Tổng / 200).
   - Danh sách chi tiết toàn bộ 40 câu hỏi: hiển thị đáp án người học đã chọn, dấu tích xanh (đúng) hoặc chữ X đỏ (sai), đáp án chính xác và lời giải thích chi tiết (`explanation`).

---

## 3. Bảng tổng hợp các tệp đã sửa đổi & bổ sung

| Tệp tin | Trạng thái | Nội dung chính |
| :--- | :--- | :--- |
| `lib/features/pronunciation/domain/models/pronunciation_models.dart` | Sửa đổi | Bổ sung enum `PronunciationEvaluationStatus` (`success`, `failed`, `unsupported`, `insufficientAudio`) |
| `lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart` | Sửa đổi | Loại bỏ điểm mock `0.85/0.92`, kiểm tra tệp/dung lượng/thời lượng, tích hợp Cloud ASR trung thực |
| `lib/core/audio/audio_player_service.dart` | Sửa đổi | Chuẩn hóa tiền tố `asset:///` và `asset://` thành `assets/` |
| `lib/features/listening/presentation/providers/listening_providers.dart` | Sửa đổi | Kết nối `ListeningPlaybackNotifier` với `AudioPlayerService`, hỗ trợ tua 5s, seek, tốc độ, buffer |
| `lib/features/listening/presentation/screens/listening_screen.dart` | Sửa đổi | Nối nút `replay_5`, Slider thực, play/pause với spinner buffer, hiển thị lỗi file |
| `lib/features/curriculum/data/curriculum_repository.dart` | Sửa đổi | Bổ sung hàm `recordExitExamSubmission` với SQLite transaction (`mastery`, `activities`, `evidence`, `unlock`) |
| `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart` | Viết lại | Loại bỏ 4 câu mock, tải 40 câu thật, phát audio câu nghe, chấm thang 200, review câu hỏi chi tiết |
| `test/features/pronunciation/pronunciation_analysis_test.dart` | Sửa đổi | Cập nhật bộ test đánh giá phát âm thực tế: file rỗng, offline, timeout, độ chính xác transcript |
| `test/features/pronunciation/pronunciation_lab_widget_test.dart` | Sửa đổi | Đăng ký mock audio hardware platform channel cho luồng thu âm widget |
| `test/features/listening/real_listening_playback_test.dart` | Tạo mới | Unit test kiểm thử tua lùi 5s, kẹp mốc 0:00, tua sau khi kết thúc, kéo slider, đổi tốc độ |
| `test/features/curriculum/real_level_exit_exam_test.dart` | Tạo mới | Integration test tải đề 40 câu, empty state, ghi nhận cơ sở dữ liệu và mở khóa cấp độ kế tiếp |

---

## 4. Kết quả kiểm thử thực nghiệm

Toàn bộ các test suite thuộc các phân hệ Pronunciation, Listening, và Curriculum đều vượt qua 100%:

```
$ flutter test test/features/pronunciation/ test/features/listening/ test/features/curriculum/curriculum_ui_widget_test.dart test/features/curriculum/real_level_exit_exam_test.dart

00:25 +33: All tests passed!
```

Phân tích tĩnh (`dart analyze`):
```
$ dart analyze lib/features/pronunciation lib/features/listening lib/features/curriculum test/features/pronunciation test/features/listening test/features/curriculum
Analyzing pronunciation, listening, curriculum, pronunciation, listening, curriculum...
No issues found!
```
Zero errors, zero warnings.
