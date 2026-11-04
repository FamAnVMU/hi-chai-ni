import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/router/app_router.dart';
import 'package:hi_chinese/core/router/app_routes.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';
import 'package:hi_chinese/features/app_shell/presentation/screens/app_shell.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';
import 'package:hi_chinese/features/home/presentation/screens/home_screen.dart';
import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_flow_screen.dart';

class _ReadyStartupNotifier extends AppStartupNotifier {
  @override
  AppStartupState build() {
    return const AppStartupState(isInitializing: false, isReady: true);
  }

  @override
  Future<void> initialize({
    AssetBundle? bundle,
    Database? databaseOverride,
    dynamic credentialStorageOverride,
  }) async {}
}

class _CompletedOnboardingNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() {
    return const OnboardingState(
      isLoading: false,
      isCompleted: true,
      currentStep: OnboardingStep.completed,
    );
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  group('Prompt 8: AppRouteGuard & Deep Link Protection Tests', () {
    test('1. Blocks direct navigation to protected routes when onboarding is incomplete', () {
      const protectedPaths = [
        AppRoutes.home,
        AppRoutes.learning,
        AppRoutes.aiTutor,
        AppRoutes.review,
        AppRoutes.profile,
      ];

      for (final path in protectedPaths) {
        final decision = AppRouteGuard.evaluate(
          path: path,
          isOnboardingCompleted: false,
        );
        expect(
          decision,
          equals(RouteGuardAction.redirectToOnboarding),
          reason: 'Uncompleted onboarding must block $path',
        );
      }
    });

    test('2. Intercepts custom URI scheme deep links (hichinese://...) before onboarding completes', () {
      const deepLinks = [
        'hichinese://home',
        'hichinese://learning',
        'hichinese://ai-tutor',
        'hichinese://profile',
        'https://app.hichinese.com/home',
      ];

      for (final uri in deepLinks) {
        final decision = AppRouteGuard.evaluate(
          path: uri,
          isOnboardingCompleted: false,
        );
        expect(
          decision,
          equals(RouteGuardAction.redirectToOnboarding),
          reason: 'Deep link $uri must be intercepted to onboarding',
        );
      }
    });

    test('3. Allows direct navigation and deep links once onboarding is completed', () {
      const allowedPaths = [
        AppRoutes.home,
        AppRoutes.learning,
        AppRoutes.aiTutor,
        'hichinese://home',
        'hichinese://learning',
      ];

      for (final path in allowedPaths) {
        final decision = AppRouteGuard.evaluate(
          path: path,
          isOnboardingCompleted: true,
        );
        expect(
          decision,
          equals(RouteGuardAction.allow),
          reason: 'Completed onboarding must allow $path',
        );
      }
    });

    test('4. Redirects /onboarding to /home once onboarding is completed', () {
      final decision = AppRouteGuard.evaluate(
        path: AppRoutes.onboarding,
        isOnboardingCompleted: true,
      );
      expect(decision, equals(RouteGuardAction.redirectToHome));
    });

    test('5. AppRouter route generator correctly redirects un-onboarded direct routes', () {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.home),
        container as dynamic,
      );

      expect(route.settings.name, equals(AppRoutes.onboarding));
    });

    test('6. AppRouter route generator allows home route when onboarding is completed', () {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
          onboardingProvider.overrideWith(_CompletedOnboardingNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.home),
        container as dynamic,
      );

      expect(route.settings.name, equals(AppRoutes.home));
    });
  });

  group('Prompt 8: Widget Presentation Tests', () {
    testWidgets('7. Fresh Install: Enforces OnboardingFlowScreen and blocks HomeScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingFlowScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Cấu hình AI Trợ Giảng (Tùy chọn)'), findsOneWidget);
    });

    testWidgets('8. Version Upgrade / Returning User: Renders HomeScreen directly without Onboarding', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
            onboardingProvider.overrideWith(_CompletedOnboardingNotifier.new),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingFlowScreen), findsNothing);
    });
  });

  group('Prompt 8: Offline, Upgrade & Data Integrity Integration Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('onboarding_guard_test_');
      dbPath = '${tempDir.path}/test_guard.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('9. Upgrade from previous version preserves existing onboarding completion flag in SQLite', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {
          'key': OnboardingNotifier.keyOnboardingCompleted,
          'value': 'true',
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onboardingProvider.notifier).reloadState();
      final state = container.read(onboardingProvider);
      expect(state.isCompleted, isTrue);
      expect(state.currentStep, equals(OnboardingStep.completed));
    });

    test('10. Offline End-to-End Onboarding: skips AI, sets profile and creates goal without network', () async {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onboardingProvider.notifier);

      await notifier.setStep(OnboardingStep.placementTest, skippedAi: true);
      expect(container.read(onboardingProvider).hasSkippedAiSetup, isTrue);

      await notifier.completePlacementTest(2);
      expect(container.read(onboardingProvider).assessedHskLevel, equals(2));

      await notifier.completePersonalization(
        dailyMinutes: 45,
        focusSkill: 'speaking',
        learningPurpose: 'businessWork',
        showPinyin: true,
        scriptType: 'simplified',
      );

      final state = container.read(onboardingProvider);
      expect(state.isCompleted, isTrue);
      expect(state.currentStep, equals(OnboardingStep.completed));

      final settings = await db.query(DatabaseConstants.tableAppSettings);
      final settingsMap = {for (var r in settings) r['key'] as String: r['value'] as String};
      expect(settingsMap['onboarding_completed'], equals('true'));
      expect(settingsMap['roadmap_initialized'], equals('true'));
      expect(settingsMap['priority_focus_skill'], equals('speaking'));

      final goals = await db.query(
        DatabaseConstants.tableLearnerGoals,
        where: 'is_active = 1',
      );
      expect(goals.length, equals(1));
      expect(goals.first['target_hsk_level'], equals(3));
      expect(goals.first['daily_minutes'], equals(45));

      final profile = await db.query(DatabaseConstants.tableUserProfiles, limit: 1);
      expect(profile.first['current_hsk_level'], equals(2));
      expect(profile.first['daily_minutes'], equals(45));
    });

    test('11. Data Integrity: Preserves existing completed lessons during roadmap unlock', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert('content_packs', {
        'id': 'pack_test',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'Test Pack',
        'status': 'installed',
        'updated_at': nowUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('curriculums', {
        'id': 'curr_test',
        'pack_id': 'pack_test',
        'code': 'HSK1',
        'standard_name': 'Test HSK 1',
        'hsk_level': 1,
        'total_units': 1,
        'total_lessons': 2,
        'created_at': nowUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('curriculum_units', {
        'id': 'unit_test',
        'curriculum_id': 'curr_test',
        'order_index': 1,
        'title_vi': 'Unit 1',
        'title_zh': '第一单元',
        'is_locked': 0,
        'created_at': nowUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('curriculum_lessons', {
        'id': 'les_1',
        'unit_id': 'unit_test',
        'order_index': 1,
        'title_vi': 'Lesson 1 Completed',
        'title_zh': '第一课',
        'pinyin': 'dì yī kè',
        'status': 'completed',
        'is_locked': 0,
        'completed_at': '2026-01-01T00:00:00.000Z',
        'credited_reason': 'normal_study',
        'created_at': nowUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('curriculum_lessons', {
        'id': 'les_2',
        'unit_id': 'unit_test',
        'order_index': 2,
        'title_vi': 'Lesson 2 Locked',
        'title_zh': '第二课',
        'pinyin': 'dì èr kè',
        'status': 'locked',
        'is_locked': 1,
        'created_at': nowUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final handler = PlacementUnlockHandler(db);
      await handler.creditLessonsUpToLevel(hskLevel: 1, targetLessonOrder: 2);

      final les1 = (await db.query('curriculum_lessons', where: 'id = ?', whereArgs: ['les_1'])).first;
      expect(les1['status'], equals('completed'));
      expect(les1['completed_at'], equals('2026-01-01T00:00:00.000Z'));
      expect(les1['credited_reason'], equals('normal_study'));

      final les2 = (await db.query('curriculum_lessons', where: 'id = ?', whereArgs: ['les_2'])).first;
      expect(les2['status'], equals('not_started'));
      expect(les2['is_locked'], equals(0));
    });

    test('12. Idempotency: Multiple personalization completions do not create duplicate active goals', () async {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onboardingProvider.notifier);

      await notifier.completePersonalization(dailyMinutes: 15, focusSkill: 'reading');
      await notifier.completePersonalization(dailyMinutes: 30, focusSkill: 'speaking');
      await notifier.completePersonalization(dailyMinutes: 60, focusSkill: 'listening');

      final activeGoals = await db.query(
        DatabaseConstants.tableLearnerGoals,
        where: 'is_active = 1',
      );
      expect(activeGoals.length, equals(1));
      expect(activeGoals.first['daily_minutes'], equals(60));
    });
  });
}
