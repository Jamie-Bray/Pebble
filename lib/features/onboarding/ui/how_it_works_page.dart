import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';

/// One stop of the "how a check works" tour.
class HowItWorksStop {
  const HowItWorksStop(this.title, this.body);

  final String title;
  final String body;
}

/// The three stops, in order: the step, the photo, the tick.
const howItWorksStops = [
  HowItWorksStop(
    'One step at a time',
    'Every routine shows one step, so you only think about one thing.',
  ),
  HowItWorksStop(
    'Photo steps',
    'Some steps ask for a picture first, so you can look back and see it was done.',
  ),
  HowItWorksStop(
    'Tick it off',
    "Tap the circle when it's done. Pebble keeps the time in History.",
  ),
];

/// The first-run explainer: one example step from the player, with a lit
/// circle on each part in turn. Nothing is created or saved, so it never
/// leaves a routine or a check behind.
class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key, required this.onDone, required this.onSkip});

  /// After the last stop: on to "Time to build your own".
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _targetKeys = List.generate(howItWorksStops.length, (_) => GlobalKey());
  late final AnimationController _pulse;
  int _stop = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startPulse();
  }

  /// A few gentle pulses per stop, then the ring rests. Off when the phone
  /// asks for less motion.
  void _startPulse() {
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.value = 1;
      return;
    }
    _pulse.repeat(count: 3);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        _targetKeys[_stop].currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || targetBox == null || !targetBox.hasSize) return;
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final rect = topLeft & targetBox.size;
    if (rect != _hole) setState(() => _hole = rect);
  }

  void _next() {
    if (_stop == howItWorksStops.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => _stop++);
    _startPulse();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final hole = _hole;
    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(child: _ExampleStep(targetKeys: _targetKeys)),
        if (hole != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    circle: _circleFor(hole),
                    progress: _pulse.value,
                    scrim: Colors.black.withValues(alpha: 0.6),
                    ring: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (hole != null)
          _CoachCard(
            stop: _stop,
            circle: _circleFor(hole),
            onNext: _next,
            onSkip: widget.onSkip,
          ),
      ],
    );
  }
}

/// A circle around the target, with a little room to spare.
_Circle _circleFor(Rect rect) {
  final radius = math.max(rect.width, rect.height) / 2 + 14;
  return _Circle(rect.center, radius);
}

class _Circle {
  const _Circle(this.center, this.radius);

  final Offset center;
  final double radius;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.circle,
    required this.progress,
    required this.scrim,
    required this.ring,
  });

  final _Circle circle;
  final double progress;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path()
      ..addOval(Rect.fromCircle(center: circle.center, radius: circle.radius));
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(shade, Paint()..color = scrim);
    canvas.drawCircle(
      circle.center,
      circle.radius + 4 + 14 * progress,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: 0.9 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.progress != progress ||
      old.circle.center != circle.center ||
      old.circle.radius != circle.radius;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.stop,
    required this.circle,
    required this.onNext,
    required this.onSkip,
  });

  final int stop;
  final _Circle circle;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final textTheme = Theme.of(context).textTheme;
    final item = howItWorksStops[stop];
    final isLast = stop == howItWorksStops.length - 1;
    final card = Material(
      color: foundation.bgBase,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: foundation.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${stop + 1} of ${howItWorksStops.length}',
                  style: textTheme.labelSmall?.copyWith(
                    color: foundation.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.body,
              style: textTheme.bodyMedium?.copyWith(
                color: foundation.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                PebbleButton.tertiary(onPressed: onSkip, label: 'Skip'),
                PebbleButton.primary(
                  expand: false,
                  onPressed: onNext,
                  label: isLast ? 'Build your first routine' : 'Next',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below the circle when it sits in the top half, otherwise above it,
        // and always fully on screen (the circle may then sit under it).
        const cardRoom = 200.0;
        final height = constraints.maxHeight;
        final below = circle.center.dy < height / 2;
        double? top;
        double? bottom;
        if (below) {
          top = math.min(
            circle.center.dy + circle.radius + 18,
            math.max(16, height - cardRoom),
          );
        } else {
          bottom = math.min(
            height - circle.center.dy + circle.radius + 18,
            math.max(16, height - cardRoom),
          );
        }
        return Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: top,
              bottom: bottom,
              child: card,
            ),
          ],
        );
      },
    );
  }
}

/// A still picture of one player step. Nothing on it does anything.
class _ExampleStep extends StatelessWidget {
  const _ExampleStep({required this.targetKeys});

  final List<GlobalKey> targetKeys;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final primary = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i < 2 ? primary : foundation.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quick departure check',
                        style: textTheme.labelMedium?.copyWith(
                          color: foundation.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Step 2 of 4',
                      key: targetKeys[0],
                      style: textTheme.labelMedium?.copyWith(
                        color: foundation.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Stove and oven dials off',
                  style: PebbleFonts.serif(
                    color: foundation.textPrimary,
                    fontSize: 29,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Look at each dial on the hob and the oven.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: foundation.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: foundation.surfaceLow,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: foundation.borderSubtle),
                ),
                alignment: Alignment.center,
                child: Column(
                  key: targetKeys[1],
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.camera, size: 30, color: primary),
                    const SizedBox(height: 6),
                    Text(
                      'Take a photo',
                      style: textTheme.bodyMedium?.copyWith(
                        color: foundation.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Container(
                key: targetKeys[2],
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: 34,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap when it's done",
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: foundation.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
