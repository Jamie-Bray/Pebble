import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';

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

class PebbleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? iconColor;
  final Color? backgroundColor;

  const PebbleBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: backgroundColor ?? foundation.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: foundation.borderSubtle),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            (onPressed ?? () => _defaultBackAction(context)).call();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              LucideIcons.chevronLeft,
              size: 18,
              color: iconColor ?? foundation.textSecondary,
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

  const PebbleBackChrome({
    super.key,
    this.trailing,
    this.title,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.respectSafeArea = true,
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
    if (!respectSafeArea) return row;
    return SafeArea(bottom: false, child: row);
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
    this.showDivider = true,
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

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 132 : 158);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: _PebbleHeaderContent(
            title: title ?? '',
            subtitle: subtitle,
            actions: actions,
            onBack: onBack,
            showDivider: true,
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

  const _PebbleHeaderContent({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onBack,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 132;
        final titleFontSize = compact ? 22.0 : 28.0;
        final titleMaxLines = compact ? 1 : 2;
        final subtitleMaxLines = compact ? 1 : 2;
        final gapAfterNav = compact ? 12.0 : 20.0;
        final gapAfterTitle = compact ? 6.0 : 8.0;
        final gapBeforeDivider = compact ? 12.0 : 16.0;

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
            SizedBox(height: gapAfterNav),
            Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: foundation.textPrimary,
                height: 1.05,
              ),
            ),
            if (hasSubtitle) ...[
              SizedBox(height: gapAfterTitle),
              Text(
                subtitle!,
                maxLines: subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: foundation.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            if (showDivider) ...[
              SizedBox(height: gapBeforeDivider),
              Container(height: 1, color: foundation.borderSubtle),
            ],
          ],
        );
      },
    );
  }
}
