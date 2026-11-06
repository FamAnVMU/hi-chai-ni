# Task 4 Brief: Bọc Error Boundary & Chống Lỗi Giao Diện Trắng (Fail-Safe UI)

**Files:**
- Create: `lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart`
- Modify: `lib/features/curriculum/presentation/screens/lesson_study_screen.dart`
- Test: `test/features/curriculum/lesson_step_error_boundary_test.dart`

**Exact Requirements:**
1. **Create `LessonStepErrorBoundary` Widget**:
   `lib/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart`:
   - A widget that uses `ErrorWidget.builder` or `CustomErrorWidget` or standard error catching (or encapsulates the step widget in a protected builder).
   - In Flutter, if a child widget throws an unhandled exception during `build()`, in release mode Flutter displays `SizedBox.shrink()` (an empty white screen).
   - `LessonStepErrorBoundary` must catch rendering errors or provide a fallback UI when a step's payload is malformed or invalid:
     - Shows a clean Card with `Icons.school_outlined` or `Icons.info_outline`
     - Clear text: "Bước này gặp gián đoạn dữ liệu học liệu" or "Nội dung bài học đang được làm mới"
     - Action buttons: "Tiếp tục bước kế tiếp" (triggers `flowNotifier.completeStep(...)` or `flowNotifier.goToStep(...)`) so the user is NEVER trapped on a blank screen.
2. **Integrate into `LessonStudyScreen`**:
   In `LessonStudyScreen._buildCurrentStep`:
   Wrap each step view (`WarmupStepView`, `VocabStepView`, etc.) in `LessonStepErrorBoundary(stepName: _stepTitles[safeIndex], onSkip: () => flowNotifier.completeStep(...), child: ...)`.
3. **Automated Verification Test**:
   Create `test/features/curriculum/lesson_step_error_boundary_test.dart`:
   - Pump `LessonStepErrorBoundary` wrapping a child widget that throws an exception during build.
   - Verify error UI is displayed instead of a blank screen.
   - Verify tapping skip button triggers `onSkip` callback.
4. **Commit Message**:
   `feat(curriculum): add fail-safe error boundary for lesson study steps`
