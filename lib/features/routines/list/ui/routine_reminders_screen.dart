import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/notifications/notification_service.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/shared_alert_preferences_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  SharedAlertContact? _sharedContact;
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
    final alertRepo = ref.read(sharedAlertPreferencesRepositoryProvider);

    final routines = await db.routineDao.watchAllRoutines().first;
    final reminders = widget.routine != null
        ? await db.routineReminderDao.getRemindersForRoutine(widget.routine!.id)
        : await db.routineReminderDao.getAllReminders();
    final remindersByDay = await db.routineReminderDao.getRemindersByDay(
      routineId: widget.routine?.id,
    );

    SharedAlertContact? sharedContact;
    String? sharedContactError;
    if (widget.routine != null) {
      try {
        sharedContact = await alertRepo.getForRoutine(
          routineId: widget.routine!.id,
          routineCloudId: widget.routine!.cloudId,
        );
      } catch (e) {
        sharedContactError = _friendlySharedAlertError(e);
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
                  : 'Routine reminders and shared notifications',
              actions: [
                if (_allReminders.isNotEmpty)
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
                            Tab(text: 'By Day'),
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
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [_buildSharedRemindersCard(cs), const SizedBox(height: 100)],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(cs, 'Reminders', LucideIcons.bell),
        const SizedBox(height: 12),
        if (_allReminders.isEmpty)
          _buildInlineEmptyState(
            cs,
            'No reminders set for this routine.',
            actionLabel: 'Add reminder',
            onAction: _openAddReminderFlow,
          )
        else
          ..._allReminders.map((r) => _buildReminderCard(r, cs)),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSharedRemindersCard(ColorScheme cs) {
    final isLocked = !ref.watch(subscriptionProvider).hasSharedReminders;
    final contact = _sharedContact;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: _buildTrustedContactCardContent(
        cs,
        contact: contact,
        isLocked: isLocked,
      ),
    );
  }

  Widget _buildTrustedContactCardContent(
    ColorScheme cs, {
    required SharedAlertContact? contact,
    required bool isLocked,
  }) {
    if (isLocked) {
      return Row(
        children: [
          Icon(LucideIcons.lock, color: cs.primary.withValues(alpha: 0.48)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Upgrade to add trusted contacts.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (contact == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isSharedContactSaving ? null : _showTrustedContactSheet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactCardHeading(
              cs,
              icon: LucideIcons.mailPlus,
              title: 'Add trusted contact',
            ),
            const SizedBox(height: 12),
            Text(
              'Email someone when this routine is completed.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: cs.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            _buildFlowSteps(cs),
            if (_sharedContactError != null) ...[
              const SizedBox(height: 14),
              _buildInlineMessage(cs, _sharedContactError!, isError: true),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContactStateHeader(cs, contact),
        const SizedBox(height: 14),
        _buildEmailAddressPanel(cs, contact),
        const SizedBox(height: 14),
        if (contact.status == SharedAlertContactStatus.accepted) ...[
          _buildCompletionEmailToggle(cs, contact),
          const SizedBox(height: 14),
        ],
        _buildInlineMessage(
          cs,
          _sharedContactError ?? _sharedContactHelper(contact.status, contact),
          isError: _sharedContactError != null,
        ),
        const SizedBox(height: 18),
        _buildTrustedContactActions(cs, contact),
      ],
    );
  }

  Widget _buildSharedContactStatusPill(
    ColorScheme cs,
    SharedAlertContactStatus status,
  ) {
    final label = switch (status) {
      SharedAlertContactStatus.pending => 'Pending',
      SharedAlertContactStatus.accepted => 'Accepted',
      SharedAlertContactStatus.declined => 'Declined',
      SharedAlertContactStatus.blocked => 'Blocked',
      SharedAlertContactStatus.disabled => 'Off',
    };
    final Color color = switch (status) {
      SharedAlertContactStatus.accepted => cs.primary,
      SharedAlertContactStatus.blocked => cs.error,
      SharedAlertContactStatus.declined => cs.error,
      _ => cs.onSurface.withValues(alpha: 0.58),
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

  Widget _buildContactStateHeader(ColorScheme cs, SharedAlertContact contact) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _sharedContactTitle(contact),
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

  Widget _buildEmailAddressPanel(ColorScheme cs, SharedAlertContact contact) {
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
    SharedAlertContact contact,
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
          Switch(
            value: isOn,
            onChanged: _isSharedContactSaving || _isSharedContactRefreshing
                ? null
                : (enabled) => _setSharedContactToggle(contact, enabled),
            activeThumbColor: cs.primary,
          ),
        ],
      ),
    );
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
    SharedAlertContact contact,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (contact.status == SharedAlertContactStatus.pending)
          OutlinedButton.icon(
            onPressed: _isSharedContactSaving
                ? null
                : () => _showTrustedContactSheet(forceResend: true),
            icon: const Icon(LucideIcons.send, size: 16),
            label: const Text('Resend invite'),
          )
        else if (contact.status == SharedAlertContactStatus.blocked)
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
              contact.status == SharedAlertContactStatus.accepted
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
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
    SharedAlertContact contact,
    bool enabled,
  ) async {
    if (_isSharedContactSaving) return;
    final repo = ref.read(sharedAlertPreferencesRepositoryProvider);
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
      setState(() => _sharedContactError = _friendlySharedAlertError(e));
      ZenNotifications.showError(
        context,
        message: _friendlySharedAlertError(e),
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
      final repo = ref.read(sharedAlertPreferencesRepositoryProvider);
      final contact = await repo.getForRoutine(
        routineId: routine.id,
        routineCloudId: routine.cloudId,
      );
      if (!mounted) return;
      setState(() => _sharedContact = contact);
      ZenNotifications.showInfo(
        context,
        message: _sharedContactStatusMessage(contact),
        title: 'Checked',
      );
    } catch (e) {
      if (!mounted) return;
      final message = _friendlySharedAlertError(e);
      setState(() => _sharedContactError = message);
      ZenNotifications.showError(
        context,
        message: message,
        title: 'Could not check',
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

    SharedAlertContact? contact;
    try {
      contact = await showModalBottomSheet<SharedAlertContact>(
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
                          forceResend ? 'Resend invite' : 'Add trusted contact',
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
                              : 'Enter the email address of someone you trust. Pebble will send them an invite first. They will only receive completion emails if they accept.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.66),
                          ),
                        ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
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
    final isAccepted = contact.status == SharedAlertContactStatus.accepted;
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

  Future<void> _showInviteSentSheet(SharedAlertContact contact) {
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
                  'We have emailed ${contact.recipientEmail}. They need to accept before Pebble can send completion emails for this routine.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You can check the status from this screen.',
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

  Future<void> _confirmRemoveSharedContact(SharedAlertContact contact) async {
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
                  'Remove trusted contact?',
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

  Future<void> _removeSharedContact(SharedAlertContact contact) async {
    if (_isSharedContactSaving) return;
    final repo = ref.read(sharedAlertPreferencesRepositoryProvider);
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
      final message = _friendlySharedAlertError(e);
      setState(() => _sharedContactError = message);
      ZenNotifications.showError(
        context,
        message: message,
        title: 'Could not remove',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactSaving = false);
      }
    }
  }

  Future<void> _submitTrustedContactSheet(
    BuildContext sheetContext,
    Routine routine,
    TextEditingController controller,
    GlobalKey<FormState> formKey,
    StateSetter setSheetState,
    bool Function() isSaving,
    ValueChanged<bool> setSaving,
  ) async {
    if (isSaving() || formKey.currentState?.validate() != true) return;
    FocusScope.of(sheetContext).unfocus();
    setSheetState(() => setSaving(true));
    try {
      final repo = ref.read(sharedAlertPreferencesRepositoryProvider);
      final email = controller.text.trim();
      final isResend =
          email.toLowerCase() == _sharedContact?.recipientEmail.toLowerCase();
      if (mounted) {
        setState(() {
          _isSharedContactSaving = true;
          _sharedContactError = null;
        });
      }
      final contact = await repo.requestContact(
        routineId: routine.id,
        routineCloudId: routine.cloudId,
        recipientEmail: email,
        resend: isResend,
      );
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext, contact);
      }
    } catch (e) {
      if (!sheetContext.mounted) return;
      setSheetState(() => setSaving(false));
      if (mounted) {
        setState(() => _sharedContactError = _friendlySharedAlertError(e));
      }
      ZenNotifications.showError(
        sheetContext,
        message: _friendlySharedAlertError(e),
        title: 'Invitation failed',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharedContactSaving = false);
      }
    }
  }

  String _sharedContactTitle(SharedAlertContact contact) {
    if (contact.status == SharedAlertContactStatus.accepted) {
      return contact.notifyWhenFinished
          ? 'Completion emails are on'
          : 'Completion emails are paused';
    }
    return switch (contact.status) {
      SharedAlertContactStatus.pending => 'Waiting for them to accept',
      SharedAlertContactStatus.accepted => 'Completion emails are on',
      SharedAlertContactStatus.declined => 'Invite declined',
      SharedAlertContactStatus.blocked => 'Future invites blocked',
      SharedAlertContactStatus.disabled => 'Trusted contact removed',
    };
  }

  String _sharedContactHelper(
    SharedAlertContactStatus status,
    SharedAlertContact contact,
  ) {
    if (status == SharedAlertContactStatus.accepted) {
      return contact.notifyWhenFinished
          ? 'Pebble will email this contact when you complete this routine.'
          : 'Completion emails are paused for this routine.';
    }
    return switch (status) {
      SharedAlertContactStatus.pending =>
        'They need to accept the invite before Pebble sends completion emails.',
      SharedAlertContactStatus.accepted =>
        'Pebble will email this contact when you complete this routine.',
      SharedAlertContactStatus.declined =>
        'They declined this invite. You can replace this contact with a different email address.',
      SharedAlertContactStatus.blocked =>
        'They blocked future invites from this account. You can use a different email address.',
      SharedAlertContactStatus.disabled =>
        'Add a trusted contact again when you are ready.',
    };
  }

  String _sharedContactStatusMessage(SharedAlertContact? contact) {
    if (contact == null) {
      return 'No trusted contact is set up for this routine.';
    }
    return switch (contact.status) {
      SharedAlertContactStatus.pending => 'Still waiting for them to accept.',
      SharedAlertContactStatus.accepted =>
        'They have accepted. Pebble can now send completion emails for this routine.',
      SharedAlertContactStatus.declined => 'They declined this invite.',
      SharedAlertContactStatus.blocked => 'They blocked future invites.',
      SharedAlertContactStatus.disabled =>
        'Completion emails are off for this routine.',
    };
  }

  String _friendlySharedAlertError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Could not update shared notification.' : message;
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

  Widget _buildInlineEmptyState(
    ColorScheme cs,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.05),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: cs.primary),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7, // 7 days of the week
      itemBuilder: (context, index) {
        final day = index + 1;
        final dayReminders = _remindersByDay[day] ?? [];

        if (dayReminders.isEmpty) return const SizedBox.shrink();

        return _buildDaySection(day, dayReminders, cs);
      },
    );
  }

  Widget _buildAllView(ColorScheme cs) {
    if (_allReminders.isEmpty) {
      return _buildEmptyState(cs);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allReminders.length,
      itemBuilder: (context, index) {
        final reminder = _allReminders[index];
        return _buildReminderCard(reminder, cs);
      },
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
          Text(
            _weekdayLabel(day),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...reminders.map((reminder) => _buildReminderCard(reminder, cs)),
        ],
      ),
    );
  }

  Widget _buildReminderCard(RoutineReminder reminder, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reminder.isEnabled
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        onTap: () async {
          final db = ref.read(localDbProvider);
          final routine = await db.routineDao.getRoutineById(
            reminder.routineId,
          );
          if (routine != null && mounted) {
            await ReminderSheet.show(
              context,
              routine,
              reminderToEdit: reminder,
            );
            await _loadData();
          }
        },
        title: Text(
          '${reminder.time} - ${_weekdayLabel(reminder.dayOfWeek)}',
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
            Switch(
              value: reminder.isEnabled,
              onChanged: (enabled) => _toggleReminder(reminder, enabled),
              activeThumbColor: cs.primary,
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
              'Add reminders to your routines to get started',
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

  Future<Routine?> _pickRoutineForNewReminder() async {
    final db = ref.read(localDbProvider);
    final routines = await db.routineDao.watchAllRoutines().first;
    if (!mounted) return null;
    if (routines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a routine first before adding reminders.'),
          behavior: SnackBarBehavior.floating,
        ),
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
    await NotificationService().cancelRoutineReminder(
      reminder.routineId,
      reminderId: reminder.id,
    );
    await db.routineReminderDao.deleteReminder(reminder.id);
    final remaining = await db.routineReminderDao.getRemindersForRoutine(
      reminder.routineId,
    );
    if (remaining.isEmpty) {
      final repo = ref.read(routineRepositoryProvider);
      await repo.updateRoutineReminder(
        id: reminder.routineId,
        reminderDay: null,
        reminderTime: null,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadData();
  }

  Future<void> _toggleReminder(RoutineReminder reminder, bool enabled) async {
    final db = ref.read(localDbProvider);
    await db.routineReminderDao.toggleReminder(reminder.id, enabled);

    try {
      if (enabled) {
        final time = _parseTime(reminder.time);
        if (time == null) {
          throw Exception('Invalid reminder time.');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requiresPermission
                  ? 'Notification permission is required to enable reminders.'
                  : 'Could not update reminder. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
            action: requiresPermission
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: () => openAppSettings(),
                  )
                : null,
          ),
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
                    ? 'This will remove all personal reminders for "${widget.routine!.title}".'
                    : 'This will remove all personal reminders across all routines.',
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

    final db = ref.read(localDbProvider);
    if (isRoutineSpecific) {
      await db.routineReminderDao.deleteRemindersForRoutine(widget.routine!.id);
      await NotificationService().cancelAllNotificationsForRoutine(
        widget.routine!.id,
        _allReminders,
      );
    } else {
      await db.routineReminderDao.deleteAllReminders();
      await NotificationService().cancelAllScheduledNotifications();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRoutineSpecific
              ? 'Reminders cleared for routine'
              : 'All reminders cleared',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  TimeOfDay? _parseTime(String timeString) {
    try {
      final time = DateFormat('h:mm a').parse(timeString);
      return TimeOfDay(hour: time.hour, minute: time.minute);
    } catch (_) {
      return null;
    }
  }
}
