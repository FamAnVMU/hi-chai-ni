import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/shadowing/shadowing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late ShadowingRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shadow_test_');
    final dbPath = '${tempDir.path}/test_shadow.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = ShadowingRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ShadowingRepository SQLite & Privacy Tests', () {
    test('1. recordShadowingSession persists to learner_evidence & learning_activities atomically', () async {
      final now = DateTime.utc(2026, 11, 1, 16, 0, 0);
      final assessment = ShadowingAssessmentResult(
        segmentId: 'DOC01_SEG01',
        targetDurationMs: 2800,
        userDurationMs: 2900,
        pacingRatio: 1.04,
        pacingVerdict: 'Chuẩn nhịp độ bản xứ',
        timelineMatchPercent: 96.0,
        fluencyIndex: 0.96,
        userAudioPath: '${tempDir.path}/shadow_rec.wav',
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
        timestamp: now,
      );

      final evidenceId = await repository.recordShadowingSession(
        assessment: assessment,
        timestamp: now,
      );

      expect(evidenceId, contains('EVI_SHADOW_'));

      // Check learner_evidence
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: [evidenceId],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['source'], equals('shadowing'));
      expect(evidenceRows.first['content_type'], equals('shadowing'));
      expect(evidenceRows.first['score'], equals(0.96));

      // Check learning_activities
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['shadowing'],
      );
      expect(activityRows.length, equals(1));
      expect(activityRows.first['duration_seconds'], equals(3));
      expect(activityRows.first['activity_date'], equals('2026-11-01'));
    });

    test('2. deleteRecordingAudio removes audio file and preserves aggregated evidence', () async {
      final dummyAudioFile = File('${tempDir.path}/dummy_shadow.wav');
      await dummyAudioFile.writeAsString('audio_shadow_bytes');

      final assessment = ShadowingAssessmentResult(
        segmentId: 'DOC02_SEG01',
        targetDurationMs: 3000,
        userDurationMs: 3100,
        pacingRatio: 1.03,
        pacingVerdict: 'Chuẩn',
        timelineMatchPercent: 97.0,
        fluencyIndex: 0.97,
        userAudioPath: dummyAudioFile.path,
        mode: ShadowingMode.simultaneous,
        speed: ShadowingPlaybackSpeed.normal,
        timestamp: DateTime.now(),
      );

      final evidenceId = await repository.recordShadowingSession(assessment: assessment);

      await repository.deleteRecordingAudio(
        audioPath: dummyAudioFile.path,
        evidenceId: evidenceId,
        retainEvidence: true,
      );

      expect(await dummyAudioFile.exists(), isFalse);

      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: [evidenceId],
      );
      expect(evidenceRows.length, equals(1));
      final meta = json.decode(evidenceRows.first['metadata_json'] as String);
      expect(meta['audio_deleted'], isTrue);
      expect(meta['user_audio_path'], isNull);
    });
  });
}
