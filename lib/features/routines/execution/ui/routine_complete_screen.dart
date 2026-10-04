import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// A photo taken this run, loaded lazily for the receipt.
@immutable
class CompletionPhoto {
  const CompletionPhoto({required this.id, required this.load});

  final String id;
  final Future<File?> Function() load;
}

/// Where this run's record lives, in the words of COPY_GUIDELINES.md.
enum CompletionStorage {
  /// "Saved on this device".
  device,

  /// Saved here and queued for backup: "Saved on this device · Backup is on".
  deviceBackupOn,

  /// "Backed up".
  backedUp;

  static CompletionStorage fromSyncStatus(String? syncStatus) =>
      switch (syncStatus) {
        'synced' => CompletionStorage.backedUp,
        'pendingUpload' => CompletionStorage.deviceBackupOn,
        _ => CompletionStorage.device,
      };

  String get label => switch (this) {
    CompletionStorage.device => 'Saved on this phone',
    CompletionStorage.deviceBackupOn => 'Saved on this phone · Backup is on',
    CompletionStorage.backedUp => 'Backed up',
  };
}

/// Moment 2 (DESIGN_DIRECTION.md §4): "the cairn and the time".
///
/// One pebble per step drops onto a small cairn, the finish time appears
/// large, and a calm receipt lists the steps, this run's photos and where
/// the record is saved. One primary action, Done. The button is tappable
/// from the first frame, so nobody waits for the motion.
class RoutineCompleteScreen extends StatefulWidget {
  const RoutineCompleteScreen({
    super.key,
    required this.routineName,
    this.routineId,
    required this.totalStepsCompleted,
    required this.totalPhotosSaved,
    this.totalSteps,
    this.skippedSteps = 0,
    this.showPhotoSummary = true,
    this.finishedAt,
    this.photos = const [],
    this.storage = CompletionStorage.device,
    this.completionEmailNote,
    this.haptics = false,
    this.onLanded,
    this.onOpenPhoto,
    required this.onBackToHome,
    required this.onReviewRoutine,
  });

  final String routineName;

  /// For the shared `cairn-<id>` Hero with the Home "Checked" card.
  final int? routineId;
  final int totalStepsCompleted;
  final int totalPhotosSaved;

  /// Steps in the run. Defaults to completed + skipped.
  final int? totalSteps;
  final int skippedSteps;

  /// False for a routine with no photo steps, so the receipt doesn't report
  /// "no photos" for something that was never asked for.
  final bool showPhotoSummary;

  /// When the run finished. Defaults to now.
  final DateTime? finishedAt;
  final List<CompletionPhoto> photos;
  final CompletionStorage storage;

  /// For example "Completion email sent to sam@example.com." Shown under the
  /// receipt once the send finishes; null shows nothing.
  final String? completionEmailNote;

  /// Feel each pebble land (the "Buzz on step complete" setting).
  final bool haptics;

  /// Called once as the cairn settles, e.g. to play the completion sound.
  final VoidCallback? onLanded;
  final void Function(int index)? onOpenPhoto;

  /// "Done".
  final VoidCallback onBackToHome;

  /// "See details": opens the run detail.
  final VoidCallback onReviewRoutine;

  /// The semantics label of the header, kept from the previous screen.
  static const String headerSemanticsLabel = 'Routine complete';

  @override
  State<RoutineCompleteScreen> createState() => _RoutineCompleteScreenState();
}

class _RoutineCompleteScreenState extends State<RoutineCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Timer> _timers = <Timer>[];
  bool _started = false;
  late final DateTime _finishedAt = widget.finishedAt ?? DateTime.now();

  int get _total =>
      widget.totalSteps ?? widget.totalStepsCompleted + widget.skippedSteps;

  int get _pebbles => PebbleCairn.pebbleCount(_total);

  /// When the last pebble has landed and the cairn settles.
  Duration get _settleAt =>
      cairnPebbleStart(_pebbles - 1) + const Duration(milliseconds: 160);

  Duration get _totalDuration =>
      _settleAt + const Duration(milliseconds: 360) + PebbleMotion.quick;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce Motion: the final state, with one firm haptic.
      _controller.value = 1;
      if (widget.haptics) unawaited(HapticFeedback.mediumImpact());
      widget.onLanded?.call();
      return;
    }
    unawaited(_controller.forward());
    if (widget.haptics) {
      for (var i = 0; i < _pebbles; i++) {
        _timers.add(
          Timer(cairnPebbleStart(i) + cairnTouchDown, () {
            unawaited(HapticFeedback.selectionClick());
          }),
        );
      }
    }
    _timers.add(
      Timer(_settleAt, () {
        if (!mounted) return;
        if (widget.haptics) unawaited(HapticFeedback.mediumImpact());
        widget.onLanded?.call();
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  /// 0→1 progress of a phase that starts [startMs] after [_settleAt].
  double _phase(Duration elapsed, int startMs, Duration length, Curve curve) {
    final t =
        (elapsed - _settleAt - Duration(milliseconds: startMs)).inMicroseconds /
        length.inMicroseconds;
    return curve.transform(t.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final foundation = context.darkFoundation;
    final gutter = PebbleSpacing.gutter(MediaQuery.sizeOf(context).width);
    final routineName = widget.routineName.trim().isEmpty
        ? 'Routine'
        : widget.routineName.trim();
    final skipped = widget.skippedSteps.clamp(0, _total).toInt();
    final checked = _total - skipped;
    final overline = skipped > 0
        ? '$checked of $_total checked'
        : 'All checked';
    final dateLabel = DateFormat.MMMEd().format(_finishedAt);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = _controller.duration! * _controller.value;
        final drops = [
          for (var i = 0; i < _pebbles; i++)
            _controller.value >= 1 ? (0.0, 1.0) : cairnDropAt(i, elapsed),
        ];
        final settle = _phase(
          elapsed,
          0,
          const Duration(milliseconds: 240),
          Curves.linear,
        );
        final compress = settle <= 0 || settle >= 1
            ? 0.0
            : (1 - (2 * settle - 1).abs());
        final headline = _phase(
          elapsed,
          120,
          PebbleMotion.emphasized,
          PebbleMotion.emphasizedCurve,
        );
        final receipt = _phase(
          elapsed,
          240,
          PebbleMotion.standard,
          PebbleMotion.enter,
        );
        final button = _phase(
          elapsed,
          360,
          PebbleMotion.quick,
          Curves.easeOut,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            PebbleSpacing.xl,
            gutter,
            PebbleSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'cairn-${widget.routineId ?? routineName}',
                            child: PebbleCairn(
                              total: _total,
                              skipped: skipped,
                              drops: drops,
                              compress: compress,
                            ),
                          ),
                          const SizedBox(height: PebbleSpacing.xl),
                          _Rise(
                            t: headline,
                            distance: 12,
                            child: Column(
                              children: [
                                Semantics(
                                  header: true,
                                  label:
                                      RoutineCompleteScreen.headerSemanticsLabel,
                                  child: Text(
                                    overline.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: type.overline.copyWith(
                                      color: context.readableAccentText(
                                        context.done,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: PebbleSpacing.xs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: PebbleBigTime(
                                    at: _finishedAt,
                                    textAlign: TextAlign.center,
                                    style: type.displayXL.copyWith(
                                      fontSize: 64,
                                      height: 1,
                                      color: foundation.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: PebbleSpacing.xs),
                                Text(
                                  '$routineName · $dateLabel',
                                  textAlign: TextAlign.center,
                                  style: type.body.copyWith(
                                    color: context.readableSecondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: PebbleSpacing.xxl),
                          _Rise(
                            t: receipt,
                            distance: 16,
                            child: _ReceiptCard(
                              checked: checked,
                              total: _total,
                              skipped: skipped,
                              showPhotos: widget.showPhotoSummary,
                              photoCount: widget.totalPhotosSaved,
                              photos: widget.photos,
                              storage: widget.storage,
                              onOpenPhoto: widget.onOpenPhoto,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: PebbleMotion.standard,
                            child: widget.completionEmailNote == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    key: ValueKey(widget.completionEmailNote),
                                    padding: const EdgeInsets.only(
                                      top: PebbleSpacing.md,
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Icon(
                                              LucideIcons.mail,
                                              size: 16,
                                              color:
                                                  context.readableSecondaryText,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: PebbleSpacing.xs,
                                          ),
                                          Flexible(
                                            child: Text(
                                              widget.completionEmailNote!,
                                              style: type.body.copyWith(
                                                color: context
                                                    .readableSecondaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Opacity(
                  opacity: button,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PebbleButton.primary(
                        onPressed: widget.onBackToHome,
                        label: 'Done',
                      ),
                      const SizedBox(height: PebbleSpacing.xxs),
                      PebbleButton.tertiary(
                        expand: true,
                        onPressed: widget.onReviewRoutine,
                        label: 'See details',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.distance, required this.child});

  final double t;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, distance * (1 - t)),
        child: child,
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.checked,
    required this.total,
    required this.skipped,
    required this.showPhotos,
    required this.photoCount,
    required this.photos,
    required this.storage,
    this.onOpenPhoto,
  });

  final int checked;
  final int total;
  final int skipped;
  final bool showPhotos;
  final int photoCount;
  final List<CompletionPhoto> photos;
  final CompletionStorage storage;
  final void Function(int index)? onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = foundation.textPrimary.withValues(alpha: 0.08);
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;

    final rows = <Widget>[
      _ReceiptRow(
        label: 'Steps',
        trailing: Text(
          skipped > 0
              ? '$checked of $total · $skipped skipped'
              : '$checked of $total',
          style: type.body.copyWith(
            color: secondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      if (showPhotos)
        _ReceiptRow(
          label: 'Photos',
          semanticsValue: '$photoCount photo${photoCount == 1 ? '' : 's'}',
          trailing: photos.isEmpty
              ? Text(
                  photoCount == 0
                      ? 'None'
                      : '$photoCount photo${photoCount == 1 ? '' : 's'}',
                  style: type.body.copyWith(color: secondary),
                )
              : _ThumbStrip(
                  photos: photos,
                  count: photoCount,
                  onOpen: onOpenPhoto,
                ),
        ),
      _ReceiptRow(
        icon: storage == CompletionStorage.backedUp
            ? LucideIcons.cloudCheck
            : LucideIcons.smartphone,
        label: storage.label,
      ),
    ];

    // Card style (DESIGN_DIRECTION.md §3.4): page fill plus a hairline in
    // light themes, the low surface in dark ones. No shadow.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: PebbleSpacing.lg,
        vertical: PebbleSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isDark ? foundation.surfaceLow : foundation.bgBase,
        borderRadius: PebbleRadius.lgAll,
        border: isDark
            ? null
            : Border.all(color: foundation.textPrimary.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: hairline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    this.trailing,
    this.icon,
    this.semanticsValue,
  });

  final String label;
  final Widget? trailing;
  final IconData? icon;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final foundation = context.darkFoundation;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PebbleSpacing.sm),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.readableSecondaryText),
              const SizedBox(width: PebbleSpacing.sm),
            ],
            Expanded(
              child: Text(
                label,
                style: type.body.copyWith(
                  color: icon != null
                      ? context.readableSecondaryText
                      : foundation.textPrimary,
                  fontWeight: icon != null ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: PebbleSpacing.sm),
              Flexible(
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
          ],
        ),
      ),
    );
    if (semanticsValue == null) return row;
    return Semantics(
      label: label,
      value: semanticsValue,
      child: row,
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.photos, required this.count, this.onOpen});

  static const int max = 4;
  final List<CompletionPhoto> photos;
  final int count;
  final void Function(int index)? onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(max).toList();
    final extra = count - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: PebbleSpacing.xs),
          PhotoThumb(
            key: ValueKey('completion-photo-${shown[i].id}'),
            load: shown[i].load,
            size: 48,
            overlayLabel: i == shown.length - 1 && extra > 0 ? '+$extra' : null,
            semanticsLabel: 'Photo ${i + 1} of $count',
            onTap: onOpen == null ? null : () => onOpen!(i),
          ),
        ],
      ],
    );
  }
}

/// A rounded photo thumbnail (r8) that loads its file lazily.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.load,
    this.size = 48,
    this.overlayLabel,
    this.semanticsLabel,
    this.onTap,
  });

  final Future<File?> Function() load;
  final double size;
  final String? overlayLabel;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final thumb = SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: PebbleRadius.xsAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _LazyPhoto(load: load, size: size),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: PebbleRadius.xsAll,
                border: Border.all(
                  color: foundation.textPrimary.withValues(alpha: 0.08),
                ),
              ),
            ),
            if (overlayLabel != null)
              ColoredBox(
                color: foundation.bgBase.withValues(alpha: 0.72),
                child: Center(
                  child: Text(
                    overlayLabel!,
                    style: PebbleType.of(context).caption.copyWith(
                      color: foundation.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      image: true,
      label: semanticsLabel,
      child: thumb,
    );
  }
}

class _LazyPhoto extends StatefulWidget {
  const _LazyPhoto({required this.load, required this.size});

  final Future<File?> Function() load;
  final double size;

  @override
  State<_LazyPhoto> createState() => _LazyPhotoState();
}

class _LazyPhotoState extends State<_LazyPhoto> {
  late final Future<File?> _file = widget.load();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final placeholder = ColoredBox(
      color: foundation.textPrimary.withValues(alpha: 0.06),
      child: Icon(
        LucideIcons.image,
        size: widget.size * 0.38,
        color: foundation.textPrimary.withValues(alpha: 0.3),
      ),
    );
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return placeholder;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: (widget.size * dpr).round(),
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}
