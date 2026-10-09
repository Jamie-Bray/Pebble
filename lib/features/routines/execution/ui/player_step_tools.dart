import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';

/// The quiet row under a step: small round icons, each with a word under it.
/// Only the ones a step uses are passed in, so most steps show just Note.
class PlayerStepTools extends StatelessWidget {
  const PlayerStepTools({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: PebbleSpacing.lg,
      runSpacing: PebbleSpacing.sm,
      children: children,
    );
  }
}

/// One round tool: a 46 px ring with an icon, and its label underneath.
/// [progress] draws a thin ring that fills (the voice tip while it plays).
class PlayerToolButton extends StatelessWidget {
  const PlayerToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.filled = false,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// The tool already holds something (a saved note).
  final bool filled;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = context.readableAccentText(theme.colorScheme.primary);
    final enabled = onTap != null;
    final progress = this.progress;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: PebbleRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: PebbleMotion.quick,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? theme.colorScheme.primary.withValues(alpha: 0.10)
                            : Colors.transparent,
                        border: Border.all(
                          width: 1.5,
                          color: onSurface.withValues(
                            alpha: filled ? 0.16 : 0.12,
                          ),
                        ),
                      ),
                    ),
                    if (progress != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ProgressRingPainter(
                            progress: progress.clamp(0.0, 1.0),
                            color: accent,
                          ),
                        ),
                      ),
                    Icon(
                      icon,
                      size: 20,
                      color: enabled
                          ? accent
                          : onSurface.withValues(alpha: 0.38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: PebbleFonts.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.readableSecondaryText,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(1),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Listen: plays the step's voice tip in place. While it plays a thin ring
/// fills around the icon and the label counts down; a second tap stops it.
/// Nothing opens or pops up.
class PlayerListenTool extends StatefulWidget {
  const PlayerListenTool({
    super.key,
    required this.audio,
    required this.storage,
  });

  final StepGuidanceAudio audio;
  final GuidanceAudioStorage storage;

  @override
  State<PlayerListenTool> createState() => _PlayerListenToolState();
}

class _PlayerListenToolState extends State<PlayerListenTool> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _playing = false;
  bool _unavailable = false;
  Duration _position = Duration.zero;

  Duration get _length {
    final known = _player.duration;
    if (known != null && known > Duration.zero) return known;
    return Duration(milliseconds: math.max(1, widget.audio.durationMs));
  }

  @override
  void initState() {
    super.initState();
    _positionSub = _player.positionStream.listen((position) {
      if (mounted && _playing) setState(() => _position = position);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
      return;
    }
    try {
      final path = await widget.storage.resolveStoredPath(
        widget.audio.localPath,
      );
      if (!await File(path).exists()) {
        if (mounted) setState(() => _unavailable = true);
        return;
      }
      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.seek(Duration.zero);
      if (!mounted) return;
      setState(() {
        _playing = true;
        _position = Duration.zero;
      });
      unawaited(HapticFeedback.selectionClick());
      await _player.play();
    } catch (e) {
      debugPrint('Voice tip playback failed (${e.runtimeType})');
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const PlayerToolButton(
        icon: LucideIcons.volumeX,
        label: 'Unavailable',
        semanticLabel: 'Voice tip unavailable',
        onTap: null,
      );
    }
    final length = _length;
    final remaining = length - _position;
    return PlayerToolButton(
      key: const ValueKey('player-listen'),
      icon: _playing ? LucideIcons.pause : LucideIcons.volume2,
      label: _playing ? _clock(remaining) : 'Listen',
      semanticLabel: _playing ? 'Stop voice tip' : 'Play voice tip',
      progress: _playing
          ? _position.inMilliseconds / length.inMilliseconds
          : null,
      onTap: () => unawaited(_toggle()),
    );
  }

  static String _clock(Duration d) {
    final seconds = d.isNegative ? 0 : (d.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// A saved note, shown as one soft line under the step. Tap to edit it.
class PlayerNoteLine extends StatelessWidget {
  const PlayerNoteLine({super.key, required this.note, required this.onTap});

  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = context.readableSecondaryText;
    return Semantics(
      button: true,
      label: 'Your note: $note. Double tap to edit.',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('player-note-line'),
        onTap: onTap,
        borderRadius: PebbleRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(LucideIcons.pencilLine, size: 15, color: secondary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  note,
                  style: PebbleFonts.sans(
                    fontSize: 15,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The note bar: a slim rounded field sitting on top of the keyboard with a
/// tick to save, like a message bar. The step stays in view above it.
class PlayerNoteComposer extends StatelessWidget {
  const PlayerNoteComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      key: const ValueKey('player-note-composer'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: onSurface.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final count = value.text.characters.length;
                  return TextField(
                    key: const ValueKey('player-note-field'),
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    // Tapping the step (or anywhere off the bar) saves and
                    // closes it, the same as the tick.
                    onTapOutside: (_) => onSave(),
                    minLines: 1,
                    maxLines: 4,
                    maxLength: maxStepNoteChars,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: PebbleFonts.sans(
                      fontSize: 16,
                      height: 1.35,
                      color: onSurface,
                    ),
                    // The count only appears when it starts to matter.
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => count > 100
                        ? Text('$count / $maxStepNoteChars')
                        : null,
                    decoration: InputDecoration(
                      hintText: 'Add a note…',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: onSurface.withValues(alpha: 0.14),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: onSurface.withValues(alpha: 0.14),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: onSurface.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              // Lines the tick up with a one-line field, above any counter.
              padding: const EdgeInsets.only(bottom: 2),
              child: Semantics(
                button: true,
                label: 'Save note',
                excludeSemantics: true,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('player-note-save'),
                    customBorder: const CircleBorder(),
                    onTap: onSave,
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        LucideIcons.check,
                        size: 20,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
