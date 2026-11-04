import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/app_shell/presentation/providers/app_shell_providers.dart';
import 'package:hi_chinese/features/app_shell/presentation/screens/app_shell.dart';
import 'package:hi_chinese/features/home/home.dart';
import 'package:hi_chinese/features/app_shell/presentation/widgets/hi_bottom_nav_bar.dart';
import 'package:hi_chinese/features/profile/profile.dart';
import 'package:hi_chinese/features/settings/settings.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({
    AppTab initialTab = AppTab.home,
    bool initialUnsaved = false,
    AppStartupState startupState = const AppStartupState(
      isInitializing: false,
      isReady: true,
      error: null,
      statusMessage: 'Ready',
    ),
  }) {
    return ProviderScope(
      overrides: [
        appStartupProvider.overrideWith(
          () => _MockAppStartupNotifier(startupState),
        ),
        srsStudySessionProvider.overrideWith(
          () => _MockSrsStudySessionNotifier(),
        ),
        srsDueCountProvider.overrideWith(
          () => _MockSrsDueCountNotifier(),
        ),
        userProfileProvider.overrideWith(
          () => _MockUserProfileNotifier(),
        ),
        goalHistoryProvider.overrideWith(
          (ref) => Future.value([]),
        ),
        microphoneStatusProvider.overrideWith(
          (ref) => Future.value(PermissionStatus.granted),
        ),
        onboardingProvider.overrideWith(
          () => _MockOnboardingNotifier(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          return MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AppShell(),
          );
        },
      ),
    );
  }

  group('AppShell Tab Navigation Tests', () {
    testWidgets('Renders all 5 tabs and starts on HomeScreen', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom bar tabs exist
      expect(find.byType(HiBottomNavBar), findsOneWidget);
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Học tập'), findsOneWidget);
      expect(find.text('AI Tutor'), findsAtLeastNWidgets(1));
      expect(find.text('Ôn tập'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);

      // Home Screen content is active
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Tapping Learning tab switches to LearningScreen', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Học tập' in bottom bar
      await tester.tap(find.text('Học tập'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies LearningScreen is displayed
      expect(find.text('Lộ Trình Học Tập'), findsOneWidget);
      expect(find.text('Khảo sát năng lực đầu vào'), findsOneWidget);
    });

    testWidgets('Tapping center prominent AI Tutor button switches to AiTutorTabScreen', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Center prominent button has ValueKey tab_ai_tutor
      final aiTutorFinder = find.byKey(const ValueKey('tab_ai_tutor'));
      expect(aiTutorFinder, findsOneWidget);

      await tester.tap(aiTutorFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies AiTutorTabScreen content is displayed
      expect(find.text('Nhắn tin'), findsOneWidget);
      expect(find.text('Hội thoại'), findsOneWidget);
    });

    testWidgets('Tapping Review tab switches to ReviewScreen with SM-2 flashcard', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Ôn tập'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ôn Tập Ngắt Quãng (SM-2)'), findsOneWidget);
      expect(find.text('Cần ôn hôm nay'), findsOneWidget);
      expect(find.text('Xem đáp án (Lật thẻ)'), findsOneWidget);
    });

    testWidgets('Tapping Profile tab switches to ProfileScreen with settings', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cá nhân'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Cá Nhân & Cài Đặt'), findsOneWidget);
      expect(find.text('Giao Diện & Tùy Chọn Đọc'), findsOneWidget);
    });
  });

  group('Android Back Button & State Preservation Tests', () {
    testWidgets('Back button on non-home tab navigates back to Home tab first', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Review tab
      await tester.tap(find.text('Ôn tập'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Ôn Tập Ngắt Quãng (SM-2)'), findsOneWidget);

      // Simulate Android back button press
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies we returned to Home tab
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Back button with unsaved changes shows confirmation dialog', (tester) async {
      late WidgetRef savedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartupProvider.overrideWith(
              () => _MockAppStartupNotifier(
                const AppStartupState(isInitializing: false, isReady: true),
              ),
            ),
            onboardingProvider.overrideWith(
              () => _MockOnboardingNotifier(),
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              savedRef = ref;
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const AppShell(),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Set unsaved changes flag
      savedRef.read(hasUnsavedChangesProvider.notifier).setHasUnsavedChanges(true);
      await tester.pump();

      // Simulate back button
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirmation dialog should be visible
      expect(find.text('Chưa lưu thay đổi'), findsOneWidget);
      expect(find.text('Bạn có dữ liệu chưa lưu. Bạn có chắc chắn muốn thoát không?'), findsOneWidget);
      expect(find.text('Ở lại'), findsOneWidget);

      // Dismiss dialog by staying
      await tester.tap(find.text('Ở lại'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Chưa lưu thay đổi'), findsNothing);
    });

    testWidgets('IndexedStack preserves text input state across tab switches', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Go to AI Tutor tab
      final aiTutorFinder = find.byKey(const ValueKey('tab_ai_tutor'));
      await tester.tap(aiTutorFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Enter draft text in input
      final inputFinder = find.byType(HiTextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Câu hỏi kiểm tra lưu trạng thái');
      await tester.pump();

      // Switch to Profile tab
      await tester.tap(find.text('Cá nhân'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Cá Nhân & Cài Đặt'), findsOneWidget);

      // Switch back to AI Tutor tab
      await tester.tap(aiTutorFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify draft text is preserved without reset
      expect(find.text('Câu hỏi kiểm tra lưu trạng thái'), findsOneWidget);
    });
  });

  group('Startup & Initialization Lifecycle Tests', () {
    testWidgets('Displays loading indicator while isInitializing is true', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          startupState: const AppStartupState(
            isInitializing: true,
            isReady: false,
            statusMessage: 'Đang kết nối SQLite offline...',
          ),
        ),
      );

      expect(find.text('Đang kết nối SQLite offline...'), findsOneWidget);
      expect(find.byType(HiLoadingIndicator), findsOneWidget);
      expect(find.byType(HiBottomNavBar), findsNothing);
    });

    testWidgets('Displays HiErrorState when startup error occurs and allows retry', (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartupProvider.overrideWith(
              () => _MockAppStartupNotifier(
                const AppStartupState(
                  isInitializing: false,
                  isReady: false,
                  error: 'SQLite disk I/O error',
                ),
                onRetry: () => retryCalled = true,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AppShell(),
          ),
        ),
      );

      expect(find.text('Khởi động ứng dụng thất bại'), findsOneWidget);
      expect(find.text('SQLite disk I/O error'), findsOneWidget);
      expect(find.text('Thử lại kết nối'), findsOneWidget);

      await tester.tap(find.text('Thử lại kết nối'));
      expect(retryCalled, isTrue);
    });

    testWidgets('Renders bottom navigation bar without overflow on narrow 320dp screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Check no overflow exception
      expect(tester.takeException(), isNull);
      expect(find.byType(HiBottomNavBar), findsOneWidget);
    });
  });
}

class _MockAppStartupNotifier extends AppStartupNotifier {
  final AppStartupState _initial;
  final VoidCallback? onRetry;

  _MockAppStartupNotifier(this._initial, {this.onRetry});

  @override
  AppStartupState build() {
    return _initial;
  }

  @override
  Future<void> initialize({
    AssetBundle? bundle,
    Database? databaseOverride,
    dynamic credentialStorageOverride,
  }) async {
    onRetry?.call();
  }
}

class _MockSrsStudySessionNotifier extends SrsStudySessionNotifier {
  @override
  Future<SrsStudySession> build() async {
    final card = SrsFlashcardItem(
      id: 'VOCAB_TEST',
      simplified: '银行',
      pinyin: 'yínháng',
      hskLevel: 2,
      meaningVi: 'Ngân hàng',
      srsState: SrsCardState(
        id: 'SRS_TEST',
        contentId: 'VOCAB_TEST',
        dueAt: DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      estimatedIntervalDays: const {
        SrsRating.again: 1,
        SrsRating.hard: 2,
        SrsRating.good: 4,
        SrsRating.easy: 8,
      },
    );
    return SrsStudySession(queue: [card]);
  }
}

class _MockSrsDueCountNotifier extends SrsDueCountNotifier {
  @override
  Future<int> build() async => 5;
}

class _MockUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile> build() async => UserProfile.defaultProfile();
}

class _MockOnboardingNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() {
    return const OnboardingState(
      isLoading: false,
      isCompleted: true,
      currentStep: OnboardingStep.completed,
    );
  }
}
