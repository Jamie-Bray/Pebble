import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/auth/ui/auth_method_sheet.dart';
import 'package:pebble_routines/features/auth/ui/email_otp_sheet.dart';
import 'package:pebble_routines/features/auth/ui/migration_sanctuary_overlay.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) return;
      final cloudAccess = ref.read(personalCloudAccessProvider);
      final isReady =
          next.status == AuthStatus.signedIn &&
          cloudAccess.status != PersonalCloudAccessStatus.syncing;
      if (isReady) {
        HapticFeedback.mediumImpact();
        final isPremium = ref.read(entitlementStateProvider).isPersonalPaid;
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                isPremium
                    ? 'Signed in. Backup and restore are getting ready.'
                    : 'Signed in. Your routines still stay on this device unless you unlock Personal Premium.',
              ),
            ),
          );
        context.go('/account-hub');
        return;
      }
      if (next.status == AuthStatus.authError &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final accountState = ref.watch(subscriptionAccountControllerProvider);
    final cloudAccess = ref.watch(personalCloudAccessProvider);
    final supabaseConfig = ref.watch(supabaseRuntimeConfigProvider);
    final authController = ref.read(authControllerProvider.notifier);
    final canUseGoogleSignIn =
        supabaseConfig.googleWebClientId?.isNotEmpty == true;
    final isBusy =
        authState.status == AuthStatus.authenticating ||
        cloudAccess.status == PersonalCloudAccessStatus.syncing;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const PebbleSubPageHeader(
                  title: 'Sign in to back up Pebble',
                  subtitle: 'Only needed for Premium backup or restore.',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                    children: [
                      if (!authController.isConfigured)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.34,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            'Sign-in is not available in this build yet. Please check app configuration and try again.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.76,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        if (canUseGoogleSignIn) ...[
                          _SignInButton(
                            icon: LucideIcons.badgeCheck,
                            label: 'Continue with Google',
                            filled: true,
                            onTap: isBusy
                                ? null
                                : authController.signInWithGoogle,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SignInButton(
                          icon: LucideIcons.mail,
                          label: 'Use email instead',
                          filled: !canUseGoogleSignIn,
                          onTap: isBusy
                              ? null
                              : () => showEmailOtpSheet(context, ref),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Pebble is free without an account. Signing in connects your Premium backup to this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => showAuthMethodSheet(context),
                        child: const Text('Why does backup need sign-in?'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isBusy)
            MigrationSanctuaryOverlay(
              message: _overlayMessage(authState, accountState, cloudAccess),
            ),
        ],
      ),
    );
  }

  String _overlayMessage(
    AuthState authState,
    SubscriptionAccountState accountState,
    PersonalCloudAccessState cloudAccess,
  ) {
    if (authState.status == AuthStatus.authenticating &&
        accountState.bootstrapStatus == BootstrapStatus.idle) {
      return 'Signing you in...';
    }
    switch (cloudAccess.status) {
      case PersonalCloudAccessStatus.syncing:
      case PersonalCloudAccessStatus.offlinePending:
        return 'Preparing your backup...';
      case PersonalCloudAccessStatus.consentRequired:
        return 'Getting your account ready...';
      case PersonalCloudAccessStatus.available:
        return 'Getting everything ready...';
      case PersonalCloudAccessStatus.error:
        return 'Finalizing your setup...';
      case PersonalCloudAccessStatus.offFree:
      case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      case PersonalCloudAccessStatus.pausedSignedOut:
      case PersonalCloudAccessStatus.expiredGrace:
      case PersonalCloudAccessStatus.accountSwitchBlocked:
        return 'Getting everything ready...';
    }
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: shape,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: shape,
        ),
      ),
    );
  }
}
