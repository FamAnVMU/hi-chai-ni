# QA Bug Tracker – HI Chinese
> **Thread 5 – Quality Assurance, Testing & System Optimization**
> Audit Date: 2026-11-05 | Commit: `ac677f1` | Branch: `main`

---

## Legend

| Mức độ | Mô tả |
|---|---|
| **P0 – Critical** | Crash / Data loss / Security breach. Block release. |
| **P1 – High** | Chức năng quan trọng bị hỏng. Phải fix trước release. |
| **P2 – Medium** | Chức năng bị giảm chất lượng đáng kể. Fix trong sprint tiếp. |
| **P3 – Low** | Vấn đề nhỏ, improvement. Backlog. |
| **P4 – Info** | Ghi chú kỹ thuật / Giới hạn thiết kế, không cần fix. |

| Trạng thái | Ý nghĩa |
|---|---|
| 🔴 OPEN | Chưa fix |
| 🟡 IN_PROGRESS | Đang xử lý |
| ✅ FIXED | Đã fix và xác nhận |
| 🔵 WONTFIX | Giới hạn thiết kế, không fix |

---

## Bug List

---

### BUG-NEW-001 ✅ FIXED
**Mức độ**: P1 – High  
**Trạng thái**: ✅ FIXED (phiên kiểm toán 2026-11-05)  
**Thread**: Thread 1 – Core Engine  

**Tiêu đề**: `Isolate.run()` capture non-sendable DatabaseExecutor gây lỗi startup

**File**: `lib/features/content_packs/data/content_pack_manager.dart:165`

**Mã lỗi gốc**:
```dart
final decoded = await Isolate.run(() {
  return json.decode(rawJson) as Map<String, dynamic>;
});
```

**Root Cause Analysis**:  
`installOrUpdatePack()` dùng `Isolate.run()` để decode JSON. Mặc dù `rawJson` là sendable, Dart's closure capture mechanism bắt toàn bộ context của `installOrUpdatePack()`, trong đó có `_db` (`DatabaseExecutor` / `SqfliteDatabaseBase`) chứa `BasicLock` và internal `Future` state – đây là các object **không thể serialize** qua isolate boundary.

**Lỗi runtime**:
```
Bad state: Illegal argument in isolate message: 
object is unsendable - Library:'dart:async' Class: _Future@5048458
  <- _rawLock in Instance of 'SqfliteDatabaseBase'
```

**Impact**: App startup thất bại khi install HSK2 content pack. Startup Integration Test fail.

**Fix áp dụng**:
```dart
// TRƯỚC (lỗi):
final decoded = await Isolate.run(() {
  return json.decode(rawJson) as Map<String, dynamic>;
});

// SAU (đúng):
final decoded = json.decode(rawJson) as Map<String, dynamic>;
```
Đồng thời xóa `import 'dart:isolate';` không còn dùng.

**Lý do**: JSON decoding của content pack JSON (< 10MB) không đáng kể về CPU. Không cần isolate. Nếu cần isolate thực sự, phải dùng `compute()` từ Flutter với pure top-level function (không capture bất kỳ non-sendable state nào).

**Test xác nhận**: `flutter test test/core/startup/app_startup_integration_test.dart` → PASS

---

### BUG-NEW-002 🔴 OPEN
**Mức độ**: P2 – Medium  
**Trạng thái**: 🔴 OPEN  
**Thread**: Thread 2 – Pedagogy & Learning System  

**Tiêu đề**: `skipLesson()` hardcode `completion_score: 1.0` – bài bị bỏ qua hiện như đã làm thành thạo

**File**: `lib/features/roadmap/data/roadmap_repository.dart:256`

**Mã lỗi**:
```dart
await _db.update(
  'lesson_progress',
  {
    'status': 'skipped',
    'completion_score': 1.0,  // ← BUG: hardcode 1.0
    'completed_at': DateTime.now().toIso8601String(),
  },
  ...
);
```

**Root Cause**: `completion_score: 1.0` ngụ ý người học đã làm bài đạt 100%. Nếu hệ thống Roadmap dùng `completion_score` để tính mastery-based progression hoặc unlock bài tiếp, bài bị skip sẽ hiện như đã hoàn toàn thành thạo.

**Impact**:
- Người dùng có thể skip tất cả bài và hệ thống vẫn hiển thị "mastered"
- Dữ liệu analytics sai lệch (completion_score không phản ánh thực tế)
- Tiềm năng: unlock bài nâng cao mà không học bài nền tảng

**Giải pháp đề xuất**:
```dart
'completion_score': 0.0,  // hoặc một giá trị đặc biệt như -1.0 / null để phân biệt skip vs complete
```
Hoặc thêm cột `skip_reason` và không dùng `completion_score` cho trạng thái skip.

---

### BUG-NEW-003 🔵 WONTFIX (by design – roadmap item)
**Mức độ**: P4 – Info  
**Trạng thái**: 🔵 WONTFIX  
**Thread**: Thread 3 – AI Intelligence & Voice Lab  

**Tiêu đề**: Voice Chat không có STT/ASR thực – chỉ là text chat với audio greeting

**File**: `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart`

**Mô tả**:
- Screen "Voice Chat" record audio qua `AudioRecorderService` nhưng **không có speech-to-text transcription**
- `pubspec.yaml` không có package `speech_to_text` hoặc bất kỳ ASR nào
- Người dùng phải nhập text thủ công vào `TextField` với hint `'Nhập tiếng Trung nếu cần giả lập giọng nói...'`
- TTS (Text-to-Speech) của AI response hoạt động bình thường qua `flutter_tts`

**Impact**: Chức năng "Voice Chat" không phải là voice conversation thực sự. Có thể gây nhầm lẫn cho người dùng.

**Quyết định**: WONTFIX trong phiên này – đây là **roadmap item** (STT integration) chưa được implement. Cần communicate rõ trong UI hoặc feature flag.

**Khuyến nghị cho Thread 3**:
- Rename feature từ "Voice Chat" → "AI Chat" hoặc thêm label "Beta / Text mode"
- Lên kế hoạch tích hợp `speech_to_text` hoặc Gemini Live API cho STT thực sự

---

### BUG-NEW-004 🔴 OPEN
**Mức độ**: P3 – Low  
**Trạng thái**: 🔴 OPEN  
**Thread**: Thread 1 – Core Engine / Database  

**Tiêu đề**: N+1 query trong `getLessonProgressMap()` – 2 DB calls per lesson

**File**: `lib/features/roadmap/data/roadmap_repository.dart:75-121`

**Root Cause**: Với mỗi row `lesson_progress`, hàm thực hiện 2 DB calls tuần tự:
1. `knowledgeRegistry.toCanonicalLessonId(lessonId)` → 1 query
2. `knowledgeRegistry.getAliasesFor(canonicalId)` → 1 query

Với n lesson trong progress: **O(2n) queries**. Với 50 lessons = 100 DB roundtrips.

**Impact**: Roadmap screen load chậm khi người dùng có nhiều lesson trong progress (>20).

**Giải pháp đề xuất**:
```dart
// Batch load: query toàn bộ knowledge_registry một lần
// rồi build in-memory Map<String, String> cho canonical IDs
// và Map<String, List<String>> cho aliases
```
Dùng JOIN query hoặc load tất cả alias records một lần và resolve in-memory.

---

### BUG-NEW-005 🔴 OPEN
**Mức độ**: P3 – Low  
**Trạng thái**: 🔴 OPEN  
**Thread**: Thread 2 – Pedagogy / Thread 4 – UI/UX  

**Tiêu đề**: `LessonDetailSheet.onComplete` bypass anti-cheating F-05 với default score 0.8

**File**: `lib/features/roadmap/presentation/widgets/lesson_detail_sheet.dart:340`

**Mã lỗi**:
```dart
// Nút "Xác nhận hoàn thành bài học"
onComplete: () {
  completeLesson(
    lessonId: lesson.id,
    score: progress?.score ?? 0.8,  // ← Nếu progress null → score = 0.8 mặc định
  );
},
```

**Root Cause**: Khi `progress` là null (bài chưa được học), nút "Complete" thủ công gửi `score = 0.8`. Anti-cheating F-05 trong `lesson_flow_providers.dart` chỉ guard khi đến từ luồng học bài chính thức (quiz/exercise completion). Manual complete từ `LessonDetailSheet` không đi qua guard này.

**Impact**: Người dùng có thể "complete" bất kỳ bài nào từ Roadmap sheet mà không học, với score 0.8 (giả).

**Giải pháp đề xuất**:
```dart
// Option 1: Disable nút nếu chưa bắt đầu học
enabled: progress != null && progress.status == 'in_progress',

// Option 2: Gọi completeLesson với score = 0.0 nếu progress null
score: progress?.score ?? 0.0,

// Option 3: Route qua anti-cheating validation trong completeLesson()
```

---

### BUG-NEW-006 ✅ FIXED
**Mức độ**: P3 – Low  
**Trạng thái**: ✅ FIXED (phiên kiểm toán 2026-11-05)  
**Thread**: All / Thread 4  

**Tiêu đề**: `pubspec.yaml` version `1.0.9+10` không khớp với APK build `1.0.11+11`

**File**: `pubspec.yaml:19`

**Mô tả**: APK build với `--build-name=1.0.11 --build-number=11` nhưng source vẫn là `1.0.9+10`. Gây inconsistency giữa source code và artifact.

**Fix**: `pubspec.yaml` cập nhật thành `version: 1.0.11+11`.

Đồng thời cập nhật `ContentPackManager.currentAppVersion = '1.0.11'`.

---

## Summary Dashboard

| ID | Tiêu đề | Mức độ | Thread | Trạng thái |
|---|---|---|---|---|
| BUG-NEW-001 | Isolate.run() non-sendable DatabaseExecutor | P1 | T1 | ✅ FIXED |
| BUG-NEW-002 | skipLesson() hardcode score 1.0 | P2 | T2 | 🔴 OPEN |
| BUG-NEW-003 | Voice Chat no STT/ASR | P4 | T3 | 🔵 WONTFIX |
| BUG-NEW-004 | N+1 query getLessonProgressMap | P3 | T1 | 🔴 OPEN |
| BUG-NEW-005 | LessonDetailSheet bypass anti-cheating | P3 | T2/T4 | 🔴 OPEN |
| BUG-NEW-006 | pubspec.yaml version mismatch | P3 | All | ✅ FIXED |

---
*Bug Tracker maintained by Thread 5 – QA Engineer | Last updated: 2026-11-05*
