import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/core/notifications/notification_service.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';

class ReminderSheet extends ConsumerStatefulWidget {
  final Routine routine;
  final RoutineReminder? reminderToEdit;
  const ReminderSheet({super.key, required this.routine, this.reminderToEdit});

  static Future<void> show(
    BuildContext context,
    Routine routine, {
    RoutineReminder? reminderToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ReminderSheet(routine: routine, reminderToEdit: reminderToEdit),
    );
  }

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet>
    with TickerProviderStateMixin {
  Set<int> _selectedDays = <int>{};
  TimeOfDay? _time;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSuccess = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _controller.forward();
    _loadExistingReminder();
  }

  @override
  void dispose() {
    _controller.dispose();
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReminder() async {
    final db = ref.read(localDbProvider);
    final reminders = await db.routineReminderDao.getRemindersForRoutine(
      widget.routine.id,
    );
    RoutineReminder? targetReminder;
    final editingId = widget.reminderToEdit?.id;
    if (editingId != null) {
      for (final reminder in reminders) {
        if (reminder.id == editingId) {
          targetReminder = reminder;
          break;
        }
      }
      targetReminder ??= widget.reminderToEdit;
    }
    if (!mounted) return;
    setState(() {
      _selectedDays = {
        if (targetReminder?.dayOfWeek != null) targetReminder!.dayOfWeek,
      };
      // Start with a time already chosen, like the system alarm app, so
      // saving only needs a day selection.
      _time =
          _parseTime(targetReminder?.time) ??
          const TimeOfDay(hour: 9, minute: 0);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.45,
      maxChildSize: 0.85,
      builder: (context, controller) => ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: _isSuccess
                ? _buildSuccessView(cs)
                : _isLoading
                ? _buildLoadingState(cs)
                : ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      _buildHandle(cs),
                      const SizedBox(height: 20),
                      Text(
                        widget.reminderToEdit == null
                            ? 'Add reminder'
                            : 'Edit reminder',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTimeSelector(cs),
                      const SizedBox(height: 24),
                      _buildDaySelector(cs),
                      const SizedBox(height: 20),
                      _buildSummaryLine(cs),
                      const SizedBox(height: 20),
                      _buildActionButtons(cs),
                      if (widget.reminderToEdit != null) ...[
                        const SizedBox(height: 4),
                        _buildRemoveButton(cs),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(ColorScheme cs) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildTimeSelector(ColorScheme cs) {
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _time != null ? _formatTime(_time!) : 'Choose time',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1.1,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to change time',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(ColorScheme cs) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) => i + 1).map((d) {
            final selected = _selectedDays.contains(d);
            return InkWell(
              onTap: () {
                setState(() {
                  final next = Set<int>.from(_selectedDays);
                  if (selected) {
                    next.remove(d);
                  } else {
                    next.add(d);
                  }
                  _selectedDays = next;
                });
              },
              customBorder: const CircleBorder(),
              child: Semantics(
                label: _weekdayLabel(d),
                selected: selected,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? cs.primary : cs.surfaceContainerHighest,
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    labels[d - 1],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDayPresetChip(
              cs,
              label: 'Every day',
              selected: _selectedDays.length == 7,
              onTap: () => _setSelectedDays(List.generate(7, (i) => i + 1)),
            ),
            const SizedBox(width: 10),
            _buildDayPresetChip(
              cs,
              label: 'Weekdays',
              selected: _isWeekdaysOnly,
              onTap: () => _setSelectedDays(const [1, 2, 3, 4, 5]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayPresetChip(
    ColorScheme cs, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? cs.onPrimaryContainer
                : cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(ColorScheme cs) {
    if (_selectedDays.isEmpty || _time == null) {
      return Text(
        'Pick at least one day.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final nextDate = _calculateNextReminder();
    final daysUntil = nextDate.difference(DateTime.now()).inDays;
    final firstOne = daysUntil == 0
        ? 'later today'
        : daysUntil == 1
        ? 'tomorrow'
        : 'in $daysUntil days';
    return Text(
      '${_selectedDaysSummary()} at ${_formatTime(_time!)}. First one $firstOne.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs) {
    final canSave = _selectedDays.isNotEmpty && _time != null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving || !canSave ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.primary,
              disabledBackgroundColor: cs.surfaceContainerHighest,
            ),
            child: _isSaving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                    ),
                  )
                : Text(
                    widget.reminderToEdit == null
                        ? 'Save reminder'
                        : 'Update reminder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: canSave
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton(ColorScheme cs) {
    if (widget.reminderToEdit == null) return const SizedBox.shrink();

    return Center(
      child: TextButton.icon(
        onPressed: _isSaving ? null : _remove,
        icon: const Icon(LucideIcons.trash2, size: 18),
        label: const Text(
          'Delete reminder',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        style: TextButton.styleFrom(
          foregroundColor: cs.error,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Store original time in case user cancels
    final originalTime = _time;

    // We'll use a DateTime for the Cupertino picker, initially set to current selection or 9:00 AM
    final now = DateTime.now();
    DateTime initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _time?.hour ?? 9,
      _time?.minute ?? 0,
    );

    // If _time is null, set a default so the UI shows something immediately when they start scrolling
    _time ??= const TimeOfDay(hour: 9, minute: 0);

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 320,
        padding: const EdgeInsets.only(top: 6.0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _time = originalTime);
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    'Set Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  CupertinoButton(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _time = TimeOfDay(
                        hour: newDateTime.hour,
                        minute: newDateTime.minute,
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          ScaleTransition(
            scale: _checkAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bellRing,
                color: Colors.green,
                size: 80,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.reminderToEdit == null ? 'Reminder set' : 'Reminder updated',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.reminderToEdit == null
                ? 'Reminder saved. It will repeat on ${_selectedDaysSummary().toLowerCase()}.'
                : 'Reminder updated. It will repeat on ${_selectedDaysSummary().toLowerCase()}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calendar, size: 18, color: cs.primary),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${_selectedDaysSummary()} - ${_formatTime(_time!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GlobalRemindersScreen(routine: widget.routine),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: cs.onSurface,
              ),
              child: Text(
                'Manage reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.surface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty || _time == null) return;

    setState(() => _isSaving = true);

    try {
      final needsNotificationPermission =
          widget.reminderToEdit?.isEnabled ?? true;
      if (needsNotificationPermission &&
          !await NotificationService().hasNotificationPermission()) {
        final accepted = await _showNotificationPermissionRationale();
        if (!accepted) {
          if (mounted) {
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final db = ref.read(localDbProvider);
      final repo = ref.read(routineRepositoryProvider);
      final editingReminder = widget.reminderToEdit;
      final selectedDays = _selectedDays.toList()..sort();
      if (editingReminder != null) {
        final firstDay = selectedDays.first;
        final updatedReminder = editingReminder.copyWith(
          dayOfWeek: firstDay,
          time: _formatTime(_time!),
        );
        await db.routineReminderDao.updateReminder(updatedReminder);
        final insertedReminderIds = <int>[];
        try {
          if (updatedReminder.isEnabled) {
            await NotificationService().scheduleRoutineReminder(
              routineId: widget.routine.id,
              title: widget.routine.title,
              dayOfWeek: updatedReminder.dayOfWeek,
              time: _time!,
              reminderId: updatedReminder.id,
            );
          } else {
            await NotificationService().cancelRoutineReminder(
              widget.routine.id,
              reminderId: updatedReminder.id,
            );
          }
          for (final day in selectedDays.skip(1)) {
            final reminderId = await db.routineReminderDao.addReminder(
              RoutineRemindersCompanion(
                routineId: drift.Value(widget.routine.id),
                dayOfWeek: drift.Value(day),
                time: drift.Value(_formatTime(_time!)),
                isEnabled: drift.Value(updatedReminder.isEnabled),
              ),
            );
            insertedReminderIds.add(reminderId);
            if (updatedReminder.isEnabled) {
              await NotificationService().scheduleRoutineReminder(
                routineId: widget.routine.id,
                title: widget.routine.title,
                dayOfWeek: day,
                time: _time!,
                reminderId: reminderId,
              );
            }
          }
        } catch (e) {
          for (final reminderId in insertedReminderIds) {
            final reminder = await db.routineReminderDao.getReminderById(
              reminderId,
            );
            if (reminder != null) {
              await repo.deleteRoutineReminder(reminder);
            }
            await NotificationService().cancelRoutineReminder(
              widget.routine.id,
              reminderId: reminderId,
            );
          }
          await db.routineReminderDao.updateReminder(editingReminder);
          rethrow;
        }
      } else {
        final insertedReminderIds = <int>[];
        try {
          for (final day in selectedDays) {
            final reminderId = await db.routineReminderDao.addReminder(
              RoutineRemindersCompanion(
                routineId: drift.Value(widget.routine.id),
                dayOfWeek: drift.Value(day),
                time: drift.Value(_formatTime(_time!)),
                isEnabled: const drift.Value(true),
              ),
            );
            insertedReminderIds.add(reminderId);

            await NotificationService().scheduleRoutineReminder(
              routineId: widget.routine.id,
              title: widget.routine.title,
              dayOfWeek: day,
              time: _time!,
              reminderId: reminderId,
            );
          }
        } catch (e) {
          for (final reminderId in insertedReminderIds) {
            final reminder = await db.routineReminderDao.getReminderById(
              reminderId,
            );
            if (reminder != null) {
              await repo.deleteRoutineReminder(reminder);
            }
            await NotificationService().cancelRoutineReminder(
              widget.routine.id,
              reminderId: reminderId,
            );
          }
          rethrow;
        }
      }

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isSaving = false;
        });
        unawaited(_checkController.forward());
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        final errorText = e.toString().toLowerCase().contains('permission')
            ? 'Enable notifications in settings to receive reminders'
            : 'Could not save this reminder. Please try again.';
        ZenNotifications.showWarning(
          context,
          title: 'Permission needed',
          message: errorText,
          actionLabel: 'Settings',
          onAction: () => openAppSettings(),
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<bool> _showNotificationPermissionRationale() async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enable reminders?'),
          content: const Text(
            'Pebble uses notifications only for routine reminders you turn on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _remove() async {
    setState(() => _isSaving = true);

    try {
      final db = ref.read(localDbProvider);
      final repo = ref.read(routineRepositoryProvider);
      final editingReminder = widget.reminderToEdit;

      if (editingReminder != null) {
        await NotificationService().cancelRoutineReminder(
          widget.routine.id,
          reminderId: editingReminder.id,
        );
        await repo.deleteRoutineReminder(editingReminder);

        final remaining = await db.routineReminderDao.getRemindersForRoutine(
          widget.routine.id,
        );
        if (remaining.isEmpty) {
          // Keep the legacy routine-level reminder fields cleared too.
          await repo.updateRoutineReminder(
            id: widget.routine.id,
            reminderDay: null,
            reminderTime: null,
          );
        }

        if (mounted) {
          ZenNotifications.showInfo(context, message: 'Reminder deleted');
          Navigator.pop(context, true);
        }
        return;
      }

      final reminders = await db.routineReminderDao.getRemindersForRoutine(
        widget.routine.id,
      );
      for (final reminder in reminders) {
        await NotificationService().cancelRoutineReminder(
          widget.routine.id,
          reminderId: reminder.id,
        );
      }
      await repo.deleteRoutineRemindersForRoutine(widget.routine.id);

      // Keep the legacy routine-level reminder fields cleared too.
      await repo.updateRoutineReminder(
        id: widget.routine.id,
        reminderDay: null,
        reminderTime: null,
      );

      if (mounted) {
        ZenNotifications.showInfo(context, message: 'All reminders removed');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ZenNotifications.showError(
          context,
          message: 'Could not remove reminders. Please try again.',
        );
      }
    }
  }

  DateTime _calculateNextReminder() {
    if (_selectedDays.isEmpty || _time == null) return DateTime.now();

    final now = DateTime.now();
    DateTime scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      _time!.hour,
      _time!.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    while (!_selectedDays.contains(scheduled.weekday)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  bool get _isWeekdaysOnly =>
      _selectedDays.length == 5 &&
      _selectedDays.containsAll(const [1, 2, 3, 4, 5]);

  void _setSelectedDays(List<int> days) {
    setState(() => _selectedDays = days.toSet());
  }

  String _selectedDaysSummary() {
    final days = _selectedDays.toList()..sort();
    if (days.length == 7) return 'Every day';
    if (_isWeekdaysOnly) return 'Monday to Friday';
    if (days.length == 1) return 'Every ${_weekdayLabel(days.single)}';
    return days.map(_shortWeekdayLabel).join(', ');
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parse(value);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  String _weekdayLabel(int day) {
    const labels = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return labels[day] ?? 'Day $day';
  }

  String _shortWeekdayLabel(int day) {
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return labels[day] ?? 'Day $day';
  }
}
