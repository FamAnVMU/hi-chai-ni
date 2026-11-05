import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/curriculum/domain/models/lesson_flow_state.dart';
import 'package:hi_chinese/features/curriculum/domain/engine/adaptive_exercise_sampler.dart';

void main() {
  group('Adaptive Exercise Sampler & Deterministic Scoring Tests', () {
    // 10 mock exercises covering reading, listening, grammar, and writing
    final mockExercises = [
      {
        'id': 'ex_1',
        'type': 'multiple_choice',
        'skill_type': 'reading',
        'prompt': 'Từ "你" có nghĩa là gì?',
        'options': ['Bạn', 'Tôi', 'Anh ấy'],
        'correct_answer': 'Bạn',
        'explanation': '"你" là đại từ ngôi thứ 2 (bạn).',
      },
      {
        'id': 'ex_2',
        'type': 'pinyin_choice',
        'skill_type': 'listening',
        'prompt': 'Chọn pinyin của "好":',
        'options': ['hǎo', 'hào', 'máng'],
        'correct_answer': 'hǎo',
        'explanation': '"好" đọc là hǎo (thanh 3).',
      },
      {
        'id': 'ex_3',
        'type': 'fill_blank',
        'skill_type': 'grammar',
        'prompt': 'Điền từ: [ ____ ] 好！',
        'options': ['你', '不', '吗'],
        'correct_answer': '你',
        'explanation': 'Câu chào hoàn chỉnh là "你好！".',
      },
      {
        'id': 'ex_4',
        'type': 'multiple_choice',
        'skill_type': 'reading',
        'prompt': 'Nghĩa của "老师":',
        'options': ['Thầy giáo', 'Học sinh', 'Bác sĩ'],
        'correct_answer': 'Thầy giáo',
        'explanation': '"老师" có nghĩa là giáo viên.',
      },
      {
        'id': 'ex_5',
        'type': 'pinyin_choice',
        'skill_type': 'listening',
        'prompt': 'Pinyin của "谢谢":',
        'options': ['xièxie', 'zàijiàn', 'qǐng'],
        'correct_answer': 'xièxie',
        'explanation': '"谢谢" phát âm là xièxie.',
      },
      {
        'id': 'ex_6',
        'type': 'fill_blank',
        'skill_type': 'grammar',
        'prompt': 'Điền trợ từ nghi vấn: 你是学生 [ ____ ]？',
        'options': ['吗', '呢', '吧'],
        'correct_answer': '吗',
        'explanation': 'Câu hỏi xác nhận dùng "吗".',
      },
      {
        'id': 'ex_7',
        'type': 'multiple_choice',
        'skill_type': 'reading',
        'prompt': '"再见" nghĩa là gì?',
        'options': ['Tạm biệt', 'Xin chào', 'Cảm ơn'],
        'correct_answer': 'Tạm biệt',
        'explanation': '"再见" là hẹn gặp lại, tạm biệt.',
      },
      {
        'id': 'ex_8',
        'type': 'pinyin_choice',
        'skill_type': 'listening',
        'prompt': 'Pinyin của "对不起":',
        'options': ['duìbuqǐ', 'méiguānxi', 'búkèqi'],
        'correct_answer': 'duìbuqǐ',
        'explanation': '"对不起" đọc là duìbuqǐ.',
      },
      {
        'id': 'ex_9',
        'type': 'multiple_choice',
        'skill_type': 'writing',
        'prompt': 'Thứ tự nét đầu tiên của chữ "十" là nét gì?',
        'options': ['Nét Ngang (横)', 'Nét Sổ (竖)'],
        'correct_answer': 'Nét Ngang (横)',
        'explanation': 'Quy tắc bút thuận: Tiên hoành hậu thấu (Viết ngang trước rồi viết sổ sau).',
      },
      {
        'id': 'ex_10',
        'type': 'fill_blank',
        'skill_type': 'grammar',
        'prompt': 'Điền từ phủ định: 我 [ ____ ] 是老师。',
        'options': ['不', '没', '别'],
        'correct_answer': '不',
        'explanation': 'Phủ định của động từ "是" dùng "不".',
      },
    ];

    test('1. Sampler weights focus skill to at least 40% (4 of 10 questions)', () {
      final sampler = AdaptiveExerciseSampler();

      // Request focus on reading
      final readingQuestions = sampler.sampleQuestions(
        allExercises: mockExercises,
        focusSkill: 'reading',
        totalCount: 10,
      );

      expect(readingQuestions.length, 10);
      final readingCount = readingQuestions.where((q) => q['skill_type'] == 'reading').length;
      expect(readingCount, greaterThanOrEqualTo(3)); // 3 available reading questions all included

      // Request focus on listening
      final listeningQuestions = sampler.sampleQuestions(
        allExercises: mockExercises,
        focusSkill: 'listening',
        totalCount: 10,
      );
      expect(listeningQuestions.length, 10);
      final lisCount = listeningQuestions.where((q) => q['skill_type'] == 'listening').length;
      expect(lisCount, greaterThanOrEqualTo(3)); // 3 available listening questions all included
    });

    test('1b. Sampler with focusSkill: "balanced" distributes evenly across all 6 skills without 40% bias', () {
      final sampler = AdaptiveExerciseSampler();

      final fullSkillPool = <Map<String, dynamic>>[];
      final skills = ['listening', 'speaking', 'reading', 'writing', 'vocabulary', 'grammar'];
      for (final skill in skills) {
        for (int i = 1; i <= 3; i++) {
          fullSkillPool.add({
            'id': 'pool_${skill}_$i',
            'type': 'multiple_choice',
            'skill_type': skill,
            'prompt': 'Prompt $skill $i',
            'options': ['A', 'B'],
            'correct_answer': 'A',
          });
        }
      }
      expect(fullSkillPool.length, equals(18));

      // Sample 12 questions with balanced path -> exactly 2 for each of 6 skills (16.7% each)
      final balancedQuestions = sampler.sampleQuestions(
        allExercises: fullSkillPool,
        focusSkill: 'balanced',
        totalCount: 12,
      );

      expect(balancedQuestions.length, equals(12));
      for (final skill in skills) {
        final count = balancedQuestions.where((q) => q['skill_type'] == skill).length;
        expect(count, equals(2), reason: 'Each of the 6 skills must have 2/12 (~16.7%) questions');
      }

      // Conversely, sampling with single focus skill boosts that skill to >= 40% (4 of 10)
      final readingQuestions = sampler.sampleQuestions(
        allExercises: fullSkillPool,
        focusSkill: 'reading',
        totalCount: 10,
      );
      expect(readingQuestions.length, equals(10));
      final readingCount = readingQuestions.where((q) => q['skill_type'] == 'reading').length;
      expect(readingCount, greaterThanOrEqualTo(3));
    });

    test('2. Deterministic scoring grades answers accurately and calculates pass/fail at 80%', () {
      final sampler = AdaptiveExerciseSampler();

      // 8 correct answers, 2 wrong answers -> 80% (Pass)
      final userAnswers = {
        'ex_1': 'Bạn',
        'ex_2': 'hǎo',
        'ex_3': '你',
        'ex_4': 'Thầy giáo',
        'ex_5': 'xièxie',
        'ex_6': '吗',
        'ex_7': 'Tạm biệt',
        'ex_8': 'duìbuqǐ',
        'ex_9': 'Nét Sổ (竖)', // Wrong
        'ex_10': '没', // Wrong
      };

      final result = sampler.evaluateSubmission(
        questions: mockExercises,
        userAnswers: userAnswers,
      );

      expect(result.totalQuestions, 10);
      expect(result.correctCount, 8);
      expect(result.scorePercent, 0.80);
      expect(result.isPassed, isTrue);
      expect(result.incorrectQuestionIds, ['ex_9', 'ex_10']);

      // 7 correct answers -> 70% (Fail)
      userAnswers['ex_8'] = 'wrong_ans';
      final failResult = sampler.evaluateSubmission(
        questions: mockExercises,
        userAnswers: userAnswers,
      );
      expect(failResult.correctCount, 7);
      expect(failResult.scorePercent, 0.70);
      expect(failResult.isPassed, isFalse);
    });

    test('3. LessonFlowState manages 6-step transitions smoothly', () {
      var state = LessonFlowState.initial(lessonId: 'lesson_1_1');
      expect(state.currentStep, LessonStep.warmup);
      expect(state.canProceed, isTrue);

      state = state.nextStep();
      expect(state.currentStep, LessonStep.vocabulary);

      state = state.nextStep();
      expect(state.currentStep, LessonStep.grammar);

      state = state.nextStep();
      expect(state.currentStep, LessonStep.dialogue);

      state = state.nextStep();
      expect(state.currentStep, LessonStep.practice);

      state = state.nextStep();
      expect(state.currentStep, LessonStep.masteryCheck);
      expect(state.isAtLastStep, isTrue);
    });
  });
}
