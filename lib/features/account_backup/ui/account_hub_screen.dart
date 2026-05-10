import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

class AccountHubScreen extends ConsumerStatefulWidget {
  const AccountHubScreen({super.key});

  @override
  ConsumerState<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends ConsumerState<AccountHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncPulseController;
  bool _manualSyncInFlight = false;
  bool _restoreInFlight = false;
  bool _deleteInFlight = false;
  bool _consentInFlight = false;

  @override
  void initState() {
    super.initState();
    _syncPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _syncPulseController.dispose();
    super.dispose();
  }

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
        _showVaultSnackBar('Backup current. Supported changes are synced.');
        return;
      case ManualSyncResultType.noChanges:
        HapticFeedback.mediumImpact();
        _showVaultSnackBar('All caught up. No new changes to sync.');
        return;
      case ManualSyncResultType.partialRetryScheduled:
        HapticFeedback.lightImpact();
        _showVaultSnackBar(result.message);
        return;
      case ManualSyncResultType.blockedSignedOut:
      case ManualSyncResultType.blockedNoEntitlement:
      case ManualSyncResultType.blockedConsentRequired:
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
              title: const Text('Enable cloud backup?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pebble will store this consent with your user ID, timestamp, app version, privacy-policy version, terms version, and consent-text hash.',
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
                  child: const Text('Enable cloud backup'),
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
      _showVaultSnackBar(
        'Cloud backup enabled. Pebble will sync supported routine data.',
      );
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
          title: const Text('Pause cloud backup?'),
          content: const Text(
            'Pebble will stop uploading routine backup data for this account. '
            'Existing cloud backup data is not deleted by this pause; you can delete your account or contact support to request deletion.',
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
      _showVaultSnackBar('Cloud backup is paused. Local routines remain here.');
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
          title: const Text('Delete Account'),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authSessionProvider);
    final entitlement = ref.watch(entitlementStateProvider);
    final isPremium = entitlement.isPersonalPaid;
    final cloudAccess = ref.watch(effectivePersonalCloudStatusProvider);
    final runtime = ref.watch(cloudSyncRuntimeStateProvider);
    final fairUseState = ref.watch(proofMediaFairUseStateProvider).valueOrNull;
    final uiState = ref.watch(accountBackupUiStateProvider);
    final pendingCount = ref
        .watch(syncOutboxCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);

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
          title: 'Account Hub',
          subtitle: 'Local storage, backup, and account access',
          onBack: _exitVault,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          children: [
            if (!auth.isSignedIn && !isPremium)
              _buildStateA(context, colorScheme)
            else if (auth.isSignedIn && !isPremium)
              _buildStateB(context, colorScheme, auth.email)
            else if (auth.isSignedIn && isPremium)
              _buildStateC(
                context,
                colorScheme,
                email: auth.email,
                syncStatus: cloudAccess,
                pendingCount: pendingCount,
                isRuntimeSyncing: runtime.isRunning,
                backupDetail: uiState.backupDetail,
                lastSyncText: _toLastSyncedLabel(uiState.lastSyncText),
                fairUseState: fairUseState,
              )
            else
              _buildStateA(context, colorScheme),
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

  Widget _buildStateA(BuildContext context, ColorScheme colorScheme) {
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AccountHero(
          icon: LucideIcons.hardDrive,
          title: 'Pebble works without an account.',
          body:
              'Your routines are stored on this device. Sign in is only needed for Premium backup or restore.',
        ),
        const SizedBox(height: 24),
        const _PremiumBenefitsList(),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: purchaseRepository.isPurchaseAvailable
              ? () => context.push(
                  premiumRoute(source: PremiumEntrySource.backup),
                )
              : null,
          child: const Text('Start Personal Premium'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _restoreInFlight || !purchaseRepository.isPurchaseAvailable
              ? null
              : _restorePurchase,
          child: Text(
            _restoreInFlight
                ? 'Checking purchase...'
                : 'Restore purchase / I already have Premium',
          ),
        ),
        if (purchaseRepository.unavailableReason != null) ...[
          const SizedBox(height: 8),
          Text(
            purchaseRepository.unavailableReason!,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStateB(
    BuildContext context,
    ColorScheme colorScheme,
    String? email,
  ) {
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountHero(
          icon: LucideIcons.hardDrive,
          title: 'Backup is off.',
          body:
              '${email ?? 'This account'} is signed in, but routines stay on this device until you start or restore Personal Premium.',
        ),
        const SizedBox(height: 24),
        const _PremiumBenefitsList(),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: purchaseRepository.isPurchaseAvailable
              ? () => context.push(
                  premiumRoute(source: PremiumEntrySource.backup),
                )
              : null,
          child: const Text('Start Personal Premium'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _restoreInFlight || !purchaseRepository.isPurchaseAvailable
              ? null
              : _restorePurchase,
          child: Text(
            _restoreInFlight
                ? 'Checking purchase...'
                : 'Restore purchase / I already have Premium',
          ),
        ),
        if (purchaseRepository.unavailableReason != null) ...[
          const SizedBox(height: 8),
          Text(
            purchaseRepository.unavailableReason!,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStateC(
    BuildContext context,
    ColorScheme colorScheme, {
    required String? email,
    required PersonalCloudAccessStatus syncStatus,
    required int pendingCount,
    required bool isRuntimeSyncing,
    required String? backupDetail,
    required String? lastSyncText,
    required ProofMediaFairUseState? fairUseState,
  }) {
    final isSyncing =
        syncStatus == PersonalCloudAccessStatus.syncing || _manualSyncInFlight;
    final requiresConsent =
        syncStatus == PersonalCloudAccessStatus.consentRequired;
    final canManualSync =
        !_manualSyncInFlight && !isSyncing && !requiresConsent;
    final statusTone = _statusTone(syncStatus, colorScheme);
    final statusCopy = _statusCopy(
      status: syncStatus,
      pendingCount: pendingCount,
      backupDetail: backupDetail,
      lastSyncText: lastSyncText,
      isRuntimeSyncing: isRuntimeSyncing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountHero(
          icon: requiresConsent
              ? LucideIcons.fileCheck
              : LucideIcons.shieldCheck,
          title: requiresConsent
              ? 'Review cloud backup first.'
              : 'Backup is active.',
          body: requiresConsent
              ? 'Before Pebble uploads supported routine data, confirm that cloud backup may include sensitive details about your health, home, family, workplace, habits, or personal circumstances.'
              : '${email ?? 'Personal Premium'} has cloud backup enabled for supported routine data. Proof photos are kept in cloud for 30 days.',
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _SyncStatusPanel(
            key: ValueKey(
              '${syncStatus.name}-$pendingCount-${_manualSyncInFlight ? 1 : 0}',
            ),
            title: statusCopy.title,
            subtitle: statusCopy.subtitle,
            icon: statusCopy.icon,
            tone: statusTone,
            pulse: isSyncing
                ? CurvedAnimation(
                    parent: _syncPulseController,
                    curve: Curves.easeInOut,
                  )
                : null,
          ),
        ),
        if (lastSyncText != null || pendingCount > 0) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (lastSyncText != null)
                _VaultMetaChip(icon: LucideIcons.clock3, label: lastSyncText),
              if (pendingCount > 0 &&
                  syncStatus != PersonalCloudAccessStatus.available)
                _VaultMetaChip(
                  icon: LucideIcons.refreshCw,
                  label:
                      '$pendingCount pending change${pendingCount == 1 ? '' : 's'}',
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _FairUseMeter(state: fairUseState),
        const SizedBox(height: 18),
        Text(
          'Guidance audio recordings stay on this device in this build. Routine backup may include guidance-audio metadata, such as a local filename or duration.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Yearly Premium is \u00A35.49, about 46p/month. Pebble Household is coming later.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: requiresConsent
              ? _showCloudBackupConsentDialog
              : canManualSync
              ? _runManualSync
              : null,
          icon: _manualSyncInFlight
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  requiresConsent
                      ? LucideIcons.fileCheck
                      : LucideIcons.refreshCw,
                  size: 18,
                ),
          label: Text(
            requiresConsent
                ? 'Review and enable cloud backup'
                : isSyncing
                ? 'Syncing...'
                : 'Sync now',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openManagePlan,
          icon: const Icon(LucideIcons.externalLink, size: 18),
          label: const Text('Manage plan'),
        ),
        if (!requiresConsent) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _consentInFlight
                ? null
                : _showWithdrawCloudBackupConsentDialog,
            child: const Text('Pause cloud backup consent'),
          ),
        ],
      ],
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

  String? _toLastSyncedLabel(String? lastSyncText) {
    if (lastSyncText == null || lastSyncText.isEmpty) {
      return null;
    }
    final normalized = lastSyncText.replaceFirst('Last sync ', '');
    return 'Last synced: $normalized';
  }

  _VaultStatusCopy _statusCopy({
    required PersonalCloudAccessStatus status,
    required int pendingCount,
    required String? backupDetail,
    required String? lastSyncText,
    required bool isRuntimeSyncing,
  }) {
    switch (status) {
      case PersonalCloudAccessStatus.syncing:
        return _VaultStatusCopy(
          title: 'Syncing latest changes',
          subtitle: pendingCount > 0
              ? '$pendingCount change${pendingCount == 1 ? '' : 's'} syncing to your backup.'
              : 'Uploading supported routine updates now.',
          icon: LucideIcons.refreshCw,
        );
      case PersonalCloudAccessStatus.available:
        return _VaultStatusCopy(
          title: isRuntimeSyncing ? 'Syncing latest changes' : 'All caught up',
          subtitle:
              lastSyncText ??
              'Supported routine data is synced for restore if you switch devices.',
          icon: LucideIcons.cloudCheck,
        );
      case PersonalCloudAccessStatus.consentRequired:
        return _VaultStatusCopy(
          title: 'Cloud backup needs your review',
          subtitle:
              backupDetail ??
              'Pebble will not upload routines, proof photos, history, or metadata until you enable cloud backup.',
          icon: LucideIcons.fileCheck,
        );
      case PersonalCloudAccessStatus.offlinePending:
        return _VaultStatusCopy(
          title: 'Waiting for connection',
          subtitle:
              backupDetail ??
              'Your latest changes are queued on this device and will upload when you are back online.',
          icon: LucideIcons.wifiOff,
        );
      case PersonalCloudAccessStatus.error:
        return _VaultStatusCopy(
          title: 'Needs attention',
          subtitle:
              backupDetail ??
              'Pebble could not finish syncing everything yet, but your local data remains on this device.',
          icon: LucideIcons.cloudAlert,
        );
      case PersonalCloudAccessStatus.offFree:
      case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      case PersonalCloudAccessStatus.pausedSignedOut:
        return _VaultStatusCopy(
          title: 'Sign in to resume backup',
          subtitle:
              backupDetail ??
              'Sign in and upgrade to turn cloud backup back on.',
          icon: LucideIcons.cloudOff,
        );
    }
  }

  _VaultStatusTone _statusTone(
    PersonalCloudAccessStatus status,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case PersonalCloudAccessStatus.syncing:
        return _VaultStatusTone(
          background: colorScheme.primary.withValues(alpha: 0.08),
          border: colorScheme.primary.withValues(alpha: 0.18),
          iconColor: colorScheme.primary,
          titleColor: colorScheme.onSurface,
        );
      case PersonalCloudAccessStatus.available:
        return _VaultStatusTone(
          background: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.56,
          ),
          border: colorScheme.outline.withValues(alpha: 0.14),
          iconColor: colorScheme.primary,
          titleColor: colorScheme.onSurface,
        );
      case PersonalCloudAccessStatus.consentRequired:
        return _VaultStatusTone(
          background: colorScheme.tertiaryContainer.withValues(alpha: 0.28),
          border: colorScheme.tertiary.withValues(alpha: 0.18),
          iconColor: colorScheme.tertiary,
          titleColor: colorScheme.onSurface,
        );
      case PersonalCloudAccessStatus.offlinePending:
        return _VaultStatusTone(
          background: colorScheme.secondaryContainer.withValues(alpha: 0.34),
          border: colorScheme.outline.withValues(alpha: 0.14),
          iconColor: colorScheme.onSurface.withValues(alpha: 0.75),
          titleColor: colorScheme.onSurface,
        );
      case PersonalCloudAccessStatus.error:
        return _VaultStatusTone(
          background: colorScheme.error.withValues(alpha: 0.08),
          border: colorScheme.error.withValues(alpha: 0.18),
          iconColor: colorScheme.error,
          titleColor: colorScheme.error,
        );
      case PersonalCloudAccessStatus.offFree:
      case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      case PersonalCloudAccessStatus.pausedSignedOut:
        return _VaultStatusTone(
          background: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.56,
          ),
          border: colorScheme.outline.withValues(alpha: 0.14),
          iconColor: colorScheme.onSurface.withValues(alpha: 0.65),
          titleColor: colorScheme.onSurface,
        );
    }
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: colorScheme.primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.02,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _PremiumBenefitsList extends StatelessWidget {
  const _PremiumBenefitsList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Premium',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        const _PremiumBenefitItem('Restore routines if you change phones'),
        const _PremiumBenefitItem('Back up routine history and proof photos'),
        const _PremiumBenefitItem('Keep proof photos for 30 days'),
        const _PremiumBenefitItem('Only proof photos you choose are backed up'),
      ],
    );
  }
}

class _PremiumBenefitItem extends StatelessWidget {
  const _PremiumBenefitItem(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleCheck, size: 16, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: colorScheme.onSurface.withValues(alpha: 0.76),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FairUseMeter extends StatelessWidget {
  const _FairUseMeter({required this.state});

  final ProofMediaFairUseState? state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fairUse =
        state ??
        const ProofMediaFairUseState(
          activeCloudBytes: 0,
          storageLimitBytes: ProofMediaFairUsePolicy.storageLimitBytes,
          uploadsThisPeriod: 0,
          monthlyUploadLimit: ProofMediaFairUsePolicy.monthlyUploadLimit,
        );
    final tone = switch (fairUse.status) {
      ProofMediaFairUseStatus.ok => colorScheme.primary,
      ProofMediaFairUseStatus.warning => colorScheme.tertiary,
      ProofMediaFairUseStatus.full => colorScheme.error,
    };
    final message = switch (fairUse.status) {
      ProofMediaFairUseStatus.ok =>
        'Routine sync and proof photo backup are ready.',
      ProofMediaFairUseStatus.warning =>
        'Proof photo storage is nearly full. Routine sync still works.',
      ProofMediaFairUseStatus.full =>
        'Photo storage full. Routine sync still works.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.image, size: 17, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Proof photo storage: ${fairUse.storageLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fairUse.storageFraction,
              minHeight: 8,
              backgroundColor: colorScheme.outline.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fairUse.uploadLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: tone.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusPanel extends StatelessWidget {
  const _SyncStatusPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.pulse,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _VaultStatusTone tone;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tone.iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21, color: tone.iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tone.titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colorScheme.onSurface.withValues(alpha: 0.74),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: pulse == null
          ? content
          : FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 1).animate(pulse!),
              child: content,
            ),
    );
  }
}

class _VaultMetaChip extends StatelessWidget {
  const _VaultMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultStatusCopy {
  const _VaultStatusCopy({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _VaultStatusTone {
  const _VaultStatusTone({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.titleColor,
  });

  final Color background;
  final Color border;
  final Color iconColor;
  final Color titleColor;
}
