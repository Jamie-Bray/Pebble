import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/data/repositories/theme_repository.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

/// Themes and colours: a swipeable gallery of Home painted in each theme,
/// with every theme also shown as a small pebble to jump to. Looking is free
/// and instant; nothing changes until the button at the bottom is pressed.
class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  // Built once: ThemeData for every theme is needed by both the gallery and
  // the pebbles, and building it per frame would be wasteful.
  final Map<ThemeId, ThemeData> _themes = {
    for (final id in ThemeId.values) id: AppTheme.fromId(id),
  };

  late final _ThemeGroups _groups;
  late final PageController _pages;
  final ScrollController _scroll = ScrollController();
  late ThemeId _previewId;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(themeRepositoryProvider);
    _groups = _ThemeGroups(
      free: repository.getMainPickerThemes(ThemePickerCategory.included),
      premium: repository.getMainPickerThemes(ThemePickerCategory.premium),
      older: repository.getMoreOptionsThemes(ThemePickerCategory.premium),
      accessibility: ThemeMetadata.byCategory(
        ThemePickerCategory.accessibility,
      ),
    );
    _previewId = ref.read(currentColorThemeProvider);
    final start = _groups.all.indexWhere((t) => t.id == _previewId);
    _pages = PageController(
      viewportFraction: 0.56,
      initialPage: math.max(0, start),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showTheme(ThemeId id, {bool bringIntoView = false}) {
    final index = _groups.all.indexWhere((t) => t.id == id);
    if (index < 0) return;
    setState(() => _previewId = id);
    final instant = MediaQuery.disableAnimationsOf(context);
    if (instant) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: PebbleMotion.emphasized,
        curve: Curves.easeOutCubic,
      );
    }
    // A pebble tapped further down the page would change a preview that is
    // out of sight, so bring the gallery back up to show it.
    if (bringIntoView && _scroll.hasClients && _scroll.offset > 0) {
      if (instant) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: PebbleMotion.emphasized,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _showFromPebble(ThemeId id) => _showTheme(id, bringIntoView: true);

  Future<void> _choose(ThemeMetadata meta, {required bool locked}) async {
    if (locked) {
      unawaited(
        context.push(premiumRoute(source: PremiumEntrySource.premiumTheme)),
      );
      return;
    }
    await ref.read(themeProvider.notifier).setColorTheme(meta.id);
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final currentId = ref.watch(currentColorThemeProvider);
    final canUsePremium = ref
        .watch(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
    final preview = ThemeMetadata.get(_previewId);
    final previewLocked = _isLocked(preview, canUsePremium);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        bottom: false,
        child: AdaptiveContentWidth(
          child: Stack(
            children: <Widget>[
              CustomScrollView(
                key: const ValueKey('appearance_scroll'),
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const PebbleBackChrome(
                            padding: EdgeInsets.zero,
                            respectSafeArea: false,
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            header: true,
                            child: Text(
                              'Themes and colours',
                              style: type.title1.copyWith(
                                color: foundation.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Swipe to look around. Nothing changes until you choose.',
                            style: type.body.copyWith(
                              color: context.readableSecondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Gallery(
                      controller: _pages,
                      themes: _groups.all,
                      themeData: _themes,
                      previewId: _previewId,
                      onPageChanged: (index) =>
                          setState(() => _previewId = _groups.all[index].id),
                      onCardTap: _showTheme,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _PreviewCaption(
                        meta: preview,
                        isDark:
                            _themes[preview.id]!.brightness == Brightness.dark,
                        isLocked: previewLocked,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 140 + bottomInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(<Widget>[
                        _PebbleShelf(
                          title: 'Free',
                          themes: _groups.free,
                          themeData: _themes,
                          previewId: _previewId,
                          currentId: currentId,
                          canUsePremium: canUsePremium,
                          onTap: _showFromPebble,
                        ),
                        _PebbleShelf(
                          title: 'Personal Premium',
                          trailing: canUsePremium ? 'Included' : null,
                          themes: _groups.premium,
                          themeData: _themes,
                          previewId: _previewId,
                          currentId: currentId,
                          canUsePremium: canUsePremium,
                          onTap: _showFromPebble,
                        ),
                        if (_groups.older.isNotEmpty)
                          _PebbleShelf(
                            title: 'Older Premium themes',
                            themes: _groups.older,
                            themeData: _themes,
                            previewId: _previewId,
                            currentId: currentId,
                            canUsePremium: canUsePremium,
                            onTap: _showFromPebble,
                          ),
                        _PebbleShelf(
                          title: 'Easier to see',
                          trailing: 'Always free',
                          themes: _groups.accessibility,
                          themeData: _themes,
                          previewId: _previewId,
                          currentId: currentId,
                          canUsePremium: canUsePremium,
                          onTap: _showFromPebble,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ChooseBar(
                  meta: preview,
                  previewTheme: _themes[preview.id]!,
                  isCurrent: preview.id == currentId,
                  isLocked: previewLocked,
                  onChoose: () => _choose(preview, locked: previewLocked),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeGroups {
  _ThemeGroups({
    required this.free,
    required this.premium,
    required this.older,
    required this.accessibility,
  });

  final List<ThemeMetadata> free;
  final List<ThemeMetadata> premium;
  final List<ThemeMetadata> older;
  final List<ThemeMetadata> accessibility;

  /// Gallery order: the same order as the pebbles below it.
  late final List<ThemeMetadata> all = <ThemeMetadata>[
    ...free,
    ...premium,
    ...older,
    ...accessibility,
  ];
}

// ---------------------------------------------------------------------------
// Gallery
// ---------------------------------------------------------------------------

/// The size Home is laid out at before being scaled into a gallery card, so
/// the preview keeps the real proportions of the screen.
const Size _homeCanvas = Size(330, 600);

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.controller,
    required this.themes,
    required this.themeData,
    required this.previewId,
    required this.onPageChanged,
    required this.onCardTap,
  });

  final PageController controller;
  final List<ThemeMetadata> themes;
  final Map<ThemeId, ThemeData> themeData;
  final ThemeId previewId;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ThemeId> onCardTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth * 0.56, 230.0);
        final cardHeight = cardWidth * _homeCanvas.height / _homeCanvas.width;
        return SizedBox(
          height: cardHeight + 36,
          child: PageView.builder(
            key: const ValueKey('appearance_gallery'),
            controller: controller,
            itemCount: themes.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final meta = themes[index];
              return Center(
                child: _GalleryCard(
                  meta: meta,
                  theme: themeData[meta.id]!,
                  width: cardWidth - 16,
                  height:
                      cardHeight - 16 * _homeCanvas.height / _homeCanvas.width,
                  isShown: meta.id == previewId,
                  onTap: () => onCardTap(meta.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.meta,
    required this.theme,
    required this.width,
    required this.height,
    required this.isShown,
    required this.onTap,
  });

  final ThemeMetadata meta;
  final ThemeData theme;
  final double width;
  final double height;
  final bool isShown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final radius = BorderRadius.circular(26);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: isShown,
      label: '${meta.name} preview',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: isShown ? 1 : 0.92,
        duration: reduceMotion ? Duration.zero : PebbleMotion.standard,
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : PebbleMotion.standard,
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isShown
                    ? foundation.textPrimary
                    : foundation.borderSubtle,
                width: isShown ? 2 : 1,
              ),
              boxShadow: isShown
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                child: SizedBox.fromSize(
                  size: _homeCanvas,
                  child: Theme(
                    data: theme,
                    // The preview always draws at normal text size: it is a
                    // picture of Home, scaled down, not something to read.
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: _HomePreview(
                        isAccessibility: meta.isAccessibilityTheme,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A still picture of Home as it looks now (Up next card, then Your
/// routines), drawn in whatever theme surrounds it.
class _HomePreview extends StatelessWidget {
  const _HomePreview({required this.isAccessibility});

  /// Accessibility themes ignore routine colours, as on the real Home.
  final bool isAccessibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = context.darkFoundation;
    final x = theme.extension<PebbleThemeX>()!;
    final isDark = theme.brightness == Brightness.dark;
    final secondary = context.readableSecondaryText;
    final accentText = context.readableAccentText(scheme.primary);
    final secondRoutine = isAccessibility
        ? scheme.primary
        : RoutinePalette.stones[1].forBrightness(theme.brightness);
    final cardFill = isDark
        ? f.surfaceLow
        : Color.alphaBlend(f.textPrimary.withValues(alpha: 0.045), f.bgBase);
    final sans = PebbleFonts.sans(fontSize: 13, color: f.textPrimary);

    Widget roundButton(IconData icon) => Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: f.borderSubtle),
      ),
      child: Icon(icon, size: 17, color: f.textPrimary),
    );

    Widget stone(Color color, IconData icon) => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: isDark ? f.bgBase : Colors.white),
    );

    Widget step(int n, String label, {bool first = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: f.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text('$n', style: sans.copyWith(color: secondary)),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sans.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: f.bgBase,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: 'pebble'),
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ],
                      ),
                      style: PebbleFonts.serif(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        height: 1,
                        color: f.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    roundButton(LucideIcons.settings),
                    const SizedBox(width: 6),
                    roundButton(LucideIcons.user),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: cardFill,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          stone(scheme.primary, LucideIcons.house),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'UP NEXT',
                              style: PebbleFonts.sans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                                color: accentText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: f.borderSubtle),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  LucideIcons.slidersHorizontal,
                                  size: 12,
                                  color: f.textPrimary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Settings',
                                  style: sans.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            const TextSpan(text: 'Leaving the house'),
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: scheme.primary),
                            ),
                          ],
                        ),
                        style: PebbleFonts.serif(
                          fontSize: 28,
                          height: 1.06,
                          letterSpacing: -0.5,
                          color: f.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '5 steps · 1 photo',
                        style: sans.copyWith(fontSize: 12, color: secondary),
                      ),
                      const SizedBox(height: 8),
                      step(1, 'Keys and wallet', first: true),
                      step(2, 'Back door locked'),
                      step(3, 'Hob off'),
                      const SizedBox(height: 10),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              LucideIcons.play,
                              size: 16,
                              color: scheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Start',
                              style: PebbleFonts.sans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Last checked yesterday, 8:15 AM',
                          style: sans.copyWith(fontSize: 11, color: secondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Your routines',
                        style: PebbleFonts.serif(
                          fontSize: 21,
                          color: f.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '1 checked today',
                      style: sans.copyWith(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    stone(secondRoutine, LucideIcons.moon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Wind down', style: sans.copyWith(fontSize: 14)),
                          Text(
                            '4 steps',
                            style: sans.copyWith(
                              fontSize: 11,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.check, size: 13, color: x.done),
                    const SizedBox(width: 4),
                    Text(
                      '9:12 PM',
                      style: sans.copyWith(fontSize: 12, color: x.done),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: isDark ? f.surfaceLow : f.surfaceHigh,
                border: Border(top: BorderSide(color: f.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Icon(LucideIcons.house, size: 18, color: f.textPrimary),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: x.actionAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 20,
                      color: x.onActionAccent,
                    ),
                  ),
                  Icon(LucideIcons.history, size: 18, color: secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Name, description and light or dark for the theme in the middle of the
/// gallery.
class _PreviewCaption extends StatelessWidget {
  const _PreviewCaption({
    required this.meta,
    required this.isDark,
    required this.isLocked,
  });

  final ThemeMetadata meta;
  final bool isDark;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;
    final note = <String>[
      if (isLocked) 'Personal Premium',
      if (meta.isAccessibilityTheme) 'Always free',
    ].join(' · ');
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : PebbleMotion.quick,
        child: Row(
          key: ValueKey(meta.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    meta.name,
                    style: PebbleFonts.serif(
                      fontSize: 26,
                      height: 1.1,
                      color: foundation.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.accessibilityNote ?? meta.description,
                    style: type.caption.copyWith(color: secondary),
                  ),
                  if (note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: type.caption.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: foundation.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isDark ? LucideIcons.moon : LucideIcons.sun,
                    size: 13,
                    color: secondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isDark ? 'Dark' : 'Light',
                    style: type.caption.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pebbles
// ---------------------------------------------------------------------------

class _PebbleShelf extends StatelessWidget {
  const _PebbleShelf({
    required this.title,
    required this.themes,
    required this.themeData,
    required this.previewId,
    required this.currentId,
    required this.canUsePremium,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final List<ThemeMetadata> themes;
  final Map<ThemeId, ThemeData> themeData;
  final ThemeId previewId;
  final ThemeId currentId;
  final bool canUsePremium;
  final ValueChanged<ThemeId> onTap;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    style: type.overline.copyWith(color: secondary),
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: type.caption.copyWith(color: secondary)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth >= 520 ? 6 : 4;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 14,
                children: <Widget>[
                  for (final meta in themes)
                    SizedBox(
                      width: itemWidth,
                      child: _PebbleChoice(
                        meta: meta,
                        theme: themeData[meta.id]!,
                        isShown: meta.id == previewId,
                        isCurrent: meta.id == currentId,
                        isLocked: _isLocked(meta, canUsePremium),
                        onTap: () => onTap(meta.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PebbleChoice extends StatelessWidget {
  const _PebbleChoice({
    required this.meta,
    required this.theme,
    required this.isShown,
    required this.isCurrent,
    required this.isLocked,
    required this.onTap,
  });

  final ThemeMetadata meta;
  final ThemeData theme;
  final bool isShown;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final f = theme.extension<PebbleDarkFoundation>()!;
    final x = theme.extension<PebbleThemeX>()!;
    return Semantics(
      button: true,
      selected: isShown,
      label: <String>[
        meta.name,
        meta.subtitle,
        if (isCurrent) 'in use',
        if (isLocked) 'Personal Premium',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('theme_pebble_${meta.id.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              SizedBox(
                width: 62,
                height: 56,
                child: CustomPaint(
                  painter: _PebblePainter(
                    page: f.bgBase,
                    accent: x.actionAccent,
                    ink: f.textPrimary,
                    lockBadge: foundation.textPrimary,
                    lockGlyph: foundation.bgBase,
                    ring: isShown ? foundation.textPrimary : null,
                    lock: isLocked,
                    hairline: foundation.borderSubtle,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: type.caption.copyWith(
                  color: foundation.textPrimary,
                  fontWeight: isShown ? FontWeight.w600 : FontWeight.w400,
                  height: 1.2,
                ),
              ),
              if (isCurrent)
                Text(
                  'In use',
                  style: type.caption.copyWith(
                    fontSize: 11,
                    color: context.readableAccentText(
                      Theme.of(context).colorScheme.primary,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A theme as a pebble: the page colour is the stone, with its accent and
/// text colours as two small stones resting on it.
class _PebblePainter extends CustomPainter {
  _PebblePainter({
    required this.page,
    required this.accent,
    required this.ink,
    required this.lockBadge,
    required this.lockGlyph,
    required this.ring,
    required this.lock,
    required this.hairline,
  });

  final Color page;
  final Color accent;
  final Color ink;
  final Color lockBadge;
  final Color lockGlyph;
  final Color? ring;
  final bool lock;
  final Color hairline;

  Path _pebble(Rect r) {
    final w = r.width;
    final h = r.height;
    return Path()
      ..moveTo(r.left + w * 0.5, r.top)
      ..cubicTo(
        r.left + w * 0.82,
        r.top,
        r.right,
        r.top + h * 0.2,
        r.right,
        r.top + h * 0.5,
      )
      ..cubicTo(
        r.right,
        r.top + h * 0.85,
        r.left + w * 0.78,
        r.bottom,
        r.left + w * 0.48,
        r.bottom,
      )
      ..cubicTo(
        r.left + w * 0.16,
        r.bottom,
        r.left,
        r.top + h * 0.8,
        r.left,
        r.top + h * 0.48,
      )
      ..cubicTo(
        r.left,
        r.top + h * 0.18,
        r.left + w * 0.22,
        r.top,
        r.left + w * 0.5,
        r.top,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final body = outer.deflate(3.5);
    if (ring != null) {
      canvas.drawPath(
        _pebble(outer.deflate(1)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = ring!,
      );
    }
    final shape = _pebble(body);
    canvas.drawPath(shape, Paint()..color = page);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hairline,
    );

    void stone(Offset centre, Size s, double turn, Color color) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(turn);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s.width, height: s.height),
        Paint()..color = color,
      );
      canvas.restore();
    }

    final w = size.width;
    final h = size.height;
    stone(Offset(w * 0.40, h * 0.55), Size(w * 0.37, h * 0.34), -0.2, accent);
    stone(Offset(w * 0.65, h * 0.44), Size(w * 0.23, h * 0.21), 0.24, ink);

    if (lock) {
      final c = Offset(w * 0.82, h * 0.82);
      final badge = lockBadge;
      final glyph = lockGlyph;
      // A ring in the page colour keeps the badge apart from any pebble.
      canvas.drawCircle(c, 10, Paint()..color = glyph);
      canvas.drawCircle(c, 8.5, Paint()..color = badge);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, 1.2), width: 7, height: 5.4),
          const Radius.circular(1.2),
        ),
        Paint()..color = glyph,
      );
      canvas.drawArc(
        Rect.fromCenter(center: c.translate(0, -1.6), width: 4.4, height: 4.4),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = glyph,
      );
    }
  }

  @override
  bool shouldRepaint(_PebblePainter old) =>
      old.page != page ||
      old.accent != accent ||
      old.ink != ink ||
      old.ring != ring ||
      old.lock != lock ||
      old.lockBadge != lockBadge ||
      old.hairline != hairline;
}

// ---------------------------------------------------------------------------
// Choose
// ---------------------------------------------------------------------------

class _ChooseBar extends StatelessWidget {
  const _ChooseBar({
    required this.meta,
    required this.previewTheme,
    required this.isCurrent,
    required this.isLocked,
    required this.onChoose,
  });

  final ThemeMetadata meta;
  final ThemeData previewTheme;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final x = previewTheme.extension<PebbleThemeX>()!;
    final buttonText = PebbleFonts.sans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    final Widget button;
    if (isCurrent) {
      button = OutlinedButton(
        key: const ValueKey('appearance_choose'),
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          side: BorderSide(color: foundation.borderSubtle),
          // Solid, so the list scrolling underneath never shows through.
          disabledBackgroundColor: foundation.bgBase,
          disabledForegroundColor: context.readableSecondaryText,
          textStyle: buttonText,
        ),
        child: Text('${meta.name} is on'),
      );
    } else if (isLocked) {
      button = FilledButton(
        key: const ValueKey('appearance_choose'),
        onPressed: onChoose,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          backgroundColor: foundation.textPrimary,
          foregroundColor: foundation.bgBase,
          textStyle: buttonText,
        ),
        child: const Text('See Personal Premium'),
      );
    } else {
      button = FilledButton(
        key: const ValueKey('appearance_choose'),
        onPressed: onChoose,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          // The button wears the theme it will apply.
          backgroundColor: x.actionAccent,
          foregroundColor: x.onActionAccent,
          textStyle: buttonText,
        ),
        child: Text('Use ${meta.name}'),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const <double>[0, 0.72, 1],
          colors: <Color>[
            foundation.bgBase,
            foundation.bgBase,
            foundation.bgBase.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            button,
            if (isLocked && !isCurrent) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${meta.name} comes with Personal Premium. Looking is free.',
                textAlign: TextAlign.center,
                style: type.caption.copyWith(
                  color: context.readableSecondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isLocked(ThemeMetadata meta, bool canUsePremiumThemes) {
  return meta.isPremium && !canUsePremiumThemes;
}
