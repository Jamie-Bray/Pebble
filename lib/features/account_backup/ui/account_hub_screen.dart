import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/account_backup/providers/account_profile_presentation_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_lapse_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/subscription/ui/premium_lapse_ui.dart';

class AccountHubScreen extends ConsumerStatefulWidget {
  const AccountHubScreen({super.key});

  @override
  ConsumerState<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends ConsumerState<AccountHubScreen> {
  bool _restoreInFlight = false;
  bool _deleteInFlight = false;

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
            .refreshCloudAccessAfterEntitlementChange(
              refreshEntitlement: false,
            );
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
        'Manage your subscription in your app store account settings.',
        title: 'Manage subscription',
        type: NotificationType.info,
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
        body:
            'This deletes your Pebble account and cloud backup data. Local routines already saved on this device will stay here until you remove them manually.',
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
          // Required by Apple and Google: deleting the account is not the
          // same as cancelling the store subscription.
          _AccountSheetWarningRow(
            icon: LucideIcons.creditCard,
            text:
                'If you have Personal Premium, this does not cancel it. To '
                'stop renewals, cancel in your app store subscription '
                'settings.',
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authSessionProvider);
    final profile = ref.watch(accountProfilePresentationProvider);
    final backupSummary = ref.watch(accountBackupStatusSummaryProvider);
    final lifecycle = ref.watch(subscriptionLifecycleProvider);
    final isLapsedPremium =
        lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace ||
        lifecycle.phase == SubscriptionLifecyclePhase.expired;

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
          subtitle: isLapsedPremium
              ? 'Premium ended'
              : 'Plan, sign-in and backup',
          onBack: _exitVault,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          children: [
            if (profile.isSignedIn) ...[
              _AccountIdentityHeader(profile: profile),
              const SizedBox(height: 24),
            ],
            // The plan always leads: what you have, and (for Premium) when
            // the current period ends. After a lapse, what changed and by
            // when leads instead; the account rows below stay available.
            if (isLapsedPremium) ...[
              _LapsedPremiumSection(
                state: _buildLapsedPremiumState(lifecycle),
                onRenew: () => context.push(
                  premiumRoute(source: PremiumEntrySource.routineLimit),
                ),
                onManagePlan: _openManagePlan,
                onChooseRoutines: () => showKeepRoutinesSheet(context),
              ),
              const SizedBox(height: 28),
            ] else ...[
              _AccountPlanCard(profile: profile),
              const SizedBox(height: 14),
            ],
            if (profile.canStartPremium && !isLapsedPremium) ...[
              _AccountUpgradeCard(
                onGetPremium: () => context.push(
                  premiumRoute(source: PremiumEntrySource.backup),
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Signed out, sign-in is always offered: it is how a returning
            // Premium user gets their plan and backup back on a new phone.
            if (profile.canSignIn) ...[
              _AccountSignInCard(
                hasPremium: profile.hasPremium,
                onSignIn: () => context.push('/sign-in'),
              ),
              const SizedBox(height: 14),
            ],
            _AccountSettingsRows(
              canRestorePurchase: profile.canRestorePurchase,
              // After a lapse the section above already offers it.
              canManagePlan: profile.canManagePlan && !isLapsedPremium,
              restoreInFlight: _restoreInFlight,
              backupStatus: backupSummary.label,
              onRestorePurchase: _restoreInFlight ? null : _restorePurchase,
              onManagePlan: _openManagePlan,
              onOpenBackup: () => context.push('/cloud-backup'),
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
                  'Local routines stay on this device.',
                  title: 'Signed out',
                  type: NotificationType.info,
                );
              }
            },
            child: Text(
              'Sign out',
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
              _deleteInFlight ? 'Deleting account...' : 'Delete account',
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
    final purchase = ref.watch(purchaseRepositoryProvider);
    final products = purchase.personalPremiumProducts;
    final monthly = _productForPlan(products, BillingPlan.monthly);
    final yearly = _productForPlan(products, BillingPlan.yearly);

    return _LapsedPremiumState(
      summary: ref.watch(premiumLapseSummaryProvider),
      graceDays: _remainingGraceDays(lifecycle),
      // Only real store prices; never a made-up fallback.
      monthlyPrice: monthly?.priceLabel.trim().isNotEmpty == true
          ? monthly!.priceLabel
          : null,
      yearlyPrice: yearly?.priceLabel.trim().isNotEmpty == true
          ? yearly!.priceLabel
          : null,
    );
  }
}

class _AccountIdentityHeader extends StatelessWidget {
  const _AccountIdentityHeader({required this.profile});

  final AccountProfilePresentation profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final caption = profile.providerLabel == null
        ? profile.identityDetail
        : 'Signed in with ${profile.providerLabel}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              profile.isSignedIn ? LucideIcons.userCheck : LucideIcons.user,
              size: 21,
              color: colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.identityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
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

class _AccountPlanCard extends StatelessWidget {
  const _AccountPlanCard({required this.profile});

  final AccountProfilePresentation profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final periodLine = profile.planPeriodLine;
    // Just the facts: plan name, status and what it includes. The selling
    // happens in the upgrade card below, not here.
    return _AccountSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                profile.planName,
                style: GoogleFonts.dmSerifDisplay(
                  color: colorScheme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.05,
                ),
              ),
              if (profile.hasPremium)
                _AccountPill(label: profile.planStatusLabel),
            ],
          ),
          if (periodLine != null) ...[
            const SizedBox(height: 8),
            Text(
              periodLine,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _AccountLimitGrid(limits: profile.limits),
        ],
      ),
    );
  }
}

/// Offered whenever nobody is signed in. Free users see it as the way back
/// to Premium they already bought; Premium users as the way to turn on
/// backup.
class _AccountSignInCard extends StatelessWidget {
  const _AccountSignInCard({required this.hasPremium, required this.onSignIn});

  final bool hasPremium;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = hasPremium ? 'Sign in to back up' : 'Already have Premium?';
    final body = hasPremium
        ? 'Premium is active on this phone. Sign in so Pebble can back up '
              'your routines and restore them on a new phone.'
        : 'Sign in with the account you used before. Pebble brings back '
              'your Premium and your backup. If Premium does not appear, use '
              'Restore purchase below.';
    return _AccountSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSerifDisplay(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: GoogleFonts.outfit(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onSignIn,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(LucideIcons.logIn, size: 18),
            label: const Text(
              'Sign in',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountUpgradeCard extends StatelessWidget {
  const _AccountUpgradeCard({required this.onGetPremium});

  final VoidCallback onGetPremium;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Premium',
            style: GoogleFonts.dmSerifDisplay(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Get 21 days of history, unlimited routines and steps, and '
            'cloud backup when you choose to turn it on.',
            style: GoogleFonts.outfit(
              color: colorScheme.onSurface.withValues(alpha: 0.66),
              fontSize: 13.5,
              fontWeight: FontWeight.w300,
              letterSpacing: 0,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onGetPremium,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(LucideIcons.sparkles, size: 18),
            label: const Text(
              'Get Premium',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSettingsRows extends StatelessWidget {
  const _AccountSettingsRows({
    required this.canRestorePurchase,
    required this.canManagePlan,
    required this.restoreInFlight,
    required this.backupStatus,
    required this.onRestorePurchase,
    required this.onManagePlan,
    required this.onOpenBackup,
  });

  final bool canRestorePurchase;
  final bool canManagePlan;
  final bool restoreInFlight;
  final String backupStatus;
  final VoidCallback? onRestorePurchase;
  final VoidCallback onManagePlan;
  final VoidCallback onOpenBackup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      if (canManagePlan)
        _AccountSettingsRow(
          icon: LucideIcons.creditCard,
          label: 'Manage subscription',
          onTap: onManagePlan,
        ),
      if (canRestorePurchase)
        _AccountSettingsRow(
          icon: LucideIcons.rotateCw,
          label: restoreInFlight ? 'Restoring...' : 'Restore purchase',
          onTap: onRestorePurchase,
        ),
      _AccountSettingsRow(
        icon: LucideIcons.cloud,
        label: 'Backup',
        value: backupStatus,
        onTap: onOpenBackup,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outline.withValues(alpha: 0.10),
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountSettingsRow extends StatelessWidget {
  const _AccountSettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.56),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  color: colorScheme.onSurface.withValues(
                    alpha: onTap == null ? 0.45 : 0.86,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountLimitGrid extends StatelessWidget {
  const _AccountLimitGrid({required this.limits});

  final List<AccountProfileLimit> limits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < limits.length; index++) ...[
          Expanded(child: _AccountLimitTile(limit: limits[index])),
          if (index != limits.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AccountLimitTile extends StatelessWidget {
  const _AccountLimitTile({required this.limit});

  final AccountProfileLimit limit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                limit.value,
                maxLines: 1,
                style: GoogleFonts.dmSerifDisplay(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              limit.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface.withValues(alpha: 0.56),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSurface extends StatelessWidget {
  const _AccountSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: colorScheme.onSurface.withValues(alpha: 0.66),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
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
    required this.summary,
    required this.graceDays,
    required this.monthlyPrice,
    required this.yearlyPrice,
  });

  final PremiumLapseSummary summary;
  final int graceDays;
  final String? monthlyPrice;
  final String? yearlyPrice;
}

/// Top of the account screen once Premium has ended: what changed, by when,
/// and what the user can do (renew, choose routines to keep). The normal
/// account rows (sign in, restore, backup, sign out, delete) follow it.
class _LapsedPremiumSection extends StatelessWidget {
  const _LapsedPremiumSection({
    required this.state,
    required this.onRenew,
    required this.onManagePlan,
    required this.onChooseRoutines,
  });

  final _LapsedPremiumState state;
  final VoidCallback onRenew;
  final VoidCallback onManagePlan;
  final VoidCallback onChooseRoutines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = state.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LapsedHero(
          inGrace: summary.inGrace,
          graceEndDate: summary.graceEndDateLabel,
        ),
        const SizedBox(height: 24),
        _RiskCard(
          icon: LucideIcons.clock3,
          title: 'Longer history',
          body: _historyBody(summary),
          countdown: summary.inGrace
              ? _countdownLabel(state.graceDays)
              : 'FREE LIMITS APPLY',
          progress: summary.inGrace ? state.graceDays / 7 : 0,
        ),
        if (summary.hasMoreRoutinesThanFree) ...[
          const SizedBox(height: 10),
          _RiskCard(
            icon: LucideIcons.listChecks,
            title: 'Extra routines and steps',
            body: _routinesBody(summary),
            countdown: summary.inGrace
                ? _countdownLabel(state.graceDays)
                : 'FREE LIMITS APPLY',
            progress: summary.inGrace ? state.graceDays / 7 : 0,
            actionLabel: 'Choose ${summary.freeRoutineLimit} routines to keep',
            onAction: onChooseRoutines,
          ),
        ],
        const SizedBox(height: 24),
        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.12)),
        const SizedBox(height: 20),
        _LapsedCtaSection(
          monthlyPrice: state.monthlyPrice,
          yearlyPrice: state.yearlyPrice,
          onRenew: onRenew,
          onManagePlan: onManagePlan,
        ),
        const SizedBox(height: 18),
        Text(
          'Works without an account · Cancel anytime',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.3,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  static String _countdownLabel(int days) =>
      '$days ${days == 1 ? 'DAY' : 'DAYS'} LEFT';

  static String _historyBody(PremiumLapseSummary summary) {
    final backupLine = summary.isSignedIn
        ? ' If backup was on, your account keeps a copy, and the last 21 days '
              'come back when you renew.'
        : ' If backup was on, your account keeps a copy. Renew and sign in to '
              'bring back the last 21 days.';
    if (summary.inGrace) {
      final date = summary.graceEndDateLabel;
      if (summary.olderHistoryRunCount == 0) {
        return 'Your history is still here. From $date, Free keeps the last '
            '48 hours on this phone.$backupLine';
      }
      final count = summary.olderHistoryRunCount;
      return '$count completed ${count == 1 ? 'routine' : 'routines'} older '
          'than 48 hours stay on this phone until $date. After that they are '
          'removed from this phone, because Free keeps 48 hours. Renew before '
          'then to keep them.$backupLine';
    }
    return 'Free keeps the last 48 hours of history on this phone.$backupLine';
  }

  static String _routinesBody(PremiumLapseSummary summary) {
    final limit = summary.freeRoutineLimit;
    if (summary.inGrace) {
      return 'Free includes $limit routines with up to 10 steps each. From '
          '${summary.graceEndDateLabel}, the others lock until you renew. '
          'Nothing is deleted, and you choose which $limit stay unlocked.';
    }
    final locked = summary.lockedRoutineCount;
    return '$locked ${locked == 1 ? 'routine is' : 'routines are'} locked and '
        'still saved. Steps after the 10th are locked too. Everything unlocks '
        'again when you renew.';
  }
}

class _LapsedHero extends StatelessWidget {
  const _LapsedHero({required this.inGrace, required this.graceEndDate});

  final bool inGrace;
  final String graceEndDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Premium has\n'),
              TextSpan(
                text: 'ended.',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 38,
            height: 1.06,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          inGrace
              ? 'Everything stays as it is on this phone until $graceEndDate. '
                    'Here is what changes after that.'
              : 'Pebble now uses Free limits. Here is what that means for '
                    'what you saved.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.6,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.countdown,
    required this.progress,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String countdown;
  final double progress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Information, not an alarm: one calm accent for both cards.
    final accent = colorScheme.primary;
    final actionLabel = this.actionLabel;

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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  countdown,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
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
    required this.onRenew,
    required this.onManagePlan,
  });

  final String? monthlyPrice;
  final String? yearlyPrice;
  final VoidCallback onRenew;
  final VoidCallback onManagePlan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthlyPrice = this.monthlyPrice;
    final yearlyPrice = this.yearlyPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (monthlyPrice != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text(
                monthlyPrice,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 30,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '/ month',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              if (yearlyPrice != null)
                _AccountPill(label: 'or $yearlyPrice/year'),
            ],
          ),
        if (monthlyPrice != null) const SizedBox(height: 14),
        // Always tappable: the paywall explains a store problem and offers
        // Try again, which a disabled button here never could.
        FilledButton.icon(
          onPressed: onRenew,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('Renew Premium'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onManagePlan,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Manage subscription'),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final foreground = colorScheme.onSurface;
    final secondaryText = foreground.withValues(alpha: 0.68);

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
