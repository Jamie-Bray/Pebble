import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/providers/ai_caption_store.dart';

/// The photo part of a photo step, in one calm block:
///
/// - no photo yet: one large dashed tile that opens the camera, with a small
///   "Choose from library" link inside it;
/// - one photo: the photo fills the same space;
/// - two or more: a strip of square thumbnails ending in a "+" tile.
///
/// Under the photo there is one caption slot for the AI description of the
/// photo shown (or the thumbnail picked). It keeps its height while the
/// description is on its way, so nothing below it jumps, and it is never
/// drawn over the photo.
class PlayerProofZone extends StatefulWidget {
  const PlayerProofZone({
    super.key,
    required this.proofAssets,
    required this.aiDescriptionFor,
    required this.showCaptionSlot,
    required this.resolveProofPath,
    this.isFreeTier = false,
    this.onTakePhoto,
    this.onChooseFromLibrary,
    this.onOpenPhoto,
    this.onRemovePhoto,
    this.onRetryCaption,
    this.onPhotoLimitUpgrade,
  });

  final List<RoutineSessionProofAsset> proofAssets;
  final ProofAiDescription? Function(RoutineSessionProofAsset asset)
  aiDescriptionFor;

  /// Photos on this step are sent to be described, so the slot is kept.
  final bool showCaptionSlot;
  final Future<String> Function(String storedPath) resolveProofPath;
  final bool isFreeTier;

  /// Null when no more photos can be added right now.
  final Future<void> Function()? onTakePhoto;

  /// Null when this step doesn't allow library photos, or no more fit.
  final Future<void> Function()? onChooseFromLibrary;
  final Future<void> Function(String proofId)? onOpenPhoto;
  final Future<void> Function(String proofId)? onRemovePhoto;
  final void Function(String proofId)? onRetryCaption;

  /// Free tier with one photo: "Add more" opens Premium.
  final VoidCallback? onPhotoLimitUpgrade;

  @override
  State<PlayerProofZone> createState() => _PlayerProofZoneState();
}

class _PlayerProofZoneState extends State<PlayerProofZone> {
  String? _selectedId;

  @override
  void didUpdateWidget(PlayerProofZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.proofAssets.map((a) => a.proofId).toList();
    final oldIds = oldWidget.proofAssets.map((a) => a.proofId).toSet();
    final added = ids.where((id) => !oldIds.contains(id)).toList();
    if (added.isNotEmpty) {
      // A new photo is the one you want to see described.
      _selectedId = added.last;
    } else if (!ids.contains(_selectedId)) {
      _selectedId = ids.isEmpty ? null : ids.last;
    }
  }

  RoutineSessionProofAsset? get _selected {
    final assets = widget.proofAssets;
    if (assets.isEmpty) return null;
    for (final asset in assets) {
      if (asset.proofId == _selectedId) return asset;
    }
    return assets.last;
  }

  Future<void> _add() async {
    final library = widget.onChooseFromLibrary;
    final camera = widget.onTakePhoto;
    if (camera == null) return;
    if (library == null) return camera();
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.camera),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              ListTile(
                leading: const Icon(LucideIcons.images),
                title: const Text('Choose from library'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == true) await camera();
    if (choice == false) await library();
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.proofAssets;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selected = _selected;
    final description = selected == null
        ? null
        : widget.aiDescriptionFor(selected);
    final showSlot =
        selected != null && (widget.showCaptionSlot || description != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final heroHeight = (width * 0.62).clamp(180.0, 260.0);
        final Widget photos;
        if (assets.isEmpty) {
          photos = _EmptyProofTile(
            height: heroHeight,
            onTakePhoto: widget.onTakePhoto,
            onChooseFromLibrary: widget.onChooseFromLibrary,
          );
        } else if (assets.length == 1) {
          photos = SizedBox(
            height: heroHeight,
            child: _ProofPhoto(
              key: ValueKey('proof-${assets.single.proofId}'),
              asset: assets.single,
              radius: PebbleRadius.lg,
              reduceMotion: reduceMotion,
              resolveProofPath: widget.resolveProofPath,
              openSemanticLabel: 'Open proof photo',
              removeSemanticLabel: 'Remove proof photo 1',
              onOpen: widget.onOpenPhoto == null
                  ? null
                  : () => widget.onOpenPhoto!(assets.single.proofId),
              onRemove: widget.onRemovePhoto == null
                  ? null
                  : () => widget.onRemovePhoto!(assets.single.proofId),
              corner: widget.onTakePhoto != null
                  ? _PhotoCornerAction(
                      label: 'Add photo',
                      semanticLabel: 'Add another proof photo',
                      icon: LucideIcons.plus,
                      onTap: () => unawaited(_add()),
                    )
                  : null,
            ),
          );
        } else {
          photos = _ProofStrip(
            assets: assets,
            selectedId: selected!.proofId,
            width: width,
            reduceMotion: reduceMotion,
            resolveProofPath: widget.resolveProofPath,
            onSelect: (id) => setState(() => _selectedId = id),
            onOpen: widget.onOpenPhoto,
            onRemove: widget.onRemovePhoto,
            onAdd: widget.onTakePhoto == null ? null : _add,
          );
        }

        // Free tier, photo taken: one small grey line, never a tile, so it
        // doesn't nag on every run.
        final upgrade = widget.onPhotoLimitUpgrade;
        final showUpgrade =
            widget.isFreeTier &&
            upgrade != null &&
            assets.isNotEmpty &&
            widget.onTakePhoto == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            photos,
            if (showUpgrade)
              Center(
                child: TextButton(
                  key: const ValueKey('proof-add-more-premium'),
                  onPressed: upgrade,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: context.readableSecondaryText,
                    textStyle: PebbleFonts.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Add more with Premium'),
                ),
              ),
            if (showSlot) ...[
              const SizedBox(height: PebbleSpacing.sm),
              ProofCaptionSlot(
                key: ValueKey('ai-description-${selected.proofId}'),
                description: description,
                photoLabel: assets.length > 1
                    ? 'Photo ${assets.indexOf(selected) + 1}'
                    : null,
                onRetry: widget.onRetryCaption == null
                    ? null
                    : () => widget.onRetryCaption!(selected.proofId),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One line (two at most) under a photo: the AI description, "Describing…"
/// while it is on its way, or why there isn't one. Same height in every
/// state, so the screen doesn't move when the description lands. Tap a long
/// description to read all of it.
class ProofCaptionSlot extends StatefulWidget {
  const ProofCaptionSlot({
    super.key,
    required this.description,
    this.photoLabel,
    this.onRetry,
    this.textAlign = TextAlign.start,
  });

  final ProofAiDescription? description;

  /// "Photo 2", when there are several photos, for screen readers.
  final String? photoLabel;
  final VoidCallback? onRetry;
  final TextAlign textAlign;

  static const double fontSize = 13.5;
  static const double lineHeight = 1.4;

  @override
  State<ProofCaptionSlot> createState() => _ProofCaptionSlotState();
}

class _ProofCaptionSlotState extends State<ProofCaptionSlot> {
  bool _expanded = false;

  /// Two lines normally; large text gets four, so a description stays
  /// readable without a tap.
  int _collapsedLines(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 4 : 2;

  @override
  void didUpdateWidget(ProofCaptionSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description?.text != widget.description?.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final lineBox =
        scaler.scale(ProofCaptionSlot.fontSize) * ProofCaptionSlot.lineHeight;
    final secondary = context.readableSecondaryText;
    final foundation = context.darkFoundation;
    final description = widget.description;
    final prefix = widget.photoLabel == null ? '' : '${widget.photoLabel}. ';
    final base = TextStyle(
      fontSize: ProofCaptionSlot.fontSize,
      height: ProofCaptionSlot.lineHeight,
      color: secondary,
    );
    final sparkle = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ExcludeSemantics(
          child: Icon(LucideIcons.sparkles, size: 14, color: secondary),
        ),
      ),
    );

    final Widget child;
    if (description == null) {
      child = const SizedBox.shrink();
    } else if (description.text != null) {
      final text = description.text!;
      child = Semantics(
        liveRegion: true,
        button: true,
        label: '$prefix$aiPhotoLabel: $text',
        onTap: () => setState(() => _expanded = !_expanded),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text.rich(
            TextSpan(
              children: [
                sparkle,
                TextSpan(
                  text: '$aiPhotoLabel · ',
                  style: base.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: text,
                  style: base.copyWith(color: foundation.textPrimary),
                ),
              ],
            ),
            textAlign: widget.textAlign,
            maxLines: _expanded ? null : _collapsedLines(context),
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: base,
          ),
        ),
      );
    } else if (description.isPending) {
      child = Semantics(
        liveRegion: true,
        label: '${prefix}Describing photo',
        excludeSemantics: true,
        child: _Pulse(
          child: Text.rich(
            TextSpan(
              children: [
                sparkle,
                const TextSpan(text: aiPhotoDescribingLabel),
              ],
            ),
            textAlign: widget.textAlign,
            maxLines: 1,
            style: base,
          ),
        ),
      );
    } else if (description.failureMessage == null && description.canRetry) {
      final accent = context.readableAccentText(
        Theme.of(context).colorScheme.primary,
      );
      child = Semantics(
        liveRegion: true,
        button: widget.onRetry != null,
        label: "$prefix$aiPhotoFailedMessage $aiPhotoRetryAction",
        onTap: widget.onRetry,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: PebbleRadius.xsAll,
          onTap: widget.onRetry,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: widget.textAlign == TextAlign.center
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    sparkle,
                    const TextSpan(text: '$aiPhotoRetryFailedShort · '),
                    TextSpan(
                      text: aiPhotoRetryAction,
                      style: base.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: widget.textAlign,
                style: base,
              ),
            ),
          ),
        ),
      );
    } else {
      final message = description.failureMessage ?? aiPhotoFailedMessage;
      child = Semantics(
        liveRegion: true,
        label: '$prefix$message',
        onTap: () => setState(() => _expanded = !_expanded),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text.rich(
            TextSpan(
              children: [
                sparkle,
                TextSpan(text: message),
              ],
            ),
            textAlign: widget.textAlign,
            maxLines: _expanded ? null : _collapsedLines(context),
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: base,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: math.max(44, lineBox * 2)),
      child: Align(
        alignment: widget.textAlign == TextAlign.center
            ? Alignment.topCenter
            : Alignment.topLeft,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : PebbleMotion.standard,
          child: KeyedSubtree(
            key: ValueKey(
              description == null
                  ? 'none'
                  : description.text ??
                        (description.isPending ? 'pending' : 'failed'),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A slow, soft opacity pulse for "Describing…". Still under Reduce Motion.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Before the first photo: one large dashed tile. Tapping anywhere opens the
/// camera; the library link inside it is the only other way in.
class _EmptyProofTile extends StatelessWidget {
  const _EmptyProofTile({
    required this.height,
    this.onTakePhoto,
    this.onChooseFromLibrary,
  });

  final double height;
  final Future<void> Function()? onTakePhoto;
  final Future<void> Function()? onChooseFromLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.readableAccentText(theme.colorScheme.primary);
    final type = PebbleType.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: CustomPaint(
        painter: DashedRRectPainter(
          color: theme.colorScheme.primary.withValues(alpha: 0.34),
          radius: PebbleRadius.lg,
        ),
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.035),
          borderRadius: PebbleRadius.lgAll,
          child: InkWell(
            borderRadius: PebbleRadius.lgAll,
            onTap: onTakePhoto == null ? null : () => unawaited(onTakePhoto!()),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PebbleSpacing.md,
                vertical: PebbleSpacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    button: onTakePhoto != null,
                    label: 'Take photo',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.10,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.camera,
                            size: 24,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: PebbleSpacing.sm),
                        Text(
                          'Take photo',
                          textAlign: TextAlign.center,
                          style: type.bodyLarge.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onChooseFromLibrary != null) ...[
                    const SizedBox(height: PebbleSpacing.xxs),
                    TextButton(
                      onPressed: () => unawaited(onChooseFromLibrary!()),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: context.readableSecondaryText,
                        textStyle: PebbleFonts.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Choose from library'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCornerAction {
  const _PhotoCornerAction({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;
}

/// A saved proof photo filling its frame, with a remove button in the corner
/// and, on the single large photo, a small "Add photo" pill.
class _ProofPhoto extends StatelessWidget {
  const _ProofPhoto({
    super.key,
    required this.asset,
    required this.radius,
    required this.reduceMotion,
    required this.resolveProofPath,
    required this.openSemanticLabel,
    required this.removeSemanticLabel,
    this.selected = false,
    this.onOpen,
    this.onRemove,
    this.corner,
  });

  final RoutineSessionProofAsset asset;
  final double radius;
  final bool reduceMotion;
  final Future<String> Function(String storedPath) resolveProofPath;
  final String openSemanticLabel;
  final String removeSemanticLabel;
  final bool selected;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onRemove;
  final _PhotoCornerAction? corner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final photo = Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius,
            child: FutureBuilder<String>(
              future: resolveProofPath(asset.localRelativePath),
              builder: (context, snapshot) {
                final path = snapshot.data;
                final file = path == null ? null : File(path);
                final exists = file != null && file.existsSync();
                return ExcludeSemantics(
                  child: exists
                      ? Image.file(file, fit: BoxFit.cover)
                      : ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            LucideIcons.imageOff,
                            size: 22,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  width: selected ? 2 : 1,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
        ),
        if (onOpen != null)
          Positioned.fill(
            child: Semantics(
              button: true,
              selected: selected,
              label: openSemanticLabel,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: () => unawaited(onOpen!()),
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 0,
            child: _RoundIconButton(
              icon: LucideIcons.x,
              semanticLabel: removeSemanticLabel,
              onTap: () => unawaited(onRemove!()),
            ),
          ),
        if (corner != null)
          Positioned(
            right: PebbleSpacing.xs,
            bottom: PebbleSpacing.xs,
            child: _CornerPill(action: corner!),
          ),
      ],
    );

    if (reduceMotion) return photo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: PebbleMotion.standard,
      curve: PebbleMotion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
      ),
      child: photo,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.72,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPill extends StatelessWidget {
  const _CornerPill({required this.action});

  final _PhotoCornerAction action;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Semantics(
      button: true,
      label: action.semanticLabel,
      onTap: action.onTap,
      excludeSemantics: true,
      child: Material(
        color: foundation.bgBase.withValues(alpha: 0.92),
        borderRadius: PebbleRadius.pillAll,
        child: InkWell(
          borderRadius: PebbleRadius.pillAll,
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 15, color: foundation.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    action.label,
                    style: PebbleFonts.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foundation.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or more photos: square thumbnails in a row that scrolls, fading at
/// the right edge when more are off screen. Tap one to see its description;
/// tap it again to open it.
class _ProofStrip extends StatefulWidget {
  const _ProofStrip({
    required this.assets,
    required this.selectedId,
    required this.width,
    required this.reduceMotion,
    required this.resolveProofPath,
    required this.onSelect,
    this.onOpen,
    this.onRemove,
    this.onAdd,
  });

  final List<RoutineSessionProofAsset> assets;
  final String selectedId;
  final double width;
  final bool reduceMotion;
  final Future<String> Function(String storedPath) resolveProofPath;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String proofId)? onOpen;
  final Future<void> Function(String proofId)? onRemove;
  final Future<void> Function()? onAdd;

  static const double gap = PebbleSpacing.xs;

  @override
  State<_ProofStrip> createState() => _ProofStripState();
}

class _ProofStripState extends State<_ProofStrip> {
  final ScrollController _scroll = ScrollController();
  bool _moreToTheRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void didUpdateWidget(_ProofStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added = widget.assets.length > oldWidget.assets.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A new photo is picked straight away, so bring it into view.
      if (added && mounted && _scroll.hasClients) {
        final end = _scroll.position.maxScrollExtent;
        if (widget.reduceMotion) {
          _scroll.jumpTo(end);
        } else {
          unawaited(
            _scroll.animateTo(
              end,
              duration: PebbleMotion.standard,
              curve: PebbleMotion.enter,
            ),
          );
        }
      }
      _updateFade();
    });
  }

  void _updateFade() {
    if (!mounted || !_scroll.hasClients) return;
    final more = _scroll.position.extentAfter > 1;
    if (more != _moreToTheRight) setState(() => _moreToTheRight = more);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.assets;
    final tiles = assets.length + (widget.onAdd == null ? 0 : 1);
    // Three tiles fill the width; more scroll. Never smaller than 80.
    final size =
        ((widget.width - 2 * _ProofStrip.gap) / 3).clamp(80.0, 120.0) *
        (widget.assets.length + (widget.onAdd == null ? 0 : 1) > 3 ? 0.9 : 1);
    final count = assets.length;
    final list = ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      itemCount: tiles,
      separatorBuilder: (_, _) => const SizedBox(width: _ProofStrip.gap),
      itemBuilder: (context, index) {
        if (index == count) {
          return _AddTile(
            key: const ValueKey('proof-add-tile'),
            size: size,
            onTap: widget.onAdd!,
          );
        }
        final asset = assets[index];
        final selected = asset.proofId == widget.selectedId;
        return SizedBox.square(
          key: ValueKey('proof-strip-$index'),
          dimension: size,
          child: _ProofPhoto(
            key: ValueKey('proof-${asset.proofId}'),
            asset: asset,
            radius: PebbleRadius.md,
            selected: selected,
            reduceMotion: widget.reduceMotion,
            resolveProofPath: widget.resolveProofPath,
            openSemanticLabel: selected
                ? 'Open proof photo ${index + 1} of $count'
                : 'Show proof photo ${index + 1} of $count',
            removeSemanticLabel: 'Remove proof photo ${index + 1}',
            onOpen: () async {
              if (!selected) {
                widget.onSelect(asset.proofId);
                return;
              }
              await widget.onOpen?.call(asset.proofId);
            },
            onRemove: selected && widget.onRemove != null
                ? () => widget.onRemove!(asset.proofId)
                : null,
          ),
        );
      },
    );

    final background = context.darkFoundation.bgBase;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          Positioned.fill(child: list),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 32,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _moreToTheRight ? 1 : 0,
                duration: PebbleMotion.quick,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        background.withValues(alpha: 0),
                        background.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.size, required this.onTap});

  final double size;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.readableAccentText(theme.colorScheme.primary);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: DashedRRectPainter(
          color: theme.colorScheme.primary.withValues(alpha: 0.34),
          radius: PebbleRadius.md,
        ),
        child: Semantics(
          button: true,
          label: 'Add another proof photo',
          onTap: () => unawaited(onTap()),
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: PebbleRadius.mdAll,
              onTap: () => unawaited(onTap()),
              child: Center(
                child: Icon(LucideIcons.plus, size: 24, color: accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint dashed rounded-rect outline for an empty photo frame.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
