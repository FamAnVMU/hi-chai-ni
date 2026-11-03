import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../hanzi/data/hanzi_dao.dart';
import '../../data/hanzi_writing_repository.dart';
import '../../domain/engine/hanzi_stroke_bank.dart';
import '../../domain/engine/stroke_evaluator.dart';
import '../../domain/models/stroke_models.dart';

/// Exposes the SQLite repository for Hanzi writing.
final hanziWritingRepositoryProvider = Provider<HanziWritingRepository>((ref) {
  final db = AppDatabase.instance.database;
  return HanziWritingRepository(db);
});

/// Exposes the Hanzi Stroke Bank connected to the shared Hanzi database.
final hanziStrokeBankProvider = Provider<HanziStrokeBank>((ref) {
  final db = AppDatabase.instance.database;
  final dao = HanziDao(db);
  return HanziStrokeBank(dao);
});

/// Exposes the pure mathematical Stroke Evaluator.
final strokeEvaluatorProvider = Provider<StrokeEvaluator>((ref) {
  return const StrokeEvaluator();
});

/// The active character being practiced in the session.
class SelectedHanziCharacterNotifier extends Notifier<String> {
  @override
  String build() => '十';

  void selectCharacter(String char) {
    state = char;
  }
}

final selectedHanziCharacterProvider =
    NotifierProvider<SelectedHanziCharacterNotifier, String>(
  SelectedHanziCharacterNotifier.new,
);

/// Provider returning stroke order specification for the selected character,
/// resolving from curated bank, dynamic cache, or shared database.
final currentHanziStrokeDataProvider = FutureProvider<HanziStrokeData?>((ref) async {
  final character = ref.watch(selectedHanziCharacterProvider);
  final bank = ref.watch(hanziStrokeBankProvider);
  return bank.getStrokeDataAsync(character);
});

/// Provider returning available characters for study.
final availableHanziCharactersProvider = FutureProvider<List<String>>((ref) async {
  final bank = ref.watch(hanziStrokeBankProvider);
  return bank.getAvailableCharactersAsync(limit: 100);
});
