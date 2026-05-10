import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';

class GuidanceAudioPlayButton extends StatefulWidget {
  const GuidanceAudioPlayButton({
    required this.audio,
    required this.storage,
    this.compact = false,
    super.key,
  });

  final StepGuidanceAudio audio;
  final GuidanceAudioStorage storage;
  final bool compact;

  @override
  State<GuidanceAudioPlayButton> createState() =>
      _GuidanceAudioPlayButtonState();
}

class _GuidanceAudioPlayButtonState extends State<GuidanceAudioPlayButton> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isUnavailable = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnavailable) {
      return Text(
        'Audio unavailable',
        style: TextStyle(
          fontSize: widget.compact ? 12.5 : 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => unawaited(_togglePlayback()),
      icon: Icon(
        _isPlaying ? LucideIcons.pause : LucideIcons.volume2,
        size: widget.compact ? 14 : 16,
      ),
      label: Text(_isPlaying ? 'Playing' : 'Play guidance'),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface.withValues(alpha: 0.74),
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.14)),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 12,
          vertical: widget.compact ? 8 : 10,
        ),
        minimumSize: Size(0, widget.compact ? 36 : 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TextStyle(
          fontSize: widget.compact ? 12.5 : 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }

    try {
      final path = await widget.storage.resolveStoredPath(
        widget.audio.localPath,
      );
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() => _isUnavailable = true);
        }
        return;
      }

      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      if (mounted) {
        setState(() => _isPlaying = true);
      }
      await _player.play();
    } catch (e, st) {
      debugPrint('Guidance audio playback error: $e\n$st');
      // Do not permanently lock into _isUnavailable if it's a transient engine issue.
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }
}
