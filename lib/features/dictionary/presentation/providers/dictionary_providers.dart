import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../data/dictionary_repository.dart';
import '../../domain/models/dictionary_models.dart';

final dictionaryRepositoryProvider = Provider<DictionaryRepository>((ref) {
  final db = AppDatabase.instance.database;
  final aiService = ref.watch(aiServiceProvider);
  return DefaultDictionaryRepository(db, aiService: aiService);
});

class DictionarySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final dictionarySearchQueryProvider =
    NotifierProvider<DictionarySearchQueryNotifier, String>(
  DictionarySearchQueryNotifier.new,
);

final dictionarySearchResultsProvider =
    FutureProvider.autoDispose<List<DictionaryEntry>>((ref) async {
  final query = ref.watch(dictionarySearchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repo = ref.watch(dictionaryRepositoryProvider);
  return await repo.search(query);
});

final savedWordsListProvider =
    FutureProvider.autoDispose<List<UserSavedWord>>((ref) async {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return await repo.getSavedWords();
});

final recentSearchesProvider =
    FutureProvider.autoDispose<List<DictionaryHistoryItem>>((ref) async {
  final repo = ref.watch(dictionaryRepositoryProvider);
  return await repo.getRecentSearches();
});
