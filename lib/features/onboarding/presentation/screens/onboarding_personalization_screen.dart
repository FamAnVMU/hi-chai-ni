import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class OnboardingPersonalizationScreen extends StatefulWidget {
  final void Function(int dailyMinutes, String focusSkill) onComplete;

  const OnboardingPersonalizationScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingPersonalizationScreen> createState() => _OnboardingPersonalizationScreenState();
}

class _OnboardingPersonalizationScreenState extends State<OnboardingPersonalizationScreen> {
  int _selectedMinutes = 30;
  String _selectedSkill = 'reading';

  final List<int> _commitmentOptions = [15, 30, 60];

  final List<Map<String, String>> _skillOptions = [
    {'id': 'listening', 'label': 'Nghe hiểu', 'desc': 'Luyện nghe phản xạ và thanh điệu'},
    {'id': 'speaking', 'label': 'Nói / Phát âm', 'desc': 'Luyện phát âm chuẩn Pinyin & Shadowing'},
    {'id': 'reading', 'label': 'Đọc hiểu', 'desc': 'Nhận diện mặt chữ Hán và ngữ cảnh văn bản'},
    {'id': 'writing', 'label': 'Viết chữ Hán', 'desc': 'Luyện thứ tự nét bút thuận (Vĩnh tự bát pháp)'},
    {'id': 'grammar', 'label': 'Điểm ngữ pháp', 'desc': 'Thành thạo cấu trúc câu và từ loại'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bước 3 / 3'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thiết Lập Mục Tiêu Học Tập',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tùy chỉnh thời lượng học và kỹ năng trọng điểm để hệ thống tự động tối ưu hóa ngân hàng bài tập phù hợp với bạn.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // 1. Time commitment
              Text(
                'Thời gian học mỗi ngày:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: _commitmentOptions.map((minutes) {
                  final isSelected = _selectedMinutes == minutes;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text('$minutes phút'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedMinutes = minutes);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 2. Focus Skill selection
              Text(
                'Kỹ năng trọng điểm ưu tiên:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Hệ thống sẽ tăng 40% tỷ trọng bài tập của kỹ năng này trong mỗi bài học.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._skillOptions.map((skill) {
                final isSelected = _selectedSkill == skill['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withAlpha(80)
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.limeGreen : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedSkill = skill['id']!);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: skill['id']!,
                              groupValue: _selectedSkill,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSkill = val);
                              },
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skill['label']!,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    skill['desc']!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),
              HiButton(
                text: 'Bắt đầu lộ trình ngay',
                icon: const Icon(Icons.rocket_launch_rounded),
                isFullWidth: true,
                onPressed: () {
                  widget.onComplete(_selectedMinutes, _selectedSkill);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
