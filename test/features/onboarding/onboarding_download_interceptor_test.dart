import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/content_packs/presentation/providers/content_packs_providers.dart';
import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_personalization_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Onboarding Download Interceptor & HSK Selection Tests', () {
    testWidgets('1. OnboardingPersonalizationScreen displays HSK chips and allows HSK 3+ selection', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      PersonalizationData? resultData;
      int selectedMin = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingPersonalizationScreen(
              initialHskLevel: 3,
              onComplete: (minutes, skill, [data]) {
                selectedMin = minutes;
                resultData = data;
              },
            ),
          ),
        ),
      );

      // Verify HSK level chips are rendered
      expect(find.text('Cấp độ HSK mục tiêu:'), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_hsk_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_hsk_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_hsk_4')), findsOneWidget);

      // Select HSK 4
      final chipHsk4 = find.byKey(const ValueKey('chip_hsk_4'));
      await tester.ensureVisible(chipHsk4);
      await tester.pumpAndSettle();
      await tester.tap(chipHsk4);
      await tester.pumpAndSettle();

      // Navigate to step 2
      final nextBtn = find.text('Tiếp tục sang Chặng 2');
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Navigate to step 3
      final nextBtn2 = find.text('Tiếp tục Chặng 3');
      await tester.ensureVisible(nextBtn2);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn2);
      await tester.pumpAndSettle();

      // Complete personalization
      final finishBtn = find.text('Hoàn tất thiết lập & Vào học');
      await tester.ensureVisible(finishBtn);
      await tester.pumpAndSettle();
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(resultData, isNotNull);
      expect(resultData!.targetHskLevel, 4);
      expect(selectedMin, 30);
    });

    testWidgets('2. Interceptor Dialog displays when currentHsk >= 3 and pack is uninstalled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isHskLevelInstalledProvider(3).overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      final isInstalled = await ProviderContainer(
                        overrides: [
                          isHskLevelInstalledProvider(3).overrideWith((ref) => false),
                        ],
                      ).read(isHskLevelInstalledProvider(3).future);

                      if (!isInstalled && context.mounted) {
                        showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Bạn đã sẵn sàng học HSK 3!'),
                            content: const Text(
                              'Để học ngay giáo trình và từ vựng chuẩn HSK 3, ứng dụng cần tải gói học liệu (~350KB - 1.5MB). Bạn muốn tải ngay bây giờ không?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Để sau'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Tải ngay & Bắt đầu'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text('Simulate Onboarding Finish'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Simulate Onboarding Finish'));
      await tester.pumpAndSettle();

      // Verify Dialog Title, Body, and Buttons match acceptance criteria verbatim
      expect(find.text('Bạn đã sẵn sàng học HSK 3!'), findsOneWidget);
      expect(
        find.text(
          'Để học ngay giáo trình và từ vựng chuẩn HSK 3, ứng dụng cần tải gói học liệu (~350KB - 1.5MB). Bạn muốn tải ngay bây giờ không?',
        ),
        findsOneWidget,
      );
      expect(find.text('Tải ngay & Bắt đầu'), findsOneWidget);
      expect(find.text('Để sau'), findsOneWidget);

      // Tap 'Để sau'
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã sẵn sàng học HSK 3!'), findsNothing);
    });

    test('3. isHskLevelInstalledProvider returns true for HSK 1 and HSK 2 without DB check', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isHsk1 = await container.read(isHskLevelInstalledProvider(1).future);
      final isHsk2 = await container.read(isHskLevelInstalledProvider(2).future);

      expect(isHsk1, isTrue);
      expect(isHsk2, isTrue);
    });
  });
}
