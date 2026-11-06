# Task 2 Brief: Xây Dựng `lessonDetailProvider` Phản Ứng & Tự Động Đồng Bộ Học Liệu

**Files:**
- Modify: `lib/features/curriculum/presentation/providers/curriculum_providers.dart`
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_detail_reactive_test.dart`

**Exact Requirements:**
1. **`lessonDetailProvider` in `curriculum_providers.dart`**:
   ```dart
   final lessonDetailProvider = FutureProvider.family<CurriculumLesson?, String>((ref, lessonId) async {
     final repo = ref.watch(curriculumRepositoryProvider);
     return repo.getLessonById(lessonId);
   });
   ```
2. **Integration in `LessonStudyScreen`**:
   - Watch `ref.watch(lessonDetailProvider(widget.lesson.id))` in `build()`.
   - Resolve reactive lesson:
     ```dart
     final reactiveLessonAsync = ref.watch(lessonDetailProvider(widget.lesson.id));
     final currentLesson = reactiveLessonAsync.value ?? widget.lesson;
     ```
   - In `_buildCurrentStep(safeIndex, flowNotifier)`, pass `currentLesson` (and its fresh segments) into the respective step views:
     - `WarmupStepView(lesson: currentLesson, ...)`
     - `VocabStepView(lesson: currentLesson, ...)`
     - `GrammarStepView(lesson: currentLesson, ...)`
     - `DialogueStepView(lesson: currentLesson, ...)`
     - `PracticeStepView(lesson: currentLesson, ...)`
     - `MasteryCheckStepView(lesson: currentLesson, ...)`
3. **Reactive Testing**:
   Create `test/features/curriculum/lesson_detail_reactive_test.dart`:
   - Mock/override `lessonDetailProvider` or test with a container where a lesson without segments is initially provided, and `lessonDetailProvider` delivers the populated `CurriculumLesson` with 6 segments.
   - Verify that `LessonStudyScreen` renders segments from the reactive lesson smoothly without throwing exceptions or showing empty views.
4. **Run Test**:
   `cd C:\Users\phama\Downloads\hi_chinese; flutter test test/features/curriculum/lesson_detail_reactive_test.dart` -> PASS.
5. **Commit Message**:
   `feat(curriculum): add reactive lessonDetailProvider with live segment reloading`
