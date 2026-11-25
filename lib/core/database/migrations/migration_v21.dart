import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

class MigrationV21 implements Migration {
  const MigrationV21();

  @override
  int get version => 21;

  @override
  String get description =>
      'Add Wave 2 columns, normalize exit exam scores, deduplicate vocab_* and SRS rows, create FTS5 dictionary index, and drop redundant indexes';

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table);');
    final exists = tableInfo.any((col) => col['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    }
  }

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Add Wave 2 schema columns idempotently
    await _addColumnIfMissing(
      db,
      DatabaseConstants.tableChatMessages,
      'evaluation_json',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseConstants.tableChatMessages,
      'follow_up_suggestions_json',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseConstants.tableChatSessions,
      'persona_id',
      "TEXT DEFAULT 'qiaoqiao'",
    );
    await _addColumnIfMissing(
      db,
      DatabaseConstants.tableUserProfiles,
      'total_xp',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // 2. Normalize level_exit_exams passing score
    await db.execute('''
      UPDATE ${DatabaseConstants.tableLevelExitExams}
      SET passing_score = 120
      WHERE passing_score <= 1;
    ''');

    // 3. Normalize whitespace in segment/content IDs so B-Tree joins work cleanly
    await db.execute('''
      UPDATE ${DatabaseConstants.tableLessonSegments}
      SET content_ref_id = TRIM(content_ref_id)
      WHERE content_ref_id IS NOT NULL AND content_ref_id != TRIM(content_ref_id);
    ''');
    await db.execute('''
      UPDATE ${DatabaseConstants.tableContentItems}
      SET content_id = TRIM(content_id)
      WHERE content_id != TRIM(content_id);
    ''');

    // 4. Deduplicate legacy vocab_* entries into canonical VOC_* rows (AUD-010)
    await _deduplicateVocabularies(db);

    // 5. Deduplicate active srs_items and enforce partial UNIQUE index (RISK-04)
    await _deduplicateSrsAndCreateUniqueIndex(db);

    // 6. Create FTS5 virtual table + triggers + initial rebuild for dictionary_entries
    await _createDictionaryFts(db);

    // 7. Drop 10 redundant SQLite indexes
    const redundantIndexes = [
      'idx_grammar_items_hsk',
      'idx_activity_date',
      'idx_reading_hsk_level',
      'idx_practice_attempts_session',
      'idx_saved_words_vocab',
      'idx_reading_progress_passage',
      'idx_lesson_progress_id',
      'idx_hanzi_char',
      'idx_hanzi_prog_char',
      'idx_sent_prog_sent_id',
    ];
    for (final indexName in redundantIndexes) {
      await db.execute('DROP INDEX IF EXISTS $indexName;');
    }
  }

  Future<void> _deduplicateVocabularies(DatabaseExecutor db) async {
    final legacyRows = await db.rawQuery('''
      SELECT * FROM ${DatabaseConstants.tableVocabularies}
      WHERE SUBSTR(id, 1, 6) = 'vocab_' AND deleted_at IS NULL
    ''');

    for (final legacy in legacyRows) {
      final legacyId = legacy['id'] as String;
      final simplified = legacy['simplified'] as String? ?? '';
      if (simplified.isEmpty) continue;

      final canonicalRows = await db.rawQuery('''
        SELECT * FROM ${DatabaseConstants.tableVocabularies}
        WHERE SUBSTR(id, 1, 4) = 'VOC_' AND simplified = ? AND deleted_at IS NULL
        ORDER BY hsk_level ASC, id ASC
        LIMIT 1
      ''', [simplified]);

      if (canonicalRows.isEmpty) continue;

      final canonical = canonicalRows.first;
      final canonicalId = canonical['id'] as String;

      // Backfill missing metadata onto canonical record
      final patch = <String, dynamic>{};
      for (final field in const [
        'traditional',
        'pinyin',
        'pinyin_clean',
        'hanviet',
        'audio_uri',
        'stroke_count',
        'radicals',
        'frequency_rank',
        'source',
      ]) {
        final cur = canonical[field];
        final leg = legacy[field];
        if ((cur == null || (cur is String && cur.trim().isEmpty)) &&
            leg != null &&
            (leg is! String || leg.trim().isNotEmpty)) {
          patch[field] = leg;
        }
      }
      if (patch.isNotEmpty) {
        await db.update(
          DatabaseConstants.tableVocabularies,
          patch,
          where: 'id = ?',
          whereArgs: [canonicalId],
        );
      }

      // Merge SRS items from legacyId into canonicalId
      final legacySrsRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ? AND content_type = ?',
        whereArgs: [legacyId, 'vocabulary'],
      );
      for (final legacySrs in legacySrsRows) {
        final legacySrsId = legacySrs['id'] as String;
        final isDeleted = legacySrs['deleted_at'] != null;
        if (isDeleted) {
          await db.update(
            DatabaseConstants.tableSrsItems,
            {'content_id': canonicalId},
            where: 'id = ?',
            whereArgs: [legacySrsId],
          );
          continue;
        }

        final canonicalSrsRows = await db.query(
          DatabaseConstants.tableSrsItems,
          where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
          whereArgs: [canonicalId, 'vocabulary'],
          limit: 1,
        );

        if (canonicalSrsRows.isEmpty) {
          await db.update(
            DatabaseConstants.tableSrsItems,
            {'content_id': canonicalId},
            where: 'id = ?',
            whereArgs: [legacySrsId],
          );
        } else {
          final canonicalSrs = canonicalSrsRows.first;
          final canonicalSrsId = canonicalSrs['id'] as String;
          final legReps = (legacySrs['repetitions'] as num?)?.toInt() ?? 0;
          final canReps = (canonicalSrs['repetitions'] as num?)?.toInt() ?? 0;
          final legUpdated = legacySrs['updated_at'] as String? ?? '';
          final canUpdated = canonicalSrs['updated_at'] as String? ?? '';

          final legacyWins = legReps > canReps ||
              (legReps == canReps && legUpdated.compareTo(canUpdated) > 0);
          if (legacyWins) {
            await db.update(
              DatabaseConstants.tableSrsItems,
              {
                'state': legacySrs['state'],
                'interval_days': legacySrs['interval_days'],
                'ease_factor': legacySrs['ease_factor'],
                'repetitions': legacySrs['repetitions'],
                'lapses': legacySrs['lapses'],
                'due_at': legacySrs['due_at'],
                'last_reviewed_at': legacySrs['last_reviewed_at'],
                'updated_at': legacySrs['updated_at'],
              },
              where: 'id = ?',
              whereArgs: [canonicalSrsId],
            );
          }

          await db.update(
            DatabaseConstants.tableLearnerEvidence,
            {'srs_item_id': canonicalSrsId},
            where: 'srs_item_id = ?',
            whereArgs: [legacySrsId],
          );
          await db.delete(
            DatabaseConstants.tableSrsItems,
            where: 'id = ?',
            whereArgs: [legacySrsId],
          );
        }
      }

      // Repoint learner evidence content_id
      await db.update(
        DatabaseConstants.tableLearnerEvidence,
        {'content_id': canonicalId},
        where: "content_id = ? AND content_type = 'vocabulary'",
        whereArgs: [legacyId],
      );

      // Merge user_saved_words
      final legacySavedRows = await db.query(
        DatabaseConstants.tableUserSavedWords,
        where: 'vocabulary_id = ?',
        whereArgs: [legacyId],
      );
      if (legacySavedRows.isNotEmpty) {
        final legSaved = legacySavedRows.first;
        final canonicalSavedRows = await db.query(
          DatabaseConstants.tableUserSavedWords,
          where: 'vocabulary_id = ?',
          whereArgs: [canonicalId],
          limit: 1,
        );
        if (canonicalSavedRows.isEmpty) {
          await db.update(
            DatabaseConstants.tableUserSavedWords,
            {'vocabulary_id': canonicalId},
            where: 'vocabulary_id = ?',
            whereArgs: [legacyId],
          );
        } else {
          final canSaved = canonicalSavedRows.first;
          final canNote = (canSaved['custom_note'] as String?)?.trim() ?? '';
          final legNote = (legSaved['custom_note'] as String?)?.trim() ?? '';
          final mergedNote = canNote.isNotEmpty
              ? canSaved['custom_note']
              : (legNote.isNotEmpty ? legSaved['custom_note'] : null);
          final canFav = (canSaved['is_favorite'] as num?)?.toInt() ?? 0;
          final legFav = (legSaved['is_favorite'] as num?)?.toInt() ?? 0;
          await db.update(
            DatabaseConstants.tableUserSavedWords,
            {
              'custom_note': mergedNote,
              'is_favorite': (canFav == 1 || legFav == 1) ? 1 : 0,
            },
            where: 'vocabulary_id = ?',
            whereArgs: [canonicalId],
          );
          await db.delete(
            DatabaseConstants.tableUserSavedWords,
            where: 'vocabulary_id = ?',
            whereArgs: [legacyId],
          );
        }
      }

      // Preserve senses/examples if canonical lacks senses
      final canonicalSensesCount = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ${DatabaseConstants.tableVocabularySenses} WHERE vocabulary_id = ?',
              [canonicalId],
            ),
          ) ??
          0;
      if (canonicalSensesCount == 0) {
        await db.update(
          DatabaseConstants.tableVocabularySenses,
          {'vocabulary_id': canonicalId},
          where: 'vocabulary_id = ?',
          whereArgs: [legacyId],
        );
        await db.update(
          DatabaseConstants.tableVocabularyExamples,
          {'vocabulary_id': canonicalId},
          where: 'vocabulary_id = ?',
          whereArgs: [legacyId],
        );
      }

      await db.delete(
        DatabaseConstants.tableVocabularies,
        where: 'id = ?',
        whereArgs: [legacyId],
      );
    }
  }

  Future<void> _deduplicateSrsAndCreateUniqueIndex(DatabaseExecutor db) async {
    final dupGroups = await db.rawQuery('''
      SELECT content_id, content_type
      FROM ${DatabaseConstants.tableSrsItems}
      WHERE deleted_at IS NULL
      GROUP BY content_id, content_type
      HAVING COUNT(*) > 1
    ''');

    for (final group in dupGroups) {
      final contentId = group['content_id'] as String;
      final contentType = group['content_type'] as String;
      final rows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ? AND content_type = ? AND deleted_at IS NULL',
        whereArgs: [contentId, contentType],
        orderBy: 'repetitions DESC, updated_at DESC, id ASC',
      );
      if (rows.length <= 1) continue;

      final winnerId = rows.first['id'] as String;
      for (int i = 1; i < rows.length; i++) {
        final loserId = rows[i]['id'] as String;
        await db.update(
          DatabaseConstants.tableLearnerEvidence,
          {'srs_item_id': winnerId},
          where: 'srs_item_id = ?',
          whereArgs: [loserId],
        );
        await db.delete(
          DatabaseConstants.tableSrsItems,
          where: 'id = ?',
          whereArgs: [loserId],
        );
      }
    }

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_srs_content_active
      ON ${DatabaseConstants.tableSrsItems} (content_id, content_type)
      WHERE deleted_at IS NULL;
    ''');
  }

  Future<void> _createDictionaryFts(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS ${DatabaseConstants.tableDictionaryEntriesFts}
        USING fts5(
          id UNINDEXED,
          simplified,
          pinyin_clean,
          hanviet,
          meaning_vi,
          content='${DatabaseConstants.tableDictionaryEntries}',
          content_rowid='rowid',
          tokenize='unicode61 remove_diacritics 0'
        );
      ''');

      await createDictionaryFtsTriggers(db);
      await rebuildDictionaryFts(db);
    } catch (e) {
      debugPrint('[MigrationV21] FTS5 setup skipped or unavailable: $e');
      rethrow;
    }
  }

  static const dictionaryFtsTriggerNames = [
    'trg_dict_entries_ai',
    'trg_dict_entries_ad',
    'trg_dict_entries_au',
  ];

  /// Drops FTS sync triggers so bulk seeding avoids per-row FTS writes; pair with
  /// [createDictionaryFtsTriggers] + [rebuildDictionaryFts] afterwards.
  static Future<void> dropDictionaryFtsTriggers(DatabaseExecutor db) async {
    for (final name in dictionaryFtsTriggerNames) {
      await db.execute('DROP TRIGGER IF EXISTS $name;');
    }
  }

  static Future<void> rebuildDictionaryFts(DatabaseExecutor db) async {
    await db.execute('''
      INSERT INTO ${DatabaseConstants.tableDictionaryEntriesFts}(
        ${DatabaseConstants.tableDictionaryEntriesFts}
      ) VALUES('rebuild');
    ''');
  }

  static Future<void> createDictionaryFtsTriggers(DatabaseExecutor db) async {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_dict_entries_ai
        AFTER INSERT ON ${DatabaseConstants.tableDictionaryEntries}
        BEGIN
          INSERT INTO ${DatabaseConstants.tableDictionaryEntriesFts}(
            rowid, id, simplified, pinyin_clean, hanviet, meaning_vi
          ) VALUES (
            new.rowid, new.id, new.simplified, new.pinyin_clean, new.hanviet, new.meaning_vi
          );
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_dict_entries_ad
        AFTER DELETE ON ${DatabaseConstants.tableDictionaryEntries}
        BEGIN
          INSERT INTO ${DatabaseConstants.tableDictionaryEntriesFts}(
            ${DatabaseConstants.tableDictionaryEntriesFts}, rowid, id, simplified, pinyin_clean, hanviet, meaning_vi
          ) VALUES (
            'delete', old.rowid, old.id, old.simplified, old.pinyin_clean, old.hanviet, old.meaning_vi
          );
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_dict_entries_au
        AFTER UPDATE ON ${DatabaseConstants.tableDictionaryEntries}
        BEGIN
          INSERT INTO ${DatabaseConstants.tableDictionaryEntriesFts}(
            ${DatabaseConstants.tableDictionaryEntriesFts}, rowid, id, simplified, pinyin_clean, hanviet, meaning_vi
          ) VALUES (
            'delete', old.rowid, old.id, old.simplified, old.pinyin_clean, old.hanviet, old.meaning_vi
          );
          INSERT INTO ${DatabaseConstants.tableDictionaryEntriesFts}(
            rowid, id, simplified, pinyin_clean, hanviet, meaning_vi
          ) VALUES (
            new.rowid, new.id, new.simplified, new.pinyin_clean, new.hanviet, new.meaning_vi
          );
        END;
      ''');
  }
}
