import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/account_backup/ui/account_status_card.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
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

  void _showVaultSnackBar(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _reviewLocalDataForCurrentAccount(String? email) async {
    final userId = ref.read(authSessionProvider).userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showVaultSnackBar('Sign in before linking local data.');
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
      _showVaultSnackBar('Local data is already linked to this account.');
      return;
    }

    if (report.state != LocalDataOwnershipState.unownedOnly) {
      _showVaultSnackBar(
        'Some Pebble data on this device belongs to another account. Pebble will keep it local.',
      );
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

  Future<bool?> _showLinkLocalDataDialog({
    required String? email,
    required int unownedCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Link this device\'s data?'),
          content: Text(
            'Pebble found $unownedCount local item${unownedCount == 1 ? '' : 's'} on this device. Link them to ${email ?? 'this account'} so backup can start, or keep them only on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep local for now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Link to this account'),
            ),
          ],
        );
      },
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
      _showVaultSnackBar('Linked to this account. Backup can start now.');
    } catch (error) {
      final message = _toUserFacingError(error);
      await ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(message);
      _showVaultSnackBar(message);
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
        _showVaultSnackBar('Backup is up to date.');
        return;
      case ManualSyncResultType.noChanges:
        HapticFeedback.mediumImpact();
        _showVaultSnackBar('All caught up.');
        return;
      case ManualSyncResultType.partialRetryScheduled:
        HapticFeedback.lightImpact();
        _showVaultSnackBar(result.message);
        return;
      case ManualSyncResultType.blockedSignedOut:
      case ManualSyncResultType.blockedNoEntitlement:
      case ManualSyncResultType.blockedConsentRequired:
      case ManualSyncResultType.blockedAccountSwitch:
      case ManualSyncResultType.blockedOffline:
      case ManualSyncResultType.failed:
        _showVaultSnackBar(result.message);
        return;
    }
  }

  Future<void> _restorePurchase() async {
    if (_restoreInFlight) {
      return;
    }
    final auth = ref.read(authSessionProvider);
    if (!auth.isSignedIn) {
      await ref.read(authControllerProvider.notifier).beginPremiumUpgrade();
      if (mounted) {
        _showVaultSnackBar('Sign in first so Pebble can verify Google Play.');
        context.push('/sign-in');
      }
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
      _showVaultSnackBar(result.message);
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
      if (mounted) {
        context.go('/account-hub');
      }
    } catch (_) {
      _showVaultSnackBar(
        'Could not restore your purchase yet. Please try again.',
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
      _showVaultSnackBar('Google Play subscription management is not ready.');
      return;
    }
    final url = Uri.parse(rawUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showVaultSnackBar('Could not open Google Play subscriptions.');
    }
  }

  Future<void> _showCloudBackupConsentDialog() async {
    if (_consentInFlight) {
      return;
    }

    var accepted = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              title: const Text('Turn on backup?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pebble will only start backup after you choose to turn it on.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: accepted,
                      onChanged: _consentInFlight
                          ? null
                          : (value) {
                              setDialogState(() => accepted = value == true);
                            },
                      title: const Text(cloudBackupConsentText),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _consentInFlight
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _consentInFlight || !accepted
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          await _acceptCloudBackupConsent();
                        },
                  child: const Text('Turn on backup'),
                ),
              ],
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
      _showVaultSnackBar('Backup is on.');
    } catch (error) {
      _showVaultSnackBar(_toUserFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _consentInFlight = false);
      }
    }
  }

  Future<void> _showWithdrawCloudBackupConsentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: const Text('Pause backup?'),
          content: const Text(
            'Pebble will stop saving new backup changes for this account. Existing backup stays available unless you delete your account or ask support to remove it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _withdrawCloudBackupConsent();
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Pause backup'),
            ),
          ],
        );
      },
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
      _showVaultSnackBar('Backup is paused. Local routines remain here.');
    } catch (error) {
      _showVaultSnackBar(_toUserFacingError(error));
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
      _showVaultSnackBar(
        'Account deleted. Cloud backup data was removed. Local routines stay on this device.',
      );
      context.go('/');
    } catch (error) {
      _showVaultSnackBar(_toUserFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _deleteInFlight = false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final runtimeConfig = ref.read(appRuntimeConfigProvider);
    final deletionUrl = runtimeConfig.accountDeletionUrl;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: const Text('Delete account'),
          content: Text(
            deletionUrl == null
                ? 'This deletes your Pebble account and cloud backup data. Local routines already saved on this device will stay here until you remove them manually.'
                : 'This deletes your Pebble account and cloud backup data. Local routines already saved on this device will stay here until you remove them manually. You can also use the web deletion page.',
          ),
          actions: [
            TextButton(
              onPressed: _deleteInFlight
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            if (deletionUrl != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final opened = await launchUrl(
                    deletionUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened) {
                    _showVaultSnackBar(
                      'Could not open the account deletion page.',
                    );
                  }
                },
                child: const Text('Open web page'),
              ),
            FilledButton(
              onPressed: _deleteInFlight
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _deleteAccount();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete account'),
            ),
          ],
        );
      },
    );
  }

  String _toUserFacingError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('StateError: ')) {
      return raw.replaceFirst('StateError: ', '');
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
        _showVaultSnackBar('Kept local on this device. Backup stays paused.');
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Signed out.'),
                  ),
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
}
