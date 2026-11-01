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


---

## 7. Thiết Kế Bộ Não AI Tutor & Context Builder (Task 3.2)

### 7.1. Nguyên Tắc Sư Phạm 3 Bước & Rào Chắn Chống Sửa Nhầm (Anti-Hypercorrection)
- **Vấn đề sư phạm phổ biến ở các LLM thông thường:**
  - Khi được yêu cầu làm gia sư ngôn ngữ, LLM thường có xu hướng "bới lông tìm vết" (hypercorrection), cố tình thay thế từ ngữ của người học bằng các từ đồng nghĩa hoa mỹ dù câu người học đã đúng ngữ pháp 100%. Điều này làm người mới học bị nản chí và hoang mang.
- **Rào chắn chống sửa nhầm (Anti-Hypercorrection Guardrail):**
  - Prompt hệ thống quy định nghiêm ngặt: Nếu câu của học viên đã đúng ngữ pháp và tự nhiên theo chuẩn Hán ngữ hiện đại, AI **tuyệt đối không được cố tình tìm lỗi**.
  - Mô hình bắt buộc trả về `is_correct: true`, `corrected_text: null`, `error_category: "none"` kèm lời khích lệ ngắn gọn, ấm áp và tiếp nối dòng chảy đàm thoại.
- **Quy trình phản hồi sư phạm 3 bước khi phát hiện lỗi thật sự:**
  1. **Bước 1 (Khích lệ):** Xác nhận ý định giao tiếp, ghi nhận nỗ lực của học viên để duy trì tâm lý thoải mái.
  2. **Bước 2 (Phân tích chi tiết kèm Pinyin):** Chỉ rõ căn nguyên của lỗi bằng tiếng Việt (chọn sai từ, sai trật tự câu S-V-O, thiếu lượng từ, nhầm lẫn thanh điệu). Kèm Pinyin cho cả từ sai và từ đúng.
  3. **Bước 3 (Mẫu câu chuẩn tự nhiên):** Đưa ra câu diễn đạt chuẩn mực nhất của người bản xứ kèm chữ Hán, Pinyin và bản dịch tiếng Việt.

### 7.2. Phân Hệ Hình Tượng Gia Sư (Personas) & Tình Huống Hội Thoại (Scenarios)
- **3 Persona sư phạm chuyên biệt:**
  1. **Cô giáo Kiều Kiều (乔乔老师 - Qiaoqiao):** Trợ giảng kiên nhẫn, ấm áp, ngôn ngữ đơn giản HSK 1-3, lý tưởng cho người mới bắt đầu.
  2. **Thầy Lão Vương (老王老师 - Lao Wang):** Nghiêm cẩn, chính xác, sử dụng từ ngữ HSK 4-6, thành ngữ (成语) và ngữ cảnh thương mại/công việc.
  3. **Bạn cùng phòng Tiểu Minh (小明 - Xiao Ming):** Đồng trang lứa, giàu khẩu ngữ đời sống (口语), tiếng lóng giới trẻ lành mạnh và văn hóa hiện đại.
- **Hệ thống Scenario nhập vai:** Hỗ trợ từ hội thoại tự do (`free_chat`) đến các tình huống thực tế sinh động: Gọi món nhà hàng (`restaurant`), Mua sắm & Trả giá (`shopping`), Hỏi đường (`asking_directions`), Nhận phòng khách sạn (`hotel_checkin`), Sân bay (`airport`), Phỏng vấn xin việc (`job_interview`).

### 7.3. Context Builder, Giới Hạn Cửa Sổ Ngữ Cảnh & Kích Hoạt Trí Nhớ Chủ Động (Active Recall)
- **Cơ chế Sliding Window (Cửa sổ trượt có chặn):**
  - Chỉ trích xuất tối đa N tin nhắn gần nhất từ SQLite (`maxHistoryTurns = 10`), đảm bảo cặp hội thoại user-model hợp lệ và không làm phình to token context window, giữ cho chi phí và thời gian phản hồi ở mức tối thiểu.
- **Tích hợp Active Recall với Bộ não SRS:**
  - Context Builder truy vấn các từ vựng người học đang yếu hoặc đến hạn ôn tập từ SQLite (`srs_items` có ease factor thấp) và lồng ghép chỉ thị vào System Prompt.
  - AI Tutor sẽ khéo léo lồng ghép 1-2 từ vựng này vào câu hỏi tiếp theo, kích thích phản xạ ghi nhớ của người học mà không tạo cảm giác gượng gạo.

### 7.4. Phân Tích Cú Pháp Phản Hồi Bền Vững (Fault-Tolerant Parser)
- `TutorResponseParser` hỗ trợ:
  1. Giải mã chuỗi JSON thuần và JSON bọc trong Markdown code block (` ```json ... ``` `).
  2. Ánh xạ linh hoạt `error_category` giữa cả chuẩn snake_case của prompt và camelCase của Dart enum.
  3. Cơ chế cứu nguy tự động (Fallback): Nếu AI trả về text không cấu trúc, parser sử dụng regex chữ Hán và thanh điệu Pinyin để bóc tách câu thoại, đảm bảo UI không bao giờ bị crash.
- **Lưu vết học tập (Learner Evidence):**
  - Mọi lượt đánh giá có lỗi sai (`is_correct: false`) đều được tự động lưu vào bảng `learner_evidence` dạng append-only, phục vụ chẩn đoán lỗ hổng kiến thức và điều chỉnh lộ trình học thích ứng.

---

## 8. Tối Ưu Hóa Hệ Thống Toàn Diện Trước Giai Đoạn 4 (System Optimization)

Nhằm chuẩn bị nền tảng hiệu năng cao cho Giai đoạn 4 (các module học tập tương tác UI, Flashcard SRS, Hanzi animation và đàm thoại thời gian thực), hệ thống đã trải qua đợt tối ưu hóa toàn diện trên cả 3 tầng cốt lõi:

### 8.1. Tinh Chỉnh SQLite I/O & Quản Lý Bộ Nhớ Đệm (PRAGMA Tuning)
- **Tăng dung lượng Page Cache (`PRAGMA cache_size = -8000;`):** Cấp phát 8MB bộ nhớ RAM làm cache cho SQLite engine, giúp các thao tác tra cứu từ vựng và bảng SRS diễn ra trong vài micro-giây mà không đọc lặp lại bộ nhớ flash.
- **Lưu trữ bảng tạm trên RAM (`PRAGMA temp_store = MEMORY;`):** Chuyển toàn bộ các bảng tạm thời gian thực thi, các phép sắp xếp `ORDER BY` và chỉ mục nội bộ lên RAM, giảm thiểu tối đa hao mòn I/O đĩa trên thiết bị di động.
- **Cơ chế WAL Checkpoint chủ động & Tối ưu hóa Bộ lập kế hoạch truy vấn (`PRAGMA optimize;`):**
  - Bổ sung hàm `AppDatabase.checkpoint({bool truncate = false})` giúp chủ động chuyển đổi các trang log WAL về tệp DB chính định kỳ hoặc khi ứng dụng vào trạng thái nhàn rỗi.
  - Bổ sung `AppDatabase.optimize()` và tự động kích hoạt `PRAGMA optimize;` trước khi đóng DB để cập nhật thống kê bộ lập kế hoạch truy vấn SQLite (Cost-based Query Planner).

### 8.2. Hệ Thống Chỉ Mục Phức Hợp Hiệu Năng Cao (Composite Indexing)
- **`idx_evidence_type_score` (`learner_evidence (content_type, score, created_at)`):**
  - Tối ưu hóa triệt để truy vấn tìm kiếm lỗi lặp (`_loadRecurringErrors`) và kiểm đếm bằng chứng học tập mà không cần quét toàn bộ bảng log lịch sử.
- **`idx_chat_messages_lookup` (`chat_messages (session_id, role, created_at)`):**
  - Tối ưu hóa trích xuất tóm tắt và tin nhắn lịch sử gần nhất theo phiên trò chuyện với độ phức tạp $O(\log N)$.

### 8.3. Bộ Đệm Tính Toán SRS (Due Count Memoization & Cache Invalidation)
- **Vấn đề:** Các widget hiển thị số lượng thẻ đến hạn ôn tập (Badges trên tab học tập, thanh điều hướng, màn hình Home) thường được render lại liên tục khi người dùng chuyển màn hình, gây lãng phí CPU và I/O đĩa.
- **Giải pháp:** Bổ sung cơ chế Memoization có thời hạn (TTL 60s) cho `SrsRepository.getDueCardsCount()`.
- **Tự động hủy cache (Auto-Invalidation):** Ngay khi người dùng hoàn thành một lượt ôn tập (`processReview()`), cache đếm hạn sẽ tự động bị xóa bỏ để tính toán lại ngay tức thì, đảm bảo tính nhất quán dữ liệu 100%.

### 8.4. Bộ Nhớ Đệm Ngữ Cảnh Người Học (Session-Scoped Context Caching)
- **Giảm tải truy vấn trong hội thoại đàm thoại:**
  - `LearnerContextService` tích hợp bộ đệm theo phiên (`sessionId`) với TTL 30s. Trong các lượt trao đổi chat liên tiếp nhanh chóng, AI Tutor tái sử dụng ngữ cảnh học viên đã phân tích thay vì thực thi đồng thời 5 câu lệnh SQL song song.
  - Tự động hủy cache khi có sự kiện ghi nhận lỗi sai hoặc đề xuất bằng chứng học tập mới (`_applyValidatedProposals`), bảo đảm AI luôn phản hồi theo dữ liệu học tập cập nhật nhất.

### 8.5. Quản Lý Vòng Đời Kết Nối & Giải Phóng Tài Nguyên (Resource Lifecycle)
- Chuẩn hóa phương thức `dispose()` trên các interface `AiProvider`, `GeminiRestAiProvider` và `AiService` để giải phóng HTTP Client connection pool và socket ngầm khi ứng dụng hủy dịch vụ hoặc thay đổi cấu hình API key, ngăn chặn hoàn toàn rò rỉ bộ nhớ (memory leaks).

---

## 9. Material 3 Design System & Phân Cấp Màu Ngữ Nghĩa (Task 4.1)

### 9.1. Quy Chuẩn Màu Sắc (Color Tokens & WCAG 2.2 AA)
- **Quy tắc hạt nhân:** Không bao giờ dùng màu Lime Green (`#A3D635`) làm nền đại trà cho mọi thành phần hoặc bề mặt màn hình lớn.
- **Phân cấp ngữ nghĩa (Semantic Hierarchy):**
  - **Lime Green (`#A3D635`):** Đóng vai trò **Primary Action Accent** trong Dark Theme (Hero buttons, active tab indicators, glowing accents).
  - **Dark Forest Palette:** `#121811` (Scaffold background), `#1A2418` (Surface/AppBar/Dialog), `#243022` (Card surface), `#2E3D2B` (Border).
  - **Off-white (`#F6FAF2`):** Scaffold background trong Light Theme kết hợp thẻ trắng `#FFFFFF`.
- **Kiểm định tỷ lệ tương phản chuẩn W3C:**
  $$\text{Contrast Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05}$$
  - Nút chính Dark Theme (chữ Dark Forest `#121811` trên nền Lime Green `#A3D635`): Tỷ lệ tương phản **10.8:1** (Vượt xa chuẩn AA 4.5:1 và AAA 7.0:1).
  - Nút chính Light Theme (chữ trắng trên nền `#53740A`): Tỷ lệ tương phản **5.0:1** (Đạt chuẩn AA).
  - Chữ trên Surface Dark Theme (`#E2E4DC` trên `#1A2418`): Tỷ lệ tương phản **> 12.0:1**.

### 9.2. Phông Chữ Bản Địa Hoá & Không Tải Font Runtime (Offline-First Typography)
- Loại bỏ hoàn toàn sự phụ thuộc vào các thư viện tải font online runtime (như `google_fonts`) nhằm triệt tiêu độ trễ mạng và nguy cơ layout shift.
- Áp dụng chuỗi font fallback hệ thống bản địa:
  `['Noto Sans SC', 'PingFang SC', 'Heiti SC', 'Roboto', 'sans-serif']`.
  Bảo đảm hiển thị sắc nét đồng thời chữ Hán (Giản thể & Phồn thể) và các dấu thanh tiếng Việt có dấu mũ/móc phức tạp (`ệ`, `ẩ`, `ỹ`, `ớ`, `ừ`).
- Thiết lập các kiểu chữ học tập đặc thù trong `AppTypography`:
  - `hanziLarge`: 40sp, weight: 600.
  - `hanziMedium`: 24sp, weight: 500.
  - `hanziSmall`: 18sp, weight: 400.
  - `pinyin`: 14sp, letterSpacing: 0.5, height: 1.4.

---

## 10. Kiến Trúc Component `RubyText` & An Toàn Đa Âm Tự (Task 4.2)

### 10.1. Nguyên Tắc Phòng Ngừa Sai Lệch Đa Âm Tự (Polyphone Defense)
- Tuyệt đối không tự suy luận pinyin từ chuỗi Hán tự bằng thuật toán đơn giản hoặc regex (tránh sai kinh điển như chữ `行` trong `银行 yínháng` vs `自行车 zìxíngchē`, hoặc chữ `得` trong `跑得快 de` vs `你得走 děi`).
- Mọi Pinyin hiển thị phải được truyền vào từ dataset / từ điển SQLite đã được kiểm duyệt. Nếu không có pinyin, segment hiển thị Hán tự thuần mà không đoán mò.

### 10.2. Xuống Dòng Ở Ranh Giới Từ & Căn Chân Dấu Câu (Word-Level Wrapping & Baseline Alignment)
- Thay vì dùng `Text.rich` hoặc các ký tự Unicode ruby giả lập, `RubyText` sử dụng `Wrap` trong đó mỗi `RubySegment` là một khối nguyên tử (atomic widget).
- Khi dòng chạm lề màn hình, toàn bộ cụm Hán tự và Pinyin của từ đó sẽ xuống dòng cùng nhau, **Pinyin không bao giờ bị trôi hoặc ngắt lẻ sang dòng khác**.
- Đối với từ ghép nhiều chữ (như `你好` - `nǐ hǎo`), nếu số lượng âm tiết cách nhau bởi khoảng trắng khớp với số chữ Hán, component căn chỉnh từng âm tiết trực tiếp trên đầu từng chữ Hán tương ứng bên trong một `Row` bất biến, giúp từ vựng hiển thị cân xứng hoàn hảo.
- Căn chân dấu câu: Dấu câu tiếng Trung (`，`, `。`, `！`, `？`, `、`, `：`, `；`) sử dụng `WrapCrossAlignment.end` để tự động nằm ngang bằng chân (baseline) với chữ Hán, không bị lơ lửng trên không trung.

---

## 11. App Shell 5 Tab, Quản Lý Trạng Thái & Điều Hướng Cử Chỉ Android (Task 4.3)

### 11.1. Cấu Trúc 5 Tab & Nút Trung Tâm Nổi Bật
- **5 Tab cốt lõi:** 0: Trang chủ, 1: Học tập, 2: AI Tutor (Nút trung tâm nổi bật), 3: Ôn tập, 4: Cá nhân.
- **Nút AI Tutor:** Thiết kế nổi bật dạng viên thuốc (`AppRadius.borderFull`) với màu Lime Green rực rỡ, tích hợp `Semantics` label và diện tích chạm $\ge 48\times 48\text{ dp}$.
- **Tối ưu điện thoại & SafeArea:** Sử dụng `MediaQuery.paddingOf(context).bottom` kết hợp `SafeArea(bottom: true)`, tự động thích ứng với thanh điều hướng cử chỉ (Gesture Navigation bar) và tai thỏ camera trên các dòng máy Android.

### 11.2. Bảo Toàn Trạng Thái Cuộn & Dữ Liệu Qua `IndexedStack`
- 5 tab được duy trì đồng thời trong bộ nhớ bằng `IndexedStack` và `AutomaticKeepAliveClientMixin`.
- Chuyển đổi qua lại giữa các tab giữ nguyên 100% vị trí cuộn danh sách và nội dung đang nhập dở trong các trường văn bản.

### 11.3. Kiểm Soát Nút Back Của Android Qua `PopScope`
- **Bảo vệ dữ liệu chưa lưu:** Tích hợp `hasUnsavedChangesProvider`, tự động hiển thị hộp thoại cảnh báo `HiDialog` xác nhận nếu người dùng nhấn Back khi đang làm bài kiểm tra hoặc nhập liệu dở dang.
- **Quy tắc điều hướng chuẩn Android:** Nhấn Back từ bất kỳ tab phụ nào (Học tập, AI Tutor, Ôn tập, Cá nhân) sẽ tự động quay về Tab Trang chủ (Tab 0) trước khi thoát ứng dụng.

---

## 12. Tối Ưu Hóa & Chuẩn Bị Toàn Diện Trước Giai Đoạn 5 (Pre-Stage 5 Optimizations)

Trước khi bước vào Giai đoạn 5 (triển khai 22 phân hệ học tập chuyên sâu: Flashcard tương tác, Luyện viết chữ Hán Canvas, Phòng âm học Shadowing, Khảo sát năng lực CAT), hệ thống đã được tối ưu hóa đồng bộ:

### 12.1. Tự Động Checkpoint SQLite Khi Ứng Dụng Chuyển Background
- Mở rộng `AppLifecycleManager`: Khi nhận sự kiện vòng đời `AppLifecycleState.paused`, `inactive`, hoặc `hidden` (người dùng thoát ra màn hình chính, có cuộc gọi đến hoặc khóa màn hình), hệ thống tự động kích hoạt `AppDatabase.instance.checkpoint(truncate: false)` chạy ngầm không gây block giao diện.
- **Ý nghĩa:** Chuyển sạch các trang nhật ký WAL vào tệp DB chính, triệt tiêu nguy cơ mất mát dữ liệu do Android OOM Killer và giúp ứng dụng khởi động lạnh (Cold Boot) cực nhanh ở lần mở tiếp theo.

### 12.2. Reactive Riverpod Binding Cho Huy Hiệu Ôn Tập (SRS Due Counter)
- Thiết lập `srsDueCountProvider` (`AsyncNotifierProvider`) gắn kết trực tiếp `SrsRepository.getDueCardsCount(forceRefresh: true)`.
- Kết nối phản ứng tức thời giữa Tab Trang chủ và Tab Ôn tập: Ngay khi người dùng đánh giá thẻ SRS tại `ReviewScreen`, số lượng thẻ đến hạn trên thẻ cảnh báo của `HomeScreen` và badge của `ReviewScreen` được cập nhật đồng thời mà không cần reload màn hình.

### 12.3. Tách Biệt Toàn Diện Trạng Thái Khởi Động (`appStartupProvider`)
- Giữ tệp `main.dart` hoàn toàn tinh gọn (< 70 dòng), chuyển toàn bộ logic kết nối SQLite, chạy migrations v1-v2 và PRAGMAs sang `AppStartupNotifier`.
- Hỗ trợ màn hình Splash loader chuẩn `HiLoadingIndicator` và màn hình xử lý lỗi khởi động có nút Retry `HiErrorState`.

---

## 13. Kiến Trúc Trang Chủ & Chuỗi Học Tập Tính Toán Theo Múi Giờ (Task 5.1)

### 13.1. Thuật Toán Tính Chuỗi Học Tập (Timezone-Aware Streak Engine)
- **Định nghĩa "Ngày học có ý nghĩa":**
  - Chỉ tính khi có hoạt động học tập thực tế trong bảng `learner_evidence` (đánh giá thẻ Flashcard, trả lời bài tập, đàm thoại AI) hoặc `learning_activities` (`duration_seconds >= 30` hoặc `items_count >= 1`).
  - Mở ứng dụng (App Open) thuần túy **không được ghi nhận** và **tuyệt đối không làm tăng streak**.
  - Dữ liệu mẫu (với `source IN ('sample_data', 'seed')`) được lọc bỏ triệt để khỏi mọi truy vấn thống kê.
- **Quy tắc tính toán ngày dương lịch địa phương:**
  - Mọi mốc thời gian được lưu trữ dưới dạng chuẩn ISO-8601 UTC trong SQLite.
  - Khi tính chuỗi, hệ thống chuyển đổi timestamp UTC sang ngày lịch địa phương (`DateTime.toLocal()` hoặc `timeZoneOffset` cụ thể), loại bỏ triệt để lỗi chệch múi giờ khi người dùng di chuyển hoặc thay đổi DST.
  - **Học qua nửa đêm (Midnight crossover):** Một phiên học bắt đầu lúc 23:55 (Ngày 1) và kết thúc bài học tiếp theo lúc 00:05 (Ngày 2) được ghi nhận chính xác cho cả 2 ngày dương lịch liên tiếp, duy trì và nâng chuỗi học tập xứng đáng.
  - **Bảo toàn chuỗi chờ học trong ngày:** Nếu người học chưa học hôm nay nhưng hôm qua có học, chuỗi vẫn được giữ nguyên kèm lời nhắc động viên ("Học ngay hôm nay để giữ chuỗi!"). Chỉ khi cả hôm nay và hôm qua đều không có hoạt động học tập có ý nghĩa thì chuỗi mới bị ngắt (reset về 0), nhưng kỷ lục chuỗi cao nhất (`bestStreak`) vẫn được bảo lưu vĩnh viễn.

### 13.2. Cấu Trúc Bảng Điều Khiển Trang Chủ (Home Dashboard Data Flow)
- `HomeRepository`: Assembles trực tiếp từ SQLite WAL:
  - Contextual greeting theo giờ địa phương (Sáng/Chiều/Tối).
  - Chuỗi học tập và tiến độ mục tiêu ngày (`LearningStreak`).
  - Số thẻ SRS đến hạn hôm nay (`SrsRepository.getDueCardsCount(forceRefresh: true)`).
  - Lộ trình HSK và tỷ lệ từ vựng đã học / thành thạo (`RoadmapProgress`).
  - Danh sách 5 hoạt động học gần đây nhất kèm thời gian tương đối (`RecentActivityItem`).
- **Phòng thủ trạng thái lỗi trong Riverpod:**
  - Xử lý điều kiện `dashboardAsync.hasError && !dashboardAsync.hasValue` hiển thị ngay `HiErrorState` kèm nút "Thử lại", ngăn chặn hiện tượng treo màn hình skeleton loading khi SQLite gặp lỗi truy vấn lần đầu.

### 13.3. Tích Hợp Tra Cứu Từ Điển Offline Tức Thì (Quick Dictionary Modal)
- Nút "Từ điển tra cứu" trong lưới Truy Cập Nhanh (Quick Actions Grid) mở trực tiếp `QuickDictionarySheet`.
- Cho phép tra cứu chữ Hán, Pinyin và tiếng Việt tức thì trên hơn 1,200 từ vựng HSK hoàn toàn offline, hiển thị kết hợp chữ `RubyText`, nghĩa tiếng Việt và câu ví dụ mà không tốn tài nguyên mạng.

---

## 14. Kiến Trúc Bài Kiểm Tra Thích Ứng Đầu Vào (CAT Placement Test) Cho 6 Kỹ Năng (Task 5.2)

### 14.1. Động Cơ Toán Học 2PL IRT (Item Response Theory) & Định Tuyến Thích Ứng
- **Mô hình 2-Tham số Logistic (2PL IRT):**
  - Xác suất trả lời đúng của học viên có năng lực $\theta$ với câu hỏi $i$ có độ khó $b_i$ và độ phân biệt $a_i$:
    $$P_i(\theta) = \frac{1}{1 + e^{-D \cdot a_i (\theta - b_i)}} \quad (D = 1.702)$$
  - Lượng thông tin Fisher (Fisher Information):
    $$I_i(\theta) = a_i^2 \cdot P_i(\theta) \cdot (1 - P_i(\theta))$$
  - Chọn câu hỏi tiếp theo có $I_i(\theta)$ cực đại tại mức năng lực $\theta$ hiện thời trong danh sách các câu hỏi chưa làm của kỹ năng mục tiêu.
- **Cập nhật năng lực (Theta Update & Step Bounding):**
  - Sử dụng thuật toán Newton-Raphson xấp xỉ có ràng buộc biên bước nhảy $|\Delta\theta| \le 0.8$ nhằm ngăn chặn hiện tượng bất ổn định toán học khi học viên trả lời đúng hoặc sai một chuỗi liên tiếp ở đầu bài thi.
  - Sau mỗi câu trả lời, sai số chuẩn đo lường được tính tự động:
    $$SE(\theta) = \frac{1}{\sqrt{\sum_{k} I_k(\theta)}}$$
- **Quy tắc dừng linh hoạt (Adaptive Stopping Rules):**
  - Số câu tối thiểu: 12 câu (đảm bảo độ phủ mẫu trên các kỹ năng chính).
  - Số câu tối đa: 30 câu (ngăn ngừa quá tải tâm lý và mỏi mệt).
  - Điều kiện hội tụ: $SE(\theta) \le 0.35$ (tương đương độ tin cậy > 88%).
  - Dừng sớm theo kỹ năng: Nếu học viên trả lời sai 3 câu liên tiếp ở một kỹ năng, hệ thống tự động khóa kỹ năng đó và chuyển sang kỹ năng tiếp theo để bảo vệ trải nghiệm của người học sơ cấp.

### 14.2. Nguyên Tắc Đánh Giá 6 Kỹ Năng & Liêm Chính Dữ Liệu
1. **Từ vựng, Ngữ pháp, Đọc hiểu, Nghe hiểu:**
   - Được đo lường qua các câu hỏi đa dạng (trắc nghiệm, câu hỏi kèm phát âm ngữ âm chuẩn).
2. **Kỹ năng Viết (Writing) — Không trộn điểm:**
   - Hệ thống tách bạch tuyệt đối 3 chỉ số thành phần:
     1. Nhận diện chữ Hán (`charRecognitionRate`).
     2. Nhập Pinyin kèm thanh điệu chuẩn (`pinyinInputAccuracy`).
     3. Thứ tự nét bút thuận (`strokeOrderScore`).
   - Không gộp thành một điểm số bình quân duy nhất làm sai lệch năng lực chữ viết.
3. **Kỹ năng Nói / Phát âm (Speaking) — Nguyên tắc chống phán đoán giả:**
   - Tuyệt đối không đánh giá thanh điệu và ngữ điệu nếu chỉ dựa vào transcript của nhận dạng giọng nói ASR.
   - Nếu không có tín hiệu audio phân tích âm học thực hoặc học viên nhấn "Bỏ qua", hệ thống ghi nhận rõ ràng: **"Chưa đủ dữ liệu đánh giá phát âm"** (`SpeakingEvaluationMode.insufficientData`).
   - **Tuyệt đối không chấm 0 điểm** đối với kỹ năng thiếu dữ liệu.
4. **Xử lý kỹ năng bị bỏ qua:**
   - Bất kỳ kỹ năng nào người học chủ động bỏ qua sẽ được gán `isAssessed = false`, hiển thị nhãn `Chưa đánh giá` trên biểu đồ Radar và bảng điểm.
5. **Tuyên bố pháp lý bắt buộc (Legal Disclaimer):**
   - HSK chỉ là thang quy chiếu nội bộ phục vụ cá nhân hóa lộ trình học tại ứng dụng HI Chinese.
   - Ứng dụng luôn hiển thị cảnh báo: *"Kết quả kiểm tra thích ứng chỉ mang tính tham chiếu nội bộ... không tương đương chứng chỉ HSK chính thức."*

### 14.3. Lưu Trữ SQLite & Khả Năng Tiếp Tục Làm Bài (Persistence & Resume)
- **Cơ sở dữ liệu (Migration V3):**
  - Bảng `placement_test_sessions`: Lưu trữ `session_id`, `status` (`in_progress`, `completed`, `abandoned`), `current_step`, `estimated_theta`, `confidence_interval`, `overall_hsk_band`, `diagnostic_report_json`.
  - Bảng `placement_test_responses`: Append-only lưu lại từng lượt trả lời gồm `item_id`, `skill`, `user_answer`, `is_correct`, `response_time_ms`, `timestamp`.
- **Khôi phục trạng thái (Resume on Restart):**
  - Khi người dùng thoát ứng dụng đột ngột hoặc tắt máy giữa bài thi, phiên `in_progress` được lưu trữ an toàn trong SQLite.
  - Khi mở lại, màn hình `PlacementTestIntroScreen` hiển thị nút "Tiếp tục bài kiểm tra dang dở", khôi phục đúng bước câu hỏi, lịch sử điểm số và ma trận câu hỏi đã làm mà không làm mất dữ liệu.
- **Đồng bộ bằng chứng học tập (Evidence Sync):**
  - Khi hoàn thành bài test, kết quả được ghi nhận vào `learner_evidence` với nguồn `cat_placement_test` và `learning_activities`, kích hoạt cập nhật lộ trình gợi ý trên Trang Chủ.

---

## 15. Kiến Trúc Giao Diện Flashcard & Ôn Tập SRS SM-2 (Task 5.3)

### 15.1. Mô Hình Thẻ Lật 3D (3D Flipping Flashcard) & Khả Năng Tiếp Cận (WCAG 2.2 AA)
- **Hiệu ứng lật 3D mượt mà:**
  - Sử dụng `AnimationController` với đường cong `Curves.easeInOutCubic` kết hợp phép biến đổi hình học không gian 3D `Transform(transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle))` tạo hiệu ứng lật thẻ vật lý tự nhiên.
  - Phân tách góc quay $\pi/2$ giữa mặt trước và mặt sau, ngăn chặn hiện tượng chớp nháy (visual flicker) hoặc lộ ngược văn bản mặt sau.
- **Mặt trước (Front Face):**
  - Chữ Hán nổi bật với cỡ chữ lớn ($56\text{pt}$), font Noto Sans SC / Heiti SC fallback.
  - Nút chuyển đổi ẩn/hiện Pinyin (`Ẩn Pinyin` / `Hiện Pinyin`) phục vụ nhu cầu học phân hóa (học nhận diện mặt chữ thuần túy vs. học kèm ngữ âm).
  - Huy hiệu cấp độ HSK và số nét bút thuận (`stroke_count`).
  - Gợi ý chạm trực quan và nút bấm lật thẻ rõ ràng cho người dùng điều khiển cảm ứng.
- **Mặt sau (Back Face):**
  - Phiên âm Pinyin đầy đủ dấu thanh kết hợp `RubyText`.
  - Định nghĩa nghĩa tiếng Việt (`meaning_vi`) và loại từ (`part_of_speech`).
  - Khối ví dụ câu song ngữ kèm Pinyin và bản dịch tiếng Việt.
  - Nút phát âm âm học chuẩn bản xứ (có cơ chế phản hồi thân thiện khi thẻ chưa có audio gốc, không làm gián đoạn trải nghiệm).
  - Nút tra cứu nhanh tức thời mở `QuickDictionarySheet` với từ vựng được điền sẵn.
- **Chuẩn tiếp cận (Accessibility):**
  - Toàn bộ 2 mặt thẻ được bọc trong các nút `Semantics` thông báo rõ ràng mặt trước, mặt sau và hướng dẫn thao tác cho màn hình đọc (TalkBack / Screen Readers).

### 15.2. Tính Toán Trước Khoảng Cách Ôn Tập (SM-2 Interval Previews)
- **4 Lựa chọn đánh giá chuẩn SM-2:**
  1. `Again (Quên)`: Quality 1, đặt lại khoảng cách ôn về 1 ngày / lặp lại ngay (`< 10 phút`).
  2. `Hard (Khó)`: Quality 3, tăng khoảng cách nhẹ hoặc giữ nguyên mức an toàn, hệ số dễ EF giảm $0.14$.
  3. `Good (Nhớ)`: Quality 4, áp dụng công thức $I_n = \text{round}(I_{n-1} \times EF)$, giữ nguyên EF.
  4. `Easy (Dễ)`: Quality 5, thưởng khoảng cách bước nhảy lớn kết hợp hệ số thưởng `easyBonusMultiplier`, EF tăng $0.10$.
- **Dự báo thời gian ôn tập không tác dụng phụ (`Sm2Engine.previewIntervals`):**
  - Tính toán trước khoảng cách ngày cho cả 4 lựa chọn trực tiếp từ trạng thái `SrsCardState` hiện thời.
  - Hiển thị nhãn thời gian ước tính (ví dụ: `< 10 phút`, `2 ngày`, `4 ngày`, `8 ngày`) ngay trên thanh nút bấm `FlashcardRatingBar`.
- **Tách bạch trách nhiệm:**
  - Tầng Presentation tuyệt đối không tự tính toán công thức SM-2 mà chỉ ủy quyền cho `Sm2Engine` và `SrsRepository`.

### 15.3. Liêm Chính Dữ Liệu, Chống Tap Lặp & Bảo Toàn Trạng Thái
- **Chặn bấm lặp kép (Anti-Spam / Debounce Lockout):**
  - Bảo vệ 2 lớp: Ở tầng UI, cờ `isProcessingReview` vô hiệu hóa thanh nút bấm ngay khi chạm; ở tầng Repository, `_inFlightContentIds` và ngưỡng debounce $100\text{ms} - 800\text{ms}$ loại trừ triệt để lỗi ghi đè dữ liệu thẻ.
- **Giao dịch nguyên tử (Atomic SQLite Transaction):**
  - Cập nhật đồng thời bảng `srs_items` và chèn bản ghi nhật ký bất biến `learner_evidence` (`source: 'srs_flashcard'`).
  - Tự động ghi nhận một bản ghi vào `learning_activities` (`activity_type: 'srs_review'`), nuôi dưỡng chuỗi ngày học (`streak`) trên Trang Chủ mà không cần thao tác thủ công.
- **Xử lý hàng đợi rỗng & Tiếp tục học:**
  - `FlashcardEmptyState` hiển thị lời chúc mừng khi hoàn thành tất cả thẻ cần ôn trong ngày kèm thống kê số thẻ đã ôn và tỷ lệ nhớ.
  - Hỗ trợ nút "Học thêm 15 từ mới", tự động truy vấn từ vựng chưa học từ bảng `vocabularies` và khởi tạo thẻ SRS mới trên SQLite hoàn toàn offline.
- **Bảo toàn trạng thái khi App Pause / Resume:**
  - Sử dụng `AppLifecycleListener` để tự động làm mới số lượng thẻ cần ôn khi người dùng quay lại từ background.
  - Kết hợp `AutomaticKeepAliveClientMixin` trong `ReviewScreen` giúp giữ nguyên vị trí thẻ đang xem khi chuyển đổi qua lại giữa các tab trên thanh điều hướng.

---

## 16. Kiến Trúc Luyện Viết Chữ Hán Bằng Canvas & CustomPainter (Task 5.4)

### 16.1. Khung Canvas Thư Pháp Ô Mễ (米字格), CustomPainter Độc Lập & Tối Ưu Hiệu Năng 60–120fps
- **Kiến trúc Canvas 2 lớp phân tách:**
  - Lớp tĩnh (`MizigePainter`): Vẽ khung viền ngoài bo góc và hệ lưới chữ Mễ chuẩn thư pháp cổ điển (đường ngang, đường dọc, hai đường chéo nét đứt). Tách rời hoàn toàn khỏi tương tác vẽ để tránh repaint lặp lại.
  - Lớp động (`HanziPainter`): Vẽ các nét chữ do người dùng tạo ra, nét đang vẽ (`activeStroke`), chữ mẫu mờ (watermark) và highlight nét gợi ý.
- **Tối ưu hóa hiệu năng cực đại (Zero Parent Rebuilds):**
  - Bọc canvas trong `RepaintBoundary` kết hợp `AnimatedBuilder` lắng nghe `HanziCanvasController` (`ChangeNotifier`).
  - Các sự kiện cảm ứng chạm (`PointerDownEvent`, `PointerMoveEvent`, `PointerUpEvent`, `PointerCancelEvent`) chỉ kích hoạt repaint nội bộ canvas mà không bao giờ trigger build lại màn hình bên ngoài, duy trì khung hình mượt mà 60–120fps trên thiết bị di động.
- **Khử rung lắc cảm ứng (Micro-Jitter Filtering):**
  - Thuật toán loại bỏ các điểm di chuyển có khoảng cách Euclidean nhỏ hơn $1.5\text{px}$, giúp làm mịn đường cong chữ Hán và giảm tiêu hao bộ nhớ.
- **Hỗ trợ bút Stylus & ngón tay:**
  - Nhận diện giá trị áp lực cảm ứng `event.pressure` (nằm trong dải $0.2 - 2.0$), tự động điều biến độ dày nét vẽ tạo cảm giác đè bút thư pháp chân thực.
- **Bố cục co giãn thích ứng (Adaptive Layout):**
  - Sử dụng `LayoutBuilder` tự động thích ứng kích thước ô vẽ (từ 240dp đến 340dp) trên các màn hình hẹp (320dp width) mà không gây lỗi tràn viền `RenderFlex`.

### 16.2. Chế Độ Luyện Tập Linh Hoạt & Thanh Điều Khiển Tiện Ích
- **Chế độ Tô mẫu (Tracing Mode):**
  - Hiển thị chữ Hán hình mờ bán trong suốt (Watermark) với tone màu Lime Green chuẩn Design System.
  - Hỗ trợ làm nổi bật (highlight) nét chữ cần viết tiếp theo, dẫn dắt trực quan từng bước cho người mới học.
- **Chế độ Tự viết (Freeform Mode):**
  - Ẩn hoàn toàn chữ mẫu, để lại ô lưới 米字格 giúp học viên tự kiểm tra trí nhớ về kết cấu không gian và tỷ lệ chữ.
- **Thanh công cụ điều khiển (`WritingToolbar`):**
  - Chuyển đổi tức thời giữa 2 chế độ `Tracing` và `Freeform`.
  - 3 Mức độ dày nét vẽ tiêu chuẩn (`StrokeWidthPreset`): Mảnh ($4.0\text{px}$), Vừa ($7.0\text{px}$), Đậm ($11.0\text{px}$).
  - Nút Hoàn tác (`Undo`): Xóa nét vừa vẽ gần nhất mà không làm mất các nét trước đó.
  - Nút Xóa hết (`Reset`): Làm sạch khung vẽ để viết lại từ đầu.
  - Nút Xem hoạt họa (`Replay`): Hiển thị tuần tự từng nét bút kèm tên gọi Hán Việt chuẩn (ví dụ: Nét Ngang, Nét Sổ, Nét Phẩy, Nét Mác).

### 16.3. Thuật Toán Đánh Giá Thứ Tự Nét (Stroke Order Evaluator) & Tính Liêm Chính Học Thuật
- **Cơ sở quy chuẩn quốc gia:**
  - Đối chiếu thứ tự nét bút thuận theo quy chuẩn quốc gia Trung Quốc GB/T 13000 và tiêu chuẩn Hanban (先横后竖, 先撇后捺, 从上到下, 从左到右, 先外后内, 先里头后封口).
- **Thuật toán so khớp vector hình học thuần túy (Deterministic Geometric Matching):**
  - Chuẩn hóa tọa độ nét người dùng về không gian đơn vị $[0.0, 1.0] \times [0.0, 1.0]$.
  - So khớp vector chỉ phương giữa nét vẽ và nét chuẩn bằng phép đo góc $\Delta\theta$ và độ tương đồng Cosine Similarity:
    $$\cos(\theta) = \frac{\vec{u} \cdot \vec{v}}{\|\vec{u}\| \|\vec{v}\|}$$
  - Phát hiện chính xác lỗi viết ngược chiều (ví dụ: nét sổ viết từ dưới lên, nét ngang viết từ phải sang trái khi $\cos < -0.3$).
  - Kiểm tra bán kính sai số vùng xuất phát (Tolerance radius $\le 0.35$).
- **Liêm chính học thuật (No Fake OCR):**
  - Tuyệt đối không tuyên bố là mô hình nhận dạng chữ viết AI (OCR) khi chỉ dựa vào đối chiếu tọa độ thô.
  - `WritingEvaluationSheet` hiển thị rõ ràng tỷ lệ % độ chuẩn xác nét, phân tích chi tiết từng nét đúng/sai/ngược và tuyên bố phương pháp luận minh bạch.
- **Xử lý trung thực khi chữ thiếu dữ liệu nét chuẩn:**
  - Khi một chữ chưa có dữ liệu vector nét chuẩn trong hệ thống, ứng dụng hiển thị biểu ngữ thông báo rõ ràng cho người học và cho phép tự do luyện viết trên ô lưới mà không phạt điểm hay đánh giá sai.

### 16.4. Lưu Trữ Vector Metadata Tinh Gọn Trên SQLite Cục Bộ
- **Lưu trữ nguyên tử, không làm phình cơ sở dữ liệu:**
  - Kết quả luyện viết được lưu vào bảng `learner_evidence` (`source: 'hanzi_writing'`) với `content_id` là chữ Hán tương ứng.
  - Tuyệt đối không lưu các file ảnh raw bitmap nặng nề làm chậm cơ sở dữ liệu SQLite; chỉ lưu trữ metadata JSON gọn nhẹ ($< 1\text{KB}$) gồm tỷ lệ chính xác, số nét chuẩn, chế độ viết và danh sách nhận xét.
- **Tích hợp chuỗi ngày học (Streak Integration):**
  - Tự động ghi một bản ghi vào bảng `learning_activities` (`activity_type: 'hanzi_writing'`), kích hoạt và duy trì chuỗi học tập (`streak`) trên Trang Chủ.
- **Hoạt động hoàn toàn Offline (100% Local):**
  - Mọi thao tác vẽ, đánh giá hình học, hoạt họa nét và ghi nhận dữ liệu đều chạy cục bộ trên thiết bị di động, không yêu cầu kết nối mạng.

---

## 17. Kiến Trúc Pronunciation Lab & Shadowing Training (Task 5.5)

### 17.1. Phân Tách Hai Luồng Luyện Tập Riêng Biệt (Không Nhập Nhằng Kết Quả)
- **Pronunciation Lab (Phòng Luyện Phát Âm):**
  - **Mục tiêu:** Huấn luyện cấp độ Âm vị (Phoneme) & Từ vựng (Word/Phrase), tập trung vào Thanh điệu (Tones), Âm đầu (Initials: zh/ch, z/c), Vận mẫu (Finals: an/ang, en/eng).
  - **Dữ liệu Evidence:** Lưu trữ vào `learner_evidence` với `source: 'pronunciation_lab'`, kỹ năng `pronunciation`.
  - **Duy trì Streak:** Ghi nhận vào `learning_activities` với `activity_type: 'pronunciation'`.
- **Shadowing (Luyện Nói Đuổi / Nhại Theo):**
  - **Mục tiêu:** Huấn luyện cấp độ Câu (Sentence) & Đoạn hội thoại (Discourse), tập trung vào Nhịp độ phát ngôn (Speech Pacing Ratio), Độ liền mạch (Fluency Index) và Ngữ điệu tự nhiên.
  - **Dữ liệu Evidence:** Lưu trữ vào `learner_evidence` với `source: 'shadowing'`, kỹ năng `shadowing`.
  - **Duy trì Streak:** Ghi nhận vào `learning_activities` với `activity_type: 'shadowing'`.
  - **Nguyên tắc phân định:** Hai luồng học tách biệt hoàn toàn về định danh bảng ghi, mục tiêu đánh giá và logic tính điểm; không trộn lẫn kết quả câu dài vào bài luyện thanh điệu đơn lẻ.

### 17.2. Quản Lý Vòng Đời Audio & Quyền Microphone Chuẩn Android
- **Audio Service Layer (`lib/core/audio/`):**
  - `AudioPlayerService` và `AudioRecorderService` cung cấp giao diện chuẩn cho việc phát mẫu, lặp (Looping), đổi tốc độ ($0.5\times - 2.0\times$) và thu âm WAV thời gian thực.
- **Tích hợp An Toàn Vòng Đời (`AppLifecycleManager`):**
  - Đăng ký phiên thu âm với `AppLifecycleManager.instance.registerAudioSession`.
  - Khi ứng dụng chuyển sang trạng thái nền (`paused`, `inactive`, `hidden`), hệ thống tự động ngắt và giải phóng microphone ngay lập tức, ngăn ngừa hiện tượng chiếm dụng tài nguyên ngầm và tuân thủ tuyệt đối chính sách bảo mật microphone của Google Play.
- **Microphone Permission Handling (`PermissionHelper`):**
  - Giải thích rõ ràng mục đích sử dụng quyền thu âm thông qua Rational Dialog trước khi xin quyền từ hệ thống.
  - Hỗ trợ mock quyền trong môi trường kiểm thử không có giao diện native OS.

### 17.3. Liêm Chính Học Thuật Trong Đánh Giá Phát Âm
- **Không Giả Lập Điểm Số (No Fake Tone Scoring):**
  - Hệ thống chỉ chấm điểm thanh điệu (Tone Accuracy) và âm đầu/cuối khi mô hình âm học phía backend/local thực sự phân tích đường nét cao độ F0 (Pitch Contour).
  - Khi provider chỉ hỗ trợ nhận dạng văn bản ASR thông thường (`hasAcousticModel: false`), cờ `isAcousticallyAnalyzed` được gán `false`, `toneAccuracy` là `null`, và ứng dụng hiển thị thông báo minh bạch: *"Mô hình chỉ hỗ trợ nhận dạng văn bản ASR. Chưa hỗ trợ bộ phân tích âm học đường nét cao độ (F0) và thanh điệu."*
- **Không Giả Lập Nhận Xét Accent Bản Xứ (No Fake Accent Scoring):**
  - Trong luồng Shadowing, hệ thống đánh giá khách quan dựa trên tỷ lệ nhịp độ thời gian:
    $$\text{Pacing Ratio} = \frac{\text{Thời lượng người học}}{\text{Thời lượng mẫu}}$$
    và chỉ số đối sánh timeline trực quan. Tuyệt đối không đưa ra các nhận xét cảm tính hoặc chấm điểm giả mạo về "giọng chuẩn bản xứ".

### 17.4. Bảo Vệ Quyền Riêng Tư & Quản Lý File Thu Âm
- **Mặc định lưu trữ cục bộ (Local-First Storage):**
  - File thu âm được lưu tạm thời trong thư mục cục bộ của ứng dụng, không gửi ra ngoài internet nếu không có sự đồng ý của người dùng.
- **Tính năng Xóa File Bản Thu Linh Hoạt (`deleteRecordingAudio`):**
  - Cho phép người học xóa file âm thanh thu âm bất kỳ lúc nào để giải phóng dung lượng bộ nhớ.
  - Tùy chọn `retainEvidence: true` cho phép xóa file vật lý trên đĩa nhưng vẫn bảo toàn số liệu thống kê học tập (cập nhật metadata `audio_deleted: true, audio_local_path: null`).





