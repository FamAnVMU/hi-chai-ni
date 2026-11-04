import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_progress_header.dart';

class OnboardingPersonalizationScreen extends StatefulWidget {
  final dynamic onComplete;
  final VoidCallback? onBack;

  const OnboardingPersonalizationScreen({
    super.key,
    required this.onComplete,
    this.onBack,
  });

  @override
  State<OnboardingPersonalizationScreen> createState() => _OnboardingPersonalizationScreenState();
}

class _OnboardingPersonalizationScreenState extends State<OnboardingPersonalizationScreen> {
  int _selectedMinutes = 30;
  String _selectedSkill = 'reading';
  String _selectedPurpose = 'dailyCommunication';
  bool _showPinyin = true;
  String _pinyinPosition = 'above_hanzi';
  String _scriptType = 'simplified';
  String _learningMethod = 'contextual_lessons';
  double _speechRate = 1.0;
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  final List<int> _commitmentOptions = [10, 15, 30, 45, 60];

  final List<Map<String, String>> _skillOptions = [
    {'id': 'listening', 'label': 'Nghe hiểu', 'desc': 'Luyện nghe phản xạ và nhận diện thanh điệu'},
    {'id': 'speaking', 'label': 'Nói / Phát âm', 'desc': 'Luyện phát âm chuẩn Pinyin & kỹ thuật Shadowing'},
    {'id': 'reading', 'label': 'Đọc hiểu', 'desc': 'Nhận diện mặt chữ Hán và ngữ cảnh văn bản'},
    {'id': 'writing', 'label': 'Viết chữ Hán', 'desc': 'Luyện thứ tự nét bút thuận (Vĩnh tự bát pháp)'},
    {'id': 'vocabulary', 'label': 'Vốn từ vựng', 'desc': 'Nhớ từ vựng cốt lõi & mở rộng từ theo gốc'},
    {'id': 'grammar', 'label': 'Điểm ngữ pháp', 'desc': 'Thành thạo cấu trúc câu và từ loại HSK'},
  ];

  final List<Map<String, dynamic>> _purposeOptions = [
    {
      'id': 'hskExam',
      'label': 'Luyện thi chứng chỉ HSK',
      'desc': 'Mục tiêu chứng chỉ HSK 1 - HSK 6 theo chuẩn HSK 3.0',
      'icon': Icons.school_rounded,
    },
    {
      'id': 'dailyCommunication',
      'label': 'Giao tiếp hàng ngày',
      'desc': 'Giao tiếp đời sống, phản xạ, đàm thoại thực tế',
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'id': 'businessWork',
      'label': 'Công việc & Thương mại',
      'desc': 'Thương mại, đàm phán, email và gặp gỡ đối tác',
      'icon': Icons.work_outline_rounded,
    },
    {
      'id': 'travelCulture',
      'label': 'Du lịch & Văn hóa',
      'desc': 'Du lịch, ẩm thực, âm nhạc và điện ảnh Trung Hoa',
      'icon': Icons.flight_takeoff_rounded,
    },
  ];

  final List<Map<String, dynamic>> _methodOptions = [
    {
      'id': 'contextual_lessons',
      'label': 'Bài học theo ngữ cảnh',
      'desc': 'Học qua câu chuyện, đoạn hội thoại và tình huống sinh động',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'id': 'srs_flashcard',
      'label': 'Ôn tập ngắt quãng (SRS)',
      'desc': 'Ghi nhớ từ vựng lâu dài theo thuật toán SuperMemo SM-2',
      'icon': Icons.style_rounded,
    },
    {
      'id': 'ai_tutor_conversation',
      'label': 'Đàm thoại với AI Tutor',
      'desc': 'Luyện phản xạ giao tiếp 1-1 với trợ giảng AI thông minh',
      'icon': Icons.support_agent_rounded,
    },
  ];

  void _handleSubmit() {
    final formattedTime =
        '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
    final data = PersonalizationData(
      purpose: _selectedPurpose,
      showPinyin: _showPinyin,
      pinyinPosition: _pinyinPosition,
      scriptType: _scriptType,
      learningMethod: _learningMethod,
      speechRate: _speechRate,
      reminderEnabled: _reminderEnabled,
      reminderTime: formattedTime,
    );

    try {
      (widget.onComplete as dynamic)(_selectedMinutes, _selectedSkill, data);
    } catch (_) {
      (widget.onComplete as dynamic)(_selectedMinutes, _selectedSkill);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá Nhân Hóa Trải Nghiệm'),
        centerTitle: true,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Quay lại',
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingProgressHeader(currentStep: 3),
              Text(
                'Thiết Lập Mục Tiêu Học Tập',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tùy chỉnh mục tiêu, thời lượng, phương pháp và hiển thị để ứng dụng điều chỉnh giáo trình phù hợp nhất với bạn.',
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
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _commitmentOptions.map((minutes) {
                    final isSelected = _selectedMinutes == minutes;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('$minutes phút'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedMinutes = minutes);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 2. Focus Skill selection
              Text(
                'Kỹ năng trọng điểm ưu tiên:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hệ thống sẽ tăng 40% tỷ trọng bài tập của kỹ năng này trong mỗi bài học.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._skillOptions.map((skill) {
                final isSelected = _selectedSkill == skill['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildSelectableCard(
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedSkill = skill['id']!),
                    leading: Container(
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
                    title: skill['label']!,
                    subtitle: skill['desc']!,
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // 3. Learning Purpose
              Text(
                'Mục tiêu học tiếng Trung chính của bạn:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._purposeOptions.map((purpose) {
                final isSelected = _selectedPurpose == purpose['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildSelectableCard(
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedPurpose = purpose['id'] as String),
                    leading: Icon(
                      purpose['icon'] as IconData,
                      color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
                    ),
                    title: purpose['label'] as String,
                    subtitle: purpose['desc'] as String,
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // 4. Pinyin & Display Preferences
              Text(
                'Hiển thị Pinyin & Phiên âm:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              HiCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hiển thị Pinyin mặc định'),
                      subtitle: const Text('Hỗ trợ người mới nhận diện phát âm nhanh chóng'),
                      value: _showPinyin,
                      activeThumbColor: AppColors.primaryBlueDark,
                      onChanged: (val) => setState(() => _showPinyin = val),
                    ),
                    if (_showPinyin) ...[
                      const Divider(),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vị trí hiển thị Pinyin:',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'above_hanzi',
                                label: Text('Trên chữ'),
                              ),
                              ButtonSegment(
                                value: 'below_hanzi',
                                label: Text('Dưới chữ'),
                              ),
                            ],
                            selected: {_pinyinPosition},
                            onSelectionChanged: (set) {
                              setState(() => _pinyinPosition = set.first);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 5. Script Type (Simplified vs Traditional)
              Text(
                'Bộ chữ Hán ưa thích:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioOptionCard(
                      title: 'Giản thể (简体)',
                      subtitle: 'Đại lục & HSK',
                      isSelected: _scriptType == 'simplified',
                      onTap: () => setState(() => _scriptType = 'simplified'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildRadioOptionCard(
                      title: 'Phồn thể (繁體)',
                      subtitle: 'Đài Loan, HK',
                      isSelected: _scriptType == 'traditional',
                      onTap: () => setState(() => _scriptType = 'traditional'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // 6. Preferred Learning Method
              Text(
                'Phương pháp học ưa thích:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._methodOptions.map((method) {
                final isSelected = _learningMethod == method['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildSelectableCard(
                    isSelected: isSelected,
                    onTap: () => setState(() => _learningMethod = method['id'] as String),
                    leading: Icon(
                      method['icon'] as IconData,
                      color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
                    ),
                    title: method['label'] as String,
                    subtitle: method['desc'] as String,
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // 7. Audio Playback Speed
              Text(
                'Tốc độ phát âm audio mặc định:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.8, label: Text('Chậm (0.8x)')),
                  ButtonSegment(value: 1.0, label: Text('Chuẩn (1.0x)')),
                  ButtonSegment(value: 1.2, label: Text('Nhanh (1.2x)')),
                ],
                selected: {_speechRate},
                onSelectionChanged: (set) {
                  setState(() => _speechRate = set.first);
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // 8. Daily Study Reminder
              Text(
                'Nhắc nhở học tập hàng ngày:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              HiCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bật nhắc nhở hằng ngày'),
                      subtitle: const Text('Duy trì chuỗi học tập (Streak) bền vững'),
                      value: _reminderEnabled,
                      activeThumbColor: AppColors.primaryBlueDark,
                      onChanged: (val) => setState(() => _reminderEnabled = val),
                    ),
                    if (_reminderEnabled) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alarm_rounded, color: AppColors.primaryBlueDark),
                        title: const Text('Giờ nhắc nhở'),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime,
                            );
                            if (picked != null) {
                              setState(() => _reminderTime = picked);
                            }
                          },
                          child: Text(
                            '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlueDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              HiButton(
                text: 'Bắt đầu lộ trình ngay',
                icon: const Icon(Icons.rocket_launch_rounded),
                isFullWidth: true,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableCard({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Material(
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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryBlueDark : AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
    );
  }

  Widget _buildRadioOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected ? AppColors.primaryBlueLight : AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primaryBlueDark : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryBlueDark : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryBlueDark),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
