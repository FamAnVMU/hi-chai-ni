import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/dictionary_history_dao.dart';
import '../../../../core/database/dao/user_saved_words_dao.dart';
import '../../../../core/database/dao/vocabulary_dao.dart';
import '../../../../core/network/ai/ai.dart';
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
  final AiService _aiService;
  late final VocabularyDao _vocabDao;
  late final UserSavedWordsDao _savedWordsDao;
  late final DictionaryHistoryDao _historyDao;

  @override
  Database? get database => _db;

  DefaultDictionaryRepository(
    this._db, {
    AiService? aiService,
  })  : _aiService = aiService ??
            AiService(
              provider: GeminiRestAiProvider(
                credentialStorage: AiCredentialStorage(),
              ),
              credentialStorage: AiCredentialStorage(),
              modelRegistry: AiModelRegistry(),
            ) {
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
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      throw const AiValidationException('Từ vựng cần phân tích không được để trống.');
    }

    final contextClause = contextSentence != null && contextSentence.trim().isNotEmpty
        ? 'Phân tích cụ thể sắc thái và vai trò ngữ pháp của từ trong ngữ cảnh câu: "$contextSentence".'
        : 'Giải thích sắc thái biểu cảm và ngữ cảnh sử dụng tự nhiên của từ.';

    final systemPrompt = '''
Bạn là Trợ Giảng Tiếng Trung AI Sư Phạm chuyên nghiệp trong ứng dụng "HI Chinese", chuyên phân tích từ vựng chuyên sâu cho người Việt Nam học tiếng Hán.

# MỤC TIÊU SƯ PHẠM
Hãy phân tích từ vựng được yêu cầu theo đúng cấu trúc chuẩn sau:
1. **Nghĩa & Từ loại**: Giải thích nghĩa gốc, từ loại chính, và nghĩa mở rộng phổ biến nhất.
2. **Cấu tạo chữ Hán & Chiết tự**: Phân tích bộ thủ, cấu trúc chữ (hội ý, hình thanh, tượng hình...), ý nghĩa các thành phần tạo nên chữ để người học dễ nhớ mặt chữ.
3. **Phân tích ngữ cảnh**: $contextClause
4. **2 Câu ví dụ chuẩn HSK**: Cung cấp đúng 2 câu ví dụ thực tế, tự nhiên. Mỗi câu BẮT BUỘC có đủ: Chữ Hán giản thể, Pinyin có dấu thanh, và bản dịch tiếng Việt chuẩn xác.
5. **Lỗi người Việt hay mắc (Cảnh báo sư phạm)**: Chỉ rõ lỗi sai phổ biến của người Việt (ví dụ: dùng sai ngữ cảnh, dịch từng chữ theo Hán-Việt thô ráp, nhầm với từ gần nghĩa hoặc lỗi trật tự từ).

# NGUYÊN TẮC BẮT BUỘC
- Ngôn ngữ giải thích: Tiếng Việt sư phạm, khúc chiết, chuẩn mực.
- Tuyệt đối KHÔNG gợi ý người học làm bài kiểm tra năng lực đầu vào (placement test).
- Trình bày dạng Markdown có gạch đầu dòng rõ ràng, dễ đọc trên thiết bị di động.
''';

    final userPrompt = contextSentence != null && contextSentence.trim().isNotEmpty
        ? 'Hãy phân tích từ "$trimmedWord" xuất hiện trong câu ngữ cảnh: "$contextSentence".'
        : 'Hãy phân tích chi tiết từ vựng "$trimmedWord".';

    final request = AiPromptRequest.singlePrompt(
      userPrompt,
      systemInstruction: systemPrompt,
      temperature: 0.3,
      taskId: 'dictionary_word_explanation',
    );

    final response = await _aiService.generateText(
      request,
      taskType: AiTaskType.dictionaryExplanation,
    );

    return response.text.trim();
  }
}
