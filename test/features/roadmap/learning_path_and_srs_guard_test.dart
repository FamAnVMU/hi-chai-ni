import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';
import 'package:hi_chinese/features/curriculum/data/placement_unlock_handler.dart';
import 'package:hi_chinese/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:hi_chinese/features/roadmap/domain/models/roadmap_models.dart';
import 'package:hi_chinese/features/vocabulary_srs/presentation/providers/srs_providers.dart';

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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  group('LearningPathType Domain Model & Serialization Tests', () {
    test('enum contains focused and comprehensive values', () {
      expect(LearningPathType.values, contains(LearningPathType.focused));
      expect(LearningPathType.values, contains(LearningPathType.comprehensive));
      expect(LearningPathType.values.length, equals(2));
    });

    test('displayName and description return valid localized strings', () {
      expect(LearningPathType.focused.displayName, isNotEmpty);
      expect(LearningPathType.comprehensive.displayName, contains('Toàn diện'));
      expect(LearningPathType.focused.description, isNotEmpty);
      expect(LearningPathType.comprehensive.description, contains('6 kỹ năng'));
    });

    test('dbValue matches enum name', () {
      expect(LearningPathType.focused.dbValue, equals('focused'));
      expect(LearningPathType.comprehensive.dbValue, equals('comprehensive'));
    });

    test('fromDb deserializes balanced and comprehensive to comprehensive', () {
      expect(LearningPathTypeExtension.fromDb('balanced'), equals(LearningPathType.comprehensive));
      expect(LearningPathTypeExtension.fromDb('comprehensive'), equals(LearningPathType.comprehensive));
      expect(LearningPathTypeExtension.fromDb('focused'), equals(LearningPathType.focused));
      expect(LearningPathTypeExtension.fromDb('unknown'), equals(LearningPathType.focused));
      expect(LearningPathTypeExtension.fromDb(null), equals(LearningPathType.focused));
    });
  });

  group('Onboarding & LearningPathType Persistence Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('learning_path_test_');
      dbPath = '${tempDir.path}/test_path.db';
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

    test('Selecting comprehensive path persists balanced to app_settings', () async {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onboardingProvider.notifier);

      final success = await notifier.completePersonalization(
        dailyMinutes: 30,
        focusSkill: 'reading',
        learningPathType: LearningPathType.comprehensive,
      );
      expect(success, isTrue);

      final state = container.read(onboardingProvider);
      expect(state.learningPathType, equals(LearningPathType.comprehensive));
      expect(state.focusSkill, equals('balanced'));

      final settings = await db.query(DatabaseConstants.tableAppSettings);
      final settingsMap = {for (final row in settings) row['key'] as String: row['value'] as String};
      expect(settingsMap[OnboardingNotifier.keyPrioritySkill], equals('balanced'));
      expect(settingsMap[OnboardingNotifier.keyLearningPathType], equals('balanced'));
    });

    test('Passing focusSkill as balanced selects comprehensive path', () async {
      final container = ProviderContainer(
        overrides: [
          appStartupProvider.overrideWith(_ReadyStartupNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onboardingProvider.notifier);

      final success = await notifier.completePersonalization(
        dailyMinutes: 15,
        focusSkill: 'balanced',
      );
      expect(success, isTrue);

      final state = container.read(onboardingProvider);
      expect(state.learningPathType, equals(LearningPathType.comprehensive));
      expect(state.focusSkill, equals('balanced'));

      final settings = await db.query(DatabaseConstants.tableAppSettings);
      final settingsMap = {for (final row in settings) row['key'] as String: row['value'] as String};
      expect(settingsMap[OnboardingNotifier.keyPrioritySkill], equals('balanced'));
      expect(settingsMap[OnboardingNotifier.keyLearningPathType], equals('balanced'));
    });

    test('Reloading state restores comprehensive learningPathType from app_settings', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {
          'key': OnboardingNotifier.keyLearningPathType,
          'value': 'balanced',
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {
          'key': OnboardingNotifier.keyPrioritySkill,
          'value': 'balanced',
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
      expect(state.learningPathType, equals(LearningPathType.comprehensive));
      expect(state.focusSkill, equals('balanced'));
    });
  });

  group('hasCompletedLessonsProvider Guard Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('srs_guard_test_');
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

    test('returns false when user has not completed any lessons', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCompleted = await container.read(hasCompletedLessonsProvider.future);
      expect(hasCompleted, isFalse);
    });

    test('returns false after placement test completes and unlocks level', () async {
      final unlockHandler = PlacementUnlockHandler(db);
      await unlockHandler.unlockForRecommendedLevel(2);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCompleted = await container.read(hasCompletedLessonsProvider.future);
      expect(hasCompleted, isFalse);
    });

    test('returns false when lesson_progress has status completed but source placement_test', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_test_placement',
          'lesson_id': 'lesson_hsk1_1',
          'unit_id': 'unit_1',
          'hsk_level': 1,
          'status': 'completed',
          'source': 'placement_test',
          'completion_score': 1.0,
          'evidence_count': 1,
          'started_at': nowUtc,
          'completed_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCompleted = await container.read(hasCompletedLessonsProvider.future);
      expect(hasCompleted, isFalse);
    });

    test('returns true after learner completes a curriculum lesson', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_test_curriculum',
          'lesson_id': 'lesson_hsk1_1',
          'unit_id': 'unit_1',
          'hsk_level': 1,
          'status': 'completed',
          'source': 'curriculum_lesson',
          'completion_score': 0.95,
          'evidence_count': 1,
          'started_at': nowUtc,
          'completed_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCompleted = await container.read(hasCompletedLessonsProvider.future);
      expect(hasCompleted, isTrue);
    });

    test('returns true when legacy lesson_progress has completed status with null source', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_test_legacy',
          'lesson_id': 'lesson_hsk1_2',
          'unit_id': 'unit_1',
          'hsk_level': 1,
          'status': 'completed',
          'source': null,
          'completion_score': 0.85,
          'evidence_count': 1,
          'started_at': nowUtc,
          'completed_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCompleted = await container.read(hasCompletedLessonsProvider.future);
      expect(hasCompleted, isTrue);
    });
  });
}
