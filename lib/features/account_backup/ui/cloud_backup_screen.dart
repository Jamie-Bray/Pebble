import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_simple_sheet.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/history/ui/styled_history_screen.dart';
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
        'This phone is already linked to your account.',
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
    return showPebbleSimpleSheet<bool>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        icon: LucideIcons.userCheck,
        title: 'Use this account for this phone?',
        body:
            'This phone has routines from another sign-in. Pebble will back '
            'them up to ${email ?? 'this account'} too. They stay on this '
            'phone either way.',
        primaryLabel: 'Use this account',
        onPrimary: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep backup off',
        onSecondary: () => Navigator.of(sheetContext).pop(false),
      ),
    );
  }

  Future<bool?> _showLinkLocalDataDialog({
    required String? email,
    required int unownedCount,
  }) {
    final itemLabel = '$unownedCount item${unownedCount == 1 ? '' : 's'}';
    return showPebbleSimpleSheet<bool>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        icon: LucideIcons.link,
        title: "Back up this phone's routines?",
        body:
            'Pebble found $itemLabel on this phone. Add them to '
            '${email ?? 'this account'} so they are backed up too.',
        primaryLabel: 'Add to this account',
        onPrimary: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep local',
        onSecondary: () => Navigator.of(sheetContext).pop(false),
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
        title: "Couldn't link",
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
        'This phone now uses your signed-in account for backup.',
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
        title: "Couldn't continue",
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

    // Success needs no toast: the status card turns to "Backed up".
    switch (result.type) {
      case ManualSyncResultType.synced:
      case ManualSyncResultType.noChanges:
        return;
      case ManualSyncResultType.partialRetryScheduled:
      case ManualSyncResultType.blockedSignedOut:
      case ManualSyncResultType.blockedNoEntitlement:
      case ManualSyncResultType.blockedConsentRequired:
      case ManualSyncResultType.blockedAccountSwitch:
      case ManualSyncResultType.blockedOffline:
      case ManualSyncResultType.failed:
        _showBackupNotice(
          result.message,
          title: "Couldn't finish backing up",
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
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: "Couldn't refresh",
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _verificationInFlight = false);
      }
    }
  }

  /// One sheet, one tap: the statement the server records is shown word
  /// for word directly above the button that agrees to it.
  Future<void> _showCloudBackupConsentDialog() async {
    if (_consentInFlight) {
      return;
    }
    await showPebbleSimpleSheet<void>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        icon: LucideIcons.cloudUpload,
        title: 'Turn on backup?',
        body: 'Keep your routines, history and photos safe in your account.',
        content: const PebbleStatementBox(text: cloudBackupConsentText),
        primaryLabel: 'Turn on backup',
        onPrimary: () async {
          Navigator.of(sheetContext).pop();
          await _acceptCloudBackupConsent();
        },
        detailsLabel: 'How backup works',
        onDetails: () => showHowBackupWorks(sheetContext),
      ),
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
          .refreshCloudAccessAfterEntitlementChange(refreshEntitlement: false);
      // No toast: the hero headline flips to "Backup is on" right here.
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: "Couldn't turn on backup",
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _consentInFlight = false);
      }
    }
  }

  Future<void> _showWithdrawCloudBackupConsentDialog() async {
    await showPebbleSimpleSheet<void>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        icon: LucideIcons.cloudOff,
        title: 'Pause backup?',
        body:
            'Pebble stops backing up new changes. Everything stays on this '
            'phone, and you can turn backup back on any time.',
        primaryLabel: 'Pause backup',
        destructive: true,
        onPrimary: () async {
          Navigator.of(sheetContext).pop();
          await _withdrawCloudBackupConsent();
        },
        secondaryLabel: 'Keep backup on',
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
          .refreshCloudAccessAfterEntitlementChange(refreshEntitlement: false);
      // No toast: the hero headline flips to the paused state right here,
      // and the pause sheet already covered what stays on the device.
    } catch (error) {
      _showBackupNotice(
        _toUserFacingError(error),
        title: "Couldn't pause backup",
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

  void _openPhotoVault() {
    ref.read(historyViewModeProvider.notifier).state = HistoryViewMode.vault;
    ref.read(navIndexProvider.notifier).state = 1;
    context.go('/');
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
      return "The store couldn't finish that. Try again.";
    }
    if (raw.startsWith('FunctionException')) {
      return "Pebble couldn't finish that. Try again.";
    }
    return raw;
  }

  /// The one action the status card offers, if any.
  ({String label, IconData icon, VoidCallback onTap, bool primary, bool busy})?
  _cardAction(BackupStatus status, BackupDashboardPresentation presentation) {
    switch (status.phase) {
      case BackupPhase.notIncluded:
        return (
          label: 'Get Premium',
          icon: LucideIcons.sparkles,
          onTap: () => _handleAction(BackupDashboardAction.getPremium),
          primary: true,
          busy: false,
        );
      case BackupPhase.paused:
        return (
          label: 'Renew Premium',
          icon: LucideIcons.sparkles,
          onTap: () => _handleAction(BackupDashboardAction.getPremium),
          primary: true,
          busy: false,
        );
      case BackupPhase.signedOut:
        return (
          label: 'Sign in',
          icon: LucideIcons.logIn,
          onTap: () => _handleAction(BackupDashboardAction.signIn),
          primary: true,
          busy: false,
        );
      case BackupPhase.off:
        return (
          label: 'Turn on backup',
          icon: LucideIcons.cloudUpload,
          onTap: () => _handleAction(BackupDashboardAction.turnOnBackup),
          primary: true,
          busy: _consentInFlight,
        );
      case BackupPhase.needsAttention:
        if (presentation.showOwnershipMismatch) return null;
        final verify =
            presentation.primaryAction == BackupDashboardAction.tryAgain;
        return (
          label: 'Try again',
          icon: LucideIcons.rotateCw,
          onTap: () => verify ? _refreshBackupVerification() : _runManualSync(),
          primary: true,
          busy: verify ? _verificationInFlight : _manualSyncInFlight,
        );
      case BackupPhase.waiting:
        return (
          label: 'Back up now',
          icon: LucideIcons.refreshCw,
          onTap: _runManualSync,
          primary: false,
          busy: _manualSyncInFlight,
        );
      case BackupPhase.upToDate:
        return (
          label: 'Back up now',
          icon: LucideIcons.refreshCw,
          onTap: _runManualSync,
          primary: false,
          busy: _manualSyncInFlight,
        );
      case BackupPhase.checking:
      case BackupPhase.backingUp:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final presentation = ref.watch(backupDashboardPresentationProvider);
    final status = ref.watch(backupStatusProvider);
    final auth = ref.watch(authSessionProvider);
    final action = _cardAction(status, presentation);
    final now = DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitBackup();
        }
      },
      child: Scaffold(
        backgroundColor: foundation.bgBase,
        appBar: PebbleSubscreenAppBar(title: 'Backup', onBack: _exitBackup),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
          children: [
            BackupStatusCard(
              status: status,
              now: now,
              email: status.phase == BackupPhase.notIncluded
                  ? null
                  : auth.email,
              switchValue: status.isOn,
              onSwitchChanged: status.isOn && presentation.backupSwitchEnabled
                  ? _handleBackupSwitch
                  : null,
            ),
            if (action != null) ...[
              const SizedBox(height: PebbleSpacing.md),
              if (action.primary)
                PebbleButton.primary(
                  key: const ValueKey('backup_card_action'),
                  label: action.label,
                  icon: action.icon,
                  busy: action.busy,
                  onPressed: action.onTap,
                )
              else
                PebbleButton.secondary(
                  key: const ValueKey('backup_card_action'),
                  label: action.label,
                  icon: action.icon,
                  busy: action.busy,
                  onPressed: action.onTap,
                ),
            ],
            if (status.phase == BackupPhase.notIncluded && !auth.isSignedIn)
              Padding(
                padding: const EdgeInsets.only(top: PebbleSpacing.xs),
                child: PebbleButton.tertiary(
                  label: 'Already have Premium? Sign in',
                  expand: true,
                  onPressed: () => _handleAction(BackupDashboardAction.signIn),
                ),
              ),
            if (presentation.showOwnershipMismatch) ...[
              const SizedBox(height: PebbleSpacing.md),
              _OwnershipChoice(
                title:
                    presentation.ownershipTitle ??
                    'Which account should this phone use?',
                detail: presentation.ownershipDetail,
                busy: _linkLocalDataInFlight || _consentInFlight,
                onUseCurrentAccount: () =>
                    _handleAction(BackupDashboardAction.useCurrentAccount),
                onKeepBackupOff: () =>
                    _handleAction(BackupDashboardAction.keepBackupOff),
              ),
            ],
            const SizedBox(height: PebbleSpacing.xxl),
            _LinkRow(
              key: const ValueKey('backup_whats_included'),
              icon: LucideIcons.listChecks,
              label: "What's backed up",
              value: 'Routines, history, photos',
              onTap: () => _showWhatsBackedUp(presentation),
            ),
            if (presentation.dataItemsLive)
              _LinkRow(
                icon: LucideIcons.image,
                label: 'Proof photos',
                onTap: _openPhotoVault,
              ),
            _LinkRow(
              icon: LucideIcons.info,
              label: 'How backup works',
              onTap: () => showHowBackupWorks(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWhatsBackedUp(BackupDashboardPresentation presentation) {
    return showPebbleSimpleSheet<void>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        title: "What's backed up",
        body: presentation.dataItemsLive
            ? 'Pebble backs up new changes by itself, a few seconds after '
                  'you make them.'
            : 'Once backup is on, Pebble backs up changes by itself.',
        content: Column(
          children: [
            for (final item in presentation.dataItems)
              _BackupItemLine(item: item, live: presentation.dataItemsLive),
          ],
        ),
        primaryLabel: 'Done',
        onPrimary: () => Navigator.of(sheetContext).pop(),
        secondaryLabel: null,
      ),
    );
  }
}

/// The answer to "is my stuff backed up?", in one card: an icon, a two-word
/// headline and one line ("Backed up · 2 min ago"). Reused by Account.
class BackupStatusCard extends StatelessWidget {
  const BackupStatusCard({
    super.key,
    required this.status,
    required this.now,
    this.email,
    this.switchValue = false,
    this.onSwitchChanged,
  });

  final BackupStatus status;
  final DateTime now;
  final String? email;
  final bool switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, tint) = backupPhaseIcon(context, status);
    return Semantics(
      container: true,
      label: '${status.headline}. ${status.line(now)}',
      child: Container(
        key: const ValueKey('backup_status_card'),
        padding: const EdgeInsets.all(PebbleSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? foundation.surfaceLow : foundation.bgBase,
          borderRadius: PebbleRadius.lgAll,
          border: isDark
              ? null
              : Border.all(
                  color: foundation.textPrimary.withValues(alpha: 0.10),
                ),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        status.phase == BackupPhase.backingUp ||
                            status.phase == BackupPhase.checking
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tint,
                            ),
                          )
                        : Icon(icon, size: 24, color: tint),
                  ),
                  const Spacer(),
                  if (onSwitchChanged != null)
                    Switch.adaptive(
                      key: const ValueKey('backup_switch'),
                      value: switchValue,
                      onChanged: onSwitchChanged,
                    ),
                ],
              ),
              const SizedBox(height: PebbleSpacing.md),
              Text(
                status.headline,
                key: const ValueKey('backup_status_headline'),
                style: type.title1.copyWith(color: foundation.textPrimary),
              ),
              const SizedBox(height: PebbleSpacing.xxs),
              Text(
                status.line(now),
                key: const ValueKey('backup_status_line'),
                style: type.body.copyWith(color: context.readableSecondaryText),
              ),
              if (email != null) ...[
                const SizedBox(height: PebbleSpacing.sm),
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.caption.copyWith(
                    color: context.readableSecondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The icon and tint for a backup phase, shared by the card and status rows.
(IconData, Color) backupPhaseIcon(BuildContext context, BackupStatus status) {
  final foundation = context.darkFoundation;
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status.phase) {
    BackupPhase.upToDate => (LucideIcons.cloudCheck, context.done),
    BackupPhase.backingUp ||
    BackupPhase.checking => (LucideIcons.cloudUpload, colorScheme.primary),
    BackupPhase.waiting => (
      status.offline ? LucideIcons.wifiOff : LucideIcons.cloudUpload,
      foundation.textSecondary,
    ),
    BackupPhase.needsAttention => (LucideIcons.cloudAlert, colorScheme.error),
    BackupPhase.notIncluded ||
    BackupPhase.off ||
    BackupPhase.signedOut ||
    BackupPhase.paused => (LucideIcons.cloudOff, foundation.textSecondary),
  };
}

class _OwnershipChoice extends StatelessWidget {
  const _OwnershipChoice({
    required this.title,
    required this.detail,
    required this.busy,
    required this.onUseCurrentAccount,
    required this.onKeepBackupOff,
  });

  final String title;
  final String? detail;
  final bool busy;
  final VoidCallback onUseCurrentAccount;
  final VoidCallback onKeepBackupOff;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    return Container(
      padding: const EdgeInsets.all(PebbleSpacing.lg),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: PebbleRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: type.headline.copyWith(color: foundation.textPrimary),
          ),
          if (detail != null) ...[
            const SizedBox(height: PebbleSpacing.xxs),
            Text(
              detail!,
              style: type.body.copyWith(color: context.readableSecondaryText),
            ),
          ],
          const SizedBox(height: PebbleSpacing.md),
          PebbleButton.primary(
            label: 'Use this account',
            busy: busy,
            onPressed: busy ? null : onUseCurrentAccount,
          ),
          PebbleButton.tertiary(
            label: 'Keep backup off',
            expand: true,
            onPressed: busy ? null : onKeepBackupOff,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: PebbleRadius.mdAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PebbleSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 20, color: secondary),
              const SizedBox(width: PebbleSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: type.body.copyWith(color: foundation.textPrimary),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: PebbleSpacing.xs),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: type.caption.copyWith(color: secondary),
                  ),
                ),
              ],
              const SizedBox(width: PebbleSpacing.xxs),
              Icon(LucideIcons.chevronRight, size: 18, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupItemLine extends StatelessWidget {
  const _BackupItemLine({required this.item, required this.live});

  final BackupDataItem item;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final secondary = context.readableSecondaryText;
    final trailing = !live
        ? null
        : switch (item.state) {
            BackupDataItemState.saved => Icon(
              LucideIcons.check,
              size: 18,
              color: context.done,
            ),
            BackupDataItemState.pending => Icon(
              LucideIcons.clock,
              size: 18,
              color: secondary,
            ),
            BackupDataItemState.attention => Icon(
              LucideIcons.circleAlert,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            BackupDataItemState.off => null,
          };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PebbleSpacing.xs),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: secondary),
          const SizedBox(width: PebbleSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: type.body.copyWith(color: foundation.textPrimary),
                ),
                Text(
                  item.detail,
                  style: type.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// "How backup works": the detail that used to crowd the backup screens.
Future<void> showHowBackupWorks(BuildContext context) {
  return PebbleDetailsPage.push(
    context,
    title: 'How backup works',
    sections: const [
      (
        'What it keeps',
        'Your routines and their steps, reminders, voice tips and your check '
            'history. Proof photos are kept for 21 days.',
      ),
      (
        'When it backs up',
        'By itself, a few seconds after each change, whenever you are online. '
            'If you are offline, changes wait on this phone and go up when '
            'you are back online.',
      ),
      (
        'Getting it back',
        'Sign in with the same account on a new phone and Pebble brings your '
            'routines and history back.',
      ),
      (
        'Turning it off',
        'You can pause backup at any time. Everything stays on this phone. '
            'Backup comes with Personal Premium; if Premium ends, backup '
            'pauses.',
      ),
      (
        'Your privacy',
        'Routines, photos and history can say something personal about you, '
            'such as your health or your home. Only your account can read '
            'your backup. Deleting your account deletes the backup.',
      ),
    ],
  );
}
