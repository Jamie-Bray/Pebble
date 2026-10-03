import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

class ZenHeader extends StatelessWidget {
  const ZenHeader({super.key, this.extraActions = const []});

  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return SliverToBoxAdapter(
      child: ZenScreenHeader(
        title: 'Pebble',
        subtitle: 'Small routines. Lasting ripples.',
        actions: [
          ...extraActions,
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              context.pushNamed('settings');
            },
            icon: Icon(LucideIcons.settings, color: foundation.textSecondary),
          ),
        ],
      ),
    );
  }
}

class ZenScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  /// Set when a floating back button ([PebbleBackChrome]) sits above the
  /// header, so the title starts below it instead of underneath it.
  final bool reserveBackButtonSpace;

  const ZenScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
    this.leading,
    this.reserveBackButtonSpace = false,
  });

  /// Back chrome: 8 top padding + 44 button, plus breathing room.
  static const double _backButtonClearance = 8 + 44 + 16;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    // Inside a SafeArea this inset is already 0, so it never double counts.
    final topInset = MediaQuery.paddingOf(context).top;
    final topPadding = reserveBackButtonSpace
        ? topInset + _backButtonClearance
        : max(84.0, topInset + 24);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, PebbleSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              // Expanded + scaleDown: at large text the title shrinks instead
              // of pushing the actions off screen.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: type.title1.copyWith(
                        color: foundation.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: PebbleSpacing.xs),
          // Regular body, no italic and no divider (DESIGN_DIRECTION.md §3.2).
          Text(
            subtitle,
            style: type.body.copyWith(color: context.readableSecondaryText),
          ),
        ],
      ),
    );
  }
}

class ZenBounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const ZenBounceButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  @override
  State<ZenBounceButton> createState() => _ZenBounceButtonState();
}

class _ZenBounceButtonState extends State<ZenBounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _animation, child: widget.child),
    );
  }
}
