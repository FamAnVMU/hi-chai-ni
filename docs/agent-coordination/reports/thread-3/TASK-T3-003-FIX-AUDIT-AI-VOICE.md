# BÁO CÁO KHẮC PHỤC LỖI KỸ THUẬT AI & VOICE TỪ THREAD 5 AUDIT
**Task ID:** TASK-T3-003-FIX-AUDIT-AI-VOICE  
**Thread:** Thread 3 (AI Intelligence & Voice Lab)  
**Owner:** Senior AI Engineer, LLM Systems Architect, Speech Processing Engineer & Voice AI Specialist  
**Date:** 2026-11-05  
**Auditor:** Thread 5 (Independent QA & Release Engineer)  
**Căn cứ kiểm toán:** `audit/BAO_CAO_KIEM_TOAN_HI_CHINESE.md` (Findings: F-06, F-12, F-18, F-22, F-30)

---

## 1. TỔNG QUAN XỬ LÝ THEO MỨC ĐỘ ƯU TIÊN

| Finding | Mức độ | Mô tả vấn đề | Giải pháp & Trạng thái |
|---|---|---|---|
| **F-06 / F-18** | **CRITICAL** | Mic tiếp tục ghi âm dưới nền khi rời tab AI Tutor; TTS streaming không bị hủy; `DefaultAudioRecorderService` rò rỉ observer của `AppLifecycleManager`. | **ĐÃ XỬ LÝ**: Bổ sung `dispose()`, unregister lifecycle observer; tích hợp `cancelCurrentTurn()` & `CancelToken` ngắt SSE/HTTP request; lắng nghe `selectedTabProvider` để ngắt mic và audio khi chuyển tab. |
| **F-12** | **HIGH** | 79 URI âm thanh trỏ tới Asset ảo không tồn tại trong catalogs (Pinyin, Shadowing, Pronunciation). | **ĐÃ XỬ LÝ**: `DefaultAudioPlayerService` chủ động kiểm tra `rootBundle.load()`; nếu asset thiếu thì tự động chuyển sang đọc fallback bằng hệ thống TTS chuẩn mà không ném crash exception. |
| **F-22** | **MEDIUM** | Nguy cơ SSRF và lộ plain API key qua proxy URL không an toàn. | **ĐÃ XỬ LÝ**: Thắt chặt `saveCustomProxyUrl` (chỉ nhận HTTPS, chặn localhost/private IP); bổ sung `_validateEndpointSecurity()` trong `GeminiRestAiProvider.testConnection()`, `verifyCredentials()`, và `_resolveSecureBaseUrl()`. |
| **F-30** | **MEDIUM** | Tệp ghi âm tạm thời `.m4a`/`.wav` không được dọn dẹp gây tràn bộ nhớ thiết bị. | **ĐÃ XỬ LÝ**: Tạo `AudioTempCleaner`, hook dọn dẹp tự động lúc khởi động app (`AppStartupNotifier` bước 1), và dọn dẹp khi ghi âm lại/hủy trong `PronunciationLabScreen`. |

---

## 2. CHI TIẾT THAY ĐỔI KỸ THUẬT

### 2.1. Quản lý vòng đời Mic & Audio Session khi rời màn hình AI Tutor (F-06, F-18)
- **`lib/core/audio/audio_recorder_service.dart`**:
  - Tại `DefaultAudioRecorderService.dispose()`: Thêm lệnh `AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleStop);` tránh rò rỉ listener.
- **`lib/features/ai_tutor/domain/voice/voice_conversation_service.dart`**:
  - Thêm phương thức `cancelCurrentTurn()` và `stopListening()` vào interface `VoiceConversationService`.
  - Tích hợp `CancelToken _currentTurnCancelToken` vào các lượt chat AI. Khi người dùng ngắt lời (`interrupt()`), dừng (`cancelCurrentTurn()`), rời màn hình, hoặc khi app lifecycle stop: lập tức hủy token (`cancel()`) để ngắt request Gemini SSE/HTTP đang chạy và dừng `player` lẫn `tts`.
- **`lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart`**:
  - Hook vào `deactivate` và `dispose` để gọi `_abortActiveVoiceAndAudio()`.
  - Thêm `ref.listen<AppTab>(selectedTabProvider)` phát hiện người dùng chuyển tab để dừng micro, hủy stream và ngắt TTS ngay lập tức.

### 2.2. Xử lý URI âm thanh trỏ tới Asset ảo (F-12)
- **`lib/core/audio/audio_player_service.dart`**:
  - Injected lazy `TtsService _effectiveTts` vào `DefaultAudioPlayerService`.
  - Khi phát asset (`cleanUri.startsWith('assets/')`), kiểm tra sự tồn tại qua `rootBundle.load(cleanUri)`.
  - Nếu asset chưa được nạp/đóng gói: tự động chuyển sang đọc văn bản phát âm tương ứng bằng TTS (`zh-CN`) qua phương thức `_deriveTextFromAudioUri()`, cập nhật trạng thái `playing` -> `completed` an toàn, không phát sinh lỗi văng app.

### 2.3. Bảo mật Custom Proxy URL và API Key (F-22)
- **`lib/core/network/ai/models/ai_errors.dart`**:
  - Bổ sung `class SecurityException implements Exception`.
- **`lib/core/network/ai/providers/gemini_rest_ai_provider.dart`**:
  - Xây dựng phương thức thẩm tra bảo mật `_validateEndpointSecurity(String url)`.
  - Trước khi gọi API trong `testConnection()`, `verifyCredentials()`, và `_resolveSecureBaseUrl()`: nếu URL không dùng HTTPS hoặc trỏ tới `localhost`, `127.0.0.1`, `0.0.0.0`, `::1`, hay các dải IP Private (`10.x.x.x`, `172.16-31.x.x`, `192.168.x.x`), provider lập tức ném `SecurityException` ngăn chặn gửi header `x-goog-api-key`.
- **`test/core/network/ai/security/ai_credential_security_test.dart`**:
  - Bổ sung test case `7c. GeminiRestAiProvider.testConnection throws SecurityException before sending API key if proxy is unsafe`.

### 2.4. Dọn dẹp tệp ghi âm tạm thời tránh tràn bộ nhớ (F-30)
- **`lib/core/audio/audio_temp_cleaner.dart`**:
  - Cung cấp `AudioTempCleaner.cleanupTempAudioFiles({Duration olderThan})`: Quét thư mục tạm của ứng dụng, xóa các tệp ghi âm `rec_*.m4a`/`*.wav` cũ hơn thời gian quy định (mặc định 1 giờ).
  - Cung cấp `AudioTempCleaner.deleteAudioFile(String? filePath)`: Xóa ngay lập tức file ghi âm đơn lẻ.
- **`lib/core/startup/app_startup_provider.dart`**:
  - Tích hợp `AudioTempCleaner.cleanupTempAudioFiles()` vào Bước 1 của chu trình khởi động ứng dụng (`AppStartupNotifier.initialize`).
- **`lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart`**:
  - Dọn dẹp tệp ghi âm cũ trước khi bắt đầu lượt thu mới và dọn dẹp khi dispose màn hình nếu người dùng không lưu.
- **`test/core/audio/audio_temp_cleaner_test.dart`**:
  - Kiểm thử dọn dẹp tự động theo tuổi của file và xóa file an toàn.

---

## 3. KẾT QUẢ KIỂM THỬ THỰC TẾ

1. **Core Audio Test Suite (bao gồm Lifecycle, TTS fallback, AudioTempCleaner):**
   ```
   flutter test test/core/audio/
   -> 00:01 +9: All tests passed! (100% PASS)
   ```
2. **AI Credential & Security Test Suite (bao gồm SSRF & Proxy validation):**
   ```
   flutter test test/core/network/ai/
   -> 00:04 +27: All tests passed! (100% PASS)
   ```
3. **Pronunciation Feature Test Suite:**
   ```
   flutter test test/features/pronunciation/
   -> 00:10 +13: All tests passed! (100% PASS)
   ```
4. **Master Regression Test Suite (Toàn bộ 15 modules của ứng dụng):**
   ```
   flutter test test/regression/full_app_regression_test.dart
   -> 00:39 +15: All tests passed! (100% PASS)
   ```

---

## 4. TỔNG KẾT BÀN GIAO CHO THREAD 5
- **Branch:** `feature/thread-3-ai-voice`
- **Tình trạng:** Tất cả 4 nhóm lỗi kỹ thuật F-06, F-12, F-18, F-22, F-30 đã được giải quyết triệt để và xác minh qua automated tests.
