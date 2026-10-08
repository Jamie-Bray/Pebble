import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

void _defaultBackAction(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  if (rootNavigator.canPop()) {
    rootNavigator.pop();
  }
}

/// The one back button (DESIGN_DIRECTION.md §3.8): a 44 circle of floating
/// glass (§3.4), so content scrolling underneath stays out of the way. Full
/// screen tasks (the player, the composer) keep their bare chevron instead.
class PebbleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  /// Overrides for unusual backdrops (e.g. a photo viewer).
  final Color? iconColor;
  final Color? backgroundColor;

  const PebbleBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
    this.iconColor,
    this.backgroundColor,
  });

  static const double size = PebbleGlassIconButton.size;

  @override
  Widget build(BuildContext context) {
    return PebbleGlassIconButton(
      icon: LucideIcons.chevronLeft,
      tooltip: tooltip,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      onPressed: onPressed ?? () => _defaultBackAction(context),
    );
  }
}

/// A 44 circular icon button in the floating glass style (§3.4): page colour
/// at 78% (surfaceHigh at 82% in dark themes) over a σ24 blur, a hairline
/// edge and a soft shadow. Used for the back button and other header
/// controls that float over content.
class PebbleGlassIconButton extends StatelessWidget {
  const PebbleGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.flat = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? backgroundColor;

  /// No shadow: for a header that sits on the page rather than over
  /// scrolling content (Home).
  final bool flat;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        backgroundColor ??
        (isDark
            ? foundation.surfaceHigh.withValues(alpha: 0.82)
            : foundation.bgBase.withValues(alpha: 0.78));
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: flat
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.32 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Material(
                color: fill,
                shape: CircleBorder(
                  side: BorderSide(
                    color: foundation.textPrimary.withValues(
                      alpha: flat ? 0.12 : (isDark ? 0.08 : 0.06),
                    ),
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Icon(
                      icon,
                      size: 22,
                      color: iconColor ?? foundation.textPrimary,
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

class PebbleBackChrome extends StatelessWidget {
  final Widget? trailing;
  final String? title;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final bool respectSafeArea;

  /// When the chrome floats over a scroll view, fade the page colour in
  /// behind it so content scrolling up dissolves instead of colliding with
  /// the back button.
  final bool fadeContentBehind;

  const PebbleBackChrome({
    super.key,
    this.trailing,
    this.title,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.respectSafeArea = true,
    this.fadeContentBehind = false,
  });

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final row = Padding(
      padding: padding,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            PebbleBackButton(onPressed: onBack),
            const SizedBox(width: 12),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foundation.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              height: 44,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    final chrome = respectSafeArea ? SafeArea(bottom: false, child: row) : row;
    if (!fadeContentBehind) return chrome;
    final bg = foundation.bgBase;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          bottom: -PebbleSpacing.xl,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.92),
                    bg.withValues(alpha: 0.6),
                    bg.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
        chrome,
      ],
    );
  }
}

class PebbleSubPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const PebbleSubPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 20),
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: _PebbleHeaderContent(
        title: title,
        subtitle: subtitle,
        actions: actions,
        onBack: onBack,
        showDivider: showDivider,
      ),
    );
  }
}

class PebbleSubpageHeader extends PebbleSubPageHeader {
  const PebbleSubpageHeader({
    super.key,
    required super.title,
    super.subtitle,
    super.actions,
    super.onBack,
    super.padding,
    super.showDivider,
  });
}

class PebbleSubscreenAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const PebbleSubscreenAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  // 16 top + 44 back button + 16 + 40 title + 16 bottom; a one-line
  // subtitle adds 8 + up to 33 (body at the 1.5x clamp below).
  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 132 : 174);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        // The bar has a fixed height; the title scales down on its own and
        // the subtitle stops growing at 1.5x so nothing overflows.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: _PebbleHeaderContent(
              title: title ?? '',
              subtitle: subtitle,
              actions: actions,
              onBack: onBack,
              showDivider: false,
              fixedHeight: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _PebbleHeaderContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showDivider;

  /// The app-bar variant has a fixed height, so its subtitle keeps to one
  /// line.
  final bool fixedHeight;

  const _PebbleHeaderContent({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onBack,
    required this.showDivider,
    this.fixedHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PebbleBackButton(onPressed: onBack),
            if (actions != null && actions!.isNotEmpty) ...[
              Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ] else ...[
              const SizedBox(width: 44, height: 44),
            ],
          ],
        ),
        const SizedBox(height: PebbleSpacing.md),
        // Single-line title: at large text it scales down rather than
        // wrapping or clipping.
        SizedBox(
          height: _titleHeight,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: type.title1.copyWith(color: foundation.textPrimary),
            ),
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: PebbleSpacing.xs),
          Text(
            subtitle!,
            maxLines: fixedHeight ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: type.body.copyWith(color: context.readableSecondaryText),
          ),
        ],
        if (showDivider) ...[
          const SizedBox(height: PebbleSpacing.md),
          Container(height: 1, color: foundation.borderSubtle),
        ],
      ],
    );
  }

  static const double _titleHeight = 40;
}
