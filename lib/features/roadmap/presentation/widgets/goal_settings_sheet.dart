import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/roadmap_models.dart';

/// Modal bottom sheet allowing the learner to customize their learning goal.
class GoalSettingsSheet extends StatefulWidget {
  final LearnerGoal currentGoal;
  final ValueChanged<LearnerGoal> onSave;

  const GoalSettingsSheet({
    super.key,
    required this.currentGoal,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required LearnerGoal currentGoal,
    required ValueChanged<LearnerGoal> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoalSettingsSheet(
        currentGoal: currentGoal,
        onSave: onSave,
      ),
    );
  }

  @override
  State<GoalSettingsSheet> createState() => _GoalSettingsSheetState();
}

class _GoalSettingsSheetState extends State<GoalSettingsSheet> {
  late int _targetHskLevel;
  late LearnerPurpose _purpose;
  late LearnerTimeframe _timeframe;
  late int _dailyMinutes;

  @override
  void initState() {
    super.initState();
    _targetHskLevel = widget.currentGoal.targetHskLevel;
    _purpose = widget.currentGoal.purpose;
    _timeframe = widget.currentGoal.timeframe;
    _dailyMinutes = widget.currentGoal.dailyMinutes;
  }

  void _handleSave() {
    final updated = widget.currentGoal.copyWith(
      targetHskLevel: _targetHskLevel,
      purpose: _purpose,
      timeframe: _timeframe,
      dailyMinutes: _dailyMinutes,
      updatedAt: DateTime.now().toUtc(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: AppColors.limeGreen,
                  size: AppDimensions.iconMd,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Thiết Lập Mục Tiêu Học Tập',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 1. Target HSK Level
            Text(
              'Cấp độ HSK mục tiêu:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [1, 2, 3, 4, 5].map((lvl) {
                final isSelected = _targetHskLevel == lvl;
                return HiChip(
                  label: 'HSK $lvl',
                  isSelected: isSelected,
                  onTap: () => setState(() => _targetHskLevel = lvl),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Learning Purpose
            Text(
              'Mục đích học chính:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: LearnerPurpose.values.map((purp) {
                final isSelected = _purpose == purp;
                return HiChip(
                  label: purp.displayName,
                  isSelected: isSelected,
                  onTap: () => setState(() => _purpose = purp),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Timeframe / Pace
            Text(
              'Tốc độ mong muốn:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: LearnerTimeframe.values.map((tf) {
                final isSelected = _timeframe == tf;
                return HiChip(
                  label: tf.displayName,
                  isSelected: isSelected,
                  onTap: () => setState(() => _timeframe = tf),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Daily Minutes
            Text(
              'Thời lượng mỗi ngày: $_dailyMinutes phút',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [15, 30, 45, 60].map((mins) {
                final isSelected = _dailyMinutes == mins;
                return HiChip(
                  label: '$mins phút',
                  isSelected: isSelected,
                  onTap: () => setState(() => _dailyMinutes = mins),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: HiButton(
                    text: 'Hủy',
                    variant: HiButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HiButton(
                    text: 'Lưu mục tiêu',
                    variant: HiButtonVariant.primary,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
