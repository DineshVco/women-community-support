import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/helplines.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/content_library.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../widgets/quick_exit_button.dart';
import '../help_screen.dart';

/// Loads the bundled library once per app run.
Future<ContentLibrary> _library() => _cached ??= ContentLibrary.load();
Future<ContentLibrary>? _cached;

/// The guides library: short, kind guides, offline. Search, category
/// pills, and a "Saved" filter for bookmarked guides.
class GuidesScreen extends StatefulWidget {
  const GuidesScreen({
    super.key,
    this.library,
    this.bookmarks,
    this.includeDrafts = kDebugMode,
  });

  /// For tests.
  final ContentLibrary? library;
  final GuideBookmarks? bookmarks;

  /// Drafts (unchecked guides) only show in debug builds.
  final bool includeDrafts;

  static const String noneYet =
      'The guides are being checked by the Looma team. Please come back soon.';

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  late final Future<ContentLibrary> _load =
      widget.library != null ? Future.value(widget.library!) : _library();
  late final GuideBookmarks _bookmarks =
      widget.bookmarks ?? context.read<GuideBookmarks>();

  String _query = '';

  /// null = all, 'saved' = bookmarks, otherwise a category id.
  String? _filter;
  Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    _bookmarks.load().then((ids) {
      if (mounted) setState(() => _saved = ids);
    });
  }

  Future<void> _open(Guide guide) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideDetailScreen(guide: guide, bookmarks: _bookmarks),
      ),
    );
    final ids = await _bookmarks.load();
    if (mounted) setState(() => _saved = ids);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'Guides',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: FutureBuilder<ContentLibrary>(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  illustration: LoomaCats.heart,
                  title: 'Could not open the guides',
                  message: 'Please try again in a moment.',
                );
              }
              final library = snapshot.data;
              if (library == null) {
                return const Center(child: CupertinoActivityIndicator());
              }

              final all = library.visibleGuides(
                includeDrafts: widget.includeDrafts,
              );
              final shown =
                  all.where((g) {
                    if (_filter == 'saved' && !_saved.contains(g.id)) {
                      return false;
                    }
                    if (_filter != null &&
                        _filter != 'saved' &&
                        g.category != _filter) {
                      return false;
                    }
                    return g.matches(_query);
                  }).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                    ),
                    child: CupertinoSearchTextField(
                      placeholder: 'Search guides',
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: palette.text),
                      backgroundColor: palette.softFill,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Row(
                      children: [
                        for (final (id, label) in [
                          (null, 'All'),
                          ('saved', 'Saved'),
                          for (final c in GuideCategories.all) (c.$1, c.$2),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            child: Pill(
                              label: label,
                              selected: _filter == id,
                              onTap: () => setState(() => _filter = id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (all.isEmpty)
                    const EmptyState(
                      illustration: LoomaCats.browse,
                      title: 'Guides are on their way',
                      message: GuidesScreen.noneYet,
                    )
                  else if (shown.isEmpty)
                    EmptyState(
                      illustration: LoomaCats.browse,
                      title:
                          _filter == 'saved'
                              ? 'Nothing saved yet'
                              : 'No guides found',
                      message:
                          _filter == 'saved'
                              ? 'Tap the bookmark on a guide to keep it here.'
                              : 'We could not find that. Try another word.',
                    )
                  else
                    GroupedSection(
                      children: [
                        for (final g in shown)
                          _GuideRow(
                            guide: g,
                            saved: _saved.contains(g.id),
                            onTap: () => _open(g),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.guide,
    required this.saved,
    required this.onTap,
  });

  final Guide guide;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final draft = !guide.publishable;
    return Semantics(
      button: true,
      label:
          '${guide.title}. ${guide.categoryLabel}, ${guide.readMinutes} '
          'minute read${saved ? ', saved' : ''}${draft ? ', draft' : ''}',
      excludeSemantics: true,
      child: CupertinoListTile.notched(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
        backgroundColor: palette.surface,
        backgroundColorActivated: palette.softFill,
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: guide.categoryColor,
            shape: BoxShape.circle,
          ),
        ),
        leadingSize: 12,
        title: Text(
          guide.title,
          maxLines: 3,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: palette.text,
          ),
        ),
        subtitle: Text(
          '${guide.categoryLabel} · ${guide.readMinutes} min read'
          '${draft ? ' · Draft' : ''}',
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saved)
              Icon(
                CupertinoIcons.bookmark_fill,
                size: 16,
                color: palette.textSecondary,
              ),
            const SizedBox(width: 4),
            const CupertinoListTileChevron(),
          ],
        ),
        onTap: () {
          AppHaptics.light();
          onTap();
        },
      ),
    );
  }
}

/// One guide: big title, short sections, the footer note. Safety guides
/// also show "In danger? Call 999". Unchecked guides (debug builds only)
/// carry a clear "Draft" banner and highlight anything marked [VERIFY].
class GuideDetailScreen extends StatefulWidget {
  const GuideDetailScreen({
    super.key,
    required this.guide,
    required this.bookmarks,
  });

  final Guide guide;
  final GuideBookmarks bookmarks;

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    widget.bookmarks.load().then((ids) {
      if (mounted) setState(() => _saved = ids.contains(widget.guide.id));
    });
  }

  Future<void> _toggle() async {
    AppHaptics.light();
    final ids = await widget.bookmarks.toggle(widget.guide.id);
    if (!mounted) return;
    setState(() => _saved = ids.contains(widget.guide.id));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final guide = widget.guide;

    return Scaffold(
      appBar: loomaNavBar(
        context,
        trailing: NavBarActions(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minSize: 44,
              onPressed: _toggle,
              child: Icon(
                _saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                color: palette.text,
                semanticLabel: _saved ? 'Remove bookmark' : 'Bookmark',
              ),
            ),
            const QuickExitButton(),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              if (!guide.publishable) const _DraftBanner(),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: guide.categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${guide.categoryLabel.toUpperCase()} · '
                    '${guide.readMinutes} MIN READ',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.8,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                guide.title,
                style: AppTypography.heading(32, palette.text, height: 1.15),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final s in guide.sections) ...[
                Text(s.heading, style: AppTypography.heading(21, palette.text)),
                const SizedBox(height: AppSpacing.sm),
                _SectionText(section: s),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (guide.aboutSafety) ...[
                const _CallCard(),
                const SizedBox(height: AppSpacing.xl),
              ],
              Divider(color: palette.border),
              const SizedBox(height: AppSpacing.md),
              Text(
                guideFooter,
                key: const ValueKey('guide-footer'),
                style: TextStyle(fontSize: 13, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  const _SectionText({required this.section});

  final GuideSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(fontSize: 17, height: 1.5, color: palette.text);
    if (!section.needsChecking) return Text(section.text, style: style);
    // Debug builds only: make the unchecked fact impossible to miss.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.softFill,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: palette.textSecondary),
      ),
      child: Text(
        section.text,
        style: style.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.softFill,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        'Draft, not checked yet. Only shown in test builds. Najwa: check '
        'every fact (especially [VERIFY] marks), then set verified to true.',
        style: TextStyle(fontSize: 13, color: palette.text),
      ),
    );
  }
}

/// "In danger? Call 999" on safety guides.
class _CallCard extends StatelessWidget {
  const _CallCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.blushTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'In danger? Call 999',
              style: AppTypography.heading(20, palette.text),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: const StadiumBorder(),
            ),
            onPressed: () => HelpScreen.call(context, Helplines.emergency),
            icon: const Icon(CupertinoIcons.phone, size: 18),
            label: const Text('Call 999'),
          ),
        ],
      ),
    );
  }
}
