import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pebble_routines/core/theme/colors.dart';

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
              HapticFeedback.lightImpact();
              context.pushNamed('settings');
            },
            icon: Icon(
              Icons.settings_outlined,
              color: foundation.textSecondary,
            ),
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

  const ZenScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 84, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 2,
                ), // Precision alignment
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: foundation.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: foundation.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: foundation.borderSubtle),
        ],
      ),
    );
  }
}

// Beautiful ambient particles painter
class AmbientParticlesPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkTheme;

  AmbientParticlesPainter(this.animationValue, this.isDarkTheme);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42); // Fixed seed for consistent positions

    // Create subtle ambient particles
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      // Floating animation
      final floatOffset = sin((animationValue * 2 * pi) + (i * 0.5)) * 15;
      final currentY = y + floatOffset;

      // Different particle sizes and opacities
      double particleSize;
      double opacity;

      if (i < 3) {
        // Hero particles - larger and brighter
        particleSize = 2.0 + (sin(animationValue * pi + i) * 0.3);
        opacity = 0.08 + (sin(animationValue * pi + i) * 0.02);
      } else if (i < 10) {
        // Medium particles
        particleSize = 1.0 + (sin(animationValue * pi + i) * 0.2);
        opacity = 0.04 + (sin(animationValue * pi + i) * 0.01);
      } else {
        // Small particles
        particleSize = 0.5 + (sin(animationValue * pi + i) * 0.1);
        opacity = 0.02 + (sin(animationValue * pi + i) * 0.005);
      }

      paint.color = isDarkTheme
          ? Colors.white.withValues(alpha: opacity)
          : Colors.black.withValues(alpha: opacity * 0.3);
      canvas.drawCircle(Offset(x, currentY), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
        HapticFeedback.selectionClick();
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
