import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/core/notifications/notification_service.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  int? _day;
  TimeOfDay? _time;
  bool _everyDay = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSuccess = false;
  bool _hasExistingReminders = false;
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
      _day = targetReminder?.dayOfWeek;
      _time = _parseTime(targetReminder?.time);
      _hasExistingReminders = reminders.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = (_day != null || _everyDay) && _time != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
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
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    children: [
                      _buildHandle(cs),
                      const SizedBox(height: 20),
                      _buildHeader(cs),
                      const SizedBox(height: 32),
                      _buildTimeSelector(cs),
                      const SizedBox(height: 28),
                      _buildDaySelector(cs),
                      if (hasSelection) ...[
                        const SizedBox(height: 28),
                        _buildPreviewCard(cs),
                      ],
                      const SizedBox(height: 32),
                      _buildActionButtons(cs),
                      if (widget.reminderToEdit != null ||
                          _hasExistingReminders) ...[
                        const SizedBox(height: 16),
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

  Widget _buildHeader(ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(LucideIcons.bell, color: cs.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reminderToEdit == null
                    ? 'Add reminder'
                    : 'Edit reminder',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.reminderToEdit == null
                    ? 'Choose a day and time, or set it for every day.'
                    : 'Update the weekly day and time.',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _pickTime();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              gradient: _time != null
                  ? LinearGradient(
                      colors: [
                        cs.primaryContainer,
                        cs.primaryContainer.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _time == null ? cs.surfaceContainerHighest : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _time != null
                    ? cs.primary.withValues(alpha: 0.3)
                    : cs.onSurface.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _time != null
                        ? cs.primary.withValues(alpha: 0.15)
                        : cs.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: _time != null
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _time != null ? _formatTime(_time!) : 'Choose time',
                        style: TextStyle(
                          fontSize: _time != null ? 32 : 20,
                          fontWeight: _time != null
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _time != null
                              ? cs.onPrimaryContainer
                              : cs.onSurface.withValues(alpha: 0.5),
                          letterSpacing: _time != null ? -0.5 : 0,
                        ),
                      ),
                      if (_time != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Tap to change',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_rounded,
                  color: _time != null
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day of the week',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.reminderToEdit == null) ...[
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _everyDay = true;
                _day = null;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: _everyDay
                    ? LinearGradient(
                        colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !_everyDay ? cs.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _everyDay
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.1),
                  width: _everyDay ? 2 : 1,
                ),
                boxShadow: _everyDay
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.repeat,
                    size: 16,
                    color: _everyDay
                        ? cs.onPrimary
                        : cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Every day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _everyDay
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) => i + 1).map((d) {
            final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            final fullLabels = [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ];
            final selected = _day == d;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _everyDay = false;
                      _day = d;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: !selected ? cs.surfaceContainerHighest : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.1),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          labels[d - 1],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullLabels[d - 1],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? cs.onPrimary.withValues(alpha: 0.8)
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ColorScheme cs) {
    final nextDate = _calculateNextReminder();
    final now = DateTime.now();
    final daysUntil = nextDate.difference(now).inDays;
    final hoursUntil = nextDate.difference(now).inHours % 24;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.tertiaryContainer,
            cs.tertiaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.calendar, color: cs.tertiary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _everyDay
                      ? 'Next reminder, then daily'
                      : 'Next reminder, then weekly',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onTertiaryContainer.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _everyDay
                      ? 'Every day at ${_formatTime(_time!)}'
                      : 'Every ${_weekdayLabel(_day!)} at ${_formatTime(_time!)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysUntil == 0
                      ? 'Today in $hoursUntil hours'
                      : 'In $daysUntil ${daysUntil == 1 ? "day" : "days"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onTertiaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs) {
    final canSave = (_day != null || _everyDay) && _time != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: cs.outline),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.circleCheck,
                        size: 20,
                        color: canSave
                            ? cs.onPrimary
                            : cs.onSurface.withValues(alpha: 0.38),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _everyDay
                            ? 'Save daily reminders'
                            : widget.reminderToEdit == null
                            ? 'Save weekly reminder'
                            : 'Update weekly reminder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: canSave
                              ? cs.onPrimary
                              : cs.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
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
            CircularProgressIndicator(color: cs.primary),
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
                      HapticFeedback.mediumImpact();
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
                    HapticFeedback.selectionClick();
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
            widget.reminderToEdit == null
                ? 'Reassurance Scheduled'
                : 'Reminder Updated',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _everyDay
                ? 'Reminders saved. They will repeat every day.'
                : widget.reminderToEdit == null
                ? 'Reminder saved. It will repeat every ${_weekdayLabel(_day!)}.'
                : 'Reminder updated. It will repeat every ${_weekdayLabel(_day!)}.',
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
                Text(
                  _everyDay
                      ? 'Every day · ${_formatTime(_time!)}'
                      : 'Every ${_weekdayLabel(_day!)} · ${_formatTime(_time!)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
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
    if ((_day == null && !_everyDay) || _time == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final db = ref.read(localDbProvider);
      final editingReminder = widget.reminderToEdit;
      if (editingReminder != null) {
        final updatedReminder = editingReminder.copyWith(
          dayOfWeek: _day!,
          time: _formatTime(_time!),
        );
        await db.routineReminderDao.updateReminder(updatedReminder);
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
        } catch (e) {
          await db.routineReminderDao.updateReminder(editingReminder);
          rethrow;
        }
      } else if (_everyDay) {
        final insertedReminderIds = <int>[];
        try {
          for (final day in List.generate(7, (index) => index + 1)) {
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
            await db.routineReminderDao.deleteReminder(reminderId);
            await NotificationService().cancelRoutineReminder(
              widget.routine.id,
              reminderId: reminderId,
            );
          }
          rethrow;
        }
      } else {
        final reminderId = await db.routineReminderDao.addReminder(
          RoutineRemindersCompanion(
            routineId: drift.Value(widget.routine.id),
            dayOfWeek: drift.Value(_day!),
            time: drift.Value(_formatTime(_time!)),
            isEnabled: const drift.Value(true),
          ),
        );

        try {
          // Schedule using the reminder row ID so each reminder has its own
          // notification slot and cannot overwrite siblings.
          await NotificationService().scheduleRoutineReminder(
            routineId: widget.routine.id,
            title: widget.routine.title,
            dayOfWeek: _day!,
            time: _time!,
            reminderId: reminderId,
          );
        } catch (e) {
          // Roll back DB insert if OS scheduling fails.
          await db.routineReminderDao.deleteReminder(reminderId);
          rethrow;
        }
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isSuccess = true;
          _isSaving = false;
        });
        _checkController.forward();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        HapticFeedback.vibrate();
        final errorText = e.toString().toLowerCase().contains('permission')
            ? 'Enable notifications in settings to receive reminders'
            : 'Could not save this reminder. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Permission needed',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(errorText, style: const TextStyle(fontSize: 13)),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final db = ref.read(localDbProvider);
      final editingReminder = widget.reminderToEdit;

      if (editingReminder != null) {
        await NotificationService().cancelRoutineReminder(
          widget.routine.id,
          reminderId: editingReminder.id,
        );
        await db.routineReminderDao.deleteReminder(editingReminder.id);

        final remaining = await db.routineReminderDao.getRemindersForRoutine(
          widget.routine.id,
        );
        if (remaining.isEmpty) {
          // Keep the legacy routine-level reminder fields cleared too.
          final repo = ref.read(routineRepositoryProvider);
          await repo.updateRoutineReminder(
            id: widget.routine.id,
            reminderDay: null,
            reminderTime: null,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Reminder deleted',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.grey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
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
      await db.routineReminderDao.deleteRemindersForRoutine(widget.routine.id);

      // Keep the legacy routine-level reminder fields cleared too.
      final repo = ref.read(routineRepositoryProvider);
      await repo.updateRoutineReminder(
        id: widget.routine.id,
        reminderDay: null,
        reminderTime: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.notifications_off_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'All reminders removed',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove reminders. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  DateTime _calculateNextReminder() {
    if ((_day == null && !_everyDay) || _time == null) return DateTime.now();

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

    if (_everyDay) {
      return scheduled;
    }

    while (scheduled.weekday != _day) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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
}
