# F13: N+1 SQLite Query Optimization for Hanzi and Sentence Modules

## 1. Executive Summary
This document records the architectural root causes, optimization designs, and benchmark results for eliminating N+1 SQLite queries in HI Chinese's Hanzi Character Browsing and Sentence Practice modules.

Prior to this fix, opening the character list screen (`hanzi_character_list_screen.dart`) or sentence browser screen (`sentence_browser_screen.dart`) executed up to hundreds of sequential SQLite queries inside loops to load user progress and related audio assets.

By replacing sequential point queries with batch-parameterized bulk queries (`IN (?, ?, ...)`), chunking requests safely within SQLite bind variable limits (chunk size: 300), and consolidating UI state changes into a single `setState()`, database query counts and interface loading latency have been reduced by up to 99.6%.

---

## 2. Root Cause Analysis

### Module Hanzi (`hanzi_character_list_screen.dart`)
1. **Character Progress Fetching**:
   - `_loadProgress()` looped across all characters in the current view (up to 300 characters per HSK level), calling `widget.repository.getProgress(character)` sequentially.
   - For 300 characters, this issued 300 individual `SELECT ... FROM hanzi_writing_progress WHERE character = ?` queries across the isolate bridge.
2. **Review Filter Mode**:
   - In review mode, the screen retrieved review progress records and then looped sequentially calling `widget.repository.getCharacter(r.character)` to fetch character entity data, generating another N point queries.

### Module Sentences (`sentence_browser_screen.dart` & `sentence_dao.dart`)
1. **Sentence Progress Fetching**:
   - `_loadSentences()` looped across fetched sentences (e.g. 501 items), calling `widget.repository.getProgress(s.id)` sequentially per sentence.
   - For 501 sentences, this generated 501 individual SQLite queries.
2. **Review Mode Fetching**:
   - In review mode, it looped across review items calling `widget.repository.getSentenceById(r.sentenceId)` sequentially.
3. **Internal Sentence Audio Fetching (`sentence_dao.dart`)**:
   - `getSentencesByHskLevel()` and `searchSentences()` queried the `sentences` table (1 query) and then looped over every returned sentence calling `getAudiosForSentence(sentenceId)`.
   - For 30 sentences, this caused 1 + 30 = 31 queries.

---

## 3. Bulk Query Architecture & Design

### 3.1 SQLite Batch Safety & Chunking
SQLite limits the number of host parameters (`SQLITE_MAX_VARIABLE_NUMBER`). To ensure safe execution across older and modern SQLite runtimes without risk of overflow:
- Chunk size is constrained to **300 items per batch** (configurable).
- Batch queries construct parameterized placeholder strings `?` (e.g. `IN (?, ?, ...)`), preventing SQL injection vulnerabilities.
- Inputs are pre-filtered to remove duplicates and blank/empty values before querying.
- If input list is empty or whitespace-only, **0 database queries** are performed.

### 3.2 Implemented Bulk Query APIs

#### Hanzi Module
- **DAO & Repository API**:
  ```dart
  Future<Map<String, HanziWritingProgress>> getProgressForCharacters(
    List<String> characters, {
    int batchSize = 300,
  });
  
  Future<List<HanziCharacter>> getCharactersByGlyphs(
    List<String> characters, {
    int batchSize = 300,
  });
  ```
- **Return Type**: `Map<String, HanziWritingProgress>` keyed by character glyph for O(1) in-memory lookups.

#### Sentence Module
- **DAO & Repository API**:
  ```dart
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(
    List<String> sentenceIds, {
    int batchSize = 300,
  });

  Future<List<SentenceItem>> getSentencesByIds(
    List<String> sentenceIds, {
    int batchSize = 300,
  });

  Future<Map<String, List<SentenceAudio>>> getAudiosForSentences(
    List<String> sentenceIds, {
    int batchSize = 300,
  });
  ```
- **Internal Optimization**:
  - `SentenceDao.getSentencesByHskLevel` and `SentenceDao.searchSentences` now invoke `getAudiosForSentences` once per page instead of per sentence.

---

## 4. UI State Consolidation

In both `hanzi_character_list_screen.dart` and `sentence_browser_screen.dart`:
- Replaced progressive item-by-item updates with a clean pipeline:
  1. Fetch list of items.
  2. Perform single bulk progress query.
  3. Map progress into existing state map in memory.
  4. Call a single consolidated `setState()` (with `mounted` check) to trigger a single UI repaint.

---

## 5. Benchmarks & Verification

The suite `test/features/performance/n_plus_one_optimization_test.dart` verifies query counts using an instrumented `CountingDatabaseExecutor`:

| Scenario | Input Size | Before Optimization | After Optimization | Reduction |
| :--- | :--- | :--- | :--- | :--- |
| **Hanzi Progress (Empty)** | 0 items | 0 queries | **0 queries** | 0% overhead |
| **Hanzi Progress (Single)** | 1 character | 1 query | **1 query** | Parity |
| **Hanzi Progress (Partial)** | 100 characters (50 with progress) | 100 queries | **1 query** | **99.0%** |
| **Hanzi Progress (Page)** | 300 characters | 300 queries | **1 query** | **99.6%** |
| **Hanzi Review Mode Filter** | 20 characters | 20 queries | **1 query** | **95.0%** |
| **Sentence Progress (Single)** | 1 sentence | 1 query | **1 query** | Parity |
| **Sentence Progress (Chunked)** | 501 sentences | 501 queries | **2 queries** (ceil(501/300)) | **99.6%** |
| **Sentence Progress (Large)** | 1,000 sentences | 1,000 queries | **4 queries** (ceil(1000/300)) | **99.6%** |
| **Sentence Internal Audio Join**| 30 sentences with audios | 31 queries (1 + 30) | **2 queries** (1 + 1 bulk) | **93.5%** |
| **Sentence Review Batch Mode** | 3 sentences + audio | 4 queries (3 + 1) | **2 queries** (1 + 1 bulk) | **50.0%** |

### Test Suite Execution
- `test/features/performance/n_plus_one_optimization_test.dart`: 12/12 passing.
- `test/features/hanzi/` & `test/features/sentences/`: 32/32 passing.
- `dart analyze lib test`: 0 errors, 0 warnings.
