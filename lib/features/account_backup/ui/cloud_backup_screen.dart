import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/backup_dashboard_presentation_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';

class CloudBackupScreen extends ConsumerStatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  ConsumerState<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends ConsumerState<CloudBackupScreen> {
  bool _manualSyncInFlight = false;
  bool _consentInFlight = false;
  bool _linkLocalDataInFlight = false;
  bool _verificationInFlight = false;

  void _exitBackup() {
    if (!mounted) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/account-hub');
    }
  }

  void _showBackupNotice(
    String message, {
    String? title,
    NotificationType type = NotificationType.info,
  }) {
    if (!mounted) {
      return;
    }
    switch (type) {
      case NotificationType.success:
        ZenNotifications.showSuccess(context, title: title, message: message);
      case NotificationType.info:
        ZenNotifications.showInfo(context, title: title, message: message);
      case NotificationType.warning:
        ZenNotifications.showWarning(context, title: title, message: message);
      case NotificationType.error:
        ZenNotifications.showError(context, title: title, message: message);
    }
  }

  Future<void> _reviewLocalDataForCurrentAccount(String? email) async {
    final userId = ref.read(authSessionProvider).userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showBackupNotice(
        'Sign in before linking local data.',
        title: 'Sign-in needed',
        type: NotificationType.warning,
      );
      return;
    }

    final report = await LocalDataOwnershipGuard.inspect(
      database: ref.read(localDbProvider),
      signedInUserId: userId,
    );
    if (!mounted) {
      return;
    }

    if (report.state == LocalDataOwnershipState.empty ||
        report.state == LocalDataOwnershipState.sameOwnerOnly) {
      try {
        await _prepareBackupAfterOwnershipChoice(userId);
      } catch (error) {
        _showBackupNotice(
          _toUserFacingError(error),
          title: 'Backup setup failed',
          type: NotificationType.error,
        );
        return;
      }
      _showBackupNotice(
        'This device is already linked to your account.',
        title: 'Already linked',
        type: NotificationType.info,
      );
      return;
    }

    if (report.differentOwnerCount > 0) {
      final confirmed = await _showUseCurrentAccountDialog(
        email: email,
        report: report,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _useCurrentAccountForLocalData(userId);
      return;
    }

    final confirmed = await _showLinkLocalDataDialog(
      email: email,
      unownedCount: report.unownedCount,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _linkLocalDataToCurrentAccount(userId);
  }

  Future<bool?> _showUseCurrentAccountDialog({
    required String? email,
    required LocalDataOwnershipReport report,
  }) {
    final itemCount =
        report.unownedCount +
        report.sameOwnerCount +
        report.differentOwnerCount;
    final itemLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';
    return _showBackupActionSheet<bool>(
      context: context,
      builder: (sheetContext) => _BackupActionSheet(
        icon: LucideIcons.userCheck,
        eyebrow: 'Backup',
        title: 'Use this account for this device?',
        body:
            'This device has Pebble data from another sign-in. Use ${email ?? 'this account'} from now on so backup can continue.',
        accentColor: Theme.of(sheetContext).colorScheme.primary,
        details: [
          _BackupSheetPillRow(
            pills: [
              _BackupSheetPill(value: itemLabel, label: 'On this device'),
              const _BackupSheetPill(value: 'Current', label: 'Account'),
              const _BackupSheetPill(value: 'Backup', label: 'After choice'),
            ],
          ),
        ],
        primaryLabel: 'Use this account',
        onPrimaryPressed: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep backup off',
        onSecondaryPressed: () => Navigator.of(sheetContext).pop(false),
        footer:
            'Pebble will only upload this device\'s routines after you choose.',
      ),
    );
  }

  Future<bool?> _showLinkLocalDataDialog({
    required String? email,
    required int unownedCount,
  }) {
    final itemLabel = '$unownedCount item${unownedCount == 1 ? '' : 's'}';
    return _showBackupActionSheet<bool>(
      context: context,
      builder: (sheetContext) => _BackupActionSheet(
        icon: LucideIcons.link,
        eyebrow: 'Backup',
        title: 'Link this device\'s data?',
        body:
            'Pebble found $itemLabel on this device. Link them to ${email ?? 'this account'} so backup can start, or keep them local.',
        accentColor: Theme.of(sheetContext).colorScheme.primary,
        details: [
          _BackupSheetPillRow(
            pills: [
              _BackupSheetPill(value: itemLabel, label: 'Found here'),
              const _BackupSheetPill(value: 'Backup', label: 'After linking'),
              const _BackupSheetPill(value: 'Local', label: 'Optional'),
            ],
          ),
        ],
        primaryLabel: 'Link to this account',
        onPrimaryPressed: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep local',
        onSecondaryPressed: () => Navigator.of(sheetContext).pop(false),
        footer: 'Pebble will not upload this device\'s data unless you choose.',
      ),
    );
  }

  Future<void> _linkLocalDataToCurrentAccount(String userId) async {
    if (_linkLocalDataInFlight) {
      return;
    }
    setState(() => _linkLocalDataInFlight = true);
    try {
      await LocalDataOwnershipGuard.linkUnownedLocalData(
        database: ref.read(localDbProvider),
        signedInUserId: userId,
      );
      await _prepareBackupAfterOwnershipChoice(userId);
      _showBackupNotice(
        'Linked to this account. Backup can start now.',
        title: 'Data linked',
        type: NotificationType.success,
      );
    } catch (error) {
      final message = _toUserFacingError(error);
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(message);
      _showBackupNotice(
        message,
        title: 'Could not link',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _linkLocalDataInFlight = false);
      }
    }
  }

  Future<void> _useCurrentAccountForLocalData(String userId) async {
    if (_linkLocalDataInFlight) {
      return;
    }
    setState(() => _linkLocalDataInFlight = true);
    try {
      await LocalDataOwnershipGuard.useCurrentAccountForLocalData(
        database: ref.read(localDbProvider),
        signedInUserId: userId,
      );
      await _prepareBackupAfterOwnershipChoice(userId);
      _showBackupNotice(
        'This device now uses your signed-in account for backup.',
        title: 'Backup is on',
        type: NotificationType.success,
      );
    } catch (error) {
      final message = _toUserFacingError(error);
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(message);
      _showBackupNotice(
        message,
        title: 'Could not continue',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _linkLocalDataInFlight = false);
      }
    }
  }

  Future<void> _prepareBackupAfterOwnershipChoice(String userId) async {
    await ref
        .read(subscriptionAccountControllerProvider.notifier)
        .updateBootstrapStatus(BootstrapStatus.preparing, clearError: true);
    try {
      await ref.read(cloudRestoreCoordinatorProvider).bootstrapAndMerge(userId);
    } catch (error) {
      // A failed merge must not leave the account stuck on "preparing":
      // surface a retryable error state, then let the caller report it.
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .updateBootstrapStatus(
            BootstrapStatus.error,
            error: _toUserFacingError(error),
          );
      rethrow;
    }
    await ref
        .read(subscriptionAccountControllerProvider.notifier)
        .updateBootstrapStatus(BootstrapStatus.ready, clearError: true);
    unawaited(ref.read(cloudSyncCoordinatorProvider).kick());
  }

  Future<void> _runManualSync() async {
    if (_manualSyncInFlight) {
      return;
    }
    setState(() => _manualSyncInFlight = true);
    final result = await ref.read(cloudSyncCoordinatorProvider).runManualSync();
    if (!mounted) {
      return;
    }
    setState(() => _manualSyncInFlight = false);

    switch (result.type) {
      case ManualSyncResultType.synced:
        _showBackupNotice(
          'Backup is up to date.',
          title: 'All caught up',
          type: NotificationType.success,
        );
      case ManualSyncResultType.noChanges:
        _showBackupNotice(
          'There are no backup changes waiting.',
          title: 'All caught up',
          type: NotificationType.success,
        );
      case ManualSyncResultType.partialRetryScheduled:
        _showBackupNotice(
          result.message,
          title: 'Backup will retry',
          type: NotificationType.warning,
        );
      case ManualSyncResultType.blockedSignedOut:
      case ManualSyncResultType.blockedNoEntitlement:
      case ManualSyncResultType.blockedConsentRequired:
      case ManualSyncResultType.blockedAccountSwitch:
      case ManualSyncResultType.blockedOffline:
      case ManualSyncResultType.failed:
        _showBackupNotice(
          result.message,
          title: 'Backup not finished',
          type: NotificationType.warning,
        );
    }
  }

  Future<void> _refreshBackupVerification() async {
    if (_verificationInFlight) {
      return;
    }
    setState(() => _verificationInFlight = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
      _showBackupNotice(
        'Pebble checked Premium and backup for this account.',
        title: 'Status refreshed',
        type: NotificationType.success,
      );
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: 'Could not refresh',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _verificationInFlight = false);
      }
    }
  }

  Future<void> _showCloudBackupConsentDialog() async {
    if (_consentInFlight) {
      return;
    }

    var accepted = false;
    await _showBackupActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return _BackupActionSheet(
              icon: LucideIcons.cloudUpload,
              eyebrow: 'Backup',
              title: 'Turn on backup?',
              body:
                  'Pebble will only start backup after you choose. Supported routine data can upload for restore when backup is on.',
              accentColor: Theme.of(sheetContext).colorScheme.primary,
              details: [
                _BackupConsentCheck(
                  accepted: accepted,
                  enabled: !_consentInFlight,
                  onChanged: (value) {
                    setDialogState(() => accepted = value == true);
                  },
                ),
              ],
              primaryLabel: 'Turn on backup',
              primaryEnabled: accepted && !_consentInFlight,
              onPrimaryPressed: () async {
                Navigator.of(sheetContext).pop();
                await _acceptCloudBackupConsent();
              },
              secondaryLabel: 'Cancel',
              secondaryEnabled: !_consentInFlight,
              onSecondaryPressed: () => Navigator.of(sheetContext).pop(),
              footer:
                  'You can pause backup later. Local routines stay on this device either way.',
            );
          },
        );
      },
    );
  }

  Future<void> _acceptCloudBackupConsent() async {
    if (_consentInFlight) {
      return;
    }
    setState(() => _consentInFlight = true);
    try {
      await ref.read(cloudBackupConsentControllerProvider.notifier).accept();
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
      _showBackupNotice(
        'Pebble will back up supported routine data for this account.',
        title: 'Backup is on',
        type: NotificationType.success,
      );
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: 'Could not turn on backup',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _consentInFlight = false);
      }
    }
  }

  Future<void> _showWithdrawCloudBackupConsentDialog() async {
    await _showBackupActionSheet<void>(
      context: context,
      builder: (sheetContext) => _BackupActionSheet(
        icon: LucideIcons.cloudOff,
        eyebrow: 'Backup',
        title: 'Pause backup?',
        body:
            'Pebble will stop saving new backup changes for this account. Local routines stay on this device.',
        accentColor: Theme.of(sheetContext).colorScheme.secondary,
        details: const [
          _BackupSheetPillRow(
            pills: [
              _BackupSheetPill(value: 'Stops', label: 'New uploads'),
              _BackupSheetPill(value: 'Keeps', label: 'Local data'),
              _BackupSheetPill(value: 'Resume', label: 'Any time'),
            ],
          ),
        ],
        primaryLabel: 'Pause backup',
        primaryTone: _BackupSheetButtonTone.warning,
        onPrimaryPressed: () async {
          Navigator.of(sheetContext).pop();
          await _withdrawCloudBackupConsent();
        },
        secondaryLabel: 'Cancel',
        onSecondaryPressed: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _withdrawCloudBackupConsent() async {
    if (_consentInFlight) {
      return;
    }
    setState(() => _consentInFlight = true);
    try {
      await ref.read(cloudBackupConsentControllerProvider.notifier).withdraw();
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
      _showBackupNotice(
        'Local routines remain on this device.',
        title: 'Backup is paused',
        type: NotificationType.info,
      );
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: 'Could not pause backup',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _consentInFlight = false);
      }
    }
  }

  void _handleAction(BackupDashboardAction action) {
    switch (action) {
      case BackupDashboardAction.none:
        return;
      case BackupDashboardAction.signIn:
        context.push('/sign-in');
      case BackupDashboardAction.getPremium:
        context.push('/paywall');
      case BackupDashboardAction.turnOnBackup:
        _showCloudBackupConsentDialog();
      case BackupDashboardAction.pauseBackup:
      case BackupDashboardAction.keepBackupOff:
        _showWithdrawCloudBackupConsentDialog();
      case BackupDashboardAction.backUpNow:
        _runManualSync();
      case BackupDashboardAction.tryAgain:
        _refreshBackupVerification();
      case BackupDashboardAction.useCurrentAccount:
        _reviewLocalDataForCurrentAccount(ref.read(authSessionProvider).email);
    }
  }

  bool _isActionBusy(BackupDashboardAction action) {
    return switch (action) {
      BackupDashboardAction.turnOnBackup ||
      BackupDashboardAction.pauseBackup ||
      BackupDashboardAction.keepBackupOff => _consentInFlight,
      BackupDashboardAction.backUpNow => _manualSyncInFlight,
      BackupDashboardAction.tryAgain => _verificationInFlight,
      BackupDashboardAction.useCurrentAccount => _linkLocalDataInFlight,
      _ => false,
    };
  }

  bool _showHeroAction(BackupDashboardPresentation presentation) {
    return presentation.primaryActionLabel != null &&
        presentation.primaryAction != BackupDashboardAction.none &&
        presentation.primaryAction != BackupDashboardAction.useCurrentAccount &&
        presentation.primaryAction != BackupDashboardAction.keepBackupOff;
  }

  void _handleBackupSwitch(bool enabled) {
    if (enabled) {
      _showCloudBackupConsentDialog();
    } else {
      _showWithdrawCloudBackupConsentDialog();
    }
  }

  String _toUserFacingError(Object error) {
    if (error is PurchaseFlowException) {
      return error.message;
    }
    final raw = error.toString();
    if (raw.startsWith('StateError: ')) {
      return raw.replaceFirst('StateError: ', '');
    }
    if (raw.startsWith('PlatformException')) {
      return 'The store could not complete that request. Please try again.';
    }
    if (raw.startsWith('FunctionException')) {
      return 'Pebble could not complete that request. Please try again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final presentation = ref.watch(backupDashboardPresentationProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitBackup();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: PebbleSubscreenAppBar(
          title: 'Backup',
          subtitle: 'A safe copy of your routines',
          onBack: _exitBackup,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          children: [
            _BackupStatusCard(
              state: presentation,
              onSwitchChanged: presentation.backupSwitchEnabled
                  ? _handleBackupSwitch
                  : null,
              primaryBusy: _isActionBusy(presentation.primaryAction),
              onPrimary: _showHeroAction(presentation)
                  ? () => _handleAction(presentation.primaryAction)
                  : null,
            ),
            if (presentation.pendingBannerText != null) ...[
              const SizedBox(height: 12),
              _PendingChangesBanner(text: presentation.pendingBannerText!),
            ],
            if (presentation.showOwnershipMismatch) ...[
              const SizedBox(height: 16),
              _OwnershipMismatchCard(
                state: presentation,
                onUseCurrentAccount:
                    _isActionBusy(BackupDashboardAction.useCurrentAccount)
                    ? null
                    : () => _handleAction(
                        BackupDashboardAction.useCurrentAccount,
                      ),
                onKeepBackupOff:
                    _isActionBusy(BackupDashboardAction.keepBackupOff)
                    ? null
                    : () => _handleAction(BackupDashboardAction.keepBackupOff),
              ),
            ],
            const SizedBox(height: 24),
            _BackupDataSection(
              items: presentation.dataItems,
              live: presentation.dataItemsLive,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupStatusCard extends StatelessWidget {
  const _BackupStatusCard({
    required this.state,
    required this.onSwitchChanged,
    required this.primaryBusy,
    required this.onPrimary,
  });

  final BackupDashboardPresentation state;
  final ValueChanged<bool>? onSwitchChanged;
  final bool primaryBusy;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _toneColor(colorScheme, state.tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: state.needsAttention
              ? accent.withValues(alpha: 0.32)
              : colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ToneIcon(icon: state.icon, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              state.statusLabel,
                              style: GoogleFonts.dmSerifDisplay(
                                color: colorScheme.onSurface,
                                fontSize: 30,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                height: 1.05,
                              ),
                            ),
                          ),
                          // A switch you cannot use is noise: only show it
                          // while backup is on, where flipping it means pause.
                          if (state.backupSwitchValue) ...[
                            const SizedBox(width: 12),
                            Switch.adaptive(
                              value: state.backupSwitchValue,
                              onChanged: onSwitchChanged,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.detail,
                        style: GoogleFonts.outfit(
                          color: colorScheme.onSurface.withValues(alpha: 0.68),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _BackupSetupChecklist(steps: state.setupSteps),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (state.needsAttention)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              state.lastBackupText,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onPrimary != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: primaryBusy ? null : onPrimary,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(_buttonIcon(state.primaryAction), size: 18),
                label: Text(
                  primaryBusy ? 'Working...' : state.primaryActionLabel ?? '',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupSetupChecklist extends StatelessWidget {
  const _BackupSetupChecklist({required this.steps});

  final List<BackupSetupStep> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          _BackupSetupRow(step: steps[index]),
          if (index != steps.length - 1)
            Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.10),
            ),
        ],
      ],
    );
  }
}

class _BackupSetupRow extends StatelessWidget {
  const _BackupSetupRow({required this.step});

  final BackupSetupStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrent =
        step.state == BackupSetupStepState.current ||
        step.state == BackupSetupStepState.attention;
    final color = switch (step.state) {
      BackupSetupStepState.done => colorScheme.primary,
      BackupSetupStepState.current => colorScheme.tertiary,
      BackupSetupStepState.attention => colorScheme.error,
      BackupSetupStepState.locked => colorScheme.onSurface.withValues(
        alpha: 0.36,
      ),
    };
    final stateIcon = switch (step.state) {
      BackupSetupStepState.done => LucideIcons.circleCheck,
      BackupSetupStepState.current => LucideIcons.circle,
      BackupSetupStepState.attention => LucideIcons.circleAlert,
      BackupSetupStepState.locked => LucideIcons.lock,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isCurrent ? 0.14 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(stateIcon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(step.icon, size: 15, color: color),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        step.label,
                        style: GoogleFonts.outfit(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  step.detail,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface.withValues(
                      alpha: step.state == BackupSetupStepState.locked
                          ? 0.48
                          : 0.66,
                    ),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingChangesBanner extends StatelessWidget {
  const _PendingChangesBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.cloudUpload, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupDataSection extends StatelessWidget {
  const _BackupDataSection({required this.items, required this.live});

  final List<BackupDataItem> items;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            live ? "What's backed up" : 'What gets backed up',
            style: GoogleFonts.outfit(
              color: colorScheme.onSurface.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _BackupDataRow(item: items[index]),
                  if (index != items.length - 1)
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.10),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupDataRow extends StatelessWidget {
  const _BackupDataRow({required this.item});

  final BackupDataItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (IconData stateIcon, Color stateColor) = switch (item.state) {
      BackupDataItemState.saved => (LucideIcons.check, colorScheme.primary),
      BackupDataItemState.attention => (
        LucideIcons.circleAlert,
        colorScheme.error,
      ),
      BackupDataItemState.off => (
        LucideIcons.minus,
        colorScheme.onSurface.withValues(alpha: 0.30),
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 19,
            color: colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(stateIcon, size: 18, color: stateColor),
        ],
      ),
    );
  }
}

class _OwnershipMismatchCard extends StatelessWidget {
  const _OwnershipMismatchCard({
    required this.state,
    required this.onUseCurrentAccount,
    required this.onKeepBackupOff,
  });

  final BackupDashboardPresentation state;
  final VoidCallback? onUseCurrentAccount;
  final VoidCallback? onKeepBackupOff;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ToneIcon(icon: LucideIcons.shieldAlert, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.ownershipTitle ?? 'Review this device',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.ownershipDetail ??
                  'Pebble will keep this device local until you choose.',
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onUseCurrentAccount,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Use this account'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onKeepBackupOff,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Keep backup off'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneIcon extends StatelessWidget {
  const _ToneIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 23, color: color),
    );
  }
}

IconData _buttonIcon(BackupDashboardAction action) {
  switch (action) {
    case BackupDashboardAction.turnOnBackup:
      return LucideIcons.cloudUpload;
    case BackupDashboardAction.backUpNow:
      return LucideIcons.refreshCw;
    case BackupDashboardAction.tryAgain:
      return LucideIcons.rotateCw;
    case BackupDashboardAction.useCurrentAccount:
      return LucideIcons.userCheck;
    case BackupDashboardAction.signIn:
      return LucideIcons.logIn;
    case BackupDashboardAction.getPremium:
      return LucideIcons.sparkles;
    case BackupDashboardAction.pauseBackup:
    case BackupDashboardAction.keepBackupOff:
      return LucideIcons.cloudOff;
    case BackupDashboardAction.none:
      return LucideIcons.circle;
  }
}

Color _toneColor(ColorScheme colorScheme, BackupDashboardTone tone) {
  switch (tone) {
    case BackupDashboardTone.active:
      return colorScheme.primary;
    case BackupDashboardTone.syncing:
      return colorScheme.tertiary;
    case BackupDashboardTone.paused:
      return colorScheme.secondary;
    case BackupDashboardTone.attention:
      return colorScheme.error;
    case BackupDashboardTone.neutral:
      return colorScheme.onSurface.withValues(alpha: 0.62);
  }
}

Future<T?> _showBackupActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.66),
    isScrollControlled: true,
    builder: builder,
  );
}

enum _BackupSheetButtonTone { primary, warning }

class _BackupActionSheet extends StatelessWidget {
  const _BackupActionSheet({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accentColor,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.secondaryLabel,
    required this.onSecondaryPressed,
    this.details = const [],
    this.primaryTone = _BackupSheetButtonTone.primary,
    this.primaryEnabled = true,
    this.secondaryEnabled = true,
    this.footer,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final Color accentColor;
  final List<Widget> details;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final _BackupSheetButtonTone primaryTone;
  final bool primaryEnabled;
  final String secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool secondaryEnabled;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final foreground = colorScheme.onSurface;
    final secondaryText = foreground.withValues(alpha: 0.68);
    final mutedText = foreground.withValues(alpha: 0.48);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: accentColor.withValues(alpha: 0.42),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 34,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _BackupSheetIcon(icon: icon, accentColor: accentColor),
                    const SizedBox(height: 22),
                    Text(
                      eyebrow.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSerifDisplay(
                        color: foreground,
                        fontSize: 30,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                        height: 1.62,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      ...details,
                    ],
                    const SizedBox(height: 24),
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 24),
                    _BackupSheetButton(
                      label: primaryLabel,
                      tone: primaryTone,
                      accentColor: accentColor,
                      enabled: primaryEnabled,
                      onPressed: onPrimaryPressed,
                    ),
                    const SizedBox(height: 10),
                    _BackupSheetButton(
                      label: secondaryLabel,
                      tone: _BackupSheetButtonTone.primary,
                      accentColor: accentColor,
                      enabled: secondaryEnabled,
                      outlined: true,
                      onPressed: onSecondaryPressed,
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        footer!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupSheetIcon extends StatelessWidget {
  const _BackupSheetIcon({required this.icon, required this.accentColor});

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: accentColor, size: 34),
    );
  }
}

class _BackupSheetButton extends StatelessWidget {
  const _BackupSheetButton({
    required this.label,
    required this.tone,
    required this.accentColor,
    required this.enabled,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final _BackupSheetButtonTone tone;
  final Color accentColor;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _BackupSheetButtonTone.warning => accentColor,
      _BackupSheetButtonTone.primary => accentColor,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.22),
            ),
            shape: shape,
          ),
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: background.withValues(alpha: 0.32),
          disabledForegroundColor: colorScheme.onPrimary.withValues(
            alpha: 0.64,
          ),
          shape: shape,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BackupSheetPill extends StatelessWidget {
  const _BackupSheetPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.11)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.dmSerifDisplay(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.58),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSheetPillRow extends StatelessWidget {
  const _BackupSheetPillRow({required this.pills});

  final List<_BackupSheetPill> pills;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < pills.length; index++) ...[
          Expanded(child: pills[index]),
          if (index != pills.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _BackupConsentCheck extends StatelessWidget {
  const _BackupConsentCheck({
    required this.accepted,
    required this.enabled,
    required this.onChanged,
  });

  final bool accepted;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: CheckboxListTile.adaptive(
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        controlAffinity: ListTileControlAffinity.leading,
        value: accepted,
        onChanged: enabled ? onChanged : null,
        title: Text(
          cloudBackupConsentText,
          style: GoogleFonts.outfit(
            color: colorScheme.onSurface.withValues(alpha: 0.74),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.42,
          ),
        ),
      ),
    );
  }
}
