import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_remote_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(sqfliteFfiInit);

  group('Wave 2 ContentPacks: HSK3 Checksum, VOC_* Dedup & Late Placement Unlock', () {
    late Directory tempDir;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wave2_packs_test_');
      db = await AppDatabase.instance.open(
        customPath: '${tempDir.path}/packs.db',
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('AUD-042: hsk3_pack_v1 has valid non-empty SHA-256 and downloads/installs cleanly', () async {
      final hsk3Info = ContentPackRemoteService.getAvailablePacks()
          .firstWhere((p) => p.packId == 'hsk3_pack_v1');
      expect(hsk3Info.sha256Checksum, isNotEmpty);

      final raw = await File('assets/data/content_packs/hsk3/hsk3_pack_v1.json').readAsString();
      expect(ContentPackManager.computeChecksum(raw), equals(hsk3Info.sha256Checksum));

      final client = _MockHttpClient();
      when(() => client.get(Uri.parse(hsk3Info.downloadUrl))).thenAnswer(
        (_) async => http.Response.bytes(utf8.encode(raw), 200),
      );

      final remote = ContentPackRemoteService(db: db, httpClient: client);
      final result = await remote.downloadAndInstallPack(packInfo: hsk3Info);
      expect(result.isSuccess, isTrue, reason: 'HSK3 download/install failed: ${result.errorMessage}');
      expect(await remote.isHskLevelInstalled(3), isTrue);
    });

    test('AUD-010: installing pack reuses existing VOC_* row instead of creating duplicate vocab_*', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'VOC_9999',
        'simplified': '中国',
        'traditional': '中國',
        'pinyin': 'Zhōngguó',
        'hsk_level': 1,
        'created_at': now,
        'updated_at': now,
      });

      final packJson = json.encode({
        'manifest': {
          'pack_id': 'pack_dedup_test',
          'hsk_level': 2,
          'version': '1.0.0',
          'title': 'Dedup Test',
        },
        'curriculum': {
          'id': 'curr_dedup',
          'units': [
            {
              'id': 'u_d1',
              'order_index': 1,
              'title_vi': 'U1',
              'title_zh': 'U1',
              'lessons': [
                {
                  'id': 'l_d1',
                  'order_index': 1,
                  'title_vi': 'L1',
                  'title_zh': 'L1',
                  'pinyin': 'L1',
                  'segments': [
                    {'id': 's_d1', 'step_order': 1, 'segment_type': 'vocabulary', 'title': 'V', 'content_ref_id': 'CI_D1'}
                  ],
                }
              ],
            }
          ],
        },
        'content_items': [
          {
            'content_id': 'CI_D1',
            'knowledge_type': 'vocabulary',
            'hsk_level': 2,
            'title': 'Vocab',
            'content_json': {
              'words': [
                {'simplified': '中国', 'pinyin': 'Zhōngguó', 'meaning_vi': 'Trung Quốc'}
              ],
            },
          }
        ],
      });

      final res = await ContentPackManager(db).installOrUpdatePack(packJson);
      expect(res.isSuccess, isTrue);

      final rows = await db.query(
        DatabaseConstants.tableVocabularies,
        where: 'simplified = ?',
        whereArgs: ['中国'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['id'], equals('VOC_9999'));
      expect(rows.first['hsk_level'], equals(1)); // Lower-level ownership preserved
    });

    test('AUD-023: late HSK3 install after placement triggers PlacementUnlockHandler', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(DatabaseConstants.tablePlacementTestSessions, {
        'id': 'place_hsk3',
        'status': 'completed',
        'skill_scores_json': '{}',
        'knowledge_gaps_json': '[]',
        'recommended_level': 3,
        'started_at': now,
        'completed_at': now,
        'created_at': now,
        'updated_at': now,
      });

      final manager = ContentPackManager(db);
      for (final lvl in [1, 2, 3]) {
        final raw = await File('assets/data/content_packs/hsk$lvl/hsk${lvl}_pack_v1.json').readAsString();
        final res = await manager.installOrUpdatePack(raw, isBundled: lvl < 3);
        expect(res.isSuccess, isTrue, reason: 'HSK $lvl failed: ${res.errorMessage}');
      }

      final hsk2Lessons = await db.rawQuery('''
        SELECT l.status, l.credited_reason
        FROM ${DatabaseConstants.tableCurriculumLessons} l
        JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
        JOIN ${DatabaseConstants.tableCurriculums} c ON u.curriculum_id = c.id
        WHERE c.hsk_level = 2
      ''');
      expect(hsk2Lessons, isNotEmpty);
      expect(
        hsk2Lessons.every((r) => r['status'] == 'completed' && r['credited_reason'] == 'credited_by_placement_test'),
        isTrue,
      );

      final hsk3First = await db.rawQuery('''
        SELECT l.is_locked
        FROM ${DatabaseConstants.tableCurriculumLessons} l
        JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
        JOIN ${DatabaseConstants.tableCurriculums} c ON u.curriculum_id = c.id
        WHERE c.hsk_level = 3
        ORDER BY u.order_index ASC, l.order_index ASC
        LIMIT 1
      ''');
      expect(hsk3First, isNotEmpty);
      expect(hsk3First.first['is_locked'], equals(0));
    });
  });
}
