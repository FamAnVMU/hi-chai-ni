# Round 2 — Audit HIỆU NĂNG / BẤT ĐỒNG BỘ / VÒNG ĐỜI TÀI NGUYÊN

**Repo**: `C:\Users\phama\Downloads\hi_chinese` (Flutter/Dart, HSK app; 348 file trong `lib`)
**Người thực hiện**: scout-perf (task-4)
**Phạm vi**: `lib/core/audio/**`, `lib/core/startup/**`, `lib/core/network/ai/**`, `lib/features/{audio_management,listening,shadowing,pronunciation,sentences,vocabulary_srs,review,ai_tutor,home,hanzi}/**`, toàn bộ Riverpod provider có async/Timer/Subscription, đường khởi động, rebuild storm.
**Phương pháp**: đọc mã nguồn thực tế + grep đối chứng (bằng chứng "không có cleanup" luôn kèm grep); đọc source package trong `pub pub-cache` để xác minh hành vi thư viện; **không sửa file nào**, không chạy flutter/dart (Lead & QA sở hữu).

**Phiên bản thư viện quyết định hành vi** (từ `pubspec.lock`):
| Package | Version | Dùng để xác minh |
|---|---|---|
| `just_audio` | **0.10.6** | tần số `positionStream` (PERF-06) |
| `record` | **7.1.2** | `onAmplitudeChanged` / `getAmplitude` (PERF-07) |
| `flutter_tts` | **4.2.5** | vòng đời TTS |
| `sqflite` | **2.4.5** | tính chất tuần tự của truy vấn (PERF-12/13/14) |
| `flutter_riverpod` / `riverpod` | **3.4.3** | `autoDispose` vẫn **opt-in** (`isAutoDispose: true`), provider thường = sống suốt app; `==` filtering; auto-retry provider lỗi (PERF-01/03/09) |
| `web_socket_channel` | 3.0.3 | **không có chỗ nào dùng trong `lib/`** (chỉ SSE HTTP) |

**Ghi chú tin cậy**: các con số thời gian (ms) trong báo cáo là **ước tính từ độ phức tạp tĩnh** (số dòng/kích thước asset/số vòng lặp), *chưa đo trên thiết bị* — nơi cần đo thật được đánh dấu **cần xác minh**. Các con số đếm (dung lượng asset, số dòng DB, số lần gọi hàm) là số liệu thực tế đọc được.

---

## Bảng xếp hạng (theo tác động người dùng)

| ID | Mức | Vị trí | Tác động 1 dòng |
|---|---|---|---|
| PERF-01 | **Critical** | `home_providers.dart:21` + `srs_providers.dart:105` + `home_repository.dart:192-199,250-257,273-278` | Mỗi lượt chấm SRS kéo 2 lần nạp lại Home = 2 full-table scan + O(n×m) trên UI isolate, tăng tuyến tính theo lịch sử học |
| PERF-02 | **High** | `hanzi_repository.dart:154-160`, `sentence_repository.dart:140-146`, `grammar_repository.dart:53-56` | Parse 7,7 MB / 3,5 MB JSON trên UI isolate ở lần mở đầu → đứng hình 0,3–1,5 s/lần (cần xác minh) |
| PERF-03 | **High** | `ai_tutor_voice_chat_screen.dart:67-75`, `ai_tutor_tab_screen.dart:266-268`, `ai_tutor_providers.dart:50-79` | Rời màn voice/đổi mode không kết thúc phiên → micro vẫn thu, `.m4a` lớn ~57 MB/giờ |
| PERF-04 | **High** | `gemini_rest_ai_provider.dart:248-256` + `voice_conversation_service.dart:455-461` | Request AI voice không huỷ được → turn cũ chạy tiếp sau teardown: phát audio "ma", bật lại micro, status sai |
| PERF-05 | **High** | `hanzi_writing_screen.dart:62-64` + `hanzi_character_painter.dart:56-93` + `svg_path_parser.dart:126-159` | `setState()` mỗi frame + parse lại toàn bộ SVG path mỗi lần paint → rớt frame khi xem thứ tự nét |
| PERF-06 | **High** | `listening_providers.dart:123-125` + `listening_screen.dart:45,252-382` | `positionStream` 16–200 ms (tới ~60 lần/s) rebuild cả màn Listening + dựng lại toàn bộ câu hỏi |
| PERF-07 | **Med** | `audio_recorder_service.dart:173-203,241-256` + 3 screen recorder | Amplitude phát 2 lần/100 ms và mỗi mẫu `setState` toàn màn hình (10–20 lần/s) |
| PERF-08 | **Med** | `ai_tutor_text_chat_screen.dart:92-101,147-155` | Mỗi chunk SSE: `setState` + `animateTo(250ms)` mới → scroll giật, rebuild liên tục khi AI trả lời |
| PERF-09 | **Med** | `app_shell.dart:104-113` + `ai_tutor_voice_chat_screen.dart:37` + `ai_tutor_providers.dart:43-79` | 5 tab + 3 engine audio native (player/recorder/TTS) được tạo ngay khi shell mount dù chưa dùng |
| PERF-10 | **Med** | `audio_temp_cleaner.dart:33-58` + `app_startup_provider.dart:94-98,197` | Startup quét filesystem **đồng bộ** trên UI isolate + delay nhân tạo 50 ms trước khi ready |
| PERF-11 | **Med** | `audio_pack_downloader.dart:87-168` + `audio_pack_manager.dart:210-241` | Tải audio pack tuần tự tới 2.600 request (4–13 phút), cancel không dừng request, sau đó 300 UPDATE đơn lẻ + sha256 đồng bộ |
| PERF-12 | **Med** | `audio_coverage_auditor.dart:30-35,66-84` | N+1 `File.exists()` tuần tự (hàng nghìn syscall) trên UI isolate, chạy lại sau mỗi lần download/delete |
| PERF-13 | **Med** | `chat_dao.dart:46-53` + `ai_tutor_repository.dart:203,306` + `voice_conversation_service.dart:171-194` | Mỗi lượt chat đọc lại **toàn bộ** lịch sử (không LIMIT) đưa vào prompt; transcript copy full list mỗi cập nhật (O(n²)/phiên) |
| PERF-14 | **Med** | `hanzi_character_list_screen.dart:44-77` + `sentence_browser_screen.dart:52-85` | Tìm kiếm không debounce: 2 query DB + 2 `setState` mỗi phím, không guard thứ tự kết quả |
| PERF-15 | **Low** | `audio_player_service.dart:170-194` | Mỗi lần phát audio asset: đọc **toàn bộ** file để kiểm tra tồn tại rồi just_audio đọc lại lần 2 |

---

# Findings chi tiết

### PERF-01 [Critical] Mỗi lượt chấm điểm SRS kéo theo 2 lần nạp lại Home dashboard, gồm 2 full-table scan và vòng lặp O(n×m)

**Vị trí**
- `lib/features/home/presentation/providers/home_providers.dart:19-31`
- `lib/features/vocabulary_srs/presentation/providers/srs_providers.dart:27-37, 73-105`
- `lib/features/home/data/home_repository.dart:192-199, 250-257, 273-278, 362-427`

**Mã lỗi**
```dart
// home_providers.dart:19-30 — build() của HomeDashboardNotifier
Future<HomeDashboardData> build() async {
  // Re-evaluate if srsDueCount changes or profile changes
  ref.watch(srsDueCountProvider);
  ...
  return await repo.getDashboardData(...);
}

// srs_providers.dart:27-36 — refreshCount() phát HAI trạng thái
Future<void> refreshCount() async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async { ... });

// srs_providers.dart:105 — gọi sau MỖI thẻ được chấm
ref.read(srsDueCountProvider.notifier).refreshCount();

// home_repository.dart:192-199 — KHÔNG có LIMIT / cửa sổ thời gian
final activityRows = await _db.rawQuery('''
  SELECT id, activity_type, duration_seconds, items_count, activity_date, created_at
  FROM ${DatabaseConstants.tableLearningActivities}
  WHERE activity_type NOT IN ('sample_data', 'seed')
  ORDER BY created_at ASC
  ''');

// home_repository.dart:250-257 — KHÔNG có LIMIT, kéo cả cột TEXT metadata_json
final evidenceRows = await _db.rawQuery('''
  SELECT id, content_id, content_type, source, score, duration_ms, metadata_json, created_at
  FROM ${DatabaseConstants.tableLearnerEvidence}
  WHERE source NOT IN ('sample_data', 'seed')
  ORDER BY created_at ASC
  ''');

// home_repository.dart:273-278 — O(evidence × activities)
final isEnclosed = validActivities.any((act) {
  if (act.localDate != localDate) return false;
  ...
  return parsedUtc.isAfter(start) && parsedUtc.isBefore(end);
});
```

**Nguyên nhân gốc rễ**
1. `HomeDashboardNotifier.build()` `watch` toàn bộ `srsDueCountProvider` (một con số) thay vì `select` — nên **mọi** thay đổi due-count đều invalidate toàn bộ dashboard.
2. `refreshCount()` phát `loading` rồi `data` ⇒ **2 lần** invalidate liên tiếp cho **1** lần chấm thẻ.
3. `getDashboardData()` (8 truy vấn: tên, HSK, 2 scan không LIMIT, streak, srs `forceRefresh:true`, roadmap 3 query, recent activities 2 query) chạy lại trên UI isolate; bước dedup là vòng lặp lồng `any()`.
4. Kết quả không có cache: mỗi lượt chấm thẻ trong màn Review lại gọi `refreshCount()` (`srs_providers.dart:105`).

**Kịch bản & tác động (đo được)**
- Kịch bản: người dùng học 1 tháng (giả sử 500 activity + 5.000 evidence — bảng `learner_evidence` có `metadata_json` TEXT nên rất nặng; DB dev hiện có 18,0 MB dù mới chỉ có bảng grammar/hanzi/sentences). Mỗi lần bấm 1 trong 4 nút đánh giá thẻ SRS → **2 lần** `getDashboardData`.
- Số phép so sánh thực hiện: **2 × (5.000 × 500) = 5.000.000** lượt `isAfter/isBefore` + 2 lần đọc full bảng `learner_evidence` (kèm TEXT) + 2 lần đọc full `learning_activities` + ~14 query khác — **tất cả trên UI isolate**, dù màn Home đang bị che (IndexedStack vẫn giữ sống).
- Thời gian phản hồi của nút đánh giá tăng tuyến tính theo lịch sử học; sau vài tháng dữ liệu, mỗi lần chấm thẻ có thể gây khựng 1 khung hình hoặc hơn (**cần xác minh trên thiết bị** bằng DevTools CPU profiler).
- Đây là "hidden cost" khó thấy khi test vì DB test nhỏ.

**Bản vá**
1. Tách provider: `homeDashboardProvider` không watch trực tiếp due-count; thay bằng `ref.listen(srsDueCountProvider.select((v) => v.value), ...)` + debounce 500 ms, hoặc để màn Review chủ động `invalidate(homeDashboardProvider)` khi kết thúc phiên (không phải từng thẻ).
2. `refreshCount()` chỉ phát **một** trạng thái: `state = await AsyncValue.guard(...)` (bỏ `AsyncValue.loading()`), hoặc dùng `state = AsyncData(...)` sau khi có kết quả.
3. `getSanitizedStudySessionsAndStats`: thêm `WHERE created_at >= ?` (90 ngày) + `LIMIT`, và bỏ dedup `any()` bằng cách sort `validActivities` theo `timestampUtc` rồi binary-search cửa sổ, hoặc làm phép đếm trong SQL (`GROUP BY date(created_at)`).
4. Cache dashboard trong 30–60 s và chỉ refresh khi có activity mới.

---

### PERF-02 [High] JSON 7,7 MB + 3,5 MB được parse trên UI isolate ở lần mở Hanzi/Sentence/Grammar đầu tiên

**Vị trí**
- `lib/features/hanzi/data/hanzi_repository.dart:146-169`
- `lib/features/sentences/data/sentence_repository.dart:132-154`
- `lib/features/grammar/data/grammar_repository.dart:46-70` (+ gọi tại `:206, :226, :274`)
- Asset: `assets/data/hanzi_stroke_data.json` = 8.629.414 bytes; `assets/data/sentences_corpus.json` = 3.566.000 bytes; `assets/data/hsk_grammar_all.json` = 3.508.000 bytes

**Mã lỗi**
```dart
// hanzi_repository.dart:153-160
final jsonString = await rootBundle.loadString(assetPath);
final data = jsonDecode(jsonString) as Map<String, dynamic>;   // <-- UI isolate
final rawChars = data['characters'] as List;
final characters = rawChars
    .map((item) => HanziCharacter.fromJson(item as Map<String, dynamic>))
    .toList();
await _dao.insertCharactersBatch(characters);
```
```dart
// sentence_repository.dart:140-146
final jsonString = await rootBundle.loadString(assetPath);
final data = jsonDecode(jsonString) as Map<String, dynamic>;   // <-- UI isolate
final rawSentences = data['sentences'] as List;
final sentences = rawSentences.map((item) => SentenceItem.fromJson(...)).toList();
```
```dart
// grammar_repository.dart:53-56
final jsonStr = await rootBundle.loadString('assets/data/hsk_grammar_all.json');
final decoded = json.decode(jsonStr) as List<dynamic>;          // <-- UI isolate
final items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
```

**Nguyên nhân gốc rễ**
Ba repository tự-seed dữ liệu từ asset lớn bằng `jsonDecode` + map model **ngay trên isolate UI**, chỉ khi bảng tương ứng rỗng (`_isSeeded == false`). Grep toàn `lib/`: `Isolate.run` chỉ có **4 chỗ** (`seed_loader.dart:71`, `content_pack_manager.dart:165`, `audio_pack_manager.dart:187,223`) và **không có `compute(` nào** → 3 đường này chưa được offload. (Việc `AssetBundle.loadString` offload UTF-8 cho asset > 50 KB đã được round-1 xác minh; phần tốn CPU còn lại là `jsonDecode` + mapping + batch insert.)

**Kịch bản & tác động (đo được)**
- Kịch bản: cài mới → Từ điển → bấm "Kho chữ Hán & Luyện viết" (`dictionary_screen.dart:155-170`) → `HanziCharacterListScreen.initState` → `getCharactersByHskLevel` → `_checkAndSeed()` → `ensureSeedLoaded()`.
- Dữ liệu thực tế: asset 8,63 MB chứa **2.632** chữ Hán (đối chiếu DB dev: `hanzi_characters = 2632`) ⇒ trung bình **~3,3 KB/chữ**; asset câu 3,57 MB chứa **1.500** câu (DB dev: `sentences = 1500`) ⇒ **~2,4 KB/câu**.
- Trong lúc `jsonDecode` 7,7–8,6 MB + map 2.632 object + insert batch chạy, UI isolate bị chặn hoàn toàn → không thể render frame; ước tính **0,3–1,5 s** trên máy tầm trung (`cần xác minh` bằng trace). Trên máy yếu có thể vượt ngưỡng ANR 5 s khi cộng cả `loadString` + batch insert.
- Với Sentence Browser (`sentence_browser_screen.dart:40-44`), cùng cơ chế với 3,5 MB; Grammar mở lần đầu (`grammar_repository.dart:206`) với 3,5 MB.
- Người dùng cảm nhận: bấm vào là "treo", thậm chí rơi frame của animation chuyển màn.

**Bản vá**
```dart
// Ví dụ Hanzi: decode + map trong background, trả về List<Map> thuần
final raw = await rootBundle.loadString(assetPath);
final characters = await Isolate.run(() {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (data['characters'] as List)
      .map((e) => HanziCharacter.fromJson(e as Map<String, dynamic>))
      .toList();
});
```
Áp dụng cùng mẫu cho Sentence/Grammar (hoặc chuyển 3 asset sang SQLite seed lúc startup trong `SeedLoader` vốn đã có isolate); hiển thị skeleton + tiến trình khi seed lần đầu.

---

### PERF-03 [High] Rời màn Voice / đổi mode Text↔Voice không kết thúc phiên: micro vẫn thu, file `.m4a` tiếp tục lớn

**Vị trí**
- `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart:67-75`
- `lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart:244-248, 266-268, 297-303`
- `lib/features/ai_tutor/presentation/providers/ai_tutor_providers.dart:50-79`
- `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:338-395` (đặc biệt `:393`)

**Mã lỗi**
```dart
// ai_tutor_voice_chat_screen.dart:67-75 — dispose KHÔNG gọi endSession/stopRecording
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _statusSub?.cancel();
  _transcriptSub?.cancel();
  _scrollController.dispose();
  _speechInputController.dispose();
  super.dispose();
}
```
```dart
// ai_tutor_tab_screen.dart:266-268 — đổi mode Text <-> Voice KHÔNG abort phiên
onSelectionChanged: (Set<AiTutorMode> newSelection) {
  ref.read(aiTutorModeProvider.notifier).setMode(newSelection.first);
},
```
```dart
// ai_tutor_providers.dart:50-79 — Provider thường (không autoDispose) => sống suốt app
final aiTutorAudioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = DefaultAudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});
```
```dart
// voice_conversation_service.dart:393
await recorder.startRecording();
```

**Nguyên nhân gốc rễ**
- `AiTutorVoiceChatScreen` được đặt trong `IndexedStack` (`ai_tutor_tab_screen.dart:297-303`) nên khi đổi mode Text/Voice nó **không bị dispose** — nhưng cũng không có chỗ nào abort phiên. `_abortActiveVoiceAndAudio()` chỉ được gọi khi **đổi bottom tab** (`ai_tutor_tab_screen.dart:244-248`) hoặc `deactivate/dispose` của tab cha.
- `dispose()` của màn voice không gọi `service.endSession()` (grep `endSession` toàn `lib/`: chỉ có 1 caller là nút bấm `_endVoiceSession` tại `ai_tutor_voice_chat_screen.dart:113-118`).
- Riverpod 3.4.3: `autoDispose` vẫn opt-in; `voiceConversationServiceProvider` và các provider recorder/player/TTS đều không autoDispose ⇒ service + recorder sống tới khi app đóng.

**Kịch bản & tác động (đo được)**
1. Vào tab AI → "Hội thoại" → bấm bắt đầu phiên (mic recording bắt đầu, `voice_conversation_service.dart:393`).
2. Bấm "Nhắn tin" (đổi mode) hoặc `Navigator.pop` khỏi màn hình.
3. `DefaultAudioRecorderService` vẫn `Timer.periodic(100ms)` + `onAmplitudeChanged` chạy; file ghi AAC-LC 16 kHz/128 kbps (`audio_recorder_service.dart:159-164`) tiếp tục được ghi.
- Tốc độ lớn file: 128 kbps ≈ **16 KB/s ≈ 57 MB/giờ**; pin bị tiêu thêm; user không thấy bất kỳ chỉ báo nào (UI đã đổi mode/đã rời màn).
- Micro chỉ được nhả khi: bấm "Kết thúc", đổi bottom tab, hoặc app vào background (qua `AppLifecycleManager`). Trong trường hợp user chỉ chuyển sang xem tab khác → tab switch có abort (OK); nhưng **đổi mode trong tab AI** và **màn hình voice bị pop** thì không.
- Đây là vi phạm kỳ vọng quyền riêng tư (mic sau khi rời màn hình) + rò rỉ dung lượng, không phải chỉ là "chậm".

**Bản vá**
- Trong `dispose()` của `AiTutorVoiceChatScreen`: `final s = ref.read(voiceConversationServiceProvider); s.endSession();` (hoặc thêm `stopListening()` + `cancelCurrentTurn()`).
- Trong `onSelectionChanged` của `SegmentedButton`: nếu `prev == voice` → `await voiceService.endSession()` trước khi đổi mode.
- Cân nhắc `Provider(isAutoDispose: true)` cho stack voice + `ref.keepAlive()` trong lúc phiên active, để rời màn hình là dispose.

---

### PERF-04 [High] Request AI voice không thể huỷ; turn cũ tiếp tục chạy sau `endSession`/`dispose` → audio "ma", bật lại micro, status nhảy về `listening`

**Vị trí**
- `lib/core/network/ai/providers/gemini_rest_ai_provider.dart:248-256, 292-303` (`generateText` — đường voice dùng)
- `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:397-462` (`submitSpeechInput`), `:510-521` (`endSession`), `:523-541` (`_onLifecycleAbort`)

**Mã lỗi**
```dart
// gemini_rest_ai_provider.dart:248-256 — chỉ kiểm tra token TRƯỚC mỗi lần thử,
// không huỷ được POST đang bay (timeout 30s)
while (true) {
  if (cancelToken?.isCancelled ?? false) {
    throw const AiCancelledException();
  }
  try {
    final httpResponse = await _client
        .post(uri, headers: headers, body: bodyJson)
        .timeout(timeout);
```
```dart
// voice_conversation_service.dart:455-461 — sau khi lỗi/huỷ vẫn "hồi sinh" phiên
} catch (e) {
  debugPrint('[VoiceConversationService] Speech turn error: $e');
  _setStatus(VoiceConversationStatus.reconnecting);
  await Future.delayed(const Duration(milliseconds: 800));
  _setStatus(VoiceConversationStatus.listening);      // <-- kể cả khi đã endSession/dispose
  await recorder.resumeRecording();                   // <-- bật lại mic
}
```

**Nguyên nhân gốc rễ**
1. `submitSpeechInput` dùng `repository.sendMessage` → `aiService.generateText` (non-stream) → `_client.post(...)` là một `Future` **không có handle để huỷ**; `CancelToken` chỉ được check ở biên vòng retry. Vì vậy `cancelCurrentTurn()`/`interrupt()`/`endSession()` **không dừng** request — response sẽ về sau 0,1–30 s.
2. Khi response/lỗi về, `submitSpeechInput` không kiểm tra "phiên còn active không" (không có generation counter / `_activeSessionId == null` check), nên tiếp tục: `_addTranscript`, `player.play(assetUri)` (`:436-441`), `_setStatus`, `recorder.resumeRecording()`.
3. Đường stream (`streamText`) thì có huỷ thật (`gemini_rest_ai_provider.dart:362-380`), nhưng đường voice lại không dùng nó.

**Kịch bản & tác động (đo được)**
1. Trong phiên voice, user nói → `submitSpeechInput` → request AI (độ trễ mạng 2–10 s).
2. User bấm "Kết thúc" hoặc thoát màn hình ngay lập tức.
3. 0,1–30 s sau: service phát file mẫu persona qua `player.play` (âm thanh phát ra dù phiên đã kết thúc), ghi transcript "assistant" vào bộ nhớ, set status về `listening`, và gọi `recorder.resumeRecording()` → **micro có thể bật lại sau khi user đã rời màn hình**.
4. Nếu request thành công muộn, còn ghi thêm 1 lượt assistant vào SQLite + evidence (`ai_tutor_repository.dart:344-365`) → dữ liệu sai (lượt hội thoại "ma").
- Tác động đo được: 1 audio phát ngoài ý muốn/mỗi lần teardown giữa turn; 1 record assistant + evidence ghi thừa; mic-on ngoài màn hình (pin + riêng tư). Ngoài ra token API vẫn bị tính cho request không ai nhận.

**Bản vá**
- Dùng `http.StreamedRequest` + `sink.close()` khi cancel, hoặc đổi voice sang `sendMessageStream` (đã có huỷ thật) và chỉ chờ kết quả cuối.
- Thêm vào `DefaultVoiceConversationService`: `int _turnGeneration = 0;` — tăng ở mỗi `submitSpeechInput`/`endSession`; sau **mỗi** `await` kiểm tra `if (gen != _turnGeneration || _activeSessionId == null) return;` trước khi add transcript/play/resumeRecording.
- `endSession()` phải set cờ `_ended = true` và mọi callback async check cờ này.

---

### PERF-05 [High] Animation nét chữ Hán: `setState()` mỗi frame và parse lại toàn bộ SVG path mỗi lần `paint`

**Vị trí**
- `lib/features/hanzi/presentation/screens/hanzi_writing_screen.dart:57-70` (đặc biệt `:62-64`)
- `lib/features/hanzi/presentation/painters/hanzi_character_painter.dart:50-93`
- `lib/features/hanzi/domain/engine/svg_path_parser.dart:126-159` (`_tokenize`)
- `lib/features/hanzi/presentation/widgets/hanzi_writing_canvas.dart:141-170` (2 painter chồng nhau)

**Mã lỗi**
```dart
// hanzi_writing_screen.dart:62-64 — mỗi frame animation gọi setState toàn màn hình
_animController.addListener(() {
  setState(() {});
});
```
```dart
// hanzi_character_painter.dart:56-64 — parse lại TẤT CẢ nét mỗi lần paint
for (int i = 0; i < character!.strokes.length; i++) {
  final path = SvgPathParser.parse(
    character!.strokes[i],
    width: width, height: height, padding: padding,
  );
  canvas.drawPath(path, outlinePaint);
}
// :75-80 (nét đã vẽ) và :88-93 (nét đang vẽ) — parse lại lần nữa
```
```dart
// svg_path_parser.dart:130-152 — tokenize từng ký tự + double.tryParse từng số
for (int i = 0; i < pathString.length; i++) {
  final char = pathString[i];
  if ('MLQCZmlqcz'.contains(char)) { ... }
  ...
}
```

**Nguyên nhân gốc rễ**
- `AnimationController.addListener` gọi `setState(() {})` không thay đổi state nào → rebuild toàn bộ `HanziWritingScreen` ở 60 fps trong suốt 700 ms/nét.
- `HanziCharacterPainter.paint` không cache `Path`: mỗi lần repaint (mỗi frame) parse lại **toàn bộ** strokes cho cả painter chính (outline + nét xong) **và** painter hint thứ hai.
- `SvgPathParser` tạo `List<String>` tokens + `double.tryParse` cho từng số, cấp phát rất nhiều object ngắn hạn mỗi lần gọi.

**Kịch bản & tác động (đo được)**
- Kịch bản: mở `HanziWritingScreen` ở mode Learn → animation vẽ 1 chữ 12 nét, mỗi nét 700 ms.
- Số phép parse/frame: outline 12 + nét đã vẽ ~12 + nét đang vẽ 1 = **~25 lần `SvgPathParser.parse`/frame** (×2 nếu bật hint). Mỗi path điển hình 100–300 số ⇒ **~2.500–7.500 `double.tryParse` + tokenize hàng nghìn ký tự mỗi frame**; @60 fps ≈ **150.000–450.000 phép parse số/giây** + GC liên tục.
- Hệ quả: frame budget 16,6 ms bị ăn bởi parse + allocation → rớt frame đúng lúc người dùng đang xem demo thứ tự nét (màn hình này là trọng tâm luyện viết). `cần xác minh` mức rớt frame bằng DevTools Performance (chạy profile mode).

**Bản vá**
1. Cache path theo `(strokeIndex, size, padding)` — `Map<String, Path>` trong State/painter hoặc `late final List<Path>` dựng 1 lần khi `character`/size đổi (`shouldRepaint` đã có sẵn logic so sánh).
2. Bỏ `setState` mỗi frame: cho painter nhận `repaint: _animController` (`CustomPainter(repaint: ...)`) hoặc bọc `AnimatedBuilder` chỉ quanh `CustomPaint`.
3. Có thể parse `Path` ở `parseRaw` (toạ độ gốc) 1 lần rồi dùng `path.transform(Matrix4...)` khi size đổi.

---

### PERF-06 [High] Màn Listening rebuild toàn bộ màn hình theo `positionStream` của just_audio (16–200 ms) khi đang phát

**Vị trí**
- `lib/features/listening/presentation/providers/listening_providers.dart:108-126` (đặc biệt `:123-125`)
- `lib/features/listening/presentation/screens/listening_screen.dart:45` (`ref.watch(listeningPlaybackProvider)`), `:252-382` (dựng toàn bộ câu hỏi bằng `.map`, không builder)
- Hành vi thư viện: `just_audio 0.10.6` — `just_audio.dart:693-701`

**Mã lỗi**
```dart
// listening_providers.dart:123-125 — mỗi vị trí phát => state mới => notify
_posSub = _player!.positionStream.listen((pos) {
  state = state.copyWith(position: pos);
});
```
```dart
// listening_screen.dart:45
final playbackState = ref.watch(listeningPlaybackProvider);
```
```dart
// just_audio 0.10.6, lib/just_audio.dart:698-701
_positionSubject!.addStream(createPositionStream(
  steps: 800,
  minPeriod: const Duration(milliseconds: 16),
  maxPeriod: const Duration(milliseconds: 200)));
```

**Nguyên nhân gốc rễ**
- Provider chứa **cả** state tĩnh của màn (câu hỏi, đáp án, transcript) lẫn `position` cập nhật liên tục trong **một** object; `ListeningPlaybackState` không override `==` (Riverpod 3.4.3 filter bằng `==`) nên mọi `copyWith(position: ...)` đều là state mới.
- Widget `ListeningScreen` watch toàn bộ object → rebuild toàn màn hình, bao gồm `...activeLesson.questions.map(...)` dựng lại toàn bộ card câu hỏi + option (không `ListView.builder`, mỗi option là `Material`/`InkWell`).
- Tần số: `minPeriod` 16 ms, `maxPeriod` 200 ms, interval = duration/800 kẹp trong [16, 200] → clip 30 s ≈ **37 ms (~27 lần/s)**, clip ngắn 3 s → **16 ms (~60 lần/s)**. `DefaultAudioPlayerService` còn subscribe `positionStream` **vô điều kiện** (`audio_player_service.dart:89-94`) nên tần số này luôn tồn tại khi phát.

**Kịch bản & tác động (đo được)**
- Kịch bản: vào Listening, bấm phát, audio 30 s có 10 câu hỏi × 4 đáp án.
- Mỗi lần position: rebuild `Scaffold` + `ListView` + dựng lại **~40 widget card/option** + 3 `ChoiceChip` + `Slider` → **27 lần/s × 40 widget ≈ 1.080 widget-instance/giây** (chưa kể layout/paint). Trên máy tầm trung đây là nguồn jank kinh điển khi vừa nghe vừa đọc câu hỏi; `cần xác minh` bằng frame chart.
- Slider chỉ cần ~10 Hz để mượt; không cần 60 Hz.

**Bản vá**
- Tách `position` ra provider riêng, hoặc dùng `ref.watch(listeningPlaybackProvider.select((s) => s.position))` **chỉ trong widget Slider/text thời gian**; phần danh sách câu hỏi watch `select` các trường không đổi.
- Trong notifier: dùng `_player.createPositionStream(steps: 100, minPeriod: 200ms)` thay vì `positionStream` mặc định, hoặc throttle `state` cập nhật ≤10 Hz.
- Chuyển danh sách câu hỏi sang `ListView.builder`/`SliverList`.

---

### PERF-07 [Med] Recorder phát amplitude 2 lần mỗi 100 ms và mỗi mẫu gọi `setState` toàn màn hình (10–20 lần/s)

**Vị trí**
- `lib/core/audio/audio_recorder_service.dart:171-203` (start), `:241-256` (resume)
- `lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart:54-69`
- `lib/features/shadowing/presentation/screens/shadowing_screen.dart:47-62`
- `lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart:54-60`

**Mã lỗi**
```dart
// audio_recorder_service.dart:173-203 — 2 nguồn amplitude cùng lúc
_durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
  ...
  try {
    final amp = await _recorder.getAmplitude();       // nguồn 1: poll platform channel
    final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
    if (!_amplitudeController.isClosed) _amplitudeController.add(normalized);
  } catch (_) {}
});

_amplitudeSub = _recorder
    .onAmplitudeChanged(const Duration(milliseconds: 100))   // nguồn 2: native stream
    .listen((amp) { ... _amplitudeController.add(normalized); });
```
```dart
// pronunciation_lab_screen.dart:54-56 — mỗi mẫu setState toàn màn hình
_ampSub = _recorder.amplitudeStream.listen((amp) {
  if (mounted) setState(() => _currentAmplitude = amp);
});
```

**Nguyên nhân gốc rễ**
- Hai nguồn amplitude trùng tần số (100 ms) cùng đẩy vào một `StreamController` ⇒ mỗi 100 ms phát **2** sự kiện; ngoài ra `getAmplitude()` là platform-channel call thừa vì đã có stream native.
- Callback `Timer.periodic` là `async` nhưng **không có guard re-entrancy**: nếu `getAmplitude()` chậm > 100 ms (máy bận), các callback xếp chồng, gọi native chồng nhau.
- Ba màn hình recording đều `setState` **toàn màn hình** cho mỗi mẫu (waveform + duration + toàn bộ nội dung bài học).

**Kịch bản & tác động (đo được)**
- Kịch bản: ghi âm 1 phút ở Pronunciation Lab/Shadowing.
- Số lần rebuild: 2 sự kiện/100 ms ⇒ **20 lần `setState`/giây** trên màn hình nặng (CustomPaint waveform, danh sách target, nút bấm) = ~1.200 rebuild/phút; mỗi rebuild phải layout lại toàn bộ.
- Số platform-channel call: 10 `getAmplitude`/s dù đã có 10 event native/s ⇒ gấp đôi công việc native; pin và jank tăng.
- Tác động phụ: khi amplitude/duration đến sau `stopRecording()` (callback đang bay), vẫn cộng thêm `setState` thừa.

**Bản vá**
- Bỏ một nguồn: chỉ dùng `onAmplitudeChanged` (native) hoặc chỉ poll; nếu cần duration, dùng `Timer` riêng chỉ cập nhật duration.
- Thay `setState` toàn màn hình bằng `ValueListenableBuilder`/`AnimatedBuilder` chỉ bọc `WaveformVisualizer` và text thời gian; hoặc dùng provider + `select`.
- Thêm `bool _polling` guard trong callback timer.

---

### PERF-08 [Med] Streaming chat: mỗi chunk SSE `setState` toàn màn hình + khởi động lại `animateTo(250 ms)`

**Vị trí**
- `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart:92-101` (`_scrollToBottom`), `:147-171` (`stream.listen`)
- `:550-565` (`ListView.builder` được rebuild mỗi lần `setState`)

**Mã lỗi**
```dart
// :147-155 — mỗi chunk: setState + scrollToBottom
_streamSub = stream.listen(
  (chunk) {
    if (mounted) {
      setState(() {
        _streamBuffer += chunk;
      });
      _scrollToBottom();
    }
  },
```
```dart
// :92-101 — mỗi lần gọi tạo 1 animation 250 ms mới
void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
}
```

**Nguyên nhân gốc rễ**
- Mỗi token/chunk từ SSE (thường 20–80 ms/chunk) kéo theo 2 việc: rebuild toàn bộ screen (bao gồm `ListView.builder` + item đang stream + input bar) và thêm 1 post-frame callback khởi động animation scroll 250 ms.
- `animateTo` mới huỷ animation đang chạy nhưng `maxScrollExtent` đo tại thời điểm callback — khi text đang dài ra, animation liên tục bị restart ⇒ scroll "giật"/không bao giờ dừng ở đúng đáy trong suốt quá trình sinh.

**Kịch bản & tác động (đo được)**
- Kịch bản: gửi 1 câu hỏi, AI trả lời 500 token trong 15 s.
- Nếu ~25 chunk/s ⇒ **25 setState/s** rebuild `ListView` + chrome màn hình, và **25 animation 250 ms/s** (gần như luôn có animation scroll đang chạy) → jank, pin, và hao frame trong lúc người dùng đọc câu trả lời đang chảy.
- Prompt càng dài/model càng nhanh → tần số càng cao.

**Bản vá**
- Gom chunk: `StringBuffer` + `Timer(80–120 ms)` flush vào 1 `ValueNotifier<String>`; bubble streaming là `ValueListenableBuilder` riêng ⇒ chỉ bubble repaint.
- Scroll: chỉ `jumpTo`/`animateTo` khi người dùng đang ở gần đáy, và throttle (≤ 4 lần/s); hoặc dùng `reverse: true` ListView.

---

### PERF-09 [Med] 5 tab + toàn bộ audio stack của AI Tutor được tạo ngay khi shell mount

**Vị trí**
- `lib/features/app_shell/presentation/screens/app_shell.dart:103-120` (`IndexedStack` 5 tab)
- `lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart:297-303` (`IndexedStack` 2 mode)
- `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart:32-40` (`initState` → `ref.read(voiceConversationServiceProvider)`)
- `lib/features/ai_tutor/presentation/providers/ai_tutor_providers.dart:43-79`

**Mã lỗi**
```dart
// app_shell.dart:104-113 — IndexedStack build TẤT CẢ children ngay
body: IndexedStack(
  index: currentTab.index,
  children: const [
    HomeScreen(), LearningScreen(), AiTutorTabScreen(), ReviewScreen(), ProfileScreen(),
  ],
),
```
```dart
// ai_tutor_voice_chat_screen.dart:37 — initState của màn voice chạy dù user chưa mở
final service = ref.read(voiceConversationServiceProvider);
```
```dart
// ai_tutor_providers.dart:43-79 — tạo 3 engine native + recorder + player + TTS
final aiTutorAudioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = DefaultAudioRecorderService(); ...
final aiTutorAudioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final player = DefaultAudioPlayerService(); ...
```

**Nguyên nhân gốc rễ**
- `IndexedStack` build/layout **mọi** child; `AiTutorTabScreen` lại là `IndexedStack` của 2 màn chat ⇒ màn Voice được mount ngay từ frame đầu tiên sau khi startup xong.
- `AiTutorVoiceChatScreen.initState` `ref.read` service voice ⇒ khởi tạo cả chuỗi `DefaultAudioRecorderService` (native `AudioRecorder` + đăng ký `AppLifecycleManager`), `DefaultAudioPlayerService` (native `AudioPlayer` — ExoPlayer/AVPlayer), `DefaultTtsService` (native `FlutterTts`), `DefaultVoiceConversationService`.
- Provider thường (không autoDispose) nên các engine này giữ nguyên suốt vòng đời app, kể cả khi user chỉ dùng Text/không bao giờ dùng Voice.

**Kịch bản & tác động (đo được)**
- Kịch bản: mở app → chuyển ngay sang tab Home, không mở AI.
- Ngay sau khi startup `isReady`, app khởi tạo: 1 native audio player + 1 native recorder + 1 TTS engine + 1 voice service + `ChatDao.getActiveSessions` (`_ensureActiveSession`) — dù không dùng.
- Tác động: (a) tăng thời gian "sẵn sàng" của frame đầu sau splash; (b) giữ native memory (ExoPlayer + AudioRecord + TTS) cho cả phiên → áp lực bộ nhớ trên máy RAM thấp; (c) nếu thiết bị không có mic/TTS zh-CN, các khởi tạo này có thể sinh log lỗi/khựng ngay đầu app. `cần xác minh` bằng DevTools memory + timeline lúc mở app.

**Bản vá**
- Chỉ build tab khi được chọn: thay `IndexedStack` bằng `PageView` lazy/`IndexedStack` với children `_built[index] ??= ...`, hoặc dùng `Offstage` + lazy init.
- Chuyển `ref.read(voiceConversationServiceProvider)` khỏi `initState`: khởi tạo khi user bấm "Bắt đầu hội thoại"; hoặc `Provider(isAutoDispose: true)` + `keepAlive` trong phiên.

---

### PERF-10 [Med] Startup quét filesystem **đồng bộ** trên UI isolate + delay nhân tạo 50 ms trước khi `isReady`

**Vị trí**
- `lib/core/audio/audio_temp_cleaner.dart:14-71` (đặc biệt `:34, :37, :53, :57`)
- `lib/core/startup/app_startup_provider.dart:92-98` (gọi ở bước 1/10), `:197`

**Mã lỗi**
```dart
// audio_temp_cleaner.dart:33-58 — sync IO trên UI isolate
for (final dir in targetDirs) {
  if (!dir.existsSync()) continue;
  final entities = dir.listSync(followLinks: false);   // <-- blocking
  for (final entity in entities) {
    ...
    final stat = entity.statSync();                    // <-- blocking
    ...
    entity.deleteSync();                               // <-- blocking
```
```dart
// app_startup_provider.dart:94-98
try {
  await AudioTempCleaner.cleanupTempAudioFiles();
} catch (e) { ... }
```
```dart
// app_startup_provider.dart:196-197
// Brief yield for smooth UI animation
await Future<void>.delayed(const Duration(milliseconds: 50));
```

**Nguyên nhân gốc rễ**
- `AudioTempCleaner` dùng `existsSync/listSync/statSync/deleteSync` (đồng bộ, chặn isolate) trên **toàn bộ** thư mục temp của app — không giới hạn số entry, không lọc trước bằng stream.
- Chạy ở bước 1 của chuỗi 10 bước startup, ngay sau splash, trước khi mở DB/UI sẵn sàng.
- Thêm `Future.delayed(50ms)` cố ý trước khi bật `isReady` — cộng thẳng vào cold start.

**Kịch bản & tác động (đo được)**
- Kịch bản: app đã dùng lâu, thư mục temp/cache có N file (ảnh cache, file tạm khác). Mỗi lần cold start: `listSync` đọc toàn bộ N entry + `statSync` cho từng entry audio; với N = 2.000 file có thể chặn UI isolate **hàng trăm ms** (`cần xác minh`; phụ thuộc IO thiết bị).
- Cộng thêm 50 ms delay nhân tạo ⇒ mỗi lần mở app chậm thêm ≥ 50 ms vô ích.
- Trong khi chặn, splash không thể animate → người dùng thấy "đứng" ngay giây đầu.

**Bản vá**
- Đổi sang `await for (final e in dir.list(recursive: false))` + `await e.stat()` (async, nhường event loop), hoặc chạy `Isolate.run` cho toàn bộ scan; lọc theo tên trước khi stat.
- Chỉ chạy cleanup **sau** khi `isReady` (idle callback/`Future.delayed(2s)`), không chặn splash; bỏ hẳn `Future.delayed(50ms)`.

---

### PERF-11 [Med] Cài audio pack: tải tuần tự tới 2.600 request, cancel không dừng request đang bay, sau đó 300 UPDATE đơn lẻ + sha256 đồng bộ trên UI isolate

**Vị trí**
- `lib/features/audio_management/data/audio_pack_downloader.dart:56-173` (đặc biệt `:87-99`, `:127`, `:136-144`)
- `lib/features/sentences/data/audio_pack_manager.dart:230-242` (N+1 UPDATE), `:210-214` (sync hash)
- `lib/features/audio_management/presentation/providers/audio_pack_providers.dart:42-127`

**Mã lỗi**
```dart
// audio_pack_downloader.dart:87-99 — vòng lặp tuần tự, cancel chỉ check đầu vòng
for (final asset in manifest.assets) {
  if (_isCancelled) { ... throw ...; }
  while (_isPaused) { await Future.delayed(const Duration(milliseconds: 200)); ... }
  ...
  final response = await client.get(uri, headers: config.defaultHeaders);  // :127
```
```dart
// audio_pack_manager.dart:233-241 — N+1 write sau khi giải nén
final sentences = await _dao.getSentencesByHskLevel(level, limit: 300);
for (final s in sentences) {
  for (final a in s.audios) {
    if (a.audioType == AudioType.humanRecording) {
      final localPath = p.join(targetDir.path, '${a.id}.${a.fileFormat}');
      await _dao.updateAudioLocalPath(a.id, localPath, 'downloaded');   // 1 transaction/lần
    }
  }
}
```
```dart
// audio_pack_manager.dart:214 — đọc cả file zip đồng bộ + sha256 trên UI isolate
final fallbackHash = sha256.convert(localFallbackZip.readAsBytesSync()).toString();
```

**Nguyên nhân gốc rễ**
- Downloader xử lý từng file một (`await` trong `for`), không có pool concurrency; `client.get` tải **toàn bộ** body vào RAM thay vì stream; `_isCancelled` chỉ được kiểm tra ở đầu vòng lặp nên request đang bay (tối đa timeout) không thể huỷ.
- Catalog audio pack rất lớn (`audio_pack_providers.dart:75-114`): HSK5 1.350 file, HSK6 2.600 file.
- Sau khi giải nén, cập nhật DB theo kiểu N+1 (mỗi audio 1 `update` = 1 transaction sqflite).
- Nhánh fallback offline hash zip 3,9 MB bằng `readAsBytesSync` + sha256 ngay trên UI isolate.

**Kịch bản & tác động (đo được)**
- Kịch bản: tải HSK6 audio pack (2.600 file ~250 MB). Giả sử mỗi request 100–300 ms → **260–780 s (4,3–13 phút)** chỉ vì tuần tự; user bấm "Hủy" khi đang ở file 1.500 → request hiện tại vẫn chạy xong, UI không phản hồi ngay.
- Sau đó: tối đa 300 lần `updateAudioLocalPath` tuần tự (`getSentencesByHskLevel(limit: 300)`), mỗi lần một transaction → hàng trăm ms–vài giây block UI (db native nhưng mỗi `await` là một round-trip).
- Bộ nhớ: `response.bodyBytes` giữ nguyên 1 file trong RAM mỗi vòng (file audio ~20–40 KB nên không lớn, nhưng `Read` toàn bộ là anti-pattern khi pack lớn).

**Bản vá**
- Pool 4–6 download song song; ghi bằng `response.stream` → `sink` (đã có `openWrite` ở `audio_pack_manager.dart:155-168`); check `_isCancelled` **trong** `await for` và đóng `http.Client`/request khi cancel.
- Gom cập nhật DB vào 1 `batch`/transaction (hoặc `UPDATE ... WHERE id IN (...)` theo lô 300).
- Hash trong `Isolate.run` hoặc dùng `sha256.bind(openRead())` (đã đúng ở `audio_pack_manager.dart:172` — chỉ nhánh fallback còn sync).

---

### PERF-12 [Med] `AudioCoverageAuditor`: N+1 `File.exists()` tuần tự (hàng nghìn syscall) trên UI isolate

**Vị trí**
- `lib/features/audio_management/data/audio_coverage_auditor.dart:24-35` (level 0), `:66-84` (HSK 1–6)
- `lib/features/audio_management/presentation/providers/audio_pack_providers.dart:21-29` (`FutureProvider` gọi `auditCoverage`), `:133, :139` (`ref.invalidate(audioCoverageReportProvider)`)

**Mã lỗi**
```dart
// audio_coverage_auditor.dart:30-35
for (final row in pinyinAssets) {
  final path = row['local_path'] as String?;
  if (path != null && await File(path).exists()) {   // 1 await/syscall cho MỖI asset
    pinyinVerified++;
  }
}
```
```dart
// audio_coverage_auditor.dart:76-83
for (final a in assets) {
  ...
  if (path != null && await File(path).exists()) {   // tương tự cho từng HSK level
    verified++;
  }
}
```

**Nguyên nhân gốc rễ**
- Mỗi asset = một `await File.exists()` tuần tự (native stat + microtask hop trên UI isolate), không batch, không isolate.
- Số asset: Pinyin 114 + HSK1..6 yêu cầu 150+150+300+600+1300+2500 ⇒ hàng nghìn bản ghi `audio_assets` khi đã tải đủ; mỗi lần audit phải stat từng file.
- Provider được `invalidate` sau mỗi lần download/delete pack (`audio_pack_providers.dart:133,139`) ⇒ audit chạy lại toàn bộ.

**Kịch bản & tác động (đo được)**
- Kịch bản: user đã cài đủ audio pack HSK1–6 (≈5.000 file), mở màn quản lý audio → audit ~5.000 `await exists()` tuần tự.
- Mỗi `await` tốn ít nhất 1 microtask + 1 syscall; 5.000 lần có thể mất **hàng trăm ms tới vài giây** tuỳ IO (`cần xác minh`), trong khi UI đang chờ FutureProvider → màn hình loading lâu; đồng thời event loop bị chia nhỏ liên tục.
- Mỗi lần xoá/tải pack xong → audit chạy lại toàn bộ (không incremental).

**Bản vá**
- Chỉ `File.exists()` cho **file mới/không chắc chắn**, hoặc bỏ verify hoàn toàn (dựa vào `status = ready` trong DB).
- Nếu vẫn cần: chạy trong `Isolate.run` (đường dẫn + kết quả trả về) hoặc `Future.wait` theo lô ≤ 50 để giới hạn.
- Cache kết quả audit theo `(packId, mtime)` thay vì invalidate toàn bộ.

---

### PERF-13 [Med] Chat AI: mỗi lượt đọc lại **toàn bộ** lịch sử (không LIMIT) và đưa vào prompt; transcript voice copy toàn list mỗi cập nhật

**Vị trí**
- `lib/core/database/dao/chat_dao.dart:46-53`
- `lib/features/ai_tutor/data/repositories/ai_tutor_repository.dart:194-219` (`sendMessage`), `:305-335` (`sendMessageStream`), `:332-338`
- `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:171-194` (`_addTranscript`/`_updateLastInterimTranscript`)

**Mã lỗi**
```dart
// chat_dao.dart:46-53 — không LIMIT
Future<List<Map<String, dynamic>>> getMessagesBySessionId(String sessionId) async {
  return await _db.query(
    DatabaseConstants.tableChatMessages,
    where: 'session_id = ?',
    whereArgs: [sessionId],
    orderBy: 'created_at ASC',
  );
}
```
```dart
// ai_tutor_repository.dart:306 — mỗi lượt đọc lại toàn bộ, rồi build prompt bằng cả history
final rawHistory = await chatDao.getMessagesBySessionId(sessionId);
final request = contextBuilder.buildRequest(
  userInput: userText,
  rawDbHistory: historyExcludingLast, ...
```
```dart
// voice_conversation_service.dart:171-175 — mỗi segment: copy toàn list
void _addTranscript(VoiceTranscriptSegment segment) {
  _transcripts.add(segment);
  if (!_transcriptController.isClosed) {
    _transcriptController.add(List.unmodifiable(_transcripts));  // O(n) mỗi lần
  }
}
```

**Nguyên nhân gốc rễ**
- Không có cửa sổ lịch sử: lượt thứ N đọc N×2 message (có cả pinyin/translation TEXT), map sang `TutorChatTurn`, rồi đưa **toàn bộ** vào prompt gửi API. Chi phí DB + JSON encode + số token tăng tuyến tính theo độ dài phiên (và chi phí tiền API).
- Voice transcript: mỗi lần thêm/cập nhật một segment lại `List.unmodifiable(_transcripts)` (copy toàn bộ) và emit → listener rebuild list transcript. Với phiên dài 100 lượt ⇒ ~200 lần copy có kích thước tăng dần = **O(n²)** tổng cộng.

**Kịch bản & tác động (đo được)**
- Kịch bản: một phiên chat 100 lượt (200 message) — rất bình thường với AI tutor.
  - Mỗi lượt gửi: 1 query trả ~200–400 row (kèm TEXT), map ~200–400 object, JSON encode toàn bộ history + system prompt ⇒ độ trễ gửi tăng dần; memory tạm tăng; prompt gửi lên model lớn dần (chi phí token tăng bậc hai theo số lượt vì mỗi lượt gửi lại toàn bộ).
  - Voice: phiên 50 lượt ⇒ ~100 lần emit list; tổng số phần tử copy ≈ 100×50/2 = 2.500 (chưa lớn nhưng tăng dần, kèm rebuild UI mỗi segment).
- `cần xác minh` thời gian thực tế bằng trace; điểm chắc chắn: độ phức tạp tăng tuyến tính (chat) và bậc hai (transcript) theo dữ liệu phiên.

**Bản vá**
- `getMessagesBySessionId(sessionId, {int limit = 20, int beforeId?})` + tóm tắt các lượt cũ (đã có `recentChatSummary` trong `LearnerContextService`) thay vì gửi toàn bộ.
- Voice: giữ transcript dạng `List` + emit **delta** (`transcriptAdded`/`transcriptUpdated`) hoặc dùng `ValueNotifier` + `addPostFrameCallback`; không `List.unmodifiable` toàn bộ mỗi segment.

---

### PERF-14 [Med] Tìm kiếm theo từng ký tự ở Hanzi/Sentence browser: không debounce, 2 query DB + 2 `setState` mỗi phím

**Vị trí**
- `lib/features/hanzi/presentation/screens/hanzi_character_list_screen.dart:44-77`
- `lib/features/sentences/presentation/screens/sentence_browser_screen.dart:52-85`
- So sánh mẫu đúng đã có sẵn: `lib/features/dictionary/presentation/screens/dictionary_screen.dart:63-68` (debounce 250 ms)

**Mã lỗi**
```dart
// hanzi_character_list_screen.dart:72-77 — mỗi ký tự gọi load ngay
void _onSearchChanged(String val) {
  setState(() {
    _searchQuery = val;
  });
  _loadCharacters();               // 2 query DB + setState
}
```
```dart
// sentence_browser_screen.dart:82-85
void _onSearchChanged(String val) {
  setState(() => _searchQuery = val);
  _loadSentences();                // tương tự
}
```
```dart
// hanzi_character_list_screen.dart:50-61 — mỗi lần load: 2 query tuần tự
chars = await widget.repository.searchCharacters(_searchQuery);       // query 1
...
final map = await widget.repository.getProgressForCharacters(charGlyphs);  // query 2
```

**Nguyên nhân gốc rễ**
- Không debounce (mẫu đã tồn tại trong `dictionary_screen.dart:63-68` nhưng không được áp dụng lại) ⇒ mỗi keystroke: 2 truy vấn DB + 2 `setState` + rebuild danh sách.
- Không có "generation guard": kết quả của query 1 (list) và query 2 (progress) ở 2 keystroke khác nhau có thể xếp hàng xen kẽ trên cùng DB queue của `sqflite 2.4.5` (q1a, q2a, q1b, q2b...) ⇒ `_progressMap` của lần tìm cũ có thể được gán cho list mới (hoặc ngược lại) trong lúc gõ nhanh.

**Kịch bản & tác động (đo được)**
- Kịch bản: gõ "中" rồi "中国" (2 phím) hoặc tìm 8 ký tự.
- 8 phím ⇒ **16 truy vấn DB + 16 lần setState/rebuild danh sách** trong < 1 s; mỗi rebuild dựng lại list card (có `_progressMap` lookup).
- Với dữ liệu lớn (2.632 chữ Hán/1.500 câu) `searchCharacters` có thể dùng `LIKE '%q%'` (xem `hanzi_dao.searchCharacters`) ⇒ full scan bảng mỗi phím.
- Kết quả nhấp nháy/không nhất quán khi gõ nhanh (list mới + progress cũ).

**Bản vá**
- Dùng `Timer` debounce 250–300 ms như `dictionary_screen.dart:63-68`.
- Thêm `int _requestId = 0;` tăng mỗi lần gọi, sau `await` kiểm tra `if (id != _requestId) return;` trước `setState`.
- Cân nhắc `TextEditingController` + `ValueListenableBuilder` để tránh `setState` mỗi phím.

---

### PERF-15 [Low] Mỗi lần phát audio asset: đọc **toàn bộ** file để kiểm tra tồn tại rồi just_audio đọc lại lần thứ hai

**Vị trí**
- `lib/core/audio/audio_player_service.dart:164-194` (đặc biệt `:170-181`)

**Mã lỗi**
```dart
// audio_player_service.dart:170-181
if (cleanUri.startsWith('assets/')) {
  // Check asset existence before feeding to native player to avoid unhandled crashes
  bool assetExists = false;
  try {
    await rootBundle.load(cleanUri);      // <-- đọc TOÀN BỘ bytes của asset, rồi vứt
    assetExists = true;
  } catch (_) {
    assetExists = false;
  }
  if (assetExists) {
    source = ja.AudioSource.asset(cleanUri);   // just_audio sẽ đọc lại asset
  }
```

**Nguyên nhân gốc rễ**
- Kiểm tra tồn tại bằng cách `rootBundle.load` toàn bộ file (ByteData) — với mỗi lần phát; kết quả không được cache. Trong khi đó các module pinyin/shadowing/pronunciation/placement/listening đều dùng URI dạng `assets/audio/...` hoặc `asset:///assets/...` (grep: 90 chỗ khai báo `assets/audio/...` trong `lib/`) ⇒ đường này chạy trên gần như **mọi** lần phát audio asset.
- Fallback khi thiếu asset lại đọc TTS theo tên file (`_deriveTextFromAudioUri`, `:294-301`) — vừa tốn vừa sai nội dung (cross-domain, xem phần leads).

**Kịch bản & tác động (đo được)**
- Kịch bản: bấm nghe 1 từ HSK1 (`assets/audio/hsk1/*.mp3`, ~20–28 KB mỗi file).
- Mỗi lần bấm: 1 lần đọc asset đầy đủ + cấp phát `ByteData` bị bỏ + thêm 1 lần đọc asset bởi just_audio ⇒ **đọc gấp đôi + ~28 KB alloc/lần**, cộng độ trễ vào thao tác UI (mỗi lần play).
- Trên danh sách dài (bấm nghe liên tục khi lướt từ vựng) → GC pressure + latency cộng dồn.

**Bản vá**
- Bỏ pre-check; bắt lỗi từ `setAudioSource`/`AudioSource.asset` và fallback TTS trong `catch`.
- Hoặc cache `Set<String>` asset đã xác nhận tồn tại (1 lần/asset) / đọc `AssetManifest.bin` một lần lúc startup.
- Với listening (`asset:///...`), chuẩn hoá về `assets/...` và dùng chung logic.

---

## Đã kiểm tra — KHÔNG phải lỗi (tránh false positive)

1. **`SeedLoader` đã offload đúng**: `seed_loader.dart:71-81` dùng `Isolate.run` cho `json.decode` 8,4 MB + `SeedBundle.fromJson` + SHA-256; ghi DB theo batch 50 trong transaction. Không phải lỗi (đã fix so với giai đoạn trước).
2. **Zip extraction đã offload + chặn Zip Slip**: `audio_pack_manager.dart:14-47` chạy trong `Isolate.run` (`:187,223`), có `p.canonicalize` + `p.isWithin` + bỏ entry `.`/basename rỗng.
3. **`main.dart` không block trước `runApp`**: `main.dart:11-44` chỉ cấu hình `SystemChrome`/image cache rồi `runApp`; startup chạy trong Riverpod notifier (`app_startup_provider.dart:66-75`) ⇒ splash vẽ được ngay.
4. **`DefaultAudioPlayerService.dispose()` đóng đủ**: `audio_player_service.dart:303-318` cancel 3 subscription, chỉ dispose player/TTS nếu sở hữu, close 2 controller — không rò rỉ.
5. **`DefaultAudioRecorderService` giờ đã unregister callback lifecycle**: `audio_recorder_service.dart:302` (`unregisterAudioSession`) — round-1 F06 **đã được fix** (không còn tích callback theo từng recorder).
6. **`DefaultVoiceConversationService.dispose()`** unregister + cancel 2 sub + close 4 controller (`voice_conversation_service.dart:552-570`) — phần teardown nội bộ đúng; lỗi nằm ở *ai gọi teardown* (PERF-03/04).
7. **Stream SSE có huỷ thật**: `gemini_rest_ai_provider.dart:362-380` — `onCancel` huỷ subscription HTTP, `cancelToken.onCancelled` đẩy `AiCancelledException`; text chat gọi `_cancelToken.cancel()` (`ai_tutor_text_chat_screen.dart:184-198`) nên nút "Dừng" của chat chữ hoạt động. (Chỉ nhánh `generateText` của voice là không huỷ được — PERF-04.)
8. **`AiTutorTextChatScreen.dispose()`** huỷ `_streamSub` + `_cancelToken` + dispose 2 controller (`:43-49`) — đúng.
9. **`AiTutorVoiceChatScreen.dispose()`** remove observer + cancel 2 sub + dispose 2 controller (`:68-75`) — đúng phần controller; thiếu teardown phiên (PERF-03).
10. **Danh sách Timer nhỏ và đều có cancel**: grep `Timer(`/`Timer.periodic` chỉ 7 chỗ; tất cả có `cancel()` ở dispose/stop (`dictionary_screen.dart:57`, `lesson_vocab_view.dart:65`, `reading_detail_screen.dart:57-…`, `audio_recorder_service.dart:265,281,303`).
11. **`AppDatabase.open()`** idempotent (`app_database.dart:47-49`), cấu hình WAL + `synchronous=NORMAL` + `cache_size=-8000` + `temp_store=MEMORY` (`:66-83`) — hợp lý cho app mobile.
12. **`ReadingDetailScreen`** có Timer 1 s nhưng huỷ trong `dispose` (grep xác nhận) — không phải lỗi.
13. **`FlashcardCard`** dispose đúng: `_flipController.dispose()` + stop audio/TTS + chỉ dispose cái mình sở hữu (`flashcard_card.dart:82-94`).
14. **`UnifiedAudioPlaybackService`** có `dispose()` đóng sub + player (`unified_audio_playback_service.dart:114-118`) — dù là singleton và trên thực tế không ai gọi dispose (chấp nhận được vì sống cùng app); **không** tính là lỗi rò rỉ.
15. **`srs_providers.dart:73-115`** chống double-submit đúng: set `isProcessingReview = true` **trước** `await`, guard ở đầu hàm, revert khi lỗi.
16. **Riverpod 3.4.3**: `autoDispose` vẫn opt-in (`CHANGELOG` 3.0.0: `Provider(isAutoDispose: true)`), nên kết luận "provider thường sống suốt app" là đúng version hiện tại — **không** áp dụng giả định autoDispose mặc định.
17. **`web_socket_channel` không được dùng**: grep `WebSocket|web_socket_channel|StreamChannel` chỉ ra 4 kết quả, toàn bộ là comment/UI copy trong `ai_tutor_voice_chat_screen.dart:282` và `voice_conversation_models.dart:117-118`; AI thật dùng HTTP SSE (`gemini_rest_ai_provider.dart:317`). (Cross-domain: UI overclaim.)

---

## Đối chiếu Round 1 (chỉ ghi nhận trạng thái, không copy nội dung)

| Round-1 ID | Nội dung | Trạng thái Round 2 (đã đọc lại code hiện tại) |
|---|---|---|
| T4-F01 | Voice session sống sót khi đổi tab/mode | **Còn** → PERF-03 (mở rộng: thêm đường dispose/back) |
| T4-F02 | Turn voice cũ không huỷ được, phát TTS sau teardown | **Còn** → PERF-04 (bổ sung root cause `generateText` không huỷ được POST) |
| T4-F06 | Recorder không unregister callback lifecycle | **ĐÃ FIX** — `audio_recorder_service.dart:302` |
| T4-F08 | 5 tab + audio stack tạo eager | **Còn** → PERF-09 |
| T4-F09 | Amplitude phát 2 lần/100 ms | **Còn** → PERF-07 |
| T4-F10 | Streaming rebuild + animate mỗi token | **Còn** → PERF-08 |
| T4-F11 | Chat history unbounded | **Còn** → PERF-13 |
| T4-F12 | Transcript list O(n²) | **Còn** → PERF-13 |
| T4-F13 | AudioCoverageAuditor N+1 `exists()` | **Còn** → PERF-12 |
| T4-F14 | Content-pack import N+1 | **Một phần**: top-level JSON đã `Isolate.run` (`content_pack_manager.dart:165`), N+1 per-row vẫn còn (không đưa vào top-15 vì chỉ chạy khi cài/gói mới) |
| T4-F15 | `initialize()` không chặn gọi chồng | **Còn** (`app_startup_provider.dart:77-98` không có in-flight guard; nút "Thử lại" `app_shell.dart:51-53`) → cross-domain QA |
| T4-F17 | File ghi âm tạm không được xoá | **Một phần**: có `AudioTempCleaner` ở startup (`app_startup_provider.dart:95`), nhưng `ShadowingScreen.dispose()` không xoá file cuối (`shadowing_screen.dart:66-75`) và cleaner chỉ quét định kỳ |
| T4-F21 | Cache `LearnerContextService` không evict | **Còn** nhưng tác động thấp (key theo sessionId, TTL 30 s, `invalidateCache()` được gọi); không đưa vào top-15 |

**Finding hoàn toàn mới ở Round 2** (không có trong danh sách round 1): PERF-01, PERF-02, PERF-05, PERF-06, PERF-10, PERF-11 (góc nhìn downloader+DB), PERF-14, PERF-15.

---

## Cross-domain leads (gửi kèm cho Lead)

- **scout-business / QA — âm lượng không có tác dụng**: `UnifiedAudioPlaybackService.setVolume` chỉ gán `_volume` (`unified_audio_playback_service.dart:110-112`), không gọi player; `AudioPlayerService` interface không có `setVolume` ⇒ UI đổi âm lượng không đổi âm thanh thực tế.
- **scout-business — voice phát sai nội dung**: `submitSpeechInput` phát file mẫu của persona (`persona.voicePreviewSampleUri`) thay vì đọc câu trả lời (`voice_conversation_service.dart:436-441`); nếu không có file mẫu thì TTS đọc `tutorResponse.replyZh` — nghĩa là audio không khớp text ở nhánh asset.
- **scout-data — downloadPack "thành công giả"**: catch-all `audio_pack_manager.dart:192-207` biến lỗi mạng thành chuỗi progress giả và cuối cùng `onProgress(1.0)` dù không có file nào được giải nén ⇒ DB/UI báo tải xong nhưng không có audio.
- **scout-security — chỗ cần soi**: `_extractZipFileSafely` đã có guard Zip Slip (verified clean); nhưng `_resolveManifestExpectedSha256`/fallback dùng đường dẫn tương đối `content_packs_cdn/...` (`audio_pack_manager.dart:67, 211`) → không tồn tại trên mobile, nhánh fallback offline thực tế chết (không phải lỗ hổng, nhưng là dead path).
- **scout-qa — lifecycle abort quá tay**: `AppLifecycleManager.didChangeAppLifecycleState` xử lý `inactive` (`app_lifecycle_manager.dart:51-60`); trên Android/iOS `inactive` xảy ra khi kéo notification shade/control center → `DefaultAudioRecorderService._onLifecycleStop` gọi `cancelRecording()` (`audio_recorder_service.dart:105-110`) và hàm này **xoá file ghi âm** (`:280-298`) ⇒ user mất bản ghi đang thu; đồng thời `_updateStatus(error)` và `cancelRecording` set `idle` chạy đua (unawaited) ⇒ trạng thái cuối không xác định.
- **scout-qa — overclaim WebSocket**: UI nói "Sẵn sàng đấu nối WebSocket Live API" (`ai_tutor_voice_chat_screen.dart:282`) nhưng không có mã WebSocket nào trong `lib/`; `web_socket_channel 3.0.3` là dependency không dùng.
- **scout-data — startup không chặn gọi chồng** (round-1 F15, đã verify lại): `AppStartupNotifier.initialize()` không có cờ in-flight; retry có thể chạy song song 2 lần seed/import.
- **scout-qa — số liệu DB**: `hi_chinese_dev.db` (18,0 MB) chỉ chứa 2.632 hanzi + 1.500 câu + 1.027 grammar + 6.174 grammar examples ⇒ không phản ánh dữ liệu production; các ước lượng hiệu năng theo lịch sử học (PERF-01/13) cần test với DB lớn.

---

## Ghi chú giới hạn

- Không chạy `flutter analyze/test/build`, không sửa file nguồn nào; báo cáo này là file duy nhất được ghi.
- Mọi khẳng định "không có cleanup" đều có grep đối chứng (`StreamSubscription`, `.listen(`, `Timer(`, `autoDispose`, `ref.onDispose`, `compute(`, `Isolate.run`, `endSession`, `dispose`).
- Các con số thời gian (ms/số lần rebuild thực tế) là ước tính tĩnh; QA/Lead nên xác nhận bằng Profile mode + DevTools (Frame chart, CPU profiler, Memory) trước khi đưa vào kết luận cuối, đặc biệt PERF-01, PERF-02, PERF-05, PERF-06, PERF-12.
