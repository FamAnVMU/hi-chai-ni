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
                        ? AppColors.primaryBlueLight
                        : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryBlueDark : AppColors.border,
                        width: isSelected ? 1.5 : 1,
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
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.primaryBlueDark : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skill['label']!,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.primaryBlueDark : AppColors.primaryText,
                                    ),
                                  ),
                                  Text(
                                    skill['desc']!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondaryText,
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
