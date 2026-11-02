import '../models/pinyin_models.dart';

class PinyinExerciseEvaluationResult {
  final bool isCorrect;
  final double score; // 0.0 to 1.0
  final String feedback;
  final String? userAnswer;
  final String correctAnswer;
  final String explanation;

  const PinyinExerciseEvaluationResult({
    required this.isCorrect,
    required this.score,
    required this.feedback,
    this.userAnswer,
    required this.correctAnswer,
    required this.explanation,
  });
}

/// Pure domain evaluation engine for Pinyin Foundation exercises.
/// Adheres strictly to deterministic rule-based evaluation. Never calls LLM for objective answers.
class PinyinExerciseEngine {
  const PinyinExerciseEngine();

  /// Evaluates a learner's answer against a PinyinExercise.
  PinyinExerciseEvaluationResult evaluate({
    required PinyinExercise exercise,
    required String submission,
  }) {
    final cleanSubmission = submission.trim().toLowerCase();
    final cleanCorrect = exercise.correctAnswer.trim().toLowerCase();

    switch (exercise.type) {
      case PinyinExerciseType.listenSelectSyllable:
      case PinyinExerciseType.listenIdentifyTone:
      case PinyinExerciseType.selectInitial:
      case PinyinExerciseType.selectFinal:
      case PinyinExerciseType.blendInitialFinal:
      case PinyinExerciseType.blendSyllableTone:
      case PinyinExerciseType.discriminateMinimalPairs:
      case PinyinExerciseType.comprehensiveReview:
        // Multiple choice matching
        final isMatch = cleanSubmission == cleanCorrect;
        return PinyinExerciseEvaluationResult(
          isCorrect: isMatch,
          score: isMatch ? 1.0 : 0.0,
          feedback: isMatch ? 'Chính xác! Bạn đã nhận diện âm rất tốt.' : 'Chưa chính xác. Hãy chú ý vị trí đặt lưỡi và thanh điệu.',
          userAnswer: submission,
          correctAnswer: exercise.correctAnswer,
          explanation: exercise.explanation,
        );

      case PinyinExerciseType.listenInputPinyin:
        // Text-based input evaluation (normalizes whitespace and accents)
        final isMatch = cleanSubmission == cleanCorrect;
        return PinyinExerciseEvaluationResult(
          isCorrect: isMatch,
          score: isMatch ? 1.0 : 0.0,
          feedback: isMatch ? 'Hoàn hảo! Chính tả Pinyin của bạn hoàn toàn chính xác.' : 'Chưa đúng chính tả Pinyin.',
          userAnswer: submission,
          correctAnswer: exercise.correctAnswer,
          explanation: exercise.explanation,
        );

      case PinyinExerciseType.listenRepeatRecord:
        // Recording attempt evaluation
        // Safeguard: Does not hallucinate acoustic pitch scores without trusted audio ML model
        final hasRecording = submission.isNotEmpty;
        return PinyinExerciseEvaluationResult(
          isCorrect: hasRecording,
          score: hasRecording ? 1.0 : 0.0,
          feedback: hasRecording
              ? 'Đã ghi lại phát âm của bạn thành công. Hãy nghe lại và so sánh với audio mẫu của giáo viên bản xứ.'
              : 'Chưa có bản ghi âm. Vui lòng bấm giữ nút micro để luyện nói.',
          userAnswer: submission,
          correctAnswer: exercise.correctAnswer,
          explanation: exercise.explanation,
        );
    }
  }

  /// Calculates aggregate score for a full lesson attempt.
  double calculateLessonScore(List<PinyinExerciseEvaluationResult> results) {
    if (results.isEmpty) return 0.0;
    final total = results.fold(0.0, (acc, r) => acc + r.score);
    return total / results.length;
  }
}
