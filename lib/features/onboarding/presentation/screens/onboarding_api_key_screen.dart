import 'package:flutter/material.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
import '../../../../core/theme/theme.dart';

class OnboardingApiKeyScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final Future<bool> Function(String apiKey) onSaveApiKey;

  const OnboardingApiKeyScreen({
    super.key,
    required this.onSkip,
    required this.onSaveApiKey,
  });

  @override
  State<OnboardingApiKeyScreen> createState() => _OnboardingApiKeyScreenState();
}

class _OnboardingApiKeyScreenState extends State<OnboardingApiKeyScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
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
      final success = await widget.onSaveApiKey(rawKey);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (!success) {
          _errorMessage = 'Không thể lưu API Key vào bộ nhớ bảo mật. Vui lòng thử lại.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Lỗi hệ thống khi lưu trữ an toàn. Vui lòng thử lại.';
      });
    }
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
              const SizedBox(height: AppSpacing.md),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 64,
                color: AppColors.primaryBlueDark,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Cấu hình AI Trợ Giảng (Tùy chọn)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'HI Chinese là nền tảng tự học hoạt động ngoại tuyến 100%. Toàn bộ giáo trình HSK 1, bài học, bài tập và đề thi đều được lưu trữ trực tiếp trên thiết bị của bạn.\n\nAPI Key chỉ dùng cho Trợ giảng AI khi bạn muốn hỏi sâu hơn và hoàn toàn không bắt buộc.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Google Gemini API Key (tùy chọn)',
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    tooltip: _obscureText ? 'Hiện API Key' : 'Ẩn API Key',
                  ),
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              HiButton(
                text: 'Lưu API Key & Tiếp Tục',
                icon: const Icon(Icons.check_circle_outline_rounded),
                isLoading: _isSaving,
                isFullWidth: true,
                onPressed: _isSaving ? null : _handleSave,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _isSaving ? null : widget.onSkip,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Bỏ qua để học ngoại tuyến'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
