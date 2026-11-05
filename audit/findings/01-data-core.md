# T1 — Database & Data Integrity Audit

**Auditor:** data-core (T1) · **Date:** 2026-11-04 · **Method:** static code tracing only (read-only). No Flutter/Dart builds or tests were run by T1. SQLite semantics claims marked `[SQLite-verified]` were reproduced with a standalone `sqlite3` 3.53.1 harness (independent of the app) using the exact schema/FK declarations from the migrations.

## Scope covered

- `lib/core/database/app_database.dart`, `database_constants.dart`, `database_backup_helper.dart`
- `lib/core/database/migrations/migration.dart`, `migration_engine.dart`, `migration_v1.dart` … `migration_v16.dart`, `timezone_data_migrator.dart`
- `lib/core/database/seed/seed_loader.dart`, `seed_data_validator.dart`, `seed_history_dao.dart`, `seed_models.dart`
- `lib/core/database/dao/*.dart` — activity, app_settings, chat, content_item, curriculum, dictionary_history, grammar, knowledge_registry, learner_evidence, mastery, reading, srs, user_saved_words, vocabulary
- `lib/core/knowledge/domain/services/unified_knowledge_service.dart`, `knowledge_identity_registry.dart`, `lib/core/knowledge/domain/models/unified_knowledge_models.dart`
- Multi-table/transaction callers: `learning_pipeline_coordinator`, `srs_repository`, `practice_repository`, `roadmap_repository`, `curriculum_repository`, `reading_repository`, `grammar_repository`, `pinyin_repository`, `placement_test_repository`, `placement_unlock_handler`, `content_pack_manager`, `data_management_service`, `onboarding_providers`, `app_startup_provider`, `home_repository`, `hanzi_dao`/`sentence_dao` seed paths
- Assets cross-checked: `assets/data/hsk_seed_fixture_v2.json` (8.6 MB, 5,000 vocabularies), `assets/data/content_packs/hsk1/hsk1_pack_v1.json`, `assets/data/content_packs/hsk2/hsk2_pack_v1.json`
- Tests reviewed for masking: `test/core/database/*.dart`, `test/core/knowledge/knowledge_identity_and_srs_test.dart`, `test/features/learning_pipeline/learning_pipeline_coordinator_test.dart`
- Docs cross-checked: `README.md`, `docs/system-documentation/04-database-schema.md`, `docs/data-integration/UNIFIED_SCHEMA.md`, `docs/data-integration/ID_STRATEGY.md`, `docs/bug-fixes/P0_04_SQLITE_UPSERT_SAFETY.md`, `P0_01_STARTUP_SEED_LOADING.md`, `F04_F17_UNIFIED_ID_AND_SRS.md`, `F18_TIMEZONE_AND_LEARNING_STREAK.md`
- sqflite behavior verified from the actual resolved package `sqflite_common 2.5.14` in the pub cache (`lib/src/database_mixin.dart:1129–1181`)

## Top 5 priority order

1. **[T1-F01] High — Vocabulary PK namespace collision.** The dictionary seed (`VOC_HSK1_你_ni`) and the mandatory content-pack importer (`vocab_你`) create two different rows for the same Hanzi word on a normal install: **268 duplicate word rows expected** (computed from the shipped assets). Splits dictionary results, SRS cards and progress.
2. **[T1-F03] High — `recordExerciseAttempt()` rewrites `curriculum_mastery` with `INSERT OR REPLACE` and hardcoded `attempts_count: 1`, dropping `due_review_at`.** Every practice answer silently resets mastery history and scheduled-review state. `[SQLite-verified]`
3. **[T1-F02] High — `restoreBackup()` overwrites the live DB with an unvalidated file, closes the singleton connection and reopens it, leaving 25+ providers holding closed `Database` handles; integrity issues are only `debugPrint`-ed and there is no schema-version check.** A single corrupt/incompatible backup file is unrecoverable without a manual app-data wipe.
4. **[T1-F05] Medium — Migration v10 backfill is best-effort: one wrapping `catch` swallows every error, and its `ConflictAlgorithm.replace` on `knowledge_registry` cascades deletion of `lesson_knowledge_items` links inserted earlier.** Users upgrading v9→v10 get a half-migrated knowledge graph with no retry and no error surfaced.
5. **[T1-F04] Medium — Startup freshness gate ignores version/checksum.** `_checkSeedLoaded()` / `_checkPackNeedsImport()` only check `status` + row counts, so a seed/pack content update shipped in an app update is never re-imported (contradicts P0-01 claim of a version check).

---

## [T1-F01] Seed loader and content-pack importer create the same vocabulary word under two different primary keys

- Severity: High
- Confidence: CONFIRMED
- Location: `lib/core/database/seed/seed_loader.dart:181-212`; `lib/features/content_packs/data/content_pack_manager.dart:441-480`; asset evidence `assets/data/hsk_seed_fixture_v2.json` (`"id": "VOC_HSK1_爱_ai"`), `assets/data/content_packs/hsk1/hsk1_pack_v1.json` (`"words":[{"simplified":"你"}...`)`, `assets/data/content_packs/hsk2/hsk2_pack_v1.json`
- Evidence: ```dart
// seed_loader.dart:181-199 — the seed PK is taken verbatim from the JSON bundle ("VOC_HSK1_<word>_<pinyin>")
            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableVocabularies} (
                id, simplified, traditional, pinyin, pinyin_clean, hanviet, hsk_level,
                frequency_rank, source, license, verification_status, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                ...
                updated_at = excluded.updated_at;
            ''', [
              v.id,
```
```dart
// content_pack_manager.dart:441-452 — the pack importer derives a DIFFERENT PK
              final vocabId = 'vocab_$simplified';
              final senseId = 'sense_${simplified}_1';
              final knowId = 'KNOW_VOCAB_$simplified';

              // 1. Insert/update vocabulary without cascade delete
              final existingVocab = await txn.query(
                DatabaseConstants.tableVocabularies,
                columns: ['id'],
                where: 'id = ?',
                whereArgs: [vocabId],
                limit: 1,
              );
```
- Root cause: Both writers are part of the *normal* startup path (`app_startup_provider.dart:114-162`: seed first, then mandatory packs `hsk1_pack_v1`, `hsk2_pack_v1`), but each derives `vocabularies.id` from a different convention. The pack importer only checks for an existing row by its own derived PK (`vocab_<simplified>`), never by `simplified`, so it inserts a second row for a word the seed already loaded. Verified by asset analysis: of the 287 unique pack words, **268 also exist in the 5,000-word seed**; 142 of the 150 HSK-1 pack words and 136 of the 147 HSK-2 pack words overlap the seed. The F-04 report (`docs/bug-fixes/F04_F17_UNIFIED_ID_AND_SRS.md:23-29, 55-66`) and `ID_STRATEGY.md` claim the opposite ("Không tạo 2 bản ghi riêng biệt gây phân mảnh từ điển và trùng lặp tiến độ").
- Impact: On a fresh install the dictionary contains duplicate entries for hundreds of common words (`searchVocabulariesAdvanced()` queries by `simplified = ?` and returns every matching id — `vocabulary_dao.dart:187-194`). SRS treats the two rows as different knowledge items (`getDueFlashcards()` new-word branch joins `vocabularies` filtered only by `NOT EXISTS srs_items`, `srs_repository.dart:286-305`), so the learner can be shown the same word twice with **independent** `srs_items`/`curriculum_mastery`/`lesson_progress` rows. Roadmap stats inflate (`getRoadmapProgress()` counts `vocabularies` per HSK level, `home_repository.dart:468-472`). Favorites/saved words are also split (`user_saved_words.vocabulary_id` is one of the two).
- Fix: Normalise the physical PK in one place before writing. Minimal patch for the pack importer (accept seed rows by word, and stop minting a second namespace):
```dart
// content_pack_manager.dart — resolve existing row by semantic key first
var existingVocab = await txn.query(
  DatabaseConstants.tableVocabularies,
  columns: ['id'],
  where: 'id = ?',
  whereArgs: [vocabId], limit: 1,
);
if (existingVocab.isEmpty) {
  existingVocab = await txn.query(
    DatabaseConstants.tableVocabularies,
    columns: ['id'],
    where: 'simplified = ? AND deleted_at IS NULL',
    whereArgs: [simplified],
    orderBy: 'hsk_level ASC, id ASC', limit: 1,
  );
}
final activeVocabId = existingVocab.isNotEmpty ? existingVocab.first['id'] as String : vocabId;
```
  Then write senses/examples/`knowledge_registry` links against `activeVocabId`. For pre-existing installs add a one-shot migration that merges rows by `simplified` (merge `created_at` min, re-point `vocabulary_senses.vocabulary_id`, `srs_items.content_id`, `curriculum_mastery.item_id`, `user_saved_words.vocabulary_id`, `lesson_knowledge_items`, then hard/soft-delete the loser) inside one transaction. Also add a `UNIQUE` semantic guard, e.g. `CREATE UNIQUE INDEX ux_vocab_word ON vocabularies(simplified, pinyin_clean) WHERE deleted_at IS NULL`.
- Verification status: traced both writers in the startup sequence (`app_startup_provider.dart:114-135` seed, `:140-162` packs), read the full insert blocks, and computed the overlap directly from the two shipped pack JSONs vs `hsk_seed_fixture_v2.json` (5,000 seed rows, all ids prefixed `VOC_`; 268/287 pack words exist in seed). Search path that exposes duplicates traced at `vocabulary_dao.dart:185-194` → `dictionary_repository.dart:59-80`.

## [T1-F02] Restore of a backup is destructive and unvalidated; DB singleton/handles are left inconsistent

- Severity: High
- Confidence: CONFIRMED
- Location: `lib/features/settings/data/services/data_management_service.dart:117-188`; caller `lib/features/settings/presentation/widgets/data_management_sheet.dart:130-161`; `lib/core/database/app_database.dart:92-97`; providers capturing `AppDatabase.instance.database`
- Evidence: ```dart
// data_management_service.dart:145-158 — delete the live DB, copy the backup, then delete WAL/SHM
// (immediately preceded by `await AppDatabase.instance.close();` at line 143)
    // 3. Cleanly remove target file on platforms (e.g. Windows) that fail on copy collision, then copy backup
    final targetDbFile = File(_dbPath);
    if (await targetDbFile.exists()) {
      await targetDbFile.delete();
    }
    await backupFile.copy(_dbPath);

    // 4. Remove lingering -wal and -shm files to avoid inconsistencies
    final walFile = File('$_dbPath-wal');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
```
```dart
// data_management_service.dart:166-186 — fallback open WITHOUT version/migrations; integrity problems only logged
    // 5. Safely re-open database connection
    try {
      _db = await AppDatabase.instance.open(customPath: _dbPath);
    } catch (_) {
      _db = await databaseFactory.openDatabase(
        _dbPath,
        options: OpenDatabaseOptions(
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
            await db.rawQuery('PRAGMA journal_mode = WAL;');
          },
        ),
      );
    }

    // 6. Verify integrity of restored database
    final issues = await DatabaseBackupHelper.checkIntegrity(_db);
    if (issues.isNotEmpty) {
      debugPrint('[DataManagement] Warning: Integrity check issues after restore: $issues');
    }
```
- Root cause: `restoreBackup()` does not validate the candidate file before destroying the live database: no `PRAGMA integrity_check` on the backup, no `user_version`/schema-version comparison, no app-format check. The pre-restore safety snapshot is best-effort and swallowed (`:122-127`). After copying, the file is only checked *after* it has already replaced the live DB and the issue is downgraded to a `debugPrint`. Additionally, the restore closes the singleton (`AppDatabase.instance.close()`, `:143`) and then reopens it, creating a **new** `Database` object; 25+ providers/repositories cached the previous object (grep `AppDatabase.instance.database` → `home_providers.dart:10`, `srs_providers.dart:9`, `dictionary_screen.dart:40`, `onboarding_providers.dart:161`, …), so every cached handle is now a closed connection. The UI only invalidates `userProfileProvider`, `goalHistoryProvider`, `storageBreakdownProvider`, `backupListProvider` and then shows success (`data_management_sheet.dart:146-153`).
- Impact: (a) A corrupted or foreign `.hibak` file silently replaces the learner's database; the previous DB file has already been deleted, so the only recovery is an app-data wipe (the "safety snapshot" is never restored automatically). (b) Restoring a backup made by a *newer* schema triggers the `onDowngrade` `StateError` (`app_database.dart:92-97`); restore then falls through to the raw `openDatabase` fallback that opens the future-version DB without migrations, leaving a schema/data mismatch. (c) After a successful restore, any provider holding the old handle throws `DatabaseException(database_closed)` until process restart; the UI reports success and does not restart. Same flaw underlies every "copy DB file over live DB" flow.
- Fix: validate before touching the live file, and make the restore a hard app restart:
```dart
Future<void> restoreBackup(File backupFile) async {
  // 0) validate the candidate using a throw-away connection
  final probe = await databaseFactory.openDatabase(backupFile.path,
      options: OpenDatabaseOptions(readOnly: true));
  final issues = await DatabaseBackupHelper.checkIntegrity(probe);
  final version = await probe.getVersion();
  await probe.close();
  if (issues.isNotEmpty) throw DatabaseIntegrityException('Backup is corrupt', issues: issues);
  if (version != DatabaseConstants.currentDatabaseVersion) {
    throw StateError('Backup schema v$version is not compatible with app schema '
        'v${DatabaseConstants.currentDatabaseVersion}');
  }
  // 1) best-effort pre-restore snapshot must abort the restore if it fails
  await createBackup(customName: 'pre_restore_safety_snapshot_...hibak');
  // 2) close, swap, and force process restart (e.g. Phoenix/restart_app or
  //    SystemNavigator.pop + relaunch intent) instead of relying on cached handles
  ...
}
```
  At minimum the `onDowngrade` fallback must be removed, and the restore must set an "app must restart" state rather than returning to the normal UI.
- Verification status: traced `data_management_sheet.dart:144-157` (restore call and success snackbar), the close/reopen sequence at `:129-179`, and the provider handle caching with grep for `AppDatabase.instance.database` (28 matches across 20+ provider files). `onDowngrade` throw confirmed at `app_database.dart:92-97`.

## [T1-F03] Practice attempts rewrite mastery rows with `INSERT OR REPLACE`, resetting `attempts_count`, `created_at` and clearing `due_review_at`

- Severity: High
- Confidence: CONFIRMED (SQLite semantics reproduced independently)
- Location: `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:630-654` (correct answer path), `:566-583` (wrong answer path); called from `lib/features/practice/data/practice_repository.dart:221`
- Evidence: ```dart
      } else {
        // Successful attempt: fetch history and evaluate promotion
        final historyRows = await txn.query(
          DatabaseConstants.tableLearnerEvidence,
          where: 'content_id = ?',
          whereArgs: [targetId],
        );
        final history = historyRows.map((r) => LearningEvidence.fromMap(r)).toList();
        final calculatedState = evaluator.evaluate(evidenceHistory: history);

        await txn.insert(
          DatabaseConstants.tableCurriculumMastery,
          {
            'id': 'mastery_$targetId',
            'item_id': targetId,
            'item_type': 'vocabulary',
            'mastery_state': calculatedState.value,
            'score': attempt.score,
            'attempts_count': 1,
            'last_attempt_at': nowIso,
            'created_at': nowIso,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
```
- Root cause: `curriculum_mastery.item_id` is `UNIQUE` (`migration_v9.dart:138-149`), so `ConflictAlgorithm.replace` performs `DELETE` + `INSERT` on the existing row. The replacement map hardcodes `attempts_count: 1`, sets `created_at: nowIso`, and **omits `due_review_at`** (the correct-answer branch) — the old review schedule is lost. The same class of bug exists in the incorrect branch (`:566-583`), which also hardcodes `attempts_count: 1` even though the row it replaces may have an accumulated counter. Reproduced in a standalone SQLite 3.53.1 harness with the exact v9 table DDL: a row with `attempts_count=7, due_review_at='2026-02-01', created_at='2026-01-01'` becomes `(attempts_count=1, due_review_at=NULL, created_at=<now>)` after the replace.
- Impact: Every practice question silently rewrites the learner's mastery record: the attempt counter stops accumulating, the "needs review" schedule (`getItemsNeedingReview()` filters `due_review_at <= now`) permanently loses that timestamp, and `created_at` (used by analytics/streak UI in some paths) is reset. `recordLessonCompletion()` in the same file carefully increments `attempts_count` and preserves `created_at`, so the two pipeline branches now produce inconsistent mastery state for the same item.
- Fix: replace the `insert(... replace)` with an explicit in-place update-and-preserve, like the lesson branch already does:
```dart
final existing = await txn.query(DatabaseConstants.tableCurriculumMastery,
    where: 'item_id = ?', whereArgs: [targetId], limit: 1);
final attempts = existing.isNotEmpty
    ? ((existing.first['attempts_count'] as num?)?.toInt() ?? 0) + 1
    : 1;
final values = <String, dynamic>{
  'id': 'mastery_$targetId',
  'item_id': targetId,
  'item_type': 'vocabulary',
  'mastery_state': calculatedState.value,
  'score': attempt.score,
  'attempts_count': attempts,
  'last_attempt_at': nowIso,
  'created_at': existing.isNotEmpty ? existing.first['created_at'] : nowIso,
  'updated_at': nowIso,
  // preserve prior schedule when the state did not change; only set on failures
  if (existing.isNotEmpty && existing.first['due_review_at'] != null)
    'due_review_at': existing.first['due_review_at'],
  if (!attempt.isCorrect) 'due_review_at': nowIso,
};
if (existing.isEmpty) {
  await txn.insert(DatabaseConstants.tableCurriculumMastery, values);
} else {
  await txn.update(DatabaseConstants.tableCurriculumMastery, values,
      where: 'item_id = ?', whereArgs: [targetId]);
}
```
- Verification status: read both branches in full; confirmed the production call chain `practice_session_screen → practice_repository.recordAttempt → LearningPipelineCoordinator.recordExerciseAttempt` (`practice_repository.dart:221`); confirmed `item_id TEXT NOT NULL UNIQUE` in `migration_v9.dart:140`; reproduced the reset semantics with a standalone SQLite harness (S3 in the harness: `(7, '2026-02-01', '2026-01-01')` → `(1, None, '2026-03-01')`). Existing test `test/features/learning_pipeline/learning_pipeline_coordinator_test.dart:409-461` asserts only `mastery_state`/SRS due, not `attempts_count`/`due_review_at`, so the regression is not caught.

## [T1-F04] Startup seed/content-pack freshness gates ignore version and checksum, so updated bundled data is never re-imported

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/core/startup/app_startup_provider.dart:207-241`; contrast with `lib/core/database/seed/seed_loader.dart:109-128` and `lib/features/content_packs/data/content_pack_manager.dart:186-211`
- Evidence: ```dart
  Future<bool> _checkSeedLoaded(Database db) async {
    final history = await db.query(
      DatabaseConstants.tableSeedHistory,
      where: 'bundle_name = ? AND status = ?',
      whereArgs: [canonicalSeedBundleName, 'completed'],
      limit: 1,
    );
    if (history.isEmpty) return false;

    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableVocabularies}',
    );
    final count = Sqflite.firstIntValue(countRes) ?? 0;
    return count >= minimumExpectedVocabCount;
  }
```
- Root cause: The startup fast-path treats "`seed_history` row says completed + ≥5,000 vocab rows" as authoritative and **never invokes `SeedLoader`**, so the checksum/version gate implemented inside `SeedLoader.seedBundle()` (`seed_loader.dart:109-128`: `existingEntry.status == 'completed' && existingEntry.checksum == checksum && existingEntry.version == bundle.version`) is unreachable. The identical pattern exists for content packs: `_checkPackNeedsImport()` (`app_startup_provider.dart:223-241`) only checks `content_packs.status IN ('installed','bundled')` and `lessons > 0`; `ContentPackManager`'s version/checksum logic (`content_pack_manager.dart:177-211`, `validateManifest` `:82-143`) is only reached if the startup gate decides an import is needed. `docs/bug-fixes/P0_01_STARTUP_SEED_LOADING.md:67,138` claims "gói đã cài đặt đúng phiên bản" is checked — it is not.
- Impact: When a future app update ships `hsk_seed_fixture_v2.json` (same asset path/bundle name, new content/checksum) or a new `hsk1_pack_v1.json`, existing users keep the stale data forever; only a fresh install gets the update. Content/curriculum corrections, new audio mappings and dictionary fixes silently do not reach the installed base.
- Fix: Compute the asset checksum at startup (or store the asset's expected checksum in a manifest) and invoke `SeedLoader`/`ContentPackManager` unconditionally; let their internal idempotency gates decide. Minimal for seed:
```dart
final raw = await assetBundle.loadString(canonicalSeedAssetPath);
final checksum = SeedLoader.computeChecksum(raw);
final seeded = await db.query(DatabaseConstants.tableSeedHistory,
    where: 'bundle_name = ? AND status = ?', whereArgs: [canonicalSeedBundleName, 'completed'],
    limit: 1);
final fresh = seeded.isNotEmpty &&
    seeded.first['checksum'] == checksum &&
    (seeded.first['version'] as int? ?? 0) == parsedBundle.version;
if (!fresh) { /* run SeedLoader.seedFromJsonString(raw) */ }
```
  For packs, compare `manifest.version`/`manifest.sha256` against `content_packs.version`/`checksum_sha256` instead of only counting rows.
- Verification status: read the startup sequence `:106-169`; confirmed that the only call to `SeedLoader` is inside `if (!isSeedReady)`, and the only call to `installOrUpdatePack` is inside `if (needsImport)`. Confirmed the seed asset's current `bundleName`/`version` match the startup constants, so the bug is latent for this exact build and triggers on the next data update.

## [T1-F05] Migration v10's content backfill swallows every error and can cascade-delete the knowledge links it just created

- Severity: Medium
- Confidence: CONFIRMED (SQLite cascade semantics reproduced independently; user-data dependence is data-dependent)
- Location: `lib/core/database/migrations/migration_v10.dart:116-327` (catch at `:324-326`), registry upsert at `:213-229`, lesson linking at `:232-246`; FK at `lib/core/database/migrations/migration_v10.dart:52-63`
- Evidence: ```dart
            // Register in knowledge_registry
            await db.insert(
              DatabaseConstants.tableKnowledgeRegistry,
              {
                'id': knowId,
                'entity_type': 'vocabulary',
                'canonical_id': simplified,
                'hsk_level': hskLevel,
                'title': simplified,
                'is_deprecated': 0,
                'replaced_by_id': null,
                'package_id': currId,
                'metadata_json': json.encode({'pinyin': pinyin, 'meaning_vi': meaningVi}),
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
```
  and the surrounding handler:
```dart
    } catch (e, stackTrace) {
      debugPrint('[MigrationV10] Content backfill non-fatal warning: $e\n$stackTrace');
    }
```
- Root cause: Two independent defects in one user-data migration. (1) `_backfillContentItems()` swallows *all* exceptions and returns; `MigrationEngine.executeMigrations()` then proceeds to v11..v16 and sqflite records `user_version=16`. A partially-normalised database is therefore indistinguishable from a correct one and is never retried. (2) `knowledge_registry` has `UNIQUE(entity_type, canonical_id)` (`migration_v10.dart:37-40`) and `lesson_knowledge_items.knowledge_item_id` references it with `ON DELETE CASCADE` (`:60-61`). `ConflictAlgorithm.replace` = `INSERT OR REPLACE`, which **deletes the conflicting parent row** → cascades to the link rows inserted earlier in the same loop for the same word (`lki_<lesson>_KNOW_VOCAB_<word>`). The code then re-inserts the registry row (new rowid) and only re-links the current content item's lessons, permanently losing the earlier links. A standalone SQLite harness reproduced: `1` child row → `0` after an `INSERT OR REPLACE` on the parent that conflicts on `(entity_type, canonical_id)`.
- Impact: Users upgrading from schema v9 with existing content packs get a silently half-migrated knowledge graph: words appearing in more than one content item lose `lesson_knowledge_items` links (breaking "knowledge items for lesson" enrichment and mastery-by-lesson), and any backfill error (type cast on legacy rows, missing column, FK failure) is never surfaced. `migration_v10.dart:158-160` also silently `continue`s on malformed JSON. Docs (`04-database-schema.md:23-25`) promise full rollback protection.
- Fix: (a) do not swallow; either let the exception abort the migration (sqflite rolls the whole open transaction back — verified in `sqflite_common` `database_mixin.dart:1140-1176`) or collect errors and re-run a repair pass; (b) use explicit `SELECT`-then-`UPDATE`/`INSERT OR IGNORE` instead of `REPLACE` for the registry:
```dart
final existing = await db.query(DatabaseConstants.tableKnowledgeRegistry,
    columns: ['id'], where: 'entity_type = ? AND canonical_id = ?',
    whereArgs: ['vocabulary', simplified], limit: 1);
final activeKnowId = existing.isNotEmpty ? existing.first['id'] as String : knowId;
if (existing.isNotEmpty) {
  await db.update(DatabaseConstants.tableKnowledgeRegistry,
      {'title': simplified, 'updated_at': nowUtc}, where: 'id = ?', whereArgs: [activeKnowId]);
} else {
  await db.insert(DatabaseConstants.tableKnowledgeRegistry, {...});
}
// link using activeKnowId, never the freshly derived knowId
```
- Verification status: read `MigrationV10` in full (328 lines); read `MigrationEngine` failure handling; confirmed sqflite wraps `onCreate`/`onUpgrade` in an exclusive transaction from the resolved package source (`sqflite_common-2.5.14/lib/src/database_mixin.dart:1139-1176`); reproduced the REPLACE→CASCADE child deletion independently (SQLite 3.53.1, S2). `docs/bug-fixes/P0_04_SQLITE_UPSERT_SAFETY.md:21` claims this exact registry pattern was converted to a safe upsert — the *migration* was not.

## [T1-F06] `SeedHistoryDao.recordFailed()` is UPDATE-only: a first-run validation failure is never recorded

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/core/database/seed/seed_history_dao.dart:62-79`; `lib/core/database/seed/seed_loader.dart:138-152`
- Evidence: ```dart
  Future<void> recordFailed({
    required String bundleName,
    required String errorMessage,
    int appliedItems = 0,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      DatabaseConstants.tableSeedHistory,
      {
        'status': 'failed',
        'applied_items': appliedItems,
        'applied_at': now,
        'error_message': errorMessage,
      },
      where: 'bundle_name = ?',
      whereArgs: [bundleName],
    );
  }
```
- Root cause: `recordFailed()` issues only an `UPDATE ... WHERE bundle_name = ?` and ignores the affected-row count. In the validation-failure path, `recordFailed` is called **before** `recordInProgress()`, so no `seed_history` row exists and the update silently affects 0 rows (`seed_loader.dart:143-146`). Only the later execution-failure path has a row to update.
- Impact: The documented retry/repair state (`seed_history.status='failed'`, `error_message`, `applied_items`) never exists for the most common failure mode (invalid shipped seed data or validator regression). Startup then fails with only an in-memory `StateError` (`app_startup_provider.dart:129-131`), and no diagnostics survive a restart. `P0_01`/`v2` docs describe `seed_history` as the idempotent/retry ledger, which is only half-true.
- Fix: upsert in `recordFailed`, mirroring `recordInProgress`, e.g.:
```dart
await _db.insert(
  DatabaseConstants.tableSeedHistory,
  {
    'bundle_name': bundleName, 'version': version ?? 0, 'checksum': checksum ?? '',
    'status': 'failed', 'total_items': totalItems ?? 0,
    'applied_items': appliedItems, 'applied_at': now, 'error_message': errorMessage,
  },
  conflictAlgorithm: ConflictAlgorithm.replace,
);
```
  (pass version/checksum/totalItems from `SeedLoader`), or call `recordInProgress` before validation.
- Verification status: read `SeedHistoryDao` in full and both seed-failure branches (`seed_loader.dart:138-152` validation, `:429-452` execution). `recordCompleted()` has the same shape but is always preceded by `recordInProgress()`, so it is safe today.

## [T1-F07] "Clear all user data" and JSON export/import miss user progress stored inside curriculum/content tables

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/settings/data/services/data_management_service.dart:191-228` (export map), `:362-393` (clear transaction); progress columns live in `lib/core/database/migrations/migration_v9.dart:63, 82-88`
- Evidence: ```dart
    // 2. Clear user-generated and progress tables in transaction
    await _db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableChatMessages);
      await txn.delete(DatabaseConstants.tableChatSessions);
      await txn.delete(DatabaseConstants.tablePracticeAttempts);
      await txn.delete(DatabaseConstants.tablePracticeSessions);
      await txn.delete(DatabaseConstants.tableReadingProgress);
      await txn.delete(DatabaseConstants.tableUserSavedWords);
      await txn.delete(DatabaseConstants.tableDictionaryHistory);
      await txn.delete(DatabaseConstants.tableSrsItems);
      await txn.delete(DatabaseConstants.tableLearnerEvidence);
      await txn.delete(DatabaseConstants.tableLearningActivities);
      await txn.delete(DatabaseConstants.tablePlacementTestResponses);
      await txn.delete(DatabaseConstants.tablePlacementTestSessions);
      await txn.delete(DatabaseConstants.tableGrammarProgress);
      await txn.delete(DatabaseConstants.tableLessonProgress);
      await txn.delete(DatabaseConstants.tableCurriculumMastery);
      await txn.delete(DatabaseConstants.tableHanziWritingProgress);
      await txn.delete(DatabaseConstants.tableSentencePracticeProgress);
      await txn.delete(DatabaseConstants.tablePinyinProgress);
      await txn.delete(DatabaseConstants.tableLearnerGoals);
      await txn.delete(DatabaseConstants.tableRoadmapSnapshots);
      await txn.delete(DatabaseConstants.tableGoalHistory);
      await txn.delete(DatabaseConstants.tableUserProfiles);
```
- Root cause: Lesson/unit completion is *also* stored in the content tables: `curriculum_lessons.status`, `completed_at`, `credited_reason`, `is_locked` (`migration_v9.dart:82-88`) and `curriculum_units.is_locked` (`:63`). `ContentPackManager` deliberately preserves these as learner state across upgrades (`content_pack_manager.dart:277-288, 312-352`), proving they are user progress — but `clearAllUserData()` never resets them, and `exportUserDataJson()` never exports them (nor `lesson_progress`, `learner_evidence`, `learning_activities`, `hanzi/sentence/pinyin` progress — `:209-225`). `docs/bug-fixes/F04_F17_UNIFIED_ID_AND_SRS.md` explicitly claims progress is decoupled and canonical.
- Impact: (a) After the in-app destructive reset, the app still shows completed/unlocked lessons and credited placement lessons; the fresh default profile restarts at HSK 1 while the curriculum tree remains fully progressed. (b) Export→wipe/reinstall→import does not restore lesson completion, SRS review history, practice history or streaks — the advertised "personal learner data" backup is incomplete; restoring it can even contradict remaining curriculum flags.
- Fix: include the curriculum progress columns in the reset (inside the same transaction) and in the export/import:
```dart
await txn.update(DatabaseConstants.tableCurriculumLessons, {
  'status': 'not_started', 'is_locked': 1, 'completed_at': null, 'credited_reason': null,
});
await txn.update(DatabaseConstants.tableCurriculumUnits, {'is_locked': 1});
// and add lesson_progress / learner_evidence / learning_activities to exportUserDataJson()
```
  or better: move those columns into dedicated learner-progress tables (they already exist: `lesson_progress`, `curriculum_mastery`) and stop writing them into content rows.
- Verification status: read the full clear/export methods; read v9 table definitions; confirmed write/preserve sites in `content_pack_manager.dart:277-352` and `placement_unlock_handler.dart:39-45`.

## [T1-F08] SRS review commits its state transactionally, then logs the streak activity outside the transaction and swallows failures

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/vocabulary_srs/data/srs_repository.dart:329-372` (activity insert at `:355-369`), review transaction at `:141-188`
- Evidence: ```dart
    try {
      final now = reviewTime ?? AppClock.now();
      final nowUtc = now.toUtc();
      final offset = timeZoneOffset ?? AppClock.currentOffset;
      final dateStr = AppClock.toLocalDateString(now, timeZoneOffset: offset);
      await _db.insert(
        DatabaseConstants.tableLearningActivities,
        {
          'id': 'ACT_${nowUtc.microsecondsSinceEpoch}_${item.id}',
          'activity_type': 'srs_review',
          'duration_seconds': (durationMs / 1000).ceil().clamp(1, 300),
          'items_count': 1,
          'activity_date': dateStr,
          'created_at': nowUtc.toIso8601String(),
          'timezone_offset_minutes': offset.inMinutes,
        },
      );
    } catch (_) {
      // Non-critical if table has constraint, review state is already committed atomically
    }
```
- Root cause: `processReview()` commits SRS state + `learner_evidence` + `curriculum_mastery` inside one transaction (`:141-188`). `recordReviewAndProgress()` then performs the `learning_activities` insert in a **separate, non-transactional** call wrapped in a bare `catch (_) {}`. If that insert fails (SQLITE_BUSY, disk full, schema drift, id collision from `microsecondsSinceEpoch`), the review is recorded but the streak/statistics event is silently dropped — permanently, because there is no queue/retry.
- Impact: Wins on `srs_items`/`learner_evidence` diverge from `learning_activities`; the home dashboard streak and today/week study stats under-count reviews (`home_repository.getSanitizedStudySessionsAndStats` uses `learning_activities` as canonical source and only backfills orphan `learner_evidence` — see F10). Users can lose streak days despite reviewing. The same "review committed, activity lost" hazard applies to every `try { _db.insert(activities) } catch {}` in the codebase.
- Fix: pass the existing transaction into the activity write. `processReview()` already owns a transaction — either move `learning_activities` insertion into it, or have `processReview` return and let the caller open one transaction for both:
```dart
await _db.transaction((txn) async {
  await _writeSrsStateAndEvidence(txn, ...);       // existing logic
  await txn.insert(DatabaseConstants.tableLearningActivities, {...}); // same txn
});
```
  If activity logging must stay non-fatal, at least `debugPrint` the error and enqueue a retry instead of swallowing it.
- Verification status: read both methods in full; traced the production caller `srs_providers.dart:87` → `recordReviewAndProgress`; confirmed the transaction boundary at `:141` and the separate insert at `:355`.

## [T1-F09] `getDueFlashcards()` performs per-word SELECT+INSERT (write-on-read) in a loop

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/vocabulary_srs/data/srs_repository.dart:282-321`; `getOrCreateCardState` at `:52-85`
- Evidence: ```dart
      final newRows = await _db.rawQuery(
        newVocabsQuery,
        hskLevel != null ? [hskLevel] : [],
      );

      for (final row in newRows) {
        final vocabId = (row['vocab_id'] ?? row['id']) as String;
        final srsState = await getOrCreateCardState(contentId: vocabId);
        final intervals = _engine.previewIntervals(srsState);
        results.add(SrsFlashcardItem.fromDatabaseRow(
          row: {...row, 'id': vocabId},
          srsState: srsState,
          estimatedIntervalDays: intervals,
        ));
      }
```
- Root cause: For each "unlearned" word needed to fill the deck, `getOrCreateCardState()` issues (a) a `content_id_mappings` walk through `KnowledgeIdentityRegistry.toCanonicalVocabularyId` (up to 6 queries: direct PK, mapping hop chain, simplified match, registry-prefix match, …), (b) a `SELECT` on `srs_items`, and (c) an `INSERT` of the new card when absent. That is ~3 queries + 1 write per word, outside any transaction and outside any batch. A 30-card deck can trigger 90+ round trips and 30 individual autocommits; the whole call is invoked from the flashcard screen provider path.
- Impact: Slow flashcard deck load on low-end Android (each write forces a WAL frame); each read mutates the database (viewing the deck creates SRS rows), so the "due count" changes as a side effect of rendering. Any mid-loop failure leaves a partially enrolled deck. This contradicts the F-13 optimization report (`docs/bug-fixes/F13_N_PLUS_ONE_QUERY_OPTIMIZATION.md`).
- Fix: resolve cards in one pass, then batch-insert missing ones:
```dart
final ids = newRows.map((r) => r['vocab_id'] as String).toList();
final existing = await _db.query(DatabaseConstants.tableSrsItems,
    columns: ['content_id', 'id'],
    where: 'content_type = ? AND content_id IN (${List.filled(ids.length, '?').join(',')})',
    whereArgs: ['vocabulary', ...ids]);
final byContent = {for (final r in existing) r['content_id'] as String: r['id'] as String};
final toInsert = <Map<String, dynamic>>[];
for (final row in newRows) {
  final vid = row['vocab_id'] as String;
  if (!byContent.containsKey(vid)) toInsert.add(SrsCardState.newCard(
      id: 'SRS_VOCABULARY_$vid', contentId: vid).toMap());
}
if (toInsert.isNotEmpty) {
  final batch = _db.batch();
  for (final m in toInsert) { batch.insert(DatabaseConstants.tableSrsItems, m,
      conflictAlgorithm: ConflictAlgorithm.ignore); }
  await batch.commit(noResult: true);
}
```
  and build the in-memory states from the fetched rows instead of re-querying.
- Verification status: read `getDueFlashcards` in full (around the due-card query at `:250-280` and the fill loop at `:282-322`); read `getOrCreateCardState` (`:52-85`) and the registry resolution chain (`knowledge_identity_registry.dart:134-223`); confirmed no transaction/batch wraps the loop.

## [T1-F10] Home dashboard loads the entire append-only evidence table on every render and dedupes with an O(n²) scan

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/home/data/home_repository.dart:191-243` (`learning_activities` full scan), `:249-307` (`learner_evidence` full scan), `:273-278` (nested per-evidence scan); callers `:384-396` (dashboard), `:432-450` (streak)
- Evidence: ```dart
      final evidenceRows = await _db.rawQuery(
        '''
        SELECT id, content_id, content_type, source, score, duration_ms, metadata_json, created_at 
        FROM ${DatabaseConstants.tableLearnerEvidence}
        WHERE source NOT IN ('sample_data', 'seed')
        ORDER BY created_at ASC
        ''',
      );
```
  and the dedupe loop it feeds:
```dart
        final isEnclosed = validActivities.any((act) {
          if (act.localDate != localDate) return false;
          final start = act.timestampUtc.subtract(Duration(seconds: act.durationSeconds + 30));
          final end = act.timestampUtc.add(const Duration(seconds: 30));
          return parsedUtc.isAfter(start) && parsedUtc.isBefore(end);
        });
```
- Root cause: No `LIMIT`/date window is applied and the whole result is materialised into Dart lists before filtering. `learner_evidence` is append-only by design (`learner_evidence_dao.dart:10-18`) and grows for the life of the install (one row per SRS review, practice question, lesson item, CAT response). The "was this evidence already counted?" check is a nested scan (`for evidence × for activity`), i.e. quadratic in the number of learning events, executed on the home screen and on every streak widget refresh.
- Impact: Home screen latency and memory grow monotonically with learner history; after months of use this can load tens of thousands of rows into memory on the UI isolate, causing jank/ANR-class startup of the dashboard. The dedupe also uses a heuristic time window (duration+30s), so two legitimate activities within that window are silently merged while long sessions are mis-attributed.
- Fix: push the computation into SQL with a bounded window and aggregates, e.g.:
```sql
SELECT activity_date, SUM(duration_seconds) AS duration, SUM(items_count) AS items
FROM learning_activities
WHERE activity_date >= ?  -- e.g. 400 days ago
GROUP BY activity_date;
```
  plus a separate query for the streak (distinct dates only), and drop the row-by-row "enclosed evidence" merge (or mark evidence rows as `counted_in_activity_id` at write time in the same transaction as the activity insert — see F08).
- Verification status: read `getSanitizedStudySessionsAndStats` and `getDashboardData` in full; confirmed both raw queries have no `LIMIT`/date predicate and that `learning_activities` has an `activity_date` index while the evidence query orders by `created_at` (index exists, but the select is still unbounded).

## [T1-F11] `migrateSrsItemsToCanonical()` would fail with an FK violation on its promotion path — and it is never called in production, so the F-04 ID merge never runs

- Severity: Medium
- Confidence: LIKELY (dead-code + verified SQLite failure mode; no production caller)
- Location: `lib/features/vocabulary_srs/data/srs_repository.dart:443-561` (promotion path `:475-495`), FK declaration `lib/core/database/migrations/migration_v1.dart:112-125`; only caller is `test/core/knowledge/knowledge_identity_and_srs_test.dart:277`
- Evidence: ```dart
        if (existingCanonicalRows.isEmpty) {
          // No duplicate card exists: promote current card to canonical ID
          final newSrsId = 'SRS_VOCABULARY_$canonicalId';
          await txn.update(
            DatabaseConstants.tableSrsItems,
            {
              'id': newSrsId,
              'content_id': canonicalId,
              'updated_at': nowUtc,
            },
            where: 'id = ?',
            whereArgs: [oldSrsId],
          );

          // Update learner_evidence references
          await txn.update(
            DatabaseConstants.tableLearnerEvidence,
            {
              'srs_item_id': newSrsId,
              'content_id': canonicalId,
            },
            where: 'srs_item_id = ? OR content_id = ?',
            whereArgs: [oldSrsId, oldContentId],
          );
```
- Root cause: `learner_evidence.srs_item_id` is declared `FOREIGN KEY (srs_item_id) REFERENCES srs_items (id) ON DELETE SET NULL` with **no `ON UPDATE` clause** (`migration_v1.dart:123`), i.e. default `NO ACTION`. With `PRAGMA foreign_keys = ON` (set in `app_database.dart:68`), updating the parent PK `srs_items.id` while child evidence rows still reference the old value fails immediately — the code updates the parent first and the child second. Independently reproduced in SQLite 3.53.1: `UPDATE srs_items SET id=... WHERE id=<old>` → `FOREIGN KEY constraint failed`. The test that calls this function opens its DB **without** `PRAGMA foreign_keys=ON` (`knowledge_identity_and_srs_test.dart:32`), which is why it passes. Separately, `grep` finds no production caller at all — the F-04 report presents `migrateSrsItemsToCanonical()` as the delivered fix (`docs/bug-fixes/F04_F17_UNIFIED_ID_AND_SRS.md:65`), so legacy split-brain SRS cards are never merged.
- Impact: If ever wired (e.g. by a future startup task), the first card with existing evidence aborts the entire migration transaction. Today the practical impact is the inverse: the promised identity repair is absent, so any SRS cards created under a non-canonical `content_id` (possible through `KnowledgeIdentityRegistry.toCanonicalVocabularyId()`'s fallback that returns the raw alias — `knowledge_identity_registry.dart:221-222`) stay invisible to `getDueFlashcards()` (INNER JOIN on `v.id`, `srs_repository.dart:254-255`) while still being counted by `getDueCardsCount()` (join `OR s.content_id = v.simplified`, `:399-411`).
- Fix: re-link children first, then move the parent, inside the same transaction:
```dart
// 1) detach evidence from the old card
await txn.update(DatabaseConstants.tableLearnerEvidence,
    {'srs_item_id': null}, where: 'srs_item_id = ?', whereArgs: [oldSrsId]);
// 2) insert the new canonical card (or update in place if it already exists)
// 3) re-point evidence to the new id
await txn.update(DatabaseConstants.tableLearnerEvidence,
    {'srs_item_id': newSrsId, 'content_id': canonicalId},
    where: "srs_item_id IS NULL AND (content_id = ? OR content_id = ?)",
    whereArgs: [oldContentId, canonicalId]);
```
  then wire it into `AppStartupNotifier.initialize()` after migrations (guarded by a settings flag) and enable `PRAGMA foreign_keys=ON` in its test.
- Verification status: read the function in full; verified the FK declaration in `migration_v1.dart:123`; confirmed FK enforcement is on in production (`app_database.dart:68`, test `app_database_test.dart:38-39`); reproduced the parent-PK update failure with a standalone SQLite harness; grep over `lib/` showed only the test caller.

## [T1-F12] `dictionary_entries` (the advertised 122k offline dictionary) is never populated; the FK on `user_saved_words` would reject its ids

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/core/database/migrations/migration_v12.dart:84-113` (table creation only); `lib/core/database/dao/vocabulary_dao.dart:331-357`; `lib/features/dictionary/data/dictionary_repository.dart:82-109, 147-164`; FK `lib/core/database/migrations/migration_v4.dart:33-44`
- Evidence: ```dart
      final dictRows = await _vocabDao.searchDictionaryEntries(trimmed, limit: limit - entries.length);
      for (final d in dictRows) {
        final dId = 'dict_${d['id'] ?? d['simplified']}';
        if (entries.any((e) => e.simplified == d['simplified'])) continue;

        entries.add(DictionaryEntry(
          id: dId,
          simplified: d['simplified'] as String,
```
  and the FK that would then reject that id:
```dart
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUserSavedWords} (
        id TEXT PRIMARY KEY,
        vocabulary_id TEXT NOT NULL UNIQUE,
        simplified TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        custom_note TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vocabulary_id) REFERENCES ${DatabaseConstants.tableVocabularies} (id) ON DELETE CASCADE
      );
```
- Root cause: `dictionary_entries` is created by migration v12 only. The sole writer in the repository is `tool/import_vocabulary.dart`, which targets a developer desktop DB (`hi_chinese_dev.db`); nothing in `lib/` or `assets/` ever inserts into it, and no bundled `.db` asset exists (asset inventory: only JSON + audio). So `searchDictionaryEntries()` always queries an empty table and the "122k offline dictionary fallback" never returns a row. If it ever were populated, `DefaultDictionaryRepository.toggleSaveWord()` (`:147-164`) would pass `vocabularyId = 'dict_...'` to `UserSavedWordsDao.saveWord()`, which inserts into `user_saved_words` whose FK requires the id to exist in `vocabularies` → `FOREIGN KEY constraint failed` (reproduced independently). The dictionary detail sheet calls `toggleSaveWord` without any error handling (`dictionary_detail_sheet.dart:91-104`).
- Impact: Documented/announced offline lookup beyond the 5,000 HSK words does not exist (dead schema + dead UI path). The latent FK bug means enabling the feature as designed would break "save word" for every non-HSK word. `docs/data-integration/OFFLINE_DATA_ARCHITECTURE.md` and `vocabulary_dao.dart:331` comments ("122k words") are aspirational.
- Fix: either ship the dictionary DB and copy it into place on first launch (then insert rows in a transaction before enabling the fallback), or remove the dead table/fallback/claims. For save support, upsert the dictionary entry into `vocabularies` first (same transaction) and use that PK as `vocabulary_id`, or drop the FK and add a `source` discriminator.
- Verification status: grep over `lib/` for `tableDictionaryEntries` shows only migration + read queries; grep over whole repo for `dictionary_entries` shows only `tool/import_vocabulary.dart` writing; asset scan found no bundled sqlite database; reproduced the FK rejection of `dict_*` ids with a standalone SQLite harness (S7).

## [T1-F13] F-18's historical timezone repair is never executed: migration v16 adds the column but `TimezoneDataMigrator` is test-only

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/core/database/migrations/migration_v16.dart:15-27`; `lib/core/database/migrations/timezone_data_migrator.dart:22-129`; claim `docs/bug-fixes/F18_TIMEZONE_AND_LEARNING_STREAK.md:92-104`
- Evidence: ```dart
  Future<void> up(DatabaseExecutor db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableLearningActivities});');
    final hasCol = tableInfo.any((col) => col['name'] == 'timezone_offset_minutes');
    if (!hasCol) {
      await db.execute(
        'ALTER TABLE ${DatabaseConstants.tableLearningActivities} ADD COLUMN timezone_offset_minutes INTEGER;',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_activities_date_created ON ${DatabaseConstants.tableLearningActivities} (activity_date, created_at);',
    );
  }
```
- Root cause: `migration_v16` only alters schema. The `TimezoneDataMigrator.backfillWithVerifiedTimezone()` that F-18 documents (audit + transaction + report) has **no production caller** — `grep -r "TimezoneDataMigrator" lib/` returns only its own file, and the only reference anywhere is `test/features/home/local_timezone_and_streak_test.dart:6,335`. There is no startup hook, no migration invocation, and no admin UI.
- Impact: Material pre-v16 activity rows that were recorded with the old (UTC-day) bug are never audited or corrected; historical streak days remain wrong for affected users and the `timezone_offset_minutes` column stays NULL for them, so any future repair tool also cannot distinguish them. The F-18 completion claim ("Đã khắc phục triệt để", test matrix row 11) is not reflected in the shipping code path. Also note the migrator itself does its UPDATEs one row at a time outside a transaction (`timezone_data_migrator.dart:96-127`) contrary to the doc's "Thực hiện trong Transaction an toàn".
- Fix: run the audit/backfill once after migration in `AppStartupNotifier.initialize()` (guarded by an `app_settings` flag), inside `AppDatabase.runInTransaction`, or move the logic into a new `MigrationV17`:
```dart
// after db.getVersion() in startup
await db.transaction((txn) async {
  final migrator = TimezoneDataMigrator();
  final audit = await migrator.auditHistoricalActivities(txn,
      assumedOffset: AppClock.currentOffset);
  if (audit.potentiallyShiftedRecords > 0) {
    await migrator.backfillWithVerifiedTimezone(txn,
        verifiedOffset: AppClock.currentOffset);
  }
});
```
  then update the F-18 doc to match reality.
- Verification status: read `migration_v16` and `timezone_data_migrator` in full; grep for class/import names across `lib/` and `test/` (only the test imports it); read the F-18 doc section claiming a transactional migration.

## [T1-F14] Backup fallback performs a raw file copy after a swallowed checkpoint failure and never validates the result

- Severity: Medium
- Confidence: LIKELY (depends on platform SQLite version / checkpoint busy state)
- Location: `lib/core/database/database_backup_helper.dart:39-91` (checkpoint `:53-59`, fallback copy `:76-87`); used by `app_database.backup()` and `DataManagementService.createBackup()`
- Evidence: ```dart
    // 3. Attempt atomic VACUUM INTO
    bool vacuumSucceeded = false;
    try {
      // Escape single quotes for SQL string literal
      final escapedPath = destinationBackupPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$escapedPath';");
      vacuumSucceeded = true;
      debugPrint('[DatabaseBackup] Atomic VACUUM INTO succeeded.');
    } catch (e) {
      debugPrint('[DatabaseBackup] VACUUM INTO not supported or failed ($e), falling back to file copy.');
    }

    // Fallback to raw copy if VACUUM INTO wasn't supported
    if (!vacuumSucceeded) {
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        throw StateError('Source database file does not exist at: $dbPath');
      }
      await sourceFile.copy(destinationBackupPath);
    }
```
- Root cause: `VACUUM INTO` requires SQLite ≥ 3.27; on older Android system SQLite (API < 29 uses older SQLite; e.g. Android 8 ships 3.18/3.19) it fails and the code falls back to copying only the main DB file. The preceding `PRAGMA wal_checkpoint(TRUNCATE)` is best-effort — its exception is swallowed at `:54-59` — so if the checkpoint could not complete (busy reader, `SQLITE_BUSY`) the main file lacks committed WAL pages and the copy is silently **incomplete**. The resulting backup is never opened or `integrity_check`-ed before `createBackup` returns success (`:89`).
- Impact: Users on older Android devices can get backups that are missing recent learning data (or internally inconsistent); they only discover this at restore time. Because the F-02 restore path does not validate the backup either, this can compound into silent data loss.
- Fix: verify the produced backup before returning, and treat a failed checkpoint as fatal for the file-copy fallback:
```dart
final cp = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
final busy = (cp.first['busy'] as num?)?.toInt() ?? 1;
if (!vacuumSucceeded && busy != 0) {
  throw StateError('Cannot create consistent backup: WAL checkpoint busy');
}
// then open the backup and run integrity_check + schema version check
final check = await databaseFactory.openDatabase(destinationBackupPath,
    options: OpenDatabaseOptions(readOnly: true));
try {
  final issues = await checkIntegrity(check);
  if (issues.isNotEmpty) throw DatabaseIntegrityException('Backup failed verification', issues: issues);
  if (await check.getVersion() != DatabaseConstants.currentDatabaseVersion) {
    throw StateError('Backup schema mismatch');
  }
} finally { await check.close(); }
```
- Verification status: read the helper in full; read the vendor behavior (VACUUM INTO added in SQLite 3.27) and confirmed the app targets Android with system SQLite via sqflite; traced both backup entry points (`app_database.dart:116-126`, `data_management_service.dart:79-95`). Not executed on an old-Android device — hence LIKELY.

## [T1-F15] `MigrationEngine` has no completeness guard: a bumped `currentDatabaseVersion` without a matching registered migration silently "succeeds"

- Severity: Low
- Confidence: CONFIRMED
- Location: `lib/core/database/migrations/migration_engine.dart:61-91`; constants `lib/core/database/database_constants.dart:5`, `lib/core/constants/app_constants.dart:8`, `lib/core/database/app_database.dart:45`
- Evidence: ```dart
  Future<void> executeMigrations(Database db, int oldVersion, int newVersion) async {
    debugPrint('[MigrationEngine] Upgrading database from v$oldVersion to v$newVersion...');

    final pendingMigrations = _migrations
        .where((m) => m.version > oldVersion && m.version <= newVersion)
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    if (pendingMigrations.isEmpty && oldVersion != 0) {
      debugPrint('[MigrationEngine] No pending migrations to execute.');
      return;
    }
```
- Root cause: The list of migrations is filtered by `newVersion`, but nothing asserts that the highest registered migration equals `newVersion`, and the "empty pending" early-return plus `PRAGMA user_version = $newVersion` (line 79) make a *missing* migration look like a successful upgrade. `DatabaseConstants.currentDatabaseVersion` (16) and `AppConstants.databaseVersion` (16) are currently consistent and all v1..v16 are registered (`migration_engine.dart:36-54`), so this is a future-bug guard, not a live defect.
- Impact: If a future release bumps the constant (e.g. to 17) without adding `MigrationV17`, fresh installs and existing installs both end at `user_version=17` with a v16 schema — the failure surfaces much later as `no such column` runtime crashes. A second constant (`AppConstants.databaseVersion`) duplicating the value can drift and mislead tooling.
- Fix: assert at construction/execution time and delete the duplicate constant:
```dart
int get maxSupportedVersion => _migrations.isEmpty ? 0 : _migrations.last.version;
...
if (newVersion > maxSupportedVersion) {
  throw MigrationException(
    'No migration registered up to v$newVersion (max ${maxSupportedVersion})',
    fromVersion: oldVersion, toVersion: newVersion);
}
```
  and make `AppConstants.databaseVersion` a getter forwarding to `DatabaseConstants.currentDatabaseVersion` (or delete it).
- Verification status: read `MigrationEngine`, `AppDatabase.open()` and both constants; verified the registered list covers 1..16 exactly today, so no live drift.

## [T1-F16] Docs/README schema-version claims are stale (README v9, schema doc v11, unified-schema doc v15, actual v16)

- Severity: Low
- Confidence: CONFIRMED
- Location: `README.md:5` and `:47`; `docs/system-documentation/04-database-schema.md:1` and `:9`; `docs/data-integration/UNIFIED_SCHEMA.md:2`; `docs/bug-fixes/P0_01_STARTUP_SEED_LOADING.md:52`; code `lib/core/database/database_constants.dart:5`, `lib/core/constants/app_constants.dart:8`
- Evidence: ```dart
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'hi_chinese.db';
  static const int currentDatabaseVersion = 16;
```
- Root cause: The version constant was bumped through v16 but the documentation set was never updated. Claims: README "SQLite Schema v9" (twice), `04-database-schema.md` title "SCHEMA V11" and "`DatabaseConstants.currentDatabaseVersion = 11`" with a v1→v11 migration history, `UNIFIED_SCHEMA.md` "Phiên bản 15", `P0_01` "hiện tại v15". The prompt's suspicion that `AppConstants.databaseVersion` might be `1` is **false** — it is 16 and matches `DatabaseConstants.currentDatabaseVersion`.
- Impact: Auditors/maintainers reading docs will believe migrations stop at v11 and cannot reason about v12–v16 tables/columns; any doc-driven planning (backup, migration) is based on a wrong schema. No runtime impact.
- Fix: Update the four docs in one pass (v16, history v1→v16, list v12 audio/Pinyin/dictionary, v13 grammar, v14 hanzi, v15 sentences, v16 timezone) and add a CI check comparing `DatabaseConstants.currentDatabaseVersion` and `migration_engine`'s registered list to the docs.
- Verification status: read the constants and the exact doc lines listed above; verified all 16 migrations are registered and run on both fresh-create and upgrade paths.

## [T1-F17] Remaining `ConflictAlgorithm.replace` on parent rows loses row identity and can null evidence links (roadmap, JSON import, chat sessions)

- Severity: Low
- Confidence: CONFIRMED (SQLite semantics reproduced independently)
- Location: `lib/features/roadmap/data/roadmap_repository.dart:154-173` (`lesson_progress`), `lib/features/settings/data/services/data_management_service.dart:303-312` (`srs_items` import), `lib/core/database/dao/chat_dao.dart:9-16` (`chat_sessions`), FK `lib/core/database/migrations/migration_v1.dart:123`; P0-04 claim `docs/bug-fixes/P0_04_SQLITE_UPSERT_SAFETY.md:18-26`
- Evidence: ```dart
    await _db.transaction((txn) async {
      // 1. Update lesson progress
      await txn.insert(
        DatabaseConstants.tableLessonProgress,
        {
          'id': 'prog_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
          'lesson_id': lessonId,
          'unit_id': lesson.unitId,
          'hsk_level': lesson.level,
          'status': LessonStatus.completed.name,
          'completion_score': clampedScore,
          'evidence_count': 1,
          'started_at': nowUtc,
          'completed_at': nowUtc,
          'last_studied_at': nowUtc,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
```
- Root cause: P0-04's report claims REPLACE was eliminated from all DAOs, but three production writers still use it on tables with secondary UNIQUE constraints and/or children: `lesson_progress.lesson_id UNIQUE` (`migration_v5.dart:37-40`) with a **new PK on every call** → the previous row is deleted, so `started_at`/original row id are lost on each completion/skip; JSON import REPLACEs `srs_items` (`data_management_service.dart:303-312`), whose PK is referenced by `learner_evidence.srs_item_id ON DELETE SET NULL` → imported evidence links are nulled (harness S6); `ChatDao.insertSession` REPLACEs `chat_sessions` whose `chat_messages` cascade — a re-insert of an existing session id would delete the transcript (harness S5). Chat currently only creates new ids, so that one is latent.
- Impact: Lesson progress history (when the lesson was started, original row identity) is destroyed on every re-completion; JSON import of SRS state breaks the audit link from evidence to cards; any future "resume chat session" path that calls `insertSession` would wipe the conversation.
- Fix: replace with the safe `SELECT`-then-`UPDATE/INSERT` pattern used elsewhere (e.g. `MasteryDao._safeUpsert`), preserving `created_at`/`started_at` and keeping the existing `id`; for import, merge into the existing card by `(content_id, content_type)` instead of REPLace-by-PK:
```dart
final existing = await txn.query(DatabaseConstants.tableLessonProgress,
    columns: ['id', 'started_at', 'created_at'],
    where: 'lesson_id = ?', whereArgs: [lessonId], limit: 1);
final row = {...fields, 'id': existing.isNotEmpty ? existing.first['id'] : newId,
             'started_at': existing.isNotEmpty ? existing.first['started_at'] : nowUtc,
             'created_at': existing.isNotEmpty ? existing.first['created_at'] : nowUtc};
if (existing.isEmpty) { await txn.insert(...); } else { await txn.update(..., where: 'lesson_id = ?'); }
```
- Verification status: read all three writers; read FK declarations in `migration_v1.dart` and `migration_v5.dart`; confirmed P0-04's claim of full conversion is inaccurate via grep for `ConflictAlgorithm.replace` in `lib/` (still present in 15+ places); reproduced row-identity loss and evidence-link nulling in the standalone SQLite harness (S4, S6, S5).

## [T1-F18] Test suite masks the above: repositories are tested with foreign keys disabled and no test asserts fresh-vs-upgraded schema equivalence

- Severity: Low
- Confidence: CONFIRMED
- Location: `test/core/database/upsert_safety_test.dart:31-57`; `test/core/knowledge/knowledge_identity_and_srs_test.dart:32-38`; e.g. `test/features/learning_pipeline/learning_pipeline_coordinator_test.dart:200`, `test/features/vocabulary_srs/srs_integration_test.dart:21`, `test/features/grammar/grammar_repository_test.dart:22`, `test/features/roadmap/roadmap_repository_test.dart:21`
- Evidence: ```dart
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (d, v) async {
        await const MigrationV1().up(d);
        await const MigrationV5().up(d);
        await const MigrationV9().up(d);
        await const MigrationV10().up(d);
        await const MigrationV12().up(d);
      },
    );
```
  and an FK-critical test that does not enable FK at all:
```dart
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('knowledge_identity_test_');
    final dbPath = '${tempDir.path}/test_knowledge.db';
    db = await databaseFactory.openDatabase(dbPath);
```
- Root cause: (1) `upsert_safety_test` hand-builds a schema from only v1/v5/v9/v10/v12 and stamps `version: 1`, so it never exercises the registered migration chain nor v13–v16; a DAO using a v13+ column can be "green" while production fresh-install would be different. (2) `knowledge_identity_and_srs_test` (which calls `migrateSrsItemsToCanonical`) opens the DB without `PRAGMA foreign_keys=ON` — exactly the configuration that hides the FK violation in F11. (3) Many feature/repository tests open DBs with `databaseFactory.openDatabase(dbPath)` and no `onConfigure`, so FK enforcement is off for all their assertions. (4) There is no test that compares `PRAGMA table_info` / `sqlite_master` between a fresh `onCreate` DB and an upgraded DB (the prime drift risk the audit was asked to check actually converges — see Claims checked — but nothing prevents regressions).
- Impact: This is why the REPLACE/FK defects above survive a green suite; future schema drift or FK violations will also be invisible in CI. It does not change production behavior directly.
- Fix: add `PRAGMA foreign_keys = ON` to a shared test DB helper and migrate all tests onto it; replace the hand-built schema in `upsert_safety_test` with `AppDatabase.open()` (full chain); add a schema-equivalence test:
```dart
final fresh = await AppDatabase.instance.open(customPath: freshPath, customFactory: ff);
final upgraded = await databaseFactoryFfi.openDatabase(upgradePath,
    options: OpenDatabaseOptions(version: 1, onCreate: (d, _) => MigrationV1().up(d)));
await upgraded.close();
final up = await databaseFactoryFfi.openDatabase(upgradePath,
    options: OpenDatabaseOptions(version: DatabaseConstants.currentDatabaseVersion,
      onUpgrade: (d, o, n) => MigrationEngine().executeMigrations(d, o, n),
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON')));
expect(await schemaFingerprint(fresh), equals(await schemaFingerprint(up)));
```
- Verification status: read the three named test files; grep of tests shows many `openDatabase` calls without FK configuration; no schema-fingerprint comparison exists anywhere in `test/`.

---

## Claims checked from docs

| # | Claim (source) | Verdict | Evidence |
|---|---|---|---|
| 1 | README: "SQLite Schema v9" (`README.md:5,47`) | **FALSE / drift** | Actual `DatabaseConstants.currentDatabaseVersion = 16` (`database_constants.dart:5`), `AppConstants.databaseVersion = 16` (`app_constants.dart:8`). See F16. |
| 2 | `04-database-schema.md`: "currentDatabaseVersion = 11", migration history ends at v11 | **FALSE / drift** | v12–v16 files exist, are imported and registered (`migration_engine.dart:9-19, 36-54`). See F16. |
| 3 | Suspected CRITICAL: fresh `onCreate` schema diverges from upgraded schema (missing column on fresh install) | **NOT PRESENT — verified convergent** | `app_database.dart:84-87` (`onCreate` → `executeMigrations(db, 0, ver)`) and `:88-90` (`onUpgrade` → same engine/list). Sqflite wraps both callbacks in one exclusive transaction (`sqflite_common 2.5.14`, `lib/src/database_mixin.dart:1129-1181`). All column-adding migrations are reentrant (`PRAGMA table_info` check in v6:35-44, v10:101-110, v13:38-47, v16:16-22; `IF NOT EXISTS` elsewhere). No table/column referenced by any DAO is absent from the migration chain. |
| 4 | `04-database-schema.md:23-25`: migrations are wrapped in a DB transaction with rollback | **TRUE (by sqflite), with caveat** | Verified in resolved sqflite source. Caveat: `MigrationV10._backfillContentItems` swallows its own errors so a *data* backfill failure does not roll back or surface (F05). |
| 5 | `P0_04_SQLITE_UPSERT_SAFETY.md:16-26`: all `ConflictAlgorithm.replace` usages replaced with safe upsert | **PARTIALLY FALSE** | Still `replace` on parent tables in `learning_pipeline_coordinator.dart:583,653`; `data_management_service.dart:309`; `chat_dao.dart:9-16`; `roadmap_repository.dart:172`; `pinyin_repository.dart:110,177`; `grammar_repository.dart:402,461,482`; `hanzi_dao.dart:104,115,194`; `sentence_dao.dart:230,248,293`. Concrete harm shown in F03/F17; verify each site before trusting the report. |
| 6 | `F04_F17_UNIFIED_ID_AND_SRS.md:23-29,65`: `migrateSrsItemsToCanonical()` standardises SRS IDs and is the delivered fix | **FALSE in production** | No caller in `lib/` (grep); only `test/core/knowledge/knowledge_identity_and_srs_test.dart:277`. Its promotion path would itself throw an FK violation with FK enforcement on (F11). |
| 7 | `F18...md:92-104`: historical timezone dates repaired via transactional `TimezoneDataMigrator` | **FALSE in production** | Migration v16 only adds a column and index; `TimezoneDataMigrator` has no production caller (F13). |
| 8 | `P0_01_STARTUP_SEED_LOADING.md:67,138`: idempotent fast-skip checks the package *version* | **FALSE** | Startup checks only `status` + row counts (`app_startup_provider.dart:207-241`); version/checksum gates inside `SeedLoader`/`ContentPackManager` are bypassed (F04). |
| 9 | `app_database.dart:36-41,66-83`: `PRAGMA foreign_keys = ON` set at open | **TRUE** | `onConfigure` runs before the version transaction (`app_database.dart:66-68`, sqflite `database_mixin.dart:1129-1140`); asserted by `app_database_test.dart:38-39`. Consequence: all FK-relevant defects above are live. |
| 10 | `04-database-schema.md:15-19`: WAL + `synchronous=NORMAL` + cache temp store configured | **TRUE** | `app_database.dart:66-83`. |
| 11 | `UNIFIED_SCHEMA.md:1-2`: "Phiên bản 15" | **FALSE / drift** | Schema is v16 (F16); doc also repeats old vocabulary PK examples. |
| 12 | `ID_STRATEGY.md`: physical vocabulary PK convention `voc_hsk{lvl}_{...}` (e.g. `voc_hsk1_001`) | **FALSE in shipped data** | No `voc_*` id exists in any shipped write path: seed uses `VOC_HSK*_*` ids (5,000/5,000 rows), pack importer mints `vocab_*`; `voc_hsk*` appears only in docs/tests. This is the root of F01. |
| 13 | `ID_STRATEGY.md:"Không tạo 2 bản ghi riêng biệt gây phân mảnh..."` | **FALSE** | 268 duplicate word rows are created by the standard startup sequence (F01). |
| 14 | `README.md`: canonical dataset = 150 HSK-1 words only / docs claim 5,000-word seed | **PARTIAL drift** | Seed is 5,000 words (verified from JSON); HSK-1 pack adds 150 (142 overlapping). The duplication in F01 is the real issue. |
| 15 | Comment `database.dart:1-33` exports all migrations | **FALSE-ish (maintenance risk)** | `database.dart` re-exports v1–v11 only (lines 4-15); v12–v16 must be imported directly. Cosmetic today, but it hides new migrations from anything importing the barrel. |
| 16 | Tests intentionally/accidentally mask DB issues | **TRUE** | See F18: FK disabled in several suites and hand-built partial schema with `version: 1`. |

### Explicit non-findings (checked and cleared)

- **Migration registration/order**: 16 migrations registered in version order (`migration_engine.dart:36-54`), filtered `m.version > oldVersion && <= newVersion` and sorted (`:64-67`). Fresh DB (`oldVersion==0`) runs the entire chain; upgraded DB runs the exact same objects. No drift found.
- **Table creation order vs FK targets**: v1 creates `vocabularies` before `vocabulary_senses`, `srs_items` before `learner_evidence`, `chat_sessions` before `chat_messages`; v9 creates `content_packs`→`curriculums`→`units`→`lessons`→`segments`; v10 creates `knowledge_registry` before `lesson_knowledge_items`. FK column types are all `TEXT`/`INTEGER` matching referenced PKs. No creation-order defect.
- **`PRAGMA foreign_keys=ON`** is set in `onConfigure` before both onCreate/onUpgrade and is effective on the production connection (also asserted in `app_database_test.dart:38-39`).
- **`ConflictAlgorithm.abort` for append-only evidence** is used consistently in `learner_evidence_dao.dart:16`, `srs_repository.dart:178`, `learning_pipeline_coordinator.dart:222,328,562`.
- **`AppConstants.databaseVersion`** is **16**, not 1 — the suspicion in the task brief is stale.
- **No nested `Database.transaction` calls found**: every coordinator/repository that receives a `Transaction` uses it directly; the only transaction-taking helper (`AppDatabase.runInTransaction`) has no callers. The `_db is Database` guards prevent double-transactions.
- **`getDueFlashcards` sense selection** is deterministic (`ORDER BY COALESCE(vs2.order_index, 999999) ASC, vs2.id ASC LIMIT 1`), matching the F-17 fix claim.
