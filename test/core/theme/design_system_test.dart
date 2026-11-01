import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/design_system/presentation/screens/design_system_demo_screen.dart';

/// Helper to calculate relative luminance according to WCAG 2.2 formula
double calculateRelativeLuminance(Color color) {
  double transform(double val) {
    return val <= 0.03928
        ? val / 12.92
        : math.pow((val + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = transform(color.r);
  final g = transform(color.g);
  final b = transform(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Helper to calculate WCAG contrast ratio between two colors
double calculateContrastRatio(Color foreground, Color background) {
  final l1 = calculateRelativeLuminance(foreground);
  final l2 = calculateRelativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Design System Tokens & Contrast Tests', () {
    test('Palette constants conform to plan', () {
      expect(AppColors.limeGreen, const Color(0xFFA3D635));
      expect(AppColors.offWhite, const Color(0xFFF6FAF2));
      expect(AppColors.darkForestBg, const Color(0xFF121811));
      expect(AppColors.darkForestSurface, const Color(0xFF1A2418));
      expect(AppColors.darkForestCard, const Color(0xFF243022));
    });

    test('Spacing tokens adhere to standard 4/8pt grid', () {
      expect(AppSpacing.none, 0.0);
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
      expect(AppSpacing.xxxl, 32.0);
      expect(AppSpacing.huge, 48.0);
    });

    test('Radius tokens conform to design standards', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 24.0);
      expect(AppRadius.full, 999.0);
    });

    test('Dimension tokens enforce min 48x48dp touch target', () {
      expect(AppDimensions.minTouchTarget, 48.0);
      expect(AppDimensions.inputMinHeight, greaterThanOrEqualTo(48.0));
      expect(AppDimensions.buttonHeightLg, greaterThanOrEqualTo(48.0));
    });

    test('Typography includes Chinese and Vietnamese fallbacks', () {
      expect(AppTypography.fontFallbacks, contains('Noto Sans SC'));
      expect(AppTypography.fontFallbacks, contains('Roboto'));

      final textTheme = AppTypography.createTextTheme(Colors.white, Colors.white70);
      expect(textTheme.bodyLarge?.fontFamilyFallback, contains('Noto Sans SC'));
      expect(textTheme.titleMedium?.fontFamilyFallback, contains('Noto Sans SC'));
      expect(AppTypography.hanziLarge().fontSize, 40);
      expect(AppTypography.hanziMedium().fontSize, 24);
      expect(AppTypography.pinyin().fontSize, 14);
    });

    test('Dark theme primary text contrast satisfies WCAG AA (>= 4.5:1)', () {
      // Dark theme primary button: text (onPrimary) on limeGreen (primary)
      final ratio = calculateContrastRatio(
        AppColors.darkColorScheme.onPrimary,
        AppColors.darkColorScheme.primary,
      );
      // Dark Forest text on Lime Green gives > 10:1 contrast
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Light theme primary button text contrast satisfies WCAG AA (>= 4.5:1)', () {
      final ratio = calculateContrastRatio(
        AppColors.lightColorScheme.onPrimary, // white
        AppColors.lightColorScheme.primary, // #53740A
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Dark theme body text on surface contrast satisfies WCAG AA', () {
      final ratio = calculateContrastRatio(
        AppColors.darkColorScheme.onSurface,
        AppColors.darkColorScheme.surface,
      );
      expect(ratio, greaterThanOrEqualTo(7.0)); // AAA level
    });
  });

  group('ThemeModeNotifier Tests', () {
    test('Default mode is dark and toggles correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('Light and dark ThemeData can be instantiated without errors', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(dark.scaffoldBackgroundColor, AppColors.darkForestBg);
      expect(light.scaffoldBackgroundColor, AppColors.offWhite);
    });
  });

  group('Reusable Component Widget Tests', () {
    testWidgets('HiButton renders text, icon, and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HiButton(
              text: 'Bắt đầu học',
              icon: const Icon(Icons.school),
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Bắt đầu học'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);

      await tester.tap(find.text('Bắt đầu học'));
      expect(tapped, isTrue);
    });

    testWidgets('HiButton enforces touch target >= 48dp even for small size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: HiButton(
                text: 'Small Button',
                size: HiButtonSize.sm,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(HiButton);
      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('HiButton shows loading spinner and disables click when loading', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HiButton(
              text: 'Lưu bài',
              isLoading: true,
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Lưu bài'), findsNothing);

      await tester.tap(find.byType(HiButton));
      expect(tapped, isFalse);
    });

    testWidgets('HiTextField renders label, hint, error, and supports password toggle', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HiTextField(
              controller: controller,
              label: 'Mật khẩu bảo mật',
              hintText: 'Nhập mật khẩu...',
              isPassword: true,
            ),
          ),
        ),
      );

      expect(find.text('Mật khẩu bảo mật'), findsOneWidget);
      expect(find.text('Nhập mật khẩu...'), findsOneWidget);

      // Verify toggle button
      final toggleBtn = find.byTooltip('Hiện');
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pump();

      expect(find.byTooltip('Ẩn'), findsOneWidget);
    });

    testWidgets('HiCard handles tap and renders children', (tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HiCard(
              onTap: () {
                cardTapped = true;
              },
              child: const Text('Nội dung thẻ HSK 1'),
            ),
          ),
        ),
      );

      expect(find.text('Nội dung thẻ HSK 1'), findsOneWidget);
      await tester.tap(find.text('Nội dung thẻ HSK 1'));
      expect(cardTapped, isTrue);
    });

    testWidgets('HiChip renders neutral, selection, and status variants', (tester) async {
      bool chipTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                HiChip(
                  label: 'HSK 3',
                  isSelected: true,
                  onTap: () {
                    chipTapped = true;
                  },
                ),
                const HiChip(
                  label: 'Thành công',
                  status: HiChipStatus.success,
                ),
                const HiChip(
                  label: 'Cảnh báo',
                  status: HiChipStatus.warning,
                ),
                const HiChip(
                  label: 'Lỗi',
                  status: HiChipStatus.error,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('HSK 3'), findsOneWidget);
      expect(find.text('Thành công'), findsOneWidget);
      expect(find.text('Cảnh báo'), findsOneWidget);
      expect(find.text('Lỗi'), findsOneWidget);

      await tester.tap(find.text('HSK 3'));
      expect(chipTapped, isTrue);
    });

    testWidgets('HiEmptyState and HiErrorState render with actions', (tester) async {
      bool retryClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HiErrorState(
              title: 'Lỗi nạp bài học',
              message: 'Không thể kết nối cơ sở dữ liệu',
              onRetry: () {
                retryClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Lỗi nạp bài học'), findsOneWidget);
      expect(find.text('Không thể kết nối cơ sở dữ liệu'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(retryClicked, isTrue);
    });

    testWidgets('Text scaling is not locked and handles 1.5x scale without throwing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        'Tiếng Việt có dấu: ệ, ẩ, ỹ, ớ và 汉字: 你好，世界！',
                        style: TextStyle(fontSize: 16),
                      ),
                      HiButton(text: 'Nút bấm thích ứng font scale'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tiếng Việt có dấu: ệ, ẩ, ỹ, ớ và 汉字: 你好，世界！'), findsOneWidget);
      expect(find.text('Nút bấm thích ứng font scale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DesignSystemDemoScreen renders fully in ProviderScope', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DesignSystemDemoScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Design System Showcase'), findsOneWidget);
      expect(find.text('1. Theme Mode Switcher (Chế độ giao diện)'), findsOneWidget);
      expect(find.text('2. Bảng Màu Semantic (Color Tokens)'), findsOneWidget);
      expect(find.text('3. Typography & Đa Ngữ (Việt - Trung)'), findsOneWidget);
      expect(find.text('3.1. Component RubyText (Chữ Hán kèm Pinyin)'), findsOneWidget);
      expect(find.text('学'), findsAtLeastNWidgets(1));
      expect(find.text('xué'), findsAtLeastNWidgets(1));
    });
  });
}
