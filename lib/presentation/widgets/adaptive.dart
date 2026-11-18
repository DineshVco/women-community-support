import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';

// Dialogs and action sheets in the iOS style on every platform (Looma's
// look is iOS-like everywhere). Destructive actions are red.

/// Blur behind action sheets and alerts.
final ImageFilter _blur = ImageFilter.blur(sigmaX: 8, sigmaY: 8);

/// Kept for older callers: Looma now uses the iOS style everywhere.
bool useCupertino(BuildContext context) => true;

/// "Are you sure?" alert. Returns true only when the person confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  if (destructive) AppHaptics.warning();

  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
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
  return result ?? false;
}

/// An iOS alert with one text field (e.g. a password or a city).
/// Returns the text, or null when cancelled.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String placeholder = '',
  String confirmLabel = 'Save',
  bool obscure = false,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showCupertinoDialog<String>(
    context: context,
    builder:
        (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(message),
                ),
              const SizedBox(height: AppSpacing.md),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                placeholder: placeholder,
                onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(confirmLabel),
            ),
          ],
        ),
  );
  controller.dispose();
  return result;
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

/// An iOS action sheet from the bottom of the screen, over a blurred
/// backdrop. Returns the chosen value, or null if dismissed.
Future<T?> showOptionsSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetOption<T>> options,
  String cancelLabel = 'Cancel',
}) {
  final palette = context.palette;
  return showCupertinoModalPopup<T>(
    context: context,
    filter: _blur,
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
                child: Text(
                  option.label,
                  style:
                      option.isDestructive
                          ? null
                          : TextStyle(color: palette.text),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelLabel, style: TextStyle(color: palette.text)),
          ),
        ),
  );
}
