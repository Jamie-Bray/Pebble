import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/account_backup/ui/account_status_card.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';

class AccountHubScreen extends ConsumerStatefulWidget {
  const AccountHubScreen({super.key});

  @override
  ConsumerState<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends ConsumerState<AccountHubScreen> {
  bool _manualSyncInFlight = false;
  bool _restoreInFlight = false;
  bool _deleteInFlight = false;
  bool _consentInFlight = false;
  bool _linkLocalDataInFlight = false;

  void _exitVault() {
    if (!mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  void _showVaultNotice(
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
      _showVaultNotice(
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
      await _prepareBackupAfterOwnershipChoice(userId);
      _showVaultNotice(
        'Local data is already linked to this account.',
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
    final itemLabel = '$itemCount local item${itemCount == 1 ? '' : 's'}';
    return _showAccountActionSheet<bool>(
      context: context,
      builder: (sheetContext) => _AccountActionSheet(
        icon: LucideIcons.userCheck,
        eyebrow: 'Backup',
        title: 'Use this account for this device?',
        body:
            'This device has Pebble data from a previous sign-in. Use ${email ?? 'this account'} from now on so backup can continue.',
        accentColor: Theme.of(sheetContext).colorScheme.primary,
        details: [
          _AccountSheetPillRow(
            pills: [
              _AccountSheetPill(value: itemLabel, label: 'On this device'),
              const _AccountSheetPill(value: 'Current', label: 'Account'),
              const _AccountSheetPill(value: 'Backup', label: 'After choice'),
            ],
          ),
        ],
        primaryLabel: 'Use this account',
        onPrimaryPressed: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep backup off',
        onSecondaryPressed: () => Navigator.of(sheetContext).pop(false),
        footer:
            'Pebble will not upload this device\'s routines to the signed-in account unless you choose.',
      ),
    );
  }

  Future<bool?> _showLinkLocalDataDialog({
    required String? email,
    required int unownedCount,
  }) {
    final itemLabel = '$unownedCount local item${unownedCount == 1 ? '' : 's'}';
    return _showAccountActionSheet<bool>(
      context: context,
      builder: (sheetContext) => _AccountActionSheet(
        icon: LucideIcons.link,
        eyebrow: 'Account safety',
        title: 'Link this device\'s data?',
        body:
            'Pebble found $itemLabel on this device. Link them to ${email ?? 'this account'} so backup can start, or keep them only on this device.',
        accentColor: Theme.of(sheetContext).colorScheme.primary,
        details: [
          _AccountSheetPillRow(
            pills: [
              _AccountSheetPill(value: itemLabel, label: 'Found here'),
              const _AccountSheetPill(value: 'Backup', label: 'After linking'),
              const _AccountSheetPill(value: 'Local', label: 'Optional'),
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
      _showVaultNotice(
        'Linked to this account. Backup can start now.',
        title: 'Data linked',
        type: NotificationType.success,
      );
    } catch (error) {
      final message = _toUserFacingError(error);
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(message);
      _showVaultNotice(
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
      _showVaultNotice(
        'This device now uses your signed-in account for backup.',
        title: 'Backup is on',
        type: NotificationType.success,
      );
    } catch (error) {
      final message = _toUserFacingError(error);
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(message);
      _showVaultNotice(
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
    await ref.read(cloudRestoreCoordinatorProvider).bootstrapAndMerge(userId);
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
        HapticFeedback.mediumImpact();
        _showVaultNotice(
          'Backup is up to date.',
          title: 'All caught up',
          type: NotificationType.success,
        );
        return;
      case ManualSyncResultType.noChanges:
        HapticFeedback.mediumImpact();
        _showVaultNotice(
          'There are no backup changes waiting.',
          title: 'All caught up',
          type: NotificationType.success,
        );
        return;
      case ManualSyncResultType.partialRetryScheduled:
        HapticFeedback.lightImpact();
        _showVaultNotice(
          result.message,
          title: 'Backup will retry',
          type: NotificationType.warning,
        );
        return;
      case ManualSyncResultType.blockedSignedOut:
      case ManualSyncResultType.blockedNoEntitlement:
      case ManualSyncResultType.blockedConsentRequired:
      case ManualSyncResultType.blockedAccountSwitch:
      case ManualSyncResultType.blockedOffline:
      case ManualSyncResultType.failed:
        _showVaultNotice(
          result.message,
          title: 'Backup not finished',
          type: NotificationType.warning,
        );
        return;
    }
  }

  Future<void> _restorePurchase() async {
    if (_restoreInFlight) {
      return;
    }
    setState(() => _restoreInFlight = true);
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .restorePurchases();
      if (!mounted) {
        return;
      }
      _showVaultNotice(
        result.message,
        title: 'Purchase restored',
        type: NotificationType.success,
      );
      final auth = ref.read(authSessionProvider);
      if (auth.isSignedIn) {
        await ref
            .read(authControllerProvider.notifier)
            .refreshCloudAccessAfterEntitlementChange();
      }
      if (mounted) {
        context.go('/account-hub');
      }
    } catch (error) {
      _showVaultNotice(
        _toUserFacingError(error),
        title: 'Could not restore',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _restoreInFlight = false);
      }
    }
  }

  Future<void> _openManagePlan() async {
    final rawUrl = ref.read(purchaseRepositoryProvider).manageSubscriptionsUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      _showVaultNotice(
        'Subscription management is not ready yet.',
        title: 'Not ready',
        type: NotificationType.warning,
      );
      return;
    }
    final url = Uri.parse(rawUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showVaultNotice(
        'Could not open subscription management.',
        title: 'Could not open',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _showCloudBackupConsentDialog() async {
    if (_consentInFlight) {
      return;
    }

    var accepted = false;
    await _showAccountActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return _AccountActionSheet(
              icon: LucideIcons.cloudUpload,
              eyebrow: 'Cloud backup',
              title: 'Turn on backup?',
              body:
                  'Pebble will only start backup after you choose to turn it on. You stay in control of when supported routine data can upload.',
              accentColor: Theme.of(sheetContext).colorScheme.primary,
              details: [
                _AccountConsentCheck(
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
      HapticFeedback.mediumImpact();
      _showVaultNotice(
        'Pebble will back up supported routine data for this account.',
        title: 'Backup is on',
        type: NotificationType.success,
      );
    } catch (error) {
      _showVaultNotice(
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
    await _showAccountActionSheet<void>(
      context: context,
      builder: (sheetContext) => _AccountActionSheet(
        icon: LucideIcons.cloudOff,
        eyebrow: 'Backup control',
        title: 'Pause backup?',
        body:
            'Pebble will stop saving new backup changes for this account. Existing backup stays available unless you delete your account or ask support to remove it.',
        accentColor: Theme.of(sheetContext).colorScheme.secondary,
        details: const [
          _AccountSheetPillRow(
            pills: [
              _AccountSheetPill(value: 'Stops', label: 'New uploads'),
              _AccountSheetPill(value: 'Keeps', label: 'Local data'),
              _AccountSheetPill(value: 'Resume', label: 'Any time'),
            ],
          ),
        ],
        primaryLabel: 'Pause backup',
        primaryTone: _AccountSheetButtonTone.warning,
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
      HapticFeedback.lightImpact();
      _showVaultNotice(
        'Local routines remain on this device.',
        title: 'Backup is paused',
        type: NotificationType.info,
      );
    } catch (error) {
      _showVaultNotice(
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

  Future<void> _deleteAccount() async {
    if (_deleteInFlight) {
      return;
    }

    setState(() => _deleteInFlight = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (!mounted) {
        return;
      }
      _showVaultNotice(
        'Account deleted. Cloud backup data was removed. Local routines stay on this device.',
        title: 'Account deleted',
        type: NotificationType.success,
      );
      context.go('/');
    } catch (error) {
      _showVaultNotice(
        _toUserFacingError(error),
        title: 'Could not delete account',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _deleteInFlight = false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final runtimeConfig = ref.read(appRuntimeConfigProvider);
    final deletionUrl = runtimeConfig.accountDeletionUrl;

    await _showAccountActionSheet<void>(
      context: context,
      builder: (sheetContext) => _AccountActionSheet(
        icon: LucideIcons.trash2,
        eyebrow: 'Permanent action',
        title: 'Delete account',
        body: deletionUrl == null
            ? 'This deletes your Pebble account and cloud backup data. Local routines already saved on this device will stay here until you remove them manually.'
            : 'This deletes your Pebble account and cloud backup data. Local routines already saved on this device will stay here until you remove them manually.',
        accentColor: Theme.of(sheetContext).colorScheme.error,
        details: const [
          _AccountSheetWarningRow(
            icon: LucideIcons.userX,
            text: 'Your Pebble account is removed.',
          ),
          _AccountSheetWarningRow(
            icon: LucideIcons.cloudOff,
            text: 'Cloud backup data for this account is removed.',
          ),
          _AccountSheetWarningRow(
            icon: LucideIcons.smartphone,
            text: 'Local routines on this device stay here.',
          ),
        ],
        primaryLabel: 'Delete account',
        primaryTone: _AccountSheetButtonTone.danger,
        primaryEnabled: !_deleteInFlight,
        onPrimaryPressed: () {
          Navigator.of(sheetContext).pop();
          _deleteAccount();
        },
        secondaryLabel: 'Cancel',
        secondaryEnabled: !_deleteInFlight,
        onSecondaryPressed: () => Navigator.of(sheetContext).pop(),
        tertiaryLabel: deletionUrl == null ? null : 'Open web deletion page',
        onTertiaryPressed: deletionUrl == null
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                final opened = await launchUrl(
                  deletionUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened) {
                  _showVaultNotice(
                    'Could not open the account deletion page.',
                    title: 'Could not open',
                    type: NotificationType.error,
                  );
                }
              },
      ),
    );
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

  void _handleAccountStatusAction(AccountStatusAction action) {
    switch (action) {
      case AccountStatusAction.none:
        return;
      case AccountStatusAction.startPremium:
      case AccountStatusAction.renewPremium:
        context.push(premiumRoute(source: PremiumEntrySource.backup));
      case AccountStatusAction.restorePurchase:
        _restorePurchase();
      case AccountStatusAction.signIn:
        context.push('/sign-in');
      case AccountStatusAction.reviewBackup:
        _showCloudBackupConsentDialog();
      case AccountStatusAction.syncNow:
        _runManualSync();
      case AccountStatusAction.managePlan:
        _openManagePlan();
      case AccountStatusAction.reviewLocalData:
        _reviewLocalDataForCurrentAccount(ref.read(authSessionProvider).email);
      case AccountStatusAction.keepLocal:
        _showWithdrawCloudBackupConsentDialog();
      case AccountStatusAction.pauseBackup:
        _showWithdrawCloudBackupConsentDialog();
    }
  }

  bool _isActionBusy(AccountStatusAction action) {
    return switch (action) {
      AccountStatusAction.restorePurchase => _restoreInFlight,
      AccountStatusAction.reviewBackup ||
      AccountStatusAction.pauseBackup => _consentInFlight,
      AccountStatusAction.syncNow => _manualSyncInFlight,
      AccountStatusAction.reviewLocalData => _linkLocalDataInFlight,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authSessionProvider);
    final accountStatus = ref.watch(accountStatusPresentationProvider);
    final lifecycle = ref.watch(subscriptionLifecycleProvider);
    final isLapsedPremium =
        lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace ||
        lifecycle.phase == SubscriptionLifecyclePhase.expired;

    if (isLapsedPremium) {
      return _LapsedPremiumAccountScreen(
        state: _buildLapsedPremiumState(lifecycle),
        onBack: _exitVault,
        onRenew: () =>
            context.push(premiumRoute(source: PremiumEntrySource.routineLimit)),
        onManagePlan: _openManagePlan,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitVault();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: PebbleSubscreenAppBar(
          title: 'Your account',
          subtitle: 'Works without an account',
          onBack: _exitVault,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          children: [
            AccountStatusCard(
              state: accountStatus,
              onPrimaryAction:
                  accountStatus.primaryAction == AccountStatusAction.none
                  ? null
                  : () =>
                        _handleAccountStatusAction(accountStatus.primaryAction),
              onSecondaryAction:
                  accountStatus.secondaryAction == AccountStatusAction.none
                  ? null
                  : () => _handleAccountStatusAction(
                      accountStatus.secondaryAction,
                    ),
              isPrimaryBusy: _isActionBusy(accountStatus.primaryAction),
              isSecondaryBusy: _isActionBusy(accountStatus.secondaryAction),
            ),
            const SizedBox(height: 32),
            _buildDestructiveActions(
              context,
              ref,
              colorScheme,
              auth.isSignedIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveActions(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    bool isSignedIn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSignedIn) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                _showVaultNotice(
                  'Backup is paused. Local routines stay on this device.',
                  title: 'Signed out',
                  type: NotificationType.info,
                );
              }
            },
            child: Text(
              'Sign out (pauses backup, keeps local routines)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: colorScheme.error,
            ),
            onPressed: _deleteInFlight ? null : _showDeleteAccountDialog,
            child: Text(
              _deleteInFlight ? 'Deleting account...' : 'Delete Account',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  _LapsedPremiumState _buildLapsedPremiumState(
    SubscriptionLifecycle lifecycle,
  ) {
    final historyRuns = ref.watch(routineHistoryVmProvider).valueOrNull;
    final routines = ref.watch(routineListProvider).valueOrNull;
    final policy = ref.watch(routineLimitPolicyProvider);
    final purchase = ref.watch(purchaseRepositoryProvider);
    final historyGraceDays = _remainingGraceDays(lifecycle);
    final routineGraceDays = historyGraceDays;
    final totalHistoryDays = _distinctHistoryDays(historyRuns ?? const []);
    final showRoutineRiskCard = routines == null
        ? true
        : !isFreeTierFootprint(routines: routines, policy: policy);
    final products = purchase.personalPremiumProducts;
    final monthly = _productForPlan(products, BillingPlan.monthly);
    final yearly = _productForPlan(products, BillingPlan.yearly);

    return _LapsedPremiumState(
      totalHistoryDays: totalHistoryDays,
      historyGraceDays: historyGraceDays,
      routineGraceDays: routineGraceDays,
      showRoutineRiskCard: showRoutineRiskCard,
      monthlyPrice: monthly?.priceLabel.trim().isNotEmpty == true
          ? monthly!.priceLabel
          : '99p',
      yearlyPrice: yearly?.priceLabel.trim().isNotEmpty == true
          ? yearly!.priceLabel
          : 'GBP 7.99',
      canRenew: purchase.isPurchaseAvailable,
    );
  }
}

int _remainingGraceDays(SubscriptionLifecycle lifecycle) {
  final endsAt = lifecycle.graceEndsAt;
  if (endsAt == null) {
    return 0;
  }
  final remaining = endsAt.difference(DateTime.now());
  if (remaining.isNegative) {
    return 0;
  }
  return (remaining.inHours / 24).ceil().clamp(0, 7);
}

int _distinctHistoryDays(List<RoutineRun> runs) {
  return {
    for (final run in runs)
      DateTime(run.finishedAt.year, run.finishedAt.month, run.finishedAt.day),
  }.length;
}

PremiumProduct? _productForPlan(
  List<PremiumProduct> products,
  BillingPlan plan,
) {
  for (final product in products) {
    if (product.plan == plan) return product;
  }
  return null;
}

class _LapsedPremiumState {
  const _LapsedPremiumState({
    required this.totalHistoryDays,
    required this.historyGraceDays,
    required this.routineGraceDays,
    required this.showRoutineRiskCard,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.canRenew,
  });

  final int totalHistoryDays;
  final int historyGraceDays;
  final int routineGraceDays;
  final bool showRoutineRiskCard;
  final String monthlyPrice;
  final String yearlyPrice;
  final bool canRenew;
}

class _LapsedPremiumAccountScreen extends StatelessWidget {
  const _LapsedPremiumAccountScreen({
    required this.state,
    required this.onBack,
    required this.onRenew,
    required this.onManagePlan,
  });

  static const _bg = Color(0xFF171411);
  static const _text = Color(0xFFF3EDE4);
  static const _gold = Color(0xFFD4A853);
  static const _red = Color(0xFFE06050);

  final _LapsedPremiumState state;
  final VoidCallback onBack;
  final VoidCallback onRenew;
  final VoidCallback onManagePlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 360,
                height: 320,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x1AD4A853), Color(0x00171411)],
                    stops: [0, 0.70],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  children: [
                    _LapsedBackRow(onBack: onBack),
                    const SizedBox(height: 32),
                    const _LapsedHero(),
                    const SizedBox(height: 24),
                    _RiskCard.history(
                      totalHistoryDays: state.totalHistoryDays,
                      graceDays: state.historyGraceDays,
                    ),
                    if (state.showRoutineRiskCard) ...[
                      const SizedBox(height: 10),
                      _RiskCard.routines(graceDays: state.routineGraceDays),
                    ],
                    const SizedBox(height: 24),
                    Container(height: 1, color: _text.withValues(alpha: 0.07)),
                    const SizedBox(height: 20),
                    _LapsedCtaSection(
                      monthlyPrice: state.monthlyPrice,
                      yearlyPrice: state.yearlyPrice,
                      canRenew: state.canRenew,
                      onRenew: onRenew,
                      onManagePlan: onManagePlan,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Works without an account - Cancel anytime',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3,
                        color: _text.withValues(alpha: 0.18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LapsedBackRow extends StatelessWidget {
  const _LapsedBackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: _LapsedPremiumAccountScreen._text.withValues(
                alpha: 0.08,
              ),
              side: BorderSide(
                color: _LapsedPremiumAccountScreen._text.withValues(
                  alpha: 0.12,
                ),
              ),
            ),
            icon: const Icon(
              LucideIcons.chevronLeft,
              size: 16,
              color: _LapsedPremiumAccountScreen._text,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'YOUR ACCOUNT',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.44,
            color: _LapsedPremiumAccountScreen._text.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _LapsedHero extends StatelessWidget {
  const _LapsedHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
          decoration: BoxDecoration(
            color: _LapsedPremiumAccountScreen._gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _LapsedPremiumAccountScreen._gold.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _LapsedPremiumAccountScreen._gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'PREMIUM ENDED',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.88,
                  color: _LapsedPremiumAccountScreen._gold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'A few things\nare '),
              TextSpan(
                text: 'at risk.',
                style: TextStyle(
                  color: _LapsedPremiumAccountScreen._text.withValues(
                    alpha: 0.50,
                  ),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 40,
            height: 1.06,
            fontWeight: FontWeight.w400,
            color: _LapsedPremiumAccountScreen._text,
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text:
                    'Your premium period has ended. Here\'s what happens next - ',
              ),
              TextSpan(
                text: 'no surprises.',
                style: TextStyle(
                  color: _LapsedPremiumAccountScreen._text.withValues(
                    alpha: 0.82,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.65,
            color: _LapsedPremiumAccountScreen._text.withValues(alpha: 0.50),
          ),
        ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard._({
    required this.icon,
    required this.title,
    required this.body,
    required this.countdown,
    required this.accent,
    required this.progress,
  });

  factory _RiskCard.history({
    required int totalHistoryDays,
    required int graceDays,
  }) {
    return _RiskCard._(
      icon: LucideIcons.clock3,
      title: 'Your history is fading',
      body: TextSpan(
        children: [
          TextSpan(
            text:
                '$totalHistoryDays days of completed routines are still here. ',
          ),
          TextSpan(
            text: graceDays <= 0 ? 'Locked now' : 'Locked in $graceDays days',
            style: const TextStyle(
              color: Color(0xB8F3EDE4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' unless you renew.'),
        ],
      ),
      countdown: graceDays <= 0 ? 'LOCKED' : '$graceDays DAYS REMAINING',
      accent: _LapsedPremiumAccountScreen._gold,
      progress: graceDays / 7,
    );
  }

  factory _RiskCard.routines({required int graceDays}) {
    return _RiskCard._(
      icon: LucideIcons.listChecks,
      title: 'Extra routines & steps are at risk',
      body: TextSpan(
        children: [
          const TextSpan(text: 'Free accounts keep '),
          const TextSpan(
            text: '2 routines',
            style: TextStyle(
              color: Color(0xB8F3EDE4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' with up to '),
          const TextSpan(
            text: '10 steps each',
            style: TextStyle(
              color: Color(0xB8F3EDE4),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: graceDays <= 0
                ? '. Extra routines and steps are soft-locked until you renew.'
                : '. Extra routines and steps above this limit will be deactivated in $graceDays days.',
          ),
        ],
      ),
      countdown: graceDays <= 0 ? 'LOCKED' : '$graceDays DAYS REMAINING',
      accent: _LapsedPremiumAccountScreen._red,
      progress: graceDays / 7,
    );
  }

  final IconData icon;
  final String title;
  final TextSpan body;
  final String countdown;
  final Color accent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                    color: _LapsedPremiumAccountScreen._text.withValues(
                      alpha: 0.42,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    value: clampedProgress,
                    backgroundColor: _LapsedPremiumAccountScreen._text
                        .withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  countdown,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: accent.withValues(alpha: 0.55),
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

class _LapsedCtaSection extends StatelessWidget {
  const _LapsedCtaSection({
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.canRenew,
    required this.onRenew,
    required this.onManagePlan,
  });

  final String monthlyPrice;
  final String yearlyPrice;
  final bool canRenew;
  final VoidCallback onRenew;
  final VoidCallback onManagePlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              monthlyPrice,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 30,
                color: _LapsedPremiumAccountScreen._text,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ month',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: _LapsedPremiumAccountScreen._text.withValues(
                  alpha: 0.38,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _LapsedPremiumAccountScreen._gold.withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _LapsedPremiumAccountScreen._gold.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
              child: Text(
                'or $yearlyPrice/year',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _LapsedPremiumAccountScreen._gold.withValues(
                    alpha: 0.65,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: canRenew ? onRenew : null,
            style: FilledButton.styleFrom(
              backgroundColor: _LapsedPremiumAccountScreen._gold,
              foregroundColor: _LapsedPremiumAccountScreen._bg,
              disabledBackgroundColor: _LapsedPremiumAccountScreen._gold
                  .withValues(alpha: 0.34),
              disabledForegroundColor: _LapsedPremiumAccountScreen._bg
                  .withValues(alpha: 0.72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text(canRenew ? 'Renew Premium' : 'Premium unavailable'),
          ),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: onManagePlan,
            style: OutlinedButton.styleFrom(
              foregroundColor: _LapsedPremiumAccountScreen._text.withValues(
                alpha: 0.38,
              ),
              side: BorderSide(
                color: _LapsedPremiumAccountScreen._text.withValues(
                  alpha: 0.11,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: const Text('Manage plan'),
          ),
        ),
      ],
    );
  }
}

Future<T?> _showAccountActionSheet<T>({
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

enum _AccountSheetButtonTone { primary, warning, danger }

class _AccountActionSheet extends StatelessWidget {
  const _AccountActionSheet({
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
    this.primaryTone = _AccountSheetButtonTone.primary,
    this.primaryEnabled = true,
    this.secondaryEnabled = true,
    this.tertiaryLabel,
    this.onTertiaryPressed,
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
  final _AccountSheetButtonTone primaryTone;
  final bool primaryEnabled;
  final String secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool secondaryEnabled;
  final String? tertiaryLabel;
  final VoidCallback? onTertiaryPressed;
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
                    _AccountSheetIcon(icon: icon, accentColor: accentColor),
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
                    _AccountSheetButton(
                      label: primaryLabel,
                      tone: primaryTone,
                      accentColor: accentColor,
                      enabled: primaryEnabled,
                      onPressed: onPrimaryPressed,
                    ),
                    const SizedBox(height: 10),
                    _AccountSheetButton(
                      label: secondaryLabel,
                      tone: _AccountSheetButtonTone.primary,
                      accentColor: accentColor,
                      enabled: secondaryEnabled,
                      outlined: true,
                      onPressed: onSecondaryPressed,
                    ),
                    if (tertiaryLabel != null && onTertiaryPressed != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: onTertiaryPressed,
                        child: Text(tertiaryLabel!),
                      ),
                    ],
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

class _AccountSheetIcon extends StatelessWidget {
  const _AccountSheetIcon({required this.icon, required this.accentColor});

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

class _AccountSheetButton extends StatelessWidget {
  const _AccountSheetButton({
    required this.label,
    required this.tone,
    required this.accentColor,
    required this.enabled,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final _AccountSheetButtonTone tone;
  final Color accentColor;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _AccountSheetButtonTone.danger => colorScheme.error,
      _AccountSheetButtonTone.warning => accentColor,
      _AccountSheetButtonTone.primary => accentColor,
    };
    final foreground = switch (tone) {
      _AccountSheetButtonTone.danger => colorScheme.onError,
      _AccountSheetButtonTone.warning => colorScheme.onPrimary,
      _AccountSheetButtonTone.primary => colorScheme.onPrimary,
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
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.32),
          disabledForegroundColor: foreground.withValues(alpha: 0.64),
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

class _AccountSheetPill extends StatelessWidget {
  const _AccountSheetPill({required this.value, required this.label});

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

class _AccountSheetPillRow extends StatelessWidget {
  const _AccountSheetPillRow({required this.pills});

  final List<_AccountSheetPill> pills;

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

class _AccountConsentCheck extends StatelessWidget {
  const _AccountConsentCheck({
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

class _AccountSheetWarningRow extends StatelessWidget {
  const _AccountSheetWarningRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.76),
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
