import 'package:flutter/material.dart';
import '../tokens/app_dimensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import 'hi_button.dart';

/// Standardized dialog component for alerts, confirmations, and modals.
class HiDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? message;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final Widget? customActions;

  const HiDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
    this.isDestructive = false,
    this.customActions,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    String? message,
    String? confirmText,
    VoidCallback? onConfirm,
    String? cancelText,
    VoidCallback? onCancel,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => HiDialog(
        title: title,
        content: content,
        message: message,
        confirmText: confirmText,
        onConfirm: onConfirm != null
            ? () {
                Navigator.of(ctx).pop();
                onConfirm();
              }
            : null,
        cancelText: cancelText ?? 'Hủy',
        onCancel: onCancel != null
            ? () {
                Navigator.of(ctx).pop();
                onCancel();
              }
            : () => Navigator.of(ctx).pop(),
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderXl,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxDialogWidth,
        ),
        child: Padding(
          padding: AppSpacing.dialogPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (message != null)
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium,
                ),
              ?content,
              const SizedBox(height: AppSpacing.xxl),
              if (customActions != null)
                customActions!
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelText != null) ...[
                      HiButton(
                        text: cancelText!,
                        variant: HiButtonVariant.ghost,
                        size: HiButtonSize.md,
                        onPressed: onCancel ?? () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (confirmText != null)
                      HiButton(
                        text: confirmText!,
                        variant: isDestructive
                            ? HiButtonVariant.danger
                            : HiButtonVariant.primary,
                        size: HiButtonSize.md,
                        onPressed: onConfirm,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
