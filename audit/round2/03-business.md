# AUDIT ROUND 2 — BUSINESS LOGIC & EDGE CASES (03-business)

- **Repo:** `C:\Users\phama\Downloads\hi_chinese` (Flutter/Dart HSK app, 348 files / ~64k dòng trong `lib`).
- **Phạm vi:** curriculum (mastery/prerequisite/level_exit_exam/content pack), placement_test (CAT engine/blueprint/result), vocabulary_srs + core/knowledge (SM-2, due queue, identity), review, roadmap (engine/repository), practice (scoring/validator), grammar (evaluation), reading, listening, pronunciation, shadowing, hanzi*/hanzi_writing, pinyin_foundation, sentences, onboarding providers, settings/domain, profile/domain.
- **Phương pháp:** đọc mã tĩnh tại chỗ, trace UI → provider → engine → repository/DB → giá trị hiển thị; mọi tuyên bố "không tồn tại/không được gọi" đều được chứng minh bằng grep trên `lib/`. KHÔNG chạy `flutter analyze/test/build/dart run` (theo phân công). KHÔNG sửa file nào ngoài báo cáo này.
- **Ngày:** 2026-11-05. Tổng: **18 findings** đã xác minh (1 Critical, 8 High, 8 Med, 1 Low).
- Ghi chú: audit cũ `audit/findings/03-business.md` đã được đối chiếu lại; các mục dưới đây phản ánh **code hiện tại**, có nêu rõ trường hợp đã được vá (xem mục "Đã kiểm tra — không phải lỗi").

---

### BIZ-01 [Critical] CAT placement test kết thúc ở 12 câu và chỉ chấm 3/6 kỹ năng, 3 kỹ năng còn lại luôn "Chưa đánh giá"

**Vị trí**
- `lib/features/placement_test/domain/engine/cat_engine.dart:195-217` (nhánh khi ngân hàng câu của kỹ năng bị cạn), đặc biệt dòng 198.
- `lib/features/placement_test/domain/engine/cat_item_bank.dart` (số câu theo kỹ năng: `VOCAB_005` dòng 72, `GRAM_004` dòng 151, `READ_003` dòng 200, `SPK_002` dòng 543).
- `lib/features/placement_test/domain/engine/cat_blueprint.dart:29-45` (`minTotalItems = 12`, `maxItemsPerSkill = 5`, `skillSequence` 6 kỹ năng).
- UI hứa 6 kỹ năng: `lib/features/placement_test/presentation/screens/placement_test_intro_screen.dart:309` (`... chỉ trong 12 - 20 câu.`), dòng 318 (`'6 Kỹ Năng Được Khảo Sát'`), `placement_test_flow_screen.dart:106` (`'Đang tổng hợp báo cáo đánh giá 6 kỹ năng...'`).

**Mã lỗi:** `BIZ-CAT-EARLY-COMPLETE`

**Nguyên nhân gốc rễ**
Khi kỹ năng hiện tại hết câu hỏi (`selectNextItem` trả `null`), engine tìm kỹ năng kế tiếp rồi dùng sai điều kiện dừng bài:

```dart
// cat_engine.dart:198
if (nextSkill == null || updatedResponses.length >= activeBlueprint.minTotalItems) {
  // -> generateAssessmentResult(...) complete test
```

`minTotalItems` là **sàn tối thiểu**, không phải điều kiện kết thúc. Vì thế chỉ cần số câu đã làm ≥ 12 là bài thi đóng, dù còn kỹ năng phía sau. Số câu trong bank: vocabulary 5, grammar 4, reading 3 (các kỹ năng sau: listening 8, writing 9, speaking 2).

**Kịch bản & hậu quả (deterministic)**
1. Vocabulary có 5 câu ⇒ làm hết 5, dừng do `skillItemCount >= maxItemsPerSkill` ⇒ tổng 5.
2. Grammar có 4 câu ⇒ hết bank ở câu thứ 4, tổng 9 < 12 ⇒ engine chuyển sang Reading (đúng).
3. Reading có 3 câu ⇒ hết bank ở tổng **12** ⇒ rơi vào nhánh dòng 198: `12 >= minTotalItems(12)` ⇒ **kết thúc bài**.
4. `listening`, `writing`, `speaking` **chưa từng được hỏi**, nên `generateAssessmentResult` gán `SkillScoreEstimate.unassessed` (cat_engine.dart:300-312). Kết quả: màn hình kết quả hiển thị "Chưa đánh giá" cho 3/6 kỹ năng; HSK khuyến nghị chỉ dựa trên 3 kỹ năng; `acousticSensitivityScore`/`pictographicIntuitionScore` luôn `null`; `shouldBypassPinyinFoundation` (cat_assessment_result.dart:178-184) không bao giờ dùng được accuracy của speaking/writing. Học viên yếu (sai 3 câu liên tiếp) lại được khảo sát nhiều kỹ năng hơn học viên khá — ngược mục tiêu "adaptive".

**Bản vá**
Thay `minTotalItems` bằng `maxTotalItems` trong nhánh đó và chỉ complete khi `nextSkill == null` hoặc đã đạt `maxTotalItems`; đồng thời thêm "top-up" các kỹ năng chưa đạt `minItemsPerSkill` trước khi complete. Bổ sung test cho kịch bản "trả lời đúng liên tục" để test phải đi đủ 6 kỹ năng (hoặc đạt `maxTotalItems`).

---

### BIZ-02 [High] Roadmap không có bất kỳ đường nào để hoàn thành bài học: callback `onComplete` là dead code

**Vị trí**
- `lib/features/roadmap/presentation/widgets/lesson_detail_sheet.dart:12`, `:31`, `:43` — khai báo/truyền `final ValueChanged<double> onComplete;` nhưng **không được gọi** ở bất kỳ đâu trong `build` (grep chỉ ra 4 dòng: field, 2 constructor, 1 truyền tham số).
- `lib/features/roadmap/presentation/screens/roadmap_screen.dart:546-551` — callback `onComplete: (score) async { ... completeLesson(...) }` được truyền vào nhưng không bao giờ chạy.
- `lib/features/roadmap/presentation/screens/roadmap_screen.dart:517-544` — nút "Bắt đầu học" chỉ mở các màn hình kỹ năng rời (`HanziWritingScreen`, `PronunciationLabScreen`, `ReadingPassageListScreen`, `GrammarListScreen`, `ReviewScreen`), không mở nội dung bài và các màn hình này không báo hoàn thành bài.
- `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart:49-58` — điều kiện mở bài kế tiếp: `preProgress != null && preProgress.isCompleted`.

**Mã lỗi:** `BIZ-ROADMAP-NO-COMPLETE`

**Nguyên nhân gốc rễ**
`LessonDetailSheet` chỉ render 2 nút: `'Bắt đầu học'` (`:281`) và `'Bỏ qua'` (`:292`); không có nút "Hoàn thành". `onComplete` được khai báo như một API dở dang (stub) nên toàn bộ luồng "học → chấm điểm → hoàn thành" của tab Lộ trình bị cắt.

**Kịch bản & hậu quả**
Học viên mở tab Lộ trình → mở bài → `startLesson` ghi `status = inProgress` vào `lesson_progress` → mở màn hình kỹ năng → quay lại roadmap: bài **mãi ở trạng thái "Đang học dở"**, bài kế tiếp vẫn `locked` vì prerequisite đòi `isCompleted`. Chỉ khi người dùng tình cờ vào tab Giáo trình (`curriculum_syllabus_screen.dart:177` → `LessonStudyScreen`) mới hoàn thành được. Roadmap — được quảng cáo là "lộ trình thích ứng" — trở thành dead-end.

**Bản vá**
Thêm nút/CTA "Hoàn thành bài" gọi `onComplete(score)` (lấy điểm thật từ bài kiểm tra mastery, không hardcode), hoặc nối các màn hình kỹ năng trả kết quả về `completeLesson`. Thêm test hành vi: start → complete từ roadmap thì bài kế phải `available`.

---

### BIZ-03 [High] "Hoàn thành bài học" khi phần kiểm tra rỗng ghi nhận đậu 100%, mở khóa bài sau mà không có bất kỳ đánh giá nào

**Vị trí**
- `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:40-52` — khi không có câu hỏi, hiển thị empty state với `onAction: widget.onFinishLesson`, `buttonText: 'Hoàn thành bài học'`.
- `lib/features/curriculum/presentation/screens/lesson_study_screen.dart:105-109` — `onFinishLesson: () async { await flowNotifier.completeLesson(); ... }`.
- `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart:96-108` — `final scoreToRecord = state.lastScorePercent ?? defaultScorePercent;` với `defaultScorePercent = 1.0`.
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:63` — `final isPassed = scorePercent >= passingThreshold;` (0.8).

**Mã lỗi:** `BIZ-LESSON-FREE-PASS`

**Nguyên nhân gốc rễ**
Nếu `masteryCheck` segment không có câu hỏi (thiếu dữ liệu content pack), `state.lastScorePercent` vẫn `null` vì chưa từng gọi `submitPractice`; `completeLesson` lấy mặc định **1.0** và coi như đậu. Pipeline sau đó đặt `status = 'completed'`, ghi `curriculum_mastery.score = 1.0`, phát instruction evidence cho toàn bộ từ vựng, đăng ký SRS và **mở khóa các bài con** (Step F).

**Kịch bản & hậu quả**
Một bài HSK1 thiếu `mastery_check` (hoặc payload rỗng) → học viên bấm "Hoàn thành bài học" ngay → hệ thống ghi 100%, mở bài tiếp theo, đưa từ vựng vào SRS. Chuỗi prerequisite bị vượt qua mà không có bằng chứng học tập; mastery/roadmap bị "bơm" điểm 1.0. UI hiển thị "Đạt chuẩn đầu ra" trong khi học viên chưa làm câu nào.

**Bản vá**
`completeLesson` phải từ chối (hoặc ghi `in_progress`) khi `lastScorePercent == null`; chỉ cho phép skip có đánh dấu riêng (không tính là đậu). Tương tự, `recordLessonCompletion` nên yêu cầu `questionResults != null && isNotEmpty` để set `completed`.

---

### BIZ-04 [High] Kết quả CAT không bao giờ đi vào Roadmap: sai key JSON và so khớp nhãn knowledge-gap

**Vị trí**
- `lib/features/roadmap/data/roadmap_repository.dart:322-333` — trích điểm kỹ năng: `final rawVal = v['score'] ?? v['mastery'] ?? v['theta'];`
- `lib/features/placement_test/domain/models/cat_assessment_result.dart:52-62` — dữ liệu thực tế lưu `'estimated_theta'`, `'accuracy_rate'`, `'standard_error'`, `'is_assessed'` (không có `score`, `mastery`, `theta`).
- `lib/features/roadmap/data/roadmap_repository.dart:288-296` — knowledge gaps: `final label = e['label_vi'] ?? e['tag'] ?? e['skill'];` (lấy **nhãn tiếng Việt**).
- `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart:126-130` — so khớp: `gap.toLowerCase().contains(skill.name)` (skill.name là tiếng Anh: `listening`, `reading`, …).

**Mã lỗi:** `BIZ-CAT-ROADMAP-DECOUPLE`

**Nguyên nhân gốc rễ**
Hai phía dùng schema khác nhau: `SkillScoreEstimate.toMap()` ghi `estimated_theta/accuracy_rate`, còn roadmap đọc `score/mastery/theta` ⇒ `extractedScore` luôn `null` ⇒ `placementSkillScores` **luôn rỗng**. Với gaps, roadmap nhận chuỗi tiếng Việt ("Phân biệt thanh điệu", "Bỏ qua phần này"…) nên `hasKnowledgeGap` luôn `false`.

**Kịch bản & hậu quả**
Học viên làm CAT, hệ thống tìm ra lỗ hổng Listening & điểm Writing thấp. Mở tab Lộ trình: mọi bài đều được xếp hạng `recommended` (mục C, dòng 151-162) và reason chung chung; không có gợi ý `urgent` nào từ CAT; skill mastery ban đầu = 0; "cá nhân hóa theo bài kiểm tra đầu vào" trên thực tế không hoạt động. Đây là split-brain giữa placement và roadmap (cùng với BIZ-08).

**Bản vá**
Dùng đúng key: `v['accuracy_rate'] ?? v['estimated_theta']` (chuẩn hóa theta ∈ [-3,3] về [0,1] trước khi so); lưu cả `tag` lẫn `labelVi` khi sinh gaps và so khớp theo `tag`/`skill` bằng `Enum.name`, hoặc map nhãn Việt → `SkillDimension` qua bảng tra.

---

### BIZ-05 [High] Lỗi SRS do bài tập: "quên" được đưa về due-now nhưng KHÔNG reset repetitions/interval ⇒ lần ôn kế tiếp nhảy interval khổng lồ

**Vị trí**
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:402-414` — khi bài tập sai và card đã tồn tại, chỉ cập nhật `state`, `due_at`, `lapses`:
  ```dart
  await txn.update(... {'state': decision.targetState, 'due_at': decision.scheduledDueAt..., 'lapses': ((existingSrsItem.first['lapses'] as num?)?.toInt() ?? 0) + 1, ...})
  ```
  (không đụng `repetitions`, `interval_days`).
- `lib/features/vocabulary_srs/domain/sm2_engine.dart:112-143` — interval tính từ `prevReps/prevInterval` của state hiện tại, không xét `state == relearning`:
  ```dart
  final scaled = (prevInterval * newEf).round();   // dòng 140
  ```

**Mã lỗi:** `BIZ-SRS-LAPSE-INTERVAL-EXPLOSION`

**Nguyên nhân gốc rễ**
Pipeline "trừng phạt" bằng cách đổi `state='relearning'` + `due_at=now` + `lapses+1` nhưng giữ nguyên `repetitions` và `interval_days`. SM-2 chỉ reset khi rating < 3; nếu người học ôn lại và bấm "Nhớ" (quality 4), engine coi đây là lần thành công thứ n+1 và nhân interval cũ.

**Kịch bản & hậu quả**
Từ vựng có `repetitions=4, interval_days=30`. Học viên làm bài tập sai từ đó ⇒ card due ngay. Học viên mở ôn tập, bấm "Nhớ" ⇒ `newInterval = round(30 × newEf≈2.4) ≈ 72 ngày`. Một từ vừa bị quên biến mất gần 2,5 tháng; hệ thống tưởng đã nhớ. Lỗi này lặp lại mỗi lần sai bài tập, làm hỏng toàn bộ đường cong quên.

**Bản vá**
Khi reschedule do fail: `repetitions = 0`, `interval_days = 0` (hoặc dùng API `Sm2Engine` với quality < 3 để có một nguồn logic duy nhất). Thêm test: fail ở reps≥2 → rating good → interval phải ≤ vài ngày.

---

### BIZ-06 [High] Badge "Cần ôn hôm nay" đếm cả thẻ không bao giờ xuất hiện trong hàng đợi ôn tập; hàm migrate chưa từng được gọi

**Vị trí**
- `lib/features/vocabulary_srs/data/srs_repository.dart:242-267` — `getDueFlashcards` dùng `INNER JOIN ... ON s.content_id = v.id` (dòng 256) khi lấy queue.
- `lib/features/vocabulary_srs/data/srs_repository.dart:400-413` — `getDueCardsCount` (badge) dùng `INNER JOIN ... ON (s.content_id = v.id OR s.content_id = v.simplified)` (dòng 405).
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:200-209` — khi nạp SRS từ bài học: `final canonicalId = vocabRows.isNotEmpty ? ... : simplified;` (fallback = chữ Hán thay vì PK).
- `lib/features/vocabulary_srs/data/srs_repository.dart:444` — `migrateSrsItemsToCanonical()` tồn tại nhưng **không được gọi ở bất kỳ đâu** (grep toàn `lib/`: chỉ có định nghĩa).

**Mã lỗi:** `BIZ-SRS-QUEUE-STARVATION`

**Nguyên nhân gốc rễ**
Hai truy vấn dùng tiêu chí join khác nhau; pipeline có thể tạo `content_id` = chữ Hán (không phải PK). Badge (đếm) thấy thẻ nhờ nhánh `OR simplified`, còn queue (join `v.id`) loại bỏ ⇒ chênh lệch vĩnh viễn. Ngoài ra queue còn lọc cứng theo `v.hsk_level = profile.currentHskLevel` (dòng 246-248) nên khi người học đổi cấp HSK, toàn bộ thẻ của cấp cũ không bao giờ vào hàng đợi nữa (trong khi badge có thể vẫn đếm).

**Kịch bản & hậu quả**
Học viên thấy "Cần ôn hôm nay: 5" nhưng mở tab Ôn tập báo "Không có thẻ" hoặc chỉ 1-2 thẻ; bấm refresh vẫn vậy. Thẻ bị kẹt không thể ôn ⇒ mất dữ liệu retention; badge không giảm. Trường hợp đổi HSK level càng nặng: toàn bộ từ vựng cấp trước "biến mất" khỏi ôn tập.

**Bản vá**
Dùng cùng một điều kiện join/chuẩn hóa cho cả badge và queue (canonical hóa qua `KnowledgeIdentityRegistry`), hoặc bỏ lọc `hsk_level` mặc định (chỉ lọc khi người dùng chủ động chọn). Gọi `migrateSrsItemsToCanonical()` một lần trong startup migration và thêm test bất biến: `count(getDueCards(...)) == getDueCardsCount(...)`.

---

### BIZ-07 [High] Câu trả lời sai trong bài học không bao giờ được ghi nhận vào mastery/SRS vì chỉ nhận diện từ mục tiêu qua regex dấu ngoặc kép

**Vị trí**
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:311-330`:
  ```dart
  String? targetWord = q['target_word'] as String?;
  if (targetWord == null || targetWord.isEmpty) {
    final prompt = q['prompt'] as String? ?? '';
    final match = RegExp(r'["“]([^"”]+)["”]').firstMatch(prompt);   // dòng 324
    if (match != null) targetWord = match.group(1);
  }
  ```
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:330` — `if (targetWord != null && targetWord.isNotEmpty) { ... ghi evidence / gắn unstable / reschedule SRS ... }`

**Mã lỗi:** `BIZ-LESSON-EXERCISE-LOST`

**Nguyên nhân gốc rễ**
`enrichedExercises` do `LessonMasteryView` tạo (`lesson_mastery_view.dart:274-281`) chỉ có `id/user_answer/selected_option/is_correct/score`, **không có `target_word`**. Vì vậy mọi kết quả câu hỏi phụ thuộc vào việc prompt có chứa chữ Hán trong cặp ngoặc kép hay không. Đề bài dạng "Chọn nghĩa đúng của từ này:" hoặc "Điền vào chỗ trống" không chứa ngoặc kép ⇒ `targetWord == null` ⇒ toàn bộ khối evidence/unstable/SRS bị bỏ qua **im lặng**.

**Kịch bản & hậu quả**
Học viên sai 4/5 câu kiểm tra của bài: pipeline vẫn chỉ ghi instruction evidence (score 1.0) cho từ vựng, không có application evidence sai nào; từ vựng không bị đánh dấu `unstable`, không được reschedule về "due now". Mastery của từ giữ nguyên "learning" và SRS vẫn hẹn 1 ngày sau như thể học viên đã nắm chắc. Ngược lại, nếu prompt có ngoặc kép chứa cụm không phải từ vựng (ví dụ trích dẫn câu), evidence bị gắn sai `content_id`.

**Bản vá**
Truyền `target_word`/`vocabulary_id` tường minh từ model bài kiểm tra (thêm field vào `CurriculumExercise`) thay vì đoán từ prompt; nếu không xác định được mục tiêu, vẫn phải ghi application evidence ở mức lesson (`content_type='lesson'`) để không mất dữ liệu sai.

---

### BIZ-08 [Med-High] Roadmap dùng "mục tiêu HSK" làm "cấp đang học" ⇒ hiển thị/khóa sai cấp độ

**Vị trí**
- `lib/features/roadmap/data/roadmap_repository.dart:351` — `currentLevel: goal.targetHskLevel` (truyền vào `AdaptiveRoadmapContext.currentLevel`).
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart:375` & `:386` — onboarding luôn đặt `target_hsk_level = currentHsk + 1` (tối đa 6).
- `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart:34-35` — `final level = CurriculumCatalog.getLevel(context.currentLevel); final allLessons = level.allLessons;`

**Mã lỗi:** `BIZ-ROADMAP-TARGET-AS-CURRENT`

**Nguyên nhân gốc rễ**
`LearnerGoal.targetHskLevel` (đích đến) bị dùng thay cho `UserProfile.currentHskLevel` (trình độ hiện tại). Onboarding luôn +1 nên hai giá trị chắc chắn lệch 1 cấp.

**Kịch bản & hậu quả**
Học viên được CAT xếp HSK 2 (đã credit HSK 1 + bài đầu HSK 2) → onboarding đặt target HSK 3 → tab Lộ trình hiển thị **toàn bộ 20 bài HSK 3**, tất cả `locked` trừ bài 1 (prerequisite rỗng), và không hiển thị các bài HSK 2 đang học dở. Gợi ý "bài tiếp theo" cũng nằm ở HSK 3. Người học mất lộ trình đang học thực tế.

**Bản vá**
`currentLevel` phải lấy từ `user_profiles.current_hsk_level` (hoặc `goal.targetHskLevel` chỉ dùng cho ước lượng thời gian); hiển thị thêm bộ chọn cấp độ đã có (`selectedRoadmapLevelProvider`) để người học xem cấp hiện tại.

---

### BIZ-09 [Med-High] Resume bài CAT bị lặp câu đã trả lời / nhảy sai kỹ năng

**Vị trí**
- `lib/features/placement_test/data/placement_test_repository.dart:143-163`:
  ```dart
  for (final skill in effectiveBlueprint.skillSequence) {
    final count = skillCounts[skill] ?? 0;
    if (count < effectiveBlueprint.minItemsPerSkill) { currentSkill = skill; break; }
    if (count < effectiveBlueprint.maxItemsPerSkill) { currentSkill = skill; break; }   // dòng 153
  }
  final activeItem = _engine.selectNextItem(...) ?? _engine.selectInitialItem(currentSkill, targetTheta: currentTheta);   // dòng 159-163
  ```

**Mã lỗi:** `BIZ-CAT-RESUME-REPEAT`

**Nguyên nhân gốc rễ**
Khi resume, `currentSkill` được suy ra từ số câu đã làm, bỏ qua việc bank của kỹ năng đã cạn hoặc kỹ năng đã bị dừng bởi skip/3-sai-liên-tiếp. Nếu `selectNextItem` trả `null` (hết câu), fallback `selectInitialItem` **không nhận `usedItemIds`** nên chọn lại câu đầu tiên đã làm.

**Kịch bản & hậu quả**
Người dùng thoát giữa bài sau khi hoàn thành vocabulary (5 câu) và grammar (4 câu, bank cạn). Resume: vòng lặp thấy `grammar count=4 < maxItemsPerSkill(5)` → chọn grammar; `selectNextItem` = null → fallback trả `GRAM_001` (đã trả lời) → học viên bị hỏi lại đúng câu cũ, câu trả lời được ghi thêm một response, theta bị cập nhật lần hai cho cùng item. Ngược lại, nếu người dùng đã skip một kỹ năng, resume có thể quay lại kỹ năng đã bỏ.

**Bản vá**
Lưu `currentSkill` (và `stepIndex`) vào `placement_test_sessions` mỗi turn, hoặc tái tạo trạng thái bằng cách replay `processTurn` trên các response đã lưu; fallback phải truyền `usedItemIds` và bỏ qua skill đã đạt max/cạn bank.

---

### BIZ-10 [Med] Rating "Quên" đưa thẻ về due sau 10 phút nhưng thẻ bị loại khỏi phiên ngay, không có bước relearning trong phiên

**Vị trí**
- `lib/features/vocabulary_srs/presentation/providers/srs_providers.dart:92-102` — sau khi ghi review: `currentIndex: current.currentIndex + 1` (dòng 95) bất kể rating.
- `lib/features/vocabulary_srs/domain/sm2_engine.dart:99-107`, `:155-157` — rating "Again" đặt `newInterval = 0` và `dueAt = now + 10 minutes`.
- UI hiển thị "< 10 phút" cho nút Again: `sm2_engine.dart:224-226`.

**Mã lỗi:** `BIZ-SRS-AGAIN-NO-REQUEUE`

**Nguyên nhân gốc rễ**
Hàng đợi là snapshot một lượt (`queue`, `currentIndex`); khi rating Again, card được hẹn 10 phút nhưng không được chèn lại cuối `queue`, và provider không tự refresh queue khi đến hạn trong cùng phiên.

**Kịch bản & hậu quả**
Học viên bấm "Quên" cho 20 thẻ: cả 20 thẻ bị đẩy khỏi phiên, màn hình báo "hoàn thành" (accuracy thấp). 10 phút sau badge due tăng lại nhưng phiên mới chỉ tạo khi provider rebuild; người học không được ôn lại ngay — trái với bản chất SM-2 (lapse phải học lại trong phiên). UI còn khiến người học hiểu là "sẽ gặp lại sau 10 phút" trong chính phiên đó.

**Bản vá**
Khi rating < 3, chèn lại card vào cuối queue (tối đa N lần/phiên) hoặc thêm nút "ôn lại thẻ quên" refresh queue sau 10 phút; đảm bảo `accuracyRate`/completedCount phản ánh cả lần ôn lại.

---

### BIZ-11 [Med] Luyện phát âm offline (service trả `null` có chủ đích) bị lưu thành điểm 0.0 trong `learner_evidence`

**Vị trí**
- `lib/features/pronunciation/data/pronunciation_repository.dart:37` — `'score': assessment.overallScore ?? 0.0,`
- `lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart:303-323` — khi không có ASR: `overallScore: null, // Honest null: no fake 0.85!`, `status: PronunciationEvaluationStatus.unsupported`.
- Service cũng trả `overallScore` null ở các nhánh failed (:80, :101, :167, :266, :286).

**Mã lỗi:** `BIZ-PRON-NULL-TO-ZERO`

**Nguyên nhân gốc rễ**
Service tuân thủ "không bịa điểm", nhưng repository biến `null` thành `0.0` trước khi persist, tạo bằng chứng "làm sai" cho một lần thu âm mà hệ thống không hề chấm.

**Kịch bản & hậu quả**
Học viên dùng app không cấu hình API key (mặc định `DefaultPronunciationAnalysisService()` — `pronunciation_providers.dart:22`): mỗi lần luyện phát âm ghi 1 evidence `score = 0.0`, kèm activity. Các màn thống kê/hoạt động gần đây (Home đọc `learner_evidence` — `home_repository.dart:250-260`, `:571-587`) hiển thị buổi luyện "0 điểm"/"thất bại"; các ngưỡng đánh giá dựa trên score (mastery evaluator, roadmap evidence) có thể coi đây là bằng chứng âm. Trái với thiết kế "trung thực" của service và có thể làm giảm điểm kỹ năng Nói.

**Bản vá**
Lưu `score = null` (hoặc bỏ qua insert evidence) khi `status` là `unsupported`/`failed`/`insufficientAudio`; chỉ ghi activity và metadata. Nếu cần giữ attempt, thêm cột/status riêng để không bị tính vào mastery.

---

### BIZ-12 [Med] Luyện viết chữ Hán không có dữ liệu nét chuẩn vẫn trả 100% (pass) và nút "Đánh giá" luôn bật

**Vị trí**
- `lib/features/hanzi_writing/domain/engine/stroke_evaluator.dart:20-34` — `if (strokeData == null) { return WritingEvaluationResult(strokeOrderAccuracy: 1.0, ...); }`
- `lib/features/hanzi_writing/domain/models/stroke_models.dart:213-215` — `int get scorePercent => (strokeOrderAccuracy * 100)...; bool get isPassed => scorePercent >= 70;`
- `lib/features/hanzi_writing/presentation/widgets/writing_toolbar.dart:116` — `onPressed: controller.strokeCount > 0 ? onEvaluate : null` (không phụ thuộc `hasStrokeData`).
- `lib/features/hanzi_writing/presentation/screens/hanzi_writing_screen.dart:50-63` — `_handleEvaluate` lấy `strokeData` (có thể null) rồi gọi evaluator.

**Mã lỗi:** `BIZ-HANZI-FREE-100`

**Nguyên nhân gốc rễ**
Nhánh "chưa có dữ liệu nét chuẩn" được coi là **đạt tuyệt đối** (1.0) thay vì "không chấm được". Kết quả này được hiển thị bằng `scorePercent`/`isPassed` như một bài đạt, và được lưu vào `learner_evidence` với `score = strokeOrderAccuracy` (`hanzi_writing_repository.dart:50`).

**Kịch bản & hậu quả**
Chữ không có trong bank 8 chữ curated (`hanzi_stroke_bank.dart`, `_verifiedBank` chỉ có 一/二/三/十/人/…) và chưa kịp nạp từ DB (`getStrokeDataAsync` trả null) → học viên vẽ vài nét bất kỳ, bấm "Đánh giá" → nhận 100% "Rất tốt", "Đạt", lưu bằng chứng điểm 1.0. Ngược lại nếu `strokeData` tồn tại nhưng `strokes` rỗng (`_convertFromHanziCharacter` trả `strokes: const []`, `isVerified: strokes.isNotEmpty` — dòng 359) thì `totalStandard = 0` dẫn tới phép chia `correctStrokes / totalStandard` (dòng 114) = 0/0 → `NaN`/lỗi khi `.round()`.

**Bản vá**
Trả về trạng thái `notAssessable` (score null / 0 điểm không hiển thị "đạt") khi thiếu dữ liệu; chặn nút Đánh giá khi `!hasStrokeData`; thêm guard `totalStandard == 0` trước phép chia. Không ghi evidence điểm 1.0 cho lần không chấm được.

---

### BIZ-13 [Med] Bài tập nhập Pinyin không chuẩn hóa thanh điệu/dấu dù comment nói "normalizes whitespace and accents"

**Vị trí**
- `lib/features/pinyin_foundation/domain/engine/pinyin_exercise_engine.dart:54-63`:
  ```dart
  case PinyinExerciseType.listenInputPinyin:
    // Text-based input evaluation (normalizes whitespace and accents)
    final isMatch = cleanSubmission == cleanCorrect;
  ```
- `:31-32` — `cleanSubmission = submission.trim().toLowerCase();`, `cleanCorrect = exercise.correctAnswer.trim().toLowerCase();` (không hề xử lý dấu/thanh điệu/space).

**Mã lỗi:** `BIZ-PINYIN-TONE-NORMALIZE`

**Nguyên nhân gốc rễ**
Phép so sánh là exact-match trên chuỗi thô; comment mô tả hành vi không tồn tại trong code (false claim).

**Kịch bản & hậu quả**
Đáp án `nǐ hǎo`; người học gõ `ni hao` (bàn phím không gõ dấu) hoặc `ni3 hao3` (cách gõ số) → bị chấm sai 100%, điểm bài Pinyin Foundation giảm, dù phát âm/kiến thức đúng. Ngược lại gõ thừa khoảng trắng ở giữa cũng sai. Với trẻ mới học, đây là false-negative hệ thống và ảnh hưởng pass/fail của bài.

**Bản vá**
Chuẩn hóa: strip dấu thanh (NFD + bỏ combining marks), chuyển `ü→v/u`, chấp nhận hậu tố số thanh (`ni3 hao3`), xóa mọi khoảng trắng trước khi so; hiển thị đáp án đúng kèm pinyin có dấu. Thêm test cho 3 cách gõ.

---

### BIZ-14 [Med] Đề thi tốt nghiệp HSK: đồng hồ hiển thị tĩnh không đếm ngược, thời lượng ghi khống, và không thể đạt nếu content pack thiếu một phần thi

**Vị trí**
- `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:377-380` — `Text('$_durationMinutes:00', ...)` hiển thị "35:00" cố định (không có `Timer`/countdown nào trong file).
- `:242-250` — `durationSeconds: _durationMinutes * 60` được ghi như thể đã dùng đủ 35 phút, bất kể thời gian thực.
- `:203-222` — `listenPoints` và `readPoints` mỗi phần tối đa 100; `totalPoints = listenPoints + readPoints`; `_passingScore = 120` (`:41`), `_totalScore = 200` (`:40`).
- `:215-217` — nếu không có câu listening: `final listenPoints = listeningQuestions.isNotEmpty ? ... : 0;`

**Mã lỗi:** `BIZ-EXITEXAM-TIMER-SCORE`

**Nguyên nhân gốc rễ**
(1) Đồng hồ là UI trang trí, không ràng buộc thời gian — "đề thi 35 phút" không được thực thi. (2) Điểm được chuẩn hóa **theo từng phần** thay vì theo tổng số câu: nếu pack chỉ có 1 phần (hoặc section name không chứa "listen" — mọi section lạ rơi vào `'reading'` tại `:171`), điểm tối đa chỉ còn 100 < 120 ⇒ **không bao giờ đậu**, trong khi màn hình vẫn hiển thị "/200 điểm".

**Kịch bản & hậu quả**
Content pack HSK cấp cao chỉ có phần Reading (hoặc section "Nghe hiểu" tiếng Việt → bị gán reading): học viên làm đúng 100% vẫn "CHƯA ĐẠT ĐIỂM CHUẨN" → không được unlock cấp tiếp. Ngoài ra đề không giới hạn thời gian nên kết quả "tốt nghiệp" không tương đương điều kiện thi thật; `learning_activities` bị ghi khống 35 phút mỗi lần (ảnh hưởng streak/phút học thống kê).

**Bản vá**
Thêm `Timer` đếm ngược + auto-submit và lưu `durationSeconds` thực; tính điểm theo tổng (`score = round(correct/total*200)`) hoặc cấu hình `passing_score` theo tổng số câu thực tế của pack; map section theo `name` chuẩn (`listening`/`reading`/`writing`) với fallback rõ ràng.

---

### BIZ-15 [Med] "Bỏ qua bài" ghi `completion_score = 1.0`, không thỏa prerequisite và tạo bản ghi trùng trong `lesson_progress`

**Vị trí**
- `lib/features/roadmap/data/roadmap_repository.dart:243-263` — `skipLesson` **insert** dòng mới với `'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}'`, `'status': LessonStatus.skipped.name`, `'completion_score': 1.0` (dòng 256).
- `lib/features/roadmap/domain/engine/adaptive_roadmap_engine.dart:43` — `if (existing != null && (existing.isCompleted || existing.status == LessonStatus.skipped))` ⇒ coi skipped như đã xử lý; nhưng prerequisite ở `:51` chỉ chấp nhận `isCompleted` (`LessonProgress.isCompleted => status == LessonStatus.completed`, `roadmap_models.dart:263`).
- `lib/features/roadmap/data/roadmap_repository.dart:74-90` — `getLessonProgressMap()` đọc toàn bộ bảng **không ORDER BY**, gán đè theo thứ tự trả về.

**Mã lỗi:** `BIZ-ROADMAP-SKIP-DEADEND`

**Nguyên nhân gốc rễ**
Skip tạo dòng mới (không update dòng cũ) nên một bài có thể có 2 dòng (`inProgress` + `skipped`) hoặc nhiều dòng skipped; map last-wins không xác định. Đồng thời skipped không được tính là completed cho prerequisite, nên bài sau vẫn khóa vĩnh viễn trong roadmap (chỉ thoát được bằng cách start lại rồi hoàn thành qua tab Giáo trình — xem BIZ-02). `completion_score: 1.0` khiến bottom sheet hiển thị "Điểm đạt: 100%" cho bài chưa học (`lesson_detail_sheet.dart:259-268`).

**Kịch bản & hậu quả**
Học viên bấm "Bỏ qua" bài 2 → bài 3 vẫn "Đang khóa (chưa đạt tiên quyết)" và không có cách hoàn thành từ roadmap; đồng thời bài 2 hiển thị điểm 100%. Sau khi bấm start lại, DB có 2 dòng trạng thái khác nhau; tab Giáo trình và roadmap có thể hiển thị trạng thái khác nhau tùy thứ tự đọc.

**Bản vá**
Skip phải `upsert` theo `lesson_id` (hoặc xóa/chuyển dòng cũ), không set `completion_score` cho skipped; quyết định nghiệp vụ rõ: skip có thỏa prerequisite hay không (nếu có, sửa `isCompleted`/điều kiện engine; nếu không, không cho skip bài đang là prerequisite của bài khác). Thêm `ORDER BY updated_at DESC` khi đọc map.

---

### BIZ-16 [Med] Hoàn thành bài đọc không có câu hỏi ghi bằng chứng 100%; mỗi lần lưu lại append thêm evidence

**Vị trí**
- `lib/features/reading/data/reading_repository.dart:110-129` — `'score': (score ?? 100.0) / 100.0` (dòng 119); insert evidence mỗi khi `isCompleted` (append-only, id mới mỗi lần).
- `lib/features/reading/presentation/widgets/reading_questions_section.dart:39-58` — `if (widget.questions.isEmpty) { _score = 100.0; return; }` (dòng 40-43) và `_handleSubmit` gọi `onSubmitted(_userAnswers, _score ?? 100.0)`.
- `lib/features/reading/presentation/screens/reading_detail_screen.dart:389-418` — `onSubmitted` lưu `isCompleted: true, score: score` rồi hiển thị SnackBar "Đã hoàn thành bài đọc! Điểm: 100%".

**Mã lỗi:** `BIZ-READING-FREE-100`

**Nguyên nhân gốc rễ**
`score == null` (không có quiz / chưa chấm) được repository hiểu là 100%; UI cũng tự đặt 100 khi danh sách câu hỏi rỗng. Ngoài ra mỗi lần người dùng mở lại và submit (hoặc progress được lưu lại) đều chèn evidence mới cùng `content_id` với score 1.0.

**Kịch bản & hậu quả**
Bài đọc không có câu hỏi hiểu: người học bấm "Hoàn thành" → evidence 1.0 cho kỹ năng đọc, hiển thị 100%. Việc submit lặp tạo nhiều bằng chứng 100% cho cùng một passage (append-only) → các thống kê dựa trên evidence bị lệch; ngược lại bài đọc không được chấm cũng không bị coi là "chưa đánh giá".

**Bản vá**
Chỉ ghi evidence khi `questions.isNotEmpty` và `score != null`; nếu không có quiz, ghi activity "đã đọc" với `content_type='reading_exposure'` và score null; chống submit lặp bằng idempotency theo `(passage_id, attempts)`.

---

### BIZ-17 [Med] Một lần làm bài kiểm tra mastery bị ghi thành 2 lượt: `attempts_count` +2 và instruction evidence nhân đôi

**Vị trí**
- `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart:40-92` — `submitPractice` gọi `masteryEngine.recordLessonAttempt(...)` (dòng 79) và set `lastScorePercent`.
- `lib/features/curriculum/presentation/screens/lesson_study_screen.dart:104-109` — `onSubmit: (questions) => flowNotifier.submitPractice(questions)`; sau khi đạt, nút "Hoàn thành bài học" gọi `flowNotifier.completeLesson()`.
- `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart:96-108` — `completeLesson` gọi `recordLessonAttempt` **lần nữa** với `scoreToRecord = state.lastScorePercent`.
- `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:89-110` — mỗi lần gọi tăng `attempts_count` và ghi lại mastery; `:195-268` phát instruction evidence mới cho mọi từ.

**Mã lỗi:** `BIZ-LESSON-DOUBLE-ATTEMPT`

**Nguyên nhân gốc rễ**
Hai entry point cùng ghi "hoàn thành bài" cho cùng một lượt học; `completeLesson` không có idempotency guard.

**Kịch bản & hậu quả**
Học viên đạt 9/10 → `attempts_count = 1`; bấm "Hoàn thành bài học" → pipeline chạy lần hai: `attempts_count = 2`, evidence instruction cho mọi từ vựng được nhân đôi (append-only), SRS không nhân đôi (có check tồn tại) nhưng `evidence_count` trong `lesson_progress` tăng. Các màn "số lần thử/độ chính xác" và thống kê bằng chứng bị sai; roadmep `evidenceCount` bị thổi phồng.

**Bản vá**
Cho `submitPractice` là nơi duy nhất ghi attempt; `completeLesson` chỉ chuyển trạng thái UI/điều hướng khi `lastScorePercent != null`, hoặc thêm idempotency key `(lessonId, attemptNumber)` trong pipeline.

---

### BIZ-18 [Low] CAT: mọi kỹ năng được lưu cùng một `estimatedTheta` và cùng `standardError`/confidence của toàn bài

**Vị trí**
- `lib/features/placement_test/domain/engine/cat_engine.dart:331-333` — `double skillTheta = overallTheta;` (không có ước lượng riêng cho từng kỹ năng).
- `:370-385` — `confidenceLabel` tính từ `overallStandardError` cho **mọi** skill; `standardError: overallStandardError` (dòng 381).
- `lib/features/placement_test/domain/models/cat_assessment_result.dart:13-14` — doc nói `estimatedTheta` là "Estimated latent ability parameter θ ... (null if unassessed)" cho từng kỹ năng.

**Mã lỗi:** `BIZ-CAT-SKILL-THETA-FLAT`

**Nguyên nhân gốc rễ**
Engine chỉ cập nhật một θ toàn cục; khi sinh báo cáo, θ đó được sao cho mọi kỹ năng thay vì ước lượng riêng (IRT đa chiều) hoặc ít nhất dùng accuracy để suy θ theo kỹ năng.

**Kịch bản & hậu quả**
Học viên đúng 100% vocabulary nhưng sai 3/3 reading: cả hai skill đều lưu `estimated_theta` giống hệt nhau (và cùng confidence "Cao"), chỉ khác `accuracy_rate`. Radar hiện tại dùng `accuracyRate` nên chưa lộ, nhưng bất kỳ consumer nào đọc `estimated_theta` (báo cáo, API, đồng bộ cloud, gợi ý lộ trình tương lai) sẽ nhận chẩn đoán sai — đặc biệt là per-skill confidence luôn giống nhau.

**Bản vá**
Ước lượng θ riêng theo từng kỹ năng (EAP/MLE trên item của skill đó) hoặc suy từ accuracy + difficulty trung bình; ít nhất đặt `standardError`/`confidenceLabel` theo số item/skill thay vì toàn bài.

---

## Đã kiểm tra — không phải lỗi (đã đối chiếu code hiện tại)

1. **Công thức SM-2 EF và interval cơ bản đúng chuẩn** — `sm2_engine.dart:54-59` đúng `EF' = EF + (0.1-(5-q)(0.08+(5-q)0.02))`, clamp `[1.3, 5.0]`; interval 1/6 ngày cho n = 1/2; due date tính bằng UTC (`:154-157`). Lỗi nằm ở đường reschedule từ pipeline (BIZ-05), không phải công thức.
2. **Unassessed skill không bị chấm 0** — `cat_engine.dart:303-326` và `cat_assessment_result.dart:43-50` xử lý `isAssessed=false`, `confidenceLabel='Chưa đánh giá'` đúng; lỗi là test kết thúc sớm (BIZ-01) chứ không phải cách hiển thị.
3. **Double-tap SRS có guard** — `srs_repository.dart:102-122` dùng `_inFlightContentIds` + cooldown 800ms; `srs_providers.dart:73-84` chặn khi `isProcessingReview`. Không tìm thấy race double-record trong đường UI flashcard.
4. **Practice có idempotency theo (session_id, exercise_id)** — `learning_pipeline_coordinator.dart:548-558` và `practice_repository.dart:228-239`; không double count khi retry cùng exercise trong cùng session (đánh đổi: lần sửa lại câu sai trong cùng session không được ghi — hành vi hiện tại của UI là chuyển câu nên chưa thành lỗi).
5. **UTC vs local day** — các bảng activity dùng `AppClock.todayLocalDateString()` / `AppClock.toLocalDateString(now, timeZoneOffset)` (`srs_repository.dart:355`, `pronunciation_repository.dart:23`, `hanzi_writing_repository.dart:25`, `curriculum_repository.dart:131`), có lưu `timezone_offset_minutes`; không thấy bug lệch ngày trong phạm vi này (streak engine ở `home_repository.dart` do teammate Home/Data phụ trách — xem cross-domain).
6. **Chia 0 ở slider nghe** — `listening_screen.dart:100-104` đã guard `totalMs > 0`; không phải lỗi.
7. **Scanner exercise values** — `ExerciseEvaluationResult` trả `isPassed=false` khi `questions.isEmpty` (`adaptive_exercise_sampler.dart:67-75`), không chia 0; nhưng sampler này hiện chỉ được gọi qua `submitPractice` với danh sách đã có phần tử.
8. **`accuracy_rate` chia cho `assessedResponses`** — `cat_engine.dart:329` có guard `assessedResponses.isEmpty ? 0.0 : ...` ngay sau khi đã `continue` ở nhánh rỗng; không chia 0.
9. **`ReviewScreen` hiển thị "Tỷ lệ nhớ 100%" khi chưa ôn lượt nào** (`srs_models.dart:354-355`, `flashcard_empty_state.dart:23`) — đây là mặc định hiển thị của empty-state, chưa gây sai dữ liệu; ghi nhận mức Low, không đưa vào findings chính.
10. **PrerequisiteEngine dùng thang điểm 0..1 khớp ngưỡng 0.8** — `learning_pipeline_coordinator.dart:63,100` lưu `scorePercent` (0..1); `prerequisite_engine.dart:71-74` so `score < threshold(0.8)` đúng thang, không phải lỗi reversed threshold. (Điểm cần teammate khác xác nhận: `evaluateUnlockStatus` không được gọi từ production — chỉ có trong `test/`; unlock thực tế do `learning_pipeline_coordinator.dart:441-511` và `placement_unlock_handler.dart` đảm nhận — xem cross-domain.)

---

## Cross-domain leads (gửi Lead phân bổ)

1. **Home/Streak (Home/Data teammate):** `home_repository.dart:245-320` hợp nhất `learner_evidence` + `learning_activities` với heuristic chống double-count theo khoảng thời gian (±30s, +duration) và backfill `:568-587`; cần kiểm tra double-count XP/streak và việc evidence `score=0.0` của pronunciation/reading (BIZ-11/16) đi vào thống kê phút học.
2. **Settings/Data reset (Data teammate):** `data_management_service.dart:426-475` xóa `user_profiles`/`learner_goals`/`roadmap_snapshots` nhưng **không reset** `app_settings` (`onboarding_completed`, `roadmap_initialized`, `starting_hsk_level`) — sau reset, onboarding coi như đã xong; kiểm tra tính nhất quán.
3. **Profile (Features teammate):** `profile_screen.dart:9` import và `:492` điều hướng tới `DesignSystemDemoScreen` — màn demo design system lọt vào app production; nên xác nhận có chủ đích hay bỏ.
4. **Content packs (Data teammate):** `content_pack_manager.dart:313-380` mặc định `is_locked = 1` cho lesson/unit khi pack thiếu field; kết hợp việc `evaluateUnlockStatus` không được gọi ở production — kiểm tra người dùng mới (bỏ qua onboarding) có mở được bài 1 không; `assets/data/content_packs/hsk1|hsk2` là nguồn dữ liệu exit exam (BIZ-14) và lesson segments.
5. **AI tutor / profile stats:** các aggregate điểm kỹ năng đọc `learner_evidence` (`learner_context_service.dart:205-360`) có thể bị ảnh hưởng bởi evidence score 0/null (BIZ-11/16/17); teammate AI/Data nên rà.
6. **QA:** nên thêm test hồi quy cho: CAT 6 kỹ năng (BIZ-01), SRS fail→good interval (BIZ-05), badge==queue (BIZ-06), roadmap complete (BIZ-02), reading/pronunciation null-score (BIZ-11/16), pinyin tone input (BIZ-13).
