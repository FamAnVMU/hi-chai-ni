# HI Chinese — Architecture Decision Records (ADR)

Tài liệu này ghi lại toàn bộ quyết định kiến trúc, đánh giá kỹ thuật và danh sách dependency nền tảng cho dự án **HI Chinese** (Flutter Native Android), được thực hiện trong khuôn khổ **Task 1.2**.

---

## 1. Bối Cảnh & Mục Tiêu Kỹ Thuật

HI Chinese được xây dựng với định vị là ứng dụng Android độc lập 100%, hoạt động theo mô hình **Offline-First**, lưu trữ dữ liệu học tập cục bộ trên thiết bị bằng SQLite, kết hợp AI Tutor qua Google Gemini API.

Mọi package được đưa vào dự án phải thỏa mãn:
1. Tương thích hoàn toàn với Flutter SDK hiện tại (`3.47.9`) và Dart SDK (`3.13.7`).
2. Tương thích với Android toolchain (`minSdk: 24`, `compileSdk: 36`, Java 21 LTS).
3. Đang được cộng đồng và tác giả tích cực bảo trì, giấy phép mã nguồn mở thân thiện (MIT, BSD, Apache 2.0).
4. Không cài đặt package dư thừa, không cài package chỉ vì xuất hiện trong kế hoạch cũ.

---

## 2. Quyết Định Kiến Trúc Từng Phân Hệ

### 2.1. Quản Lý Trạng Thái (State Management & DI)
- **Package được chọn:** `flutter_riverpod: ^3.4.3`
- **Giấy phép:** MIT
- **Lý do chọn:**
  - Compile-time safety cao, không phụ thuộc vào `BuildContext` để đọc logic dữ liệu.
  - Tách biệt hoàn hảo giữa tầng Presentation, Domain và Data.
  - Hỗ trợ scoped state, autoDispose giúp giải phóng bộ nhớ tự động khi màn hình đóng.
  - Dễ dàng ghi đè (override) provider phục vụ Unit Test và Widget Test qua `ProviderContainer`.
- **Đánh giá Code Generation (`riverpod_generator`):**
  - **Quyết định: KHÔNG dùng generator.** Ở quy mô dự án hiện tại, viết Provider thuần chức năng giúp loại bỏ hoàn toàn gánh nặng chạy `build_runner`, tránh kéo dài thời gian build và ngăn ngừa xung đột phiên bản generator.
- **Phương án thay thế đã xem xét:**
  - *Bloc:* Quá nhiều boilerplate cho 15 tính năng, làm chậm tốc độ phát triển.
  - *Provider:* Thiếu compile-time safety, dễ gặp lỗi runtime `ProviderNotFoundException`.
  - *GetX:* Quá nhiều anti-pattern toàn cục, vi phạm nguyên tắc Clean Architecture.

---

### 2.2. Cơ Sở Dữ Liệu Cục Bộ (SQLite & File Path)
- **Package được chọn:** `sqflite: ^2.4.5` và `path: ^1.9.1`
- **Giấy phép:** BSD-2-Clause / BSD-3-Clause
- **Lý do chọn:**
  - Giải pháp SQLite chính thức và lâu đời nhất trên Flutter/Android, được gắn nhãn *Flutter Favorite*.
  - Gọi trực tiếp SQLite native của hệ điều hành Android thông qua Java/Kotlin platform channel, tốc độ truy vấn cực nhanh và tiêu thụ ít RAM.
  - Hỗ trợ đầy đủ Raw SQL, Transaction, Batch operation, Indexing và cơ chế Database Migration theo version chặt chẽ.
- **Chế độ WAL (Write-Ahead Logging):**
  - Sẽ được kích hoạt thông qua `PRAGMA journal_mode=WAL` sau khi triển khai và kiểm chứng checkpoint, backup trong Task 1.3.
- **Phương án thay thế đã xem xét:**
  - *Drift (Moor):* Yêu cầu build_runner code-gen phức tạp, không cần thiết cho quy mô schema hiện tại.
  - *Hive / Isar:* NoSQL không có quan hệ bảng, rất khó xây dựng thuật toán SRS liên kết từ vựng, ngữ pháp, tiến độ học và lịch sử ôn tập.

---

### 2.3. Lưu Trữ An Toàn & Bảo Mật Khóa (Secure Storage)
- **Package được chọn:** `flutter_secure_storage: ^11.2.0`
- **Giấy phép:** BSD-3-Clause
- **Lý do chọn:**
  - Trên Android, package tự động sử dụng `EncryptedSharedPreferences` được mã hóa bởi master key trong Android KeyStore phần cứng (AES-256 GCM).
  - Phù hợp để lưu trữ API key Gemini cá nhân, token xác thực và cấu hình nhạy cảm.

#### ⚠️ CẢNH BÁO BẢO MẬT & CHIẾN LƯỢC BẢO VỆ API KEY:
- **Nguyên tắc kỹ thuật trung thực:** `flutter_secure_storage` chỉ bảo vệ dữ liệu ở trạng thái nghỉ (data at rest). **Nó KHÔNG làm cho API key nhúng trong client trở nên không thể trích xuất.** Kẻ tấn công có thiết bị đã root, sử dụng kỹ thuật memory dumping hoặc hooking qua Frida/Xposed khi ứng dụng đang chạy vẫn có thể đọc được key trong bộ nhớ.
- **Chiến lược cho bản phát hành rộng rãi (Production Public Distribution):**
  - Tuyệt đối không nhúng Google AI Studio API Key bí mật dùng chung vào file build APK.
  - Sử dụng kiến trúc **Managed Backend Proxy** hoặc **Firebase AI Logic kết hợp Firebase App Check** (xác thực tính toàn vẹn của thiết bị qua Google Play Integrity API) để quản lý quota và ngăn chặn lạm dụng.
- **Chiến lược cho sản phẩm cá nhân (BYOK — Bring Your Own Key):**
  - Người dùng tự cấu hình API Key từ Google AI Studio trong mục Cài đặt.
  - Ứng dụng cung cấp:
    1. Cảnh báo rõ ràng về rủi ro trích xuất key nếu thiết bị bị xâm nhập.
    2. Hướng dẫn người dùng tạo API Key có thiết lập giới hạn hạn mức (API Quota Restriction) và giới hạn phạm vi (chỉ cấp quyền duy nhất cho Gemini API trên Google Cloud Console).
    3. Nút kiểm tra kết nối hợp lệ.
    4. Nút thu hồi / xóa sạch key khỏi `flutter_secure_storage` bất cứ lúc nào.

---

### 2.4. Xác Minh Gemini SDK & Quyết Định Nền Tảng AI (Bắt Buộc)

#### Thực trạng khảo sát từ tài liệu chính thức của Google:
1. Package `google_generative_ai` trên pub.dev hiện đã bị Google đánh dấu **chỉ dùng cho prototyping** và không còn được khuyến nghị cho ứng dụng thực tế.
2. Package `firebase_vertexai` cũng đã bị khai tử và sáp nhập vào `firebase_ai`.
3. Chuẩn mới của Google cho Flutter hiện tại là **`firebase_ai`** (Firebase AI Logic SDK).

#### Bảng so sánh các phương án tích hợp Gemini AI:

| Tiêu chí | `google_generative_ai` (Cũ) | `firebase_ai` (Firebase AI Logic) | Trực tiếp Native REST (SSE) + WebSocket |
| :--- | :--- | :--- | :--- |
| **Trạng thái bảo trì** | ⚠️ Bị Google hạ cấp / Prototyping | ✅ Chuẩn chính thức mới của Google | ✅ Chuẩn API HTTP/WebSocket v1beta của Google |
| **Yêu cầu Firebase** | Không | Bắt buộc (`firebase_core`, `google-services.json`) | **Hoàn toàn Không** |
| **Khả năng BYOK (Người dùng tự nhập key)** | Có | Rất khó (ràng buộc vào GCP/Firebase project) | **Rất thuận tiện & linh hoạt** |
| **Bảo vệ App Check** | Không | Có (qua Firebase App Check) | Có thể áp dụng khi qua Backend Proxy |
| **Text & Multimodal Streaming** | Có | Có | **Có (qua HTTP Server-Sent Events - SSE)** |
| **Live API (Voice Audio 2 chiều)** | Không hỗ trợ | Không hỗ trợ đầy đủ | **Hỗ trợ chuẩn qua WebSocket BidiGenerateContent** |
| **Tương thích Offline-first** | Trung bình | Kém (phụ thuộc hạ tầng Firebase) | **Hoàn hảo (độc lập, không dính backend cố định)** |

#### Quyết định lựa chọn:
- **Gỡ bỏ hoàn toàn `google_generative_ai` khỏi dự án.**
- Lựa chọn nền tảng: **Gọi trực tiếp Native REST (SSE Streaming) và WebSocket chính thức** sử dụng hai package chuẩn của Dart Team:
  - `http: ^1.6.0` (BSD-3-Clause): Xử lý các request Text/Vision, prompt chat và Server-Sent Events (SSE) streaming theo endpoint `POST /v1beta/models/{model}:streamGenerateContent?alt=sse`.
  - `web_socket_channel: ^3.0.3` (BSD-3-Clause): Kết nối WebSocket hai chiều theo endpoint `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent` phục vụ tính năng Gemini Live Voice.
- Kiến trúc này đảm bảo tính độc lập 100%, hỗ trợ mô hình BYOK trọn vẹn, và sẵn sàng chuyển hướng qua Backend Proxy nếu phát hành diện rộng chỉ bằng việc thay đổi Base URL.

---

### 2.5. Đánh Giá Hệ Thống Âm Thanh (Audio: Recording, Playback, Live Voice)

#### Yêu cầu kỹ thuật từ Gemini Live API:
- Định dạng âm thanh đầu vào bắt buộc: **PCM 16-bit mono, tần số lấy mẫu 16kHz hoặc 24kHz, little-endian**, truyền liên tục dạng stream theo từng chunk nhỏ qua WebSocket.
- Định dạng âm thanh đầu ra từ Gemini: Các gói Base64 chứa raw PCM audio chunk.

#### Đánh giá chi tiết các package:
1. **Ghi âm (Recording):**
   - Package `record` (`record: ^5.x`): Cung cấp hàm `startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1))`, trả về trực tiếp `Stream<List<int>>` chứa dữ liệu PCM raw. Đây là lựa chọn tối ưu nhất cho Live API.
2. **Phát âm thanh (Playback):**
   - `audioplayers` / `just_audio`: Hoạt động rất tốt với các file âm thanh hoàn chỉnh (MP3, WAV, AAC) lưu trữ offline trong assets hoặc cache cho tính năng phát âm từ vựng, hội thoại mẫu.
   - Nhược điểm với Live API: Các player thông thường không hỗ trợ nhận trực tiếp luồng raw PCM byte buffer từ WebSocket mà không có header container WAV, gây trễ lớn (high latency) nếu phải ghi ra file tạm.
   - Giải pháp cho Live Audio: Sẽ sử dụng native Android `AudioTrack` (thông qua Platform Channel hoặc package stream chuyên dụng) để đẩy trực tiếp raw PCM buffer vào loa với độ trễ tối thiểu (< 150ms).
3. **Quyết định:**
   - **Chưa thêm package audio vào `pubspec.yaml` ở Task 1.2** nhằm tuân thủ nguyên tắc "không thêm package khi chưa dùng". Cấu hình và triển khai audio sẽ được thực hiện tại các Sprint chuyên biệt (Sprint 6 cho Pronunciation và Sprint 8 cho Gemini Live Voice).

---

### 2.6. Chiến Lược Font Chữ & Hiển Thị Hán Tự (Offline Assets)
- **Vấn đề của `google_fonts`:**
  - Mặc định tải file font qua HTTP từ Google Fonts CDN trong lần chạy đầu tiên.
  - Khi thiết bị chạy Offline (không có Internet), font không tải được sẽ bị giật giao diện hoặc fallback về font hệ thống, dẫn đến việc hiển thị chữ Hán Giản thể (Simplified Chinese) bị lỗi font hoặc biến dạng nét.
- **Quyết định kiến trúc:**
  - **Gỡ bỏ `google_fonts` khỏi dependencies.**
  - Nhúng trực tiếp font offline vào thư mục `assets/fonts/`:
    - **Inter:** Dành cho chữ cái Latin, số và tiếng Việt có dấu.
    - **Noto Sans SC:** Dành cho Hán tự (chữ Hán Giản thể), đảm bảo mọi ký tự HSK từ cấp 1 đến cấp 6 hiển thị hoàn hảo ở chế độ Offline.

---

### 2.7. Hệ Thống Biểu Tượng (Icons)
- **Quyết định:** Thống nhất sử dụng **Material Icons** tích hợp sẵn trong Flutter SDK (`uses-material-design: true`), kết hợp `cupertino_icons: ^1.0.8` làm biểu tượng bổ trợ.
- Giữ dung lượng app nhẹ, không cần kéo thêm các bộ icon cồng kềnh từ bên ngoài, đảm bảo tính nhất quán trên nền Android Material 3.

---

### 2.8. Tuần Tự Hóa Dữ Liệu (JSON & Model Serialization)
- **Quyết định: Sử dụng `dart:convert` với phương thức thủ công `fromJson` và `toMap` / `fromMap`.**
- **Lý do:**
  - Các thực thể dữ liệu của HI Chinese (Vocabulary, Grammar, Card, Progress) có cấu trúc trường rõ ràng và ổn định.
  - Việc tự viết serialization thủ công giúp code dễ hiểu, không phụ thuộc vào `build_runner`, `freezed` hay `json_serializable`, giữ cho tốc độ biên dịch nhanh nhất.

---

### 2.9. Nền Tảng Kiểm Thử (Testing & Mocking)
- **Package kiểm thử:**
  - `flutter_test`: Tích hợp sẵn trong Flutter SDK.
  - `mocktail: ^1.0.5` (dev_dependencies): Thư viện mocking cho Dart không yêu cầu code-gen, cú pháp trực quan (`when()`, `verify()`), hỗ trợ fallback values cho các object tùy biến.
- **Quy chuẩn:** Sử dụng Fake Repository Pattern trong Clean Architecture cho integration test để kiểm tra logic mà không cần mở kết nối DB/Network thật.

---

## 3. Danh Sách Dependencies Chính Thức Sau Task 1.2

```yaml
environment:
  sdk: ^3.13.7

dependencies:
  flutter:
    sdk: flutter

  # UI & Iconography
  cupertino_icons: ^1.0.8

  # State Management & DI
  flutter_riverpod: ^3.4.3

  # SQLite Local Database (Offline-first)
  sqflite: ^2.4.5
  path: ^1.9.1

  # Local Key-Value & Encrypted Storage
  flutter_secure_storage: ^11.2.0
  shared_preferences: ^2.5.6

  # Networking & Gemini AI (REST SSE + WebSocket Live)
  http: ^1.6.0
  web_socket_channel: ^3.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.5
```

---

## 4. Tổng Kết & Nghiệm Thu
- Toàn bộ dependency đều có giấy phép mã nguồn mở thân thiện, được bảo trì tích cực bởi Flutter / Dart Team hoặc tác giả uy tín.
- Không có bất kỳ package nào bị deprecated trong danh sách.
- Đã chạy kiểm tra tự động:
  - `flutter pub get`: Thành công 100%.
  - `flutter analyze`: **0 cảnh báo / 0 lỗi**.
  - `flutter test`: **Toàn bộ test vượt qua**.

---

## 5. Cấu Hình Nền Tảng Android Native & Chính Sách Quyền (Task 1.3)

### 5.1. Khai Báo Quyền & Nguyên Tắc Tối Thiểu (Least Privilege)
- **Khai báo trong `AndroidManifest.xml`:**
  - `android.permission.INTERNET`: Cần thiết cho việc kết nối API Google Gemini (AI Tutor) và đồng bộ từ điển trực tuyến khi có mạng.
  - `android.permission.RECORD_AUDIO`: Dành riêng cho chức năng Luyện phát âm (Pronunciation), Nhại giọng (Shadowing) và Đàm thoại thời gian thực (Gemini Live Voice).
  - `<uses-feature android:name="android.hardware.microphone" android:required="false" />`: Đánh dấu phần cứng micro là tùy chọn, cho phép các thiết bị máy tính bảng Android hoặc thiết bị không có micro vẫn có thể cài đặt và sử dụng các tính năng học từ vựng, ngữ pháp, đọc hiểu offline.
- **Tuyệt đối không xin quyền lưu trữ rộng:**
  - Không sử dụng `MANAGE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE` hay `WRITE_EXTERNAL_STORAGE`.
  - Toàn bộ cơ sở dữ liệu SQLite (`hi_chinese.db`), cache âm thanh và file bài học được lưu trữ độc quyền trong App-Specific Internal Storage (`Context.getFilesDir()`), an toàn và tự động dọn dẹp khi gỡ cài đặt.

### 5.2. Luồng Yêu Cầu Quyền Micro Theo Ngữ Cảnh (Contextual Permission Flow)
- **Quy tắc:** Tuyệt đối KHÔNG xin quyền Micro khi người dùng vừa mở ứng dụng.
- **Quy trình:**
  1. Khi người dùng chủ động nhấn vào tính năng cần ghi âm (Luyện nói, AI Voice Chat), ứng dụng kiểm tra `Permission.microphone.status`.
  2. Nếu quyền chưa được cấp (`isDenied`), hiển thị **Hộp thoại Giải thích Ngữ cảnh (Rationale Dialog)** thông báo rõ:
     - Mục đích sử dụng micro: Nhận diện phát âm Hán ngữ và đối thoại với AI.
     - Cam kết quyền riêng tư: Ứng dụng chỉ thu âm khi người dùng giữ nút nói và tuyệt đối không bao giờ thu âm ngầm trong nền.
  3. Nếu người dùng chọn "Tiếp tục", ứng dụng mới kích hoạt hộp thoại xin quyền của hệ điều hành Android (`Permission.microphone.request()`).
  4. Nếu quyền bị từ chối vĩnh viễn (`isPermanentlyDenied`), hiển thị hộp thoại hướng dẫn người dùng bấm nút mở trực tiếp Cài đặt ứng dụng qua `openAppSettings()`.

### 5.3. Vòng Đời Ứng Dụng (Lifecycle) & An Toàn Thu Âm
- Triển khai `AppLifecycleManager` kế thừa `WidgetsBindingObserver` để giám sát trạng thái `didChangeAppLifecycleState`.
- **Chính sách ngắt micro nền:**
  - Khi ứng dụng chuyển sang `AppLifecycleState.paused`, `inactive` hoặc `hidden` (do người dùng chuyển sang app khác, có cuộc gọi đến, hoặc khóa màn hình):
    - Hệ thống ngay lập tức kích hoạt callback hủy phiên ghi âm và giải phóng micro về cho hệ điều hành Android.
    - Cập nhật giao diện về trạng thái dừng an toàn (idle).
    - Ngăn chặn hoàn toàn hành vi chạy ngầm micro âm thầm.

### 5.4. Giao Diện Edge-to-Edge & Vùng An Toàn (Safe Area)
- **Edge-to-Edge System UI:** Kích hoạt `SystemUiMode.edgeToEdge` kết hợp `SystemUiOverlayStyle` với thanh trạng thái (Status Bar) và thanh điều hướng (Navigation Bar) trong suốt (`Colors.transparent`), icon sáng trên nền Dark Forest.
- **Tránh White Flash khi mở app:** Cấu hình `splash_bg` (`#121811`) cho `launch_background.xml` và `NormalTheme` trong Android native, đảm bảo trải nghiệm mở app tối màu mượt mà, không giật màn hình trắng.
- **Xử lý tai thỏ (Notch/Cutout) & Phím điều hướng cử chỉ:** Bọc layout với `SafeArea` và `SingleChildScrollView`, tự động thích ứng với tai thỏ trên đỉnh và thanh cử chỉ (gesture pill) ở cạnh dưới màn hình.
- **Xử lý bàn phím:** Cấu hình `android:windowSoftInputMode="adjustResize"` giúp giao diện tự động co lại khi bàn phím ảo xuất hiện, không che khuất ô nhập liệu hay nút bấm.
- **Khóa xoay màn hình:** Khóa cố định chiều dọc (`DeviceOrientation.portraitUp`, `DeviceOrientation.portraitDown`) để tối ưu hóa trải nghiệm học tập di động một tay.

### 5.5. Cấu Hình Bảo Mật Mạng (Network Security)
- Thiết lập `android:usesCleartextTraffic="false"` trên thẻ `<application>`.
- Chặn đứng mọi kết nối HTTP không mã hóa, chỉ cho phép HTTPS và WSS an toàn cho các tác vụ mạng và AI.

### 5.6. Phiên Bản Android Đã Xác Minh
- **Min SDK:** 24 (Android 7.0 Nougat) — đảm bảo hỗ trợ Android KeyStore AES-256 GCM và SQLite WAL.
- **Compile SDK:** 36 (Android 16 preview / Android 15 chuẩn).
- **Target SDK:** API Level 34+ (Tuân thủ chính sách Google Play Store mới nhất).



---

## 6. Thiết Kế Tầng AI Service & Text Streaming (Task 3.1)

### 6.1. Xác Minh Trạng Thái Model Trực Tiếp Từ Tài Liệu Google Gemini (Q1 2026)
- **Tài liệu chính thức Google Gemini Deprecations & Releases:**
  - Google thông báo chính thức: *"To ensure reliable performance for everyone, we are limiting access to the 2.5 models to users who have actively used them in the past. For any new projects, use our latest models: 3.5 Flash-Lite or 3.8 Flash."*
  - Các model preview cũ như `gemini-2.5-flash-preview-09-25` có ngày shutdown là tháng 2/2026.
- **Quyết định định tuyến model (Model Routing):**
  - **Model mặc định cho Chat Tutor & Tra từ điển:** `gemini-3.5-flash-lite` (nhanh, chi phí tối ưu, độ trễ thấp).
  - **Model cho Sửa ngữ pháp & Đọc hiểu:** `gemini-3.8-flash` (độ chính xác cao, hiểu ngữ cảnh phức tạp).
  - **Model cho Phân tích sư phạm chuyên sâu:** `gemini-3.1-pro-preview`.
  - Tuyệt đối KHÔNG hardcode cố định model ID lỗi thời; toàn bộ model được quản lý tập trung qua `AiModelRegistry` và cho phép tùy biến qua Settings.

### 6.2. Đánh Giá SDK & Lựa Chọn Kiến Trúc Provider-Independent
1. **`google_generative_ai` (Dart SDK cũ):** Đã bị Google đánh dấu ngừng duy trì, không tương thích với các chuẩn streaming và tool calling hiện đại. Loại bỏ hoàn toàn.
2. **`firebase_ai` (Firebase AI Logic):** Là giải pháp được khuyến cáo cho các ứng dụng có backend Firebase và App Check nhằm che giấu API key của nhà phát triển. Tuy nhiên, với HI Chinese là ứng dụng ưu tiên **Offline-first**, việc ép buộc người dùng cài đặt Firebase Core và cấu hình Google Services sẽ phá vỡ tính độc lập.
3. **Quyết định: Provider Pattern độc lập SDK (`AiProvider`):**
   - Định nghĩa interface `AiProvider` với hai phương thức cốt lõi: `generateText()` và `streamText()`.
   - Triển khai `GeminiRestAiProvider`: Gọi trực tiếp REST API `POST /v1beta/models/{model}:generateContent` và Server-Sent Events (SSE) `POST /v1beta/models/{model}:streamGenerateContent?alt=sse` bằng `http.Client`. Hỗ trợ đổi Base URL sang Backend Proxy khi cần.
   - Triển khai `MockAiProvider`: Mô phỏng 100% các tình huống (streaming nhiều chunk, timeout, lỗi 429 rate limit, 401 unauthorized, rớt mạng, cancellation) phục vụ test offline và CI/CD mà không tốn phí hoặc phụ thuộc mạng.

### 6.3. Kiến Trúc Bảo Mật & Mô Hình BYOK (Bring Your Own Key)
- **Cảnh báo bảo mật từ Google:** Tuyệt đối không bao giờ nhúng Gemini API key bí mật của nhà phát triển vào file APK/client di động vì kẻ xấu có thể decompile mã nguồn hoặc trích xuất từ bộ nhớ RAM.
- **Giải pháp bảo vệ của HI Chinese:**
  - Áp dụng mô hình **BYOK (Bring Your Own Key)**: Người dùng tự nhập API key cá nhân của họ trong phần Cài đặt hoặc cấu hình URL Proxy cá nhân.
  - Lưu trữ mã hóa tại thiết bị (Encryption at Rest) bằng `FlutterSecureStorage` trên nền tảng Android KeyStore với thuật toán AES-256 GCM.
  - **Ranh giới bảo mật:** `FlutterSecureStorage` bảo vệ key không bị các ứng dụng khác đọc lén từ file hệ thống, nhưng khi key được nạp vào RAM trong quá trình gọi API, thiết bị Android đã bị root hoặc can thiệp bộ nhớ vẫn có thể bị trích xuất. Giao diện ứng dụng và tài liệu sẽ thông báo minh bạch điều này cho người học.
  - **Chính sách Zero-Log:** Tuyệt đối không log API key trong mã nguồn, console log hay crash analytics. Cung cấp hàm `getMaskedApiKey()` hiển thị dạng `AIzaSy...4xQ1` trên UI.
  - Hỗ trợ người dùng kiểm tra kết nối (`verifyCredentials`), thay đổi hoặc xóa bỏ API key tức thì.

### 6.4. Text Streaming, Timeout, Bounded Retries & Cancellation
- **Streaming mượt mà (Non-blocking):** Nhận stream qua `LineSplitter` xử lý từng dòng SSE (`data: {...}`), giải mã token tăng dần và đẩy ra `Stream<AiStreamChunk>` mà không làm block UI isolate.
- **Hỗ trợ Cancellation (`CancelToken`):** Cho phép người dùng bấm nút "Dừng tạo câu trả lời" bất kỳ lúc nào; `CancelToken` sẽ hủy ngay `StreamSubscription` và ngắt kết nối HTTP socket bên dưới.
- **Chính sách Thử lại Giới hạn (Bounded Retries):**
  - Chỉ tự động thử lại tối đa 2 lần với thuật toán Exponential Backoff (500ms $\to$ 1000ms) khi gặp lỗi mạng tạm thời hoặc lỗi máy chủ Google (500, 503).
  - **Tuyệt đối KHÔNG retry** khi gặp lỗi xác thực (401, 403), dữ liệu sai (400), vượt hạn mức (429) hoặc sau khi người dùng đã bấm Cancel, ngăn ngừa việc gọi lặp vô tận gây tính phí tài khoản.
