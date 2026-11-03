import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../dictionary/domain/utils/pinyin_helper.dart';
import '../domain/models/hanzi_models.dart';

class HanziDao {
  final DatabaseExecutor _db;

  HanziDao(this._db);

  /// Fetch a single character by its Hanzi character string (e.g. '你')
  Future<HanziCharacter?> getCharacter(String character) async {
    final results = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      where: 'character = ?',
      whereArgs: [character],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return HanziCharacter.fromMap(results.first);
  }

  /// Fetch a single character by ID
  Future<HanziCharacter?> getCharacterById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return HanziCharacter.fromMap(results.first);
  }

  /// Fetch characters filtered by HSK level
  Future<List<HanziCharacter>> getCharactersByHskLevel(
    int hskLevel, {
    int limit = 100,
    int offset = 0,
  }) async {
    final results = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      where: 'hsk_level = ?',
      whereArgs: [hskLevel],
      orderBy: 'stroke_count ASC, character ASC',
      limit: limit,
      offset: offset,
    );
    return results.map(HanziCharacter.fromMap).toList();
  }

  /// Search characters by character glyph, pinyin, or hanviet
  Future<List<HanziCharacter>> searchCharacters(
    String query, {
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = PinyinHelper.removeTones(trimmed);
    final results = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      where: 'character LIKE ? OR pinyin LIKE ? OR hanviet LIKE ? OR meaning_vi LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'hsk_level ASC, stroke_count ASC',
      limit: limit,
    );

    final mapped = results.map(HanziCharacter.fromMap).toList();
    if (mapped.isEmpty && normalized.isNotEmpty) {
      // Fallback: search by tone-normalized pinyin across candidates
      final all = await _db.query(
        DatabaseConstants.tableHanziCharacters,
        limit: 500,
      );
      final fallback = all.map(HanziCharacter.fromMap).where((c) {
        final cNorm = PinyinHelper.removeTones(c.pinyin);
        return cNorm.contains(normalized);
      }).take(limit).toList();
      return fallback;
    }
    return mapped;
  }

  /// Total count of imported Hanzi characters in the database
  Future<int> countCharacters() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableHanziCharacters}',
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Insert characters in a batch transaction
  Future<void> insertCharactersBatch(List<HanziCharacter> characters) async {
    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final c in characters) {
          batch.insert(
            DatabaseConstants.tableHanziCharacters,
            c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } else {
      final batch = db.batch();
      for (final c in characters) {
        batch.insert(
          DatabaseConstants.tableHanziCharacters,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  /// Get handwriting progress for a character
  Future<HanziWritingProgress?> getProgress(String character) async {
    final results = await _db.query(
      DatabaseConstants.tableHanziWritingProgress,
      where: 'character = ?',
      whereArgs: [character],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return HanziWritingProgress.fromMap(results.first);
  }

  /// Save or update writing practice / test progress
  Future<void> saveProgress(HanziWritingProgress progress) async {
    await _db.insert(
      DatabaseConstants.tableHanziWritingProgress,
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch characters scheduled for SRS review or with recorded mistakes
  Future<List<HanziWritingProgress>> getCharactersNeedingReview({
    int limit = 50,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final results = await _db.query(
      DatabaseConstants.tableHanziWritingProgress,
      where: 'srs_due_date <= ? OR mistakes_count > 0',
      whereArgs: [nowIso],
      orderBy: 'srs_due_date ASC, mistakes_count DESC',
      limit: limit,
    );
    return results.map(HanziWritingProgress.fromMap).toList();
  }

  /// Fetch recently practiced characters
  Future<List<HanziWritingProgress>> getRecentPracticed({
    int limit = 20,
  }) async {
    final results = await _db.query(
      DatabaseConstants.tableHanziWritingProgress,
      where: 'last_practiced_at IS NOT NULL',
      orderBy: 'last_practiced_at DESC',
      limit: limit,
    );
    return results.map(HanziWritingProgress.fromMap).toList();
  }
}
