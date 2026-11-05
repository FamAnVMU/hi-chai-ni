# T6 — Feature Modules Audit

**Task:** task-6 — Study-skill feature modules audit (grammar, practice, sentences, hanzi, hanzi_writing, pinyin_foundation, reading, listening, pronunciation, shadowing, dictionary).
**Mode:** read-only static audit, data-flow traced UI → provider/controller → repository → DAO → SQLite/asset.
**No source files were modified. No `flutter`/`dart` build, analyze or test command was executed** (Lead/other teammate own those); evidence comes from reading the code, the shipped JSON assets, `pubspec.yaml`, and the checked-in `hi_chinese_dev.db` (queried with the bundled Python `sqlite3`).

## Scope summary

| Module | Files | Lines | Verdict (highlights) |
|---|---|---|---|
| grammar/** | 12 | 3,052 | Pack-sourced grammar points lose all examples/contrastive data (F03); only 1 of 4 generated exercises survives; partial-answer mastery inflate (F08); asset dataset import path is dead (F19) |
| practice/** | 15 | 2,853 | Seed error-detection exercise is mathematically unanswerable (F01); HSK1 hardcode hides 7th exercise type (F13); double-complete duplicates evidence (F14); stale-session index crash risk (F18) |
| sentences/** | 12 | 2,821 | Hardcoded 100% reading score on screen open (F05); placeholder quiz distractors + blank option (F16); self-assigned shadowing scores persisted as mastery (F17) |
| hanzi/** | 11 | 2,651 | Stroke engine good, but test score floor 50% (F12); free 100% / NaN when stroke data missing (F04) |
| hanzi_writing/** | 13 | 1,867 | Evaluator fabricates 100% for null stroke data (F04); stroke-order scoring is otherwise sane |
| pinyin_foundation/** | 9 | 2,044 | All exercises credited to the lesson's first item → completion meter can never reach 100% (F06); 64 audio URIs unresolved (F02) |
| reading/** | 8 | 1,500 | Duplicate completion evidence on submit+dispose (F09); hardcoded AI stub (F11) |
| listening/** | 5 | 751 | Single hardwired lesson, HSK2 lesson unreachable, answers never persisted (F15); audio missing (F02) |
| pronunciation/** | 9 | 1,489 | Honest "unsupported" UI, but unsupported attempts are persisted as score 0.0 evidence (F07); audio missing (F02) |
| shadowing/** | 8 | 1,214 | Audio missing (F02); evaluator lacks zero-duration guard (F22, latent) |
| dictionary/** | 8 | 2,067 | Search history polluted per keystroke (F10); hardcoded "AI" stub (F11); LIKE wildcard leakage (F20) |
| design_system/**, core/theme/** | 1 + theme | 630+ | Reviewed; no domain-logic defects found. Pure styling/animation — skipped per brief |

**Read for support:** `lib/core/database/dao/grammar_dao.dart`, `reading_dao.dart`, `vocabulary_dao.dart`, `content_item_dao.dart`, `dictionary_history_dao.dart`, `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`, `lib/features/content_packs/data/content_pack_manager.dart`, `lib/core/audio/*`, `lib/core/database/migrations/migration_v10.dart`, `pubspec.yaml`, `assets/data/*`, `assets/audio/*`.

## Top 5 priority order

1. **F01 (Critical)** — The only error-detection exercise in the seed catalog can *never* be answered correctly; every default practice session includes it.
2. **F02 (Critical)** — 84 audio URIs (pinyin 64, shadowing 9, pronunciation 9, listening 2) point at files that do not exist and are not declared in `pubspec.yaml`; all native-model playback fails silently.
3. **F03 (High)** — Every content-pack grammar point loses `examples`/`contrastiveExamples` (stored as `List<String>`, parsed as `List<Map>`), so the Grammar module shows an empty examples tab and generates only 1 of its 4 exercise types.
4. **F05 (High)** — Merely opening `SentenceReadingScreen` records a hardcoded `score: 100.0` practice attempt, promoting the sentence to `mastered` with a 3-day SRS due date.
5. **F06 (High)** — Pinyin practice credits every answer of a lesson to `lesson.items.first`, so mastery/completion credit is never given to items 2..N (completion % can never reach 100%).

---

## [T6-F01] Practice error-detection exercise is unanswerable (tokenizer never produces the stored `errorToken`)

- Severity: Critical
- Confidence: CONFIRMED
- Location: `lib/features/practice/presentation/widgets/true_false_or_error_widget.dart:133` (plus `lib/features/practice/domain/catalog/practice_seed_catalog.dart:88-99`, `lib/features/practice/domain/engine/practice_scoring_engine.dart:206-208`)
- Evidence:
```dart
// practice_seed_catalog.dart:88-99
        ExerciseDefinition(
          id: 'EX_ERROR_DETECT_06',
          type: ExerciseType.trueFalseOrErrorDetection,
          skill: 'grammar',
          hskLevel: 1,
          prompt: 'Tìm từ bị dùng sai trong câu sau:',
          stimulus: '他在学校学中文在。',
          errorToken: '在。',
```
```dart
// true_false_or_error_widget.dart:130-133, 150, 178
    final text = definition.stimulus ?? definition.sentenceWithBlank ?? '';

    // Split into segments/tokens roughly by space or Chinese punctuation
    final tokens = text.split(RegExp(r'(?<=\s)|(?<=\p{P})|(?=\p{P})', unicode: true)).where((s) => s.trim().isNotEmpty).toList();
...
            final isTargetError = definition.errorToken == token;
...
              onPressed: isSubmitted ? null : () => onSelectErrorToken(token),
```
```dart
// practice_scoring_engine.dart:206-208
    if (definition.errorToken != null && definition.errorToken!.isNotEmpty) {
      final selected = answer.selectedErrorToken ?? '';
      final isCorrect = selected == definition.errorToken;
```
- Root cause: The stimulus has no spaces; the regex only splits around punctuation, so the produced chips are `["他在学校学中文在", "。"]`. The stored `errorToken` is `"在。"` (a substring spanning the last verb *and* the full stop), which can never equal either chip. The learner can only ever submit one of the two chip strings, so `_evaluateTrueFalseOrError` always returns `isCorrect: false`. The correct chip is never highlighted either (`isTargetError` never true).
- Impact (user-visible): Every user who opens **Luyện tập** from the Learning screen (the only call site is `learning_screen.dart:248`, which uses the default `skill: 'general', hskLevel: 1`) receives this question — `getExercises(hskLevel: 1)` returns it. The user taps the faulty word, is told they are wrong, is shown no green answer, and their practice session score is capped below 100% no matter what they do.
- Fix: Store a token that the renderer can actually produce (e.g. `errorToken: '在'`) and make the widget validate against a structured token list, not ad-hoc splitting; or split Chinese text into single characters when no spaces are present and compare with `text.contains(...)` semantics. Minimal fix:
```dart
// seed: errorToken: '在'  (and errorCorrection: '')
// widget: build selectable units from the error token itself
final tokens = RegExp(r'[\u4e00-\u9fff]|[^\u4e00-\u9fff\s]').allMatches(text)
    .map((m) => m.group(0)!)
    .toList();
```
- Verification status: Traced `learning_screen.dart:248` → `PracticeSessionScreen._initSession` (`practice_session_screen.dart:57-69`) → `DefaultPracticeRepository.getExercises` (`practice_repository.dart:65-92`) → `_buildExerciseBody` case `trueFalseOrErrorDetection` (`practice_session_screen.dart:434-442`) → `TrueFalseOrErrorWidget` split line 133 → scoring engine lines 204-223. Tokenizer output computed by hand against the regex (zero-width lookarounds around `\p{P}`).

## [T6-F02] 84 audio URIs reference assets that do not exist (pinyin, shadowing, pronunciation, listening); playback errors are unhandled

- Severity: Critical
- Confidence: CONFIRMED
- Location: `pubspec.yaml:76-81`, `lib/features/pinyin_foundation/domain/curriculum/pinyin_curriculum_catalog.dart:41`, `lib/features/shadowing/domain/engine/shadowing_document_bank.dart:21`, `lib/features/pronunciation/domain/engine/pronunciation_item_bank.dart:16`, `lib/features/listening/domain/models/listening_lesson.dart:52`
- Evidence:
```yaml
# pubspec.yaml:76-81 — only assets/data and the two numeric audio folders are bundled
  assets:
    - assets/data/
    - assets/data/content_packs/hsk1/
    - assets/data/content_packs/hsk2/
    - assets/audio/hsk1/
    - assets/audio/hsk2/
```
```dart
// pinyin_curriculum_catalog.dart:41 (one of 64 pinyin URIs)
              audioUri: 'assets/audio/pinyin/syllable_structure.mp3',
// shadowing_document_bank.dart:21 (one of 9)
          audioUri: 'assets/audio/shadowing/doc01_01.mp3',
// pronunciation_item_bank.dart:16 (one of 9)
      audioUri: 'assets/audio/pronunciation/ma1.mp3',
// listening_lesson.dart:52 (one of 2)
          audioUrl: 'asset:///assets/audio/listening_hsk1_01.mp3',
```
Filesystem verification (PowerShell `Test-Path`): `assets/audio/pinyin` **does not exist**, `assets/audio/pronunciation` **does not exist**, `assets/audio/shadowing` **does not exist**; `assets/audio/listening_hsk1_01.mp3` / `listening_hsk2_01.mp3` **do not exist**. `assets/audio/` contains only `hsk1/` and `hsk2/` (500 numeric Tatoeba files). A raw scan of `lib/**/*.dart` counts 64 `assets/audio/pinyin/` references, 9 `assets/audio/pronunciation/`, 9 `assets/audio/shadowing/`, 2 `assets/audio/listening_`.
```dart
// pinyin_lesson_screen.dart:124-129 — fire-and-forget, no await, no catch
                            onPressed: () {
                              UnifiedAudioPlaybackService.instance.playAudio(
                                item.audioUri,
                                simulatedDuration: const Duration(milliseconds: 1500),
                              );
                            },
```
- Root cause: URI constants were authored against asset folders that were never created or declared in `pubspec.yaml`. `DefaultAudioPlayerService.play` throws `AudioPlaybackException` when an asset source cannot be loaded (`audio_player_service.dart:181-203`), `UnifiedAudioPlaybackService.playAudio` rethrows it (`unified_audio_playback_service.dart:74-80`), and the pinyin/shadowing callers neither await nor catch. Shadowing additionally never catches (`shadowing_screen.dart:86-91`), so a raw async error is raised; the listening module is the only one that shows an error banner (`listening_screen.dart:177-199`).
- Impact (user-visible): Pinyin Foundation's "Nghe âm thanh mẫu"/lesson speaker buttons do nothing (no sound, no feedback); Shadowing's "Phát câu mẫu" does nothing; Pronunciation Lab's "Nghe phát âm chuẩn" does nothing; Listening's player shows an error and no audio for every lesson, making the listening quiz unplayable from audio. For Pinyin, the whole listening-based curriculum premise (tones/initials/finals by ear) is broken.
- Fix: Ship the audio (declare `assets/audio/pinyin/`, `assets/audio/pronunciation/`, `assets/audio/shadowing/` in `pubspec.yaml` and add files), or remove the URIs and route through OS TTS/native synthesis; and make every call site await + surface failure:
```dart
Future<void> _playAsset(String uri) async {
  try {
    await UnifiedAudioPlaybackService.instance.playAudio(uri);
  } on AudioPlaybackException catch (e) {
    if (!mounted) return;
    HiSnackBar.showError(context, 'Không phát được audio mẫu: ${e.message}');
  }
}
```
- Verification status: `Test-Path` on every referenced directory/file; `pubspec.yaml` asset list read; call chains traced from UI buttons to `DefaultAudioPlayerService.play`. No audio-pack downloader covers these namespaces (audio pack manager lists only HSK1-6 numeric packs, `audio_pack_manager.dart:76-107`).

## [T6-F03] Content-pack grammar points silently lose all examples and contrastive examples → grammar practice collapses to 1 exercise

- Severity: High
- Confidence: CONFIRMED
- Location: `lib/features/content_packs/data/content_pack_manager.dart:632` (writer), `lib/features/grammar/domain/models/grammar_models.dart:270-286` (silent parser), `lib/features/grammar/domain/engine/grammar_exercise_generator.dart:22-38`
- Evidence:
```dart
// content_pack_manager.dart:605-609, 629-636
              final title = p['title'] as String? ?? 'Điểm ngữ pháp $order';
              final structure = p['structure'] as String? ?? '';
              final explanation = p['explanation'] as String? ?? '';
              final posEx = p['positive_example'] as String? ?? '';
              final conEx = p['contrastive_example'] as String? ?? '';
...
                    'title': title,
                    'structure': structure,
                    'meaning_vi': explanation,
                    'examples_json': json.encode(posEx.isNotEmpty ? [posEx] : []),
                    'contrastive_examples_json': json.encode(conEx.isNotEmpty ? [conEx] : []),
```
```dart
// grammar_models.dart:270-286 — parser expects List<Map>, receives List<String>
    List<GrammarExample> parseExamples(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => GrammarExample.fromMap(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
        return [];
      }
```
- Root cause: The content-pack importer writes `examples_json` as `["你好！ (Chào bạn!)"]` — a JSON array of plain strings — while `GrammarExample.fromMap` requires objects and `ContrastiveExample.fromMap` likewise (`grammar_models.dart:287-302`). The cast `e as Map<String, dynamic>` throws `TypeError`, which the parser swallows with `catch (_) {}` and returns `[]`. This affects every grammar item seeded from `assets/data/content_packs/hsk1|hsk2/*.json` (45 points per pack, verified with Python against the pack: 15 grammar content items × 3 points). The same bug exists in `migration_v10.dart:274/278`.
- Impact (user-visible): In Grammar Detail: the "Ví dụ & Lỗi sai" tab always shows "Chưa có câu ví dụ nguyên bản"/no contrastive cards; the "Luyện tập" tab generates only the Structure-Selection exercise because `GrammarExerciseGenerator` skips fill-in-the-blank (needs `item.examples`), reorder (needs examples) and error-recognition (needs contrastive-examples/examples) — 1 instead of 4 exercises per grammar point. Saving that single answer yields a full mastery score (see F08).
- Fix: Write structured maps, e.g. `"examples_json": json.encode([{ 'chinese': posEx, 'pinyin': '', 'translation_vi': '' }])`, and make the parser accept both shapes instead of swallowing errors:
```dart
if (e is String) {
  return GrammarExample(hanzi: e, pinyin: '', translationVi: '');
}
if (e is Map) return GrammarExample.fromMap(Map<String, dynamic>.from(e));
throw FormatException('Bad grammar example: $e');
```
- Verification status: Traced startup `app_startup_provider.dart:137-162` (mandatory packs installed at every launch, `ContentPackManager.installOrUpdatePack`) → `content_pack_manager.dart:600-660` writes grammar rows → `DefaultGrammarRepository._ensureCatalogSeeded` skips asset import because `COUNT(*) > 0` (`grammar_repository.dart:46-70`) → `getGrammarItemById` → `GrammarItem.fromMap` → parser returns `[]` → detail screen `_cachedGeneratedExercises`. Verified pack payload type: `positive_example` is a String in both pack files.

## [T6-F04] Hanzi stroke evaluator returns 100% accuracy when stroke-order data is unavailable (and can crash on 0/0)

- Severity: Medium
- Confidence: LIKELY (code path confirmed; needs stroke data to be missing/stale at evaluate time)
- Location: `lib/features/hanzi_writing/domain/engine/stroke_evaluator.dart:19-33`, `lib/features/hanzi_writing/presentation/screens/hanzi_writing_screen.dart:50-63`, `lib/features/hanzi_writing/presentation/widgets/writing_toolbar.dart:108-117`
- Evidence:
```dart
// stroke_evaluator.dart:19-33
    // Case 1: Unverified or missing stroke order data
    if (strokeData == null) {
      return WritingEvaluationResult(
        strokeOrderAccuracy: 1.0,
        correctStrokeCount: drawnStrokes.length,
        totalStandardStrokes: drawnStrokes.length,
        userDrawnStrokesCount: drawnStrokes.length,
        isTracingMode: isTracing,
        hasStandardStrokeData: false,
        ...
```
```dart
// hanzi_writing_screen.dart:50-63 — null is a legitimate runtime state while the async provider loads
    final strokeData = ref.read(currentHanziStrokeDataProvider).value ?? bank.getStrokeData(character);
    ...
    final result = evaluator.evaluate(
      drawnStrokes: _canvasController.strokes,
      canvasSize: canvasSize,
      strokeData: strokeData,
      mode: _canvasController.mode,
    );
```
```dart
// writing_toolbar.dart:116 — evaluate is enabled whenever any stroke was drawn, regardless of hasStrokeData
                    onPressed: controller.strokeCount > 0 ? onEvaluate : null,
```
- Root cause: "No reference data" is treated as a perfect score instead of "unscored". `currentHanziStrokeDataProvider` is an async future (`hanzi_writing_providers.dart:47-51`); if the user taps **Chấm điểm** while it is loading/errored, or a character is absent from the 2,632-row `hanzi_characters` table (the table is seeded lazily by `DefaultHanziRepository.ensureSeedLoaded`, which the stroke-bank `HanziDao` does **not** call), `strokeData` is null → 100% + "Đạt tiêu chuẩn nét" + `100/100 nét đúng`. Additionally, if a non-null `HanziStrokeData` has `strokes: []` (returned by `_convertFromHanziCharacter` for characters without medians, `hanzi_stroke_bank.dart:299-310`), line 114 computes `0 / 0 = NaN`; `(NaN).round()` in `WritingEvaluationResult.scorePercent` (`stroke_models.dart:213`) throws `UnsupportedError`.
- Impact (user-visible): A learner can scribble one stroke and be awarded a perfect score, saved as `learner_evidence` with `score: 1.0` (`hanzi_writing_repository.dart:39-55`) and fed into home/streak analytics. With empty-stroke data the app crashes on the score sheet instead.
- Fix: Never fabricate a pass; return a distinct "unscored" result and disable save:
```dart
if (strokeData == null || strokeData.strokes.isEmpty) {
  return const WritingEvaluationResult(
    strokeOrderAccuracy: 0.0,
    correctStrokeCount: 0,
    totalStandardStrokes: 0,
    ... // hasStandardStrokeData: false
  );
}
...
final accuracy = totalStandard == 0 ? 0.0 : (correctStrokes / totalStandard).clamp(0.0, 1.0);
```
and gate the toolbar's evaluate with `hasStrokeData`.
- Verification status: call chain traced `writing_toolbar.dart:116` → `hanzi_writing_screen.dart:50-63` → `StrokeEvaluator.evaluate`; `hanzi_stroke_bank.dart:255-295` shows the sync getter only knows the 8 curated characters while the async getter needs the DB; `hanzi_repository.dart:146-174` shows lazy seeding is the only place `hanzi_characters` is populated.

## [T6-F05] Sentence Reading screen awards a hardcoded 100% score the moment it is opened

- Severity: High
- Confidence: CONFIRMED
- Location: `lib/features/sentences/presentation/screens/sentence_reading_screen.dart:34-38`
- Evidence:
```dart
    widget.repository.recordPracticeAttempt(
      sentenceId: widget.sentence.id,
      practiceType: 'reading',
      score: 100.0,
    );
```
- Root cause: A "reading practice" attempt is recorded in `initState`, with a literal perfect score, without any user action or comprehension check.
- Impact (user-visible): In `DefaultSentenceRepository.recordPracticeAttempt` (`sentence_repository.dart:79-124`), `score >= 85` sets `mastery = 'mastered'` and schedules SRS review in 3 days. Opening the "Luyện đọc" screen (from Sentence Browser) instantly marks the sentence mastered, adds a reading attempt, and inflates the daily streak/analytics with a fake 100% — even if the user immediately presses back. Re-opening repeats the attempt.
- Fix: Record reading attempts on a meaningful interaction (e.g. after transcript reveal + explicit "Đã đọc xong" button, or after the token-tap/quiz interaction), and never hardcode a score:
```dart
onPressed: () => widget.repository.recordPracticeAttempt(
  sentenceId: widget.sentence.id,
  practiceType: 'reading',
  score: _comprehensionScore, // computed by a real check
),
```
- Verification status: screen opened from `sentence_browser_screen.dart` action row ("Luyện đọc") → `SentenceReadingScreen.initState` → repository → `SentencePracticeProgress` mastery thresholds. No comprehension widget exists on this screen to justify a score.

## [T6-F06] Pinyin practice credits every exercise in a lesson to `lesson.items.first` — items 2..N never accumulate mastery and completion can never reach 100%

- Severity: High
- Confidence: CONFIRMED
- Location: `lib/features/pinyin_foundation/presentation/screens/pinyin_practice_screen.dart:44-53`
- Evidence:
```dart
    // Save item progress in repository
    final itemId = widget.lesson.items.isNotEmpty ? widget.lesson.items.first.id : ex.id;
    final itemType = widget.lesson.items.isNotEmpty ? widget.lesson.items.first.type.name : 'syllable';

    await ref.read(pinyinRepositoryProvider).recordItemAttempt(
      itemId: itemId,
      itemType: itemType,
      isCorrect: eval.isCorrect,
      score: eval.score,
    );
```
- Root cause: The exercise has no linkage to the specific `PinyinItem` it tests (`PinyinExercise` is only prompt/audio/options/correctAnswer). The screen works around this by always using the lesson's first item, so all answers — including those for the lesson's 2nd/3rd/4th sound — are written to one progress row.
- Impact (user-visible): A learner can complete all 17 exercises correctly across the 6 units and the "Tiến độ làm chủ phát âm" percentage (`pinyin_overview_screen.dart:85-116` ← `PinyinRepository.getOverallCompletionRate`, `pinyin_repository.dart:134-154`, which counts `familiar`/`mastered` **items**) still counts only the first item of each lesson as practiced. The overall completion meter is structurally unfillable, and per-item mastery for non-first items never appears.
- Fix: Map each exercise to its target item id (add `itemId` to `PinyinExercise` or map by `correctAnswer`/metadata) and record against that id; use a real exercise→item link in the catalog:
```dart
final itemId = ex.itemId ?? widget.lesson.items.first.id;
```
- Verification status: traced screen `_submitAnswer` → `PinyinRepository.recordItemAttempt` (`pinyin_repository.dart:25-112`) → `getOverallCompletionRate` → `pinyinCompletionRateProvider` → overview UI.

## [T6-F07] Unsupported/Failed pronunciation attempts are persisted as score 0.0 evidence

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/pronunciation/data/pronunciation_repository.dart:30-43` (writer) and `lib/features/pronunciation/domain/services/pronunciation_analysis_service.dart:303-323` (offline/unsupported result)
- Evidence:
```dart
// pronunciation_repository.dart:30-43
      await txn.insert(
        DatabaseConstants.tableLearnerEvidence,
        {
          'id': evidenceId,
          'srs_item_id': null,
          'content_id': assessment.targetId,
          'content_type': 'pronunciation',
          'source': 'pronunciation_lab',
          'score': assessment.overallScore ?? 0.0,
          'duration_ms': assessment.recordedDurationMs,
          ...
```
```dart
// pronunciation_analysis_service.dart:303-323 — default provider (no AI configured) always lands here
  return PronunciationAssessmentResult(
      ...
      overallScore: null, // Honest null: no fake 0.85!
      ...
      status: PronunciationEvaluationStatus.unsupported,
```
- Root cause: The UI correctly refuses to fabricate a score (null + `unsupported`), but the repository coerces null to `0.0` and writes it as real application evidence; the analysis service is constructed with no AI provider (`pronunciation_providers.dart:21-23` `const DefaultPronunciationAnalysisService()` with `aiProvider == null`), so in the shipped offline configuration **every** attempt is stored as score 0.0.
- Impact (user-visible): The learner's evidence trail and any report/analytics that aggregates `learner_evidence.score` (learning pipeline, AI tutor context, home stats) record pronunciation failure after failure despite the honest "unsupported" card. `learning_activities` is also logged for each attempt (streak counts attempts that were never scored).
- Fix: Skip evidence insertion when `status != success` (or store `score: null` and a `status` field in metadata); only record practice activity for successful/scored attempts:
```dart
if (assessment.status != PronunciationEvaluationStatus.success) {
  // optionally log activity only
  return evidenceId;
}
```
- Verification status: traced `PronunciationLabScreen._evaluateRecordedAudio` (`pronunciation_lab_screen.dart:131-150`) → `service.evaluatePronunciation` → `repo.recordPronunciationSession`.

## [T6-F08] Grammar mastery is computed from only the answered subset; 1 correct of 4 exercises = 100% "Đã thành thạo" (and repeated saves double-count)

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/grammar/presentation/screens/grammar_detail_screen.dart:44-77` (plus `lib/features/grammar/data/grammar_repository.dart:367-383`)
- Evidence:
```dart
  Future<void> _handleCompleteExercises(GrammarItem item) async {
    if (_exerciseResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng làm ít nhất một bài tập trước khi lưu tiến độ.')),
      );
      return;
    }
...
    final totalScore = _exerciseResults.values.fold<double>(0.0, (acc, r) => acc + r.score);
    final avgScore = totalScore / _exerciseResults.length;
...
      'Đã lưu tiến độ! Điểm bài tập: ${(avgScore * 100).toInt()}% (${avgScore >= 0.8 ? "Đã thành thạo" : "Đang rèn luyện"}).',
```
```dart
// grammar_repository.dart:379-383
    final clampedScore = score.clamp(0.0, 1.0);
    final newStatus = clampedScore >= 0.8
        ? GrammarProgressStatus.mastered
        : GrammarProgressStatus.learning;
```
- Root cause: The aggregate is the mean over *submitted* entries only (`_exerciseResults` is a sparse map keyed by exercise index, filled only when an exercise is evaluated), not over `activeExercises.length`; unanswered exercises are ignored. Since grammar points seeded from packs expose only 1 generated exercise (F03), one correct answer = 100% = `mastered`. The save button is not idempotent either: pressing it again after the snackbar re-runs `recordStudySession`, incrementing `exercises_completed` and appending another evidence + activity row each time (`grammar_repository.dart:386-437`).
- Impact (user-visible): A learner answers a single structure-selection question and the grammar point is labelled "Đã thành thạo" and a fake high score/activity is persisted; skipping the other exercises is invisible.
- Fix: Divide by the total exercise count and require a minimum completion ratio; guard the save button:
```dart
final total = _cachedGeneratedExercises?.length ?? 1;
if (_exerciseResults.length < total) { /* ask user to finish all */ }
final avgScore = _exerciseResults.values.fold<double>(0.0, (a, r) => a + r.score) / total;
if (_isSavingProgress) return;
```
- Verification status: traced `GrammarExerciseWidget.onEvaluated` (`grammar_exercise_widget.dart:45-58`) → `_exerciseResults[idx] = result` (`grammar_detail_screen.dart:321-323`) → save handler. Repository thresholds confirmed.

## [T6-F09] Reading completion evidence is written twice per completed passage (submit + `dispose`), and again on every later visit

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/reading/presentation/screens/reading_detail_screen.dart:79-85` and `:393-409`; `lib/features/reading/data/reading_repository.dart:110-144`
- Evidence:
```dart
  @override
  void dispose() {
    _readingTimer?.cancel();
    _saveProgress(isCompleted: _existingProgress?.isCompleted ?? false);
    _scrollController.dispose();
    super.dispose();
  }
```
```dart
                        onSubmitted: (answers, score) async {
                          await _saveProgress(
                            isCompleted: true,
                            answers: answers,
                            score: score,
                          );
```
```dart
// reading_repository.dart:110-129
      // 2. If completed, persist to learner_evidence and feed daily streak
      if (isCompleted) {
        final evidenceId = 'ev_rdg_${DateTime.now().microsecondsSinceEpoch}';
        await _evidenceDao.appendEvidence(
          {
            ...
            'score': (score ?? 100.0) / 100.0,
```
- Root cause: `isCompleted` is sticky: once the quiz is submitted, `_existingProgress.isCompleted == true`, so the `dispose()`-triggered save (and every future open→close of the passage) also passes `isCompleted: true`, appending a fresh `learner_evidence` row (unique id per call) and a fresh `learning_activities` row each time. `score ?? 100.0` also turns a missing score into a perfect 1.0.
- Impact (user-visible): Completing one reading passage produces at least 2 completion evidence entries and 2 reading-activity rows (inflating streak/items/duration); re-reading the passage and leaving adds another pair each time, so the home dashboard and analytics over-report reading activity.
- Fix: Save only on explicit submit, and make `dispose` a progress-only save that never emits completion evidence (or dedupe by passage/day in the repository); don't default a missing score to 100%.
```dart
// dispose: persist position/time only
_saveProgress(isCompleted: false);
// repository: if (isCompleted && !alreadyCompleted) {...}
```
- Verification status: traced `ReadingQuestionsSection.onSubmitted` (`reading_questions_section.dart:53-59`) → `_handleSubmit` → detail screen save → repository activity/evidence inserts. `reading_progress` itself is protected by `passage_id UNIQUE` (`migration_v4.dart:54-56`), so only the evidence/activity duplication remains.

## [T6-F10] Dictionary search history is polluted with every debounced keystroke fragment (and by auto-search "你好")

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/dictionary/data/dictionary_repository.dart:37-58`, `lib/features/dictionary/presentation/screens/dictionary_screen.dart:63-99`, `lib/features/dictionary/presentation/widgets/quick_dictionary_sheet.dart:42-48`
- Evidence:
```dart
// dictionary_screen.dart:63-68 — live search 250ms after the last keystroke
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }
```
```dart
// dictionary_repository.dart:48-57 — every search() call writes history
    // Record search in history asynchronously
    final historyId = 'hist_${DateTime.now().microsecondsSinceEpoch}';
    ...
    await _historyDao.insertHistory(
      id: historyId,
      query: trimmed,
      searchType: searchType,
    );
```
```dart
// quick_dictionary_sheet.dart:47 — opening the sheet records a search
      _performSearch('你好'); // Pre-populate with common greeting as sample
```
- Root cause: History recording was put inside the search primitive rather than an explicit "search submitted/selected result" action. `DictionaryHistoryDao.insertHistory` only de-duplicates by exact query (`dictionary_history_dao.dart:18-23`), so typing `nihao` can persist `n`, `ni`, `nih`, `niha`, `nihao` as five separate history rows. Every quick-lookup sheet open also inserts `你好`, and `ReadingDetailScreen._handleWordTap` fallback (`reading_detail_screen.dart:108-113`) inserts word taps into the same history.
- Impact (user-visible): The "Lịch sử" tab and the "Lịch Sử Gần Đây" chips fill with partial-typing garbage; each keystroke also fires ~7 SQL queries plus a history write because `search()` is called on every debounce.
- Fix: Record history only from explicit submits/result taps; de-duplicate by prefix exhaustion or add a "remove previous prefix" rule:
```dart
// repository: search(..., {bool recordHistory = false});
// screen: onSubmitted: (_) => _performSearch(q, recordHistory: true);
```
- Verification status: traced `TextField.onChanged` (`dictionary_screen.dart:234`) → debounce → `_performSearch` → `repository.search` → `insertHistory`; quick sheet and reading word-tap paths confirmed.

## [T6-F11] "AI" explanation features return hardcoded strings displayed as real AI analysis

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/dictionary/data/dictionary_repository.dart:188-191`, `lib/features/reading/data/reading_repository.dart:148-156`
- Evidence:
```dart
// dictionary_repository.dart:188-191
  @override
  Future<String> explainWordWithAi(String word, {String? contextSentence}) async {
    return 'Phân tích từ "$word" bằng trợ lý AI.';
  }
```
```dart
// reading_repository.dart:148-156
  @override
  Future<String> askAiAboutPassage({
    required String passageText,
    required String userQuestion,
  }) async {
    // Academic & Architectural Honesty:
    // AI assists in explaining contextual grammar, cultural nuances and sentence breakdowns.
    return 'Giải thích AI: Về câu hỏi "$userQuestion", trong bài đọc: "$passageText", điểm mấu chốt nằm ở kết cấu ngữ pháp và ngữ cảnh giao tiếp tự nhiên của người bản xứ.';
  }
```
- Root cause: The repositories are wired to stubs, while the UI presents the output as AI-generated content: dictionary detail sheet heading `'AI Tutor Phân Tích Bổ Sung'` (`dictionary_detail_sheet.dart:584`) behind the button `'Hỏi AI giải thích ngữ cảnh'` (`:678`); reading detail dialog title `'Phản Hồi Từ AI Tutor'` (`reading_detail_screen.dart:221`) behind FAB `'Hỏi AI về bài đọc'` (`:428`). No provider/network call is made.
- Impact (user-visible): Every dictionary word and reading passage returns a canned sentence — frequently just the question echoed back — presented as a contextual AI explanation. Users are misled into thinking they received a real explanation (the README advertises an "AI Trợ Giảng" that explains context).
- Fix: Wire to the real AI service (`AiProvider` already exists at `lib/core/network/ai/`) or label the result as an offline placeholder and hide the "Ask AI" affordance when no provider is configured; throw/return `null` and let UI show availability state:
```dart
if (!aiService.isConfigured) throw const AiUnavailableException();
```
- Verification status: all call sites traced (`_handleAskAi` in both screens); no other implementation of `explainWordWithAi`/`askAiAboutPassage` exists (single `Default*Repository` implementation per abstract class). Contrast: pronunciation service is honest about the same limitation.

## [T6-F12] Hanzi "test" accuracy is floored at 50% no matter how many mistakes are made

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/hanzi/presentation/screens/hanzi_writing_screen.dart:200-216`
- Evidence:
```dart
  Future<void> _onCharacterCompleted() async {
    final mistakePenalty = (_mistakesCount * 12.0).clamp(0.0, 50.0);
    final finalAccuracy = (100.0 - mistakePenalty).clamp(50.0, 100.0);
    ...
    // Record attempt in database
    await widget.repository.recordPracticeAttempt(
      character: _character!.character,
      accuracy: finalAccuracy,
      mistakes: _mistakesCount,
      strokeOrderErrors: _orderErrorsCount,
      isTestMode: _mode == WritingMode.test,
    );
```
- Root cause: The double clamp makes the score range `[50, 100]`: after 5 or more wrong stroke attempts every additional error is free, and an attempt with e.g. 20 mistakes still reports 50%. The completion dialog then presents "Độ chính xác: 50.0%" and labels it `Cần ôn thêm`, and the repository stores 50 as `lastAccuracyScore` (`hanzi_repository.dart:116-130`).
- Impact (user-visible): The "test" mode cannot report poor performance; scores are silently inflated by up to 50 points. (The newer `hanzi_writing` module evaluator does not have this floor, so the two writing modules disagree.)
- Fix: Remove the artificial floor and let the penalty reach 0:
```dart
final finalAccuracy = (100.0 - _mistakesCount * 12.0).clamp(0.0, 100.0);
```
- Verification status: traced `_onStrokeDrawn` (`:173-198`, mistakes counted on every failed attempt) → `_onCharacterCompleted` → `recordPracticeAttempt` (`hanzi_repository.dart:77-133`).

## [T6-F13] Practice hub loads HSK1 only — the 7th exercise type (short answer) is unreachable, and only 6 of the 7 seed exercises exist for HSK1

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/learning/presentation/screens/learning_screen.dart:239-251`, `lib/features/practice/domain/catalog/practice_seed_catalog.dart:102-114`, `lib/features/practice/data/practice_repository.dart:65-92`
- Evidence:
```dart
// learning_screen.dart:239-251 — no skill/hskLevel parameters are passed
            _buildFeatureBanner(
              context: context,
              icon: Icons.quiz_rounded,
              title: 'Luyện tập tương tác (Practice Engine)',
              subtitle: '7 dạng bài tập chuẩn mực: trắc nghiệm, ghép cặp, điền từ...',
              buttonText: 'Luyện tập',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PracticeSessionScreen(),
                  ),
                );
              },
            ),
```
```dart
// practice_seed_catalog.dart:101-114 — the only shortAnswer seed is HSK 2
        // 7. Short Answer with Rubric (Writing/Translation)
        ExerciseDefinition(
          id: 'EX_SHORT_ANSWER_07',
          type: ExerciseType.shortAnswer,
          skill: 'writing',
          hskLevel: 2,
```
- Root cause: `PracticeSessionScreen` defaults `skill: 'general', hskLevel: 1`; `_initSession` then calls `repo.getExercises(skill: null, hskLevel: 1)` (`practice_session_screen.dart:62-69`), which filters `hsk_level = 1` (`practice_repository.dart:75-78`). The catalog has 7 items total: 6 HSK1 + 1 HSK2 short-answer, so the short-answer widget (`short_answer_widget.dart`, the only path to `ExerciseType.shortAnswer`) can never be reached from the app UI, and the banner's "7 dạng bài tập" claim is unfulfillable.
- Impact (user-visible): Users only ever see 6 questions per session, no short-answer translation practice, and repeated sessions recycle the same 6 seeds forever (there is no content-pack import into `practice_exercises`; `_ensureCatalogSeeded` seeds `PracticeSeedCatalog.items` only, `practice_repository.dart:47-62`). README's "150 bài tập xác định" is backed by the content pack (verified: 15 `PRACTICE_L*` items × 10 questions) but that bank is never wired into this module.
- Fix: Pass the learner's HSK level into `PracticeSessionScreen` and/or drop the HSK filter to draw from the content-pack exercise bank; seed the practice table from the pack rather than the 7-item catalog.
- Verification status: traced all `PracticeSessionScreen(` call sites (only `learning_screen.dart:248`), catalog contents (7 items), repository filter, and pack counts with Python (150 questions in `hsk1_pack_v1.json`).

## [T6-F14] Double-tapping "Hoàn thành phiên" duplicates completion evidence and activity rows

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/practice/presentation/screens/practice_session_screen.dart:217-244`, `:381-389`, `lib/features/practice/data/practice_repository.dart:259-341`
- Evidence:
```dart
// practice_session_screen.dart:217-244
  Future<void> _goToNextQuestion() async {
    if (_session == null) return;

    final nextIndex = _session!.currentIndex + 1;
    final repo = ref.read(practiceRepositoryProvider);

    if (nextIndex >= _exercises.length) {
      // Completed session!
      _sessionStopwatch.stop();
      final completed = await repo.completeSession(
        sessionId: _session!.id,
        totalDurationMs: _sessionStopwatch.elapsedMilliseconds,
      );
```
```dart
// practice_repository.dart:293-328 — evidence/activity ids are timestamp-based, so a second call inserts new rows
      if (attempts.isNotEmpty) {
        await executor.insert(
          DatabaseConstants.tableLearnerEvidence,
          {
            'id': 'evi_practice_${DateTime.now().millisecondsSinceEpoch}',
            ...
        await executor.insert(
          DatabaseConstants.tableLearningActivities,
          {
            'id': 'act_practice_${DateTime.now().millisecondsSinceEpoch}',
```
- Root cause: `_goToNextQuestion` has no in-flight guard and the "Hoàn thành phiên" button stays enabled while the async completion is running. `completeSession` unconditionally inserts a new `learner_evidence` row (id = millisecond timestamp) and a new `learning_activities` row every call; it never checks that the session is already `completed`.
- Impact (user-visible): A quick double-tap on the last question writes duplicate completion evidence + duplicate practice activity (inflated streak/items/duration, `completed` dialog shown twice). Same class of issue: re-opening and completing an already completed session path is guarded by `session.isCompleted` only at session-create time, not here.
- Fix: Disable the button while completing (`_isSubmitting` / `_isCompleting` guard) and make `completeSession` idempotent (check `status = 'completed'` and return existing session before inserting evidence).
- Verification status: traced button `onPressed: _goToNextQuestion` → completion branch → repository inserts; confirmed no guard in either layer.

## [T6-F15] Listening module is hardwired to one lesson and never persists results

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/listening/presentation/providers/listening_providers.dart:17-31`, `lib/features/listening/presentation/screens/listening_screen.dart:20-24`, `lib/features/listening/data/repositories/listening_repository.dart:3-27`
- Evidence:
```dart
// listening_providers.dart:17-31
class ActiveListeningLessonNotifier extends Notifier<ListeningLesson?> {
  @override
  ListeningLesson? build() {
    final lessons = ListeningLesson.defaultLessons;
    return lessons.isNotEmpty ? lessons.first : null;
  }
...
final activeListeningLessonProvider = NotifierProvider<ActiveListeningLessonNotifier, ListeningLesson?>(
  ActiveListeningLessonNotifier.new,
);

final listeningPlaybackProvider = NotifierProvider<ListeningPlaybackNotifier, ListeningPlaybackState>(
  ListeningPlaybackNotifier.new,
);
```
```dart
// listening_repository.dart:3-27 — read-only API
abstract class ListeningRepository {
  Future<List<ListeningLesson>> getLessons({int? hskLevel});
  Future<ListeningLesson?> getLessonById(String id);
}
```
- Root cause: `ActiveListeningLessonNotifier` always returns `defaultLessons.first`; `listeningLessonsProvider` (line 12) is defined but never watched anywhere in `lib/`, and `ListeningScreen` has no lesson list/selector. Quiz answer state exists only in the notifier (`selectAnswer`/`submitQuestion`, `listening_providers.dart:272-282`); no repository method, evidence row, or activity row is ever written.
- Impact (user-visible): The HSK2 listening lesson (`LIS_HSK2_01_SHOPPING`, `listening_lesson.dart:74-100`) is unreachable; users always get the same HSK1 dialogue. Correct quiz answers produce a green banner but nothing is saved — no progress, no streak, no evidence — a silent data-loss dead end for the listening skill.
- Fix: Render a lesson list from `listeningLessonsProvider`, set the active lesson via `selectLesson`, and persist submissions (evidence + activity) through a real repository method:
```dart
Future<void> recordListeningAttempt({required String lessonId, required int correct, required int total});
```
- Verification status: grepped all usages: `activeListeningLessonProvider` is only read in `listening_screen.dart:21,44`; `listeningLessonsProvider` has no consumer; repository interface has no write method.

## [T6-F16] Sentence-listening quiz fabricates placeholder options and can include an empty correct answer when launched from the dictionary

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/sentences/presentation/screens/sentence_listening_screen.dart:71-97`, `lib/features/dictionary/presentation/widgets/dictionary_detail_sheet.dart:500-521`
- Evidence:
```dart
  void _setupQuiz() {
    _selectedOption = null;

    final correct = _currentSentence.translationVi.isNotEmpty
        ? _currentSentence.translationVi
        : _currentSentence.translationEn;

    final distractors = <String>[];
    for (final s in widget.sentenceList) {
      if (s.id != _currentSentence.id) {
        ...
      }
      if (distractors.length >= 3) break;
    }

    while (distractors.length < 3) {
      distractors.add('Nghĩa khác mẫu ${distractors.length + 1}');
    }

    final all = [correct, ...distractors.take(3)]..shuffle(Random());
```
```dart
// dictionary_detail_sheet.dart:510-519 — detail sheet passes a list containing only the current item
                                               final repo = DefaultSentenceRepository(SentenceDao(db));
                                               Navigator.push(
                                                 context,
                                                 MaterialPageRoute(
                                                   builder: (_) => SentenceListeningScreen(
                                                     sentence: item,
                                                     sentenceList: [item],
```
- Root cause: The quiz is generated from neighbouring sentences in `widget.sentenceList`; when the list is a singleton (dictionary "Luyện nghe" / "Shadowing" row buttons always pass `sentenceList: [item]`), no distractors can be collected and the `while` loop appends literal placeholders "Nghĩa khác mẫu 1/2/3" as answer options. If the dictionary example's Vietnamese translation is empty, `correct` is `''`, producing a blank option that is actually the correct answer.
- Impact (user-visible): From the dictionary detail sheet, a listening exercise shows obviously fake options; the user gets a meaningless multiple-choice quiz (or a blank button they must tap to win). The same singleton pattern hides all other sentences when navigating inside the screen.
- Fix: Provide distractors from the sentence repository (fetch random same-level sentences), and skip the quiz when `correct` is empty or fewer than 3 real distractors exist:
```dart
if (correct.isEmpty) return; // no quiz
if (distractors.length < 2) return; // not enough real options
```
- Verification status: traced both `SentenceListeningScreen` invocations (dictionary detail + sentence browser) and `_setupQuiz`.

## [T6-F17] Sentence shadowing stores self-assigned scores (100/75/50) as real mastery/SRS results

- Severity: Medium
- Confidence: CONFIRMED
- Location: `lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart:102-120, 252-273`, `lib/features/sentences/data/sentence_repository.dart:79-124`
- Evidence:
```dart
  void _onEvaluate(double score) {
    setState(() {
      _evaluatedScore = score;
    });

    widget.repository.recordPracticeAttempt(
      sentenceId: widget.sentence.id,
      practiceType: 'shadowing',
      score: score,
      recordedAudioPath: _recordedFilePath,
    );
```
```dart
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Rất chuẩn (100%)'),
                          selected: _evaluatedScore == 100.0,
                          onSelected: (_) => _onEvaluate(100.0),
                        ),
                        ChoiceChip(
                          label: const Text('Tương đối (75%)'),
                          selected: _evaluatedScore == 75.0,
                          onSelected: (_) => _onEvaluate(75.0),
                        ),
```
- Root cause: The only "evaluation" is a self-reported chip; the chosen constant is sent directly to `recordPracticeAttempt`, which derives mastery (`score >= 85` → `mastered`, SRS +3 days, `count >= 2 && currentScore >= 0.7` in pinyin style — here `sentence_repository.dart:97-106`). Every chip tap also writes another attempt (`prevShadowing + 1`) because the chips stay enabled.
- Impact (user-visible): Selecting "Rất chuẩn" immediately records a 100% shadowing attempt → mastered + SRS schedule, with no audio analysis at all. Re-tapping the chips inflates attempt counts and evidence, and self-assessment is indistinguishable from objective scoring downstream.
- Fix: Treat it as self-reflection only (store separately, don't feed mastery/SRS), or run a real similarity analysis on the recording before recording a score; disable chips after selection.
- Verification status: traced chip callbacks (`:254-273`) → `_onEvaluate` → repository → progress/mastery; note the module itself documents "Tự đánh giá độ tương đồng phát âm" so honesty in the widget is undermined by the persistence semantics.

## [T6-F18] Resuming a practice session uses a stale `currentIndex` against a freshly filtered exercise list (RangeError risk; session `exerciseIds` ignored)

- Severity: Medium
- Confidence: LIKELY (crash requires content/filter drift between session creation and resume)
- Location: `lib/features/practice/presentation/screens/practice_session_screen.dart:57-115` and `:312-313`
- Evidence:
```dart
    // 1. Check for custom exercises or load from DB
    List<ExerciseDefinition> exercises;
    if (widget.customExercises != null && widget.customExercises!.isNotEmpty) {
      exercises = widget.customExercises!;
    } else {
      exercises = await repo.getExercises(
        skill: widget.skill == 'general' ? null : widget.skill,
        hskLevel: widget.hskLevel,
      );
    }
...
    // 2. Check for active session to resume
    PracticeSession? session;
    if (widget.initialSessionId != null) {
      session = await repo.getSessionById(widget.initialSessionId!);
    } else {
      session = await repo.getActiveSession(skill: widget.skill == 'general' ? null : widget.skill);
    }
...
    final currentEx = _exercises[_session!.currentIndex];
```
```dart
// practice_session_screen.dart:312-313 (build)
    final currentEx = _exercises[_session!.currentIndex];
```
- Root cause: The exercise list is rebuilt from the *current* repository state, but the resumed `PracticeSession.currentIndex` belongs to the session's stored `exerciseIds` — which are never used to reconstruct the list. Any change in the exercise set (app update changing seed/exercise rows, content-pack/test data inserted, or a session loaded via `initialSessionId` for a different skill/level) yields index drift; `_session.currentIndex >= _exercises.length` throws `RangeError` at `:109`/`:312`.
- Impact (user-visible): Crash on opening Practice after an app update that changes the exercise catalog; even without a crash, the answered-question state is mapped onto the wrong exercise (resume shows attempt feedback for a different question and the score/evidence is attached to the wrong exercise id).
- Fix: Derive `currentIndex`-safe list from `session.exerciseIds` (fetch them via repository in order) and clamp:
```dart
exercises = await repo.getExercisesByIds(session.exerciseIds);
final idx = session.currentIndex.clamp(0, exercises.length - 1);
```
- Verification status: traced `_initSession` and both `_exercises[_session!.currentIndex]` dereferences; session factory stores `exercise_ids_json` (`practice_models.dart:552-564`) but no code reads it back for list construction (search: `exerciseIds` used only in creation/serialization).

## [T6-F19] The 1,027-item grammar asset can never be imported: `hsk_level` is a JSON string, `GrammarItem.fromMap` casts to `int?`, and the failure is silently swallowed

- Severity: Low
- Confidence: RISK (latent: production startup installs content packs first, so the asset import branch is normally skipped; if it runs, it always fails)
- Location: `lib/features/grammar/data/grammar_repository.dart:46-70, 452-462`, `lib/features/grammar/domain/models/grammar_models.dart:334-338`
- Evidence:
```dart
// grammar_repository.dart:46-70
  Future<void> _ensureCatalogSeeded() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableGrammarItems}'),
    );

    if (count == null || count == 0) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/hsk_grammar_all.json');
        final decoded = json.decode(jsonStr) as List<dynamic>;
        final items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await importGrammarDataset(items);
        return;
      } catch (_) {
        // Fallback for tests or environments where rootBundle is unavailable
      }
      for (final item in GrammarCatalog.items) { ... }
```
```dart
// grammar_models.dart:334-338
    final id = map['id'] as String? ?? '';
    final hskLevel = map['hsk_level'] as int? ?? 1;
    final code = map['code'] as String? ?? id;
```
- Root cause: In `assets/data/hsk_grammar_all.json` every item stores `hsk_level` as a string (`"1"`, verified with Python on all 1,027 rows: `{'1': 115, '2': 156, ...}`). `map['hsk_level'] as int?` throws `TypeError` for the first item, the import transaction rolls back, the bare `catch (_)` hides it, and the repository silently falls back to `GrammarCatalog.items` — **6** hardcoded grammar points. The 1,027 enriched rows with real examples/contrastive data are therefore unreachable through this code path.
- Impact (user-visible): In any environment where the grammar table is empty and content packs are not installed (tests, a failed/partial pack install, first screen before startup pack import), the Grammar module silently shows 6 points and HSK2-6 filters are empty; the fallback makes the loss invisible.
- Fix: Parse numbers leniently and don't swallow errors silently:
```dart
final hskLevel = int.tryParse('${map['hsk_level']}') ?? 1;
...
} catch (e, st) {
  debugPrint('[Grammar] Asset import failed: $e\n$st');
}
```
- Verification status: JSON types verified with Python (`json.load` type inspection); `importGrammarDataset` traced (`grammar_repository.dart:451-498`); dev DB has 1,027 `GUSHI_*` rows with integer `hsk_level`, proving a separate seeding tool produced them, not this repository path.

## [T6-F20] User input with SQL LIKE wildcards (`%`, `_`) is not escaped — broadens searches and can return unrelated rows

- Severity: Low
- Confidence: CONFIRMED
- Location: `lib/core/database/dao/vocabulary_dao.dart:196-216`, `lib/features/sentences/data/sentence_dao.dart:76-82`, `lib/features/hanzi/data/hanzi_dao.dart:61-67`
- Evidence:
```dart
// vocabulary_dao.dart:196-216
        final prefix = await _db.query(
          DatabaseConstants.tableVocabularies,
          where: '(simplified LIKE ? OR traditional LIKE ?) AND deleted_at IS NULL',
          whereArgs: ['$trimmed%', '$trimmed%'],
...
          where: '(simplified LIKE ? OR traditional LIKE ?) AND deleted_at IS NULL',
          whereArgs: ['%$trimmed%', '%$trimmed%'],
```
```dart
// sentence_dao.dart:76-82
      where: 'chinese LIKE ? OR pinyin LIKE ? OR translation_vi LIKE ? OR translation_en LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%', '%$trimmed%'],
```
- Root cause: All queries are parameterized (no SQL injection), but the user's text is embedded into the LIKE pattern without escaping `%`/`_`/`\`. Searching `%` matches every row (`%%%`), searching `_` matches arbitrary single-character positions, returning arbitrary vocabulary/sentences and polluting search history with wildcard entries.
- Impact (user-visible): Entering dictionary/pinyin/sentence searches containing `%` or `_` returns seemingly random results (or the first N rows) instead of "no results"; in the dictionary, the result list then records a bogus history item.
- Fix: Escape LIKE metacharacters and add `ESCAPE '\'`:
```dart
String likeEscape(String s) => s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
where: "simplified LIKE ? ESCAPE '\\'", whereArgs: ['%${likeEscape(trimmed)}%'],
```
- Verification status: all three DAO call sites read; search strings flow directly from `DictionaryScreen`/`SentenceBrowserScreen`/`HanziCharacterListScreen` TextFields.

## [T6-F21] Empty matching-pairs exercise is scored as a perfect answer

- Severity: Low
- Confidence: RISK (seed data currently has 4 pairs; only reachable with malformed/DB exercise rows)
- Location: `lib/features/practice/domain/engine/practice_scoring_engine.dart:84-94`
- Evidence:
```dart
    final userPairs = answer.matchedPairs ?? {};
    final totalPairs = definition.matchingPairs.length;
    if (totalPairs == 0) {
      return const ScoringResult(
        isCorrect: true,
        score: 1.0,
        confidence: 1.0,
        evaluatorType: EvaluatorType.deterministic,
        feedbackVi: 'Hoàn tất ghép cặp.',
      );
    }
```
- Root cause: A zero-pair exercise is treated as "completed perfectly" rather than invalid; the same score path is used for session mean calculation.
- Impact (user-visible): Any malformed/imported matching exercise (or a DB row with empty payload) grants free 1.0, raising session score/evidence. `ExerciseValidator` would flag `< 2` pairs (`exercise_validator.dart:70-76`) but `getExercises()` never runs the validator (`practice_repository.dart:84-91`).
- Fix: Return a validation error / zero score and reject invalid exercise definitions when loading:
```dart
if (totalPairs == 0) return const ScoringResult(isCorrect: false, score: 0.0, ...);
```
- Verification status: repository read path confirmed; no validation call in `getExercises`/`getExerciseById` (only `ExerciseValidator` exists as a standalone helper with no production callers — grep shows only its own file).

## [T6-F22] Shadowing evaluator has no zero-duration guard (division by zero → Infinity/NaN percentages)

- Severity: Low
- Confidence: RISK (current document bank hardcodes positive durations, so not reachable today; any new segment with `durationMs: 0` triggers it)
- Location: `lib/features/shadowing/domain/engine/shadowing_evaluator.dart:15-52`
- Evidence:
```dart
    final userMs = userDuration.inMilliseconds;
    // Base target duration adjusted by playback speed rate
    final effectiveTargetMs = (segment.durationMs / speed.rate).round();

    if (userMs < 400) { ... }

    // Pacing ratio: 1.0 means exact same duration as native sample
    final ratio = userMs / effectiveTargetMs;

    final String verdict;
    if (ratio >= 0.85 && ratio <= 1.15) { ... }
...
    final diff = (ratio - 1.0).abs();
    final timelineMatch = ((1.0 - diff.clamp(0.0, 1.0)) * 100.0).clamp(10.0, 100.0);
```
- Root cause: `ratio` is computed before any check that `effectiveTargetMs > 0`. With `durationMs == 0` (constructor default is 3,000 but the field is caller-controlled) `userMs / 0` yields `double.infinity` or `NaN`; `.clamp` on NaN propagates NaN, `toStringAsFixed` renders `"NaN"`, and the timeline card displays invalid pacing/fluency values. (Division-by-zero also occurs if a future playback speed entry were 0.)
- Impact (user-visible): Garbage metrics ("NaN", Infinity pacing) and `timelineMatchPercent`/`fluencyIndex` NaNs persisted into evidence metadata if a bad segment is authored/downloaded.
- Fix: Guard before dividing:
```dart
if (effectiveTargetMs <= 0) {
  return ShadowingAssessmentResult(... timelineMatchPercent: 0, fluencyIndex: 0, pacingRatio: 0, ...);
}
```
- Verification status: read evaluator + `ShadowingDocumentBank` (all three docs hardcode 2500-3500 ms) + `ShadowingTimelineCard` (`:124` uses `pacingRatio / 1.5`). Marked RISK for reachability.

---

## Verified-correct (avoid false positives)

These areas were checked and behave as the code claims; they are **not** findings:

- **README content claims are backed by the shipped pack.** `assets/data/content_packs/hsk1/hsk1_pack_v1.json` verified with Python: 15 `VOCAB_*` content items × 10 words = **150 vocabulary**, 15 `GRAMMAR_*` items × 3 points = **45 grammar points**, 15 `DIALOGUE_*` items (**15 dialogues**, 2 lines each), 15 `PRACTICE_*` items × 10 = **150 exercises**, 15 warm-ups. (The mismatch is downstream: F03 drops the grammar examples, F13 never feeds the 150 practice questions into the Practice module.)
- **HSK1/HSK2 audio for the sentence corpus exists.** `assets/audio/` contains 500 numeric MP3s whose ids match the Tatoeba recording ids in `sentences_corpus.json` (`1276691`, …); the sentences audio path is the one audio namespace that is real.
- **Dictionary search is parameterized** — F20 is LIKE-wildcard leakage, not SQL injection.
- **Pronunciation analysis service is honest**: no fake 0.85/0.92 scores, `toneAccuracy` null, `unsupported` status when no ASR provider (the defect is only the downstream evidence write, F07).
- **Multiple-choice correct-index mapping is safe**: `MultipleChoiceWidget` renders `definition.options[idx]` and never re-shuffles, so `correctOptionIndex` stays valid (`multiple_choice_widget.dart:25-34`); `getShuffledOptions` has no production caller.
- **Reorder-word scoring composes correctly**: `PracticeSeedCatalog` tokens are a valid permutation; `_normalize` strips punctuation/whitespace from both sides (`practice_scoring_engine.dart:180-184, 350-360`).
- **Reading progress row is single** thanks to `passage_id UNIQUE` (`migration_v4.dart:54-56`); only evidence/activity duplication is wrong (F09).
- **SVG path parser handles all shipped stroke data**: all 24,580 stroke paths in `hanzi_stroke_data.json` use only uppercase `M/Q/L/C/Z` with a single coordinate pair after `M` (verified with Python), so the parser's missing relative-command/arc support is latent, not user-visible.
- **Hanzi geometry engine** (the newer `hanzi/**` module) recomputes median distances with clamped segment projection and guards empty/short strokes; no NaN/point-in-polygon defect found in the shipped data path.
- **Hanzi character dataset**: 2,632 characters, 0 with empty medians/strokes, median count == `stroke_count` for all rows (verified with Python) — the empty-stroke crash path in F04 is not reachable with the shipped asset.

## Additional observations (outside T6 write-scope)

- **Content-pack vocabulary audio URIs are misnamed** (curriculum/vocabulary scope): every word in `hsk1_pack_v1.json` carries e.g. `"audio_uri": "assets/audio/hsk1/你.mp3"`, but the packaged files are numeric Tatoeba ids (`assets/audio/hsk1/1276691.mp3`). `lesson_vocab_view.dart:167-180` plays that URI, so lesson vocabulary audio will fail with the same exception class as F02. Worth a cross-team fix (content pipeline should emit numeric paths or add a mapping).
- `GrammarExerciseGenerator` produces fill-in-the-blank blanks by `text.replaceFirst(targetWord, ...)` after a first-match scan over a fixed particle list (`grammar_exercise_generator.dart:88-133`); if the chosen candidate occurs inside a different word the blank can be misleading. Content-quality risk, not a scoring bug — only reachable if grammar items regain examples (F03 fix), so not separately rated.
- `DesignSystemDemoScreen` (630 lines) is a showcase screen with no scoring/validation logic; `lib/core/theme/**` is styling only — nothing to audit beyond the global theme values used by the modules above.

## Coverage map

Read in full: grammar (repository, models, catalog, evaluation engine, exercise generator, providers, detail/list screens, exercise/rule/contrastive widgets); practice (models, validator, scoring engine, repository, seed catalog, providers, session screen, all 7 widget types); sentences (models, dao, repository, native TTS, audio manager, browser/listening/reading/shadowing screens); hanzi (models, dao, repository, geometry engine, SVG parser, character painter, writing canvas, writing screen, list screen); hanzi_writing (models, stroke bank, evaluator, repository, providers, canvas/controller/painters/toolbar/evaluation sheet); pinyin_foundation (models, repository, 825-line curriculum catalog, exercise engine, all screens, tone chart, providers); reading (models, repository, dao, providers, list/detail screens, questions section, mode selector); listening (models, repository, providers in full, screen in full); pronunciation (models, item bank, analysis service 339 lines, repository, providers, lab screen, result card, waveform); shadowing (models, document bank, evaluator, repository, providers, screen, timeline card); dictionary (models, pinyin helper, repository, providers, screen 585 lines, detail sheet 693 lines, quick sheet); plus the called DAOs, `learning_pipeline_coordinator`, `content_pack_manager` grammar path, migrations v4/v10, `pubspec.yaml`, all shipped assets (counts/types verified programmatically).

Skipped by instruction (no domain logic): `lib/features/design_system/**`, `lib/core/theme/**`.
