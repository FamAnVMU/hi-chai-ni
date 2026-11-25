import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/ai_tutor/data/repositories/ai_tutor_repository.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_chat_turn.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_correction.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_scenario.dart';

void main() {
  group('AI Tutor Evaluation, Streaming & Context Integrity', () {
    test('extractStreamingReplyZh decodes partial JSON deltas and escapes safely', () {
      expect(AiTutorRepositoryImpl.extractStreamingReplyZh('   '), isEmpty);
      expect(AiTutorRepositoryImpl.extractStreamingReplyZh('{"reply_zh": "'), isEmpty);
      expect(
        AiTutorRepositoryImpl.extractStreamingReplyZh('{"reply_zh": "你好\\n我是'),
        equals('你好\n我是'),
      );
      expect(
        AiTutorRepositoryImpl.extractStreamingReplyZh(
          '{"reply_zh": "他说\\"好\\"！", "pinyin": "tā shuō hǎo"}',
        ),
        equals('他说"好"！'),
      );
      expect(
        AiTutorRepositoryImpl.extractStreamingReplyZh('你好，很高兴认识你！'),
        equals('你好，很高兴认识你！'),
      );
    });

    test('TutorEvaluation keeps encouragementVi distinct from gentleFeedbackVi', () {
      const evalIncorrect = TutorEvaluation(
        isCorrect: false,
        originalText: '我昨天去医院看病了昨天',
        correctedText: '我昨天去医院看病了。',
        pinyin: 'Wǒ zuótiān qù yīyuàn kànbìng le.',
        explanationVi: 'Bạn bị lặp từ "昨天" ở cuối câu.',
        errorCategory: TutorErrorCategory.wordOrder,
      );

      expect(
        evalIncorrect.encouragementVi,
        equals('Bạn đã rất cố gắng diễn đạt ý tưởng của mình!'),
      );
      expect(evalIncorrect.gentleFeedbackVi, equals('Bạn bị lặp từ "昨天" ở cuối câu.'));
      expect(evalIncorrect.encouragementVi, isNot(equals(evalIncorrect.gentleFeedbackVi)));
    });

    test('TutorScenario provides specific suggestedUserPrompts for all role-play codes', () {
      for (final code in ['restaurant', 'hotel_checkin', 'airport', 'job_interview']) {
        final scenario = TutorScenarios.fromCode(code);
        expect(scenario.code, equals(code));
        expect(scenario.suggestedUserPrompts, isNotEmpty);
        expect(
          scenario.suggestedUserPrompts,
          isNot(equals(TutorScenarios.freeChat.suggestedUserPrompts)),
        );
      }
    });

    test('TutorChatTurn round-trips evaluation_json and follow_up_suggestions_json', () {
      const eval = TutorEvaluation(
        isCorrect: false,
        originalText: '我要水杯',
        correctedText: '我要一杯水。',
        pinyin: 'Wǒ yào yì bēi shuǐ.',
        explanationVi: 'Cần lượng từ 杯 trước danh từ.',
        errorCategory: TutorErrorCategory.grammarStructure,
        encouragementVi: 'Rất tốt!',
      );
      final turn = TutorChatTurn(
        id: 't1',
        sessionId: 's1',
        role: 'assistant',
        content: '好的，请稍等。',
        createdAt: DateTime.utc(2026, 11, 25, 10, 0),
        evaluation: eval,
        followUpSuggestions: const ['请给我菜单', '多少钱？'],
      );

      final map = turn.toDbMap();
      final restored = TutorChatTurn.fromDbMap(map);

      expect(restored.evaluation, isNotNull);
      expect(restored.evaluation!.correctedText, equals('我要一杯水。'));
      expect(restored.evaluation!.encouragementVi, equals('Rất tốt!'));
      expect(restored.followUpSuggestions, equals(['请给我菜单', '多少钱？']));
    });
  });
}
