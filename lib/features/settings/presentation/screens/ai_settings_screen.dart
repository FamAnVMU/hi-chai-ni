import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/ai.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/firebase_config_status.dart';
import '../providers/ai_settings_providers.dart';

/// Screen for configuring AI providers, managing API credentials,
/// selecting models with explicit capability matrix, and running live connection tests.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _proxyUrlController = TextEditingController();
  bool _obscureKey = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _proxyUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSettingsProvider);
    final notifier = ref.read(aiSettingsProvider.notifier);
    final modelRegistry = ref.watch(aiModelRegistryProvider);

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        title: const Text('Cài Đặt AI & Kết Nối'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================== 1. PROVIDER SELECTION ====================
            _buildSectionHeader('1. Nhà Cung Cấp AI (Provider)'),
            const SizedBox(height: 8.0),
            _buildProviderSelector(state, notifier),
            const SizedBox(height: 20.0),

            // ==================== 2. CREDENTIALS & SECURITY ====================
            _buildSectionHeader('2. Thông Tin Xác Thực & Bảo Mật'),
            const SizedBox(height: 8.0),
            if (state.providerType == AiProviderType.geminiRest) ...[
              _buildByokCredentialCard(state, notifier),
            ] else if (state.providerType == AiProviderType.firebaseAiLogic) ...[
              _buildFirebaseStatusCard(state.firebaseStatus),
            ] else ...[
              _buildCustomProxyCard(state, notifier),
            ],
            const SizedBox(height: 20.0),

            // ==================== 3. MODEL CONFIGURATION ====================
            _buildSectionHeader('3. Cấu Hình Mô Hình & Khả Năng'),
            const SizedBox(height: 8.0),
            _buildModelConfigCard(state, notifier, modelRegistry),
            const SizedBox(height: 24.0),

            // ==================== 4. LIVE CONNECTION TEST ====================
            _buildSectionHeader('4. Kiểm Tra Kết Nối Thực Tế'),
            const SizedBox(height: 8.0),
            _buildConnectionTestCard(state, notifier),
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlueDark,
        letterSpacing: 0.3,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Provider Selector
  // ---------------------------------------------------------------------------
  Widget _buildProviderSelector(AiSettingsState state, AiSettingsNotifier notifier) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildProviderTile(
              title: 'Google AI Studio (BYOK)',
              subtitle: 'Cá nhân • Trực tiếp bằng Gemini API Key của bạn',
              value: AiProviderType.geminiRest,
              current: state.providerType,
              onSelect: () => notifier.setProviderType(AiProviderType.geminiRest),
            ),
            const Divider(color: AppColors.divider, height: 1.0),
            _buildProviderTile(
              title: 'Firebase AI Logic',
              subtitle: 'Đám mây • Vertex AI kèm Firebase App Check',
              value: AiProviderType.firebaseAiLogic,
              current: state.providerType,
              onSelect: () => notifier.setProviderType(AiProviderType.firebaseAiLogic),
            ),
            const Divider(color: AppColors.divider, height: 1.0),
            _buildProviderTile(
              title: 'Custom Backend Proxy',
              subtitle: 'Doanh nghiệp • Máy chủ chuyển tiếp an toàn',
              value: AiProviderType.customProxy,
              current: state.providerType,
              onSelect: () => notifier.setProviderType(AiProviderType.customProxy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTile({
    required String title,
    required String subtitle,
    required AiProviderType value,
    required AiProviderType current,
    required VoidCallback onSelect,
  }) {
    final isSelected = value == current;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
                  width: 2.0,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10.0,
                        height: 10.0,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.0, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BYOK Credential Card
  // ---------------------------------------------------------------------------
  Widget _buildByokCredentialCard(AiSettingsState state, AiSettingsNotifier notifier) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Key Status Indicator
            if (state.hasApiKey) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.successContainerLight,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.success.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.success, size: 22.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Khóa API đã lưu an toàn',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText),
                          ),
                          Text(
                            'Giá trị: ${state.maskedApiKey ?? "********"}',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontFamily: 'monospace',
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: 'Xóa khóa API',
                      onPressed: () => _confirmDeleteKey(context, notifier),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.warningContainerLight,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.warning.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22.0),
                    SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        'Chưa cấu hình API Key. Hãy nhập key bên dưới để kích hoạt AI Tutor.',
                        style: TextStyle(fontSize: 13.0, color: AppColors.primaryText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Input Text Field
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.primaryText),
              decoration: InputDecoration(
                labelText: state.hasApiKey ? 'Thay đổi Gemini API Key' : 'Nhập Gemini API Key',
                hintText: 'AIzaSy...',
                hintStyle: const TextStyle(color: AppColors.mutedText),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.primaryBlueDark),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.mutedText,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Save Key Button
            ElevatedButton.icon(
              onPressed: state.isSavingKey
                  ? null
                  : () async {
                      final key = _apiKeyController.text.trim();
                      if (key.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập API Key trước khi lưu')),
                        );
                        return;
                      }
                      await notifier.saveApiKey(key);
                      _apiKeyController.clear();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã mã hóa và lưu khóa API an toàn!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
              icon: state.isSavingKey
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, color: Colors.white),
              label: Text(
                state.hasApiKey ? 'Cập Nhật Khóa' : 'Lưu Khóa API',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlueDark,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            const SizedBox(height: 10.0),

            // Security Policy Note
            const Text(
              '🔒 Bảo mật: Khóa được mã hóa phần cứng bằng AES-256 GCM qua Android KeyStore. '
              'Khóa KHÔNG bao giờ được ghi vào log, crash report hay chia sẻ ra ngoài.',
              style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Firebase AI Logic Card
  // ---------------------------------------------------------------------------
  Widget _buildFirebaseStatusCard(FirebaseConfigStatus status) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 24.0),
                SizedBox(width: 8.0),
                Text(
                  'Firebase AI Logic & App Check',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.primaryText),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            _buildStatusRow(
              label: 'Trạng thái Firebase:',
              value: status.initState == FirebaseInitState.initialized
                  ? 'Đã khởi tạo'
                  : 'Chưa cấu hình (google-services.json)',
              isOk: status.initState == FirebaseInitState.initialized,
            ),
            const SizedBox(height: 6.0),
            _buildStatusRow(
              label: 'Bảo vệ App Check:',
              value: status.appCheckState == AppCheckState.active
                  ? 'Đang thực thi Play Integrity'
                  : 'Chưa kích hoạt',
              isOk: status.appCheckState == AppCheckState.active,
            ),
            const SizedBox(height: 12.0),
            const Text(
              '💡 Chế độ Firebase AI Logic yêu cầu file google-services.json hợp lệ từ Google Cloud '
              'kèm chứng thực thiết bị Play Integrity để chống lạm dụng API.',
              style: TextStyle(fontSize: 12.0, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required bool isOk,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13.0, color: AppColors.secondaryText)),
        const SizedBox(width: 8.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: isOk ? AppColors.successContainerLight : AppColors.errorContainerLight,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: isOk ? AppColors.success : AppColors.error,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isOk ? AppColors.success : AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Custom Proxy Card
  // ---------------------------------------------------------------------------
  Widget _buildCustomProxyCard(AiSettingsState state, AiSettingsNotifier notifier) {
    if (_proxyUrlController.text.isEmpty && state.proxyUrl != null) {
      _proxyUrlController.text = state.proxyUrl!;
    }

    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _proxyUrlController,
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.primaryText),
              decoration: InputDecoration(
                labelText: 'URL Máy Chủ Proxy',
                hintText: 'https://proxy.example.com/v1beta',
                hintStyle: const TextStyle(color: AppColors.mutedText),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            const SizedBox(height: 12.0),
            ElevatedButton(
              onPressed: () async {
                await notifier.saveCustomProxyUrl(_proxyUrlController.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật URL Proxy')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlueDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu Địa Chỉ Proxy', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Model Configuration Card & Capabilities
  // ---------------------------------------------------------------------------
  Widget _buildModelConfigCard(
    AiSettingsState state,
    AiSettingsNotifier notifier,
    AiModelRegistry modelRegistry,
  ) {
    final activeSpec = modelRegistry.getModelSpec(state.selectedModelId);

    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown Selector
            const Text(
              'Mô hình mặc định:',
              style: TextStyle(fontSize: 13.0, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.selectedModelId,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  items: modelRegistry.availableModelSpecs.map((spec) {
                    return DropdownMenuItem<String>(
                      value: spec.modelId,
                      child: Text(
                        spec.displayName,
                        style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) notifier.selectModel(newId);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Active Model Specs
            if (activeSpec != null) ...[
              Text(
                activeSpec.description,
                style: const TextStyle(fontSize: 12.5, color: AppColors.primaryText),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Khuyên dùng cho: ${activeSpec.recommendedFor}',
                style: const TextStyle(
                  fontSize: 12.0,
                  color: AppColors.primaryBlueDark,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14.0),

              // Explicit Capability Matrix Badges
              const Text(
                'Khả năng được xác nhận (Capability Matrix):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryText),
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                children: [
                  _buildCapabilityChip('💬 Văn bản (Text)', activeSpec.capabilities.supportsText),
                  _buildCapabilityChip('⚡ Streaming', activeSpec.capabilities.supportsStreaming),
                  _buildCapabilityChip('🎙️ Âm thanh vào', activeSpec.capabilities.supportsAudioInput),
                  _buildCapabilityChip('🔊 Phát âm (TTS)', activeSpec.capabilities.supportsTts),
                  _buildCapabilityChip('🔄 Live API', activeSpec.capabilities.supportsLiveApi),
                  _buildCapabilityChip('👁️ Thị giác (Vision)', activeSpec.capabilities.supportsVision),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityChip(String label, bool supported) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: supported ? AppColors.primaryBlueLight : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: supported ? AppColors.secondaryBlue : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            supported ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 13.0,
            color: supported ? AppColors.primaryBlueDark : AppColors.mutedText,
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              color: supported ? AppColors.primaryBlueDark : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live Connection Test Card
  // ---------------------------------------------------------------------------
  Widget _buildConnectionTestCard(AiSettingsState state, AiSettingsNotifier notifier) {
    final result = state.connectionTestResult;

    return Card(
      color: AppColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: state.isTestingConnection ? null : () => notifier.runConnectionTest(),
              icon: state.isTestingConnection
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.network_check, color: Colors.white),
              label: Text(
                state.isTestingConnection
                    ? 'Đang gửi gói tin kiểm tra thực tế...'
                    : 'Kiểm Tra Kết Nối Thực Tế',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlueDark,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            const SizedBox(height: 6.0),
            const Text(
              'Gửi 1 request nhỏ thật tới API endpoint để kiểm tra kết nối, tính toán độ trễ (latency) '
              'và xác minh khóa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
            ),

            // Diagnostic Result Presentation
            if (result != null) ...[
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: result.isSuccess ? AppColors.successContainerLight : AppColors.errorContainerLight,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: result.isSuccess ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Result Header & Latency
                    Row(
                      children: [
                        Icon(
                          result.isSuccess ? Icons.check_circle : Icons.error_outline,
                          color: result.isSuccess ? AppColors.success : AppColors.error,
                          size: 22.0,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            result.isSuccess ? 'Kết Nối Thành Công' : 'Kiểm Tra Thất Bại',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: result.isSuccess ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '⚡ ${result.latencyMs} ms',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: result.latencyMs < 500
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),

                    // Test Metadata
                    Text(
                      'Nhà cung cấp: ${result.providerName}  |  Mô hình: ${result.modelTested}',
                      style: const TextStyle(fontSize: 12.0, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 6.0),

                    // Error Details (Sanitized)
                    if (!result.isSuccess && result.errorMessage != null) ...[
                      Text(
                        'Chi tiết: ${result.errorMessage}',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                    ],

                    // Actionable Troubleshooting Hint
                    if (result.troubleshootingHint != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('👉 ', style: TextStyle(fontSize: 13.0)),
                            Expanded(
                              child: Text(
                                result.troubleshootingHint!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.primaryText,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteKey(BuildContext context, AiSettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Xác nhận xóa khóa API?', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        content: const Text(
          'Khóa sẽ bị xóa hoàn toàn khỏi Android KeyStore. Bạn sẽ cần nhập lại khóa để tiếp tục sử dụng AI.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              notifier.clearApiKey();
              Navigator.of(ctx).pop();
            },
            child: const Text('Xóa Khóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
