import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// Moment 1 (DESIGN_DIRECTION.md §4): the check-off timeline on one 700 ms
/// controller, so every piece of the motion reads the same clock.
///
/// t=0 the step is already saved; 0-240 the check draws itself; 120-270 the
/// time chip rises in; 300-700 the step settles into the trail; 380-630 the
/// next step enters. Under Reduce Motion the controller runs for 120 ms and
/// everything is a plain cross-fade.
class CheckOffTimeline {
  const CheckOffTimeline(this.t, {required this.reduced});

  static const Duration duration = Duration(milliseconds: 700);
  static const Duration reducedDuration = PebbleMotion.reduced;

  /// Taps are ignored for this long after a check, so a double tap can never
  /// check two steps. After it, a new tap jumps the running motion to its end.
  static const Duration inputGuard = Duration(milliseconds: 450);

  /// When the second, firmer cue (haptic + optional sound) plays.
  static const Duration secondCue = Duration(milliseconds: 240);

  /// How long the final step's check shows before the completion screen.
  static const Duration finalHold = Duration(milliseconds: 300);

  final double t;
  final bool reduced;

  double _interval(double begin, double end, Curve curve) {
    final b = begin / 700, e = end / 700;
    if (t <= b) return 0;
    if (t >= e) return 1;
    return curve.transform((t - b) / (e - b));
  }

  /// How much of the check stroke is drawn.
  double get stroke => reduced ? 1 : _interval(0, 240, Curves.easeOutCubic);

  /// The ring's idle → done colour change.
  double get ringDone => stroke;

  /// The ring going back to idle for the next step.
  double get ringReset =>
      reduced ? t : _interval(380, 630, PebbleMotion.enter);

  /// Time chip fade and rise.
  double get chip => reduced ? 1 : _interval(120, 270, PebbleMotion.enter);

  /// The checked step leaving for the trail.
  double get fly => reduced ? t : _interval(300, 700, PebbleMotion.settleCurve);

  /// The checked step's opacity while it leaves.
  double get outgoingOpacity => reduced
      ? 1 - t
      : 1 - _interval(300, 430, Curves.easeOutCubic);

  /// The next step entering.
  double get incoming => reduced ? t : _interval(380, 630, PebbleMotion.enter);

  /// The new trail row growing into place.
  double get trailReveal =>
      reduced ? 1 : _interval(300, 700, PebbleMotion.settleCurve);

  /// The new trail row's opacity.
  double get trailOpacity =>
      reduced ? t : _interval(380, 700, PebbleMotion.enter);
}

/// A check mark that draws itself along its path ([progress] 0→1).
class PebbleCheckPainter extends CustomPainter {
  const PebbleCheckPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 5,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  static Path checkPath(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w * 0.22, h * 0.53)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.79, h * 0.31);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = checkPath(size);
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(PebbleCheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// The player's focus ring: the stage the check is drawn on. Driven entirely
/// by its parent, so the save never waits for it.
class AnimatedVisualAnchor extends StatelessWidget {
  const AnimatedVisualAnchor({
    super.key,
    this.check = 0,
    this.checkOpacity = 1,
    this.done = 0,
    this.size = 132,
  });

  /// How much of the check is drawn (0-1).
  final double check;

  /// The check fades (never un-draws) when the ring resets for the next
  /// step: a retracting stroke would read as "unchecked".
  final double checkOpacity;

  /// Idle (0) to done (1) colours.
  final double done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneColor = context.done;
    final idleBorder = theme.colorScheme.primary.withValues(alpha: 0.18);
    final t = done.clamp(0.0, 1.0);
    return SizedBox(
      key: const ValueKey('routine-player-visual-anchor'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.82),
            context.doneContainer,
            t,
          ),
          border: Border.all(
            width: 2 + t,
            color: Color.lerp(idleBorder, doneColor, t)!,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                theme.colorScheme.primary.withValues(alpha: 0.06),
                doneColor.withValues(alpha: 0.14),
                t,
              )!,
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 3,
                    color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  ),
                ),
              ),
            ),
            SizedBox.square(
              dimension: size * 0.56,
              child: CustomPaint(
                painter: PebbleCheckPainter(
                  progress: check.clamp(0.0, 1.0),
                  color: doneColor.withValues(
                    alpha: doneColor.a * checkOpacity.clamp(0.0, 1.0),
                  ),
                  strokeWidth: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "8:02 AM" under a checked step, or "Skipped".
class CheckTimeChip extends StatelessWidget {
  const CheckTimeChip({super.key, required this.label, this.skipped = false});

  final String label;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final fill = skipped
        ? foundation.textPrimary.withValues(alpha: 0.06)
        : context.doneContainer;
    final onFill = Color.alphaBlend(fill, foundation.bgBase);
    final fg = skipped
        ? context.readableSecondaryText
        : ensureContrast(
            context.done,
            backgrounds: [onFill],
            strongest: foundation.textPrimary,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(color: fill, borderRadius: PebbleRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (skipped)
            _HollowRing(color: fg, size: 12)
          else
            SizedBox.square(
              dimension: 14,
              child: CustomPaint(
                painter: PebbleCheckPainter(
                  progress: 1,
                  color: fg,
                  strokeWidth: 2,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PebbleType.of(context).caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HollowRing extends StatelessWidget {
  const _HollowRing({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

/// One checked (or skipped) step in the trail above the current step.
@immutable
class StepTrailEntry {
  const StepTrailEntry({
    required this.stepIndex,
    required this.label,
    required this.timeLabel,
    required this.skipped,
  });

  final int stepIndex;
  final String label;

  /// "8:02 AM"; null when the time is unknown.
  final String? timeLabel;
  final bool skipped;

  String get semanticsLabel => skipped
      ? '$label, skipped'
      : timeLabel == null
      ? '$label, checked'
      : '$label, checked at $timeLabel';
}

/// The growing record of this run: the last checked steps with their times,
/// older ones folded into a "+3 done" pill that expands in place.
///
/// While [revealing] is set, the newest row grows in (and, once the trail is
/// full, the oldest visible row folds away at the same rate) so the step
/// below glides rather than jumps.
class StepTrail extends StatefulWidget {
  const StepTrail({
    super.key,
    required this.entries,
    this.revealing,
    this.reveal = 1,
    this.revealOpacity = 1,
    this.visibleRows = 2,
    this.maxExpandedHeight = 320,
  });

  final List<StepTrailEntry> entries;

  /// The step index of the row that is arriving, if any.
  final int? revealing;
  final double reveal;
  final double revealOpacity;
  final int visibleRows;
  final double maxExpandedHeight;

  @override
  State<StepTrail> createState() => _StepTrailState();
}

class _StepTrailState extends State<StepTrail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final revealingEntry =
        widget.revealing != null &&
        entries.isNotEmpty &&
        entries.last.stepIndex == widget.revealing &&
        widget.reveal < 1;
    final visible = math.max(1, widget.visibleRows);
    final n = entries.length;

    final rows = <Widget>[];
    Widget? pill;

    if (_expanded) {
      for (final entry in entries) {
        rows.add(_rowFor(entry, revealingEntry && entry == entries.last));
      }
    } else {
      final hidden = math.max(0, n - visible);
      // While a row arrives into a full trail, keep the row it pushes out
      // and fold it away at the same rate.
      final start = revealingEntry && hidden > 0 ? hidden - 1 : hidden;
      for (var i = start; i < n; i++) {
        final entry = entries[i];
        final arriving = revealingEntry && i == n - 1;
        final leaving = revealingEntry && hidden > 0 && i == start;
        if (leaving) {
          rows.add(
            _Grow(
              factor: 1 - widget.reveal,
              opacity: 1 - widget.reveal,
              child: _TrailRow(entry: entry),
            ),
          );
        } else {
          rows.add(_rowFor(entry, arriving));
        }
      }
      if (hidden > 0) {
        final hiddenEntries = entries.take(hidden);
        final allDone = hiddenEntries.every((e) => !e.skipped);
        final label = allDone ? '+$hidden done' : '+$hidden earlier';
        final p = _TrailPill(
          label: label,
          expanded: false,
          onTap: () => setState(() => _expanded = true),
        );
        pill = revealingEntry && hidden == 1
            ? _Grow(factor: widget.reveal, opacity: widget.reveal, child: p)
            : p;
      }
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pill != null) pill,
        ...rows,
        if (_expanded && n > visible)
          _TrailPill(
            label: 'Show less',
            expanded: true,
            onTap: () => setState(() => _expanded = false),
          ),
      ],
    );

    // Grouped-list surface (DESIGN_DIRECTION.md §3.4): one soft fill, no
    // border, no shadow, so the record reads as one quiet block.
    final foundation = context.darkFoundation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: 'Checked so far',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? foundation.surfaceLow
              : foundation.textPrimary.withValues(alpha: 0.04),
          borderRadius: PebbleRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PebbleSpacing.sm,
            vertical: PebbleSpacing.xxs,
          ),
          child: _expanded
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: widget.maxExpandedHeight,
                  ),
                  child: SingleChildScrollView(child: column),
                )
              : column,
        ),
      ),
    );
  }

  Widget _rowFor(StepTrailEntry entry, bool arriving) {
    final row = _TrailRow(entry: entry);
    if (!arriving) return row;
    return _Grow(
      factor: widget.reveal,
      opacity: widget.revealOpacity,
      child: row,
    );
  }
}

/// Clips [child] to [factor] of its height, anchored to the top.
class _Grow extends StatelessWidget {
  const _Grow({
    required this.factor,
    required this.opacity,
    required this.child,
  });

  final double factor;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: factor.clamp(0.0, 1.0),
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

class _TrailRow extends StatelessWidget {
  const _TrailRow({required this.entry});

  final StepTrailEntry entry;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;
    final doneColor = context.done;
    return Semantics(
      label: entry.semanticsLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Center(
                child: entry.skipped
                    ? _HollowRing(color: secondary, size: 12)
                    : SizedBox.square(
                        dimension: 16,
                        child: CustomPaint(
                          painter: PebbleCheckPainter(
                            progress: 1,
                            color: doneColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: PebbleSpacing.sm),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.body.copyWith(color: secondary),
              ),
            ),
            const SizedBox(width: PebbleSpacing.sm),
            Text(
              entry.skipped ? 'Skipped' : (entry.timeLabel ?? ''),
              style: type.caption.copyWith(
                color: secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailPill extends StatelessWidget {
  const _TrailPill({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PebbleSpacing.xxs),
        child: Semantics(
          button: true,
          label: expanded ? 'Show fewer checked steps' : 'Show all checked steps',
          excludeSemantics: true,
          child: Material(
            color: foundation.textPrimary.withValues(alpha: 0.06),
            borderRadius: PebbleRadius.pillAll,
            child: InkWell(
              borderRadius: PebbleRadius.pillAll,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: type.caption.copyWith(
                          color: context.readableSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 14,
                        color: context.readableSecondaryText,
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

/// What was on screen when a step was checked, kept for the few hundred
/// milliseconds it takes to settle into the trail (the session has already
/// moved on to the next step by then).
@immutable
class CheckedStepSnapshot {
  const CheckedStepSnapshot({
    required this.stepIndex,
    required this.instruction,
    required this.timeLabel,
    required this.skipped,
    required this.hadRing,
    required this.isFinal,
  });

  final int stepIndex;
  final String instruction;
  final String timeLabel;
  final bool skipped;
  final bool hadRing;
  final bool isFinal;
}

/// The player's centre: the ring, then the step. While [outgoing] is set the
/// checked step stays in place (check drawing, time chip rising), then
/// shrinks and glides up toward the trail as [incoming] rises into place.
class CheckOffStage extends StatelessWidget {
  const CheckOffStage({
    super.key,
    required this.incoming,
    required this.incomingRing,
    required this.instructionStyle,
    this.outgoing,
    this.timeline,
    this.ringSize = 132,
  });

  final Widget incoming;
  final bool incomingRing;
  final TextStyle instructionStyle;
  final CheckedStepSnapshot? outgoing;
  final CheckOffTimeline? timeline;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final out = outgoing;
    final tl = timeline;
    if (out == null || tl == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (incomingRing) ...[
            AnimatedVisualAnchor(size: ringSize),
            const SizedBox(height: PebbleSpacing.xxl),
          ],
          incoming,
        ],
      );
    }

    // The ring: shared when both steps use it (it resets in place),
    // otherwise it leaves or arrives with its step.
    final checkDrawn = out.skipped ? 0.0 : tl.stroke;
    final doneTone = out.skipped ? 0.0 : tl.ringDone;
    Widget? ring;
    if (out.hadRing && incomingRing) {
      ring = AnimatedVisualAnchor(
        size: ringSize,
        check: checkDrawn,
        checkOpacity: 1 - tl.ringReset,
        done: doneTone * (1 - tl.ringReset),
      );
    } else if (out.hadRing) {
      ring = Opacity(
        opacity: tl.outgoingOpacity,
        child: AnimatedVisualAnchor(
          size: ringSize,
          check: checkDrawn,
          done: doneTone,
        ),
      );
    } else if (incomingRing) {
      ring = Opacity(
        opacity: tl.incoming,
        child: AnimatedVisualAnchor(size: ringSize),
      );
    }

    final fly = tl.fly;
    final outgoingBlock = IgnorePointer(
      child: Opacity(
        opacity: tl.outgoingOpacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -48 * fly),
          child: Transform.scale(
            scale: 1 - 0.2 * fly,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  out.instruction,
                  textAlign: TextAlign.center,
                  style: instructionStyle,
                ),
                const SizedBox(height: PebbleSpacing.md),
                Opacity(
                  opacity: tl.chip,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - tl.chip)),
                    child: CheckTimeChip(
                      label: out.skipped ? 'Skipped' : out.timeLabel,
                      skipped: out.skipped,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final incomingT = tl.incoming;
    final incomingBlock = IgnorePointer(
      ignoring: incomingT < 1,
      child: Opacity(
        opacity: incomingT,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - incomingT)),
          child: incoming,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ring != null) ...[ring, const SizedBox(height: PebbleSpacing.xxl)],
        Stack(
          alignment: Alignment.topCenter,
          children: [incomingBlock, outgoingBlock],
        ),
      ],
    );
  }
}
