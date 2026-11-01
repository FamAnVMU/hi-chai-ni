import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/shadowing_repository.dart';
import '../../domain/engine/shadowing_document_bank.dart';
import '../../domain/engine/shadowing_evaluator.dart';
import '../../domain/models/shadowing_models.dart';

/// Exposes the SQLite repository for Shadowing.
final shadowingRepositoryProvider = Provider<ShadowingRepository>((ref) {
  final db = AppDatabase.instance.database;
  return ShadowingRepository(db);
});

/// Exposes the static shadowing document bank.
final shadowingDocumentBankProvider = Provider<ShadowingDocumentBank>((ref) {
  return const ShadowingDocumentBank();
});

/// Exposes the Shadowing evaluator.
final shadowingEvaluatorProvider = Provider<ShadowingEvaluator>((ref) {
  return const ShadowingEvaluator();
});

/// Notifier managing active document selection.
class SelectedShadowingDocumentNotifier extends Notifier<ShadowingDocument> {
  @override
  ShadowingDocument build() {
    return ShadowingDocumentBank.allDocuments.first;
  }

  void selectDocument(ShadowingDocument doc) {
    state = doc;
  }
}

final selectedShadowingDocumentProvider =
    NotifierProvider<SelectedShadowingDocumentNotifier, ShadowingDocument>(
  SelectedShadowingDocumentNotifier.new,
);

/// Notifier managing active sentence segment index within the document.
class SelectedSegmentIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selectIndex(int index) {
    state = index;
  }

  void next(int maxIndex) {
    if (state < maxIndex - 1) {
      state++;
    }
  }

  void previous() {
    if (state > 0) {
      state--;
    }
  }
}

final selectedSegmentIndexProvider =
    NotifierProvider<SelectedSegmentIndexNotifier, int>(
  SelectedSegmentIndexNotifier.new,
);

/// Notifier managing shadowing mode.
class ShadowingModeNotifier extends Notifier<ShadowingMode> {
  @override
  ShadowingMode build() => ShadowingMode.listenThenRepeat;

  void setMode(ShadowingMode mode) {
    state = mode;
  }
}

final shadowingModeProvider =
    NotifierProvider<ShadowingModeNotifier, ShadowingMode>(
  ShadowingModeNotifier.new,
);

/// Notifier managing playback speed.
class ShadowingPlaybackSpeedNotifier extends Notifier<ShadowingPlaybackSpeed> {
  @override
  ShadowingPlaybackSpeed build() => ShadowingPlaybackSpeed.normal;

  void setSpeed(ShadowingPlaybackSpeed speed) {
    state = speed;
  }
}

final shadowingPlaybackSpeedProvider =
    NotifierProvider<ShadowingPlaybackSpeedNotifier, ShadowingPlaybackSpeed>(
  ShadowingPlaybackSpeedNotifier.new,
);

/// Latest evaluation result.
class LastShadowingResultNotifier extends Notifier<ShadowingAssessmentResult?> {
  @override
  ShadowingAssessmentResult? build() => null;

  void setResult(ShadowingAssessmentResult? result) {
    state = result;
  }
}

final lastShadowingResultProvider =
    NotifierProvider<LastShadowingResultNotifier, ShadowingAssessmentResult?>(
  LastShadowingResultNotifier.new,
);

/// Active SQLite evidence ID.
class LastShadowingEvidenceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setEvidenceId(String? id) {
    state = id;
  }
}

final lastShadowingEvidenceIdProvider =
    NotifierProvider<LastShadowingEvidenceIdNotifier, String?>(
  LastShadowingEvidenceIdNotifier.new,
);
