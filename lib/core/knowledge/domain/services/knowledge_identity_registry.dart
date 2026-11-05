import 'package:sqflite/sqflite.dart';
import '../../../database/database_constants.dart';

/// Types of entities governed by the Knowledge Identity Registry.
enum KnowledgeEntityType {
  vocabulary,
  hanzi,
  grammar,
  sentence,
  lesson,
  unit,
  curriculum,
}

/// Unified Identity & Alias Resolution Service (Nhiệm vụ A).
/// Resolves split-brain identifiers across Roadmap, Curriculum, Hanzi, and SRS domains
/// into single canonical identities with bidirectional alias mapping and reverse origin lookup.
class KnowledgeIdentityRegistry {
  final DatabaseExecutor _db;

  // In-memory well-known alias registry for fast sub-millisecond lookups
  static final Map<String, String> _wellKnownLessonAliases = {
    // Roadmap ID vs Curriculum ID vs Content Pack ID mappings
    'lesson_hsk1_u1_l1': 'lesson_1_1',
    'c_hsk1_l1': 'lesson_1_1',
    'LES_HSK1_01_TONES': 'lesson_1_1',

    'lesson_hsk1_u1_l2': 'lesson_1_2',
    'c_hsk1_l2': 'lesson_1_2',
    'LES_HSK1_02_WRITING_BASICS': 'lesson_1_2',

    'lesson_hsk1_u1_l3': 'lesson_1_3',
    'c_hsk1_l3': 'lesson_1_3',
    'LES_HSK1_03_GREETINGS': 'lesson_1_3',

    'lesson_hsk1_u2_l4': 'lesson_1_4',
    'c_hsk1_l4': 'lesson_1_4',
    'LES_HSK1_04_GRAMMAR_SHI': 'lesson_1_4',

    'lesson_hsk1_u2_l5': 'lesson_1_5',
    'c_hsk1_l5': 'lesson_1_5',
    'LES_HSK1_05_READING_FRIEND': 'lesson_1_5',

    'lesson_hsk1_u2_l6': 'lesson_1_6',
    'c_hsk1_l6': 'lesson_1_6',
    'LES_HSK1_06_SHADOWING_GREETING': 'lesson_1_6',

    // HSK 2 Mappings
    'lesson_hsk2_u1_l1': 'lesson_2_1',
    'c_hsk2_l1': 'lesson_2_1',
    'LES_HSK2_01_RESTAURANT_VOCAB': 'lesson_2_1',

    'lesson_hsk2_u1_l2': 'lesson_2_2',
    'c_hsk2_l2': 'lesson_2_2',
    'LES_HSK2_02_GRAMMAR_LE': 'lesson_2_2',

    'lesson_hsk2_u1_l3': 'lesson_2_3',
    'c_hsk2_l3': 'lesson_2_3',
    'LES_HSK2_03_READING_RESTAURANT': 'lesson_2_3',

    // Unit aliases
    'unit_hsk1_u1': 'unit_1',
    'UNIT_HSK1_01': 'unit_1',
    'unit_hsk1_u2': 'unit_2',
    'UNIT_HSK1_02': 'unit_2',
    'unit_hsk1_u3': 'unit_3',
    'UNIT_HSK1_03': 'unit_3',
    'unit_hsk2_u1': 'unit_2_1',
    'UNIT_HSK2_01': 'unit_2_1',

    // Curriculum aliases
    'HSK_2012_L1': 'curr_hsk1',
    'curriculum_hsk1': 'curr_hsk1',
    'c_hsk1': 'curr_hsk1',
  };

  static Map<String, String> get wellKnownLessonAliases => Map.unmodifiable(_wellKnownLessonAliases);

  KnowledgeIdentityRegistry(this._db);

  /// Generates a standardized canonical knowledge ID.
  static String formatCanonicalId(KnowledgeEntityType type, String key) {
    final cleanKey = key.trim();
    switch (type) {
      case KnowledgeEntityType.vocabulary:
        return 'KNOW_VOCAB_$cleanKey';
      case KnowledgeEntityType.hanzi:
        return 'KNOW_HANZI_$cleanKey';
      case KnowledgeEntityType.grammar:
        return 'KNOW_GRAM_$cleanKey';
      case KnowledgeEntityType.sentence:
        return 'KNOW_SENT_$cleanKey';
      case KnowledgeEntityType.lesson:
        return cleanKey.startsWith('lesson_') ? cleanKey : 'lesson_$cleanKey';
      case KnowledgeEntityType.unit:
        return cleanKey.startsWith('unit_') ? cleanKey : 'unit_$cleanKey';
      case KnowledgeEntityType.curriculum:
        return cleanKey.startsWith('curr_') ? cleanKey : 'curr_$cleanKey';
    }
  }

  /// Resolves any lesson alias (Roadmap `lesson_hsk1_u1_l1`, `c_hsk1_l1`, `LES_HSK1_01_TONES`)
  /// to the single canonical lesson identifier (e.g. `lesson_1_1`).
  Future<String> toCanonicalLessonId(String aliasOrId) async {
    final trimmed = aliasOrId.trim();
    if (_wellKnownLessonAliases.containsKey(trimmed)) {
      return _wellKnownLessonAliases[trimmed]!;
    }

    // Check content_id_mappings in SQLite
    final activeId = await resolveActiveContentId(trimmed);
    if (_wellKnownLessonAliases.containsKey(activeId)) {
      return _wellKnownLessonAliases[activeId]!;
    }

    // Pattern-based fallback: lesson_hsk{lvl}_u{u}_l{l} -> lesson_{lvl}_{l}
    final regex = RegExp(r'^lesson_hsk(\d+)_u\d+_l(\d+)$', caseSensitive: false);
    final match = regex.firstMatch(activeId);
    if (match != null) {
      return 'lesson_${match.group(1)}_${match.group(2)}';
    }

    // Pattern-based fallback: c_hsk{lvl}_l{l} -> lesson_{lvl}_{l}
    final regexC = RegExp(r'^c_hsk(\d+)_l(\d+)$', caseSensitive: false);
    final matchC = regexC.firstMatch(activeId);
    if (matchC != null) {
      return 'lesson_${matchC.group(1)}_${matchC.group(2)}';
    }

    return activeId;
  }

  /// Resolves any vocabulary reference (raw Hanzi '你好', open source 'voc_hsk1_001',
  /// legacy 'VOCAB_001_NIHAO', SRS ID 'SRS_VOCABULARY_...', or canonical 'KNOW_VOCAB_...')
  /// to the canonical Vocabulary ID that matches the primary key in table `vocabularies`.
  Future<String?> toCanonicalVocabularyId(String aliasOrWord) async {
    var trimmed = aliasOrWord.trim();
    if (trimmed.isEmpty) return null;

    // Strip SRS card prefix if accidentally passed
    if (trimmed.startsWith('SRS_VOCABULARY_')) {
      trimmed = trimmed.replaceFirst('SRS_VOCABULARY_', '');
    } else if (trimmed.startsWith('srs_voc_') || trimmed.startsWith('srs_')) {
      trimmed = trimmed.replaceFirst(RegExp(r'^srs_'), '');
    }

    // 1. Direct PK match in vocabularies table
    final directPk = await _db.query(
      DatabaseConstants.tableVocabularies,
      columns: ['id'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (directPk.isNotEmpty) {
      return directPk.first['id'] as String;
    }

    // 2. Check content_id_mappings
    final activeId = await resolveActiveContentId(trimmed);
    if (activeId != trimmed) {
      final mappedPk = await _db.query(
        DatabaseConstants.tableVocabularies,
        columns: ['id'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [activeId],
        limit: 1,
      );
      if (mappedPk.isNotEmpty) {
        return mappedPk.first['id'] as String;
      }
    }

    // 3. Match by exact simplified character / word (e.g. '你好', '老师')
    final bySimplified = await _db.query(
      DatabaseConstants.tableVocabularies,
      columns: ['id'],
      where: 'simplified = ? AND deleted_at IS NULL',
      whereArgs: [trimmed],
      orderBy: 'hsk_level ASC, id ASC',
      limit: 1,
    );
    if (bySimplified.isNotEmpty) {
      return bySimplified.first['id'] as String;
    }

    // 4. Match by Knowledge Registry canonical_id
    if (trimmed.startsWith('KNOW_VOCAB_')) {
      final stripped = trimmed.replaceFirst('KNOW_VOCAB_', '');
      final parts = stripped.split('_');
      final wordOnly = parts.isNotEmpty ? parts.first : stripped;

      final byWord = await _db.query(
        DatabaseConstants.tableVocabularies,
        columns: ['id'],
        where: 'simplified = ? AND deleted_at IS NULL',
        whereArgs: [wordOnly],
        limit: 1,
      );
      if (byWord.isNotEmpty) {
        return byWord.first['id'] as String;
      }
    }

    // 5. Match legacy pattern VOCAB_{number}_{word} (e.g. 'VOCAB_001_NIHAO')
    if (trimmed.startsWith('VOCAB_')) {
      final parts = trimmed.split('_');
      if (parts.length >= 3) {
        final pinyinOrWord = parts.sublist(2).join('');
        final byPinyin = await _db.query(
          DatabaseConstants.tableVocabularies,
          columns: ['id'],
          where: 'pinyin_clean = ? AND deleted_at IS NULL',
          whereArgs: [pinyinOrWord.toLowerCase()],
          limit: 1,
        );
        if (byPinyin.isNotEmpty) {
          return byPinyin.first['id'] as String;
        }
      }
    }

    // Fallback: return resolved active ID
    return activeId;
  }

  /// Resolves character glyph or character ID (e.g. 'char_4f60' or '你')
  /// to the canonical character glyph used in `hanzi_characters`.
  Future<String> toCanonicalHanziCharacter(String charOrId) async {
    final trimmed = charOrId.trim();
    if (trimmed.length == 1) return trimmed;

    if (trimmed.startsWith('KNOW_HANZI_')) {
      return trimmed.replaceFirst('KNOW_HANZI_', '');
    }

    final row = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      columns: ['character'],
      where: 'id = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (row.isNotEmpty) {
      return row.first['character'] as String;
    }

    return trimmed;
  }

  /// Traverses `content_id_mappings` recursively up to 10 hops to resolve the active target ID.
  Future<String> resolveActiveContentId(String contentId) async {
    String currentId = contentId.trim();
    int hops = 0;
    while (hops < 10) {
      final rows = await _db.query(
        DatabaseConstants.tableContentIdMappings,
        columns: ['new_id'],
        where: 'old_id = ?',
        whereArgs: [currentId],
        limit: 1,
      );
      if (rows.isEmpty) break;
      final nextId = rows.first['new_id'] as String;
      if (nextId == currentId) break;
      currentId = nextId;
      hops++;
    }
    return currentId;
  }

  /// Registers an immutable alias mapping in `content_id_mappings` table.
  Future<void> registerAlias({
    required String oldId,
    required String newId,
    required String mappingType,
    String? packageId,
    String? notes,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final mappingId = 'map_${oldId}_$newId';
    await _db.insert(
      DatabaseConstants.tableContentIdMappings,
      {
        'id': mappingId,
        'old_id': oldId.trim(),
        'new_id': newId.trim(),
        'mapping_type': mappingType,
        'package_id': packageId,
        'notes': notes,
        'created_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all historical aliases mapping to a given canonical ID.
  Future<List<String>> getAliasesFor(String canonicalId) async {
    final rows = await _db.query(
      DatabaseConstants.tableContentIdMappings,
      columns: ['old_id'],
      where: 'new_id = ?',
      whereArgs: [canonicalId],
    );
    final aliases = rows.map((r) => r['old_id'] as String).toList();

    _wellKnownLessonAliases.forEach((alias, canonical) {
      if (canonical == canonicalId && !aliases.contains(alias)) {
        aliases.add(alias);
      }
    });

    return aliases;
  }
}
