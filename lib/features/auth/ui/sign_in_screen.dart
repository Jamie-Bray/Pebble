import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
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
      final accountState = ref.read(subscriptionAccountControllerProvider);
      final isReady =
          next.status == AuthStatus.signedIn &&
          !_isBlockingBackupSetup(accountState);
      if (isReady) {
        // No success toast: the account hub we land on already shows the
        // signed-in identity and live backup status, so a banner on top of
        // it would just repeat the screen underneath.
        context.go('/account-hub');
        return;
      }
      if (next.status == AuthStatus.authError &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        ZenNotifications.showError(
          context,
          title: 'Could not sign in',
          message: next.errorMessage!,
        );
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
    final canUseGoogleSignIn = supabaseConfig.supportsGoogleSignIn;
    // App Store guideline 4.8: an app offering Google sign-in on iOS must
    // offer Sign in with Apple too, at least as prominently.
    final canUseAppleSignIn =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isBusy =
        authState.status == AuthStatus.authenticating ||
        _isBlockingBackupSetup(accountState);
    // Backup is Premium-only, so the promise on this screen depends on it.
    final hasPremium = ref.watch(entitlementStateProvider).isPersonalPaid;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.76,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.11),
                        colorScheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  children: [
                    _SignInBackRow(
                      onBack: () {
                        final router = GoRouter.of(context);
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          router.go('/account-hub');
                        }
                      },
                    ),
                    // Less air on short phones so the sign-in buttons sit
                    // nearer the fold.
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height < 700 ? 24 : 44,
                    ),
                    _SignInHero(hasPremium: hasPremium),
                    const SizedBox(height: 28),
                    _SignInPerks(hasPremium: hasPremium),
                    const SizedBox(height: 32),
                    Divider(
                      height: 1,
                      color: colorScheme.onSurface.withValues(alpha: 0.07),
                    ),
                    const SizedBox(height: 24),
                    if (!authController.isConfigured)
                      const _SignInUnavailableNotice(
                        message:
                            'Sign-in is not available in this build yet. Please check app configuration and try again.',
                      )
                    else ...[
                      if (canUseAppleSignIn) ...[
                        _AppleSignInButton(
                          onTap: isBusy ? null : authController.signInWithApple,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (canUseGoogleSignIn) ...[
                        _SignInButton(
                          leading: const _GoogleGMark(),
                          label: 'Continue with Google',
                          googleStyle: true,
                          onTap: isBusy
                              ? null
                              : authController.signInWithGoogle,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _SignInButton(
                        icon: LucideIcons.mail,
                        label: 'Continue with Email',
                        filled: !canUseGoogleSignIn && !canUseAppleSignIn,
                        onTap: isBusy
                            ? null
                            : () => showEmailOtpSheet(context, ref),
                      ),
                      if (ref
                          .watch(entitlementStateProvider)
                          .isPersonalPaid) ...[
                        const SizedBox(height: 16),
                        const _BackupOnSignInNote(),
                      ],
                    ],
                    const SizedBox(height: 28),
                    _NoAccountNote(onTap: () => showAuthMethodSheet(context)),
                  ],
                ),
              ),
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
        return 'Turning on backup...';
      case PersonalCloudAccessStatus.consentRequired:
        return 'Getting your account ready...';
      case PersonalCloudAccessStatus.available:
        return 'Getting everything ready...';
      case PersonalCloudAccessStatus.error:
      case PersonalCloudAccessStatus.verificationFailed:
        return 'Finalizing your setup...';
      case PersonalCloudAccessStatus.offFree:
      case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      case PersonalCloudAccessStatus.pausedSignedOut:
      case PersonalCloudAccessStatus.expiredGrace:
      case PersonalCloudAccessStatus.accountSwitchBlocked:
        return 'Getting everything ready...';
    }
  }

  bool _isBlockingBackupSetup(SubscriptionAccountState accountState) {
    return accountState.bootstrapStatus == BootstrapStatus.preparing ||
        accountState.bootstrapStatus == BootstrapStatus.syncing;
  }
}

class _SignInBackRow extends StatelessWidget {
  const _SignInBackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        PebbleBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        Text(
          'YOUR ACCOUNT',
          style: PebbleFonts.sans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.44,
            color: colorScheme.onSurface.withValues(alpha: 0.30),
          ),
        ),
      ],
    );
  }
}

class _SignInHero extends StatelessWidget {
  const _SignInHero({required this.hasPremium});

  final bool hasPremium;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (lead, accent) = hasPremium
        ? ('Your routines,\n', 'backed up.')
        : ('Your Pebble\n', 'account.');
    final intro = hasPremium
        ? 'Sign in to back up your routines and restore them on a new phone. '
        : 'Sign in to link Pebble to your account. Backup and restore come '
              'with Premium, so you can add them whenever you like. ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: lead),
              TextSpan(
                text: accent,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          style: PebbleFonts.serif(
            fontSize: 38,
            height: 1.08,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: intro),
              TextSpan(
                text: 'Pebble works fully offline',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: ' without an account.'),
            ],
          ),
          style: PebbleFonts.sans(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.65,
            color: colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _SignInPerks extends StatelessWidget {
  const _SignInPerks({required this.hasPremium});

  final bool hasPremium;

  @override
  Widget build(BuildContext context) {
    final perks = hasPremium
        ? const [
            (
              'Keep your recent history',
              'Back up up to 21 days of completed routines.',
            ),
            (
              'Photos included',
              'Proof photos back up with the routines they belong to.',
            ),
            (
              'Switch phones',
              'Sign in on a new phone and restore your backup there.',
            ),
          ]
        : const [
            (
              'Already have Premium?',
              'Sign in with the account you used before to get Premium and '
                  'your backup back.',
            ),
            (
              'Ready for backup',
              'If you get Premium later, backup can start straight away.',
            ),
            ('Optional', 'Everything else in Pebble works without an account.'),
          ];
    return Column(
      children: [
        for (var i = 0; i < perks.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _SignInPerk(title: perks[i].$1, body: perks[i].$2),
        ],
      ],
    );
  }
}

class _SignInPerk extends StatelessWidget {
  const _SignInPerk({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.50),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: ' – $body'),
              ],
            ),
            style: PebbleFonts.sans(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.45,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown to Premium users only: signing in is also the moment backup turns
/// on, so the choice has to be stated right here, where they act on it.
class _BackupOnSignInNote extends StatelessWidget {
  const _BackupOnSignInNote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.cloudUpload,
          size: 15,
          color: colorScheme.primary.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Signing in turns on backup for this account. Pebble backs up '
            'routines, history, and proof photos, which can include personal '
            'details. You can pause backup any time in Your Account.',
            style: PebbleFonts.sans(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              height: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.48),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignInUnavailableNotice extends StatelessWidget {
  const _SignInUnavailableNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: PebbleFonts.sans(
          fontSize: 14,
          height: 1.45,
          color: colorScheme.onSurface.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class _NoAccountNote extends StatelessWidget {
  const _NoAccountNote({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Pebble is fully functional offline.',
          textAlign: TextAlign.center,
          style: PebbleFonts.sans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary.withValues(alpha: 0.62),
            textStyle: PebbleFonts.sans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          child: const Text('How does backup work?'),
        ),
      ],
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.filled = false,
    this.googleStyle = false,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool googleStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
    );
    final iconWidget = leading ?? Icon(icon, size: 18);
    if (googleStyle) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: iconWidget,
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F1F1F),
            disabledForegroundColor: const Color(
              0xFF1F1F1F,
            ).withValues(alpha: 0.38),
            side: BorderSide(
              color: const Color(
                0xFFDADCE0,
              ).withValues(alpha: onTap == null ? 0.54 : 1),
            ),
            shape: shape,
            textStyle: PebbleFonts.sans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: iconWidget,
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: shape,
            textStyle: PebbleFonts.sans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: iconWidget,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface.withValues(alpha: 0.55),
          side: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.14),
          ),
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: PebbleFonts.sans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Apple's own button, so it meets the Sign in with Apple design rules. Kept
/// at the same 52dp height and pill shape as the other sign-in buttons.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: IgnorePointer(
        ignoring: onTap == null,
        child: SignInWithAppleButton(
          onPressed: onTap ?? () {},
          text: 'Continue with Apple',
          height: 52,
          style: isDark
              ? SignInWithAppleButtonStyle.white
              : SignInWithAppleButtonStyle.black,
          borderRadius: const BorderRadius.all(Radius.circular(100)),
        ),
      ),
    );
  }
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleGMarkPainter()),
    );
  }
}

class _GoogleGMarkPainter extends CustomPainter {
  const _GoogleGMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.16;
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - strokeWidth * 2,
      size.height - strokeWidth * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    void arc(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    arc(const Color(0xFF4285F4), -0.08, 1.05);
    arc(const Color(0xFF34A853), 0.96, 0.78);
    arc(const Color(0xFFFBBC05), 1.72, 0.72);
    arc(const Color(0xFFEA4335), 2.42, 1.28);

    paint
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.square;
    final center = size.center(Offset.zero);
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(rect.right, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, center.dy),
      Offset(rect.right, center.dy + strokeWidth * 1.45),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) => false;
}
