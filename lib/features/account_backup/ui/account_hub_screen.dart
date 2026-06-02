import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
        secondaryLabel: 'Keep local for now',
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
    setState(() => _restoreInFlight = true);
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .restorePurchases();
      if (!mounted) {
        return;
      }
      _showVaultSnackBar(result.message);
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
      _showVaultSnackBar(_toUserFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _restoreInFlight = false);
      }
    }
  }

  Future<void> _openManagePlan() async {
    final rawUrl = ref.read(purchaseRepositoryProvider).manageSubscriptionsUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      _showVaultSnackBar('Subscription management is not ready yet.');
      return;
    }
    final url = Uri.parse(rawUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showVaultSnackBar('Could not open subscription management.');
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
                  _showVaultSnackBar(
                    'Could not open the account deletion page.',
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
