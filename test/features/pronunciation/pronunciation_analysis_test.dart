import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';

void main() {
  group('Pronunciation Analysis Service & Academic Honesty Tests', () {
    const target = PronunciationTarget(
      id: 'TONE_01_MA1',
      text: '妈',
      pinyin: 'mā',
      meaningVi: 'Mẹ',
      category: PronunciationCategory.tone,
    );

    test('1. Short recording (< 0.3s) is flagged with zero score and retry guidance', () async {
      const service = DefaultPronunciationAnalysisService();
      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: 'dummy.wav',
        duration: const Duration(milliseconds: 150),
      );

      expect(result.overallScore, equals(0.0));
      expect(result.confidence, equals(PronunciationConfidence.low));
      expect(result.isAcousticallyAnalyzed, isFalse);
      expect(result.feedbackList.first, contains('Thời lượng thu âm quá ngắn'));
    });

    test('2. Standard text ASR provider DOES NOT fake tone accuracy (Strict Academic Honesty)', () async {
      const service = DefaultPronunciationAnalysisService(
        providerId: 'local_text_asr',
        hasAcousticModel: false,
      );

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: 'user_rec.wav',
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.recognizedTranscript, equals('妈'));
      expect(result.isRecognizedAccurately, isTrue);
      // Academic honesty assertions:
      expect(result.isAcousticallyAnalyzed, isFalse);
      expect(result.toneAccuracy, isNull, reason: 'Must not fake tone score from text transcript');
      expect(result.initialFinalAccuracy, isNull);
      expect(result.feedbackList.any((f) => f.contains('Chưa hỗ trợ bộ phân tích âm học')), isTrue);
    });

    test('3. Acoustic-capable provider provides verified pitch & phoneme breakdown', () async {
      const service = DefaultPronunciationAnalysisService(
        providerId: 'gemini_multimodal_audio',
        hasAcousticModel: true,
      );

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: 'user_rec.wav',
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.isAcousticallyAnalyzed, isTrue);
      expect(result.toneAccuracy, isNotNull);
      expect(result.toneAccuracy, greaterThan(0.8));
      expect(result.initialFinalAccuracy, isNotNull);
      expect(result.confidence, equals(PronunciationConfidence.high));
    });
  });
}
