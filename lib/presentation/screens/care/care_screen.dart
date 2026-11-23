import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/encrypted_box.dart';
import '../../../data/models/category.dart';
import '../../widgets/app_lock_gate.dart';
import '../../widgets/content_width.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/ios.dart';
import '../../widgets/quick_exit_button.dart';
import '../create_post_screen.dart';
import '../help_screen.dart';
import '../me/app_lock_settings_screen.dart';
import '../me/safety_plan_screen.dart';
import 'breathe_screen.dart';
import 'directory_screen.dart';
import 'ground_screen.dart';
import 'guides_screen.dart';
import 'journal_screen.dart';
import 'mood_screen.dart';
import '../../../core/theme/app_icons.dart';

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

/// The Care tab: calm tools that work offline, the help lines, the guides
/// library and the directory. "Get help" now lives here.
class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  static const String heroTitle = 'A calm corner for you';

  static const String intro =
      'Small tools for hard moments. What you write here stays on your phone.';

  /// Opens compose in the "Ask Looma Team" category.
  Future<void> _askLooma(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final alias = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder:
            (_) => const CreatePostScreen(
              initialCategoryId: AppCategories.askLoomaId,
            ),
      ),
    );
    if (alias == null) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Your question is in Discuss. The team will answer as Looma Team.',
        ),
      ),
    );
  }

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
                  child: HeroCard(
                    scene: HeroScene.flowers,
                    actionLabel: 'Breathe with the cat',
                    onTap: () => _push(context, const BreatheScreen()),
                    children: [
                      Text(
                        heroTitle,
                        style: AppTypography.heading(24, palette.text),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        intro,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: palette.text,
                        ),
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
                      icon: AppIcons.breathe,
                      title: 'Breathe',
                      subtitle: 'Slow breathing with the cat, 1 to 5 minutes',
                      onTap: () => _push(context, const BreatheScreen()),
                    ),
                    GroupedRow(
                      icon: AppIcons.ground,
                      title: 'Ground yourself',
                      subtitle: '5-4-3-2-1: come back to right now',
                      onTap: () => _push(context, const GroundScreen()),
                    ),
                    GroupedRow(
                      icon: AppIcons.mood,
                      title: 'How are you feeling',
                      subtitle:
                          private ? 'A private check-in' : EncryptedBox.webNote,
                      enabled: private,
                      onTap: () => _push(context, const MoodScreen()),
                    ),
                    GroupedRow(
                      icon: AppIcons.book,
                      title: 'My journal',
                      subtitle:
                          private
                              ? 'Private notes, only on this phone'
                              : EncryptedBox.webNote,
                      enabled: private,
                      onTap: () => openJournal(context),
                    ),
                    GroupedRow(
                      icon: AppIcons.safety,
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
                // From content/directory.json (same as Get help).
                const Padding(padding: side, child: HelpLineGroupsView()),
                const Padding(padding: side, child: SafeWaysCard()),
                const SizedBox(height: AppSpacing.lg),
                const Padding(padding: side, child: QuickExitCard()),
                const SizedBox(height: AppSpacing.xl),

                // ───────── 4. Guides ─────────
                GroupedSection(
                  header: 'Guides',
                  children: [
                    GroupedRow(
                      icon: AppIcons.guides,
                      title: 'Guides library',
                      subtitle: 'Short, kind guides you can read offline',
                      onTap: () => _push(context, const GuidesScreen()),
                    ),
                    GroupedRow(
                      icon: AppIcons.directory,
                      title: 'Directory',
                      subtitle: 'Organisations and help lines',
                      onTap: () => _push(context, const DirectoryScreen()),
                    ),
                    GroupedRow(
                      icon: AppIcons.askTeam,
                      title: 'Ask Looma Team',
                      subtitle:
                          'A question for the team, answered as Looma Team',
                      onTap: () => _askLooma(context),
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
