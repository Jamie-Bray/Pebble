import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

class RoutineRunDetailScreen extends ConsumerWidget {
  final RoutineRun run;
  const RoutineRunDetailScreen({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proofStorage = ref.watch(routineSessionProofStorageProvider);
    final userTier = ref.watch(subscriptionProvider);
    return _buildTimelineScreen(
      context,
      proofStorage,
      showSyncState: userTier.hasCloud,
    );
  }

  Widget _buildTimelineScreen(
    BuildContext context,
    RoutineSessionProofStorage proofStorage, {
    required bool showSyncState,
  }) {
    final completionData = _parseCompletionData();
    final steps = _stepsFromCompletionData(completionData);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _getGradientDecoration(context),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(
                context,
                steps,
                proofStorage,
                showSyncState: showSyncState,
              ),
              Expanded(
                child: _buildTimeline(
                  context,
                  steps,
                  completionData,
                  proofStorage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<RoutineStep> steps,
    RoutineSessionProofStorage proofStorage, {
    required bool showSyncState,
  }) {
    final foundation = context.darkFoundation;
    final title = run.routineTitle.trim().isEmpty
        ? 'Deleted routine'
        : run.routineTitle.trim();
    final completionData = _parseCompletionData();
    final completedWindow = _formatCompletedWindow(completionData);
    final photoRefs = _collectRunPhotoRefs();
    final duration = _runDuration(completionData);
    final completedCount = _completedStepCount(completionData);
    final syncState = showSyncState ? _syncStateForRun() : null;
    final photoLabel = photoRefs.length == 1 ? 'Photo taken' : 'Photos taken';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RunBackButton(
                onTap: () {
                  Navigator.of(context).maybePop();
                },
              ),
              const Spacer(),
              if (photoRefs.isNotEmpty)
                _buildPhotoShortcutButton(context, steps, proofStorage),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'COMPLETED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: Color(0xFF8FAF89),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _punctuatedTitle(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 31,
              height: 1.02,
              fontWeight: FontWeight.w800,
              color: foundation.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            completedWindow,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: foundation.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RunStatCard(
                  value:
                      '${completedCount.clamp(0, steps.length)} / ${steps.length}',
                  label: 'Steps done',
                  valueColor: const Color(0xFF8FAF89),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RunStatCard(
                  value: duration == null ? '--' : _formatDuration(duration),
                  label: 'Duration',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RunStatCard(
                  value: '${photoRefs.length}',
                  label: photoLabel,
                ),
              ),
            ],
          ),
          if (syncState != null) ...[
            const SizedBox(height: 10),
            _RunBackupLine(state: syncState),
          ],
          const SizedBox(height: 18),
          Container(height: 1, color: foundation.borderSubtle),
          const SizedBox(height: 14),
          Text(
            'STEPS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: foundation.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoShortcutButton(
    BuildContext context,
    List<RoutineStep> steps,
    RoutineSessionProofStorage proofStorage,
  ) {
    const accentColor = Color(0xFF4A5D4E); // Keep our forest green accent

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showRunPhotosVault(context, steps, proofStorage);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.camera, size: 16, color: accentColor),
            SizedBox(width: 8),
            Text(
              'View Photos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRunPhotosVault(
    BuildContext context,
    List<RoutineStep> steps,
    RoutineSessionProofStorage proofStorage,
  ) {
    final themeData = Theme.of(context);
    final cs = themeData.colorScheme;
    final completionData = _parseCompletionData();
    final stepData = completionData?['steps'] as List<dynamic>? ?? [];
    final allPhotos = <Map<String, dynamic>>[];

    for (var i = 0; i < stepData.length; i++) {
      final stepItem = stepData[i];
      final photos = stepItem['photos'] as List<dynamic>? ?? [];

      // Resolve correct label
      String label = stepItem['label'] ?? 'Step';
      if ((label == 'Step' || label.isEmpty) && i < steps.length) {
        label = _getStepTitle(steps[i]);
      }

      final timeStr = stepItem['completedAt'] ?? '';
      for (final p in photos) {
        allPhotos.add({'path': p, 'label': label, 'time': timeStr});
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    'Run Photos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: cs.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: allPhotos.length,
                itemBuilder: (context, index) {
                  final p = allPhotos[index];
                  return _RunPhotoItem(
                    path: p['path'],
                    label: p['label'],
                    time: p['time'],
                    photos: allPhotos,
                    photoIndex: index,
                    proofStorage: proofStorage,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    List<RoutineStep> steps,
    Map<String, dynamic>? completionData,
    RoutineSessionProofStorage proofStorage,
  ) {
    if (steps.isEmpty) {
      return _buildEmptyState();
    }

    final stepData = completionData?['steps'] as List<dynamic>? ?? [];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final stepCompletion = stepData.length > index ? stepData[index] : null;
        final isCompleted = stepCompletion?['completed'] ?? false;
        final isSkipped = stepCompletion?['skipped'] ?? false;
        final completedAt = stepCompletion?['completedAt'] != null
            ? DateTime.tryParse(stepCompletion['completedAt'])
            : null;

        return _buildTimelineItem(
          context: context,
          step: step,
          stepIndex: index,
          isCompleted: isCompleted,
          isSkipped: isSkipped,
          completedAt: completedAt,
          isLast: index == steps.length - 1,
          stepPhotos: stepCompletion?['photos'] as List<dynamic>? ?? [],
          proofStorage: proofStorage,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required RoutineStep step,
    required int stepIndex,
    required bool isCompleted,
    required bool isSkipped,
    DateTime? completedAt,
    required bool isLast,
    List<dynamic> stepPhotos = const [],
    required RoutineSessionProofStorage proofStorage,
  }) {
    final foundation = context.darkFoundation;
    final timeString = completedAt != null
        ? DateFormat('h:mm a').format(completedAt)
        : null;

    Color indicatorColor;
    Color borderColor;
    Widget indicatorChild;

    if (isCompleted) {
      indicatorColor = const Color(0xFF2F4A36);
      borderColor = indicatorColor;
      indicatorChild = const Icon(
        LucideIcons.check,
        color: Color(0xFFB9D6AC),
        size: 13,
      );
    } else if (isSkipped) {
      indicatorColor = foundation.surfaceHigh;
      borderColor = const Color(0xFF708090);
      indicatorChild = const Icon(
        LucideIcons.stepForward,
        color: Color(0xFFB8C0C8),
        size: 13,
      );
    } else {
      indicatorColor = foundation.surfaceHigh;
      borderColor = foundation.borderSubtle;
      indicatorChild = Text(
        '${stepIndex + 1}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foundation.textMuted,
        ),
      );
    }

    final hasPhotos = stepPhotos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: indicatorColor,
                  border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                ),
                child: Center(child: indicatorChild),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: hasPhotos ? 128 : 58,
                  color: foundation.borderSubtle,
                ),
            ],
          ),

          const SizedBox(width: 14),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  decoration: BoxDecoration(
                    color: foundation.surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPhotos
                          ? const Color(0xFF8D6B45).withValues(alpha: 0.28)
                          : foundation.borderSubtle,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getStepTitle(step),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: foundation.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Step ${stepIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: foundation.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (timeString != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: foundation.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (stepPhotos.isNotEmpty)
                        _buildPhotosSection(stepPhotos, proofStorage),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final foundation = context.darkFoundation;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline, size: 64, color: foundation.textMuted),
              const SizedBox(height: 16),
              Text(
                'No steps found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _getGradientDecoration(BuildContext context) {
    return BoxDecoration(color: context.darkFoundation.bgBase);
  }

  List<RoutineStep> _stepsFromCompletionData(Map<String, dynamic>? data) {
    final effectiveStepsJson = data?['effectiveSteps'] as List<dynamic>?;
    if (effectiveStepsJson != null) {
      return effectiveStepsJson
          .whereType<Map>()
          .map((e) => RoutineStep.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final stepData = data?['steps'] as List<dynamic>? ?? const [];
    return List.generate(stepData.length, (index) {
      final rawStep = stepData[index];
      final label = rawStep is Map && rawStep['label'] != null
          ? rawStep['label'].toString()
          : 'Step ${index + 1}';
      return RoutineStep.check(label: label);
    });
  }

  List<_RunPhotoRef> _collectRunPhotoRefs() {
    final completionData = _parseCompletionData();
    final stepData = completionData?['steps'] as List<dynamic>? ?? const [];
    final refs = <_RunPhotoRef>[];

    for (var i = 0; i < stepData.length; i++) {
      final rawStep = stepData[i];
      if (rawStep is! Map) {
        continue;
      }
      final step = Map<String, dynamic>.from(rawStep);
      final label = (step['label']?.toString().trim().isNotEmpty ?? false)
          ? step['label'].toString()
          : 'Step ${i + 1}';
      final completedAt =
          DateTime.tryParse(step['completedAt']?.toString() ?? '') ??
          run.finishedAt;

      final proofAssets = step['proofAssets'] as List<dynamic>? ?? const [];
      for (final rawAsset in proofAssets) {
        if (rawAsset is! Map) {
          continue;
        }
        final asset = RoutineSessionProofAsset.fromJson(
          Map<String, dynamic>.from(rawAsset),
        );
        if (asset.localRelativePath.isEmpty) {
          continue;
        }
        refs.add(
          _RunPhotoRef(
            path: asset.localRelativePath,
            timestamp: asset.capturedAt,
            label: label,
          ),
        );
      }

      if (proofAssets.isNotEmpty) {
        continue;
      }

      final photos = step['photos'] as List<dynamic>? ?? const [];
      for (final rawPath in photos) {
        final path = rawPath.toString();
        if (path.isEmpty) {
          continue;
        }
        refs.add(
          _RunPhotoRef(path: path, timestamp: completedAt, label: label),
        );
      }
    }

    return refs;
  }

  int _completedStepCount(Map<String, dynamic>? data) {
    final stepData = data?['steps'] as List<dynamic>? ?? const [];
    return stepData.where((step) {
      return step is Map &&
          (step['completed'] == true || step['skipped'] == true);
    }).length;
  }

  Duration? _runDuration(Map<String, dynamic>? data) {
    try {
      final start = DateTime.tryParse(data?['startTime']?.toString() ?? '');
      final end =
          DateTime.tryParse(data?['endTime']?.toString() ?? '') ??
          run.finishedAt;
      if (start == null || end.isBefore(start)) {
        return null;
      }
      return end.difference(start);
    } catch (_) {
      return null;
    }
  }

  _RunSyncState? _syncStateForRun() {
    if (run.syncStatus == 'synced') {
      return _RunSyncState.synced;
    }
    if (run.ownerUserId != null &&
        run.ownerUserId!.isNotEmpty &&
        run.syncStatus != 'localOnly') {
      final normalized = run.syncStatus.toLowerCase();
      if (normalized.contains('failed') || normalized.contains('error')) {
        return _RunSyncState.failed;
      }
      return _RunSyncState.pending;
    }
    return null;
  }

  String _formatCompletedWindow(Map<String, dynamic>? data) {
    final start = DateTime.tryParse(data?['startTime']?.toString() ?? '');
    final end =
        DateTime.tryParse(data?['endTime']?.toString() ?? '') ?? run.finishedAt;
    final date = DateFormat('MMM d, y').format(end);
    final endTime = DateFormat('h:mm a').format(end);

    if (start == null || end.isBefore(start)) {
      return '$date - $endTime';
    }

    final startTime = DateFormat('h:mm a').format(start);
    return '$date - $startTime - $endTime';
  }

  Map<String, dynamic>? _parseCompletionData() {
    try {
      if (run.stepCompletionData == null || run.stepCompletionData!.isEmpty) {
        return null;
      }
      return jsonDecode(run.stepCompletionData!);
    } catch (e) {
      return null;
    }
  }

  String _getStepTitle(RoutineStep step) {
    return step.maybeWhen(
      check:
          (
            label,
            requiresPhoto,
            photoCount,
            photoPrompt,
            allowSkip,
            allowGallery,
            guidanceAudio,
          ) => label,
      orElse: () => 'Unknown step',
    );
  }

  Widget _buildPhotosSection(
    List<dynamic> stepPhotos,
    RoutineSessionProofStorage proofStorage,
  ) {
    final photos = stepPhotos.cast<String>();

    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final foundation = context.darkFoundation;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.camera,
                    size: 12,
                    color: Color(0xFFD4A373),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Photo captured',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: foundation.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: photos.map((photoPath) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildPhotoThumbnail(photoPath, proofStorage),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    String photoPath,
    RoutineSessionProofStorage proofStorage,
  ) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _showPhotoDialog(context, photoPath, proofStorage),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _StoredPhotoView(
              proofStorage: proofStorage,
              storedPath: photoPath,
              fit: BoxFit.cover,
              missing: Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: Icon(
                  Icons.photo,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(
    BuildContext context,
    String photoPath,
    RoutineSessionProofStorage proofStorage,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Container(
              margin: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _StoredPhotoView(
                  proofStorage: proofStorage,
                  storedPath: photoPath,
                  missing: Container(
                    height: 300,
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Icon(
                      LucideIcons.imageOff,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
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

enum _RunSyncState { synced, pending, failed }

class _RunBackButton extends StatelessWidget {
  const _RunBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Tooltip(
      message: 'Back',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: foundation.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: foundation.borderSubtle),
            ),
            child: Icon(
              LucideIcons.chevronLeft,
              size: 20,
              color: foundation.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RunStatCard extends StatelessWidget {
  const _RunStatCard({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Container(
      height: 62,
      padding: const EdgeInsets.fromLTRB(11, 9, 10, 8),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? foundation.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: foundation.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunBackupLine extends StatelessWidget {
  const _RunBackupLine({required this.state});

  final _RunSyncState state;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final (icon, label, color) = switch (state) {
      _RunSyncState.synced => (
        LucideIcons.cloud,
        'Backed up',
        const Color(0xFF8FAF89),
      ),
      _RunSyncState.pending => (
        LucideIcons.cloudUpload,
        'Backup in progress',
        const Color(0xFFD0A24F),
      ),
      _RunSyncState.failed => (
        LucideIcons.cloudAlert,
        'Backup needs attention',
        const Color(0xFFC7856B),
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foundation.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RunPhotoRef {
  const _RunPhotoRef({
    required this.path,
    required this.timestamp,
    required this.label,
  });

  final String path;
  final DateTime timestamp;
  final String label;
}

String _punctuatedTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return 'Routine run';
  }
  if (RegExp(r'[.!?]$').hasMatch(trimmed)) {
    return trimmed;
  }
  return '$trimmed.';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) {
    return '<1 min';
  }
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = duration.inHours;
  final remainder = minutes - (hours * 60);
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

class _RunPhotoItem extends StatelessWidget {
  final String path;
  final String label;
  final String time;
  final List<Map<String, dynamic>> photos;
  final int photoIndex;
  final RoutineSessionProofStorage proofStorage;

  const _RunPhotoItem({
    required this.path,
    required this.label,
    required this.time,
    required this.photos,
    required this.photoIndex,
    required this.proofStorage,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = time.isNotEmpty
        ? DateFormat.jm().format(DateTime.parse(time))
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GestureDetector(
        onTap: () async {
          final galleryPhotos = photos
              .map(
                (photo) => PebbleGalleryPhoto(
                  id: photo['path'] as String,
                  storedPath: photo['path'] as String,
                  title: photo['label'] as String,
                  subtitle: (photo['time'] as String?)?.isNotEmpty == true
                      ? DateFormat.yMMMd().add_jm().format(
                          DateTime.parse(photo['time'] as String),
                        )
                      : null,
                ),
              )
              .toList();
          await PebblePhotoGalleryViewer.open(
            context,
            photos: galleryPhotos,
            initialIndex: photoIndex,
            resolvePhotoFile: proofStorage.resolveStoredFile,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _StoredPhotoView(
                proofStorage: proofStorage,
                storedPath: path,
                fit: BoxFit.cover,
                missing: const Icon(LucideIcons.imageOff),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoredPhotoView extends StatelessWidget {
  const _StoredPhotoView({
    required this.proofStorage,
    required this.storedPath,
    required this.missing,
    this.fit,
  });

  final RoutineSessionProofStorage proofStorage;
  final String storedPath;
  final Widget missing;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: proofStorage.resolveStoredFile(storedPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return Image.file(file, fit: fit);
        }
        return missing;
      },
    );
  }
}
