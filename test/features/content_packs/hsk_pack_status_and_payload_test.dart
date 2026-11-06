import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_remote_service.dart';
import 'package:hi_chinese/features/content_packs/presentation/providers/content_pack_providers.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Content Pack Status API & Payload Safe Parsing Tests', () {
    late Database db;
    late Directory tempDir;
    late ContentPackRemoteService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pack_status_test_');
      final dbPath = '${tempDir.path}/test_status.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      service = ContentPackRemoteService(db: db);
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. isHskLevelInstalled returns false when database has no pack or curriculum', () async {
      final isInstalled = await service.isHskLevelInstalled(4);
      expect(isInstalled, isFalse);
    });

    test('2. isHskLevelInstalled returns false when pack exists but curriculum is missing or has 0 lessons', () async {
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk4_pack_v1',
        'hsk_level': 4,
        'version': '1.0.0',
        'title': 'HSK 4',
        'status': 'installed',
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(await service.isHskLevelInstalled(4), isFalse);

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk4',
        'pack_id': 'hsk4_pack_v1',
        'code': 'HSK4',
        'standard_name': 'HSK 4 Standard',
        'hsk_level': 4,
        'total_units': 1,
        'total_lessons': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(await service.isHskLevelInstalled(4), isFalse);
    });

    test('3. isHskLevelInstalled returns true when both content_packs (installed/bundled) and curriculum (lessons > 0) exist', () async {
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk1_pack_v1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'HSK 1',
        'status': 'bundled',
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk1',
        'pack_id': 'hsk1_pack_v1',
        'code': 'HSK1',
        'standard_name': 'HSK 1 Standard',
        'hsk_level': 1,
        'total_units': 3,
        'total_lessons': 15,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(await service.isHskLevelInstalled(1), isTrue);

      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk5_pack_v1',
        'hsk_level': 5,
        'version': '1.0.0',
        'title': 'HSK 5',
        'status': 'installed',
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk5',
        'pack_id': 'hsk5_pack_v1',
        'code': 'HSK5',
        'standard_name': 'HSK 5 Standard',
        'hsk_level': 5,
        'total_units': 10,
        'total_lessons': 36,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(await service.isHskLevelInstalled(5), isTrue);
    });

    test('4. getHskPackManifest retrieves metadata or returns null when absent', () async {
      final notFound = await service.getHskPackManifest(99);
      expect(notFound, isNull);

      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk6_pack_v1',
        'hsk_level': 6,
        'version': '1.0.0',
        'title': 'Giáo trình chuẩn HSK 6',
        'description': '2.500 từ vựng học thuật đỉnh cao',
        'is_bundled': 0,
        'status': 'installed',
        'size_bytes': 1544224,
        'checksum_sha256': '0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf',
        'dependencies_json': json.encode(['hsk5_pack_v1']),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final manifest = await service.getHskPackManifest(6);
      expect(manifest, isNotNull);
      expect(manifest!.packId, equals('hsk6_pack_v1'));
      expect(manifest.hskLevel, equals(6));
      expect(manifest.title, equals('Giáo trình chuẩn HSK 6'));
      expect(manifest.sizeBytes, equals(1544224));
      expect(manifest.sha256, equals('0bb04e558f7c3c19cda4c43217a49cf3446d2dc0a485e327dfad8d0e93b5c8cf'));
      expect(manifest.dependencies, contains('hsk5_pack_v1'));
    });

    test('5. Riverpod providers isHskLevelInstalledProvider & hskPackMetadataProvider respond < 10ms', () async {
      await db.insert(DatabaseConstants.tableContentPacks, {
        'id': 'hsk2_pack_v1',
        'hsk_level': 2,
        'version': '1.0.0',
        'title': 'HSK 2',
        'status': 'bundled',
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert(DatabaseConstants.tableCurriculums, {
        'id': 'curr_hsk2',
        'pack_id': 'hsk2_pack_v1',
        'code': 'HSK2',
        'standard_name': 'HSK 2 Standard',
        'hsk_level': 2,
        'total_units': 3,
        'total_lessons': 15,
        'created_at': DateTime.now().toIso8601String(),
      });

      final container = ProviderContainer(
        overrides: [
          contentPackRemoteServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(isHskLevelInstalledProvider(2).future);
      await container.read(hskPackMetadataProvider(2).future);

      final stopwatch = Stopwatch()..start();
      final installed = await container.read(isHskLevelInstalledProvider(2).future);
      final manifest = await container.read(hskPackMetadataProvider(2).future);
      stopwatch.stop();

      expect(installed, isTrue);
      expect(manifest, isNotNull);
      expect(manifest!.packId, equals('hsk2_pack_v1'));
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });

    test('6. CurriculumDao & LessonSegment safeParsePayload deep normalizes nested child maps in lists', () {
      final dynamic rawUntyped = <dynamic, dynamic>{
        'words': <dynamic>[
          <dynamic, dynamic>{'hanzi': '你好', 'pinyin': 'nǐ hǎo'},
          <dynamic, dynamic>{'hanzi': '再见', 'pinyin': 'zài jiàn'},
        ],
        'points': <dynamic>[
          <dynamic, dynamic>{
            'title': 'Point 1',
            'structure': 'Sub + Verb',
            'explanation': 'Desc',
            'examples': <dynamic>[
              <dynamic, dynamic>{'zh': '我是学生', 'vi': 'Tôi là học sinh'}
            ],
          }
        ],
        'lines': <dynamic>[
          <dynamic, dynamic>{'speaker': 'A', 'zh': '你好'}
        ],
        'exercises': <dynamic>[
          <dynamic, dynamic>{'question': 'Q1', 'options': <dynamic>['A', 'B']}
        ],
      };

      final parsedFromDao = CurriculumDao.safeParsePayload(rawUntyped);
      expect(parsedFromDao, isNotNull);
      expect(parsedFromDao!['words'], isA<List<dynamic>>());

      final wordsList = parsedFromDao['words'] as List<dynamic>;
      expect(wordsList.first, isA<Map<String, dynamic>>());
      final firstWord = wordsList.first as Map<String, dynamic>;
      expect(firstWord['hanzi'], equals('你好'));

      final pointsList = parsedFromDao['points'] as List<dynamic>;
      final firstPoint = pointsList.first as Map<String, dynamic>;
      final examplesList = firstPoint['examples'] as List<dynamic>;
      expect(examplesList.first, isA<Map<String, dynamic>>());

      final segment = LessonSegment.fromMap({
        'id': 'seg_test',
        'lesson_id': 'lesson_test',
        'step_order': 1,
        'segment_type': 'grammar',
        'title': 'Grammar Lesson',
        'content_payload': rawUntyped,
      });

      expect(segment.contentPayload, isNotNull);
      final grammarPoints = segment.grammarPoints;
      expect(grammarPoints.length, equals(1));
      expect(grammarPoints.first.title, equals('Point 1'));
      expect(grammarPoints.first.examples.first['zh'], equals('我是学生'));
    });

    test('7. safeParsePayload handles null, empty string, invalid JSON gracefully', () {
      expect(CurriculumDao.safeParsePayload(null), isNull);
      expect(CurriculumDao.safeParsePayload(''), isNull);
      expect(CurriculumDao.safeParsePayload('   '), isNull);
      expect(CurriculumDao.safeParsePayload('{invalid json}'), isNull);
      expect(CurriculumDao.safeParsePayload(12345), isNull);

      expect(LessonSegment.safeParsePayload(null), isNull);
      expect(LessonSegment.safeParsePayload(''), isNull);
      expect(LessonSegment.safeParsePayload('   '), isNull);
      expect(LessonSegment.safeParsePayload('{invalid json}'), isNull);
    });
  });
}
