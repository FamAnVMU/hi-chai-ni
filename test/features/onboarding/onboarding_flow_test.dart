import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_api_key_screen.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_personalization_screen.dart';

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

      // Verify header and informational note
      expect(find.text('Cấu hình AI Trợ Giảng (Tùy chọn)'), findsOneWidget);
      expect(find.textContaining('hoạt động ngoại tuyến 100%'), findsOneWidget);

      // Verify text field
      expect(find.byType(TextField), findsOneWidget);

      // Verify Skip button exists and functions
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

      // Verify sections
      expect(find.text('Thiết Lập Mục Tiêu Học Tập'), findsOneWidget);
      expect(find.text('Thời gian học mỗi ngày:'), findsOneWidget);
      expect(find.text('Kỹ năng trọng điểm ưu tiên:'), findsOneWidget);

      // Verify commitment chips (15, 30, 60 phút)
      expect(find.text('15 phút'), findsOneWidget);
      expect(find.text('30 phút'), findsOneWidget);
      expect(find.text('60 phút'), findsOneWidget);

      // Select 15 phút
      await tester.tap(find.text('15 phút'));
      await tester.pumpAndSettle();

      // Select focus skill 'Nghe hiểu'
      final listeningChip = find.text('Nghe hiểu');
      expect(listeningChip, findsOneWidget);
      await tester.tap(listeningChip);
      await tester.pumpAndSettle();

      // Tap Complete Button
      final startBtn = find.text('Bắt đầu lộ trình ngay');
      expect(startBtn, findsOneWidget);
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(selectedMinutes, 15);
      expect(selectedSkill, 'listening');
    });
  });
}
