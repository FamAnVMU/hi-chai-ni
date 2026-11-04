import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_api_key_screen.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_personalization_screen.dart';
import 'package:hi_chinese/features/placement_test/presentation/providers/placement_test_providers.dart';
import 'package:hi_chinese/features/placement_test/presentation/screens/placement_test_intro_screen.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_session_state.dart';

void main() {
  group('Onboarding Flow Widget Tests', () {
    testWidgets('1. OnboardingApiKeyScreen renders input, informational note, and skip button', (tester) async {
      bool skipped = false;
      bool saved = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OnboardingApiKeyScreen(
              onSkip: () => skipped = true,
              onSaveApiKey: (key) async {
                saved = true;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Cấu hình AI Trợ Giảng (Tùy chọn)'), findsOneWidget);
      expect(find.textContaining('hoạt động ngoại tuyến 100%'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      final skipBtn = find.text('Bỏ qua để học ngoại tuyến');
      expect(skipBtn, findsOneWidget);
      await tester.ensureVisible(skipBtn);
      await tester.pumpAndSettle();
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
      expect(saved, isFalse);
    });

    testWidgets('2. OnboardingPersonalizationScreen selects study commitment and focus skill', (tester) async {
      int selectedMinutes = 0;
      String selectedSkill = '';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OnboardingPersonalizationScreen(
              onComplete: (minutes, skill) {
                selectedMinutes = minutes;
                selectedSkill = skill;
              },
            ),
          ),
        ),
      );

      expect(find.text('Thiết Lập Mục Tiêu Học Tập'), findsOneWidget);
      expect(find.text('Thời gian học mỗi ngày:'), findsOneWidget);
      expect(find.text('Kỹ năng trọng điểm ưu tiên:'), findsOneWidget);

      expect(find.text('15 phút'), findsOneWidget);
      expect(find.text('30 phút'), findsOneWidget);
      expect(find.text('60 phút'), findsOneWidget);

      final chip15 = find.text('15 phút');
      await tester.ensureVisible(chip15);
      await tester.tap(chip15);
      await tester.pumpAndSettle();

      final listeningChip = find.text('Nghe hiểu');
      expect(listeningChip, findsOneWidget);
      await tester.ensureVisible(listeningChip);
      await tester.tap(listeningChip);
      await tester.pumpAndSettle();

      final startBtn = find.text('Bắt đầu lộ trình ngay');
      expect(startBtn, findsOneWidget);
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(selectedMinutes, 15);
      expect(selectedSkill, 'listening');
    });

    testWidgets('3. PlacementTestIntroScreen allows beginner to skip to HSK 1 directly', (tester) async {
      int? assessedLevel;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveCatSessionNotifier()),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            home: PlacementTestIntroScreen(
              onTestComplete: ([level]) => assessedLevel = level,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kinh nghiệm học tiếng Trung của bạn:'), findsOneWidget);
      expect(find.text('Người mới bắt đầu'), findsOneWidget);
      expect(find.text('Đã biết cơ bản'), findsOneWidget);
      expect(find.text('Đã học một thời gian'), findsOneWidget);
      expect(find.text('Đã có chứng chỉ HSK'), findsOneWidget);

      final skipBtn = find.text('Bỏ qua bài kiểm tra (Bắt đầu từ HSK 1)');
      expect(skipBtn, findsOneWidget);
      await tester.ensureVisible(skipBtn);
      await tester.pumpAndSettle();
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(assessedLevel, equals(1));
    });

    testWidgets('4. PlacementTestIntroScreen allows certified learner to choose HSK 3 directly', (tester) async {
      int? assessedLevel;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCatSessionProvider.overrideWith(() => _TestActiveCatSessionNotifier()),
            latestAssessmentResultProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            home: PlacementTestIntroScreen(
              onTestComplete: ([level]) => assessedLevel = level,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hasHskCard = find.text('Đã có chứng chỉ HSK');
      expect(hasHskCard, findsOneWidget);
      await tester.tap(hasHskCard);
      await tester.pumpAndSettle();

      expect(find.text('Chọn cấp độ HSK bạn đã đạt được:'), findsOneWidget);
      final hsk3Chip = find.text('HSK 3');
      expect(hsk3Chip, findsOneWidget);
      await tester.ensureVisible(hsk3Chip);
      await tester.tap(hsk3Chip);
      await tester.pumpAndSettle();

      final confirmBtn = find.text('Xác nhận bắt đầu từ HSK 3');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(assessedLevel, equals(3));
    });

    testWidgets('5. OnboardingPersonalizationScreen submits full personalization profile', (tester) async {
      PersonalizationData? submittedData;
      int submittedMinutes = 0;
      String submittedSkill = '';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OnboardingPersonalizationScreen(
              onComplete: (minutes, skill, [data]) {
                submittedMinutes = minutes;
                submittedSkill = skill;
                submittedData = data;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Goals & Purpose
      expect(find.text('Mục tiêu học tiếng Trung chính của bạn:'), findsOneWidget);
      final hskExamPurpose = find.text('Luyện thi chứng chỉ HSK');
      await tester.ensureVisible(hskExamPurpose);
      await tester.tap(hskExamPurpose);
      await tester.pumpAndSettle();

      // Navigate to Step 2
      final toStep2Btn = find.text('Tiếp tục sang Chặng 2');
      expect(toStep2Btn, findsOneWidget);
      await tester.ensureVisible(toStep2Btn);
      await tester.tap(toStep2Btn);
      await tester.pumpAndSettle();

      // Step 2: Method & Reminder
      expect(find.text('Phương pháp học ưa thích:'), findsOneWidget);
      expect(find.text('Nhắc nhở học tập hàng ngày:'), findsOneWidget);

      // Navigate to Step 3
      final toStep3Btn = find.text('Tiếp tục Chặng 3');
      expect(toStep3Btn, findsOneWidget);
      await tester.ensureVisible(toStep3Btn);
      await tester.tap(toStep3Btn);
      await tester.pumpAndSettle();

      // Step 3: Display & Audio Preferences
      expect(find.text('Hiển thị Pinyin & Phiên âm:'), findsOneWidget);
      expect(find.text('Bộ chữ Hán ưa thích:'), findsOneWidget);
      expect(find.text('Tốc độ phát âm audio mặc định:'), findsOneWidget);

      final traditionalScript = find.text('Phồn thể (繁體)');
      await tester.ensureVisible(traditionalScript);
      await tester.tap(traditionalScript);
      await tester.pumpAndSettle();

      final finishBtn = find.text('Hoàn tất thiết lập & Vào học');
      expect(finishBtn, findsOneWidget);
      await tester.ensureVisible(finishBtn);
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(submittedMinutes, equals(30));
      expect(submittedSkill, equals('reading'));
      expect(submittedData, isNotNull);
      expect(submittedData!.purpose, equals('hskExam'));
      expect(submittedData!.scriptType, equals('traditional'));
      expect(submittedData!.showPinyin, isTrue);
    });
  });
}

class _TestActiveCatSessionNotifier extends ActiveCatSessionNotifier {
  @override
  Future<CatSessionState?> build() async => null;

  @override
  Future<void> startNewTest({double? initialTheta}) async {}
}
