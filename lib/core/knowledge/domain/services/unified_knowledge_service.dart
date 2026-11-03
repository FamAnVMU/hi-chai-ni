import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../features/dictionary/data/dictionary_repository.dart';
import '../../../../features/dictionary/domain/models/dictionary_models.dart';
import '../../../../features/grammar/data/grammar_repository.dart';
import '../../../../features/grammar/domain/models/grammar_models.dart';
import '../../../../features/hanzi/data/hanzi_dao.dart';
import '../../../../features/hanzi/domain/models/hanzi_models.dart';
import '../../../../features/sentences/data/sentence_dao.dart';
import '../../../database/dao/knowledge_registry_dao.dart';
import '../../../database/database_constants.dart';
import '../models/unified_knowledge_models.dart';

/// Central facade service uniting Vocabulary, Grammar, Hanzi, and Sentence domains
abstract class UnifiedKnowledgeService {
  Future<UnifiedVocabularyDetails?> getVocabularyDetails(String wordOrId);
  Future<UnifiedGrammarDetails?> getGrammarDetails(String grammarId);
  Future<UnifiedHanziDetails?> getHanziDetails(String charOrId);
  Future<UnifiedSentenceDetails?> getSentenceDetails(String sentenceId);
  Future<KnowledgeSyncReport> syncAllEntitiesToKnowledgeRegistry();
  Future<void> recordPracticeEvidence({
    required String knowledgeId,
    required String activityType,
    required double score,
    int durationMs = 0,
    Map<String, dynamic> metadata = const {},
  });
}

/// Default production implementation querying SQLite and coordinating domain DAOs
class DefaultUnifiedKnowledgeService implements UnifiedKnowledgeService {
  final Database _db;
  late final KnowledgeRegistryDao _knowledgeDao;
  late final DictionaryRepository _dictRepo;
  late final GrammarRepository _grammarRepo;
  late final HanziDao _hanziDao;
  late final SentenceDao _sentenceDao;

  DefaultUnifiedKnowledgeService(this._db) {
    _knowledgeDao = KnowledgeRegistryDao(_db);
    _dictRepo = DefaultDictionaryRepository(_db);
    _grammarRepo = DefaultGrammarRepository(_db);
    _hanziDao = HanziDao(_db);
    _sentenceDao = SentenceDao(_db);
  }

  @override
  Future<UnifiedVocabularyDetails?> getVocabularyDetails(String wordOrId) async {
    // 1. Lookup dictionary entry by exact Hanzi, ID or query
    DictionaryEntry? entry = await _dictRepo.getWordByExactHanzi(wordOrId);
    entry ??= await _dictRepo.getWordById(wordOrId);

    if (entry == null) {
      final results = await _dictRepo.search(wordOrId, limit: 1);
      if (results.isNotEmpty) {
        entry = results.first;
      }
    }

    if (entry == null) return null;

    // 2. Fetch constituent Hanzi characters with SVG stroke paths
    final chars = entry.simplified
        .split('')
        .where((c) => c.trim().isNotEmpty && (c.codeUnitAt(0) >= 0x4e00 && c.codeUnitAt(0) <= 0x9fff))
        .toList();

    final List<HanziCharacter> constituentChars = [];
    for (final ch in chars) {
      final hanzi = await _hanziDao.getCharacter(ch);
      if (hanzi != null) {
        constituentChars.add(hanzi);
      }
    }

    // 3. Fetch example sentences containing this word
    final sentences = await _sentenceDao.searchSentences(entry.simplified, limit: 5);

    // 4. Fetch related grammar points if tokens match
    final List<GrammarItem> relatedGrammar = [];
    final grammarMatches = await _grammarRepo.getGrammarItems(query: entry.simplified);
    relatedGrammar.addAll(grammarMatches.take(3));

    return UnifiedVocabularyDetails(
      entry: entry,
      constituentCharacters: constituentChars,
      exampleSentences: sentences,
      relatedGrammar: relatedGrammar,
    );
  }

  @override
  Future<UnifiedGrammarDetails?> getGrammarDetails(String grammarId) async {
    final item = await _grammarRepo.getGrammarItemById(grammarId);
    if (item == null) return null;

    // Fetch contextual sentences illustrating this rule
    final sentences = await _sentenceDao.searchSentences(item.title, limit: 5);

    // Fetch related vocabulary items from examples
    final List<DictionaryEntry> relatedVocab = [];
    for (final ex in item.examples.take(2)) {
      final words = await _dictRepo.search(ex.hanzi, limit: 3);
      for (final w in words) {
        if (!relatedVocab.any((v) => v.id == w.id)) {
          relatedVocab.add(w);
        }
      }
    }

    return UnifiedGrammarDetails(
      item: item,
      corpusSentences: sentences,
      relatedVocabulary: relatedVocab,
    );
  }

  @override
  Future<UnifiedHanziDetails?> getHanziDetails(String charOrId) async {
    final hanzi = await _hanziDao.getCharacter(charOrId);
    if (hanzi == null) return null;

    // Fetch vocabulary containing this character
    final vocabMatches = await _dictRepo.search(hanzi.character, limit: 10);

    // Fetch sentences containing this character
    final sentences = await _sentenceDao.searchSentences(hanzi.character, limit: 5);

    return UnifiedHanziDetails(
      character: hanzi,
      vocabularyWords: vocabMatches,
      exampleSentences: sentences,
    );
  }

  @override
  Future<UnifiedSentenceDetails?> getSentenceDetails(String sentenceId) async {
    final sentence = await _sentenceDao.getSentenceById(sentenceId);
    if (sentence == null) return null;

    // Lookup vocabulary for tokens
    final List<DictionaryEntry> words = [];
    for (final tok in sentence.tokens) {
      final entries = await _dictRepo.search(tok.word, limit: 1);
      if (entries.isNotEmpty && !words.any((w) => w.id == entries.first.id)) {
        words.add(entries.first);
      }
    }

    // Lookup Hanzi characters for text
    final chars = sentence.chinese
        .split('')
        .where((c) => c.trim().isNotEmpty && (c.codeUnitAt(0) >= 0x4e00 && c.codeUnitAt(0) <= 0x9fff))
        .toSet();

    final List<HanziCharacter> characters = [];
    for (final ch in chars) {
      final h = await _hanziDao.getCharacter(ch);
      if (h != null) characters.add(h);
    }

    // Lookup illustrated grammar tags
    final List<GrammarItem> grammar = [];
    for (final tag in sentence.grammarTags) {
      final matches = await _grammarRepo.getGrammarItems(query: tag);
      for (final m in matches) {
        if (!grammar.any((g) => g.id == m.id)) {
          grammar.add(m);
        }
      }
    }

    return UnifiedSentenceDetails(
      sentence: sentence,
      constituentWords: words,
      constituentCharacters: characters,
      illustratedGrammar: grammar,
    );
  }

  @override
  Future<KnowledgeSyncReport> syncAllEntitiesToKnowledgeRegistry() async {
    final sw = Stopwatch()..start();
    int vocabCount = 0;
    int grammarCount = 0;
    int hanziCount = 0;
    int sentenceCount = 0;

    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Sync Vocabularies
    final vocabRows = await _db.query(
      DatabaseConstants.tableVocabularies,
      columns: ['id', 'simplified', 'pinyin_clean', 'hsk_level'],
    );
    final List<Map<String, dynamic>> vocabRegistry = [];
    for (final r in vocabRows) {
      final simplified = r['simplified'] as String;
      final clean = r['pinyin_clean'] as String? ?? '';
      final knowId = clean.isNotEmpty
          ? 'KNOW_VOCAB_${simplified}_$clean'
          : 'KNOW_VOCAB_$simplified';

      vocabRegistry.add({
        'id': knowId,
        'entity_type': 'vocabulary',
        'canonical_id': simplified,
        'hsk_level': (r['hsk_level'] as num?)?.toInt() ?? 1,
        'title': simplified,
        'package_id': 'pack_vocab_hsk_${r['hsk_level']}',
        'metadata_json': jsonEncode({'source_pk': r['id'], 'pinyin_clean': clean}),
        'created_at': now,
        'updated_at': now,
      });
    }
    await _knowledgeDao.upsertKnowledgeItemsBatch(vocabRegistry, executor: _db);
    vocabCount = vocabRegistry.length;

    // 2. Sync Grammar Items
    final grammarRows = await _db.query(
      DatabaseConstants.tableGrammarItems,
      columns: ['id', 'grammar_id', 'title', 'hsk_level_mapped', 'topic_category'],
    );
    final List<Map<String, dynamic>> grammarRegistry = [];
    for (final r in grammarRows) {
      final gId = r['grammar_id'] as String;
      final knowId = 'KNOW_GRAM_$gId';

      grammarRegistry.add({
        'id': knowId,
        'entity_type': 'grammar',
        'canonical_id': gId,
        'hsk_level': (r['hsk_level_mapped'] as num?)?.toInt() ?? 1,
        'title': r['title'] as String,
        'package_id': 'pack_grammar_hsk_${r['hsk_level_mapped']}',
        'metadata_json': jsonEncode({'topic': r['topic_category']}),
        'created_at': now,
        'updated_at': now,
      });
    }
    await _knowledgeDao.upsertKnowledgeItemsBatch(grammarRegistry, executor: _db);
    grammarCount = grammarRegistry.length;

    // 3. Sync Hanzi Characters
    final hanziRows = await _db.query(
      DatabaseConstants.tableHanziCharacters,
      columns: ['id', 'character', 'hsk_level', 'stroke_count'],
    );
    final List<Map<String, dynamic>> hanziRegistry = [];
    for (final r in hanziRows) {
      final ch = r['character'] as String;
      final knowId = 'KNOW_HANZI_$ch';

      hanziRegistry.add({
        'id': knowId,
        'entity_type': 'hanzi',
        'canonical_id': ch,
        'hsk_level': (r['hsk_level'] as num?)?.toInt() ?? 1,
        'title': ch,
        'package_id': 'pack_hanzi_hsk_${r['hsk_level']}',
        'metadata_json': jsonEncode({'strokes': r['stroke_count']}),
        'created_at': now,
        'updated_at': now,
      });
    }
    await _knowledgeDao.upsertKnowledgeItemsBatch(hanziRegistry, executor: _db);
    hanziCount = hanziRegistry.length;

    // 4. Sync Sentences
    final sentenceRows = await _db.query(
      DatabaseConstants.tableSentences,
      columns: ['id', 'chinese', 'hsk_level', 'has_human_audio'],
    );
    final List<Map<String, dynamic>> sentenceRegistry = [];
    for (final r in sentenceRows) {
      final sId = r['id'] as String;
      final knowId = 'KNOW_SENT_$sId';

      sentenceRegistry.add({
        'id': knowId,
        'entity_type': 'sentence',
        'canonical_id': sId,
        'hsk_level': (r['hsk_level'] as num?)?.toInt() ?? 1,
        'title': r['chinese'] as String,
        'package_id': 'pack_sentences_hsk_${r['hsk_level']}',
        'metadata_json': jsonEncode({'has_audio': r['has_human_audio'] == 1}),
        'created_at': now,
        'updated_at': now,
      });
    }
    await _knowledgeDao.upsertKnowledgeItemsBatch(sentenceRegistry, executor: _db);
    sentenceCount = sentenceRegistry.length;

    sw.stop();
    return KnowledgeSyncReport(
      vocabulariesRegistered: vocabCount,
      grammarRegistered: grammarCount,
      hanziRegistered: hanziCount,
      sentencesRegistered: sentenceCount,
      elapsed: sw.elapsed,
    );
  }

  @override
  Future<void> recordPracticeEvidence({
    required String knowledgeId,
    required String activityType,
    required double score,
    int durationMs = 0,
    Map<String, dynamic> metadata = const {},
  }) async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final evidenceId = 'evid_${now.millisecondsSinceEpoch}_${knowledgeId.hashCode}';

    // 1. Insert immutable evidence into learner_evidence
    await _db.insert(
      DatabaseConstants.tableLearnerEvidence,
      {
        'id': evidenceId,
        'srs_item_id': 'srs_$knowledgeId',
        'content_id': knowledgeId,
        'content_type': 'knowledge',
        'source': activityType,
        'score': score.clamp(0.0, 1.0),
        'duration_ms': durationMs,
        'metadata_json': jsonEncode(metadata),
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Update mastery state in curriculum_mastery
    final masteryScore = score >= 0.8 ? 1.0 : (score >= 0.5 ? 0.7 : 0.4);
    final masteryState = score >= 0.8 ? 'completed' : 'in_progress';

    await _db.rawInsert('''
      INSERT INTO ${DatabaseConstants.tableCurriculumMastery} (
        id, item_id, item_type, mastery_state, score,
        attempts_count, last_attempt_at, due_review_at, created_at, updated_at
      ) VALUES (?, ?, 'knowledge', ?, ?, 1, ?, ?, ?, ?)
      ON CONFLICT(item_id) DO UPDATE SET
        mastery_state = excluded.mastery_state,
        score = excluded.score,
        attempts_count = ${DatabaseConstants.tableCurriculumMastery}.attempts_count + 1,
        last_attempt_at = excluded.last_attempt_at,
        due_review_at = excluded.due_review_at,
        updated_at = excluded.updated_at;
    ''', [
      'mastery_$knowledgeId',
      knowledgeId,
      masteryState,
      masteryScore,
      nowIso,
      now.add(const Duration(days: 3)).toIso8601String(),
      nowIso,
      nowIso,
    ]);

    // 3. Schedule / update SRS item in srs_items
    final intervalDays = score >= 0.8 ? 3 : 1;
    final dueAt = now.add(Duration(days: intervalDays)).toIso8601String();

    await _db.rawInsert('''
      INSERT INTO ${DatabaseConstants.tableSrsItems} (
        id, content_id, content_type, state, interval_days, ease_factor,
        repetitions, lapses, due_at, last_reviewed_at, created_at, updated_at
      ) VALUES (?, ?, 'knowledge', 'review', ?, 2.5, 1, 0, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        state = 'review',
        interval_days = excluded.interval_days,
        repetitions = ${DatabaseConstants.tableSrsItems}.repetitions + 1,
        last_reviewed_at = excluded.last_reviewed_at,
        due_at = excluded.due_at,
        updated_at = excluded.updated_at;
    ''', [
      'srs_$knowledgeId',
      knowledgeId,
      intervalDays,
      dueAt,
      nowIso,
      nowIso,
      nowIso,
    ]);
  }
}
