import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/app_shell/presentation/providers/app_shell_providers.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_assessment_result.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_item.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_session_state.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_skill.dart';
import 'package:hi_chinese/features/placement_test/presentation/providers/placement_test_providers.dart';
import 'package:hi_chinese/features/placement_test/presentation/screens/placement_test_intro_screen.dart';
import 'package:hi_chinese/features/placement_test/presentation/screens/placement_test_result_screen.dart';
import 'package:hi_chinese/features/placement_test/presentation/widgets/cat_question_card.dart';

void main() {
  CatAssessmentResult createSampleResult({
    double theta = 0.2,
    double se = 0.35,
    bool skipSpeaking = false,
  }) {
    return CatAssessmentResult(
      sessionId: 'SAMPLE_SESSION_01',
      overallTheta: theta,
      overallStandardError: se,
      referenceHskBand: 'HSK 2 (Sơ cấp nâng cao)',
      confidenceScore: 0.85,
      skillScores: {
        CatSkill.vocabulary: const SkillScoreEstimate(
          skill: CatSkill.vocabulary,
          isAssessed: true,
          estimatedTheta: 0.2,
          accuracyRate: 0.80,
          confidenceLabel: 'Cao',
        ),
        CatSkill.grammar: const SkillScoreEstimate(
          skill: CatSkill.grammar,
          isAssessed: true,
          estimatedTheta: 0.1,
          accuracyRate: 0.75,
          confidenceLabel: 'Cao',
        ),
        CatSkill.reading: const SkillScoreEstimate(
          skill: CatSkill.reading,
          isAssessed: true,
          estimatedTheta: 0.3,
          accuracyRate: 1.0,
          confidenceLabel: 'Cao',
        ),
        CatSkill.listening: const SkillScoreEstimate(
          skill: CatSkill.listening,
          isAssessed: true,
          estimatedTheta: 0.0,
          accuracyRate: 0.67,
          confidenceLabel: 'Trung bình',
        ),
        CatSkill.writing: const SkillScoreEstimate(
          skill: CatSkill.writing,
          isAssessed: true,
          estimatedTheta: 0.1,
          accuracyRate: 0.67,
          confidenceLabel: 'Trung bình',
          subMetrics: {
            'character_recognition_accuracy': 1.0,
            'pinyin_transcription_accuracy': 0.0,
            'stroke_order_accuracy': 1.0,
          },
        ),
        CatSkill.speaking: skipSpeaking
            ? SkillScoreEstimate.unassessed(
                CatSkill.speaking,
                reason: 'Chưa đủ dữ liệu đánh giá phát âm',
              )
            : const SkillScoreEstimate(
                skill: CatSkill.speaking,
                isAssessed: true,
                estimatedTheta: 0.0,
                accuracyRate: 1.0,
                confidenceLabel: 'Trung bình',
                subMetrics: {'speaking_mode': 'Đã phân tích âm học'},
              ),
      },
      knowledgeGaps: const [
        KnowledgeGapItem(
          tag: 'writing_pinyin_transcription_hsk2',
          labelVi: 'Quy tắc phiên âm Pinyin tiếng Trung HSK 2',
          skill: CatSkill.writing,
          suggestedRemediationVi: 'Chữ "汉语" có phiên âm chuẩn là "hànyǔ".',
        ),
      ],
      recommendedHskLevel: 2,
      recommendedRoadmapTitle: 'Lộ trình gợi ý: HSK 2',
      recommendedRoadmapCode: 'HSK_2',
      completedAt: DateTime.now().toUtc(),
    );
  }

  group('Placement Test Widget & UX Acceptance Tests', () {
    testWidgets('1. PlacementTestIntroScreen renders overview, 6 skills, and start button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveSessionNotifier(null)),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlacementTestIntroScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Khảo Sát Thích Ứng (CAT)'), findsOneWidget);
      expect(find.text('1. Từ vựng'), findsOneWidget);
      expect(find.text('2. Ngữ pháp'), findsOneWidget);
      expect(find.text('3. Đọc hiểu'), findsOneWidget);
      expect(find.text('4. Nghe hiểu'), findsOneWidget);
      expect(find.text('5. Kỹ năng Viết'), findsOneWidget);
      expect(find.text('6. Phát âm & Nói'), findsOneWidget);

      // Default selected is zeroChinese: Check encouraging copy, badge, and custom button
      expect(find.text('Đừng lo lắng! Bài kiểm tra sẽ giúp bạn kiểm tra độ nhạy âm thanh và trực giác nhận diện chữ tượng hình, không yêu cầu đã biết chữ Hán.'), findsOneWidget);
      expect(find.text('Độ khó thích ứng mức cơ bản'), findsOneWidget);
      expect(find.text('Bắt đầu bài trắc nghiệm làm quen (2 phút)'), findsOneWidget);

      // When switching to 'Đã biết cơ bản', button updates to standard start text
      await tester.tap(find.text('Đã biết cơ bản'));
      await tester.pumpAndSettle();
      expect(find.text('Bắt đầu làm bài kiểm tra'), findsOneWidget);
    });

    testWidgets('2. PlacementTestIntroScreen renders resume button when active session exists', (tester) async {
      final activeState = CatSessionState.initial('TEST_RESUME').copyWith(
        stepIndex: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveSessionNotifier(activeState)),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlacementTestIntroScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bạn có bài kiểm tra đang dang dở!'), findsOneWidget);
      expect(find.text('Đã hoàn thành 4 câu hỏi. Bạn có thể tiếp tục ngay lập tức mà không mất dữ liệu.'), findsOneWidget);
      expect(find.text('Tiếp tục bài test'), findsOneWidget);
    });

    testWidgets('3. PlacementTestIntroScreen renders past result button when previous test completed', (tester) async {
      final sampleResult = createSampleResult();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveSessionNotifier(null)),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(sampleResult)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlacementTestIntroScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kết Quả Bài Kiểm Tra Gần Nhất'), findsOneWidget);
      expect(find.text('Cấp độ tham chiếu: HSK 2 (Sơ cấp nâng cao)'), findsOneWidget);
      expect(find.text('Xem lại kết quả & phân tích'), findsOneWidget);
    });

    testWidgets('4. CatQuestionCard renders multiple choice question and submits selection', (tester) async {
      dynamic submittedAnswer;

      const item = CatItem(
        id: 'TEST_ITEM_01',
        skill: CatSkill.vocabulary,
        type: CatItemType.multipleChoice,
        difficulty: -1.0,
        hskLevel: 1,
        prompt: 'Từ nào có nghĩa là Quả táo?',
        options: ['苹果', '香蕉', '西瓜'],
        correctOptionIndex: 0,
        explanationVi: '苹果 là quả táo.',
        knowledgeGapTag: 'vocab_fruits',
        knowledgeGapLabelVi: 'Từ vựng hoa quả',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CatQuestionCard(
              item: item,
              onAnswerSubmitted: (ans) => submittedAnswer = ans,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Từ nào có nghĩa là Quả táo?'), findsOneWidget);
      expect(find.text('苹果'), findsOneWidget);
      expect(find.text('香蕉'), findsOneWidget);

      // Tap on Option A (苹果)
      await tester.tap(find.text('苹果'));
      await tester.pump();

      expect(submittedAnswer, 0);
    });

    testWidgets('5. PlacementTestResultScreen displays HSK reference band, disclaimer, skill breakdown, and roadmap', (tester) async {
      final sampleResult = createSampleResult(skipSpeaking: true);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PlacementTestResultScreen(result: sampleResult),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Reference HSK Band and Disclaimer
      expect(find.text('HSK 2 (Sơ cấp nâng cao)'), findsOneWidget);
      expect(find.text(CatAssessmentResult.disclaimerVi), findsOneWidget);

      // Assessed skills and unassessed Speaking skill
      expect(find.text('Đánh Giá Chi Tiết 6 Kỹ Năng'), findsOneWidget);
      expect(find.text('Chưa đánh giá'), findsOneWidget);
      expect(find.text('Chưa đủ dữ liệu đánh giá phát âm qua audio'), findsOneWidget);

      // Writing sub-metrics
      expect(find.text('• Nhận diện chữ Hán: '), findsOneWidget);
      expect(find.text('• Phiên âm Pinyin: '), findsOneWidget);
      expect(find.text('• Thứ tự nét viết: '), findsOneWidget);

      // Knowledge Gaps
      expect(find.text('Lỗ Hổng Trọng Tâm Cần Củng Cố'), findsOneWidget);
      expect(find.text('Quy tắc phiên âm Pinyin tiếng Trung HSK 2'), findsOneWidget);

      // Recommended starting roadmap
      expect(find.text('Lộ trình gợi ý: HSK 2'), findsOneWidget);
      expect(find.text('Bắt đầu học theo lộ trình gợi ý'), findsOneWidget);
    });

    testWidgets('6. Tapping start roadmap button navigates to Learning tab', (tester) async {
      final sampleResult = createSampleResult();
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PlacementTestResultScreen(result: sampleResult),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.text('Bắt đầu học theo lộ trình gợi ý');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      // Tap "Bắt đầu học theo lộ trình gợi ý"
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(container.read(selectedTabProvider), AppTab.learning);
    });

    testWidgets('7. Layout renders without overflow on 320dp narrow screen', (tester) async {
      final sampleResult = createSampleResult();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(320, 600)),
              child: PlacementTestResultScreen(result: sampleResult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // Zero overflows!
      expect(find.text('HSK 2 (Sơ cấp nâng cao)'), findsOneWidget);
    });

    testWidgets('8. PlacementTestResultScreen displays beginner diagnostic cards for Acoustic Sensitivity and Pictographic Intuition', (tester) async {
      final beginnerResult = CatAssessmentResult(
        sessionId: 'BEGINNER_TEST_01',
        overallTheta: -2.0,
        overallStandardError: 0.38,
        referenceHskBand: 'HSK 0 (Khởi đầu từ số 0)',
        confidenceScore: 0.75,
        skillScores: {
          CatSkill.listening: const SkillScoreEstimate(
            skill: CatSkill.listening,
            isAssessed: true,
            estimatedTheta: -1.9,
            accuracyRate: 0.80,
            confidenceLabel: 'Cao',
            subMetrics: {'acoustic_sensitivity_accuracy': 0.85},
          ),
          CatSkill.writing: const SkillScoreEstimate(
            skill: CatSkill.writing,
            isAssessed: true,
            estimatedTheta: -2.0,
            accuracyRate: 1.0,
            confidenceLabel: 'Cao',
            subMetrics: {
              'pictographic_intuition_accuracy': 1.0,
              'character_recognition_accuracy': 1.0,
            },
          ),
          CatSkill.vocabulary: SkillScoreEstimate.unassessed(CatSkill.vocabulary),
          CatSkill.grammar: SkillScoreEstimate.unassessed(CatSkill.grammar),
          CatSkill.reading: SkillScoreEstimate.unassessed(CatSkill.reading),
          CatSkill.speaking: SkillScoreEstimate.unassessed(CatSkill.speaking),
        },
        knowledgeGaps: const [],
        recommendedHskLevel: 1,
        recommendedRoadmapTitle: 'Lộ trình gợi ý: HSK 1',
        recommendedRoadmapCode: 'HSK_1',
        completedAt: DateTime.now().toUtc(),
        blueprintVersion: 'v1.0-beginner',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PlacementTestResultScreen(result: beginnerResult),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đánh Giá Khả Năng Ngôn Ngữ Tự Nhiên'), findsOneWidget);
      expect(find.text('Người mới bắt đầu'), findsOneWidget);
      expect(find.text('Độ nhạy ngữ âm (Acoustic Sensitivity)'), findsOneWidget);
      expect(find.text('Trực giác chữ tượng hình (Pictographic Intuition)'), findsOneWidget);
      expect(find.text('85%'), findsWidgets);
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Lộ trình gợi ý: HSK 1'), findsOneWidget);
    });

    testWidgets('9. PlacementTestIntroScreen provides dedicated beginner button that triggers onTestComplete(0)', (tester) async {
      int? completedLevel;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveSessionNotifier(null)),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PlacementTestIntroScreen(
              onTestComplete: ([level]) => completedLevel = level,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final beginnerBtn = find.text('Tôi là người mới bắt đầu – Chưa biết tiếng Trung');
      expect(beginnerBtn, findsOneWidget);

      await tester.ensureVisible(beginnerBtn);
      await tester.pumpAndSettle();
      await tester.tap(beginnerBtn);
      await tester.pumpAndSettle();

      expect(completedLevel, equals(0));
    });
  });
}

class _TestActiveSessionNotifier extends ActiveCatSessionNotifier {
  final CatSessionState? mockState;

  _TestActiveSessionNotifier(this.mockState);

  @override
  Future<CatSessionState?> build() async {
    return mockState;
  }
}
