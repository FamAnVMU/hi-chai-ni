# QA Optimization Report – HI Chinese
> **Thread 5 – Quality Assurance, Testing & System Optimization**
> Audit Date: 2026-11-05 | Commit: `ac677f1` | Branch: `main`

---

## Tóm tắt

Báo cáo này tổng hợp các cơ hội tối ưu hóa hiệu năng, cấu trúc mã, và bảo trì cho HI Chinese v1.0.11. Các khuyến nghị được phân loại theo mức độ ưu tiên và tác động.

---

## 1. Database Query Optimization (Priority: High)

### OPT-001 – Batch Resolution thay cho N+1 trong `getLessonProgressMap()`

**File**: `lib/features/roadmap/data/roadmap_repository.dart:75-121`  
**Mức độ tác động**: Cao (ảnh hưởng trực tiếp trải nghiệm người dùng)

**Vấn đề hiện tại**:
Với n lesson trong progress, hệ thống thực hiện 2×n DB queries:
```
Lesson 1 → toCanonicalLessonId() → query #1
Lesson 1 → getAliasesFor()       → query #2
Lesson 2 → toCanonicalLessonId() → query #3
...
```

**Giải pháp đề xuất**:
```dart
// Thay vì loop per-lesson, batch load toàn bộ:

// 1. Lấy toàn bộ canonical mappings một lần
final allCanonicalRows = await _db.query(
  'knowledge_registry',
  columns: ['alias_id', 'canonical_id'],
);
final aliasToCanonical = {
  for (final r in allCanonicalRows)
    r['alias_id'] as String: r['canonical_id'] as String,
};

// 2. Lấy toàn bộ aliases một lần
final allAliasRows = await _db.query('knowledge_registry');
final canonicalToAliases = <String, List<String>>{};
for (final r in allAliasRows) {
  final canonical = r['canonical_id'] as String;
  canonicalToAliases.putIfAbsent(canonical, () => []).add(r['alias_id'] as String);
}

// 3. Resolve in-memory (O(1) per lesson)
for (final row in progressRows) {
  final lessonId = row['lesson_id'] as String;
  final canonicalId = aliasToCanonical[lessonId] ?? lessonId;
  final aliases = canonicalToAliases[canonicalId] ?? [];
  ...
}
```

**Expected improvement**: O(2n) → O(2) DB queries, ~50x faster với 50 lessons.

---

### OPT-002 – Index thiếu trên `lesson_progress.lesson_id`

**File**: Schema hiện tại (migration files)  
**Mức độ tác động**: Trung bình

`lesson_progress` được query thường xuyên theo `lesson_id`:
```sql
SELECT * FROM lesson_progress WHERE lesson_id = ?
```

**Khuyến nghị**:
```sql
-- Thêm trong migration v18 (nếu có):
CREATE INDEX IF NOT EXISTS idx_lesson_progress_lesson_id 
ON lesson_progress(lesson_id);
```

---

## 2. JSON Parsing Safety (Priority: Medium)

### OPT-003 – Thêm size limit cho Content Pack JSON

**File**: `lib/features/content_packs/data/content_pack_manager.dart`

**Vấn đề**: Hiện không có kiểm tra kích thước của `rawJson` trước khi decode. JSON > 50MB decode trên main thread có thể gây jank.

**Giải pháp đề xuất**:
```dart
Future<ContentPackInstallResult> installOrUpdatePack(
  String rawJson, {
  bool isBundled = false,
}) async {
  // Guard against very large JSON
  const maxJsonBytes = 20 * 1024 * 1024; // 20MB
  if (rawJson.length > maxJsonBytes) {
    // Use compute() for large payloads
    final decoded = await compute(
      (String json) => jsonDecode(json) as Map<String, dynamic>,
      rawJson,
    );
    // ... continue with decoded
  } else {
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    // ... continue
  }
}
```

**Lý do**: `compute()` dùng top-level/static function (sendable), tránh được bug BUG-NEW-001.

---

## 3. Package Updates (Priority: Low)

### OPT-004 – 17 packages có phiên bản mới

`flutter pub outdated` phát hiện 17 package có thể nâng cấp:

| Package | Version hiện tại | Version mới nhất |
|---|---|---|
| `cupertino_icons` | 1.0.9 | 2.0.0 |
| `sqlite3` | 3.5.2 | 3.8.0 |
| `sqflite_common` | 2.5.14 | 2.5.15 |
| `test_api` | 0.7.12 | 0.7.15 |
| `vector_math` | 2.4.0 | 2.4.4 |
| `meta` | 1.18.3 | 1.19.0 |
| `jni` | 1.1.1 | 1.1.2 |
| `objective_c` | 9.5.0 | 9.6.3 |
| `hooks` | 2.0.2 | 2.2.0 |
| `code_assets` | 1.2.1 | 2.1.0 |
| *...* | *...* | *...* |

**Khuyến nghị**: Nâng cấp theo nhóm, test sau mỗi nhóm. Ưu tiên security-related packages trước.

> [!WARNING]
> `cupertino_icons 2.0.0` là **major version** – có thể có breaking changes về icon names. Test kỹ trên iOS trước khi upgrade.

---

## 4. Code Quality Improvements (Priority: Low)

### OPT-005 – Silent `catch (_) {}` trong ContentPackManager

**File**: `lib/features/content_packs/data/content_pack_manager.dart`

Phát hiện các khối:
```dart
try {
  parsedContent = item['content_json'] is Map<String, dynamic>
      ? ...
      : json.decode(rawContentJson) as Map<String, dynamic>;
} catch (_) {}  // ← Silent catch
```

**Vấn đề**: Nếu JSON malformed, lỗi bị nuốt hoàn toàn. Content item sẽ bị bỏ qua mà không có log.

**Giải pháp**:
```dart
} catch (e, stack) {
  debugPrint('[ContentPackManager] Failed to parse content_json for item $itemId: $e\n$stack');
  // rethrow hoặc add to error report
}
```

---

### OPT-006 – Voice Chat UX: Text-only mode indicator

**File**: `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart`

**Vấn đề**: Không có STT thực nhưng UI vẫn có "recording" indicator gây nhầm lẫn.

**Giải pháp**:
- Thêm banner/chip: `🎤 Text mode (Voice AI coming soon)`
- Rename tiêu đề từ "Voice Chat" → "AI Conversation"
- Ẩn recording animation khi không có STT

---

## 5. Architecture Improvements (Priority: Medium)

### OPT-007 – Thêm `skipLesson()` với score phù hợp

**File**: `lib/features/roadmap/data/roadmap_repository.dart`

Thay vì hardcode `completion_score: 1.0`, dùng hằng số có ý nghĩa:
```dart
static const double kSkippedLessonScore = 0.0; // or null

await _db.update('lesson_progress', {
  'status': 'skipped',
  'completion_score': kSkippedLessonScore,
  'skipped_at': DateTime.now().toIso8601String(),
  'completed_at': null,
  ...
});
```

---

### OPT-008 – Add `RoutingGuard` cho LessonDetailSheet complete button

**File**: `lib/features/roadmap/presentation/widgets/lesson_detail_sheet.dart`

Thêm guard:
```dart
onComplete: progress == null || progress.status == 'not_started'
    ? null  // Disable button nếu chưa học
    : () => completeLesson(lessonId: lesson.id, score: progress.score),
```

---

## Tổng kết Optimization Matrix

| ID | Mô tả | Tác động | Nỗ lực | Ưu tiên |
|---|---|---|---|---|
| OPT-001 | Batch resolve N+1 getLessonProgressMap | High | Medium | 🔴 P1 |
| OPT-002 | Index lesson_progress.lesson_id | Medium | Low | 🟡 P2 |
| OPT-003 | Size guard cho JSON decode | Medium | Low | 🟡 P2 |
| OPT-004 | Update 17 packages | Low | Medium | 🟢 P3 |
| OPT-005 | Log silent catch blocks | Medium | Low | 🟡 P2 |
| OPT-006 | Voice Chat UX – text mode indicator | Low | Low | 🟢 P3 |
| OPT-007 | skipLesson() correct score | Medium | Low | 🟡 P2 |
| OPT-008 | LessonDetailSheet routing guard | Medium | Low | 🟡 P2 |

---
*Optimization Report by Thread 5 – QA Engineer | 2026-11-05*
