import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../dictionary/domain/utils/pinyin_helper.dart';
import '../domain/models/sentence_models.dart';

class SentenceDao {
  final DatabaseExecutor _db;

  SentenceDao(this._db);

  /// Fetch a sentence by ID with its associated audio tracks
  Future<SentenceItem?> getSentenceById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableSentences,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final audios = await getAudiosForSentence(id);
    final map = Map<String, dynamic>.from(results.first);
    map['audios'] = audios.map((a) => a.toMap()).toList();

    return SentenceItem.fromJson(map);
  }

  /// Fetch sentences by HSK level with optional filter for human voice recordings
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  }) async {
    final whereClauses = <String>['hsk_level = ?'];
    final whereArgs = <dynamic>[hskLevel];

    if (humanAudioOnly) {
      whereClauses.add('has_human_audio = 1');
    }

    final results = await _db.query(
      DatabaseConstants.tableSentences,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'has_human_audio DESC, id ASC',
      limit: limit,
      offset: offset,
    );

    if (results.isEmpty) return const [];

    final sentenceIds = results.map((r) => r['id'] as String).toList();
    final audioMap = await getAudiosForSentences(sentenceIds);

    final sentences = <SentenceItem>[];
    for (final r in results) {
      final id = r['id'] as String;
      final map = Map<String, dynamic>.from(r);
      map['audios'] = (audioMap[id] ?? const []).map((a) => a.toMap()).toList();
      sentences.add(SentenceItem.fromJson(map));
    }

    return sentences;
  }

  /// Search sentences by Chinese text, Pinyin, or Vietnamese meaning
  Future<List<SentenceItem>> searchSentences(
    String query, {
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = PinyinHelper.removeTones(trimmed);
    final results = await _db.query(
      DatabaseConstants.tableSentences,
      where: 'chinese LIKE ? OR pinyin LIKE ? OR translation_vi LIKE ? OR translation_en LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'hsk_level ASC, has_human_audio DESC',
      limit: limit,
    );

    List<Map<String, dynamic>> rawCandidates = results.map((r) => Map<String, dynamic>.from(r)).toList();

    if (rawCandidates.isEmpty && normalized.isNotEmpty) {
      final all = await _db.query(DatabaseConstants.tableSentences, limit: 300);
      for (final r in all) {
        final p = r['pinyin'] as String? ?? '';
        final pNorm = PinyinHelper.removeTones(p).replaceAll(' ', '');
        final queryNorm = normalized.replaceAll(' ', '');
        if (pNorm.contains(queryNorm)) {
          rawCandidates.add(Map<String, dynamic>.from(r));
          if (rawCandidates.length >= limit) break;
        }
      }
    }

    if (rawCandidates.isEmpty) return const [];

    final sentenceIds = rawCandidates.map((r) => r['id'] as String).toList();
    final audioMap = await getAudiosForSentences(sentenceIds);

    final list = <SentenceItem>[];
    for (final r in rawCandidates) {
      final id = r['id'] as String;
      r['audios'] = (audioMap[id] ?? const []).map((a) => a.toMap()).toList();
      list.add(SentenceItem.fromJson(r));
    }

    return list;
  }

  /// Fetch audio tracks for multiple sentences in bulk batches
  Future<Map<String, List<SentenceAudio>>> getAudiosForSentences(
    List<String> sentenceIds, {
    int batchSize = 300,
  }) async {
    final unique = sentenceIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const {};

    final map = <String, List<SentenceAudio>>{};
    for (int i = 0; i < unique.length; i += batchSize) {
      final end = (i + batchSize < unique.length) ? i + batchSize : unique.length;
      final batch = unique.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');

      final results = await _db.query(
        DatabaseConstants.tableSentenceAudio,
        where: 'sentence_id IN ($placeholders)',
        whereArgs: batch,
      );

      for (final row in results) {
        final audio = SentenceAudio.fromMap(row);
        map.putIfAbsent(audio.sentenceId, () => []).add(audio);
      }
    }

    return map;
  }

  /// Fetch sentences by IDs in bulk batches with audios
  Future<List<SentenceItem>> getSentencesByIds(
    List<String> sentenceIds, {
    int batchSize = 300,
  }) async {
    final unique = sentenceIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];

    final rawRows = <Map<String, dynamic>>[];
    for (int i = 0; i < unique.length; i += batchSize) {
      final end = (i + batchSize < unique.length) ? i + batchSize : unique.length;
      final batch = unique.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');

      final results = await _db.query(
        DatabaseConstants.tableSentences,
        where: 'id IN ($placeholders)',
        whereArgs: batch,
      );

      rawRows.addAll(results.map((r) => Map<String, dynamic>.from(r)));
    }

    if (rawRows.isEmpty) return const [];

    final ids = rawRows.map((r) => r['id'] as String).toList();
    final audioMap = await getAudiosForSentences(ids, batchSize: batchSize);

    final list = <SentenceItem>[];
    for (final r in rawRows) {
      final id = r['id'] as String;
      r['audios'] = (audioMap[id] ?? const []).map((a) => a.toMap()).toList();
      list.add(SentenceItem.fromJson(r));
    }

    return list;
  }

  /// Fetch practice progress for multiple sentences in bulk batches
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(
    List<String> sentenceIds, {
    int batchSize = 300,
  }) async {
    final unique = sentenceIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const {};

    final map = <String, SentencePracticeProgress>{};
    for (int i = 0; i < unique.length; i += batchSize) {
      final end = (i + batchSize < unique.length) ? i + batchSize : unique.length;
      final batch = unique.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');

      final results = await _db.query(
        DatabaseConstants.tableSentencePracticeProgress,
        where: 'sentence_id IN ($placeholders)',
        whereArgs: batch,
      );

      for (final row in results) {
        final progress = SentencePracticeProgress.fromMap(row);
        map[progress.sentenceId] = progress;
      }
    }

    return map;
  }

  /// Fetch audio tracks for a given sentence
  Future<List<SentenceAudio>> getAudiosForSentence(String sentenceId) async {
    final results = await _db.query(
      DatabaseConstants.tableSentenceAudio,
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
    );
    return results.map(SentenceAudio.fromMap).toList();
  }

  /// Insert sentences and their audio records in a batch
  Future<void> insertSentencesBatch(List<SentenceItem> sentences) async {
    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final s in sentences) {
          batch.insert(
            DatabaseConstants.tableSentences,
            s.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (final a in s.audios) {
            batch.insert(
              DatabaseConstants.tableSentenceAudio,
              a.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await batch.commit(noResult: true);
      });
    } else {
      final batch = db.batch();
      for (final s in sentences) {
        batch.insert(
          DatabaseConstants.tableSentences,
          s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final a in s.audios) {
          batch.insert(
            DatabaseConstants.tableSentenceAudio,
            a.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    }
  }

  /// Update downloaded audio path and status
  Future<void> updateAudioLocalPath(String audioId, String localPath, String status) async {
    await _db.update(
      DatabaseConstants.tableSentenceAudio,
      {
        'local_path': localPath,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [audioId],
    );
  }

  /// Get practice progress for a sentence
  Future<SentencePracticeProgress?> getProgress(String sentenceId) async {
    final results = await _db.query(
      DatabaseConstants.tableSentencePracticeProgress,
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SentencePracticeProgress.fromMap(results.first);
  }

  /// Save or update practice progress
  Future<void> saveProgress(SentencePracticeProgress progress) async {
    await _db.insert(
      DatabaseConstants.tableSentencePracticeProgress,
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Total count of sentences in the database
  Future<int> countSentences() async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableSentences}',
    );
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Fetch sentences requiring SRS review
  Future<List<SentencePracticeProgress>> getSentencesNeedingReview({int limit = 50}) async {
    final nowIso = DateTime.now().toIso8601String();
    final results = await _db.query(
      DatabaseConstants.tableSentencePracticeProgress,
      where: 'srs_due_date <= ?',
      whereArgs: [nowIso],
      orderBy: 'srs_due_date ASC',
      limit: limit,
    );
    return results.map(SentencePracticeProgress.fromMap).toList();
  }
}
