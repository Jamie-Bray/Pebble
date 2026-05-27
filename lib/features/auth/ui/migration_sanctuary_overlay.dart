import 'dart:ui';

import 'package:flutter/material.dart';

class MigrationSanctuaryOverlay extends StatefulWidget {
  const MigrationSanctuaryOverlay({
    super.key,
    this.message = 'Getting everything ready...',
  });

  final String message;

  @override
  State<MigrationSanctuaryOverlay> createState() =>
      _MigrationSanctuaryOverlayState();
}

class _MigrationSanctuaryOverlayState extends State<MigrationSanctuaryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: colorScheme.surface.withValues(alpha: 0.58),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.98 + (_breath.value * 0.04),
                    child: Opacity(
                      opacity: 0.78 + (_breath.value * 0.22),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.10),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withValues(alpha: 0.94),
                          height: 1.2,
                        ),
                      ),
                    ],
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
