import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/haptics.dart';
import '../../data/content_library.dart';
import 'adaptive.dart';

/// Call, message and copy, shared by the Care help lines, Get help and the
/// Directory. On a device that cannot call or message (emulator, laptop),
/// the number is copied instead.
class ContactActions {
  ContactActions._();

  static Future<void> call(BuildContext context, String number) async {
    AppHaptics.medium();
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!opened && context.mounted) await copy(context, number);
  }

  static Future<void> copy(BuildContext context, String number) async {
    AppHaptics.light();
    await Clipboard.setData(ClipboardData(text: number));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied $number')));
  }

  /// SMS or WhatsApp: her choice when the entry has both.
  static Future<void> message(
    BuildContext context,
    DirectoryEntry entry,
  ) async {
    AppHaptics.light();
    String? choice;
    if (entry.sms != null && entry.whatsapp != null) {
      choice = await showOptionsSheet<String>(
        context,
        title: 'Message ${entry.name}',
        options: const [
          SheetOption(value: 'sms', label: 'Text message (SMS)'),
          SheetOption(value: 'whatsapp', label: 'WhatsApp'),
        ],
      );
      if (choice == null) return;
    } else if (entry.sms != null) {
      choice = 'sms';
    } else if (entry.whatsapp != null) {
      choice = 'whatsapp';
    } else {
      return;
    }
    final number = choice == 'sms' ? entry.sms! : entry.whatsapp!;
    final uri =
        choice == 'sms'
            ? Uri(scheme: 'sms', path: number.replaceAll(' ', ''))
            : Uri.https('wa.me', '/${DirectoryEntry.whatsappDigits(number)}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) await copy(context, number);
  }
}
