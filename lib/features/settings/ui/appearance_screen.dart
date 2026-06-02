import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final currentThemeId = ref.watch(currentColorThemeProvider);
    final currentMeta = ThemeMetadata.get(currentThemeId);
    final canUsePremiumThemes = ref
        .watch(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
    final included = ThemeMetadata.byCategory(ThemePickerCategory.included);
    final accessibility = ThemeMetadata.byCategory(
      ThemePickerCategory.accessibility,
    );
    final premium = ThemeMetadata.byCategory(ThemePickerCategory.premium);

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              foundation.bgBase,
              foundation.surfaceLow.withValues(alpha: 0.35),
              foundation.bgBase,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: foundation.textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a look that works for you.\nPreview first, then apply.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foundation.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ActiveThemeBar(
                        meta: currentMeta,
                        onTap: () =>
                            _openThemePreview(context, ref, currentMeta),
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
                  36 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    const _SectionHeader(title: 'Included'),
                    const SizedBox(height: 12),
                    _ThemeGrid(
                      themes: included,
                      canUsePremiumThemes: canUsePremiumThemes,
                      currentThemeId: currentThemeId,
                      onThemeTap: (meta) =>
                          _openThemePreview(context, ref, meta),
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeader(
                      title: 'Accessibility',
                      tag: 'Always free',
                    ),
                    const SizedBox(height: 12),
                    _ThemeGrid(
                      themes: accessibility,
                      canUsePremiumThemes: canUsePremiumThemes,
                      currentThemeId: currentThemeId,
                      onThemeTap: (meta) =>
                          _openThemePreview(context, ref, meta),
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeader(title: 'Premium'),
                    const SizedBox(height: 12),
                    _PremiumCarousel(
                      themes: premium,
                      canUsePremiumThemes: canUsePremiumThemes,
                      currentThemeId: currentThemeId,
                      onThemeTap: (meta) =>
                          _openThemePreview(context, ref, meta),
                    ),
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
    final foundation = context.darkFoundation;
    return Material(
      color: foundation.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Icon(
            LucideIcons.info,
            size: 16,
            color: foundation.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActiveThemeBar extends StatelessWidget {
  const _ActiveThemeBar({required this.meta, required this.onTap});

  final ThemeMetadata meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final themeData = AppTheme.fromId(meta.id);
    final scheme = themeData.colorScheme;
    final colors = _railColors(themeData).take(3).toList();

    return Material(
      color: foundation.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: foundation.borderSubtle.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: colors.map((color) {
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CURRENT THEME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: foundation.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      meta.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: foundation.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.tag});

  final String title;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Row(
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foundation.textMuted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: foundation.borderSubtle.withValues(alpha: 0.65),
          ),
        ),
        if (tag != null) ...<Widget>[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9A6E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6B9A6E).withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              tag!,
              style: const TextStyle(
                color: Color(0xFF6B9A6E),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: themes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) {
        final meta = themes[index];
        return _ThemeGridCard(
          meta: meta,
          isCurrent: meta.id == currentThemeId,
          isLocked: _isLocked(meta, canUsePremiumThemes),
          onTap: () => onThemeTap(meta),
        );
      },
    );
  }
}

class _ThemeGridCard extends StatelessWidget {
  const _ThemeGridCard({
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
    final themeData = AppTheme.fromId(meta.id);
    final accent = themeData.colorScheme.primary;
    return Material(
      color: foundation.surfaceLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent ? accent : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isCurrent
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: _MiniAppPreview(themeData: themeData, rows: 2),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                    decoration: BoxDecoration(
                      color: foundation.surfaceLow,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(17),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: foundation.borderSubtle.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          meta.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: foundation.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: foundation.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(top: 8, right: 8, child: _buildBadge(context, accent)),
              if (isLocked)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.26),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: foundation.bgBase.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: foundation.borderSubtle),
                          ),
                          child: Icon(
                            LucideIcons.lock,
                            size: 11,
                            color: foundation.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, Color accent) {
    if (isCurrent) {
      return Container(
        width: 21,
        height: 21,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    }
    if (meta.isAccessibilityTheme) {
      return const _CornerBadge(label: 'Free');
    }
    return const SizedBox.shrink();
  }
}

class _PremiumCarousel extends StatelessWidget {
  const _PremiumCarousel({
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
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final meta = themes[index];
          return _PremiumThemeCard(
            meta: meta,
            isCurrent: meta.id == currentThemeId,
            isLocked: _isLocked(meta, canUsePremiumThemes),
            onTap: () => onThemeTap(meta),
          );
        },
      ),
    );
  }
}

class _PremiumThemeCard extends StatelessWidget {
  const _PremiumThemeCard({
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
    final themeData = AppTheme.fromId(meta.id);
    final accent = themeData.colorScheme.primary;
    return SizedBox(
      width: 190,
      child: Material(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent ? accent : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isCurrent
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(19),
                        ),
                        child: _MiniAppPreview(themeData: themeData, rows: 3),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                      decoration: BoxDecoration(
                        color: foundation.surfaceLow,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(19),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            meta.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: foundation.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: foundation.textSecondary,
                                  fontSize: 11.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isCurrent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: foundation.bgBase.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: foundation.borderSubtle,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.lock,
                              size: 11,
                              color: foundation.textSecondary,
                            ),
                          ),
                        ),
                      ),
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

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foundation.textMuted,
          fontWeight: FontWeight.w900,
          fontSize: 9,
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
          color: _isActive ? accent : foundation.textMuted,
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
      (label: 'Leaving Home', count: '5', color: scheme.primary),
      (
        label: 'Everyday Departure',
        count: '10',
        color: templateTokens.templatesAccentGroup2,
      ),
      (
        label: 'Evening Wind Down',
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
                            'Preview available. Applying this theme requires Personal Premium.',
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
                            'This is an older premium palette kept available for people who already know and prefer it.',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: isCurrent
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          if (isLocked) {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push(
                              premiumRoute(
                                source: PremiumEntrySource.premiumTheme,
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
                        ? 'Unlock Premium'
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
              'Nothing changes until you confirm a theme. Accessibility themes are always free, and premium themes stay previewable before you decide.',
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
