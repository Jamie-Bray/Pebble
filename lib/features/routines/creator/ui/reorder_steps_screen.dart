import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';

class ReorderStepsScreen extends ConsumerStatefulWidget {
  final Routine routine;
  const ReorderStepsScreen({super.key, required this.routine});

  @override
  ConsumerState<ReorderStepsScreen> createState() => _ReorderStepsScreenState();
}

class _ReorderStepsScreenState extends ConsumerState<ReorderStepsScreen> {
  late List<RoutineStep> steps;

  @override
  void initState() {
    super.initState();
    steps = _decodeSteps(widget.routine.stepsJson);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const PebbleSubscreenAppBar(title: 'Reorder Steps'),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Drag and drop to adjust your flow.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                return _buildStepTile(step, index, cs);
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = steps.removeAt(oldIndex);
                  steps.insert(newIndex, item);
                });
              },
              proxyDecorator: (child, index, animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.03).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomSafe),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _saveReorder,
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(RoutineStep step, int index, ColorScheme cs) {
    return ClipRRect(
      key: ValueKey('reorder_step_$index'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
            title: Text(
              _getStepLabel(step),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            trailing: const Icon(
              Icons.drag_handle_rounded,
              color: Colors.grey,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  String _getStepLabel(RoutineStep step) {
    return step.map(
      check: (s) => s.label,
      info: (s) => s.message,
      timer: (s) => 'Timer (${s.duration})',
    );
  }

  Future<void> _saveReorder() async {
    final repo = ref.read(routineRepositoryProvider);
    final updated = widget.routine.copyWith(
      stepsJson: _encodeSteps(steps),
      updatedAt: DateTime.now(),
      version: widget.routine.version + 1,
    );
    await repo.saveRoutine(updated);
    await ref
        .read(routineComposerDraftRepositoryProvider)
        .clearEditDraftsForRoutine(widget.routine.id);
    if (!mounted) return;
    ZenNotifications.showSuccess(context, message: 'Step order updated');
    Navigator.pop(context, true);
  }

  List<RoutineStep> _decodeSteps(String stepsJson) {
    try {
      if (stepsJson.isEmpty) return <RoutineStep>[];
      final raw = jsonDecode(stepsJson);
      if (raw is! List) return <RoutineStep>[];
      final list = raw;
      return list.map((e) {
        if (e is Map<String, dynamic>) {
          // Primary path: Freezed JSON with runtimeType
          if (e.containsKey('runtimeType')) {
            return RoutineStep.fromJson(e);
          }
          // Legacy shapes: infer type from keys
          if (e.containsKey('message')) {
            return RoutineStep.info(message: (e['message'] ?? '').toString());
          }
          if (e.containsKey('duration') || e.containsKey('durationSeconds')) {
            final d = (e['duration'] ?? e['durationSeconds'] ?? 0) as int;
            return RoutineStep.timer(duration: d);
          }
          if (e.containsKey('label')) {
            final label = (e['label'] ?? '').toString();
            final requiresPhoto = (e['requiresPhoto'] ?? false) as bool;
            final allowSkip = (e['allowSkip'] ?? true) as bool;
            final photoCount = (e['photoCount'] ?? 1) as int;
            final String? photoPrompt = e['photoPrompt'] as String?;
            return RoutineStep.check(
              label: label,
              requiresPhoto: requiresPhoto,
              photoCount: photoCount,
              photoPrompt: photoPrompt,
              allowSkip: allowSkip,
            );
          }
        }
        // Fallback: represent as info with stringified content
        return RoutineStep.info(message: e.toString());
      }).toList();
    } catch (_) {
      return <RoutineStep>[];
    }
  }

  String _encodeSteps(List<RoutineStep> steps) {
    return jsonEncode(steps.map((s) => s.toJson()).toList());
  }
}
