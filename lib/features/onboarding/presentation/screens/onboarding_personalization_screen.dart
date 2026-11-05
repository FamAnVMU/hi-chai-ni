import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/onboarding_progress_header.dart';

/// Màn hình Cá nhân hóa trải nghiệm học tập dạng Multi-Step Wizard (3 chặng)
/// - Chặng 1: Mục tiêu học tập, thời gian cam kết & kỹ năng ưu tiên
/// - Chặng 2: Phương pháp học ưa thích & nhắc nhở học tập hàng ngày
/// - Chặng 3: Tùy chỉnh hiển thị Pinyin, bộ chữ Hán & tốc độ phát âm
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
  final PageController _pageController = PageController();
  int _currentSubStep = 0;
  static const int _totalSubSteps = 3;

  // --- Step 1 State: Goals & Commitment ---
  int _selectedMinutes = 30;
  String _selectedSkill = 'reading';
  String _selectedPurpose = 'dailyCommunication';

  // --- Step 2 State: Method & Habit ---
  String _learningMethod = 'contextual_lessons';
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // --- Step 3 State: Display & Audio Preferences ---
  bool _showPinyin = true;
  String _pinyinPosition = 'above_hanzi';
  String _scriptType = 'simplified';
  double _speechRate = 1.0;

  final List<int> _commitmentOptions = [10, 15, 30, 45, 60];

  final List<Map<String, String>> _skillOptions = [
    {'id': 'balanced', 'label': 'Toàn diện – Học đều 6 kỹ năng', 'desc': 'Phân bổ đều 6 kỹ năng, không ưu tiên riêng lẻ'},
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextSubStep() {
    if (_currentSubStep < _totalSubSteps - 1) {
      _pageController.animateToPage(
        _currentSubStep + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevSubStep() {
    if (_currentSubStep > 0) {
      _pageController.animateToPage(
        _currentSubStep - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onBack?.call();
    }
  }

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
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _prevSubStep();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cá Nhân Hóa Trải Nghiệm'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Quay lại',
            onPressed: _prevSubStep,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Column(
                  children: [
                    const OnboardingProgressHeader(currentStep: 3),
                    const SizedBox(height: AppSpacing.xs),
                    _buildSubStepIndicator(theme, isDark),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentSubStep = page);
                  },
                  children: [
                    _buildStep1Goals(theme),
                    _buildStep2Habits(theme),
                    _buildStep3Preferences(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh tiến trình phụ hiển thị Chặng 1/3, 2/3, 3/3
  Widget _buildSubStepIndicator(ThemeData theme, bool isDark) {
    final subStepTitles = [
      '1. Mục Tiêu & Thời Gian',
      '2. Phương Pháp & Thói Quen',
      '3. Hiển Thị & Âm Thanh',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : AppColors.primaryBlueLight.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? theme.colorScheme.outlineVariant.withAlpha(40) : AppColors.secondaryBlue.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Chặng ${_currentSubStep + 1}/$_totalSubSteps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                subStepTitles[_currentSubStep],
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? theme.colorScheme.onSurface : AppColors.primaryBlueDark,
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(_totalSubSteps, (index) {
              final isActive = index == _currentSubStep;
              final isPassed = index < _currentSubStep;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: isActive ? 16 : 8,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryBlueDark
                      : (isPassed
                          ? (isDark ? theme.colorScheme.primary : AppColors.primaryBlue)
                          : (isDark ? Colors.white24 : AppColors.border)),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CHẶNG 1: MỤC TIÊU & THỜI GIAN CAM KẾT (GOALS & COMMITMENT)
  // =========================================================================
  Widget _buildStep1Goals(ThemeData theme) {
    return SingleChildScrollView(
      key: const PageStorageKey('wizard_step_1_goals'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thiết Lập Mục Tiêu Học Tập',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mục tiêu và thời gian học của bạn',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlueDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Thiết lập mục tiêu và thời lượng cam kết mỗi ngày để hệ thống xây dựng lộ trình học tập tối ưu.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Learning Purpose
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

          const SizedBox(height: AppSpacing.md),

          // 2. Daily time commitment
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

          const SizedBox(height: AppSpacing.lg),

          // 3. Priority Skill
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

          const SizedBox(height: AppSpacing.lg),
          HiButton(
            text: 'Tiếp tục sang Chặng 2',
            icon: const Icon(Icons.arrow_forward_rounded),
            isFullWidth: true,
            onPressed: _nextSubStep,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: _handleSubmit,
              child: const Text('Bắt đầu lộ trình ngay'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  // =========================================================================
  // CHẶNG 2: PHƯƠNG PHÁP & THÓI QUEN HỌC TẬP (METHOD & HABIT)
  // =========================================================================
  Widget _buildStep2Habits(ThemeData theme) {
    return SingleChildScrollView(
      key: const PageStorageKey('wizard_step_2_habits'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phương pháp và thói quen rèn luyện',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lựa chọn phong cách tiếp cận phù hợp và duy trì thói quen học tập đều đặn mỗi ngày.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Preferred Learning Method
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

          const SizedBox(height: AppSpacing.lg),

          // 2. Daily Reminder
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevSubStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Quay lại Chặng 1'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HiButton(
                  text: 'Tiếp tục Chặng 3',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _nextSubStep,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  // =========================================================================
  // CHẶNG 3: TRẢI NGHIỆM HỌC & HIỂN THỊ (DISPLAY & AUDIO PREFERENCES)
  // =========================================================================
  Widget _buildStep3Preferences(ThemeData theme) {
    return SingleChildScrollView(
      key: const PageStorageKey('wizard_step_3_preferences'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tùy chỉnh hiển thị và âm thanh',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tinh chỉnh kiểu hiển thị chữ Hán, phiên âm Pinyin và tốc độ phát âm chuẩn xác nhất với bạn.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Pinyin Preferences
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

          const SizedBox(height: AppSpacing.lg),

          // 2. Script Type
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

          const SizedBox(height: AppSpacing.lg),

          // 3. Audio Speed
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _prevSubStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Quay lại Chặng 2'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: HiButton(
                  text: 'Hoàn tất thiết lập & Vào học',
                  icon: const Icon(Icons.rocket_launch_rounded),
                  onPressed: _handleSubmit,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark ? theme.colorScheme.primaryContainer.withAlpha(90) : AppColors.primaryBlueLight;
    final unselectedBg = isDark ? theme.colorScheme.surface : AppColors.cardBackground;
    final selectedBorder = isDark ? theme.colorScheme.primary : AppColors.primaryBlueDark;
    final unselectedBorder = isDark ? theme.colorScheme.outlineVariant.withAlpha(50) : AppColors.border;

    return Material(
      color: isSelected ? selectedBg : unselectedBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? selectedBorder : unselectedBorder,
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
                        color: isSelected
                            ? (isDark ? theme.colorScheme.primary : AppColors.primaryBlueDark)
                            : (isDark ? theme.colorScheme.onSurface : AppColors.primaryText),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? theme.colorScheme.onSurfaceVariant : AppColors.secondaryText,
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
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark ? theme.colorScheme.primaryContainer.withAlpha(90) : AppColors.primaryBlueLight;
    final unselectedBg = isDark ? theme.colorScheme.surface : AppColors.cardBackground;
    final selectedBorder = isDark ? theme.colorScheme.primary : AppColors.primaryBlueDark;
    final unselectedBorder = isDark ? theme.colorScheme.outlineVariant.withAlpha(50) : AppColors.border;

    return Material(
      color: isSelected ? selectedBg : unselectedBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? selectedBorder : unselectedBorder,
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
                        color: isSelected ? (isDark ? theme.colorScheme.primary : AppColors.primaryBlueDark) : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isDark ? theme.colorScheme.primary : AppColors.primaryBlueDark,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? theme.colorScheme.onSurfaceVariant : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
