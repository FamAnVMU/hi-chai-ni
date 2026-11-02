import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/user_profile.dart';

class EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile> onSave;

  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required UserProfile profile,
    required ValueChanged<UserProfile> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(profile: profile, onSave: onSave),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late String _selectedAvatar;
  late Set<String> _selectedInterests;

  final List<Map<String, String>> _avatars = const [
    {'id': 'panda', 'label': 'Gấu Trúc 🐼'},
    {'id': 'dragon', 'label': 'Thần Long 🐉'},
    {'id': 'bamboo', 'label': 'Trúc Xanh 🎋'},
    {'id': 'lantern', 'label': 'Lồng Đèn 🏮'},
    {'id': 'tea', 'label': 'Trà Đạo 🍵'},
    {'id': 'scholar', 'label': 'Học Giả 📜'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _selectedAvatar = widget.profile.avatarStyle;
    _selectedInterests = widget.profile.interests.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.profile.copyWith(
      displayName: _nameController.text.trim().isEmpty ? 'Người học HI Chinese' : _nameController.text.trim(),
      avatarStyle: _selectedAvatar,
      interests: _selectedInterests.toList(),
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
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
            Text(
              'Chỉnh Sửa Hồ Sơ Học Tập',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hồ sơ hoạt động hoàn toàn cục bộ trên thiết bị của bạn.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tên hiển thị
            Text(
              'Tên hiển thị (Tùy chọn)',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            HiTextField(
              controller: _nameController,
              hintText: 'Nhập tên của bạn...',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Chọn Biểu Tượng / Avatar
            Text(
              'Biểu tượng học tập',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _avatars.map((av) {
                final isSelected = _selectedAvatar == av['id'];
                return ChoiceChip(
                  label: Text(av['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAvatar = av['id']!);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Chọn Sở Thích
            Text(
              'Sở thích & Chủ đề quan tâm',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: LearnerInterest.defaultInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest.id);
                return FilterChip(
                  label: Text('${interest.labelVi} (${interest.labelZh})'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest.id);
                      } else {
                        if (_selectedInterests.length > 1) {
                          _selectedInterests.remove(interest.id);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Buttons
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
                    text: 'Lưu Hồ Sơ',
                    variant: HiButtonVariant.primary,
                    onPressed: _save,
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
