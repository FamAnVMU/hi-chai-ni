# T3 — Business Logic Audit

**Auditor:** business-logic (teammate)
**Workspace:** `C:\Users\phama\Downloads\hi_chinese`
**Date:** 2026-11-04
**Mode:** read-only source + asset inspection (no code modified)

---

## Scope summary

Traced real UI → provider/notifier → repository/engine → DAO/SQLite → UI data flow for:

| Area | Files read | Key entry points |
|---|---|---|
| `lib/features/curriculum/**` (25 files, ~4k lines) | all engine/repository/flow files + all 6 lesson-step widgets + syllabus + exit-exam screen | `LessonStudyScreen`, `LessonFlowNotifier`, `MasteryEngine`, `LearningPipelineCoordinator`, `PrerequisiteEngine`, `PlacementUnlockHandler`, `CurriculumRepository` |
| `lib/features/placement_test/**` (17 files) | `cat_engine.dart`, `cat_blueprint.dart`, `cat_item_bank.dart`, `cat_item.dart`, `placement_test_repository.dart`, notifier, flow/intro/result screens, question card | `ActiveCatSessionNotifier.submitAnswer` |
| `lib/features/vocabulary_srs/**` (9 files) | `sm2_engine.dart`, `srs_models.dart`, `srs_repository.dart`, notifier, rating bar, header, review screen | `SrsStudySessionNotifier.submitRating` |
| `lib/features/review/**` | `review_screen.dart` | — |
| `lib/features/learning_pipeline/**` (7 files) | `learning_pipeline_coordinator.dart` (all 790 lines), `mastery_evaluator.dart`, `mastery_state.dart`, `srs_intake_rules.dart`, `learning_evidence.dart` | `recordLessonCompletion` |
| `lib/features/roadmap/**` (10 files) | `adaptive_roadmap_engine.dart`, `roadmap_repository.dart`, `curriculum_catalog.dart`, `roadmap_screen.dart`, `lesson_detail_sheet.dart`, providers | `AdaptiveRoadmapNotifier` |
| `lib/features/home/**` (12 files) | `home_repository.dart` (all 657 lines), `learning_streak.dart`, `home_dashboard_data.dart`, home screen + cards, providers | `HomeDashboardNotifier.build` |
| `lib/features/onboarding/**` (5 files) | `onboarding_providers.dart`, flow screen, personalization screen, intro (placement integration) | `completePersonalization`, `completePlacementTest` |
| `lib/features/learning/**` | `learning_screen.dart` | curriculum banner + lesson cards |
| Data | `assets/data/content_packs/hsk1/hsk1_pack_v1.json`, `.../hsk2/...`, `assets/data/hsk_seed_fixture_v2.json`, `hi_chinese_dev.db` schema via migrations | counted with PowerShell JSON queries (read-only) |

Supporting files read because they are on the traced chain: `core/database/dao/curriculum_dao.dart`, `mastery_dao.dart`, `core/database/migrations/migration_v9.dart`, `migration_v5.dart`, `core/utils/app_clock.dart`, `core/startup/app_startup_provider.dart`, `core/router/app_router.dart`, `features/app_shell/...`, `features/content_packs/data/content_pack_manager.dart`, `core/knowledge/.../unified_knowledge_service.dart`.

---

## Top 5 priority order

1. **T3-F01 (Critical)** — the 6th lesson step (`mastery_check`) points to content items that do not exist in either shipped pack → the completion gate is unreachable → **no lesson can ever be completed** through the normal UI; the curriculum permanently stops at lesson 1.
2. **T3-F02 (Critical)** — every answer key in the shipped data is the first option (150/150 lesson exercises, 40/40 exit-exam questions, 150/150 HSK2) → the “≥80 % to unlock” and “≥120/200 to pass” rules are trivially bypassed by always tapping option A.
3. **T3-F03 (Critical)** — CAT placement terminates after exactly 12 responses when a skill runs out of items (reading has only 3) → listening, writing and speaking are **never assessed** on the default path, while a learner who answers 3 reading questions wrong gets a different test shape.
4. **T3-F09 (High)** — the adaptive roadmap and the curriculum use two different progress tables; `lesson_progress` is written only by the roadmap’s start/skip and `completeLesson` is never invoked → the adaptive roadmap can never progress, and “Bỏ qua” loops forever.
5. **T3-F08 (High)** — the HSK exit exam is reachable with zero prerequisites, unlimited retries, full answer key shown after each attempt, and passing auto-credits every lesson of the level → the whole level can be skipped without studying.

---

## Architecture / split-brain observations

The app maintains **four overlapping notions of “progress”** that are not synchronised:

| Concept | Written by | Read by | Problem |
|---|---|---|---|
| `curriculum_lessons.status` / `is_locked` / `credits` | `LearningPipelineCoordinator` (only after `MasteryEngine.submitPractice`), `PlacementUnlockHandler`, seed import | `LearningScreen` lesson cards, `CurriculumSyllabusScreen`, `PrerequisiteEngine` (dead code) | Only the pipeline can flip a lock, and that path is unreachable (F01). Placement/exit-exam can mass-credit it. |
| `curriculum_mastery` (item_id/score/mastery_state) | Pipeline (lessons & vocab), `CurriculumRepository.recordExitExamSubmission`, `PlacementUnlockHandler`, `UnifiedKnowledgeService` | `CurriculumRepository.getUnitsWithLessons` (score only), `PrerequisiteEngine` (dead), `getMasterySummary` | 3 writers with 3 different `score` scales/states (`completed`, `mastered`, `failed`, `unstable`, 0..1 %). The lesson view shows a “mastery %” derived from `score` but nothing consumes it consistently. |
| `lesson_progress` | `DefaultRoadmapRepository.startLesson/skipLesson` (never `completeLesson`) | `DefaultRoadmapRepository.getLessonProgressMap` → AdaptiveRoadmapEngine | Curriculum completions are **never** written here. Roadmap is permanently empty / first-lesson-only. |
| `learner_evidence` / `learning_activities` | Pipeline, SRS, exit exam, placement, home logger | Home streak/stats, roadmap recent evidence | Used as a shadow progress log; streak/stats re-derive from it; the two sources are de-duplicated with a fragile 2-second heuristic. |

Additional split-brain details:

- **Two curricula**: `CurriculumCatalog` (static, 6 HSK1 lessons with IDs `LES_HSK1_01_TONES`…) is what the roadmap shows; the content packs create 15 lessons per level with IDs `lesson_1_1`… A one-way `_catalogAliases` map in `CurriculumCatalog` bridges a few IDs, but roadmap progress rows are keyed to catalog IDs while curriculum completion is keyed to pack IDs — they can never meet.
- **Two “mastery” vocabularies**: `MasteryState` enum uses `unseen/exposed/learning/unstable/familiar/mastered`, while the curriculum tables write `not_started/in_progress/completed/mastered/failed`, and `StreakCalculator`/home uses yet another status set.
- **Two “current level” sources**: `user_profiles.current_hsk_level` (used by Home, SRS, Learning tab) vs `learner_goals.target_hsk_level` (used by the AdaptiveRoadmapEngine) vs `app_settings['starting_hsk_level']` (onboarding). A re-placement outside onboarding updates only the last/curriculum, so SRS/Home keep filtering on the old level.
- **Route guard**: `AppRouteGuard` is only consulted by `onGenerateRoute`, while `MaterialApp.home` is `AppShell` (which gates onboarding itself). Deep links to named routes are gated, but in-app `Navigator.push(MaterialPageRoute(...))` calls (lesson screen, exit exam) are not — the only gate is the `is_locked` column.

---

## README/docs claims verified

| Claim (README line) | Actual implementation / data | Verdict |
|---|---|---|
| 15 HSK-1 lessons, sequential (L22) | HSK1 pack: 3 units × 5 lessons = **15**; each chained by `prerequisites`; seed locks 2..15 | ✅ count matches |
| 150 core unique words with pinyin/meaning/example (L22) | Pack: 15 vocabulary content items × 10 `words` = **150, 150 unique**, 0 missing meanings; seed fixture HSK1 = 150 | ✅ matches |
| 45 grammar points (L22) | Pack contains **45 point objects** but only **17 unique titles**; 15 are template filler `Điểm 1: Cấu trúc sử dụng với "<word>"` with the same nonsensical “structure” `Chủ ngữ + <word> + Tân ngữ/Vị ngữ`, and the other 2 generic points repeat in every lesson | ⚠️ count matches, content is synthetic/duplicated — claim misleading |
| 15 dialogues (L22) | Pack: 15 `dialogue` items × 2 `lines` = 30 lines | ✅ count matches (but UI renders them blank — F11) |
| 150 deterministic exercises with explanations (L22) | Pack: 15 × 10 = **150 exercises**, 100 % have `correct_answer`, but **150/150 correct answers are `options[0]`** | ⚠️ count matches, answer key position-correlated — gate bypassable (F02) |
| Lessons unlock only when previous ≥ 80 % (L25) | Threshold is `0.8` inclusive in `AdaptiveExerciseSampler`/pipeline; HOWEVER completion gate is unreachable (F01) and, if reached, all answers are A (F02) | ❌ logic present, effective gating broken |
| Tracks 5 mastery states (L25) | `MasteryState` enum has **6** states (`unseen, exposed, learning, unstable, familiar, mastered`) + legacy mappings. | ❌ mismatch (5 vs 6) |
| CAT placement auto-detects level and auto-credits previous lessons (L26) | Exists (`CatEngine`, `PlacementUnlockHandler.creditLessonsUpToLevel`) but engine truncates at 12 items (F03), answer key is position-correlated (F02), listening audio is fake (F04), speaking auto-passes (F05) | ⚠️ present but unsound |
| Exit exam: 35 min, 20 listening + 20 reading, 200-point scale, pass ≥ 120 (L27) | 20+20 questions, each correct = 5 points → 200 max, pass = 120 (60 %) in `LevelExitExamScreen`. **No timer at all**; `duration_minutes` only displayed; every attempt is recorded as `35*60` seconds (F07). Correct answers all option 0 (F02). Exam has no prerequisite gate (F08). | ⚠️ math/format matches, exam-room claims false |
| Personalized 3-step onboarding (API key, placement, personalization) (L26/README banner) | Wizard exists and persists 9 preference keys, but only `show_pinyin` and `speech_rate` are ever read (settings screen); focus skill, purpose, learning method, pinyin position, script type, reminder flag/time are write-only (F18) | ⚠️ UI exists, personalization not applied |
| HSK 1–6 roadmap (README) | `CurriculumCatalog` has levels 0,1,2 only; `getLevel()` falls back to level 0 (Pinyin) for 3–5; Learning tab chips are `HSK 1..5` (no 6) | ❌ roadmap only real for HSK1/2 and incomplete |

Asset counts were produced read-only with `ConvertFrom-Json` over the pack files; commands are reproducible from the verification notes in each finding.

---

# Findings

## [T3-F01] Lesson completion is unreachable: `mastery_check` segments reference content items that do not exist

- **Severity:** Critical
- **Confidence:** CONFIRMED
- **Location:** `assets/data/content_packs/hsk1/hsk1_pack_v1.json:1` (single-line JSON, segment `content_ref_id: MASTERY_L1`), `assets/data/content_packs/hsk2/hsk2_pack_v1.json:1`; consumer `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:35`, `lib/features/curriculum/presentation/screens/lesson_study_screen.dart:99`
- **Evidence:** every `mastery_check` segment points to a knowledge item that the pack never defines:

```json
{"id": "lesson_1_1", ..., "segments": [
  {"segment_type":"warmup",       "content_ref_id":"WARMUP_L1"},
  {"segment_type":"vocabulary",   "content_ref_id":"VOCAB_L1"},
  {"segment_type":"grammar",      "content_ref_id":"GRAMMAR_L1"},
  {"segment_type":"dialogue",     "content_ref_id":"DIALOGUE_L1"},
  {"segment_type":"practice",     "content_ref_id":"PRACTICE_L1"},
  {"segment_type":"mastery_check","content_ref_id":"MASTERY_L1"}   // ← no such content_item
]}
```

Counted contents: `content_items=75` = 15 warmup + 15 vocabulary + 15 grammar + 15 dialogue + 15 exercise. `MASTERY_L*` (HSK1) and `MASTERY_L2_*` (HSK2) are absent: **15/15 missing in hsk1 and 15/15 in hsk2** (PowerShell: `mastery segments=15 missing content items=15` for each pack).

`CurriculumDao.getSegmentsByLessonId` LEFT JOINs the catalogue, so `contentPayload` becomes `null`:

```dart
// lib/core/database/dao/curriculum_dao.dart:145
Future<List<Map<String, dynamic>>> getSegmentsByLessonId(String lessonId) async {
  return _db.rawQuery('''
    SELECT ls.*, ci.content_json AS content_payload
    FROM ${DatabaseConstants.tableLessonSegments} ls
    LEFT JOIN ${DatabaseConstants.tableContentItems} ci ON ls.content_ref_id = ci.content_id
    WHERE ls.lesson_id = ?
    ORDER BY ls.step_order ASC
  ''', [lessonId]);
}
```

The mastery widget then drops into its “empty” branch:

```dart
// lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:35
final rawExercises = (widget.segment?.contentPayload?['exercises'] as List<dynamic>?) ??
    (widget.segment?.contentPayload?['questions'] as List<dynamic>?) ??
    [];
final exercises = rawExercises.whereType<Map<String, dynamic>>().toList();

if (exercises.isEmpty) {
  return LessonContentEmptyState(
    title: 'Đánh giá hoàn thành đang được chuẩn bị',
    ...
    buttonText: 'Hoàn thành bài học',
    onAction: widget.onFinishLesson,
```

and the button is wired only to a pop:

```dart
// lib/features/curriculum/presentation/screens/lesson_study_screen.dart:99
case 5:
  return LessonMasteryView(
    lesson: widget.lesson,
    segment: _getSegment('masteryCheck'),
    ...
    onSubmit: (questions) => flowNotifier.submitPractice(questions),
    onFinishLesson: () => Navigator.of(context).pop(true),
```

- **Root cause:** the pack generator emitted a `mastery_check` segment for the 6th step but no matching content item. The ONLY code path that records a lesson completion is `LessonMasteryView.onSubmit → LessonFlowNotifier.submitPractice → MasteryEngine.recordLessonAttempt → LearningPipelineCoordinator.recordLessonCompletion` (grep: `recordLessonCompletion` has exactly one caller — `mastery_engine.dart:37`; `submitPractice` exactly one caller — `lesson_study_screen.dart:104`). With `exercises.isEmpty` the submit callback is never invoked, so `curriculum_lessons.status` is never set to `completed`, `is_locked` of lesson N+1 is never cleared, and no SRS intake/evidence happens. `onFinishLesson` merely pops with `true`, which callers ignore (`learning_screen.dart:664-666` only invalidates a provider).
- **Impact (user-visible):** A learner can read all 15 lessons’ warm-up/vocabulary/grammar/dialogue/practice, answer the 10 practice questions, reach step 6 — and get “Đánh giá hoàn thành đang được chuẩn bị” + a “Hoàn thành bài học” button. Tapping it returns to the list where the lesson still says “Bắt đầu”/“Chưa học” and **lesson 2 stays locked**. The 15-lesson sequential curriculum cannot be progressed at all in a fresh install. (The practice step’s answers are also discarded — see F12.) This also means the README’s core “6-chặng” learning flow is non-functional.
- **Fix:** generate/insert the missing mastery content items at pack-build time, e.g. `MASTERY_L1` with `{"exercises": <the same 10 exercises as PRACTICE_L1>}`, and add a startup-integrity/import validator that fails loudly when `lesson_segments.content_ref_id` has no `content_items` row. Defensive code fix: in `LessonMasteryView`’s empty branch, fall back to the practice segment and/or call `onSubmit([])` so the pipeline at least records an attempt; and in `LessonStudyScreen`, do not offer a “finish” button that records nothing:

```dart
if (exercises.isEmpty) {
  // fall back to practice content rather than silently finishing
  final fallback = (widget.segment?.contentPayload?['exercises'] as List<dynamic>?) ?? const [];
  if (fallback.isEmpty) {
    // block, show data-integrity message, do NOT pop "successfully"
  }
}
```
- **Verification status:** Full chain traced: screen → `_getSegment('masteryCheck')` → `CurriculumDao.getSegmentsByLessonId` (payload null) → empty-state → `Navigator.pop(true)`; confirmed no other caller of `recordLessonCompletion`/`submitPractice` with grep; cross-checked both pack JSONs (15 missing refs each) and the import path (`content_pack_manager.dart:354-377` writes `content_ref_id` verbatim).

---

## [T3-F02] Every shipped answer key is the first option → 80 % gate and 200-point exam are trivially bypassable

- **Severity:** Critical
- **Confidence:** CONFIRMED
- **Location:** `assets/data/content_packs/hsk1/hsk1_pack_v1.json:1`, `assets/data/content_packs/hsk2/hsk2_pack_v1.json:1`; scoring code `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:265`, `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:207`, `lib/features/curriculum/presentation/widgets/lesson_practice_view.dart:143`
- **Evidence:** a full scan of the packs shows the correct answer is `options[0]` in every single item:

```text
HSK1 exercises: 150 total, correct answer at index 0: 150
HSK2 exercises: 150 total, correct answer at index 0: 150
HSK1 exit exam: 40 total (20 listening + 20 reading), 3 options each, correct at index 0: 40
```

Example (extracted from pack JSON, reformatted):

```json
{
  "id": "ex_1_1", "type": "multiple_choice", "skill_type": "reading",
  "prompt": "Từ \"你\" (nǐ) có nghĩa là gì?",
  "options": ["bạn, anh, chị (đại từ ngôi 2)", "xin lỗi", "không có gì, đừng khách sáo"],
  "correct_answer": "bạn, anh, chị (đại từ ngôi 2)"
}
```

Scoring is a pure string compare against the chosen option text — position-sensitive because the data correlates position with correctness:

```dart
// lesson_mastery_view.dart:265
final isCorrect = userAns != null &&
    userAns.trim().toLowerCase() ==
        (ex['correct_answer']?.toString() ?? '').trim().toLowerCase();
...
setState(() {
  _correctCount = correct;
  _scorePercent = exercises.isNotEmpty ? correct / exercises.length : 0.0;
  _isSubmitted = true;
});
```

and in the pipeline evaluator:

```dart
// adaptive_exercise_sampler.dart:85
if (expected != null && given != null && expected.toLowerCase() == given.toLowerCase()) {
  correct++;
```

- **Root cause:** pack generation did not shuffle options; it emits correct answer first for every question. Since scoring compares the option text (not letters), a learner (or a scripted tap) that always selects the first option scores 100 %.
- **Impact (user-visible):**
  - The lesson mastery check (10 questions) would always report 100 % → pass ≥ 80 % → unlock next lesson (once F01 is fixed).
  - The exit exam: 40 × 5 = 200/200, always `isPassed = totalPoints >= 120` → “XUẤT SẮC ĐẠT CHUẨN ĐẦU RA!”, which then mass-credits all lessons in the level and unlocks the next level (F08). Learners can skip the entire curriculum by tapping the first option 40 times, without understanding Chinese.
  - All HSK2 exercises/exit exam have the same defect.
- **Fix:** shuffle options at pack-build time (deterministically per item, storing the answer by ID/key not position), and add a pack validation rule that rejects any pack where `correct_answer == options[0]` for more than, say, 40 % of items. Also validate answer distribution on import in `ContentPackManager`. Long-term: store an `answer_key` index independent of option order and randomize display order at render time:

```dart
// example: at import time
assert(answerIndexDistribution(options, correct) is not pathologically skewed);
```
- **Verification status:** counted every exercise in both packs and every exit-exam question with a JSON parse; correlated with the three consumer scoring sites (`lesson_mastery_view`, `lesson_practice_view`, `level_exit_exam_screen`). Note: lesson mastery path currently unreachable due to F01, exit-exam path is reachable from the syllabus today.

---

## [T3-F03] CAT placement stops after ~12 items when a skill runs out of items — half the skills are never assessed

- **Severity:** Critical
- **Confidence:** CONFIRMED
- **Location:** `lib/features/placement_test/domain/engine/cat_engine.dart:195`
- **Evidence:**

```dart
// cat_engine.dart:195
if (nextItem == null) {
  // Skill items exhausted early -> advance to next skill
  final nextSkill = _findNextSkill(currentSkill, blueprint: activeBlueprint);
  if (nextSkill == null || updatedResponses.length >= activeBlueprint.minTotalItems) {
    final finalResult = generateAssessmentResult(          // <-- completes the whole test
      sessionId: currentState.sessionId,
      overallTheta: newTheta,
      overallStandardError: newSe,
      responses: updatedResponses,
      completedAt: DateTime.now().toUtc(),
      blueprintVersion: activeBlueprint.version,
    );
    return currentState.copyWith(status: 'completed', isCompleted: true, ...);
  }
  return currentState.copyWith(currentSkill: nextSkill, ...);
}
```

Blueprint: `minItemsPerSkill = 2`, `maxItemsPerSkill = 5`, `minTotalItems = 12`, `maxTotalItems = 30` (`cat_blueprint.dart:29-45`). Item bank counts per skill: vocabulary **5**, grammar **4**, reading **3**, listening 8, writing 9, speaking 2. Happy path: vocabulary consumes 5 (max per skill) → grammar exhausts after 4 (total 9 < 12 → correctly advances) → reading exhausts after only 3 → total = **12 ≥ minTotalItems 12 → the entire test completes**.

- **Root cause:** the “skill exhausted” branch reuses `minTotalItems` (a minimum-completion guard) as a termination condition. It should only complete when `nextSkill == null` or `responses >= maxTotalItems`; otherwise advance. Because reading has fewer items (3) than `maxItemsPerSkill` (5), normal learners hit it. (Learners who fail 3 reading questions in a row take the other branch and advance to listening, so two learners get different test shapes.)
- **Impact (user-visible):** the placement report says “Chưa đánh giá” for **Listening, Writing and Speaking** on the normal path; the radar card shows 3 of 6 skills unassessed; overall theta is estimated from vocabulary/grammar/reading only; `shouldBypassPinyinFoundation` (which reads speaking/writing) can never be satisfied; the README’s “CAT across 6 skills” is false. It also means the “12–20 câu” promise in the intro is wrong (exactly 12).
- **Fix:**

```dart
if (nextItem == null) {
  final nextSkill = _findNextSkill(currentSkill, blueprint: activeBlueprint);
  if (nextSkill == null || updatedResponses.length >= activeBlueprint.maxTotalItems) {
    // complete only when no next skill or hard cap
  }
  // otherwise advance regardless of responses.length
}
```
and expand the reading bank to ≥ `maxItemsPerSkill` items (currently 3) so per-skill caps are meaningful.
- **Verification status:** traced `processTurn` for all branches; computed response counts against the actual item bank (IDs counted: VOCAB 5, GRAM 4, READ 3, TONE/PIN/LIST 8, PIC/WRIT 9, SPK 2); top-level `CatProgressHeader`/result screen render unassessed skills exactly as `generateAssessmentResult` produces them. Reproduced the arithmetic (5+4+3=12) against `CatBlueprint.minTotalItems`.

---

## [T3-F04] Placement “listening” section has no audio; prompts contain the answer

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/placement_test/presentation/widgets/cat_question_card.dart:95` (snackbar stub at :100-105), item bank `lib/features/placement_test/domain/engine/cat_item_bank.dart:316`
- **Evidence:**

```dart
// cat_question_card.dart:96
IconButton.filled(
  icon: const Icon(Icons.volume_up_rounded),
  tooltip: 'Nghe lại phát âm',
  onPressed: () {
    // Audio trigger (handled via AudioService / TTS)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang phát âm thanh bài kiểm tra...'),
        duration: Duration(seconds: 1),
      ),
    );
  },
),
```

and the “listening” prompts embed the transliteration/answer:

```dart
// cat_item_bank.dart:316
CatItem(
  id: 'LIST_001',
  skill: CatSkill.listening,
  type: CatItemType.audioListeningChoice,
  difficulty: -1.7,
  ...
  prompt: 'Nghe phát âm và chọn nghĩa tiếng Việt của từ: [Audio: 谢谢 (xièxie)]',
  audioUri: 'assets/audio/hsk1/xiexie.mp3',
  options: ['Cảm ơn', 'Tạm biệt', 'Xin lỗi', 'Xin chào'],
  correctOptionIndex: 0,
```

Every listening item follows this pattern (`[Audio: mā - mà] …`, `[Audio: nǐ] …`); the answer or its pinyin is printed in the prompt, and the audio button is a snackbar stub (no `AudioPlayerService` in this widget at all).
- **Root cause:** audio playback was never wired into `CatQuestionCard`; the button is a placeholder. The prompt text was authored as if audio were the only channel but includes the literal answer to compensate.
- **Impact (user-visible):** no sound is ever played during the placement test; learners with zero listening ability can answer by reading the prompt (e.g. “谢谢 (xièxie)” vs option “Cảm ơn”). The CAT therefore measures reading, not listening; listening mastery ≈ 100 % for readers, distorting theta and the recommended HSK level. It also contradicts the “CAT 6 kỹ năng” claim.
- **Fix:** inject `AudioPlayerService`/`TtsService` (same pattern as `lesson_vocab_view.dart:92-133`) and hide the pinyin from the prompt; the prompt should be neutral (“Nghe và chọn nghĩa đúng”), with the text shown only after the answer is submitted (and even then only in the review card). Add a widget/integration test that asserts `play()` is invoked and the prompt does not contain the answer.
- **Verification status:** grepped every `Audio*` reference in `placement_test/` — only the snackbar; verified all 8 listening items contain the answer text/pinyin in the prompt; `CatItem.audioUri` is never consumed by the flow screen.

---

## [T3-F05] Placement speaking questions auto-pass on any tap

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/placement_test/presentation/widgets/cat_question_card.dart:233` (literal submitted at :239), `lib/features/placement_test/domain/models/cat_item.dart:128`
- **Evidence:**

```dart
// cat_question_card.dart:233
onPressed: _isSpeakingSimulated
    ? null
    : () {
        setState(() => _isSpeakingSimulated = true);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            widget.onAnswerSubmitted('speech_sample_recorded');   // literal string
          }
        });
      },
```

```dart
// cat_item.dart:128
// 4. String transcript or evaluation indicator
if (answer is String) {
  final trimmed = answer.trim().toLowerCase();
  if (trimmed == 'true' ||
      trimmed == 'correct' ||
      trimmed == 'passed' ||
      trimmed == 'speech_sample_recorded') {
    return true;                                              // unconditional pass
  }
```

- **Root cause:** a “simulated recording” placeholder is treated as a verified correct answer by `CatItem.checkAnswer`; no microphone capture, no pronunciation assessment, no score is passed to the engine.
- **Impact (user-visible):** every learner who taps “Bắt đầu phát âm” twice (the bank has exactly 2 speaking items, which equals `minItemsPerSkill=2`) gets 100 % on speaking. That adds 2 correct responses to the theta update (bounded ±0.6 each → up to +1.2 ability), pushes the HSK band up, and marks “Nói & Phát âm” assessed at 100 % accuracy. The report the learner sees is wrong; a mute learner can be placed above a speaking learner.
- **Fix:** remove the fake branch; require the pronunciation service to return an actual score (`num` 0..1) and pass that to `onAnswerSubmitted`; treat the speaking skill as `unassessed` if the mic/permission/assessment is unavailable (the domain already supports unassessed). At minimum, remove the `'speech_sample_recorded'` special case from `checkAnswer`.
- **Verification status:** traced card → provider `submitAnswer(answer)` → `engine.processTurn` → `activeItem.checkAnswer(userAnswer)` → `CatResponseRecord(isCorrect: true)`; confirmed both speaking items are `CatItemType.speakingPrompt` and the blueprint’s last skill has exactly 2 bank items.

---

## [T3-F06] Placement test double-tap / rapid replay race duplicates responses and double-updates theta

- **Severity:** High
- **Confidence:** LIKELY
- **Location:** `lib/features/placement_test/presentation/providers/placement_test_providers.dart:30`, `lib/features/placement_test/presentation/widgets/cat_question_card.dart:130`
- **Evidence:** the notifier has no in-flight guard; every call reads the same pre-await session:

```dart
// placement_test_providers.dart:30
Future<void> submitAnswer(dynamic answer, {int latencyMs = 1500}) async {
  final current = state.value;
  if (current == null || current.activeItem == null || current.isCompleted) {
    return;
  }
  final repo = ref.read(placementTestRepositoryProvider);
  final engine = repo.engine;

  // 1. Process turn via IRT CAT algorithm
  final nextState = engine.processTurn(currentState: current, userAnswer: answer, latencyMs: latencyMs);

  // 2. Persist turn response in SQLite
  final lastResponse = nextState.responses.last;
  await repo.saveTurnResponse(...);
  ...
  state = AsyncValue.data(nextState);
}
```

and the card submits on every tap without disabling:

```dart
// cat_question_card.dart:129
onTap: () {
  setState(() => _selectedOptionIndex = index);
  widget.onAnswerSubmitted(index);
},
```

- **Root cause:** neither the widget nor the notifier locks the current item while the async turn is in flight (`saveTurnResponse` opens a transaction, so the gap is milliseconds to tens of ms). A fast double-tap (or a tap during a rebuild) calls `processTurn` twice on the same `currentState`: two `CatResponseRecord`s for the same `item_id` are appended, `skillItemCounts[currentSkill]` is incremented twice, theta is moved twice, and `insert ... conflictAlgorithm.replace` in `saveTurnResponse` only dedupes by `id` (which includes `microsecondsSinceEpoch`, so both rows are stored). Compare the SRS side which does have an in-flight guard (`srs_repository.dart:106-122`).
- **Impact (user-visible):** the learner answers one question but their ability estimate changes twice; the persisted session contains duplicate responses; progress header can skip a number; results are irreproducible. On a slow device this is easy to trigger accidentally.
- **Fix:** add `bool _isSubmitting` to `ActiveCatSessionNotifier` (or key on `current.activeItem?.id`), ignore submits while in-flight, and disable taps:

```dart
Future<void> submitAnswer(dynamic answer, {int latencyMs = 1500}) async {
  if (_inFlight) return;
  _inFlight = true;
  try { ... } finally { _inFlight = false; }
}
```
and in `CatQuestionCard`, use `onTap: _isSubmitting ? null : ...`. Also add a unique constraint `(session_id, item_id)` on `placement_test_responses` to harden at the storage layer.
- **Verification status:** call chain read; no debounce/in-flight flag found anywhere in the placement feature (grepped `isProcessing|_inFlight|isSubmitting` — only SRS has one); `saveTurnResponse` persists both rows because the response id embeds `microsecondsSinceEpoch` (`cat_session_state.dart:37-52`). Marked LIKELY because timing must overlap (not reproduced on a device).

---

## [T3-F07] Exit exam has no timer; every attempt is recorded as 35 minutes of study

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:40`, `:202`, `:242`
- **Evidence:** the “35-minute exam room” only renders a static string, and submission hardcodes the full duration:

```dart
// level_exit_exam_screen.dart:40
static const int _totalScore = 200;
int _passingScore = 120; // 60% standard
int _durationMinutes = 35;
String _title = '';

// :377 (header)
Text(
  '$_durationMinutes:00',
  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlueDark),
),

// :242 (submit)
await repo.recordExitExamSubmission(
  hskLevel: levelNum,
  score: totalPoints,
  totalScore: _totalScore,
  listenScore: listenPoints,
  readScore: readPoints,
  isPassed: isPassed,
  durationSeconds: _durationMinutes * 60,   // always 2100 s
  itemsCount: _questions.length,
);
```

`grep "Timer|countdown|elapsed|remaining"` in the file: **no matches** — there is no countdown, no auto-submit, no elapsed tracking.
- **Root cause:** the timer was never implemented; the repo API takes `durationSeconds` but the UI passes the nominal exam length.
- **Impact (user-visible):** (a) learners can take unlimited time despite the “35 phút” label; (b) each attempt inserts a `learning_activities` row with `duration_seconds = 2100`, so Home “Hôm nay”/“Tuần”/“Tổng” study time jumps +35 min for a 60-second attempt, the daily-minutes goal is instantly met and the streak counts an activity that may never have happened; (c) `learner_evidence.duration_ms = 2_100_000` corrupts analytics. A failed attempt also banks 35 minutes.
- **Fix:** add a `Stopwatch` started in `initState`/when the first page shows and pass actual `elapsed.inSeconds` into `recordExitExamSubmission`; add a `Timer.periodic` that decrements the header and auto-submits at 0. Also clamp `durationSeconds` to `<= duration_minutes*60` in the repository.
- **Verification status:** full file read (659 lines) — only display of duration; repo function `recordExitExamSubmission` writes `duration_seconds` straight into `learning_activities` (`curriculum_repository.dart:181-193`); HomeRepository counts all durations (see F16/F30).

---

## [T3-F08] HSK exit exam is ungated, retry-unlimited, shows the answer key, and auto-credits the whole level

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart:95`, `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:594`, `lib/features/curriculum/data/curriculum_repository.dart:219`, `lib/features/curriculum/data/placement_unlock_handler.dart:29`
- **Evidence:** the “Thi ngay” banner is always enabled, with no check of lesson statuses:

```dart
// curriculum_syllabus_screen.dart:95
HiButton(
  text: 'Thi ngay',
  size: HiButtonSize.sm,
  variant: HiButtonVariant.primary,
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LevelExitExamScreen(),
      ),
    );
  },
),
```

After each submission the full review with correct answers is rendered (`_buildReviewCard`: “Đáp án đúng: $correctAnswer” + explanation), and retakes are unrestricted; passing then credits the level:

```dart
// curriculum_repository.dart:219
// 4. If passed, unlock next level
if (isPassed) {
  try {
    final unlockHandler = PlacementUnlockHandler(executor);
    await unlockHandler.unlockForRecommendedLevel(
      hskLevel + 1,
      startingLessonOrder: 1,
    );
  } catch (_) {}
}
```

```dart
// placement_unlock_handler.dart:29
for (final lesson in allLessons) {
  final lessonId = lesson['id'] as String;
  final orderIndex = (lesson['order_index'] as num).toInt();
  final existingStatus = lesson['status'] as String?;

  if (orderIndex < targetLessonOrder) {
    if (existingStatus == 'completed') { continue; }
    await _curriculumDao.updateLessonStatus(lessonId, status: 'completed', isLocked: 0, completedAt: nowIso, creditedReason: 'credited_by_placement_test');
    await _masteryDao.upsertMastery({ ... 'mastery_state': 'completed', 'score': 1.0, ... });
```

`unlockForRecommendedLevel(2)` first credits **all** HSK1 lessons (`targetLessonOrder: 999999`) and then unlocks HSK2 lesson 1.
- **Root cause:** no attempt gate (no prior-lesson check, no attempt limit/cooldown, no shuffle — F02), plus answer keys are revealed immediately, plus the pass handler treats the whole level as mastered.
- **Impact (user-visible):** a first-day learner can open HSK1 syllabus → “Thi ngay” → tap the first option 40 times (F02) → 200/200 → the app credits all 15 HSK1 lessons with score 1.0 (`credited_by_placement_test`) and unlocks HSK2 lesson 1, bypassing the entire 15-lesson curriculum and its 80 % gate. Retries also overwrite legitimate study scores with 1.0/skip re-crediting logic. This directly defeats the README’s conditional unlock design.
- **Fix:** gate the exam on curriculum state (e.g. all/most lessons completed OR at least 80 % of lessons completed) both in UI and in `CurriculumRepository.recordExitExamSubmission` (server-side-style check inside the transaction), limit attempts (e.g. 1 free retry per day / 3 total) and shuffle + key-hide until final submission. When passing, do not blanket-overwrite mastery scores; keep the highest score per lesson.
- **Verification status:** traced syllabus button → screen → repository → handler → DAO/mastery; verified `LevelExitExamScreen` has no level precheck; verified reviewer renders correct answers (`level_exit_exam_screen.dart:594-657`); verified packing of credited rows (`placement_unlock_handler.dart:35-60`).

---

## [T3-F09] Split-brain roadmap: `lesson_progress` is never written by the learning flow, and `completeLesson` is dead → adaptive roadmap cannot progress

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/roadmap/data/roadmap_repository.dart:75`, `:146`, `lib/features/roadmap/presentation/widgets/lesson_detail_sheet.dart:12`, `lib/features/roadmap/presentation/screens/roadmap_screen.dart:546`
- **Evidence:** the roadmap engine’s only progress source is `lesson_progress`:

```dart
// roadmap_repository.dart:75
Future<Map<String, LessonProgress>> getLessonProgressMap() async {
  final rows = await _db.query(DatabaseConstants.tableLessonProgress);
  ...
}
```

but grep over `lib/` for `tableLessonProgress` shows exactly one writer — the roadmap repository itself (`startLesson`, `skipLesson`, plus `completeLesson` which is never called). The curriculum pipeline writes `curriculum_lessons`/`curriculum_mastery` only. `completeLesson` is handed to the sheet but never invoked:

```dart
// roadmap_screen.dart:546
onComplete: (score) async {
  await ref.read(adaptiveRoadmapProvider.notifier).completeLesson(
        lessonId: lesson.id,
        score: score,
      );
},
```
```dart
// lesson_detail_sheet.dart:12 / 21 / 31 / 43 — declared, passed, stored… never called
final ValueChanged<double> onComplete;
...
onComplete: onComplete,
```
The sheet’s only actions are “Bắt đầu học” and “Bỏ qua” (`lesson_detail_sheet.dart:275-309`); grep of the file for `onComplete(` returns no call site.

- **Root cause:** two parallel progress systems were built and never bridged. `startLesson`/`skipLesson` write `lesson_progress`; the curriculum pipeline writes `curriculum_lessons`. There is no listener/sync; the alias map (`KnowledgeIdentityRegistry` + `_catalogAliases`) only renames keys, it doesn’t copy rows.
- **Impact (user-visible):** completing (or even mass-crediting via placement) lessons in the grammar curriculum has zero effect on the “Lộ trình thích ứng” tab. Because prerequisites require `LessonProgress.isCompleted` (`adaptive_roadmap_engine.dart:49-52`) and only skipped/inProgress rows ever exist, the roadmap shows at most the first not-skipped lesson as available and every other lesson as “Đang khóa (Chưa đạt tiên quyết)” forever. “Bỏ qua” sets `status: skipped` (not completed) so it does not even satisfy the precondition for the next lesson — the button is a dead end that visually marks the lesson.
- **Fix:** single source of truth. Either (a) make `DefaultRoadmapRepository.getLessonProgressMap()` derive from `curriculum_lessons` + `curriculum_mastery` (with alias normalisation), or (b) have `LearningPipelineCoordinator` upsert `lesson_progress` in the same transaction (and delete the roadmap’s private writers). Remove `skipLesson` or make it call the same pipeline. Add a repository contract test: after `recordLessonCompletion(lesson_1_1, 0.9)`, `getLessonProgressMap()` must contain `lesson_1_1` completed.
- **Verification status:** grep of `tableLessonProgress` across `lib/` (11 hits: migration, constants, data-management reset, roadmap repository ×6, and no other writer); grep of `onComplete` across `lib/` (only declaration/passing, never invoked); engine prerequisite code read; course completion writes `curriculum_lessons.status` only (`learning_pipeline_coordinator.dart:72-80`).

---

## [T3-F10] Roadmap catalog is hardcoded and disconnected from content packs: 6 of 15 HSK1 lessons, wrong IDs, Pinyin fallback for HSK3-5

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/roadmap/domain/catalog/curriculum_catalog.dart:198`, `:7-196`, `lib/features/roadmap/data/roadmap_repository.dart:319`
- **Evidence:** the engine works on a static catalog, not the DB:

```dart
// curriculum_catalog.dart:198
static CurriculumLevel getLevel(int level) {
  return levels.firstWhere(
    (l) => l.level == level,
    orElse: () => levels.first,      // HSK3/4/5 silently fall back to level 0 (Pinyin)
  );
}
```

The catalog defines only: level 0 = 2 Pinyin lessons; level 1 = **6** lessons (`LES_HSK1_01_TONES`…`LES_HSK1_06_SHADOWING_GREETING`); level 2 = **2** lessons (`LES_HSK2_01_RESTAURANT_VOCAB`, `LES_HSK2_02_READING_ORDERING`). The actual HSK1/2 packs have 15 lessons each with IDs `lesson_1_1` … `lesson_2_15`. The handler only has aliases for 6 HSK1 IDs and 3 HSK2 IDs:

```dart
// curriculum_catalog.dart:205
static const Map<String, String> _catalogAliases = {
  'lesson_1_1': 'LES_HSK1_01_TONES',
  'lesson_1_2': 'LES_HSK1_02_WRITING_BASICS',
  ...
```
and the engine is fed the goal level, not the selected UI level:

```dart
// roadmap_repository.dart:320
final context = AdaptiveRoadmapContext(
  goal: goal,
  currentLevel: goal.targetHskLevel,
  ...
```

- **Root cause:** the roadmap was built against an earlier, 6-lesson prototype curriculum and never migrated to `curriculum_units/curriculum_lessons`; `getLevel`’s fallback makes an unknown level look like Pinyin foundations instead of failing visibly.
- **Impact (user-visible):** the “Chi Tiết Giáo Trình HSK 1” section in the roadmap lists 6 fabricated lessons with titles/content references that don’t exist in the content packs, while the real 15 lessons live only in Learning tab. Selecting HSK 3/4/5 in the roadmap shows Pinyin Foundation units (2 lessons) under a heading “Giáo trình HSK 3/4/5”. Recommendations are drawn from this fake catalog, so “Học ngay” from a recommendation navigates to generic screens (grammar list, reading list, review) rather than the actual lesson (see `roadmap_screen.dart:510-545`). The README’s “adaptive roadmap HSK 1–6” is not implemented.
- **Fix:** delete `CurriculumCatalog` as a progress source; load units/lessons from `CurriculumRepository.getUnitsWithLessons(curriculumId)` for `selectedLevel`, and make `getLevel` throw/show an explicit “content not installed” state for levels without a pack. Wire the recommendation “Học ngay” to `LessonStudyScreen(lesson: dbLesson)`.
- **Verification status:** catalog file read end-to-end; compared lesson counts and IDs against both pack JSONs; traced `AdaptiveRoadmapContext.currentLevel` to `goal.targetHskLevel`; traced `roadmap_screen` level selector to `CurriculumCatalog.getLevel(selectedLevel)`.

---

## [T3-F11] Every dialogue step renders blank: view reads `hanzi`/`meaning`, package stores `text_zh`/`text_vi`; grammar examples never render either

- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/widgets/lesson_dialogue_view.dart:47`, `:49`; `assets/data/content_packs/hsk1/hsk1_pack_v1.json:1`; `lib/features/curriculum/presentation/widgets/lesson_grammar_view.dart:51`
- **Evidence:**

```dart
// lesson_dialogue_view.dart:45
final item = lines[index];
final speaker = (item['speaker'] ?? 'A') as String;
final hanzi = (item['hanzi'] ?? item['chinese'] ?? '') as String;
final pinyin = (item['pinyin'] ?? '') as String;
final meaning = (item['meaning'] ?? item['vietnamese'] ?? '') as String;
```

pack dialogue payload (extracted):

```json
{"speaker":"A","text_zh":"A: 你，你好！","pinyin":"A: nǐ, Nǐ hǎo!","text_vi":"A: Xin chào bạn!"}
```

so `hanzi` and `meaning` are always `''`; the widget still renders empty `Text('')` for hanzi and Vietnamese. Same class of bug in grammar:

```dart
// lesson_grammar_view.dart:51
final rawExamples = (p['examples'] as List<dynamic>?) ?? [];
final examples = rawExamples.map((e) => e as Map<String, dynamic>).toList();
```

but pack grammar points only have `positive_example` / `contrastive_example` strings, no `examples` list → the “Ví dụ minh họa” block never appears (grep `examples` in pack: absent).
- **Root cause:** the pack schema (generator) and the widget field names drifted; only vocabulary and exercise payloads still line up.
- **Impact (user-visible):** in all 15 HSK1 + 15 HSK2 lessons, step 4 “Hội thoại ứng dụng” shows chat bubbles with **empty Chinese text and empty Vietnamese translation** (only pinyin is visible, e.g. “A: nǐ, Nǐ hǎo!”). Step 3 “Điểm ngữ pháp” shows structure/title/explanation but loses the examples. The dialogue/grammar content the README advertises is effectively invisible.
- **Fix:** normalise reading in the widgets to the pack schema (`text_zh`, `text_vi`, `positive_example`, `contrastive_example`), or normalise the pack at import (`ContentPackManager` could map schema → canonical `content_json`); add a pack contract/unit test that asserts each segment type’s required keys exist before install.
- **Verification status:** read both widgets and the pack payloads; inspected sample dialogue/grammar payloads from both HSK packs (same schema); verified no `examples` key exists in any grammar point in either pack.

---

## [T3-F12] Lesson submit is fire-and-forget: UI shows pass before the transaction, failures are silent, and practice answers are never persisted

- **Severity:** High
- **Confidence:** LIKELY
- **Location:** `lib/features/curriculum/presentation/widgets/lesson_mastery_view.dart:288`, `lib/features/curriculum/presentation/providers/lesson_flow_providers.dart:40`, `lib/features/curriculum/presentation/screens/lesson_study_screen.dart:91`
- **Evidence:**

```dart
// lesson_mastery_view.dart:283
setState(() {
  _correctCount = correct;
  _scorePercent = exercises.isNotEmpty ? correct / exercises.length : 0.0;
  _isSubmitted = true;
});
widget.onSubmit?.call(enrichedExercises);       // async void call — not awaited
```

```dart
// lesson_flow_providers.dart:40
Future<ExerciseEvaluationResult> submitPractice(List<Map<String, dynamic>> questions) async {
  ...
  await masteryEngine.recordLessonAttempt(
    lessonId: state.lessonId,
    scorePercent: result.scorePercent,
    questionResults: enrichedQuestions,
  );
  ...
}
```

The UI immediately switches to “Chúc Mừng Bạn Đã Vượt Qua!” (`_isSubmitted == true`) while the pipeline transaction is still running. If `recordLessonAttempt` throws (e.g. `learner_evidence` `abort` conflict, foreign key, disk full), the exception is unhandled and the screen still shows success. The learner can also tap “Hoàn thành bài học” instantly, popping the screen while the transaction is in flight — `learning_screen.dart:664-666` then invalidates the provider and re-reads before commit, showing the lesson as not completed and the next lesson still locked.

The practice step is decorative: its answers only enter the local flow map:

```dart
// lesson_study_screen.dart:91
case 4:
  return LessonPracticeView(
    ...
    onAnswerRecorded: (qId, ans) => flowNotifier.recordAnswer(qId, ans),
```
```dart
// lesson_flow_providers.dart:34
void recordAnswer(String questionId, dynamic answer) {
  final updated = Map<String, dynamic>.from(state.userAnswers);
  updated[questionId] = answer;
  state = state.copyWith(userAnswers: updated);
}
```

No repository/coordinator call exists in `LessonPracticeView`; practice errors therefore never become evidence, never flag `unstable`, never reschedule SRS (all of that is only reachable through `submitPractice`’s `questionResults`, i.e. the same 10 mastery questions). `AdaptiveExerciseSampler.sampleQuestions` (the “adaptive 40 % focus-skill sampler”) has **zero call sites** — the practice step is the pack’s fixed 10 exercises.
- **Root cause:** the widget’s callback type is `Function(...)?` (void) so nothing can await the future; the pipeline exposes only one submit entry point and it is attached to the last step.
- **Impact (user-visible):** perceived pass may not be persisted (progress lost silently, no error toast); double-tap “Nộp bài kiểm tra” can run the pipeline twice (attempts/evidence duplicated) because there’s no in-flight flag; the “adaptive practice” step never records learning evidence and its wrong answers never feed SRS, despite the UI text “Luyện tập thích ứng” and the coordinator’s claims.
- **Fix:** make the submit callback `Future<void> Function(...)` and await it before flipping to the success view; show an error state with retry on failure. Disable the submit button while awaiting. Attach the practice step to the pipeline: record each answer via `LearningPipelineCoordinator.recordExerciseAttempt` (or accumulate and call `recordLessonCompletion` with `questionResults` from practice) and re-enable `sampleQuestions` for real adaptive selection.
- **Verification status:** call chain read; grep confirms `sampleQuestions` single definition/no callers and `recordLessonCompletion` single caller; no `_isSubmitting`/await on submit in the mastery widget. Marked LIKELY due to timing/failure-mode nature (not reproduced).

---

## [T3-F13] SRS “Quên/Again” promises “< 10 phút” but schedules the card 1 day later

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/vocabulary_srs/domain/sm2_engine.dart:99`, `:154`, `:221`
- **Evidence:**

```dart
// sm2_engine.dart:99
if (q < 3) {
  // Recall Failure (Again)
  newReps = 0;
  newLapses = prevLapses + 1;
  newInterval = 1; // Reset to 1 day
  newState = (currentState.state == SrsItemState.newCard)
      ? SrsItemState.learning
      : SrsItemState.relearning;
}
...
// :155
final scheduledDueAt = nowUtc.add(Duration(days: newInterval));
```

```dart
// sm2_engine.dart:221
static String formatIntervalExplanation(SrsRating rating, int days) {
  if (rating == SrsRating.again) {
    return '< 10 phút';
  }
```

`previewIntervals` feeds the rating bar (`flashcard_rating_bar.dart:73-74`), so the UI labels the Again button “< 10 phút”, but the persisted `due_at` is tomorrow. The card is not re-queued in the current session either (`SrsStudySessionNotifier.submitRating` only increments `currentIndex`).
- **Root cause:** the SM-2 implementation resets failed cards to a 1-day interval (a defensible simplification of SM-2, which uses minutes in a learning phase), but the presentation layer hardcodes a 10-minute promise and the session queue doesn’t implement learning steps.
- **Impact (user-visible):** learner taps “Quên” expecting to re-see the card in 10 minutes; it disappears for a full day (and the session ends without re-testing). This is a silent scheduling lie — the most important review action behaves opposite to its label.
- **Fix:** implement a learning/relearning step model (`due = now + 10 minutes` for Again; keep `interval_days = 1` for the next successful graduation), and/or change the label to the actual next interval (`formatIntervalExplanation` must not special-case Again; show “1 ngày”). If keeping 1-day intervals for Again, re-enqueue the card at the end of the current session so it is reviewed again in-session.
- **Verification status:** traced `SrsRating.again → calculateNextStateFromQuality(q=1) → scheduledDueAt` and `previewIntervals → FlashcardRatingBar → formatIntervalExplanation`; `sm2_engine.dart` unit-test expectations in `test/` not consulted (out of read scope), but behavior is deterministic from the code.

---

## [T3-F14] SRS review failures are silent; “Đã lưu SQLite” is always shown

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/vocabulary_srs/presentation/providers/srs_providers.dart:106`, `lib/features/review/presentation/screens/review_screen.dart:128-135`, `lib/features/vocabulary_srs/presentation/widgets/flashcard_progress_header.dart:46`
- **Evidence:**

```dart
// srs_providers.dart:86
final repo = ref.read(srsRepositoryProvider);
await repo.recordReviewAndProgress(item: card, rating: rating);

final isSuccess = rating != SrsRating.again;
state = AsyncValue.data(
  current.copyWith(
    currentIndex: current.currentIndex + 1,
    ...
    hasSavedOffline: true,
    ...
  ),
);
...
} catch (e) {
  // Revert processing flag and record error
  state = AsyncValue.data(
    current.copyWith(
      isProcessingReview: false,
      errorMessage: e.toString(),
    ),
  );
}
```

`errorMessage` is stored but **never rendered**: grep over `lib/` finds it only in `srs_models.dart`, the notifier write, and `srs_providers.dart:111` — `review_screen.dart` reads `session.hasSavedOffline` but not `session.errorMessage`. The header unconditionally prints “Đã lưu SQLite” when `hasSavedOffline` is true, and `hasSavedOffline` is initialised/persisted as `true` (`srs_models.dart:339`, `srs_providers.dart:98`).
- **Root cause:** error state was added to the session model but no UI surface was added; the persistence badge is optimistic, not derived from the DB result.
- **Impact (user-visible):** when a review fails (debounce/throttle, SQLite error, duplicate review, etc.) the rating buttons just re-enable, the card doesn’t advance, and **nothing tells the learner why** — it looks like a dead tap. Meanwhile the header keeps claiming everything is saved to SQLite even when the last review threw. Double-tap protection can also look like a broken button.
- **Fix:** render `session.errorMessage` as an inline error banner/snackbar in `ReviewScreen`, show a retry affordance; set `hasSavedOffline` from the actual persistence result (false on catch) and show “Chưa lưu” instead of the static success chip.
- **Verification status:** grep of `errorMessage` across `lib/` (no render site); review screen read; header read; notifier read.

---

## [T3-F15] Opening the Review tab auto-enrolls up to 25 unstudied words, inflating “due today” and making the empty state unreachable

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/vocabulary_srs/data/srs_repository.dart:282`, `:314`
- **Evidence:**

```dart
// srs_repository.dart:282 (getDueFlashcards)
// 2. If fewer than limit, pull unlearned words from vocabularies
if (results.length < limit) {
  final remaining = limit - results.length;
  ...
  final newRows = await _db.rawQuery(newVocabsQuery, hskLevel != null ? [hskLevel] : []);
  for (final row in newRows) {
    final vocabId = (row['vocab_id'] ?? row['id']) as String;
    final srsState = await getOrCreateCardState(contentId: vocabId);   // INSERT INTO srs_items
    ...
  }
}
```

`SrsStudySessionNotifier.build()` calls `getDueFlashcards(limit: 25, hskLevel: profile?.currentHskLevel)` (`srs_providers.dart:50-53`), and `getOrCreateCardState` inserts a due-now `new` card (`srs_repository.dart:71-84`). The seed has 5 000 vocabularies (150 for HSK1), so there is always something to auto-enrol.

- **Root cause:** the “learn new words” fallback writes durable SRS rows as a side effect of merely rendering the review queue; the due badge counts (`getDueCardsCount`) include those new rows.
- **Impact (user-visible):** after first launch (before studying any lesson) opening Review once makes “Cần ôn hôm nay” jump from 0 to (up to) 25; the Home SRS card also shows 25 due. The `FlashcardEmptyState`(“Hoàn thành tất cả thẻ hôm nay”) is unreachable whenever any vocabulary exists. Queue count ≠ due count: due badge query also uses a loose join (`s.content_id = v.id OR s.content_id = v.simplified`, `:404`) while the queue uses `INNER JOIN ... ON s.content_id = v.id` (`:255`) — cards keyed by legacy raw Hanzi are counted but can never be shown, and the queue may add new words not reflected in the “Cần ôn hôm nay” number.
- **Fix:** separate “review due” from “new card intake”: (a) build the new-word pool as a transient suggestion list without inserting SRS rows until the first rating, or (b) create rows with a later `due_at`/`is_introduced = 0` flag and exclude them from due counts; make `getDueCardsCount` and `getDueFlashcards` use the same canonical join; add an integration test asserting `getDueCardsCount() == getDueFlashcards().length` for a fresh profile.
- **Verification status:** repository functions read; notifier read; count/queue SQL compared line-by-line; `getOrCreateCardState` insert path confirmed.

---

## [T3-F16] Home roadmap progress is mathematically wrong: level denominator vs global numerator, plus hardcoded fake lesson names

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/home/data/home_repository.dart:466`, `:476`, `:499`, `:520`
- **Evidence:**

```dart
// home_repository.dart:468
final totalVocabRes = await _db.rawQuery(
  'SELECT COUNT(id) as count FROM ${DatabaseConstants.tableVocabularies} '
  'WHERE hsk_level = ? AND deleted_at IS NULL',
  [hskLevel],
);
...
// :476 — note: NO hsk_level filter
final learnedRes = await _db.rawQuery(
  '''
  SELECT COUNT(DISTINCT content_id) as count
  FROM ${DatabaseConstants.tableSrsItems}
  WHERE content_type = 'vocabulary'
    AND state != 'new'
    AND deleted_at IS NULL
  ''',
);
...
// :520
totalVocabCount: totalVocab > 0 ? totalVocab : 150,
```

and the “next lesson” is fabricated from vocab ratios, unrelated to `curriculum_lessons`:

```dart
// :503
if (learnedVocab == 0) {
  nextLessonTitle = 'Bài 1: Chào hỏi & Pinyin cơ bản';
  nextLessonSnippet = '你[nǐ]好[hǎo]，我[wǒ]叫[jiào]李[lǐ]华[huá]。';
} else if (learnedVocab < (totalVocab * 0.3).round()) {
  nextLessonTitle = 'Bài 2: Con số & Đồ vật hàng ngày';
  ...
```

- **Root cause:** numerator and denominator are computed from different populations (all levels vs current level); roadmap card is fed a locally synthesised object rather than curriculum data.
- **Impact (user-visible):** an HSK1 learner who reviewed 150 HSK2 words sees “150/150 từ” and 100 % HSK1 progress (or >100 % before clamp); an HSK2 learner sees HSK1 SRS progress counted against HSK2 totals. The “next lesson” card shows lesson titles that don’t exist in the curriculum (“Bài 2: Con số & Đồ vật hàng ngày” vs real `lesson_1_2` “Cảm ơn bạn”), and tapping “Tiếp tục bài học” opens the generic HSK1 syllabus (F17). The `totalVocabCount` fallback of 150 is a hardcoded constant.
- **Fix:** compute learned/mastered counts with an `hsk_level` join (`srs_items`→`vocabularies`), derive the roadmap card from `curriculum_lessons` (next not-completed/unlocked lesson, real title) instead of ratio thresholds, and remove the 150 fallback.
- **Verification status:** all SQL read; compared against seed (`hsk_level 1: 150`, `2: 150`, `3: 299`, …) and pack lessons; `HomeRoadmapCard` renders these values directly (`home_roadmap_card.dart:44`, `:51`, `:67`, `:84`).

---

## [T3-F17] Home “Tiếp tục bài học” always opens HSK 1 curriculum, even for HSK2+ learners

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/home/presentation/screens/home_screen.dart:133`
- **Evidence:**

```dart
// home_screen.dart:129
HomeRoadmapCard(
  roadmap: data.roadmap,
  onContinueLesson: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CurriculumSyllabusScreen(),   // default curriculumId = curr_hsk1
      ),
    );
  },
),
```

`CurriculumSyllabusScreen` defaults are `curriculumId = CurriculumConstants.currHsk1` (`curriculum_syllabus_screen.dart:17-18`), and `HomeRepository.getDashboardData` computes `roadmap` for `activeHskLevel` from the profile (`home_repository.dart:379`).
- **Impact (user-visible):** an onboarding- or placement-placed HSK2 learner sees an HSK2-labelled roadmap card, taps “Tiếp tục bài học”, and lands in the HSK1 syllabus (potentially with HSK1 lessons already credited). Same for the recent-lessons CTA path via `LearningScreen`? (Learning screen does pass `_curriculumId`, so only the Home path is wrong.)
- **Fix:** pass the level through: `CurriculumSyllabusScreen(curriculumId: CurriculumConstants.curriculumIdForLevel(data.roadmap.currentHskLevel), curriculumTitle: 'Giáo trình HSK ${...} Chuẩn')`; guard `curriculumIdForLevel` for level 0.
- **Verification status:** both files read; traced `data.roadmap.currentHskLevel` from `HomeRepository.getDashboardData(activeHskLevel)`.

---

## [T3-F18] Onboarding “personalization” is write-only: focus skill, purpose, pinyin position, script type, learning method and reminders are never applied or scheduled

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/onboarding/presentation/providers/onboarding_providers.dart:320-335`, `lib/features/onboarding/presentation/screens/onboarding_personalization_screen.dart:45-54`, `:132-150`
- **Evidence:** onboarding persists 13 settings keys in one transaction:

```dart
// onboarding_providers.dart:321
final settingsMap = {
  keyDailyMinutes: dailyMinutes.toString(),
  keyPrioritySkill: focusSkill,
  keyLearningPurpose: learningPurpose,
  keyShowPinyin: showPinyin.toString(),
  keyPinyinPosition: pinyinPosition,
  keyScriptType: scriptType,
  keyLearningMethod: learningMethod,
  keySpeechRate: speechRate.toString(),
  keyReminderEnabled: reminderEnabled.toString(),
  keyReminderTime: reminderTime,
  keyStartingHsk: (state.assessedHskLevel ?? 1).toString(),
  keyOnboardingStep: OnboardingStep.completed.stepIndex.toString(),
  keyOnboardingCompleted: 'true',
};
```

Grep for those literal keys across `lib/` returns only the onboarding writer (and the settings screen reading `show_pinyin`, `speech_rate`). There is **no notification scheduling anywhere** in `lib/` (grep `reminder|notification` = only these settings strings), so a learner who enables “Nhắc nhở học tập 20:00” will never receive a reminder. `_selectedSkill` (“kỹ năng ưu tiên”) is never consumed by SRS/roadmap/curriculum; `_selectedPurpose` only feeds `learner_goals.purpose` (display), never content selection; `_scriptType` (traditional/simplified) never changes any glyph rendering; `_learningMethod` and `_pinyinPosition` are never read.
- **Root cause:** onboarding UI was built ahead of the preference consumers; only `show_pinyin`/`speech_rate` have consumers in the settings screen (and even those are not applied to curriculum widgets, which always render pinyin).
- **Impact (user-visible):** personalization promises (“cá nhân hóa trải nghiệm”, focus skill, daily reminder, pinyin position, traditional script) are cosmetic; the wizard collects data that has no effect. A learner who chooses “Ôn tập ngắt quãng (SRS)” as preferred method still gets the contextual lesson path; a learner who enables reminders gets none (a silent broken promise).
- **Fix:** either wire each setting to a consumer (notification package + scheduling, script/pinyin rendering providers, focus skill as the 40 % sampler focus / SRS priority, learning method as default tab) or remove the controls to avoid false promises. Add tests that each persisted key has at least one reader.
- **Verification status:** grep of all key literals across `lib/` (only writer + settings show_pinyin/speech_rate); grep of reminder/notification code (no scheduler); personalization screen read.

---

## [T3-F19] Onboarding completes successfully even when every DB write fails (`catch (_) {}`)

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/onboarding/presentation/providers/onboarding_providers.dart:315`, `:446`
- **Evidence:**

```dart
// onboarding_providers.dart:286
Future<void> completePersonalization({...}) async {
  if (!ref.mounted) return;
  state = state.copyWith(isLoading: false, isCompleted: true, currentStep: OnboardingStep.completed, ...);
  try {
    if (AppDatabase.instance.isOpen) {
      ...
      await db.transaction((txn) async {
        ... settings, profile, learner_goal, PlacementUnlockHandler, roadmap_initialized ...
      });
    }
  } catch (_) {}      // :446 — swallowed silently
}
```

The UI immediately treats it as done: `onboarding_flow_screen.dart:97` calls `onOnboardingComplete()` right after `await notifier.completePersonalization(...)`; the notifier sets `isCompleted: true` before the transaction, and AppShell switches to the main tabs (`app_shell.dart:60-66`).
- **Impact (user-visible):** if the transaction fails (e.g. constraint, disk full, unlock handler exception), the learner lands in the main app with an empty/unchanged profile and **no credited lessons, no goal, and no message** — the placement result silently didn’t take effect; they will see HSK1 lessons locked and no roadmap. No error is surfaced anywhere.
- **Fix:** remove the blanket catch; propagate failure to a state flag, keep the wizard on the submit screen, show an actionable error with retry, and only set `isCompleted: true` after the transaction commits.
- **Verification status:** code read; AppShell/flow-screen ordering verified; `catch (_) {}` is the only error handling in the whole method.

---

## [T3-F20] HSK2 syllabus advertises and launches the HSK1 exit exam (HSK2 exam unreachable)

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart:78`, `:86`, `:102`; `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:21`
- **Evidence:** the syllabus banner is hardcoded to “HSK 1” and the button constructs the exam with defaults (`level = '1'`):

```dart
// curriculum_syllabus_screen.dart:78
Text(
  'Thi tốt nghiệp HSK 1',
  ...
),
...
Text(
  'Đề thi chuẩn quốc tế 40 câu • 35 phút',
  ...
),
...
HiButton(
  text: 'Thi ngay',
  ...
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LevelExitExamScreen(),   // level defaults to '1'
      ),
    );
  },
),
```
```dart
// level_exit_exam_screen.dart:19
const LevelExitExamScreen({
  super.key,
  this.level = '1',
  ...
```

The syllabus is level-aware everywhere else (`curriculumId`, title) and `LevelExitExamScreen` accepts a level, but nothing ever passes it. The HSK2 pack ships a valid exit exam (`hsk2_pack_v1.json.exit_exam`, 40 questions, pass 120) that is therefore unreachable from the UI.
- **Impact (user-visible):** an HSK2 learner opens their HSK2 syllabus and sees “Thi tốt nghiệp HSK 1”; pressing it runs the HSK1 exam (and on pass re-credits HSK1/unlocks HSK2 lesson 1 instead of unlocking HSK3). The HSK2 graduation exam can never be taken, so there is no way to unlock HSK3 from HSK2.
- **Fix:** pass the level derived from `curriculumId` (`CurriculumConstants.levelFromCurriculumId(curriculumId)`) to `LevelExitExamScreen(level: level.toString())` and make the banner title/description level-dependent. Add a test that each `curr_hskN` opens exam `N`.
- **Verification status:** syllabus read; `LevelExitExamScreen` constructor/single call site verified via grep (`curriculum_syllabus_screen.dart:102` only); confirmed HSK2 pack contains an exit exam.

---

## [T3-F21] Placement report: all skills share one theta, placement skill scores never reach the roadmap

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/placement_test/domain/engine/cat_engine.dart:318`, `lib/features/roadmap/data/roadmap_repository.dart:293`
- **Evidence:** per-skill “estimated theta” is just the overall theta:

```dart
// cat_engine.dart:318
// Calculate skill specific theta
double skillTheta = overallTheta;
final subMetrics = <String, dynamic>{};
...
skillScores[skill] = SkillScoreEstimate(
  skill: skill,
  isAssessed: true,
  estimatedTheta: skillTheta,
  ...
```

The result serialises `estimated_theta` (`cat_assessment_result.dart:52-62`), but the roadmap parser looks for different keys and clamps a [-3,3] theta into [0,1]:

```dart
// roadmap_repository.dart:293
double? extractedScore;
if (v is num) {
  extractedScore = v.toDouble();
} else if (v is Map) {
  final rawVal = v['score'] ?? v['mastery'] ?? v['theta'];
  if (rawVal is num) {
    extractedScore = rawVal.toDouble();
  }
}
if (extractedScore != null) {
  placementSkillScores[skill] = extractedScore.clamp(0.0, 1.0);
}
```

`v` is `SkillScoreEstimate.toMap()` = `{... 'estimated_theta': ..., 'standard_error': ..., 'accuracy_rate': ...}`; none of `score`/`mastery`/`theta` exists → `extractedScore` stays null → `placementSkillScores` is always empty. (If the key were renamed, the identical clamp would map negative theta to 0.0 and positive >1 to 1.0, i.e. wrong scale.)
- **Root cause:** schema/key drift between placement result model and roadmap consumer; per-skill theta was never computed (it is a copy of the overall theta).
- **Impact (user-visible):** the result’s six-skill breakdown shows identical “Độ thành thạo” for every assessed skill because only accuracy differs; the roadmap’s “Điểm nổi bật từ bài đánh giá năng lực” never uses placement data (skill mastery always 0 unless local evidence exists), so the adaptive roadmap is not actually seeded by the placement test; `knowledgeGaps` from the test also don’t map (they are Vietnamese labels, matched against English `skill.name`/`prerequisiteSkills`, `adaptive_roadmap_engine.dart:126-130`).
- **Fix:** compute skill-level theta from the skill’s responses (2PL EAP/ML estimate per skill) and store a `mastery_rate` 0..1 field for consumers (accuracy is already available); fix the roadmap parser to read the new field and not clamp theta; match knowledge gaps via the tag (`knowledge_gap_tag`) rather than display text.
- **Verification status:** both files read; JSON keys compared; `getAdaptiveRoadmapState` path traced into `AdaptiveRoadmapContext.skillMasteryScores`.

---

## [T3-F22] CAT resume after an app kill can re-present an already-answered item

- **Severity:** Medium
- **Confidence:** LIKELY
- **Location:** `lib/features/placement_test/data/placement_test_repository.dart:143`
- **Evidence:**

```dart
// placement_test_repository.dart:143
// Determine current active skill and select next item
final usedItemIds = responses.map((r) => r.itemId).toSet();
CatSkill currentSkill = effectiveBlueprint.skillSequence.first;

for (final skill in effectiveBlueprint.skillSequence) {
  final count = skillCounts[skill] ?? 0;
  if (count < effectiveBlueprint.minItemsPerSkill) {
    currentSkill = skill;
    break;
  }
  if (count < effectiveBlueprint.maxItemsPerSkill) {
    currentSkill = skill;
    break;
  }
}

final activeItem = _engine.selectNextItem(
  currentSkill: currentSkill,
  currentTheta: currentTheta,
  usedItemIds: usedItemIds,
) ?? _engine.selectInitialItem(currentSkill, targetTheta: currentTheta);
```

- **Root cause:** resume reconstructs only (a) theta/SE, (b) per-skill counts — not the engine’s stop state or `stepIndex`; the heuristic picks the first skill under `maxItemsPerSkill`. If the learner was killed after finishing a skill whose items are all used (e.g. 5 vocab + 4 grammar = 9 responses), resume picks grammar (count 4 < 5), `selectNextItem` returns null, and the fallback `selectInitialItem` returns GRAM_001 — which is already in `usedItemIds` — so the learner is asked an answered question and it is scored/persisted again. If all skills are exhausted, `activeItem` may be non-null-but-duplicate (as above) or null and the flow screen shows the “Đang chuyển kỹ năng...” spinner indefinitely until another turn (no turn can happen).
- **Impact (user-visible):** after backgrounding/being killed mid-test, resuming can show a question the learner already answered (same item, same options) and count it twice; theta/SE move again; conversely a null item produces a stuck loading state on the flow screen.
- **Fix:** persist `current_skill`, `step_index`, and the engine’s pending skill-advance state in `placement_test_sessions` and restore it verbatim; in the fallback path never return an item whose id is in `usedItemIds` — advance to the next skill with unused items, or finalize if none.
- **Verification status:** repository read; engine stop/advance logic read; item bank counts per skill verified (vocab 5, grammar 4, reading 3). Marked LIKELY (requires the exact interruption point).

---

## [T3-F23] “Mastered” is granted without proven spaced retention (quality ≥4 bypasses interval check)

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/learning_pipeline/domain/engine/mastery_evaluator.dart:59`
- **Evidence:**

```dart
// mastery_evaluator.dart:58
} else if (ev.activityType == ActivityType.retention) {
  // Verify spaced interval if available in metadata
  final newInterval = (ev.metadata['new_interval'] as num?)?.toInt() ?? 0;
  final quality = (ev.metadata['quality'] as num?)?.toInt() ?? 0;
  if (newInterval >= 5 || quality >= 4) {
    successfulRetentions++;
  } else {
    successfulApplications++;
  }
}
...
// :73
if (successfulRetentions >= 1 && (successfulApplications >= 1 || successfulRetentions >= 2)) {
  return MasteryState.mastered;
}
```

- **Root cause:** the comment/contract says mastery requires spaced retention, but the `|| quality >= 4` clause lets a single “Good”/“Easy” review count as retention even when the scheduled interval is 1 day. `quality: 4` is the default for any “Nhớ” tap, and the first successful review of a new card always has `new_interval = 1` (`sm2_engine.dart:112-118`).
- **Impact (user-visible):** a vocabulary item taught in a lesson (instruction evidence) plus one 1-day “Nhớ” review → `successfulRetentions=1` + `successfulApplications≥1` → state `mastered` in `curriculum_mastery`, despite no long-term retention. The six-state mastery model advertised in the README (and the roadmap/“mastered” counts) is inflated; learners see “Thành thạo” after one day.
- **Fix:** require `newInterval >= 5` (decode: e.g. ≥ 21 days) for retention evidence, and use quality only to distinguish “hard” reviews; if interval metadata is missing, do not count as retention. Add unit tests for thresholds.
- **Verification status:** evaluator read; fed through `LearningPipelineCoordinator.recordSrsReview` metadata (`srs_repository.dart:152-163` + `learning_pipeline_coordinator.dart:701-724`); SM-2 first-review interval confirmed 1 day.

---

## [T3-F24] Exit-exam persistence and unlock failures are swallowed; UI still claims success

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:232-255`, `lib/features/curriculum/data/curriculum_repository.dart:220-228`
- **Evidence:**

```dart
// level_exit_exam_screen.dart:224
setState(() {
  _listenScore = listenPoints;
  _readScore = readPoints;
  _score = totalPoints;
  _isSubmitted = true;                 // results screen shown immediately
});

try {
  ...
  if (repo != null) {
    await repo.recordExitExamSubmission(...);
  }
} catch (e) {
  debugPrint('[LevelExitExamScreen] Warning: Failed to record exit exam submission: $e');
}
```

```dart
// curriculum_repository.dart:220
if (isPassed) {
  try {
    final unlockHandler = PlacementUnlockHandler(executor);
    await unlockHandler.unlockForRecommendedLevel(hskLevel + 1, startingLessonOrder: 1);
  } catch (_) {}                         // unlock failure swallowed inside the txn
}
```

- **Root cause:** both layers treat persistence as best-effort; the result screen is state-driven and has no knowledge of the write outcome.
- **Impact (user-visible):** a learner can see “XUẤT SẮC ĐẠT CHUẨN ĐẦU RA! … đã mở khóa HSK tiếp theo” while the `curriculum_mastery`/`learning_activities` write or the level unlock failed — no next level, no streak credit, no error. Conversely, if the write succeeds but unlock failed, the mastery row says mastered without unlocking; `recordExitExamSubmission`’s transaction is not rolled back per-step (catch inside transaction).
- **Fix:** await the write before setting `_isSubmitted`, display a blocking error screen with retry on failure; remove the inner `catch (_) {}` around the unlock and let the transaction roll back so the result is all-or-nothing; surface an explicit unlock status in the result UI.
- **Verification status:** both layers read; single call site verified; no error state in the screen.

---

## [T3-F25] Re-running the placement test outside onboarding credits curriculum but never updates the learner’s HSK level (three-way level split-brain)

- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/placement_test/data/placement_test_repository.dart:296-303`, `lib/features/onboarding/presentation/providers/onboarding_providers.dart:349-375`, `lib/features/vocabulary_srs/presentation/providers/srs_providers.dart:21`, `lib/features/home/data/home_repository.dart:106`
- **Evidence:** the placement test’s completion handler always credits lessons, but only the onboarding provider updates the profile:

```dart
// placement_test_repository.dart:296
// 4. Activate PlacementUnlockHandler to unlock recommended level and auto-credit prior lessons
try {
  final unlockHandler = PlacementUnlockHandler(txn);
  await unlockHandler.unlockForRecommendedLevel(result.recommendedHskLevel);
} catch (e) {
  debugPrint('[PlacementTestRepository] Warning: PlacementUnlockHandler failed: $e');
}
```

```dart
// onboarding_providers.dart:350 — only here is the profile level updated
final updatedRows = await txn.update(
  DatabaseConstants.tableUserProfiles,
  {
    'current_hsk_level': currentHsk,
    'daily_minutes': dailyMinutes,
    'purpose': learningPurpose,
    'updated_at': nowUtc,
  },
);
```

`SrsDueCountNotifier`/`SrsStudySessionNotifier` filter by `profile?.currentHskLevel` (`srs_providers.dart:21`, `:52`), `HomeRepository.getCurrentHskLevel()` reads `user_profiles.current_hsk_level` (`home_repository.dart:106-139`), and `LearningScreen` defaults to HSK1 (`learning_screen.dart:30`). The placement test can also be launched from the Learning tab (`learning_screen.dart:97-109`, `PlacementTestIntroScreen()` with no `onTestComplete`), in which case only the repository path runs.
- **Impact (user-visible):** a learner who takes/re-takes the placement test from the Learning tab is told “Bắt đầu học từ HSK 3”, and HSK1/2 lessons are credited, but SRS, Home and the Learning tab keep filtering by the old profile level (1). The roadmap target (from `learner_goals`) is only updated by onboarding too. Result: placement report and actual app behaviour disagree; due-review badge may be 0 for the newly placed level.
- **Fix:** in `finalizeSession`, after the unlock, update `user_profiles.current_hsk_level` and the active `learner_goals.target_hsk_level` in the same transaction (and invalidate providers); or funnel all placement completions through one application service shared with onboarding.
- **Verification status:** greps confirm `user_profiles.current_hsk_level` is written only in onboarding and profile edit; placement repo writes only curriculum tables/evidence/activity; consumers read the profile; the Learning-tab entry point passes no `onTestComplete`.

---

## [T3-F26] Roadmap progress bar divides by the number of progress rows, not by lessons in the level

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/roadmap/presentation/screens/roadmap_screen.dart:216-219`
- **Evidence:**

```dart
// roadmap_screen.dart:216
final levelLessons = state.lessonProgressMap.values.where((p) => p.hskLevel == selectedLevel).toList();
final completedCount = levelLessons.where((p) => p.isCompleted).length;
final totalCount = levelLessons.length;
final double completionRate = totalCount == 0 ? 0.0 : (completedCount / totalCount);
```

- **Root cause:** the denominator is derived from the sparse progress map rather than the catalog/curriculum lesson count.
- **Impact (user-visible):** after the first “Bỏ qua” (which creates the only `lesson_progress` row) the roadmap shows “0 / 1 bài (0 %)” or, once it becomes completed, “1 / 1 bài (100 %)” for a 6/15-lesson level — misleading progress. With the split-brain (F09) this is usually the only progress the roadmap ever has.
- **Fix:** `totalCount = CurriculumCatalog.getLevel(selectedLevel).allLessons.length` (and count only completed rows among those), or use DB curriculum lessons after F10.
- **Verification status:** code read; no other denominator in the screen.

---

## [T3-F27] Review screen reports 100 % retention before any review

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/vocabulary_srs/domain/srs_models.dart:354`, `lib/features/review/presentation/screens/review_screen.dart:96`
- **Evidence:**

```dart
// srs_models.dart:354
double get accuracyRate =>
    completedReviewsCount == 0 ? 1.0 : (correctReviewsCount / completedReviewsCount);
```
```dart
// review_screen.dart:96
final accuracyPercent = (session.accuracyRate * 100).toStringAsFixed(0);
...
_buildStatCard(title: 'Tỷ lệ nhớ', value: '$accuracyPercent%', ...)
```

- **Impact (user-visible):** first card of every session shows “Tỷ lệ nhớ 100%” even though nothing has been reviewed — a wrong stat that can reassure learners falsely (and looks broken after a single “Quên” drops it).
- **Fix:** show “—/Chưa có” when `completedReviewsCount == 0` (return `null` rather than 1.0, or branch in the widget).
- **Verification status:** model + screen read.

---

## [T3-F28] Retaking a completed lesson and failing downgrades its persisted status to `in_progress`

- **Severity:** Low
- **Confidence:** LIKELY
- **Location:** `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart:72-80`
- **Evidence:**

```dart
// Step A: Update Lesson status in curriculum_lessons
await txn.update(
  DatabaseConstants.tableCurriculumLessons,
  {
    'status': isPassed ? 'completed' : 'in_progress',
    if (isPassed) 'completed_at': nowIso,
  },
  where: 'id = ?',
  whereArgs: [lessonId],
);
```

- **Root cause:** Step A is an unconditional overwrite; a failed retake of an already-completed lesson regresses the status (and the mastery row state) while `completed_at` remains from the first pass — inconsistent row.
- **Impact (user-visible):** after re-opening a finished lesson to review and scoring < 80 %, the lesson card switches from “Đã hoàn thành” to “Đang học” and the mastery score is overwritten; downstream gating that reads status (`PrerequisiteEngine`) would treat it as incomplete. Currently masked by F01 (no completion can happen), but it is latent and would surface as soon as F01 is fixed.
- **Fix:** only downgrade when no completion exists (`WHERE id = ? AND status != 'completed'`), or keep the best score/status (`status = CASE WHEN status='completed' THEN status ELSE ? END`) and do not lower `score` below the historical best.
- **Verification status:** pipeline code read; no idempotency/previous-status check; latent due to F01.

---

## [T3-F29] Home study-time dedupe drops distinct activities that share type + duration + items within the same 2-second bucket

- **Severity:** Low
- **Confidence:** LIKELY
- **Location:** `lib/features/home/data/home_repository.dart:215-221`
- **Evidence:**

```dart
// home_repository.dart:215
// Sync / retry deduplication: 2-second bucket window
final epochBucket = parsedUtc.millisecondsSinceEpoch ~/ 2000;
final dedupKey = '$type:$durationSec:$items:$epochBucket';
if (seenActivityKeys.contains(dedupKey)) {
  continue;
}
seenActivityKeys.add(dedupKey);
```

- **Root cause:** the key deliberately ignores the activity id/created_at exact value to dedupe “sync retries”, but legitimate distinct activities of the same type with the same clamped duration/items in the same 2 s bucket become indistinguishable.
- **Impact (user-visible):** quick SRS reviews of two different cards have different timestamps (each is its own transaction) so usually safe, but e.g. two different mini-games/lessons logged back-to-back in the same second with the same duration and item count (e.g. two 1-item SRS-ish activities, or batched writes) can silently lose study time/items from today/week/total stats and streak. Low frequency but a silent stat loss.
- **Fix:** dedupe on the actual primary key/id or a real retry marker; if a time window is needed, use a much smaller window (< 500 ms) and include `created_at` exact equality.
- **Verification status:** code read; low likelihood noted.

---

## [T3-F30] `MasteryDao.getWeakKnowledgeItems` uses a state that the pipeline never writes (`not_started` vs `unseen`), and the whole weak-lesson feature is dead

- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/core/database/dao/mastery_dao.dart:71-78`
- **Evidence:**

```dart
// mastery_dao.dart:71
Future<List<Map<String, dynamic>>> getWeakKnowledgeItems({double scoreThreshold = 0.7}) async {
  return _db.query(
    DatabaseConstants.tableCurriculumMastery,
    where: 'score < ? AND mastery_state != ?',
    whereArgs: [scoreThreshold, 'not_started'],
    orderBy: 'score ASC',
  );
}
```

The pipeline's default state is `unseen` (`mastery_evaluator.dart:14-16`, `mastery_state.dart:4`), and `curriculum_mastery` schema defaults to `not_started` only for legacy rows (migration_v9:142). `MasteryEngine.getWeakLessons` wraps this and has **no callers** (grep); likewise `getMasteryRecordsByType`, `getItemsNeedingReview`, `getMasterySummary` (provider only, no UI). The README claims “tự động đề xuất ôn tập SRS khi phát hiện kiến thức yếu” — the weak-detection query exists but is not connected to any screen/queue.
- **Impact (user-visible):** no automatic “weak knowledge → SRS/review” recommendation exists in the product despite the claim; where the query would run, items with state `unseen` and score 0 would be reported as “weak” (never-taught items are not weaknesses).
- **Fix:** use `MasteryState.unseen.value`/`MasteryState.values` mapping (or `state NOT IN ('unseen','exposed')`), and wire the weak-item list to a real “Cần củng cố” section / SRS intake; otherwise delete the dead code so it isn’t mistaken for a working feature.
- **Verification status:** grep of callers across `lib/`; enum/strings compared.

---

## Verification appendix — end-to-end traces performed

1. **Lesson completion (broken at step 6):**
   `LearningScreen._buildLessonCard` → `LessonStudyScreen` → `LessonFlowNotifier.nextStep` (6 steps) → `LessonMasteryView` (`_getSegment('masteryCheck')` → `CurriculumDao.getSegmentsByLessonId` LEFT JOIN content_items → `contentPayload == null`) → `LessonContentEmptyState` → `Navigator.pop(true)`; **no** `submitPractice` → **no** `MasteryEngine.recordLessonAttempt` → **no** `LearningPipelineCoordinator.recordLessonCompletion` → `curriculum_lessons.status` never becomes `completed`, step F never unlocks lesson N+1. Cross-checked there is exactly one caller chain to `recordLessonCompletion` via grep.
2. **Lesson completion if it did run:** pipeline transaction A→F writes `curriculum_lessons` (status/completed_at), `curriculum_mastery` (lesson + each taught vocab), `learner_evidence` (instruction + application), `srs_items` (intake/reschedule), and unlocks prerequisites whose prereq list contains the lesson and whose statuses are all `completed`. Nothing writes `lesson_progress` (roadmap) or `learning_activities` (home streak/durations) for the lesson itself — those are only written by the separate `DefaultRoadmapRepository.completeLesson` (dead) and SRS/exit-exam/placement paths.
3. **Placement:** `PlacementTestIntroScreen` ("Bắt đầu") → `ActiveCatSessionNotifier.startNewTest(initialTheta)` → `PlacementTestRepository.startNewSession` (`isBeginner = initialTheta <= -1.8`, beginner blueprint [listening, writing]) → `PlacementTestFlowScreen` → `CatQuestionCard.onTap/onPressed` → `submitAnswer` → `CatEngine.processTurn` (theta update, stop rules, skill advance/termination) → `saveTurnResponse` (JSON) → completion → `finalizeSession` (session row, evidence per response, learning activity, `PlacementUnlockHandler.unlockForRecommendedLevel`) → `PlacementTestResultScreen` → `onContinue(recommendedLevel)` → onboarding `completePlacementTest(level)` → personalization `completePersonalization` (profile + learner_goal + second unlock). Verified every hop and all four data-write sets; found the truncation, answer-key, fake-audio, auto-pass, double-tap, and key-mismatch defects above.
4. **SRS review:** `ReviewScreen` → `SrsStudySessionNotifier.submitRating` → `SrsRepository.recordReviewAndProgress` → `processReview` (in-flight/debounce guard, `getOrCreateCardState`, SM-2 `calculateNextState`, transaction: update `srs_items` + insert `learner_evidence` + `LearningPipelineCoordinator.recordSrsReview` upsert `curriculum_mastery`) → activity row → `refreshCount`; then `currentIndex+1`. Verified state transitions, due comparisons (UTC ISO strings), preview intervals, evidence history evaluation, auto-enrolment side effect, and silent error path.
5. **Exit exam:** `CurriculumSyllabusScreen` ("Thi ngay", level always 1) → `LevelExitExamScreen` (loads exam from `level_exit_exams` via repo or asset fallback; no timer, no gating) → `_submitExam` (per-source points out of 100, 200 total, pass 120) → `CurriculumRepository.recordExitExamSubmission` (curriculum_mastery ledger + learning_activities 35 min + learner_evidence + unlock next level) → result screen (answer key) → pop; nothing refreshes the syllabus.

## Reproducible data checks (read-only)

- HSK1 pack: 15 lessons / 150 unique words / 45 grammar points (17 unique titles) / 15 dialogues (30 lines) / 150 exercises; all 150 answers at `options[0]`; mastery refs `MASTERY_L1..15` missing (15/15).
- HSK2 pack: 15 lessons / 75 content items / 150 exercises (all `options[0]`); 15/15 mastery refs missing.
- Exit exam: 2 sections × 20 = 40 questions, 3 options each, all correct answers at index 0; `passing_score=120`, `duration_minutes=35`.
- Seed fixture v2: 5 000 vocabularies — HSK1 150, HSK2 150, HSK3 299, HSK4 601, HSK5 1300, HSK6 2500.
- CAT item bank: 31 items (vocab 5, grammar 4, reading 3, listening 8, writing 9, speaking 2); 28 multiple-choice items all `correctOptionIndex: 0`; 2 speaking items.
