import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:record/record.dart';

Future<StepGuidanceAudio?> showGuidanceAudioRecorderSheet({
  required BuildContext context,
  required GuidanceAudioStorage storage,
}) {
  return showModalBottomSheet<StepGuidanceAudio>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _GuidanceAudioRecorderSheet(storage: storage),
  );
}

class _GuidanceAudioRecorderSheet extends StatefulWidget {
  const _GuidanceAudioRecorderSheet({required this.storage});

  final GuidanceAudioStorage storage;

  @override
  State<_GuidanceAudioRecorderSheet> createState() =>
      _GuidanceAudioRecorderSheetState();
}

class _GuidanceAudioRecorderSheetState
    extends State<_GuidanceAudioRecorderSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  late final AnimationController _pulseController;
  Timer? _timer;
  DateTime? _startedAt;
  String? _targetPath;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isStopping = false;
  bool _isStarting = false;
  bool _isPointerDown = false;
  bool _recordingSaved = false;
  bool _recorderDisposed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.15,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    if (!_recordingSaved && (_isRecording || _isStarting)) {
      unawaited(_cancelAndDisposeRecorder());
    } else {
      unawaited(_disposeRecorder());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: cs.onSurface.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _isRecording ? 'Recording guidance' : 'Guidance audio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: _isRecording
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
              child: Text(_formatElapsed(_elapsed)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: cs.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 48),
            Listener(
              onPointerDown: (_) {
                if (_isPointerDown) return;
                _isPointerDown = true;
                unawaited(_startRecording());
              },
              onPointerCancel: (_) {
                if (!_isPointerDown) return;
                _isPointerDown = false;
                unawaited(_stopRecording(cancel: true));
              },
              onPointerUp: (_) {
                if (!_isPointerDown) return;
                _isPointerDown = false;
                unawaited(_stopRecording());
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isRecording ? _pulseController.value : 1.0,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  blurRadius: 28,
                                  spreadRadius:
                                      8 * (_pulseController.value - 0.95),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        LucideIcons.mic,
                        size: 42,
                        color: _isRecording
                            ? cs.onPrimary
                            : cs.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 36),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isRecording ? 0.0 : 1.0,
              child: Text(
                'Hold to record, release to save',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isStarting || _isStopping) return;
    _isStarting = true;
    setState(() => _error = null);

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isPointerDown = false;
        _error = 'Microphone access is needed to record audio.';
      });
      return;
    }

    final targetPath = await widget.storage.prepareRecordingPath();
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: targetPath,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isPointerDown = false;
        _error = 'Failed to start recording.';
      });
      return;
    }

    _targetPath = targetPath;
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _recordingSaved = false;
    _isStarting = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= GuidanceAudioStorage.maxDuration) {
        _elapsed = GuidanceAudioStorage.maxDuration;
        _timer?.cancel();
        unawaited(_stopRecording(forcedDuration: _elapsed));
        return;
      }
      if (mounted) {
        setState(() => _elapsed = elapsed);
      }
    });

    if (mounted) {
      setState(() => _isRecording = true);
      unawaited(_pulseController.repeat(reverse: true));
    }
  }

  Future<void> _stopRecording({
    Duration? forcedDuration,
    bool cancel = false,
  }) async {
    if (_isStopping || (!_isRecording && !_isStarting)) return;
    _isStopping = true;
    _timer?.cancel();
    _pulseController.stop();
    unawaited(
      _pulseController.animateTo(
        0.95,
        duration: const Duration(milliseconds: 200),
      ),
    );

    if (_isStarting) {
      // Allow start to complete before canceling so it doesn't leak
      await Future.delayed(const Duration(milliseconds: 150));
    }

    final duration =
        forcedDuration ??
        (_startedAt == null
            ? _elapsed
            : DateTime.now().difference(_startedAt!));

    try {
      // Discard very short accidental taps
      if (cancel || duration.inMilliseconds < 400) {
        await _recorder.cancel();
        if (cancel) {
          _resetState(null);
        } else {
          _resetState('Hold longer to record.');
        }
        return;
      }

      final path = await _recorder.stop() ?? _targetPath;
      if (path == null) {
        throw StateError('No audio file was recorded.');
      }
      final audio = await widget.storage.createMetadataForRecordedFile(
        absolutePath: path,
        duration: duration,
      );
      if (mounted) {
        setState(() {
          _recordingSaved = true;
          _isRecording = false;
          _isStopping = false;
          _isStarting = false;
          _isPointerDown = false;
        });
        await _disposeRecorder();
        if (!mounted) return;
        Navigator.of(context).pop(audio);
      }
    } catch (_) {
      if (!mounted) return;
      _resetState('Failed to save recording.');
    }
  }

  void _resetState(String? error) {
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isStopping = false;
      _isStarting = false;
      _isPointerDown = false;
      _recordingSaved = false;
      _elapsed = Duration.zero;
      _startedAt = null;
      _targetPath = null;
      _error = error;
    });
  }

  Future<void> _cancelAndDisposeRecorder() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // Best effort during teardown.
    }
    await _disposeRecorder();
  }

  Future<void> _disposeRecorder() async {
    if (_recorderDisposed) return;
    _recorderDisposed = true;
    try {
      await _recorder.dispose();
    } catch (_) {
      // Best effort during teardown.
    }
  }

  String _formatElapsed(Duration duration) {
    final seconds = duration.inSeconds
        .clamp(0, GuidanceAudioStorage.maxDuration.inSeconds)
        .toString()
        .padLeft(2, '0');
    final ms = ((duration.inMilliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '0:$seconds.$ms';
  }
}
