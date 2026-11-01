import 'package:flutter/material.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Standardized bottom sheet modal for HI Chinese.
class HiBottomSheet extends StatelessWidget {
  final String? title;
  final Widget content;
  final Widget? trailing;
  final bool showHandle;

  const HiBottomSheet({
    super.key,
    this.title,
    required this.content,
    this.trailing,
    this.showHandle = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget content,
    String? title,
    Widget? trailing,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (ctx) => HiBottomSheet(
        title: title,
        content: content,
        trailing: trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: AppSpacing.bottomSheetPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: AppDimensions.bottomSheetHandleWidth,
                  height: AppDimensions.bottomSheetHandleHeight,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: AppRadius.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (title != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: AppDimensions.iconSm,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Đóng',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Flexible(child: content),
          ],
        ),
      ),
    );
  }
}
