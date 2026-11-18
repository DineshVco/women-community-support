import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// True on iPhone, iPad and Mac, where Cupertino dialogs and sheets are
/// what people expect.
bool useCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// "Are you sure?" dialog. Cupertino alert on Apple devices, Material
/// elsewhere. Returns true only when the person confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  if (destructive) AppHaptics.warning();

  final bool? result;
  if (useCupertino(context)) {
    result = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  } else {
    result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style:
                    destructive
                        ? TextButton.styleFrom(
                          foregroundColor: dialogContext.palette.danger,
                        )
                        : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }
  return result ?? false;
}

/// One choice in [showOptionsSheet].
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final bool isDefault;
  final bool isDestructive;
}

/// A list of choices from the bottom of the screen: a Cupertino action sheet
/// on Apple devices, a Material bottom sheet elsewhere. Returns the chosen
/// value, or null if dismissed.
Future<T?> showOptionsSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetOption<T>> options,
  String cancelLabel = 'Cancel',
}) {
  if (useCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            title: Text(title),
            message: message == null ? null : Text(message),
            actions: [
              for (final option in options)
                CupertinoActionSheetAction(
                  isDefaultAction: option.isDefault,
                  isDestructiveAction: option.isDestructive,
                  onPressed: () {
                    AppHaptics.selection();
                    Navigator.of(sheetContext).pop(option.value);
                  },
                  child: Text(option.label),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(cancelLabel),
            ),
          ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final palette = sheetContext.palette;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: option.isDestructive ? palette.danger : null,
                      fontWeight: option.isDefault ? FontWeight.w700 : null,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetContext).pop(option.value);
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(cancelLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
