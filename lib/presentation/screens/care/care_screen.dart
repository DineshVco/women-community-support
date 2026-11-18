import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/helplines.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/encrypted_box.dart';
import '../../widgets/app_lock_gate.dart';
import '../../widgets/content_width.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../widgets/quick_exit_button.dart';
import '../help_screen.dart';
import '../me/app_lock_settings_screen.dart';
import '../me/safety_plan_screen.dart';
import 'breathe_screen.dart';
import 'ground_screen.dart';
import 'journal_screen.dart';
import 'mood_screen.dart';

/// Opens the journal. With App lock on, she confirms her PIN first.
Future<void> openJournal(BuildContext context) async {
  final lock = AppLockScope.maybeOf(context);
  if (lock != null && lock.enabled) {
    final ok = await confirmWithPin(context, lock);
    if (!ok || !context.mounted) return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const JournalScreen()));
}

/// The Care tab: calm tools that work offline, the help lines, and (soon)
/// the guides library. "Get help" now lives here.
class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  static const String intro =
      'Small tools for hard moments. What you write here stays on your phone.';

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const entrance = Entrance();
    // Private tools need safe storage, which browsers do not have.
    final private = EncryptedBox.supported;
    const side = EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal);

    return LargeTitleScaffold(
      title: 'Care',
      trailing: const QuickExitButton(),
      slivers: [
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: entrance.items([
                // ───────── Intro ─────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          intro,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const FloatingIllustration(
                        asset: LoomaCats.safe,
                        height: 84,
                        semanticLabel: 'Drawing of a cat holding a shield',
                      ),
                    ],
                  ),
                ),

                // ───────── 1. In danger ─────────
                const Padding(padding: side, child: EmergencyCard()),
                const SizedBox(height: AppSpacing.xl),

                // ───────── 2. Tools ─────────
                GroupedSection(
                  header: 'Tools',
                  children: [
                    GroupedRow(
                      icon: CupertinoIcons.wind,
                      title: 'Breathe',
                      subtitle: 'Slow breathing with the cat, 1 to 5 minutes',
                      onTap: () => _push(context, const BreatheScreen()),
                    ),
                    GroupedRow(
                      icon: CupertinoIcons.hand_raised,
                      title: 'Ground yourself',
                      subtitle: '5-4-3-2-1: come back to right now',
                      onTap: () => _push(context, const GroundScreen()),
                    ),
                    GroupedRow(
                      icon: CupertinoIcons.smiley,
                      title: 'How are you feeling',
                      subtitle:
                          private ? 'A private check-in' : EncryptedBox.webNote,
                      enabled: private,
                      onTap: () => _push(context, const MoodScreen()),
                    ),
                    GroupedRow(
                      icon: CupertinoIcons.book,
                      title: 'My journal',
                      subtitle:
                          private
                              ? 'Private notes, only on this phone'
                              : EncryptedBox.webNote,
                      enabled: private,
                      onTap: () => openJournal(context),
                    ),
                    GroupedRow(
                      icon: CupertinoIcons.shield,
                      title: 'Safety plan',
                      subtitle:
                          private
                              ? 'Contacts, a safe place, a code word'
                              : EncryptedBox.webNote,
                      enabled: private,
                      onTap: () => openSafetyPlan(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ───────── 3. Help lines ─────────
                for (final group in Helplines.groups) ...[
                  Padding(
                    padding: side,
                    child: HelplineGroupSection(group: group),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const Padding(padding: side, child: SafeWaysCard()),
                const SizedBox(height: AppSpacing.lg),
                const Padding(padding: side, child: QuickExitCard()),
                const SizedBox(height: AppSpacing.xl),

                // ───────── 4. Guides ─────────
                const GroupedSection(
                  header: 'Guides',
                  children: [
                    GroupedRow(
                      icon: CupertinoIcons.book_circle,
                      title: 'Guides library',
                      subtitle:
                          'Short, kind guides. Coming in the next update.',
                      enabled: false,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
