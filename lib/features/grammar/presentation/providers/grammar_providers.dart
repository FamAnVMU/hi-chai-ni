import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/grammar_repository.dart';
import '../../domain/engine/grammar_evaluation_engine.dart';
import '../../domain/models/grammar_models.dart';

final grammarRepositoryProvider = Provider<GrammarRepository>((ref) {
  final db = AppDatabase.instance.database;
  return DefaultGrammarRepository(db);
});

final grammarEvaluationEngineProvider = Provider<GrammarEvaluationEngine>((ref) {
  return const GrammarEvaluationEngine();
});

class SelectedGrammarHskNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectLevel(int? lvl) => state = lvl;
}

final selectedGrammarHskProvider =
    NotifierProvider<SelectedGrammarHskNotifier, int?>(
  SelectedGrammarHskNotifier.new,
);

class SelectedGrammarTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selectTag(String? tag) => state = tag;
}

final selectedGrammarTagProvider =
    NotifierProvider<SelectedGrammarTagNotifier, String?>(
  SelectedGrammarTagNotifier.new,
);

class GrammarSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final grammarSearchQueryProvider =
    NotifierProvider<GrammarSearchQueryNotifier, String>(
  GrammarSearchQueryNotifier.new,
);

final grammarListProvider = FutureProvider.autoDispose<List<GrammarItem>>((ref) async {
  final repo = ref.watch(grammarRepositoryProvider);
  final hsk = ref.watch(selectedGrammarHskProvider);
  final tag = ref.watch(selectedGrammarTagProvider);
  final query = ref.watch(grammarSearchQueryProvider);

  return await repo.getGrammarItems(
    hskLevel: hsk,
    tag: tag,
    query: query.isEmpty ? null : query,
  );
});

final grammarProgressMapProvider =
    FutureProvider.autoDispose<Map<String, GrammarProgress>>((ref) async {
  final repo = ref.watch(grammarRepositoryProvider);
  return await repo.getAllProgressMap();
});

final grammarDetailProvider =
    FutureProvider.autoDispose.family<GrammarItem?, String>((ref, id) async {
  final repo = ref.watch(grammarRepositoryProvider);
  return await repo.getGrammarItemById(id);
});

final grammarItemProgressProvider =
    FutureProvider.autoDispose.family<GrammarProgress?, String>((ref, id) async {
  final repo = ref.watch(grammarRepositoryProvider);
  return await repo.getProgress(id);
});
