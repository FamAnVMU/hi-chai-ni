# P0-03 FIX REPORT: BẢO MẬT API KEY & CHUYỂN ĐỔI BẢO MẬT CREDENTIAL SANG FLUTTER SECURE STORAGE

## 1. Tóm tắt vấn đề (Root Cause Analysis)
- **Trước khi sửa:**
  - Luồng `OnboardingFlowScreen._onApiKeySaved(apiKey)` lưu trực tiếp API key của học viên vào bảng SQLite `app_settings` (`gemini_api_key`), khiến khóa bí mật bị lưu trữ dưới dạng bản rõ (plaintext).
  - Khóa lưu trong SQLite không được mã hóa bởi phần cứng an toàn (Android KeyStore / iOS Keychain).
  - Không có cơ chế kiểm tra định dạng và độ dài tối thiểu của API Key (dẫn đến lưu các chuỗi rác hoặc chuỗi rỗng).
  - Không có cơ chế tự động di chuyển (migration) an toàn các khóa cũ đã lưu từ trước trong SQLite sang bộ nhớ bảo mật.

## 2. Giải pháp kỹ thuật đã triển khai

### A. Tăng cường `AiCredentialStorage` (`lib/core/network/ai/security/ai_credential_storage.dart`)
1. **Mã hóa phần cứng an toàn:**
   - Sử dụng `FlutterSecureStorage` với cấu hình Android KeyStore (AES-GCM) và iOS Keychain (`kSecAttrAccessibleAfterFirstUnlock`).
2. **Xác thực định dạng (`validateApiKey`):**
   - Kiểm tra API key không rỗng, độ dài tối thiểu 20 ký tự, không chứa ký tự xuống dòng (`\n`) hoặc khoảng trắng (`\t`, ` `).
3. **Quy trình ghi & xác minh tức thì (Instant Read-Back Verification):**
   - Mỗi lần lưu API key, phương thức `saveApiKey` ngay lập tức đọc lại giá trị từ bộ nhớ bảo mật.
   - Nếu kết quả đọc lại không trùng khớp hoặc xảy ra lỗi phần cứng, hệ thống lập tức ném ngoại lệ `StateError` và từ chối báo thành công.
4. **Hỗ trợ đa nhà cung cấp (Multi-Provider Isolation):**
   - Cô lập độc lập các khóa: `geminiRest`, `firebaseAiLogic`, `customProxy` và các nhà cung cấp bên thứ ba (`openai`, `claude`).
5. **Chính sách Zero-Log & Redaction (`maskKey`, `sanitizeSecret`):**
   - API key tuyệt đối không bao giờ được in ra console log, debug print hoặc exception message. Mọi chuỗi lỗi đều đi qua bộ lọc `sanitizeSecret` để che dấu regex các pattern API Key.
   - UI hiển thị dưới dạng masked (`AIza...4xQ1`).

### B. Cơ chế di chuyển an toàn & Idempotent (`migrateLegacyCredentials`)
1. Quét tìm các khóa nhạy cảm trong bảng SQLite `app_settings`: `gemini_api_key`, `api_key`, `google_api_key`, `custom_proxy_url`, `ai_proxy_url`, `openai_api_key`, `claude_api_key`.
2. Ghi từng khóa vào `FlutterSecureStorage` và xác minh tính toàn vẹn (read-back).
3. **Quy tắc an toàn dữ liệu:**
   - Chỉ xóa bản ghi plaintext khỏi SQLite SAU KHI và CHỈ KHI quá trình ghi vào `FlutterSecureStorage` đã được xác minh thành công 100%.
   - Nếu ghi vào secure storage thất bại, bản ghi trong SQLite được giữ nguyên vẹn để tránh mất dữ liệu của học viên và ghi nhận cờ thất bại.
4. Ghi nhận trạng thái hoàn thành vào `app_settings` (`credential_migration_completed: true`).
5. Tự động kích hoạt trong giai đoạn khởi động ứng dụng `AppStartupNotifier._initializeDependentServices()`.

### C. Cơ chế phòng vệ nhiều lớp (Defense-in-Depth) tại `AppSettingsDao`
- Trong `AppSettingsDao.setSetting(key, value)`: Chủ động chặn và ném ngoại lệ `ArgumentError` nếu bất kỳ module nào cố tình lưu các khóa có chứa `api_key`, `secret_key`, hoặc `auth_token` vào bảng SQLite `app_settings`.

### D. Nâng cấp giao diện Onboarding
- `OnboardingApiKeyScreen`:
  - Ẩn/hiện mật khẩu (`obscureText: true`) với icon con mắt.
  - Kiểm tra tính hợp lệ trước khi gọi lưu.
  - Hiển thị spinner trạng thái và thông báo lỗi rõ ràng nếu lưu trữ thất bại.
- `OnboardingFlowScreen`:
  - Tiếp nhận kết quả bất đồng bộ từ `AiCredentialStorage`, chỉ chuyển bước tiếp theo (Khảo sát trình độ) khi đã xác minh khóa lưu thành công.

---

## 3. Danh sách kiểm thử & Kết quả nghiệm thu

File test: `test/core/network/ai/security/ai_credential_security_test.dart` (13 tests)

| STT | Kịch bản kiểm thử | Kết quả |
|:---|:---|:---:|
| 1 | Lưu khóa API mới với cơ chế xác minh đọc lại tức thì | **PASSED** |
| 2 | Đọc khóa đã lưu và kiểm tra định dạng che phủ (masking) | **PASSED** |
| 3 | Khóa rỗng hoặc khoảng trắng tự động xóa khỏi bộ nhớ bảo mật | **PASSED** |
| 4 | Kiểm tra định dạng từ chối khóa ngắn (<20 ký tự) hoặc chứa ký tự trắng | **PASSED** |
| 5 | Giả lập lỗi I/O bảo mật phần cứng ném StateError và dừng quy trình | **PASSED** |
| 6 | Cô lập khóa giữa các nhà cung cấp (Gemini, Firebase, OpenAI, Claude) | **PASSED** |
| 7 | Bộ lọc `sanitizeSecret` bóc tách và che giấu API key khỏi log | **PASSED** |
| 8 | Di chuyển thành công từ SQLite sang SecureStorage và xóa plaintext cũ | **PASSED** |
| 9 | Lỗi di chuyển: Bản rõ trong SQLite được bảo toàn nguyên vẹn | **PASSED** |
| 10 | Tính Idempotent: Chạy migration nhiều lần không sinh thêm tác vụ | **PASSED** |
| 11 | `AppSettingsDao` chặn lưu khóa nhạy cảm vào SQLite | **PASSED** |
| 12 | Widget Test `OnboardingApiKeyScreen`: Kiểm tra nhập liệu và báo lỗi UI | **PASSED** |
| 13 | Widget Test `OnboardingFlowScreen`: Lưu khóa bảo mật và chuyển bước CAT | **PASSED** |

### Kết quả chạy kiểm tra tĩnh & kiểm thử toàn dự án:
- `dart analyze lib test`: **0 errors, 0 warnings, 0 infos (No issues found!)**
- `flutter test test/core/network/ai/security/ai_credential_security_test.dart`: **13/13 passed**
- `flutter test test/features/onboarding/onboarding_flow_test.dart`: **2/2 passed**
- `flutter test test/core/startup/app_startup_integration_test.dart`: **7/7 passed**
