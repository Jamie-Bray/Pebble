import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/data/repositories/theme_repository.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

/// The theme picker: three plain sections (free, Personal Premium, easier to
/// see), each theme shown as a small painted swatch rather than a mock app.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final currentThemeId = ref.watch(currentColorThemeProvider);
    final currentMeta = ThemeMetadata.get(currentThemeId);
    final canUsePremiumThemes = ref
        .watch(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
    final repository = ref.watch(themeRepositoryProvider);
    final free = repository.getMainPickerThemes(ThemePickerCategory.included);
    final premium = repository.getMainPickerThemes(ThemePickerCategory.premium);
    final morePremium = repository.getMoreOptionsThemes(
      ThemePickerCategory.premium,
    );
    final accessibility = ThemeMetadata.byCategory(
      ThemePickerCategory.accessibility,
    );

    void open(ThemeMetadata meta) => _openThemePreview(context, ref, meta);

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        bottom: false,
        child: AdaptiveContentWidth(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PebbleBackChrome(
                        padding: EdgeInsets.zero,
                        trailing: _InfoButton(
                          onTap: () => _showThemeInfoSheet(context),
                        ),
                        respectSafeArea: false,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Themes',
                        style: type.title1.copyWith(
                          color: foundation.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            const TextSpan(text: 'You’re using '),
                            TextSpan(
                              text: currentMeta.name,
                              style: TextStyle(
                                color: foundation.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: '. Tap any theme to try it first.',
                            ),
                          ],
                        ),
                        style: type.body.copyWith(
                          color: context.readableSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    const _SectionHeader(
                      title: 'Free for everyone',
                      subtitle: 'Use any of these, any time.',
                    ),
                    _ThemeGrid(
                      themes: free,
                      canUsePremiumThemes: canUsePremiumThemes,
                      currentThemeId: currentThemeId,
                      onThemeTap: open,
                    ),
                    _SectionHeader(
                      title: 'Personal Premium',
                      subtitle: canUsePremiumThemes
                          ? 'Included with your Personal Premium.'
                          : 'Try any of them first. Using one needs Personal Premium.',
                    ),
                    _ThemeGrid(
                      themes: premium,
                      canUsePremiumThemes: canUsePremiumThemes,
                      currentThemeId: currentThemeId,
                      onThemeTap: open,
                    ),
                    if (morePremium.isNotEmpty)
                      _MoreThemes(
                        themes: morePremium,
                        canUsePremiumThemes: canUsePremiumThemes,
                        currentThemeId: currentThemeId,
                        onThemeTap: open,
                      ),
                    const _SectionHeader(
                      title: 'Easier to see',
                      subtitle: 'Accessibility themes. Always free.',
                    ),
                    for (final meta in accessibility) ...<Widget>[
                      _AccessibilityThemeRow(
                        meta: meta,
                        isCurrent: meta.id == currentThemeId,
                        onTap: () => open(meta),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PebbleGlassIconButton(
      icon: LucideIcons.info,
      tooltip: 'About themes',
      onPressed: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: type.title2.copyWith(
                color: context.darkFoundation.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: type.caption.copyWith(color: context.readableSecondaryText),
          ),
        ],
      ),
    );
  }
}

/// Two columns of theme cards. Rows size to their content, so long names and
/// large text never clip.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.themes,
    required this.canUsePremiumThemes,
    required this.currentThemeId,
    required this.onThemeTap,
  });

  final List<ThemeMetadata> themes;
  final bool canUsePremiumThemes;
  final ThemeId currentThemeId;
  final ValueChanged<ThemeMetadata> onThemeTap;

  @override
  Widget build(BuildContext context) {
    Widget card(ThemeMetadata meta) => _ThemeCard(
      meta: meta,
      isCurrent: meta.id == currentThemeId,
      isLocked: _isLocked(meta, canUsePremiumThemes),
      onTap: () => onThemeTap(meta),
    );

    final rows = <Widget>[];
    for (var i = 0; i < themes.length; i += 2) {
      final hasPair = i + 1 < themes.length;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: card(themes[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: hasPair ? card(themes[i + 1]) : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.meta,
    required this.isCurrent,
    required this.isLocked,
    required this.onTap,
  });

  final ThemeMetadata meta;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final selected = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(20);

    return Semantics(
      button: true,
      selected: isCurrent,
      label: [
        meta.name,
        meta.subtitle,
        if (isCurrent) 'in use',
        if (isLocked) 'needs Personal Premium',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: foundation.surfaceLow,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isCurrent ? selected : foundation.borderSubtle,
                width: isCurrent ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ThemeSwatch(themeId: meta.id, height: 92, showLock: isLocked),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              meta.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.body.copyWith(
                                color: foundation.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCurrent ? 'In use' : meta.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.caption.copyWith(
                                color: isCurrent
                                    ? context.readableAccentText(selected)
                                    : context.readableSecondaryText,
                                fontWeight: isCurrent ? FontWeight.w700 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent) ...<Widget>[
                        const SizedBox(width: 6),
                        _CheckBadge(color: selected),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        LucideIcons.check,
        size: 13,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

/// A theme painted as a tiny scene in its own colours: the page, one card
/// with a checked pebble and two lines of "text", and the action button.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.themeId,
    required this.height,
    this.showLock = false,
    this.compact = false,
  });

  final ThemeId themeId;
  final double height;
  final bool showLock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromId(themeId);
    final f = theme.extension<PebbleDarkFoundation>()!;
    final x = theme.extension<PebbleThemeX>()!;
    final radius = BorderRadius.circular(compact ? 12 : 14);
    final pad = compact ? 8.0 : 12.0;

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        padding: EdgeInsets.all(pad),
        // A hairline keeps pale themes from melting into a pale page.
        decoration: BoxDecoration(
          color: f.bgBase,
          borderRadius: radius,
          border: Border.all(color: context.darkFoundation.borderSubtle),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: pad * 0.8),
                    decoration: BoxDecoration(
                      color: f.surfaceHigh,
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: compact ? 14 : 18,
                          height: compact ? 14 : 18,
                          decoration: BoxDecoration(
                            color: x.done,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.check,
                            size: compact ? 9 : 11,
                            color: f.bgBase,
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _Bar(color: f.textPrimary, widthFactor: 0.85),
                              SizedBox(height: compact ? 3 : 5),
                              _Bar(color: f.textSecondary, widthFactor: 0.55),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 14,
                    decoration: BoxDecoration(
                      color: x.actionAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ],
            ),
            if (showLock)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lock,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.widthFactor});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Older Premium themes, folded away so the main picker stays short.
class _MoreThemes extends StatefulWidget {
  const _MoreThemes({
    required this.themes,
    required this.canUsePremiumThemes,
    required this.currentThemeId,
    required this.onThemeTap,
  });

  final List<ThemeMetadata> themes;
  final bool canUsePremiumThemes;
  final ThemeId currentThemeId;
  final ValueChanged<ThemeMetadata> onThemeTap;

  @override
  State<_MoreThemes> createState() => _MoreThemesState();
}

class _MoreThemesState extends State<_MoreThemes> {
  // Open by default when the theme in use lives here, so it isn't hidden.
  late bool _open = widget.themes.any((t) => t.id == widget.currentThemeId);

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final count = widget.themes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              foregroundColor: foundation.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
            icon: Icon(
              _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 18,
            ),
            label: Text(
              _open ? 'Show fewer' : 'Show $count more Premium themes',
              style: type.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_open)
          _ThemeGrid(
            themes: widget.themes,
            canUsePremiumThemes: widget.canUsePremiumThemes,
            currentThemeId: widget.currentThemeId,
            onThemeTap: widget.onThemeTap,
          ),
      ],
    );
  }
}

class _AccessibilityThemeRow extends StatelessWidget {
  const _AccessibilityThemeRow({
    required this.meta,
    required this.isCurrent,
    required this.onTap,
  });

  final ThemeMetadata meta;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final selected = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      selected: isCurrent,
      label: [
        meta.name,
        meta.accessibilityNote ?? meta.subtitle,
        if (isCurrent) 'in use',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: foundation.surfaceLow,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isCurrent ? selected : foundation.borderSubtle,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 76,
                  child: _ThemeSwatch(
                    themeId: meta.id,
                    height: 56,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        meta.name,
                        style: type.body.copyWith(
                          color: foundation.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCurrent
                            ? 'In use'
                            : meta.accessibilityNote ?? meta.subtitle,
                        style: type.caption.copyWith(
                          color: isCurrent
                              ? context.readableAccentText(selected)
                              : context.readableSecondaryText,
                          fontWeight: isCurrent ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrent)
                  _CheckBadge(color: selected)
                else
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: foundation.textMuted,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill.active({required this.label}) : _isActive = true;
  const _StatePill.muted({required this.label}) : _isActive = false;

  final String label;
  final bool _isActive;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final foundation = context.darkFoundation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _isActive
            ? accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _isActive
              ? accent.withValues(alpha: 0.18)
              : foundation.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _isActive ? accent : context.readableSecondaryText,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniAppPreview extends StatelessWidget {
  const _MiniAppPreview({required this.themeData, required this.rows});

  final ThemeData themeData;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final scheme = themeData.colorScheme;
    final foundation = themeData.extension<PebbleDarkFoundation>()!;
    final templateTokens = themeData.extension<PebbleTemplatesTokens>()!;
    final rowData = <({String label, String count, Color color})>[
      (label: 'Leaving home', count: '5', color: scheme.primary),
      (
        label: 'Everyday departure',
        count: '10',
        color: templateTokens.templatesAccentGroup2,
      ),
      (
        label: 'Evening wind-down',
        count: '7',
        color: templateTokens.templatesAccentGroup3,
      ),
    ].take(rows).toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'pebble',
                      children: <InlineSpan>[
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: scheme.primary),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      height: 1,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Good morning',
              style: TextStyle(
                color: foundation.textSecondary,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (var index = 0; index < rowData.length; index += 1) ...<Widget>[
              _PreviewRow(
                label: rowData[index].label,
                count: rowData[index].count,
                color: rowData[index].color,
                foundation: foundation,
              ),
              if (index != rowData.length - 1) const SizedBox(height: 4),
            ],
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  <Color>[
                    scheme.primary,
                    templateTokens.templatesAccentGroup2,
                    templateTokens.templatesAccentGroup3,
                  ].asMap().entries.map((entry) {
                    final index = entry.key;
                    final color = entry.value;
                    return Container(
                      width: 16,
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? color
                            : color.withValues(alpha: index == 1 ? 0.6 : 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.count,
    required this.color,
    required this.foundation,
  });

  final String label;
  final String count;
  final Color color;
  final PebbleDarkFoundation foundation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          Container(width: 2.5, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foundation.textPrimary,
                fontSize: 7.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              color: foundation.textSecondary,
              fontSize: 7.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}

void _openThemePreview(
  BuildContext context,
  WidgetRef ref,
  ThemeMetadata meta,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThemePreviewSheet(meta: meta),
  );
}

class _ThemePreviewSheet extends ConsumerWidget {
  const _ThemePreviewSheet({required this.meta});

  final ThemeMetadata meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = Theme.of(context);
    final foundation = currentTheme.extension<PebbleDarkFoundation>()!;
    final canUsePremiumThemes = ref
        .watch(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
    final isLocked = _isLocked(meta, canUsePremiumThemes);
    final isCurrent = ref.watch(currentColorThemeProvider) == meta.id;
    final previewTheme = AppTheme.fromId(meta.id);
    final previewFoundation =
        previewTheme.extension<PebbleDarkFoundation>() ??
        PebbleDarkFoundation.fromPalette(
          bg: previewTheme.colorScheme.surface,
          fg: previewTheme.colorScheme.onSurface,
          accent: previewTheme.colorScheme.primary,
          isDark: previewTheme.brightness == Brightness.dark,
        );

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: foundation.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 230,
                        child: _MiniAppPreview(
                          themeData: previewTheme,
                          rows: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: previewTheme.colorScheme.primary.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            meta.icon,
                            size: 15,
                            color: previewTheme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                meta.name,
                                style: currentTheme.textTheme.headlineSmall
                                    ?.copyWith(
                                      color: foundation.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                meta.subtitle,
                                style: currentTheme.textTheme.bodySmall
                                    ?.copyWith(color: foundation.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const _StatePill.active(label: 'Active')
                        else if (meta.isAccessibilityTheme)
                          const _StatePill.muted(label: 'Accessibility')
                        else if (isLocked)
                          const _StatePill.muted(label: 'Premium'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      meta.description,
                      style: currentTheme.textTheme.bodyMedium?.copyWith(
                        color: foundation.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    if (isLocked) ...<Widget>[
                      const SizedBox(height: 14),
                      const _SheetNote(
                        text:
                            'You can preview this theme. Using it needs Personal Premium.',
                      ),
                    ],
                    if (meta.accessibilityNote != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _SheetNote(text: meta.accessibilityNote!),
                    ],
                    if (_isCompatibilityPremiumTheme(meta)) ...<Widget>[
                      const SizedBox(height: 14),
                      const _SheetNote(
                        text:
                            'An older theme, kept for people who already use it.',
                      ),
                    ],
                    const SizedBox(height: 18),
                    _PreviewPaletteBar(
                      foundation: previewFoundation,
                      theme: previewTheme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: previewTheme.colorScheme.primary,
                    foregroundColor: previewTheme.colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isCurrent
                      ? null
                      : () async {
                          if (isLocked) {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            unawaited(
                              router.push(
                                premiumRoute(
                                  source: PremiumEntrySource.premiumTheme,
                                ),
                              ),
                            );
                            return;
                          }
                          await ref
                              .read(themeProvider.notifier)
                              .setColorTheme(meta.id);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: Text(
                    isCurrent
                        ? 'Currently active'
                        : isLocked
                        ? 'Get Premium'
                        : 'Use this theme',
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foundation.textSecondary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _PreviewPaletteBar extends StatelessWidget {
  const _PreviewPaletteBar({required this.foundation, required this.theme});

  final PebbleDarkFoundation foundation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = _railColors(theme);
    return Row(
      children: colors.take(4).map((color) {
        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: foundation.borderSubtle.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

void _showThemeInfoSheet(BuildContext context) {
  final foundation = context.darkFoundation;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: foundation.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Preview first',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foundation.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing changes until you tap Use this theme. Accessibility themes are always free, and you can preview Premium themes before you buy.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foundation.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _isLocked(ThemeMetadata meta, bool canUsePremiumThemes) {
  return meta.isPremium && !canUsePremiumThemes;
}

bool _isCompatibilityPremiumTheme(ThemeMetadata meta) {
  final subtitle = meta.subtitle.toLowerCase();
  final description = meta.description.toLowerCase();
  return subtitle.contains('legacy') ||
      subtitle.contains('archived') ||
      description.contains('compatibility') ||
      description.contains('older');
}

List<Color> _railColors(ThemeData themeData) {
  final scheme = themeData.colorScheme;
  final colors = <Color>[
    scheme.surface,
    scheme.onSurface,
    scheme.primary,
    scheme.secondary,
  ];
  if (scheme.error != const Color(0xFFB3261E) &&
      scheme.error != const Color(0xFFFFB4AB)) {
    colors.add(scheme.error);
  }
  return colors;
}
