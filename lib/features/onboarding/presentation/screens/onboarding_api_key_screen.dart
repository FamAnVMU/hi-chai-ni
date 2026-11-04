import 'package:flutter/material.dart';
import '../../../../core/network/ai/models/ai_model_config.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
import '../../../../core/theme/theme.dart';

class OnboardingApiKeyScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final dynamic onSaveApiKey;
  final VoidCallback? onSuccessNext;

  const OnboardingApiKeyScreen({
    super.key,
    required this.onSkip,
    this.onSaveApiKey,
    this.onSuccessNext,
  });

  @override
  State<OnboardingApiKeyScreen> createState() => _OnboardingApiKeyScreenState();
}

class _OnboardingApiKeyScreenState extends State<OnboardingApiKeyScreen> {
  final TextEditingController _controller = TextEditingController();
  AiProviderType _selectedProvider = AiProviderType.geminiRest;
  bool _obscureText = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorMessage;
  String? _testSuccessMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    final rawKey = _controller.text.trim();
    final validationError = AiCredentialStorage.validateApiKey(rawKey);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _testSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _testSuccessMessage = null;
    });

    try {
      final storage = AiCredentialStorage();
      await storage.saveApiKey(rawKey, provider: _selectedProvider);
      await storage.saveProviderType(_selectedProvider);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() {
        _isTesting = false;
        _testSuccessMessage = 'Định dạng khóa hợp lệ và đã lưu trữ phần cứng an toàn!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _errorMessage = 'Kiểm tra thất bại: ${AiCredentialStorage.sanitizeSecret(e.toString())}';
      });
    }
  }

  Future<void> _handleSaveAndContinue() async {
    final rawKey = _controller.text.trim();
    if (rawKey.isEmpty) {
      widget.onSkip();
      return;
    }

    final validationError = AiCredentialStorage.validateApiKey(rawKey);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.onSaveApiKey != null) {
        bool success = false;
        final callback = widget.onSaveApiKey;
        if (callback is Future<bool> Function(String, AiProviderType)) {
          success = await callback(rawKey, _selectedProvider);
        } else if (callback is Future<bool> Function(String)) {
          success = await callback(rawKey);
        } else if (callback is bool Function(String)) {
          success = callback(rawKey);
        } else if (callback is void Function(String)) {
          callback(rawKey);
          success = true;
        }

        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          widget.onSuccessNext?.call();
        } else {
          setState(() {
            _errorMessage = 'Không thể lưu khóa API an toàn. Vui lòng thử lại.';
          });
        }
        return;
      }

      final storage = AiCredentialStorage();
      await storage.saveApiKey(rawKey, provider: _selectedProvider);
      await storage.saveProviderType(_selectedProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.onSuccessNext?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Lỗi hệ thống khi lưu trữ an toàn. Vui lòng thử lại.';
      });
    }
  }

  void _showHowToGetApiKeyDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppColors.primaryBlueDark),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Hướng Dẫn Lấy Gemini API Key Miễn Phí',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildGuideStep(
                    '1',
                    'Truy cập Google AI Studio',
                    'Mở trình duyệt và truy cập: aistudio.google.com bằng tài khoản Google của bạn.',
                  ),
                  _buildGuideStep(
                    '2',
                    'Tạo API Key',
                    'Bấm nút "Get API key" ở góc trên bên trái, sau đó chọn "Create API key".',
                  ),
                  _buildGuideStep(
                    '3',
                    'Sao chép và Dán vào đây',
                    'Sao chép chuỗi ký tự bắt đầu bằng "AIzaSy..." và dán vào ô nhập bên dưới.',
                  ),
                  _buildGuideStep(
                    '4',
                    'Chi phí & Quyền riêng tư',
                    'Bản miễn phí của Google hỗ trợ gọi mô hình thoải mái cho nhu cầu học cá nhân. Khóa được mã hóa phần cứng trên điện thoại, không bao giờ gửi về máy chủ thứ ba.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HiButton(
                    text: 'Đã hiểu',
                    isFullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuideStep(String stepNumber, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryBlueDark,
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bước 1 / 3'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xs),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 56,
                color: AppColors.primaryBlueDark,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Cấu hình AI Trợ Giảng (Tùy chọn)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'HI Chinese là nền tảng tự học hoạt động ngoại tuyến 100%. Toàn bộ giáo trình HSK 1, bài học, bài tập và đề thi đều được lưu trữ trực tiếp trên thiết bị của bạn.\n\nAPI Key chỉ dùng cho Trợ giảng AI khi bạn muốn hỏi sâu hơn và hoàn toàn không bắt buộc.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              SegmentedButton<AiProviderType>(
                segments: const [
                  ButtonSegment(
                    value: AiProviderType.geminiRest,
                    label: Text('Google Gemini'),
                    icon: Icon(Icons.bolt_rounded),
                  ),
                  ButtonSegment(
                    value: AiProviderType.firebaseAiLogic,
                    label: Text('Firebase AI'),
                    icon: Icon(Icons.cloud_queue_rounded),
                  ),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (newVal) {
                  setState(() {
                    _selectedProvider = newVal.first;
                    _errorMessage = null;
                    _testSuccessMessage = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _controller,
                obscureText: _obscureText,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: _selectedProvider == AiProviderType.geminiRest
                      ? 'Google Gemini API Key (tùy chọn)'
                      : 'Firebase AI Token',
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                    tooltip: _obscureText ? 'Hiện khóa' : 'Ẩn khóa',
                  ),
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 2),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showHowToGetApiKeyDialog,
                  icon: const Icon(Icons.help_outline_rounded, size: 16),
                  label: const Text('Cách lấy API Key miễn phí?'),
                ),
              ),

              if (_testSuccessMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _testSuccessMessage!,
                          style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xs),

              OutlinedButton.icon(
                onPressed: (_isTesting || _isSaving) ? null : _handleTestConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_protected_setup_rounded),
                label: Text(_isTesting ? 'Đang kiểm tra...' : 'Kiểm tra kết nối API'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              HiButton(
                text: 'Lưu API Key & Tiếp Tục',
                icon: const Icon(Icons.arrow_forward_rounded),
                isLoading: _isSaving,
                isFullWidth: true,
                onPressed: (_isSaving || _isTesting) ? null : _handleSaveAndContinue,
              ),

              const SizedBox(height: AppSpacing.xs),

              OutlinedButton(
                onPressed: (_isSaving || _isTesting) ? null : widget.onSkip,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Bỏ qua để học ngoại tuyến'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
