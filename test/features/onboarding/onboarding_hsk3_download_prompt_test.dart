import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/content_packs/presentation/providers/content_packs_providers.dart';
import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:hi_chinese/features/roadmap/domain/models/roadmap_models.dart' show LearningPathType;
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_flow_screen.dart';

class _FakeOnboardingNotifier extends OnboardingNotifier {
  final int startingHsk;
  int completeCalls = 0;

  _FakeOnboardingNotifier(this.startingHsk);

  @override
  OnboardingState build() => OnboardingState(
        currentStep: OnboardingStep.personalization,
        assessedHskLevel: startingHsk,
      );

  @override
  Future<bool> completePersonalization({
    required int dailyMinutes,
    required String focusSkill,
    LearningPathType learningPathType = LearningPathType.focused,
    String learningPurpose = 'dailyCommunication',
    bool showPinyin = true,
    String pinyinPosition = 'above_hanzi',
    String scriptType = 'simplified',
    String learningMethod = 'contextual_lessons',
    double speechRate = 1.0,
    bool reminderEnabled = true,
    String reminderTime = '20:00',
    int? targetHskLevel,
  }) async {
    completeCalls++;
    return true;
  }
}

Future<void> _finishPersonalization(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (final label in ['Tiếp tục sang Chặng 2', 'Tiếp tục Chặng 3', 'Hoàn tất thiết lập & Vào học']) {
    final btn = find.text(label);
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Onboarding HSK 3+ content pack download prompt', () {
    testWidgets('1. Starting at HSK 3 shows download dialog before completing onboarding', (tester) async {
      final fake = _FakeOnboardingNotifier(3);
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [onboardingProvider.overrideWith(() => fake), isHskLevelInstalledProvider(3).overrideWith((ref) => false)],
          child: MaterialApp(
            home: OnboardingFlowScreen(onOnboardingComplete: () => completed = true),
          ),
        ),
      );

      await _finishPersonalization(tester);

      expect(find.text('Bạn đã sẵn sàng học HSK 3!'), findsOneWidget);
      expect(find.text('Tải ngay & Bắt đầu'), findsOneWidget);
      expect(find.text('Để sau'), findsOneWidget);
      expect(fake.completeCalls, 0, reason: 'Onboarding must not finish before the dialog is answered');
      expect(completed, isFalse);

      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(fake.completeCalls, 1);
      expect(completed, isTrue);
    });

    testWidgets('2. Starting at HSK 5 also shows the prompt with the right level', (tester) async {
      final fake = _FakeOnboardingNotifier(5);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [onboardingProvider.overrideWith(() => fake), isHskLevelInstalledProvider(5).overrideWith((ref) => false)],
          child: MaterialApp(
            home: OnboardingFlowScreen(onOnboardingComplete: () {}),
          ),
        ),
      );

      await _finishPersonalization(tester);
      expect(find.text('Bạn đã sẵn sàng học HSK 5!'), findsOneWidget);
    });

    testWidgets('3. Starting at HSK 1 completes without any download prompt', (tester) async {
      final fake = _FakeOnboardingNotifier(1);
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [onboardingProvider.overrideWith(() => fake)],
          child: MaterialApp(
            home: OnboardingFlowScreen(onOnboardingComplete: () => completed = true),
          ),
        ),
      );

      await _finishPersonalization(tester);

      expect(find.textContaining('Bạn đã sẵn sàng học HSK'), findsNothing);
      expect(fake.completeCalls, 1);
      expect(completed, isTrue);
    });

    testWidgets('4. Starting at HSK 3 with the pack already installed skips the prompt', (tester) async {
      final fake = _FakeOnboardingNotifier(3);
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingProvider.overrideWith(() => fake),
            isHskLevelInstalledProvider(3).overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: OnboardingFlowScreen(onOnboardingComplete: () => completed = true),
          ),
        ),
      );

      await _finishPersonalization(tester);

      expect(find.text('Bạn đã sẵn sàng học HSK 3!'), findsNothing);
      expect(fake.completeCalls, 1);
      expect(completed, isTrue);
    });
  });
}