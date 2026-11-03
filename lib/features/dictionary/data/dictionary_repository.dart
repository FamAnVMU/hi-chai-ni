import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/dictionary_history_dao.dart';
import '../../../../core/database/dao/user_saved_words_dao.dart';
import '../../../../core/database/dao/vocabulary_dao.dart';
import '../domain/models/dictionary_models.dart';
import '../domain/utils/pinyin_helper.dart';

abstract class DictionaryRepository {
  Future<List<DictionaryEntry>> search(String query, {int limit = 30});
  Future<DictionaryEntry?> getWordById(String id);
  Future<DictionaryEntry?> getWordByExactHanzi(String hanzi);
  Future<bool> toggleSaveWord(DictionaryEntry entry, {String? customNote});
  Future<void> updateWordNote(String vocabularyId, String? note);
  Future<List<UserSavedWord>> getSavedWords();
  Future<List<DictionaryHistoryItem>> getRecentSearches({int limit = 20});
  Future<void> clearSearchHistory();
  Future<String> explainWordWithAi(String word, {String? contextSentence});
  Database? get database => null;
}

class DefaultDictionaryRepository implements DictionaryRepository {
  final Database _db;
  late final VocabularyDao _vocabDao;
  late final UserSavedWordsDao _savedWordsDao;
  late final DictionaryHistoryDao _historyDao;

  @override
  Database? get database => _db;

  DefaultDictionaryRepository(this._db) {
    _vocabDao = VocabularyDao(_db);
    _savedWordsDao = UserSavedWordsDao(_db);
    _historyDao = DictionaryHistoryDao(_db);
  }

  @override
  Future<List<DictionaryEntry>> search(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = PinyinHelper.removeTones(trimmed);
    final rawResults = await _vocabDao.searchVocabulariesAdvanced(
      trimmed,
      limit: limit,
      normalizedPinyin: normalized != trimmed.toLowerCase() ? normalized : null,
    );

    // Record search in history asynchronously
    final historyId = 'hist_${DateTime.now().microsecondsSinceEpoch}';
    final searchType = PinyinHelper.containsChinese(trimmed)
        ? 'hanzi'
        : (PinyinHelper.isPinyinOrLatin(trimmed) ? 'pinyin' : 'meaning');
    await _historyDao.insertHistory(
      id: historyId,
      query: trimmed,
      searchType: searchType,
    );

    final vocabIds = rawResults.map((r) => r['id'] as String).toList();
    final sensesMap = await _vocabDao.getSensesByVocabularyIds(vocabIds);
    final examplesMap = await _vocabDao.getExamplesByVocabularyIds(vocabIds);
    final savedMap = await _savedWordsDao.getSavedWordsByIds(vocabIds);

    final entries = <DictionaryEntry>[];
    for (final row in rawResults) {
      final id = row['id'] as String;
      final rawSenses = sensesMap[id] ?? const [];
      final senses = rawSenses.map((s) => DictionarySense.fromMap(s)).toList();
      final rawExamples = examplesMap[id] ?? const [];
      final examples = rawExamples.map((e) => DictionaryExample.fromMap(e)).toList();
      final savedData = savedMap[id];

      entries.add(DictionaryEntry.fromMap(
        row,
        senses: senses,
        examples: examples,
        isSaved: savedData != null && (savedData['is_favorite'] == 1),
        customNote: savedData?['custom_note'] as String?,
      ));
    }

    // Fallback: If no core HSK word matched and limit permits, search 122k general offline dictionary
    if (entries.length < limit) {
      final dictRows = await _vocabDao.searchDictionaryEntries(trimmed, limit: limit - entries.length);
      for (final d in dictRows) {
        final dId = 'dict_${d['id'] ?? d['simplified']}';
        if (entries.any((e) => e.simplified == d['simplified'])) continue;

        entries.add(DictionaryEntry(
          id: dId,
          simplified: d['simplified'] as String,
          traditional: d['traditional'] as String?,
          pinyin: d['pinyin'] as String,
          pinyinClean: d['pinyin_clean'] as String?,
          hanviet: d['hanviet'] as String?,
          hskLevel: (d['hsk_level'] as num?)?.toInt() ?? 0,
          source: d['source'] as String? ?? 'CVDICT',
          senses: [
            DictionarySense(
              id: 'sns_$dId',
              partOfSpeech: 'từ vựng',
              meaningVi: d['meaning_vi'] as String? ?? '',
              meaningEn: d['meaning_en'] as String?,
              source: 'CVDICT',
            )
          ],
        ));
      }
    }

    return entries;
  }

  @override
  Future<DictionaryEntry?> getWordById(String id) async {
    final row = await _vocabDao.getVocabularyById(id);
    if (row == null) return null;

    final rawSenses = await _vocabDao.getSensesByVocabularyId(id);
    final senses = rawSenses.map((s) => DictionarySense.fromMap(s)).toList();
    final rawExamples = await _vocabDao.getExamplesByVocabularyId(id);
    final examples = rawExamples.map((e) => DictionaryExample.fromMap(e)).toList();
    final savedData = await _savedWordsDao.getSavedWord(id);

    return DictionaryEntry.fromMap(
      row,
      senses: senses,
      examples: examples,
      isSaved: savedData != null && (savedData['is_favorite'] == 1),
      customNote: savedData?['custom_note'] as String?,
    );
  }

  @override
  Future<DictionaryEntry?> getWordByExactHanzi(String hanzi) async {
    final trimmed = hanzi.trim();
    final results = await _vocabDao.searchVocabulariesAdvanced(trimmed, limit: 5);
    final match = results.where(
      (r) => (r['simplified'] == trimmed || r['traditional'] == trimmed),
    );

    if (match.isEmpty) return null;
    return getWordById(match.first['id'] as String);
  }

  @override
  Future<bool> toggleSaveWord(DictionaryEntry entry, {String? customNote}) async {
    final currentlySaved = await _savedWordsDao.isWordSaved(entry.id);
    if (currentlySaved) {
      await _savedWordsDao.removeSavedWord(entry.id);
      return false;
    } else {
      final saveId = 'save_${entry.id}_${DateTime.now().millisecondsSinceEpoch}';
      await _savedWordsDao.saveWord(
        id: saveId,
        vocabularyId: entry.id,
        simplified: entry.simplified,
        pinyin: entry.pinyin,
        customNote: customNote ?? entry.customNote,
        isFavorite: true,
      );
      return true;
    }
  }

  @override
  Future<void> updateWordNote(String vocabularyId, String? note) async {
    await _savedWordsDao.updateCustomNote(vocabularyId, note);
  }

  @override
  Future<List<UserSavedWord>> getSavedWords() async {
    final rows = await _savedWordsDao.getSavedWords(onlyFavorites: true);
    return rows.map((r) => UserSavedWord.fromMap(r)).toList();
  }

  @override
  Future<List<DictionaryHistoryItem>> getRecentSearches({int limit = 20}) async {
    final rows = await _historyDao.getRecentSearches(limit: limit);
    return rows.map((r) => DictionaryHistoryItem.fromMap(r)).toList();
  }

  @override
  Future<void> clearSearchHistory() async {
    await _historyDao.clearAllHistory();
  }

  @override
  Future<String> explainWordWithAi(String word, {String? contextSentence}) async {
    return 'Phân tích từ "$word" bằng trợ lý AI.';
  }
}
