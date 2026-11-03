# API INVENTORY – CÁC GIAO TIẾP VÀ DỊCH VỤ

Tài liệu này tổng hợp toàn bộ các API ngoại vi (External REST / Live WebSockets) và các API dịch vụ nội bộ (Internal Service Contracts) trong HI Chinese.

---

## 1. EXTERNAL API ENDPOINTS (DỊCH VỤ BÊN NGOÀI)

### 1.1. Google Gemini Generative Language REST API
- **Endpoint:** `POST https://generativelanguage.googleapis.com/v1beta/models/{modelId}:generateContent?key={apiKey}`
- **Giao thức:** HTTPS REST / JSON
- **Mục đích:** Gửi yêu cầu gia sư AI, chấm bài luận, giải thích ngữ pháp, và trả lời câu hỏi đọc hiểu.
- **Model sử dụng:**
  - `gemini-3.5-flash-lite`: Mặc định cho đàm thoại nhẹ và phản hồi nhanh.
  - `gemini-3.8-flash`: Đàm thoại sâu sắc, phân tích ngữ pháp, đa thể thức.
  - `gemini-3.1-pro-preview`: Phân tích sư phạm chuyên sâu.
- **Header:** `Content-Type: application/json`
- **Request Body:**
  ```json
  {
    "contents": [
      {
        "role": "user",
        "parts": [{"text": "Câu hỏi của học viên"}]
      }
    ],
    "systemInstruction": {
      "parts": [{"text": "Chỉ thị vai trò gia sư AI, cấu trúc JSON trả về bắt buộc."}]
    },
    "generationConfig": {
      "temperature": 0.7,
      "topP": 0.95,
      "maxOutputTokens": 1024
    }
  }
  ```
- **Response Format (Thành công 200 OK):**
  ```json
  {
    "candidates": [
      {
        "content": {
          "parts": [{"text": "{\"reply_zh\":\"...\",\"reply_vi\":\"...\"}"}],
          "role": "model"
        },
        "finishReason": "STOP"
      }
    ]
  }
  ```
- **Xử lý lỗi & Timeout:**
  - Timeout: 30 giây.
  - Lỗi 400: Sai cấu trúc JSON hoặc API Key không hợp lệ.
  - Lỗi 403: API Key bị khóa hoặc hết quota.
  - Lỗi 429: Rate limit -> kích hoạt exponential backoff.
  - Lỗi 500: Lỗi máy chủ Google Gemini -> fallback về câu trả lời thông báo lịch sự.
- **Thành phần gọi:** `GeminiRestAiProvider` (`lib/core/network/ai/providers/gemini_rest_ai_provider.dart`).
- **Trạng thái:** **IMPLEMENTED** (Bảo mật: API Key lưu trong `FlutterSecureStorage`).

---

### 1.2. Google Gemini Live Bidirectional WebSocket API
- **Endpoint:** `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent`
- **Giao thức:** WebSocket hai chiều
- **Mục đích:** Đàm thoại thời gian thực bằng giọng nói (Voice Conversation) giữa học viên và gia sư AI.
- **Model sử dụng:** `gemini-3.8-live`
- **Thành phần gọi:** `VoiceConversationService` (`lib/features/ai_tutor/domain/voice/voice_conversation_service.dart`).
- **Trạng thái:** **IMPLEMENTED** (Tích hợp state machine hoàn chỉnh: xin quyền micro, VAD, ngắt lời, mô phỏng chuyển giọng nói thành văn bản).

---

### 1.3. Static Content CDN / GitHub Raw Releases
- **Endpoint:** `GET https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/{pack_id}.json`
- **Giao thức:** HTTPS GET
- **Mục đích:** Tải các gói học liệu chuẩn hóa bổ sung (ví dụ: HSK 3, HSK 4) không đóng gói sẵn trong APK.
- **Response:** File JSON định dạng chuẩn `ContentPackManifest` + `Curriculum` + `ContentItems`.
- **Thành phần gọi:** `ContentPackRemoteService` (`lib/features/content_packs/data/content_pack_remote_service.dart`).
- **Trạng thái:** **IMPLEMENTED**.

---

### 1.4. Static Audio Asset CDN / Distribution Endpoint
- **Endpoint:** `GET {cdnBaseUrl}/{package_id}/{relative_path}` (Cấu hình qua `ContentSourceConfig`)
- **Giao thức:** HTTPS GET (Hỗ trợ chunked streaming)
- **Mục đích:** Tải tệp âm thanh phát âm theo từng gói cấp độ HSK.
- **Thành phần gọi:** `AudioPackDownloader` (`lib/features/audio_management/data/audio_pack_downloader.dart`).
- **Trạng thái:** **IMPLEMENTED**.

---

## 2. INTERNAL SERVICE CONTRACTS (DỊCH VỤ NỘI BỘ)

### 2.1. `LearningPipelineCoordinator`
- **Vị trí:** `lib/features/learning_pipeline/data/learning_pipeline_coordinator.dart`
- **Phương thức chính:**
  - `recordLessonCompletion({required String lessonId, required double aggregateScore, ...}) -> Future<LessonPipelineResult>`
  - `recordExerciseAttempt({required ExerciseAttempt attempt}) -> Future<ExerciseAttempt>`
  - `recordSrsReview({required String cardId, required SrsRating rating}) -> Future<void>`
  - `getMasterySummary({String itemType}) -> Future<Map<MasteryState, int>>`
- **Trách nhiệm:** Đảm bảo tính toàn vẹn và đồng bộ giữa hoàn thành bài học, kết quả bài tập và hàng đợi ôn tập SRS trong một SQLite Transaction duy nhất.

### 2.2. `ContentPackManager`
- **Vị trí:** `lib/features/content_packs/data/content_pack_manager.dart`
- **Phương thức chính:**
  - `validateManifest(ContentPackManifest manifest, {String? rawJson}) -> Future<void>`
  - `installOrUpdatePack(String rawJson, {Function? onProgress}) -> Future<ContentPackInstallResult>`
  - `uninstallPack(String packId, {bool force}) -> Future<bool>`
  - `verifyIntegrity(String packId) -> Future<bool>`
- **Trách nhiệm:** Nạp giáo trình từ JSON, kiểm tra tính hợp lệ về phiên bản và mã băm SHA-256, tự động backfill sang `knowledge_registry` và `lesson_knowledge_items`.

### 2.3. `AudioStorageManager`
- **Vị trí:** `lib/features/audio_management/data/audio_storage_manager.dart`
- **Phương thức chính:**
  - `ensureDirectories(String packId) -> Future<void>`
  - `verifyFileIntegrity(File file, String expectedSha256) -> Future<bool>`
  - `promoteFromStaging({required String packId, ...}) -> Future<String>`
  - `calculatePackDiskUsage(String packId) -> Future<int>`
  - `cleanStaging(String packId) -> Future<void>`
  - `deletePackAudio(String packId) -> Future<void>`
- **Trách nhiệm:** Quản lý cây thư mục `content_packs/{pack_id}/audio/` và `.tmp/`, di chuyển tệp nguyên tử sau khi khớp mã băm SHA-256.

### 2.4. `UnifiedAudioPlaybackService`
- **Vị trí:** `lib/core/audio/unified_audio_playback_service.dart`
- **Phương thức chính:**
  - `playAudio(String uri, {double speed, bool loop}) -> Future<void>`
  - `pause() -> Future<void>`
  - `resume() -> Future<void>`
  - `stop() -> Future<void>`
  - `setPlaybackSpeed(double speed) -> Future<void>`
- **Trách nhiệm:** Bộ phát âm thanh singleton duy nhất, quản lý single audio focus, điều chỉnh tốc độ từ 0.5x đến 2.0x, kiểm tra tệp offline trước khi phát.

### 2.5. `DataManagementService`
- **Vị trí:** `lib/features/settings/data/services/data_management_service.dart`
- **Phương thức chính:**
  - `createBackup({String? customName}) -> Future<File>`
  - `restoreBackup(File backupFile) -> Future<void>`
  - `exportUserDataJson() -> Future<String>`
  - `importUserDataJson(String jsonString) -> Future<bool>`
  - `clearAllUserData({required String confirmationCode}) -> Future<void>`
  - `checkIntegrity() -> Future<List<String>>`
- **Trách nhiệm:** Bảo vệ dữ liệu người dùng, sao lưu SQLite nguyên tử bằng lệnh `VACUUM INTO`, kiểm tra toàn vẹn bằng `PRAGMA integrity_check`.
