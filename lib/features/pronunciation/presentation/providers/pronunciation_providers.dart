import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio.dart';
import '../../../../core/database/app_database.dart';
import '../../data/pronunciation_repository.dart';
import '../../domain/engine/pronunciation_item_bank.dart';
import '../../domain/models/pronunciation_models.dart';
import '../../domain/services/pronunciation_analysis_service.dart';

/// Exposes the SQLite repository for Pronunciation Lab.
final pronunciationRepositoryProvider = Provider<PronunciationRepository>((ref) {
  final db = AppDatabase.instance.database;
  return PronunciationRepository(db);
});

/// Exposes the static pronunciation items bank.
final pronunciationItemBankProvider = Provider<PronunciationItemBank>((ref) {
  return const PronunciationItemBank();
});

/// Exposes the speech & acoustic pronunciation evaluation service.
final pronunciationAnalysisServiceProvider = Provider<PronunciationAnalysisService>((ref) {
  return const DefaultPronunciationAnalysisService();
});

/// Exposes the audio recorder service.
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = DefaultAudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Exposes the audio player service.
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = DefaultAudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Notifier managing active target selection in the Lab.
class SelectedPronunciationTargetNotifier extends Notifier<PronunciationTarget> {
  @override
  PronunciationTarget build() {
    return PronunciationItemBank.allTargets.first;
  }

  void selectTarget(PronunciationTarget target) {
    state = target;
  }

  void selectTargetById(String id) {
    final bank = ref.read(pronunciationItemBankProvider);
    final target = bank.getTargetById(id);
    if (target != null) {
      state = target;
    }
  }
}

final selectedPronunciationTargetProvider =
    NotifierProvider<SelectedPronunciationTargetNotifier, PronunciationTarget>(
  SelectedPronunciationTargetNotifier.new,
);

/// State of the latest evaluation result.
class LastPronunciationResultNotifier extends Notifier<PronunciationAssessmentResult?> {
  @override
  PronunciationAssessmentResult? build() => null;

  void setResult(PronunciationAssessmentResult? result) {
    state = result;
  }
}

final lastPronunciationResultProvider =
    NotifierProvider<LastPronunciationResultNotifier, PronunciationAssessmentResult?>(
  LastPronunciationResultNotifier.new,
);

/// Currently active evidence ID in SQLite.
class LastPronunciationEvidenceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setEvidenceId(String? id) {
    state = id;
  }
}

final lastPronunciationEvidenceIdProvider =
    NotifierProvider<LastPronunciationEvidenceIdNotifier, String?>(
  LastPronunciationEvidenceIdNotifier.new,
);
