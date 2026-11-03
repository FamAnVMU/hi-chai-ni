# 10. DANH MỤC API, DỊCH VỤ & GIAO TIẾP NGOẠI VI

---

## 1. BẢNG TỔNG HỢP GIAO TIẾP NGOẠI VI (EXTERNAL API INVENTORY)

| Dịch vụ | Phương thức & URL Endpoint | Giao thức | Dữ liệu đầu vào | Dữ liệu đầu ra | Xử lý lỗi & Timeout |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **Gemini REST API** | `POST https://generativelanguage.googleapis.com/v1beta/models/{modelId}:generateContent?key={apiKey}` | HTTPS | JSON: `contents`, `systemInstruction`, `generationConfig` | JSON Candidates: `reply_zh`, `pinyin`, `reply_vi`, `corrections` | Timeout: 30s. Lỗi 429: Retry backoff. Lỗi 403: Báo lỗi API Key. |
| **Gemini Live API** | `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha...` | WSS | Audio Stream (PCM 16kHz) & Text prompts | Audio Stream (PCM 24kHz) & Transcripts | Auto reconnect, ngắt kết nối khi chuyển background. |
| **Content Pack CDN**| `GET https://raw.githubusercontent.com/.../content_packs_cdn/{pack_id}.json` | HTTPS | HTTP Headers cơ bản | Tệp JSON Content Pack hoàn chỉnh | Timeout: 45s. Kiểm tra SHA-256 sau khi tải xong. |
| **Audio CDN** | `GET {cdnBaseUrl}/{pack_id}/{relative_path}` | HTTPS | HTTP GET chunked | Nhị phân tệp âm thanh `.mp3` | Timeout: 15s/tệp. Tải vào `.tmp/`, xác thực SHA-256 trước khi lưu. |

---

## 2. CÁC LỚP NGOẠI LỆ NGHIỆP VỤ (DOMAIN EXCEPTIONS)

Hệ thống định nghĩa các lớp ngoại lệ chuyên biệt để quản lý lỗi có cấu trúc, không quăng lỗi chung chung:

1. **`ContentPackManagerException` (`lib/features/content_packs/data/content_pack_manager.dart`):**
   - Ném ra khi gói học liệu không tương thích phiên bản ứng dụng, sai cấu trúc JSON hoặc mã băm SHA-256 không trùng khớp.
2. **`AudioDownloadException` (`lib/features/audio_management/data/audio_pack_downloader.dart`):**
   - Ném ra khi bộ nhớ thiết bị không đủ chỗ trống, tải tệp bị hủy ngang bởi người dùng, hoặc tệp âm thanh bị lỗi checksum.
3. **`AudioPlaybackException` (`lib/core/audio/unified_audio_playback_service.dart`):**
   - Ném ra khi tệp âm thanh ngoại tuyến không tồn tại trên đĩa hoặc định dạng tệp không thể giải mã.
4. **`AiException` & `AiServerException` (`lib/core/network/ai/models/ai_errors.dart`):**
   - Phân loại lỗi mạng, lỗi khóa API, lỗi rate limit từ máy chủ Google Gemini.
5. **`MigrationException` (`lib/core/database/migrations/migration_engine.dart`):**
   - Ném ra khi một kịch bản di chuyển cơ sở dữ liệu SQLite thất bại, kích hoạt cơ chế rollback bảo toàn dữ liệu.

---

## 3. DANH SÁCH INTERFACE CỦA CÁC SERVICE NỘI BỘ QUAN TRỌNG

### 3.1. `LearningPipelineCoordinator`
```dart
abstract class LearningPipelineCoordinator {
  Future<LessonPipelineResult> recordLessonCompletion({
    required String lessonId,
    required double aggregateScore,
    required List<String> completedSegmentIds,
    DatabaseExecutor? executor,
  });

  Future<ExerciseAttempt> recordExerciseAttempt({
    required ExerciseAttempt attempt,
    DatabaseExecutor? executor,
  });

  Future<void> recordSrsReview({
    required String cardId,
    required SrsRating rating,
    DatabaseExecutor? executor,
  });

  Future<Map<MasteryState, int>> getMasterySummary({String itemType = 'vocabulary'});
}
```

### 3.2. `AudioStorageManager`
```dart
abstract class AudioStorageManager {
  String getPackDirectory(String packId);
  String getPackAudioDirectory(String packId);
  String getPackStagingDirectory(String packId);
  Future<void> ensureDirectories(String packId);
  Future<bool> verifyFileIntegrity(File file, String expectedSha256);
  Future<String> promoteFromStaging({
    required String packId,
    required String tempFileName,
    required String relativeTargetFilePath,
    required String expectedSha256,
  });
  Future<int> calculatePackDiskUsage(String packId);
  Future<void> cleanStaging(String packId);
  Future<void> deletePackAudio(String packId);
  Future<bool> hasSufficientStorage(int requiredBytes);
}
```

### 3.3. `DataManagementService`
```dart
abstract class DataManagementService {
  Future<StorageBreakdown> getStorageBreakdown();
  Future<List<String>> checkIntegrity();
  Future<File> createBackup({String? customName});
  Future<List<File>> listBackups();
  Future<void> restoreBackup(File backupFile);
  Future<String> exportUserDataJson();
  Future<bool> importUserDataJson(String jsonString);
  Future<void> clearAllUserData({required String confirmationCode});
}
```
