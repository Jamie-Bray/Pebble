import 'dart:convert';

import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/notifications/notification_service.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/routines/list/ui/reminder_editor_sheet.dart';

class GlobalRemindersScreen extends ConsumerStatefulWidget {
  final Routine? routine;
  final bool emailOnly;
  const GlobalRemindersScreen({
    super.key,
    this.routine,
    this.emailOnly = false,
  });

  @override
  ConsumerState<GlobalRemindersScreen> createState() =>
      _GlobalRemindersScreenState();
}

class _GlobalRemindersScreenState extends ConsumerState<GlobalRemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<int, List<RoutineReminder>> _remindersByDay = {};
  List<RoutineReminder> _allReminders = [];
  Map<int, String> _routineTitles = {};
  SharedReminderContact? _sharedContact;
  String? _sharedContactError;
  bool _isSharedContactRefreshing = false;
  bool _isSharedContactSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.routine != null ? 1 : 2,
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(localDbProvider);
    final reminderRepo = ref.read(sharedReminderPreferencesRepositoryProvider);

    final routines = await db.routineDao.watchAllRoutines().first;
    final reminders = widget.routine != null
        ? await db.routineReminderDao.getRemindersForRoutine(widget.routine!.id)
        : await db.routineReminderDao.getAllReminders();
    final remindersByDay = await db.routineReminderDao.getRemindersByDay(
      routineId: widget.routine?.id,
    );

    SharedReminderContact? sharedContact;
    String? sharedContactError;
    final premiumPolicy = ref.read(premiumFeaturePolicyProvider);
    if (widget.routine != null && premiumPolicy.canUseSharedAlerts) {
      try {
        sharedContact = await reminderRepo.getForRoutine(
          routineId: widget.routine!.id,
          routineCloudId: widget.routine!.cloudId,
        );
      } catch (e) {
        sharedContactError = _friendlySharedReminderError(e);
      }
    }

    if (mounted) {
      setState(() {
        _routineTitles = {
          for (final routine in routines) routine.id: routine.title,
        };
        _allReminders = reminders;
        _remindersByDay = remindersByDay;
        _sharedContact = sharedContact;
        _sharedContactError = sharedContactError;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PremiumFeaturePolicy>(premiumFeaturePolicyProvider, (
      previous,
      next,
    ) {
      if (widget.routine == null) return;
      if (next.canUseSharedAlerts && previous?.canUseSharedAlerts != true) {
        _loadData();
      }
    });

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            PebbleSubpageHeader(
              title: widget.routine != null
                  ? widget.emailOnly
                        ? 'Email'
                        : widget.routine!.title
                  : 'Reminders',
              subtitle: widget.routine != null
                  ? widget.emailOnly
                        ? 'Completion emails for this routine'
                        : 'Reminders for this routine'
                  : 'Reminders for all your routines',
              actions: [
                if (_allReminders.isNotEmpty && !widget.emailOnly)
                  IconButton(
                    onPressed: _showClearAllConfirmation,
                    icon: Icon(LucideIcons.trash2, color: cs.error),
                    tooltip: 'Clear all',
                  ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(cs)
                  : widget.routine != null
                  ? _buildSingleRoutineView(cs)
                  : Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: cs.primary,
                          unselectedLabelColor: cs.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          indicatorColor: cs.primary,
                          tabs: const [
                            Tab(text: 'By day'),
                            Tab(text: 'All'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [_buildByDayView(cs), _buildAllView(cs)],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.routine == null
          ? FloatingActionButton.extended(
              onPressed: _openAddReminderFlow,
              icon: const Icon(LucideIcons.plus),
              label: const Text('New reminder'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            )
          : null,
    );
  }

  Widget _buildSingleRoutineView(ColorScheme cs) {
    if (widget.emailOnly) {
      return AdaptiveContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSharedRemindersCard(cs),
            const SizedBox(height: 100),
          ],
        ),
      );
    }

    return AdaptiveContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildRoutineReminderExperience(cs),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRoutineReminderExperience(ColorScheme cs) {
    final reminders = _allReminders;
    final hasReminders = reminders.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoutineReminderHero(cs, hasReminders: hasReminders),
        const SizedBox(height: 30),
        if (!hasReminders) ...[
          _buildReminderFeatureList(cs),
          const SizedBox(height: 38),
          _buildAddReminderGhostCard(cs),
        ] else ...[
          _buildReminderOverviewStrip(cs, reminders),
          const SizedBox(height: 24),
          _buildSectionTitle(cs, 'Reminders', LucideIcons.calendarClock),
          const SizedBox(height: 12),
          ...reminders.map(
            (reminder) => _buildRoutineReminderCard(reminder, cs),
          ),
          const SizedBox(height: 14),
          _buildAddReminderGhostCard(cs, compact: true),
        ],
      ],
    );
  }

  Widget _buildRoutineReminderHero(
    ColorScheme cs, {
    required bool hasReminders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(LucideIcons.bell, size: 28, color: cs.primary),
        ),
        const SizedBox(height: 20),
        Text(
          hasReminders ? 'Reminders set' : 'No reminders yet',
          style: PebbleType.of(context).title2,
        ),
        const SizedBox(height: 12),
        Text(
          hasReminders
              ? 'Pebble sends these from your phone at the times below. You can pause or change them at any time.'
              : 'Pebble can send a notification at the time you usually do "${widget.routine?.title ?? 'this routine'}".',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: cs.onSurface.withValues(alpha: 0.66),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderFeatureList(ColorScheme cs) {
    return Column(
      children: [
        _buildReminderFeatureItem(
          cs,
          icon: LucideIcons.clock,
          title: 'Pick a time',
          body: 'Any hour and minute you like.',
        ),
        const SizedBox(height: 18),
        _buildReminderFeatureItem(
          cs,
          icon: LucideIcons.calendarDays,
          title: 'Pick the days',
          body: 'Every day, weekdays only, or the days you choose.',
        ),
      ],
    );
  }

  Widget _buildReminderFeatureItem(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Icon(icon, size: 22, color: cs.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderOverviewStrip(
    ColorScheme cs,
    List<RoutineReminder> reminders,
  ) {
    final activeCount = reminders
        .where((reminder) => reminder.isEnabled)
        .length;
    final inactiveCount = reminders.length - activeCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _buildReminderStat(cs, value: '$activeCount', label: 'Active'),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: cs.outline.withValues(alpha: 0.12),
          ),
          _buildReminderStat(cs, value: '$inactiveCount', label: 'Paused'),
          const Spacer(),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.clockCheck, size: 20, color: cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderStat(
    ColorScheme cs, {
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.52),
          ),
        ),
      ],
    );
  }

  Widget _buildAddReminderGhostCard(ColorScheme cs, {bool compact = false}) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: cs.outline.withValues(alpha: 0.32),
        radius: 16,
        strokeWidth: 2,
      ),
      child: Material(
        color: cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openAddReminderFlow,
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: Row(
              children: [
                Container(
                  width: compact ? 36 : 40,
                  height: compact ? 36 : 40,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    size: compact ? 18 : 20,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact
                            ? 'Add another reminder'
                            : 'Add your first reminder',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a time and days',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineReminderCard(RoutineReminder reminder, ColorScheme cs) {
    final isEnabled = reminder.isEnabled;
    final foreground = isEnabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(
          alpha: isEnabled ? 0.52 : 0.26,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? cs.primary.withValues(alpha: 0.24)
              : cs.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editReminder(reminder),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isEnabled ? LucideIcons.bell : LucideIcons.bellOff,
                    size: 19,
                    color: isEnabled
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.42),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatStoredClockTime(context, reminder.time),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_weekdayLabel(reminder.dayOfWeek)} · ${isEnabled ? 'On' : 'Paused'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isEnabled
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete reminder',
                  icon: Icon(LucideIcons.trash2, color: cs.error, size: 18),
                  onPressed: () => _deleteReminder(reminder),
                ),
                Semantics(
                  label:
                      'Reminder at ${formatStoredClockTime(context, reminder.time)}, ${_weekdayLabel(reminder.dayOfWeek)}',
                  child: Switch(
                    value: isEnabled,
                    onChanged: (enabled) => _toggleReminder(reminder, enabled),
                    activeThumbColor: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedRemindersCard(ColorScheme cs) {
    final premiumPolicy = ref.watch(premiumFeaturePolicyProvider);
    final isLocked = !premiumPolicy.canUseSharedAlerts;
    final contact = _sharedContact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrustedContactHero(cs),
        const SizedBox(height: 26),
        if (isLocked) ...[
          _buildEmailFeatureList(cs),
          const SizedBox(height: 28),
          _buildSectionTitle(cs, 'Email preview', LucideIcons.mailCheck),
          const SizedBox(height: 12),
          _buildCompletionEmailPreview(cs, contact: contact),
          const SizedBox(height: 28),
          _buildLockedEmailCta(cs, premiumPolicy),
        ] else if (contact == null) ...[
          _buildEmailFeatureList(cs),
          const SizedBox(height: 28),
          _buildSetupTrustedContactPanel(cs),
          const SizedBox(height: 28),
          _buildSectionTitle(cs, 'Email preview', LucideIcons.mailCheck),
          const SizedBox(height: 12),
          _buildCompletionEmailPreview(cs, contact: contact),
        ] else ...[
          _buildConfiguredTrustedContactPanel(cs, contact),
          const SizedBox(height: 28),
          _buildSectionTitle(cs, 'Email preview', LucideIcons.mailCheck),
          const SizedBox(height: 12),
          _buildCompletionEmailPreview(cs, contact: contact),
        ],
      ],
    );
  }

  Widget _buildTrustedContactHero(ColorScheme cs) {
    return Align(alignment: Alignment.centerLeft, child: _buildPremiumPill(cs));
  }

  Widget _buildPremiumPill(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Text(
        'Premium'.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildEmailFeatureList(ColorScheme cs) {
    return Column(
      children: [
        _buildEmailFeatureItem(
          cs,
          icon: LucideIcons.send,
          title: 'Send a completion email',
          body:
              "Pebble can email one person each time you finish this routine, so you don't have to message them yourself.",
        ),
        const SizedBox(height: 16),
        _buildEmailFeatureItem(
          cs,
          icon: LucideIcons.mailCheck,
          title: 'They choose',
          body:
              'They get an invite first. Nothing is sent unless they accept, and they can stop the emails at any time.',
        ),
        const SizedBox(height: 16),
        _buildEmailFeatureItem(
          cs,
          icon: LucideIcons.shieldCheck,
          title: "What's in the email",
          // The AI sentence shows only where the feature is offered, so
          // nobody reads about something they can't find.
          body:
              'The routine name and each step with the time you checked it (you can hide either), plus the completion time. Photos are never emailed.'
              '${(ref.watch(aiPhotoServerEnabledProvider).valueOrNull ?? false) || ref.watch(aiPhotoControllerProvider).isOn ? ' If you use AI photo descriptions, you can choose to add them. Photos are never emailed.' : ''}',
        ),
      ],
    );
  }

  Widget _buildEmailFeatureItem(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Icon(icon, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.66),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedEmailCta(
    ColorScheme cs,
    PremiumFeaturePolicy premiumPolicy,
  ) {
    final locked = _sharedAlertLockedMessage(premiumPolicy);
    final actionLabel = locked.actionLabel ?? 'Unlocking soon';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: locked.onAction,
          icon: Icon(
            actionLabel == 'Sign in'
                ? LucideIcons.logIn
                : locked.onAction == null
                ? LucideIcons.clock
                : LucideIcons.sparkles,
            size: 18,
          ),
          label: Text(actionLabel),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          locked.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.46),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupTrustedContactPanel(ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isSharedContactSaving ? null : _showTrustedContactSheet,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContactCardHeading(
                cs,
                icon: LucideIcons.mailPlus,
                title: 'Notify someone when you finish',
              ),
              const SizedBox(height: 12),
              Text(
                'Pebble sends an invite first. Completion emails only start after they accept.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 18),
              _buildFlowSteps(cs),
              if (_sharedContactError != null) ...[
                const SizedBox(height: 14),
                _buildInlineMessage(cs, _sharedContactError!, isError: true),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSharedContactSaving
                      ? null
                      : _showTrustedContactSheet,
                  icon: const Icon(LucideIcons.send, size: 17),
                  label: const Text('Add someone to notify'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguredTrustedContactPanel(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactStateHeader(cs, contact),
          const SizedBox(height: 14),
          _buildEmailAddressPanel(cs, contact),
          const SizedBox(height: 14),
          if (contact.status == SharedReminderContactStatus.accepted) ...[
            _buildCompletionEmailToggle(cs, contact),
            const SizedBox(height: 10),
          ],
          if (contact.status == SharedReminderContactStatus.accepted ||
              contact.status == SharedReminderContactStatus.pending) ...[
            _buildRoutineNameToggle(cs, contact),
            const SizedBox(height: 10),
            _buildStepsToggle(cs, contact),
            if (widget.routine != null &&
                ref
                    .watch(aiPhotoControllerProvider)
                    .isOnFor(widget.routine!.id)) ...[
              const SizedBox(height: 10),
              _buildAiDescriptionsToggle(cs),
            ],
            const SizedBox(height: 14),
          ],
          _buildInlineMessage(
            cs,
            _sharedContactError ??
                _sharedReminderContactHelper(contact.status, contact),
            isError: _sharedContactError != null,
          ),
          const SizedBox(height: 18),
          _buildTrustedContactActions(cs, contact),
        ],
      ),
    );
  }

  Widget _buildCompletionEmailPreview(
    ColorScheme cs, {
    required SharedReminderContact? contact,
  }) {
    final previewSentAt = DateTime.now();
    final routineTitle = widget.routine?.title.trim();
    final title = routineTitle == null || routineTitle.isEmpty
        ? 'Bedtime house check'
        : routineTitle;
    final showName = contact?.includeRoutineName ?? true;
    final showSteps = contact?.includeStepCount ?? true;
    final completion = _completionPreviewLine();
    final sentTo = contact?.recipientEmail;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
              border: Border(
                bottom: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.mailCheck,
                    size: 16,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pebble Routines',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Routine completed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat.jm().format(previewSentAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPreviewLogRow(
                  cs,
                  label: 'Routine',
                  value: showName ? title : 'Not shown',
                  highlight: showName,
                ),
                _buildPreviewLogRow(
                  cs,
                  label: 'Completed',
                  value: DateFormat.yMMMd().add_jm().format(previewSentAt),
                ),
                _buildPreviewLogRow(
                  cs,
                  label: 'Steps',
                  value: showSteps ? '$completion, with times' : 'Not shown',
                  isLast: sentTo == null || sentTo.isEmpty,
                ),
                if (sentTo != null && sentTo.isNotEmpty)
                  _buildPreviewLogRow(
                    cs,
                    label: 'To',
                    value: sentTo,
                    isLast: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLogRow(
    ColorScheme cs, {
    required String label,
    required String value,
    bool highlight = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: cs.outline.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.44),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: highlight ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedContactStatusPill(
    ColorScheme cs,
    SharedReminderContactStatus status,
  ) {
    final label = switch (status) {
      SharedReminderContactStatus.pending => 'Pending',
      SharedReminderContactStatus.accepted => 'Accepted',
      SharedReminderContactStatus.declined => 'Declined',
      SharedReminderContactStatus.blocked => 'Not accepting',
      SharedReminderContactStatus.disabled => 'Off',
    };
    final Color color = switch (status) {
      SharedReminderContactStatus.accepted => cs.primary,
      _ => cs.onSurface.withValues(alpha: 0.62),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildContactCardHeading(
    ColorScheme cs, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowSteps(ColorScheme cs) {
    const steps = [
      'Enter their email address.',
      'Pebble sends them an invite.',
      'They can accept or decline.',
      'If they accept, Pebble can email them when this routine is completed.',
    ];
    return Column(
      children: [
        for (var index = 0; index < steps.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == steps.length - 1 ? 0 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: cs.onSurface.withValues(alpha: 0.64),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContactStateHeader(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _sharedReminderContactTitle(contact),
            style: TextStyle(
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildSharedContactStatusPill(cs, contact.status),
      ],
    );
  }

  Widget _buildEmailAddressPanel(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alternate_email_rounded,
            size: 17,
            color: cs.onSurface.withValues(alpha: 0.48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contact.recipientEmail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionEmailToggle(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    final isOn = contact.notifyWhenFinished;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: isOn
            ? cs.primary.withValues(alpha: 0.1)
            : cs.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOn
              ? cs.primary.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completion emails',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOn ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOn
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Completion emails',
            child: Switch(
              value: isOn,
              onChanged: _isSharedContactSaving || _isSharedContactRefreshing
                  ? null
                  : (enabled) => _setSharedContactToggle(contact, enabled),
              activeThumbColor: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineNameToggle(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    final isOn = contact.includeRoutineName;
    return _buildSharingToggle(
      cs,
      title: 'Show the routine name',
      subtitle: isOn
          ? 'The email names this routine.'
          : 'The email says "a routine" instead.',
      value: isOn,
      onChanged: (shown) =>
          _setSharingOptions(contact, includeRoutineName: shown),
    );
  }

  Widget _buildStepsToggle(ColorScheme cs, SharedReminderContact contact) {
    final isOn = contact.includeStepCount;
    return _buildSharingToggle(
      cs,
      title: 'Show each step',
      subtitle: isOn
          ? 'The email lists each step and the time you checked it.'
          : 'The email leaves the steps out.',
      value: isOn,
      onChanged: (shown) =>
          _setSharingOptions(contact, includeStepCount: shown),
    );
  }

  Widget _buildSharingToggle(
    ColorScheme cs, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: title,
            child: Switch(
              value: value,
              onChanged: _isSharedContactSaving || _isSharedContactRefreshing
                  ? null
                  : onChanged,
              activeThumbColor: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Shown only while AI photo descriptions are on for this routine. Off
  /// unless the person turns it on here or answered "Add descriptions".
  Widget _buildAiDescriptionsToggle(ColorScheme cs) {
    final isOn = ref
        .watch(aiPhotoControllerProvider)
        .emailDescriptionsFor(widget.routine!.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add AI photo descriptions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOn
                      ? 'The email includes what AI wrote about your photos. The photos are never emailed.'
                      : 'The email leaves the descriptions out.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Add AI photo descriptions',
            child: Switch(
              value: isOn,
              onChanged: (include) => ref
                  .read(aiPhotoControllerProvider.notifier)
                  .setEmailDescriptions(widget.routine!.id, include),
              activeThumbColor: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setSharingOptions(
    SharedReminderContact contact, {
    bool? includeRoutineName,
    bool? includeStepCount,
  }) async {
    if (_isSharedContactSaving) return;
    final repo = ref.read(sharedReminderPreferencesRepositoryProvider);
    setState(() {
      _isSharedContactSaving = true;
      _sharedContactError = null;
    });
    try {
      final updated = await repo.setSharingOptions(
        contact: contact,
        includeRoutineName: includeRoutineName,
        includeStepCount: includeStepCount,
      );
      if (!mounted) return;
      setState(() => _sharedContact = updated);
    } catch (e) {
      if (!mounted) return;
      final message = _friendlySharedReminderError(e);
      setState(() => _sharedContactError = message);
      ZenNotifications.showError(
        context,
        message: message,
        title: 'Update failed',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactSaving = false);
      }
    }
  }

  Widget _buildInlineMessage(
    ColorScheme cs,
    String message, {
    required bool isError,
  }) {
    final color = isError ? cs.error : cs.onSurface.withValues(alpha: 0.58);
    return Text(
      message,
      style: TextStyle(fontSize: 13, height: 1.42, color: color),
    );
  }

  Widget _buildTrustedContactActions(
    ColorScheme cs,
    SharedReminderContact contact,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (contact.status == SharedReminderContactStatus.pending)
          OutlinedButton.icon(
            onPressed: _isSharedContactSaving
                ? null
                : () => _showTrustedContactSheet(forceResend: true),
            icon: const Icon(LucideIcons.send, size: 16),
            label: const Text('Resend invite'),
          )
        else if (contact.status == SharedReminderContactStatus.blocked)
          OutlinedButton.icon(
            onPressed: _isSharedContactSaving
                ? null
                : () => _showTrustedContactSheet(clearEmail: true),
            icon: const Icon(Icons.alternate_email_rounded, size: 16),
            label: const Text('Use different email'),
          )
        else
          OutlinedButton.icon(
            onPressed: _isSharedContactSaving
                ? null
                : () => _showTrustedContactSheet(clearEmail: true),
            icon: const Icon(Icons.alternate_email_rounded, size: 16),
            label: Text(
              contact.status == SharedReminderContactStatus.accepted
                  ? 'Change contact'
                  : 'Replace contact',
            ),
          ),
        TextButton.icon(
          onPressed: _isSharedContactRefreshing ? null : _refreshSharedContact,
          icon: _isSharedContactRefreshing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            _isSharedContactRefreshing ? 'Checking...' : 'Check status',
          ),
        ),
        TextButton.icon(
          onPressed: _isSharedContactSaving
              ? null
              : () => _confirmRemoveSharedContact(contact),
          icon: const Icon(LucideIcons.trash2, size: 16),
          label: const Text('Remove contact'),
          style: TextButton.styleFrom(foregroundColor: cs.error),
        ),
      ],
    );
  }

  Future<void> _setSharedContactToggle(
    SharedReminderContact contact,
    bool enabled,
  ) async {
    if (_isSharedContactSaving) return;
    final repo = ref.read(sharedReminderPreferencesRepositoryProvider);
    setState(() {
      _isSharedContactSaving = true;
      _sharedContactError = null;
    });
    try {
      final updated = await repo.setNotifyWhenFinished(
        contact: contact,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() => _sharedContact = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharedContactError = _friendlySharedReminderError(e));
      ZenNotifications.showError(
        context,
        message: _friendlySharedReminderError(e),
        title: 'Update failed',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactSaving = false);
      }
    }
  }

  Future<void> _refreshSharedContact() async {
    final routine = widget.routine;
    if (routine == null || _isSharedContactRefreshing) return;
    setState(() {
      _isSharedContactRefreshing = true;
      _sharedContactError = null;
    });
    try {
      final repo = ref.read(sharedReminderPreferencesRepositoryProvider);
      final contact = await repo.getForRoutine(
        routineId: routine.id,
        routineCloudId: routine.cloudId,
      );
      if (!mounted) return;
      setState(() => _sharedContact = contact);
      ZenNotifications.showInfo(
        context,
        message: _sharedReminderContactStatusMessage(contact),
        title: 'Checked',
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlySharedReminderError(e);
      setState(() => _sharedContactError = message);
      ZenNotifications.showError(
        context,
        message: message,
        title: "Couldn't check",
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactRefreshing = false);
      }
    }
  }

  Future<void> _showTrustedContactSheet({
    bool clearEmail = false,
    bool forceResend = false,
  }) async {
    final routine = widget.routine;
    if (routine == null) return;

    final controller = TextEditingController(
      text: clearEmail ? '' : _sharedContact?.recipientEmail ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final cs = Theme.of(context).colorScheme;
    var isSaving = false;
    final initialEmail = controller.text.trim().toLowerCase();
    final accountEmail = ref.read(authSessionProvider).email?.trim();
    final senderEmail = accountEmail == null || accountEmail.isEmpty
        ? null
        : accountEmail;

    SharedReminderContact? contact;
    try {
      contact = await showModalBottomSheet<SharedReminderContact>(
        context: context,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    24 + MediaQuery.viewInsetsOf(ctx).bottom,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.outline.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          forceResend
                              ? 'Resend invite'
                              : 'Add someone to notify',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          forceResend
                              ? 'Pebble will send the invite again. They will only receive completion emails if they accept.'
                              : 'Add someone who knows you and expects these emails. Pebble sends them an invite first, and only emails them after they accept.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.66),
                          ),
                        ),
                        if (senderEmail != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'The emails show your account email, $senderEmail, so they know who they are from.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: cs.onSurface.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            final isValid = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email);
                            return isValid
                                ? null
                                : 'Enter a valid email address.';
                          },
                          onFieldSubmitted: (_) => _submitTrustedContactSheet(
                            ctx,
                            routine,
                            controller,
                            formKey,
                            setSheetState,
                            () => isSaving,
                            (value) => isSaving = value,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                            ),
                            onPressed: isSaving
                                ? null
                                : () => _submitTrustedContactSheet(
                                    ctx,
                                    routine,
                                    controller,
                                    formKey,
                                    setSheetState,
                                    () => isSaving,
                                    (value) => isSaving = value,
                                  ),
                            icon: isSaving
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        cs.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Icon(LucideIcons.send, size: 16),
                            label: Text(
                              isSaving
                                  ? 'Sending invite...'
                                  : (forceResend ||
                                            initialEmail.isNotEmpty &&
                                                initialEmail ==
                                                    _sharedContact
                                                        ?.recipientEmail
                                                        .toLowerCase()
                                        ? 'Resend invite'
                                        : 'Send invite'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
    if (contact == null || !mounted) return;
    setState(() => _sharedContact = contact);
    final isAccepted = contact.status == SharedReminderContactStatus.accepted;
    if (isAccepted) {
      ZenNotifications.showSuccess(
        context,
        message:
            'They have accepted. Pebble can now send completion emails for this routine.',
        title: 'Contact ready',
      );
      return;
    }
    await _showInviteSentSheet(contact);
  }

  Future<void> _showInviteSentSheet(SharedReminderContact contact) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outline.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(LucideIcons.send, color: cs.primary, size: 20),
                ),
                const SizedBox(height: 18),
                Text(
                  'Invite sent',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "We've emailed ${contact.recipientEmail}. Pebble can send completion emails once they accept.",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You can check their reply on this screen.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveSharedContact(
    SharedReminderContact contact,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final shouldRemove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outline.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Stop notifying this person?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pebble will stop sending completion emails for this routine to ${contact.recipientEmail}.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    ),
                    child: const Text('Remove contact'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldRemove == true) {
      await _removeSharedContact(contact);
    }
  }

  Future<void> _removeSharedContact(SharedReminderContact contact) async {
    if (_isSharedContactSaving) return;
    final repo = ref.read(sharedReminderPreferencesRepositoryProvider);
    setState(() {
      _isSharedContactSaving = true;
      _sharedContactError = null;
    });
    try {
      await repo.removeContact(contact: contact);
      if (!mounted) return;
      setState(() => _sharedContact = null);
    } catch (e) {
      if (!mounted) return;
      final message = _friendlySharedReminderError(e);
      setState(() => _sharedContactError = message);
      ZenNotifications.showError(
        context,
        message: message,
        title: "Couldn't remove",
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactSaving = false);
      }
    }
  }

  Future<void> _submitTrustedContactSheet(
    BuildContext ctx,
    Routine routine,
    TextEditingController controller,
    GlobalKey<FormState> formKey,
    StateSetter setSheetState,
    bool Function() getIsSaving,
    void Function(bool) setIsSaving,
  ) async {
    if (getIsSaving()) return;
    if (formKey.currentState?.validate() ?? false) {
      setSheetState(() => setIsSaving(true));
      try {
        final repo = ref.read(sharedReminderPreferencesRepositoryProvider);
        final contact = await repo.requestContact(
          routineId: routine.id,
          recipientEmail: controller.text.trim().toLowerCase(),
          routineCloudId: routine.cloudId,
        );
        if (!ctx.mounted) return;
        Navigator.of(ctx).pop(contact);
      } catch (e) {
        if (!ctx.mounted) return;
        setSheetState(() => setIsSaving(false));
        ZenNotifications.showError(
          ctx,
          message: _friendlySharedReminderError(e),
          title: 'Invite failed',
        );
      }
    }
  }

  String _sharedReminderContactTitle(SharedReminderContact contact) {
    return switch (contact.status) {
      SharedReminderContactStatus.pending => 'Waiting for them to accept',
      SharedReminderContactStatus.accepted =>
        contact.notifyWhenFinished
            ? 'Completion emails are on'
            : 'Completion emails are off',
      SharedReminderContactStatus.declined => 'They declined',
      SharedReminderContactStatus.blocked => 'Not accepting invites',
      SharedReminderContactStatus.disabled => 'Contact removed',
    };
  }

  String _completionPreviewLine() {
    final stepsJson = widget.routine?.stepsJson;
    if (stepsJson == null || stepsJson.isEmpty) return '10 of 10';
    try {
      final decoded = jsonDecode(stepsJson);
      if (decoded is List && decoded.isNotEmpty) {
        return '${decoded.length} of ${decoded.length}';
      }
    } catch (_) {
      // Keep the preview resilient if a local draft has malformed step data.
    }
    return '10 of 10';
  }

  String _sharedReminderContactHelper(
    SharedReminderContactStatus status,
    SharedReminderContact contact,
  ) {
    return switch (status) {
      SharedReminderContactStatus.pending =>
        'Nothing is sent until they accept. The invite expires after 14 days.',
      SharedReminderContactStatus.accepted =>
        contact.notifyWhenFinished
            ? 'Pebble emails them each time you complete this routine.'
            : 'They accepted, but emails are off. Turn them on to send one each time you complete this routine.',
      SharedReminderContactStatus.declined =>
        'Nothing will be sent. You can add a different email address, or invite them again after 30 days.',
      SharedReminderContactStatus.blocked =>
        "This address isn't accepting invitations from your account. You can use a different email address.",
      SharedReminderContactStatus.disabled =>
        'You can add someone again at any time.',
    };
  }

  String _sharedReminderContactStatusMessage(SharedReminderContact? contact) {
    if (contact == null) {
      return 'No one gets completion emails for this routine yet.';
    }
    return switch (contact.status) {
      SharedReminderContactStatus.pending =>
        'Still waiting for them to accept.',
      SharedReminderContactStatus.accepted =>
        'They have accepted. Pebble can now send completion emails for this routine.',
      SharedReminderContactStatus.declined => 'They declined this invite.',
      SharedReminderContactStatus.blocked =>
        "This address isn't accepting invitations from you.",
      SharedReminderContactStatus.disabled =>
        'Completion emails are off for this routine.',
    };
  }

  String _friendlySharedReminderError(Object error) {
    return friendlySharedReminderErrorMessage(error);
  }

  _LockedSharedAlertMessage _sharedAlertLockedMessage(
    PremiumFeaturePolicy policy,
  ) {
    if (!policy.hasActiveLocalPremium) {
      return _LockedSharedAlertMessage(
        message: 'Upgrade to notify someone when you finish.',
        actionLabel: 'View Premium',
        onAction: () =>
            context.push(premiumRoute(source: PremiumEntrySource.general)),
      );
    }
    if (policy.needsSignInForServerFeatures) {
      return _LockedSharedAlertMessage(
        message: 'Sign in to add someone to notify.',
        actionLabel: 'Sign in',
        onAction: () => context.push('/sign-in'),
      );
    }
    if (!policy.hasServerVerifiedPremium) {
      return const _LockedSharedAlertMessage(
        message:
            'Premium is active. Completion emails start once the store confirms your purchase.',
      );
    }
    return const _LockedSharedAlertMessage(
      message: "Completion emails aren't available right now. Try again later.",
    );
  }

  Widget _buildSectionTitle(ColorScheme cs, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading reminders...',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildByDayView(ColorScheme cs) {
    if (_remindersByDay.isEmpty) {
      return _buildEmptyState(cs);
    }

    return AdaptiveContentWidth(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: PebbleSpacing.xl,
          vertical: PebbleSpacing.md,
        ),
        itemCount: 7, // 7 days of the week
        itemBuilder: (context, index) {
          final day = index + 1;
          final dayReminders = _remindersByDay[day] ?? [];

          if (dayReminders.isEmpty) return const SizedBox.shrink();

          return _buildDaySection(day, dayReminders, cs);
        },
      ),
    );
  }

  Widget _buildAllView(ColorScheme cs) {
    if (_allReminders.isEmpty) {
      return _buildEmptyState(cs);
    }

    return AdaptiveContentWidth(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: PebbleSpacing.xl,
          vertical: PebbleSpacing.md,
        ),
        itemCount: _allReminders.length,
        itemBuilder: (context, index) {
          final reminder = _allReminders[index];
          return _buildReminderCard(reminder, cs);
        },
      ),
    );
  }

  Widget _buildDaySection(
    int day,
    List<RoutineReminder> reminders,
    ColorScheme cs,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_weekdayLabel(day), style: PebbleType.of(context).headline),
          const SizedBox(height: 8),
          ...reminders.map((reminder) => _buildReminderCard(reminder, cs)),
        ],
      ),
    );
  }

  Widget _buildReminderCard(RoutineReminder reminder, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PebbleSpacing.xs),
      child: _buildReminderTile(reminder, cs),
    );
  }

  // A Material (not a decorated Container) so the ListTile's ink shows.
  Widget _buildReminderTile(RoutineReminder reminder, ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: PebbleRadius.mdAll,
        side: BorderSide(
          color: reminder.isEnabled
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(
          PebbleSpacing.sm,
          PebbleSpacing.xs,
          PebbleSpacing.xs,
          PebbleSpacing.xs,
        ),
        horizontalTitleGap: PebbleSpacing.sm,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: reminder.isEnabled
                ? cs.primary.withValues(alpha: 0.15)
                : cs.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            LucideIcons.bell,
            color: reminder.isEnabled
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.5),
            size: 16,
          ),
        ),
        onTap: () => _editReminder(reminder),
        title: Text(
          '${formatStoredClockTime(context, reminder.time)} - ${_weekdayLabel(reminder.dayOfWeek)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: reminder.isEnabled
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Text(
          _routineTitles[reminder.routineId] ?? 'Routine ${reminder.routineId}',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Delete reminder',
              icon: Icon(LucideIcons.trash2, color: cs.error, size: 18),
              onPressed: () => _deleteReminder(reminder),
            ),
            Semantics(
              label:
                  'Reminder at ${formatStoredClockTime(context, reminder.time)}, ${_weekdayLabel(reminder.dayOfWeek)}',
              child: Switch(
                value: reminder.isEnabled,
                onChanged: (enabled) => _toggleReminder(reminder, enabled),
                activeThumbColor: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.bellOff, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap New reminder to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddReminderFlow() async {
    Routine? targetRoutine = widget.routine;
    targetRoutine ??= await _pickRoutineForNewReminder();
    if (targetRoutine == null || !mounted) return;
    await ReminderSheet.show(context, targetRoutine);
    await _loadData();
  }

  Future<void> _editReminder(RoutineReminder reminder) async {
    final db = ref.read(localDbProvider);
    final routine = await db.routineDao.getRoutineById(reminder.routineId);
    if (routine == null || !mounted) return;
    await ReminderSheet.show(context, routine, reminderToEdit: reminder);
    await _loadData();
  }

  Future<Routine?> _pickRoutineForNewReminder() async {
    final db = ref.read(localDbProvider);
    final routines = await db.routineDao.watchAllRoutines().first;
    if (!mounted) return null;
    if (routines.isEmpty) {
      ZenNotifications.showInfo(
        context,
        message: 'Create a routine first, then add a reminder to it.',
      );
      return null;
    }

    return showModalBottomSheet<Routine>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Choose a routine',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...routines.map(
                (routine) => ListTile(
                  leading: const Icon(Icons.list_alt_rounded),
                  title: Text(routine.title),
                  onTap: () => Navigator.of(ctx).pop(routine),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteReminder(RoutineReminder reminder) async {
    final db = ref.read(localDbProvider);
    final repo = ref.read(routineRepositoryProvider);
    await NotificationService().cancelRoutineReminder(
      reminder.routineId,
      reminderId: reminder.id,
    );
    await repo.deleteRoutineReminder(reminder);
    final remaining = await db.routineReminderDao.getRemindersForRoutine(
      reminder.routineId,
    );
    if (remaining.isEmpty) {
      await repo.updateRoutineReminder(
        id: reminder.routineId,
        reminderDay: null,
        reminderTime: null,
      );
    }
    if (!mounted) return;
    // The reminder disappearing from the list is its own confirmation.
    await _loadData();
  }

  Future<void> _toggleReminder(RoutineReminder reminder, bool enabled) async {
    final db = ref.read(localDbProvider);
    await db.routineReminderDao.toggleReminder(reminder.id, enabled);

    try {
      if (enabled) {
        final time = _parseTime(reminder.time);
        if (time == null) {
          throw Exception("Couldn't read this reminder's time.");
        }
        final routine = await db.routineDao.getRoutineById(reminder.routineId);
        await NotificationService().scheduleRoutineReminder(
          routineId: reminder.routineId,
          title: routine?.title ?? 'Routine',
          dayOfWeek: reminder.dayOfWeek,
          time: time,
          reminderId: reminder.id,
        );
      } else {
        await NotificationService().cancelRoutineReminder(
          reminder.routineId,
          reminderId: reminder.id,
        );
      }
    } catch (e) {
      await db.routineReminderDao.toggleReminder(reminder.id, !enabled);
      if (mounted) {
        final requiresPermission = e.toString().toLowerCase().contains(
          'permission',
        );
        ZenNotifications.showWarning(
          context,
          message: requiresPermission
              ? 'Notifications are off for Pebble. Turn them on in Settings to get reminders.'
              : "Couldn't update the reminder. Try again.",
          actionLabel: requiresPermission ? 'Settings' : null,
          onAction: requiresPermission ? () => openAppSettings() : null,
        );
      }
    }
    await _loadData();
  }

  Future<void> _showClearAllConfirmation() async {
    final cs = Theme.of(context).colorScheme;
    final isRoutineSpecific = widget.routine != null;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRoutineSpecific
                    ? 'Clear these reminders?'
                    : 'Clear all reminders?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isRoutineSpecific
                    ? 'This deletes every reminder for "${widget.routine!.title}".'
                    : 'This deletes every reminder for all your routines.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep reminders'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error.withValues(alpha: 0.14),
                    foregroundColor: cs.error,
                  ),
                  child: const Text('Clear reminders'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    final repo = ref.read(routineRepositoryProvider);
    final affectedRoutineIds = _allReminders
        .map((reminder) => reminder.routineId)
        .toSet();
    if (isRoutineSpecific) {
      await repo.deleteRoutineRemindersForRoutine(widget.routine!.id);
      await NotificationService().cancelAllNotificationsForRoutine(
        widget.routine!.id,
        _allReminders,
      );
      await repo.updateRoutineReminder(
        id: widget.routine!.id,
        reminderDay: null,
        reminderTime: null,
      );
    } else {
      await repo.deleteAllRoutineReminders();
      await NotificationService().cancelAllScheduledNotifications();
      for (final routineId in affectedRoutineIds) {
        await repo.updateRoutineReminder(
          id: routineId,
          reminderDay: null,
          reminderTime: null,
        );
      }
    }

    if (!mounted) return;
    // The cleared list is its own confirmation.
    await _loadData();
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

  TimeOfDay? _parseTime(String timeString) => parseStoredClockTime(timeString);
}

class _LockedSharedAlertMessage {
  const _LockedSharedAlertMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  static const double _dashLength = 7;
  static const double _gapLength = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            next < metric.length ? next : metric.length,
          ),
          paint,
        );
        distance += _dashLength + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

const _sharedReminderFallbackError =
    "Couldn't update completion emails. Try again.";

String friendlySharedReminderErrorMessage(Object error) {
  final raw = error.toString();
  final message = raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('SharedReminderRepositoryException: ', '')
      .replaceFirst('FunctionException', '')
      .trim();
  if (message.contains('Shared alert environment is not configured')) {
    return "Completion emails aren't available right now. Try again later.";
  }
  if (message.contains('Personal Premium is required')) {
    return 'Premium is required to notify someone.';
  }
  if (message.contains('Missing user authorization') ||
      message.contains('Invalid user authorization')) {
    return 'Sign in again to manage who gets notified.';
  }
  if (message.contains('has blocked invites from this account')) {
    return "This address isn't accepting invitations from you.";
  }
  if (message.contains('Shared alert contact was not found')) {
    return 'This contact was removed. Check the status and try again.';
  }
  // Raw transport or provider text is never shown.
  if (message.isEmpty ||
      message.startsWith('(status:') ||
      message.startsWith('status:') ||
      message.contains('{') ||
      message.length > 200) {
    return _sharedReminderFallbackError;
  }
  return message;
}
