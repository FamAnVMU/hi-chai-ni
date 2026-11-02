enum LessonStep {
  warmup(stepIndex: 0, titleVi: 'Khởi động'),
  vocabulary(stepIndex: 1, titleVi: 'Từ vựng mới'),
  grammar(stepIndex: 2, titleVi: 'Điểm ngữ pháp'),
  dialogue(stepIndex: 3, titleVi: 'Hội thoại bài đọc'),
  practice(stepIndex: 4, titleVi: 'Luyện tập thích ứng'),
  masteryCheck(stepIndex: 5, titleVi: 'Kiểm tra hoàn thành');

  final int stepIndex;
  final String titleVi;

  const LessonStep({required this.stepIndex, required this.titleVi});

  static LessonStep fromIndex(int index) {
    if (index < 0) return LessonStep.warmup;
    if (index >= LessonStep.values.length) return LessonStep.masteryCheck;
    return LessonStep.values[index];
  }
}

class LessonFlowState {
  final String lessonId;
  final LessonStep currentStep;
  final bool canProceed;
  final Map<String, dynamic> userAnswers;
  final double? lastScorePercent;
  final bool isCompleted;

  const LessonFlowState({
    required this.lessonId,
    this.currentStep = LessonStep.warmup,
    this.canProceed = true,
    this.userAnswers = const {},
    this.lastScorePercent,
    this.isCompleted = false,
  });

  factory LessonFlowState.initial({required String lessonId}) {
    return LessonFlowState(
      lessonId: lessonId,
      currentStep: LessonStep.warmup,
      canProceed: true,
      userAnswers: const {},
    );
  }

  bool get isAtLastStep => currentStep == LessonStep.masteryCheck;

  LessonFlowState nextStep() {
    if (isAtLastStep) return this;
    final nextIndex = currentStep.stepIndex + 1;
    return copyWith(
      currentStep: LessonStep.fromIndex(nextIndex),
      canProceed: true,
    );
  }

  LessonFlowState previousStep() {
    if (currentStep.stepIndex == 0) return this;
    final prevIndex = currentStep.stepIndex - 1;
    return copyWith(
      currentStep: LessonStep.fromIndex(prevIndex),
      canProceed: true,
    );
  }

  LessonFlowState copyWith({
    String? lessonId,
    LessonStep? currentStep,
    bool? canProceed,
    Map<String, dynamic>? userAnswers,
    double? lastScorePercent,
    bool? isCompleted,
  }) {
    return LessonFlowState(
      lessonId: lessonId ?? this.lessonId,
      currentStep: currentStep ?? this.currentStep,
      canProceed: canProceed ?? this.canProceed,
      userAnswers: userAnswers ?? this.userAnswers,
      lastScorePercent: lastScorePercent ?? this.lastScorePercent,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
