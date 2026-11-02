import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class OnboardingApiKeyScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final ValueChanged<String> onSaveApiKey;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bước 1 / 3'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
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
                decoration: InputDecoration(
                  labelText: 'Google Gemini API Key (tùy chọn)',
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              HiButton(
                text: 'Lưu API Key & Tiếp Tục',
                icon: const Icon(Icons.check_circle_outline_rounded),
                isFullWidth: true,
                onPressed: () {
                  final key = _controller.text.trim();
                  if (key.isNotEmpty) {
                    widget.onSaveApiKey(key);
                  } else {
                    widget.onSkip();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: widget.onSkip,
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
