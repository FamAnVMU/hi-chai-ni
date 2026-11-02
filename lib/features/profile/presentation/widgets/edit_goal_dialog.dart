import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';

class EditGoalDialog extends StatefulWidget {
  final UserProfile profile;
  final Future<void> Function({
    required int targetHskLevel,
    required int dailyMinutes,
    required LearnerPurpose purpose,
    required String reason,
  }) onConfirm;

  const EditGoalDialog({
    super.key,
    required this.profile,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required UserProfile profile,
    required Future<void> Function({
      required int targetHskLevel,
      required int dailyMinutes,
      required LearnerPurpose purpose,
      required String reason,
    }) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => EditGoalDialog(profile: profile, onConfirm: onConfirm),
    );
  }

  @override
  State<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<EditGoalDialog> {
  late int _targetHsk;
  late int _dailyMinutes;
  late LearnerPurpose _purpose;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<int> _minuteOptions = const [15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _targetHsk = widget.profile.targetHskLevel;
    _dailyMinutes = widget.profile.dailyMinutes;
    _purpose = widget.profile.purpose;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập lý do thay đổi mục tiêu để lưu lịch sử.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(
        targetHskLevel: _targetHsk,
        dailyMinutes: _dailyMinutes,
        purpose: _purpose,
        reason: reason,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi cập nhật: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Điều Chỉnh Mục Tiêu Học Tập'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thay đổi mục tiêu sẽ được ghi lại trong lịch sử để theo dõi sự tiến bộ theo thời gian.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),

            // Mục tiêu HSK
            Text('Trình độ HSK Mục Tiêu', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: List.generate(6, (index) {
                final level = index + 1;
                final isSelected = _targetHsk == level;
                return ChoiceChip(
                  label: Text('HSK $level'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _targetHsk = level);
                  },
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // Thời gian học mỗi ngày
            Text('Thời Gian Học / Ngày', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: _minuteOptions.map((mins) {
                final isSelected = _dailyMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins phút'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _dailyMinutes = mins);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Mục đích học
            Text('Mục Đích Chính', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<LearnerPurpose>(
              initialValue: _purpose,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              ),
              items: LearnerPurpose.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _purpose = val);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Lý do thay đổi (Bắt buộc)
            Row(
              children: [
                Text('Lý Do Thay Đổi', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            HiTextField(
              controller: _reasonController,
              hintText: 'Ví dụ: Đã đạt mục tiêu cũ, sắp đi công tác...',
              maxLines: 2,
              prefixIcon: const Icon(Icons.edit_note_rounded),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu Thay Đổi'),
        ),
      ],
    );
  }
}
