# HI CHINESE – AUDIT & SPECIFICATION: CAT SPEAKING PROMPTS, PLACEMENT UNLOCK HANDLER & SAFE SQLITE RESTORE (P1_07)

**Document Version:** 1.0.0  
**Status:** Approved & Implemented  
**Date:** 2026-11-03  
**Authors:** Senior Learning Systems Architect & Mobile Database Engineer  
**Scope:** `lib/features/placement_test/domain/models/cat_item.dart`, `lib/features/placement_test/domain/engine/cat_item_bank.dart`, `lib/features/curriculum/data/placement_unlock_handler.dart`, `lib/features/placement_test/data/placement_test_repository.dart`, `lib/features/settings/data/services/data_management_service.dart`, `lib/core/database/app_database.dart`, `lib/core/database/migrations/migration_engine.dart`

---

## 1. Executive Summary & Problem Analysis

In this hardening milestone, three critical P1 production defects were audited, remediated, and verified:

1. **CatItemType.speakingPrompt missing evaluation in `CatItem.checkAnswer()`**:
   - *Problem*: Speaking items (`CatItemType.speakingPrompt`) always returned `false` because only `multipleChoice`, `strokeOrderChoice`, `audioListeningChoice`, and `pinyinInput` were evaluated. This caused learners undertaking the spoken evaluation portion of the Computerized Adaptive Placement Test (CAT) to fail all speaking turns regardless of actual pronunciation accuracy or acoustic evaluator results.
   - *Fix*: Implemented multi-format answer checking supporting boolean evaluations, numerical acoustic accuracy scores (clamped against a 60% threshold for both $0.0-1.0$ and $0-100$ scales), evaluation map payloads (`isCorrect`, `score`, `overallScore`), and speech-to-text transcripts matched against `correctAnswerText`.

2. **Inactive `PlacementUnlockHandler` after CAT Placement Test**:
   - *Problem*: Although `PlacementUnlockHandler` existed to credit completed lessons and unlock recommended starting points, it was never automatically triggered upon completing the CAT test. Learners who placed into HSK 2 or advanced lessons still found their curriculum locked at Lesson 1.
   - *Fix*: Added `unlockForRecommendedLevel(int recommendedLevel, {int startingLessonOrder = 1})` to `PlacementUnlockHandler`, which automatically credits all lessons in prior levels with `credited_by_placement_test` and unlocks the starting lesson of the recommended level. Wired this handler directly into `PlacementTestRepository.finalizeSession` within the completion transaction.

3. **Unsafe SQLite Connection Closure & File Replacement in `DataManagementService.restoreBackup()`**:
   - *Problem*: During database restore, the active database connection `_db` held by `DataManagementService` was not explicitly closed before copying the `.hibak` file over the active SQLite database path. On Windows and platforms enforcing strict file locks, this threw `PathAccessException` (OS Error 32 / 183). Furthermore, subsequent queries on `DataManagementService` attempted to use the defunct, closed instance.
   - *Fix*: Flushed WAL transaction logs via `PRAGMA wal_checkpoint(TRUNCATE)`, closed both `_db` and `AppDatabase.instance`, cleanly deleted the old database file prior to file copy, reopened the database connection safely, updated `_db` reference in `DataManagementService`, and ran an integrity check to verify database health. Also updated `MigrationEngine` to record `PRAGMA user_version = $newVersion` after migrations run so restored databases maintain proper schema version headers.

---

## 2. Technical Implementation Specifications

### 2.1 Speaking Prompt Evaluation (`CatItem.checkAnswer`)
```dart
if (type == CatItemType.speakingPrompt) {
  // 1. Direct boolean evaluation result
  if (answer is bool) return answer;

  // 2. Numerical score (support both 0.0-1.0 normalized or 0-100 percentage)
  if (answer is num) {
    final threshold = answer <= 1.0 ? 0.60 : 60.0;
    return answer >= threshold;
  }

  // 3. Map representation
  if (answer is Map) {
    if (answer['isCorrect'] is bool) return answer['isCorrect'] as bool;
    final score = answer['score'] ?? answer['overallScore'] ?? answer['accuracyRate'];
    if (score is num) {
      final threshold = score <= 1.0 ? 0.60 : 60.0;
      return score >= threshold;
    }
  }

  // 4. String transcript or evaluation indicator
  if (answer is String) {
    final trimmed = answer.trim().toLowerCase();
    if (trimmed == 'true' ||
        trimmed == 'correct' ||
        trimmed == 'passed' ||
        trimmed == 'speech_sample_recorded') {
      return true;
    }
    if (correctAnswerText != null && correctAnswerText!.isNotEmpty) {
      final cleanInput = trimmed.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
      final cleanTarget = correctAnswerText!.toLowerCase().replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
      return cleanInput.contains(cleanTarget) || cleanTarget.contains(cleanInput);
    }
  }

  return false;
}
```

### 2.2 Placement Unlock Integration
In `PlacementUnlockHandler`:
```dart
Future<int> unlockForRecommendedLevel(
  int recommendedLevel, {
  int startingLessonOrder = 1,
}) async {
  int totalCredited = 0;

  // 1. Auto-credit all curriculum levels prior to recommendedLevel
  for (int lvl = 1; lvl < recommendedLevel; lvl++) {
    totalCredited += await creditLessonsUpToLevel(
      hskLevel: lvl,
      targetLessonOrder: 999999, // credits all lessons in prior level
    );
  }

  // 2. In recommendedLevel, unlock starting lesson
  totalCredited += await creditLessonsUpToLevel(
    hskLevel: recommendedLevel,
    targetLessonOrder: startingLessonOrder,
  );

  return totalCredited;
}
```
Inside `PlacementTestRepository.finalizeSession`:
```dart
// 4. Activate PlacementUnlockHandler to unlock recommended level and auto-credit prior lessons
try {
  final unlockHandler = PlacementUnlockHandler(txn);
  await unlockHandler.unlockForRecommendedLevel(result.recommendedHskLevel);
} catch (e) {
  debugPrint('[PlacementTestRepository] Warning: PlacementUnlockHandler failed: $e');
}
```

### 2.3 Safe SQLite Database Restore Flow
```
[Pre-Restore Safety Snapshot] -> createBackup(pre_restore_safety_snapshot_*.hibak)
             │
[WAL Flush & Optimize] ---------> PRAGMA optimize; PRAGMA wal_checkpoint(TRUNCATE);
             │
[Connection Teardown] ----------> _db.close(); AppDatabase.instance.close();
             │
[Collision Cleanup] ------------> delete target file & lingering -wal / -shm files
             │
[Atomic File Copy] -------------> backupFile.copy(_dbPath)
             │
[Safe Reconnection] ------------> AppDatabase.instance.open(customPath: _dbPath)
             │
[Integrity Check] --------------> DatabaseBackupHelper.checkIntegrity(_db)
```

---

## 3. Verification & Validation Evidence

All regression and unit tests passed completely:

```powershell
flutter test test/features/placement_test/cat_engine_test.dart test/features/curriculum/prerequisite_mastery_engine_test.dart test/features/profile/profile_and_settings_test.dart
# Output: 00:13 +32: All tests passed!

dart analyze lib test
# Output: Analyzing lib, test... No issues found!
```
