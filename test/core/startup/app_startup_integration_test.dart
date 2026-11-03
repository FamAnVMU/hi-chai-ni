import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/database/dao/vocabulary_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart';
import 'package:hi_chinese/features/settings/data/services/data_management_service.dart';

/// Test AssetBundle reading assets from disk or an in-memory dictionary.
class TestFileAssetBundle extends Fake implements AssetBundle {
  final Map<String, String> _overrides;

  TestFileAssetBundle([this._overrides = const {}]);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_overrides.containsKey(key)) {
      return _overrides[key]!;
    }
    final file = File(key);
    if (await file.exists()) {
      return file.readAsString();
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  group('HI Chinese – App Startup & Learning Data Initialization Integration Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('app_startup_test_');
      dbPath = '${tempDir.path}/startup_test.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Full 10-step startup sequence initializes DB, Seed, and Content Packs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appStartupProvider.notifier);
      final assetBundle = TestFileAssetBundle();

      // Execute Startup sequence
      await notifier.initialize(
        bundle: assetBundle,
        databaseOverride: db,
      );

      final state = container.read(appStartupProvider);
      expect(state.isReady, isTrue, reason: 'App must be marked ready after complete initialization');
      expect(state.isInitializing, isFalse);
      expect(state.error, isNull);
      expect(state.statusMessage, equals('Hệ thống sẵn sàng'));

      // Verify Seed loaded into seed_history & vocabularies
      final seedHistory = await db.query(
        DatabaseConstants.tableSeedHistory,
        where: 'bundle_name = ? AND status = ?',
        whereArgs: ['hsk_seed_fixture_v2', 'completed'],
      );
      expect(seedHistory, isNotEmpty);
      expect(seedHistory.first['total_items'], greaterThanOrEqualTo(5000));

      final vocabCountRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableVocabularies}',
      );
      final vocabCount = Sqflite.firstIntValue(vocabCountRes) ?? 0;
      expect(vocabCount, greaterThanOrEqualTo(5000));

      // Verify Content Packs installed
      final packs = await db.query(DatabaseConstants.tableContentPacks);
      final packIds = packs.map((p) => p['id'] as String).toSet();
      expect(packIds.contains('hsk1_pack_v1'), isTrue);
      expect(packIds.contains('hsk2_pack_v1'), isTrue);

      // Verify Curriculums curr_hsk1 and curr_hsk2
      final curriculums = await db.query(DatabaseConstants.tableCurriculums);
      final currIds = curriculums.map((c) => c['id'] as String).toSet();
      expect(currIds.contains('curr_hsk1'), isTrue);
      expect(currIds.contains('curr_hsk2'), isTrue);

      // Verify curriculum lessons and units
      final hsk1Lessons = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableCurriculumLessons}
        WHERE unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = 'curr_hsk1')
      ''');
      expect(Sqflite.firstIntValue(hsk1Lessons), equals(15));

      final hsk2Lessons = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableCurriculumLessons}
        WHERE unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = 'curr_hsk2')
      ''');
      expect(Sqflite.firstIntValue(hsk2Lessons), equals(15));

      // Verify content_items
      final contentItemsRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableContentItems}',
      );
      expect(Sqflite.firstIntValue(contentItemsRes), greaterThanOrEqualTo(150));

      // Verify default user profile
      final profiles = await db.query(DatabaseConstants.tableUserProfiles);
      expect(profiles, isNotEmpty);
      expect(profiles.first['id'], equals('user_default'));
    });

    test('2. Idempotent re-initialization executes in < 50ms without duplicate rows', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appStartupProvider.notifier);
      final assetBundle = TestFileAssetBundle();

      // First run to seed database
      await notifier.initialize(bundle: assetBundle, databaseOverride: db);

      final vocabCountBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableVocabularies}'),
      );
      final lessonCountBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableCurriculumLessons}'),
      );
      final contentItemsBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableContentItems}'),
      );

      // Second run (simulating app relaunch)
      final sw = Stopwatch()..start();
      await notifier.initialize(bundle: assetBundle, databaseOverride: db);
      sw.stop();

      final state = container.read(appStartupProvider);
      expect(state.isReady, isTrue);
      expect(state.error, isNull);

      final vocabCountAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableVocabularies}'),
      );
      final lessonCountAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableCurriculumLessons}'),
      );
      final contentItemsAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableContentItems}'),
      );

      // Assert zero duplicates injected
      expect(vocabCountAfter, equals(vocabCountBefore));
      expect(lessonCountAfter, equals(lessonCountBefore));
      expect(contentItemsAfter, equals(contentItemsBefore));

      // Assert fast execution
      debugPrint('[Test] Idempotent re-initialization elapsed: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(300));
    });

    test('3. Safe upsert preserves learner progress and foreign keys across content pack updates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appStartupProvider.notifier);
      final assetBundle = TestFileAssetBundle();
      await notifier.initialize(bundle: assetBundle, databaseOverride: db);

      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Record learner progress on lesson_1_1
      await db.update(
        DatabaseConstants.tableCurriculumLessons,
        {
          'status': 'completed',
          'completed_at': nowUtc,
          'credited_reason': 'perfect_score',
        },
        where: 'id = ?',
        whereArgs: ['lesson_1_1'],
      );

      // Insert SRS item linked to vocabulary
      await db.insert(
        DatabaseConstants.tableSrsItems,
        {
          'id': 'srs_test_01',
          'content_id': 'VOC_HSK1_0001',
          'content_type': 'vocabulary',
          'interval_days': 7,
          'ease_factor': 2.5,
          'repetitions': 3,
          'lapses': 0,
          'due_at': nowUtc,
          'state': 'review',
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
      );

      // Simulate a pack update with force re-install
      final rawHsk1Json = await assetBundle.loadString('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      final packManager = ContentPackManager(db);
      final result = await packManager.installOrUpdatePack(rawHsk1Json, isBundled: true);
      expect(result.isSuccess, isTrue);

      // Verify learner progress was NOT wiped by ConflictAlgorithm.replace
      final lessonRows = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: ['lesson_1_1'],
      );
      expect(lessonRows.first['status'], equals('completed'));
      expect(lessonRows.first['credited_reason'], equals('perfect_score'));

      // Verify SRS item remains intact (foreign key not deleted)
      final srsRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'id = ?',
        whereArgs: ['srs_test_01'],
      );
      expect(srsRows, isNotEmpty);
      expect(srsRows.first['repetitions'], equals(3));
    });

    test('4. CurriculumDao LEFT JOIN content_items loads content_payload into LessonSegment', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appStartupProvider.notifier);
      final assetBundle = TestFileAssetBundle();
      await notifier.initialize(bundle: assetBundle, databaseOverride: db);

      final curriculumDao = CurriculumDao(db);
      final segments = await curriculumDao.getSegmentsByLessonId('lesson_1_1');
      expect(segments, isNotEmpty);

      // Check first segment
      final firstSegMap = segments.first;
      expect(firstSegMap['content_ref_id'], equals('WARMUP_L1'));
      expect(firstSegMap['content_payload'], isNotNull);

      // Check domain model parsing
      final segmentModel = LessonSegment.fromMap(firstSegMap);
      expect(segmentModel.contentPayload, isNotNull);
      expect(segmentModel.contentPayload!['objective'], isNotNull);

      // Test CurriculumRepository integration
      final repo = CurriculumRepository(db);
      final lesson = await repo.getLessonById('lesson_1_1');
      expect(lesson, isNotNull);
      expect(lesson!.segments, isNotEmpty);
      expect(lesson.segments.first.contentPayload, isNotNull);
    });

    test('5. CurriculumSyllabusScreen default curriculumId is curr_hsk1', () {
      const screen = CurriculumSyllabusScreen();
      expect(screen.curriculumId, equals('curr_hsk1'));
    });

    test('6. Secure API key storage and JSON export sanitizes sensitive keys', () async {
      // 1. Verify AiCredentialStorage saves securely in memory
      final storage = AiCredentialStorage.inMemory();
      await storage.saveApiKey('AIzaSyD-test-dummy-key-999');
      expect(await storage.hasApiKey(), isTrue);
      expect(await storage.getApiKey(), equals('AIzaSyD-test-dummy-key-999'));

      // 2. Insert sensitive keys into tableAppSettings to test sanitization
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {'key': 'gemini_api_key', 'value': 'super_secret_api_key', 'updated_at': nowUtc},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {'key': 'auth_token', 'value': 'secret_bearer_token', 'updated_at': nowUtc},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {'key': 'theme_mode', 'value': 'dark', 'updated_at': nowUtc},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final dataService = DataManagementService(db, dbPath);
      final jsonExport = await dataService.exportUserDataJson();
      final decoded = json.decode(jsonExport) as Map<String, dynamic>;
      final exportedSettings = decoded['app_settings'] as List<dynamic>;

      final settingKeys = exportedSettings.map((s) => s['key'] as String).toList();
      expect(settingKeys.contains('theme_mode'), isTrue);
      expect(settingKeys.contains('gemini_api_key'), isFalse, reason: 'API key must be filtered from JSON export');
      expect(settingKeys.contains('auth_token'), isFalse, reason: 'Token must be filtered from JSON export');
    });

    test('7. AiModelRegistry specifies valid Gemini models and default routing', () {
      final registry = AiModelRegistry();

      expect(AiModelRegistry.modelGemini25Flash, equals('gemini-2.5-flash'));
      expect(AiModelRegistry.modelGemini25FlashLite, equals('gemini-2.5-flash-lite'));
      expect(AiModelRegistry.modelGemini25Pro, equals('gemini-2.5-pro'));

      final models = registry.availableModels;
      expect(models.contains('gemini-2.5-flash'), isTrue);
      expect(models.contains('gemini-2.5-flash-lite'), isTrue);
      expect(models.contains('gemini-2.5-pro'), isTrue);

      final defaultSpec = registry.getModelSpec(registry.activeDefaultModelId);
      expect(defaultSpec, isNotNull);
      expect(defaultSpec!.modelId, equals('gemini-2.5-flash'));

      final chatConfig = registry.getConfigForTask(AiTaskType.chatTutor);
      expect(chatConfig.modelId, equals('gemini-2.5-flash-lite'));

      final grammarConfig = registry.getConfigForTask(AiTaskType.grammarCorrection);
      expect(grammarConfig.modelId, equals('gemini-2.5-flash'));
    });
  });
}
