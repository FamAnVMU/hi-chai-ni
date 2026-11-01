import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late PronunciationRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pron_test_');
    final dbPath = '${tempDir.path}/test_pron.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = PronunciationRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PronunciationRepository SQLite & Audio Retention Tests', () {
    test('1. recordPronunciationSession saves atomically to learner_evidence & learning_activities', () async {
      final now = DateTime.utc(2026, 11, 1, 15, 0, 0);
      final assessment = PronunciationAssessmentResult(
        targetId: 'TONE_01_MA1',
        targetText: '妈',
        targetPinyin: 'mā',
        recognizedTranscript: '妈',
        overallScore: 0.95,
        confidence: PronunciationConfidence.high,
        isAcousticallyAnalyzed: true,
        toneAccuracy: 0.96,
        initialFinalAccuracy: 0.94,
        feedbackList: const ['Thanh 1 rất tốt'],
        audioLocalPath: '${tempDir.path}/rec_01.wav',
        recordedDurationMs: 1400,
        providerId: 'test_engine',
        timestamp: now,
      );

      final evidenceId = await repository.recordPronunciationSession(
        assessment: assessment,
        timestamp: now,
      );

      expect(evidenceId, contains('EVI_PRON_'));

      // Check learner_evidence
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: [evidenceId],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['source'], equals('pronunciation_lab'));
      expect(evidenceRows.first['content_type'], equals('pronunciation'));
      expect(evidenceRows.first['score'], equals(0.95));

      // Check learning_activities
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['pronunciation'],
      );
      expect(activityRows.length, equals(1));
      expect(activityRows.first['duration_seconds'], equals(2));
      expect(activityRows.first['activity_date'], equals('2026-11-01'));
    });

    test('2. deleteRecordingAudio with retainEvidence=true purges file but keeps assessment score', () async {
      final dummyAudioFile = File('${tempDir.path}/dummy_pron.wav');
      await dummyAudioFile.writeAsString('audio_bytes_data');
      expect(await dummyAudioFile.exists(), isTrue);

      final assessment = PronunciationAssessmentResult(
        targetId: 'INIT_01_ZH_CH',
        targetText: '吃饭',
        targetPinyin: 'chī fàn',
        recognizedTranscript: '吃饭',
        overallScore: 0.90,
        confidence: PronunciationConfidence.high,
        isAcousticallyAnalyzed: false,
        audioLocalPath: dummyAudioFile.path,
        recordedDurationMs: 2000,
        providerId: 'local_text_asr',
        timestamp: DateTime.now(),
      );

      final evidenceId = await repository.recordPronunciationSession(assessment: assessment);

      // Delete audio with retain evidence
      await repository.deleteRecordingAudio(
        audioPath: dummyAudioFile.path,
        evidenceId: evidenceId,
        retainEvidence: true,
      );

      // Physical file must be deleted
      expect(await dummyAudioFile.exists(), isFalse);

      // Evidence record must still exist with score intact!
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: [evidenceId],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['score'], equals(0.90));

      final meta = json.decode(evidenceRows.first['metadata_json'] as String);
      expect(meta['audio_deleted'], isTrue);
      expect(meta['audio_local_path'], isNull);
    });

    test('3. deleteRecordingAudio with retainEvidence=false purges evidence completely', () async {
      final dummyAudioFile = File('${tempDir.path}/dummy_purge.wav');
      await dummyAudioFile.writeAsString('audio_bytes');

      final assessment = PronunciationAssessmentResult(
        targetId: 'FINAL_01_AN_ANG',
        targetText: '帮忙',
        targetPinyin: 'bāng máng',
        overallScore: 0.88,
        isAcousticallyAnalyzed: false,
        audioLocalPath: dummyAudioFile.path,
        providerId: 'local_text_asr',
        timestamp: DateTime.now(),
      );

      final evidenceId = await repository.recordPronunciationSession(assessment: assessment);

      await repository.deleteRecordingAudio(
        audioPath: dummyAudioFile.path,
        evidenceId: evidenceId,
        retainEvidence: false,
      );

      expect(await dummyAudioFile.exists(), isFalse);

      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: [evidenceId],
      );
      expect(evidenceRows, isEmpty);
    });
  });
}
