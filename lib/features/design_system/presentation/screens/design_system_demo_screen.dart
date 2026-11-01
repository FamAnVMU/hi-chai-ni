import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';

/// Interactive showcase screen displaying all Design Tokens, Colors,
/// Typography (Vietnamese & Chinese), and Reusable Components.
class DesignSystemDemoScreen extends ConsumerStatefulWidget {
  const DesignSystemDemoScreen({super.key});

  @override
  ConsumerState<DesignSystemDemoScreen> createState() => _DesignSystemDemoScreenState();
}

class _DesignSystemDemoScreenState extends ConsumerState<DesignSystemDemoScreen> {
  bool _isButtonLoading = false;
  bool _showPinyinInRuby = true;
  bool _showTraditionalInRuby = false;
  String? _activeRubyWordId = 'w2';
  bool _isAudioPlaying = false;
  final TextEditingController _inputController = TextEditingController(text: 'Xin chào / 你好');
  final TextEditingController _pwdController = TextEditingController(text: 'secret_api_key_123');
  String _selectedChip = 'HSK 1';

  @override
  void dispose() {
    _inputController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design System Showcase'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.colorScheme.primary,
            ),
            tooltip: isDark ? 'Chuyển sang Giao diện Sáng' : 'Chuyển sang Giao diện Tối',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. THEME MODE SELECTOR
              _buildSectionHeader('1. Theme Mode Switcher (Chế độ giao diện)'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Hệ thống'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Sáng'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Tối'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                },
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 2. PALETTE & SEMANTIC COLORS
              _buildSectionHeader('2. Bảng Màu Semantic (Color Tokens)'),
              _buildColorGrid(isDark),
              const SizedBox(height: AppSpacing.xxl),

              // 3. TYPOGRAPHY & MULTI-LANGUAGE
              _buildSectionHeader('3. Typography & Đa Ngữ (Việt - Trung)'),
              HiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Large Hanzi + Pinyin (40sp + 18sp)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('学', style: AppTypography.hanziLarge(color: theme.colorScheme.primary)),
                        const SizedBox(width: AppSpacing.md),
                        Text('xué', style: AppTypography.pinyinLarge(color: theme.colorScheme.onSurface)),
                        const SizedBox(width: AppSpacing.lg),
                        Text('(Học / Học tập)', style: AppTypography.vietnameseMeaning(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      'Hội thoại & Câu ví dụ (Medium Hanzi)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '你好，世界！我们正在构建 HI Chinese。',
                      style: AppTypography.hanziMedium(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Nǐ hǎo, shìjiè! Wǒmen zhèngzài gòujiàn HI Chinese.',
                      style: AppTypography.pinyin(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Chào thế giới! Chúng ta đang xây dựng ứng dụng HI Chinese.',
                      style: AppTypography.vietnameseMeaning(color: theme.colorScheme.onSurface),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      'Tiếng Việt đầy đủ dấu thanh (WCAG Check):',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '“Học tiếng Trung mỗi ngày cùng trợ lý AI cá nhân hoá, '
                      'luyện phát âm, nhớ từ vựng với phương pháp lặp lại ngắt quãng SM-2.”',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 3.1 RUBY TEXT COMPONENT (HANZI + PINYIN)
              _buildSectionHeader('3.1. Component RubyText (Chữ Hán kèm Pinyin)'),
              HiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tương tác & Xuống dòng chuẩn',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text('Pinyin', style: theme.textTheme.labelSmall),
                            Switch(
                              value: _showPinyinInRuby,
                              onChanged: (val) {
                                setState(() {
                                  _showPinyinInRuby = val;
                                });
                              },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Phồn thể', style: theme.textTheme.labelSmall),
                            Switch(
                              value: _showTraditionalInRuby,
                              onChanged: (val) {
                                setState(() {
                                  _showTraditionalInRuby = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Nhấn vào từng từ để xem nghĩa và kiểm tra âm thanh:',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RubyText(
                      showPinyin: _showPinyinInRuby,
                      showTraditional: _showTraditionalInRuby,
                      activeWordId: _activeRubyWordId,
                      isAudioLoading: _isAudioPlaying,
                      onSegmentTap: (segment) {
                        setState(() {
                          _activeRubyWordId = segment.wordId;
                        });
                        HiSnackBar.showInfo(
                          context,
                          'Từ: ${segment.text} [${segment.pinyin ?? ''}] - Nghĩa: ${segment.meaning ?? "Chưa có"}',
                        );
                      },
                      onPronounceTap: (segment) async {
                        setState(() {
                          _activeRubyWordId = segment.wordId;
                          _isAudioPlaying = true;
                        });
                        await Future<void>.delayed(const Duration(milliseconds: 600));
                        if (!context.mounted) return;
                        setState(() {
                          _isAudioPlaying = false;
                        });
                        HiSnackBar.showSuccess(
                          context,
                          'Đang phát âm thanh mẫu cho: ${segment.text}',
                        );
                      },
                      segments: [
                        RubySegment.word(
                          hanzi: '我们',
                          pinyin: 'wǒmen',
                          wordId: 'w1',
                          meaning: 'chúng tôi, chúng ta',
                          traditionalText: '我們',
                        ),
                        RubySegment.word(
                          hanzi: '去',
                          pinyin: 'qù',
                          wordId: 'w2',
                          meaning: 'đi',
                        ),
                        RubySegment.word(
                          hanzi: '银行',
                          pinyin: 'yínháng',
                          wordId: 'w3',
                          meaning: 'ngân hàng (đa âm tự: 行 = háng)',
                          traditionalText: '銀行',
                        ),
                        RubySegment.punctuation('，'),
                        RubySegment.word(
                          hanzi: '再去',
                          pinyin: 'zài qù',
                          wordId: 'w4',
                          meaning: 'lại đi',
                        ),
                        RubySegment.word(
                          hanzi: '骑',
                          pinyin: 'qí',
                          wordId: 'w5',
                          meaning: 'cưỡi, đạp',
                          traditionalText: '騎',
                        ),
                        RubySegment.word(
                          hanzi: '自行车',
                          pinyin: 'zìxíngchē',
                          wordId: 'w6',
                          meaning: 'xe đạp (đa âm tự: 行 = xíng)',
                          traditionalText: '自行車',
                        ),
                        RubySegment.punctuation('！'),
                      ],
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      'Câu trích Luận Ngữ (Xuống dòng nhiều câu & dấu câu):',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RubyText.fromAnnotatedString(
                      annotatedText:
                          '学[xué:học]而[ér:và]时[shí:thường xuyên]习[xí:ôn tập]之[zhī:nó]，'
                          '不[bù:không]亦[yì:cũng]说[yuè:vui vẻ]乎[hū:sao]？'
                          '有[yǒu:có]朋[péng:bạn]自[zì:từ]远[yuǎn:xa]方[fāng:phương]来[lái:đến]，'
                          '不[bù:không]亦[yì:cũng]乐[lè:vui]乎[hū:sao]！',
                      showPinyin: _showPinyinInRuby,
                      showTraditional: _showTraditionalInRuby,
                      onSegmentTap: (segment) {
                        HiSnackBar.showInfo(
                          context,
                          'Chữ Hán: ${segment.text} | Pinyin: ${segment.pinyin} | Nghĩa: ${segment.meaning}',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 4. BUTTONS
              _buildSectionHeader('4. Buttons (Nút Bấm & Trạng Thái)'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  HiButton(
                    text: 'Primary Button',
                    variant: HiButtonVariant.primary,
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () {},
                  ),
                  HiButton(
                    text: 'Secondary Button',
                    variant: HiButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  HiButton(
                    text: 'Ghost Button',
                    variant: HiButtonVariant.ghost,
                    onPressed: () {},
                  ),
                  HiButton(
                    text: 'Danger Button',
                    variant: HiButtonVariant.danger,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {},
                  ),
                  HiButton(
                    text: 'Loading State',
                    variant: HiButtonVariant.primary,
                    isLoading: _isButtonLoading,
                    onPressed: () {
                      setState(() {
                        _isButtonLoading = !_isButtonLoading;
                      });
                    },
                  ),
                  const HiButton(
                    text: 'Disabled Button',
                    variant: HiButtonVariant.primary,
                    onPressed: null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              HiButton(
                text: 'Full Width Button (Touch Target ≥ 48dp)',
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                isFullWidth: true,
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 5. INPUTS
              _buildSectionHeader('5. Input Fields (Trường Nhập Liệu)'),
              HiTextField(
                controller: _inputController,
                label: 'Tên hoặc Từ khóa tiếng Trung',
                hintText: 'Nhập từ vựng hoặc câu hỏi...',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(height: AppSpacing.md),
              HiTextField(
                controller: _pwdController,
                label: 'Gemini API Key (Bảo mật)',
                hintText: 'Nhập API Key...',
                isPassword: true,
                prefixIcon: const Icon(Icons.key_rounded),
                helperText: 'Chế độ ẩn ký tự bảo vệ khóa bí mật',
              ),
              const SizedBox(height: AppSpacing.md),
              const HiTextField(
                label: 'Trạng thái Lỗi (Validation Error)',
                hintText: 'user@example.com',
                errorText: 'Định dạng email hoặc khóa không hợp lệ',
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 6. CHIPS
              _buildSectionHeader('6. Chips & Badges'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final level in ['HSK 1', 'HSK 2', 'HSK 3', 'HSK 4'])
                    HiChip(
                      label: level,
                      isSelected: _selectedChip == level,
                      onTap: () {
                        setState(() {
                          _selectedChip = level;
                        });
                      },
                    ),
                  const HiChip(
                    label: 'Đã hoàn thành',
                    status: HiChipStatus.success,
                    icon: Icon(Icons.check_circle_rounded),
                  ),
                  const HiChip(
                    label: 'Cần ôn tập',
                    status: HiChipStatus.warning,
                    icon: Icon(Icons.schedule_rounded),
                  ),
                  const HiChip(
                    label: 'Chưa đạt',
                    status: HiChipStatus.error,
                    icon: Icon(Icons.cancel_rounded),
                  ),
                  const HiChip(
                    label: 'Thông tin',
                    status: HiChipStatus.info,
                    icon: Icon(Icons.info_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 7. CARDS & CONTAINERS
              _buildSectionHeader('7. Cards (Thẻ nội dung)'),
              HiCard(
                onTap: () {
                  HiSnackBar.showInfo(context, 'Bạn vừa chạm vào Thẻ Tương Tác');
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thẻ Học Tương Tác',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Bấm vào thẻ này để kích hoạt sự kiện tap với hiệu ứng ripple mượt mà.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 8. DIALOGS, SHEETS & SNACKBARS
              _buildSectionHeader('8. Modals, Sheets & Feedback'),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  HiButton(
                    text: 'Mở HiDialog',
                    variant: HiButtonVariant.secondary,
                    onPressed: () {
                      HiDialog.show(
                        context: context,
                        title: 'Xác nhận Đặt lại Dữ liệu?',
                        message: 'Thao tác này sẽ khôi phục cài đặt gốc của AI Tutor. Bạn có chắc chắn không?',
                        confirmText: 'Xác nhận',
                        cancelText: 'Hủy bỏ',
                        isDestructive: true,
                        onConfirm: () {
                          HiSnackBar.showSuccess(context, 'Đã đặt lại dữ liệu thành công!');
                        },
                      );
                    },
                  ),
                  HiButton(
                    text: 'Mở HiBottomSheet',
                    variant: HiButtonVariant.secondary,
                    onPressed: () {
                      HiBottomSheet.show(
                        context: context,
                        title: 'Tùy chọn Học tập',
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.speed_rounded),
                              title: const Text('Tốc độ đọc giọng nói AI'),
                              subtitle: const Text('1.0x (Bình thường)'),
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            ListTile(
                              leading: const Icon(Icons.subtitles_rounded),
                              title: const Text('Hiện Pinyin tự động'),
                              subtitle: const Text('Bật cho tất cả từ mới'),
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  HiButton(
                    text: 'SnackBar Thành Công',
                    variant: HiButtonVariant.ghost,
                    onPressed: () {
                      HiSnackBar.showSuccess(context, 'Đồng bộ bài học tiếng Trung thành công!');
                    },
                  ),
                  HiButton(
                    text: 'SnackBar Báo Lỗi',
                    variant: HiButtonVariant.ghost,
                    onPressed: () {
                      HiSnackBar.showError(context, 'Mất kết nối mạng hoặc lỗi chứng chỉ API.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 9. PROGRESS & STATES
              _buildSectionHeader('9. Trạng Thái & Loading (States)'),
              HiCard(
                child: Column(
                  children: [
                    const Text('Linear Progress (Tiến độ học tập: 68%)'),
                    const SizedBox(height: AppSpacing.sm),
                    const HiLinearProgress(value: 0.68),
                    const SizedBox(height: AppSpacing.xl),
                    const HiLoadingIndicator(
                      message: 'AI Tutor đang biên soạn bài học cá nhân...',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const HiCard(
                child: HiEmptyState(
                  icon: Icons.school_outlined,
                  title: 'Chưa có bài kiểm tra nào',
                  description: 'Hãy hoàn thành bài học cơ bản đầu tiên để mở khóa hệ thống kiểm tra.',
                  actionText: 'Bắt đầu học ngay',
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildColorGrid(bool isDark) {
    final colors = [
      {'name': 'Lime Green', 'color': AppColors.limeGreen, 'hex': '#A3D635'},
      {'name': 'Dark Forest Bg', 'color': AppColors.darkForestBg, 'hex': '#121811'},
      {'name': 'Dark Surface', 'color': AppColors.darkForestSurface, 'hex': '#1A2418'},
      {'name': 'Dark Card', 'color': AppColors.darkForestCard, 'hex': '#243022'},
      {'name': 'Off-white Light', 'color': AppColors.offWhite, 'hex': '#F6FAF2'},
      {'name': 'Success', 'color': isDark ? AppColors.successDark : AppColors.success, 'hex': isDark ? '#81C784' : '#2E7D32'},
      {'name': 'Warning', 'color': isDark ? AppColors.warningDark : AppColors.warning, 'hex': isDark ? '#FFB74D' : '#B26A00'},
      {'name': 'Error', 'color': isDark ? AppColors.errorDark : AppColors.errorLight, 'hex': isDark ? '#FFB4AB' : '#BA1A1A'},
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: colors.map((item) {
        final color = item['color'] as Color;
        final name = item['name'] as String;
        final hex = item['hex'] as String;

        return Container(
          width: 105,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: Colors.white24,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  backgroundColor: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                hex,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black87,
                  backgroundColor: Colors.white70,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
