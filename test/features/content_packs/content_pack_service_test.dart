import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_remote_service.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Content Packs & HSK 2 Bundled Integration Tests', () {
    late Database db;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hsk2_pack_test_');
      final dbPath = '${tempDir.path}/test_hsk2.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Official HSK 2 content pack file exists and is structurally valid', () async {
      final hsk2File = File('assets/data/content_packs/hsk2/hsk2_pack_v1.json');
      expect(await hsk2File.exists(), isTrue, reason: 'hsk2_pack_v1.json must exist in bundled assets');

      final raw = await hsk2File.readAsString();
      final decoded = json.decode(raw) as Map<String, dynamic>;

      expect(decoded['manifest']['pack_id'], equals('hsk2_pack_v1'));
      expect(decoded['manifest']['hsk_level'], equals(2));
      expect(decoded['manifest']['is_bundled'], isTrue);

      final units = (decoded['curriculum']['units'] as List<dynamic>);
      expect(units.length, equals(3)); // 3 distinct parts

      final allLessons = <dynamic>[];
      for (final u in units) {
        allLessons.addAll((u as Map<String, dynamic>)['lessons'] as List<dynamic>);
      }
      expect(allLessons.length, equals(15)); // Exactly 15 sequential lessons

      final contentItems = (decoded['content_items'] as List<dynamic>);
      expect(contentItems.length, greaterThanOrEqualTo(75)); // Warmup, Vocab, Grammar, Dialogue, Practice
    });

    test('2. Successfully installs bundled HSK 2 pack into SQLite database', () async {
      final hsk2File = File('assets/data/content_packs/hsk2/hsk2_pack_v1.json');
      final raw = await hsk2File.readAsString();

      final loader = ContentPackLoader(db);
      final result = await loader.loadPackFromJson(raw);

      expect(result.isSuccess, isTrue, reason: 'HSK 2 installation must succeed: ${result.errorMessage}');
      expect(result.packId, equals('hsk2_pack_v1'));
      expect(result.installedLessonsCount, equals(15));

      // Verify DB records
      final packRow = await db.query('content_packs', where: 'id = ?', whereArgs: ['hsk2_pack_v1']);
      expect(packRow.isNotEmpty, isTrue);
      expect(packRow.first['hsk_level'], equals(2));

      final lessons = await db.query('curriculum_lessons', where: 'id LIKE ?', whereArgs: ['lesson_2_%']);
      expect(lessons.length, equals(15));
    });

    test('3. ContentPackRemoteService can download and install remote HSK 3 pack from CDN mock', () async {
      final mockClient = MockHttpClient();
      final remoteService = ContentPackRemoteService(db: db, httpClient: mockClient);

      final cdnFile = File('content_packs_cdn/hsk3_pack_v1.json');
      expect(await cdnFile.exists(), isTrue);
      final cdnContent = await cdnFile.readAsString();

      final targetPack = const RemoteContentPackInfo(
        packId: 'hsk3_pack_v1',
        hskLevel: 3,
        title: 'Giáo trình chuẩn HSK 3 (Trực tuyến)',
        description: 'Test pack',
        version: '1.0.0',
        sizeBytes: 6341,
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/hsk3_pack_v1.json',
        sha256Checksum: '',
        isBundled: false,
      );

      when(() => mockClient.get(Uri.parse(targetPack.downloadUrl))).thenAnswer(
        (_) async => http.Response(cdnContent, 200, headers: {'content-type': 'application/json'}),
      );

      final isAlreadyInstalled = await remoteService.isPackInstalled(targetPack.packId);
      expect(isAlreadyInstalled, isFalse);

      final result = await remoteService.downloadAndInstallPack(packInfo: targetPack);
      expect(result.isSuccess, isTrue);

      final isNowInstalled = await remoteService.isPackInstalled(targetPack.packId);
      expect(isNowInstalled, isTrue);
    });
  });
}
