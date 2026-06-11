import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        final isPremium = ref.read(entitlementStateProvider).isPersonalPaid;
        ZenNotifications.showSuccess(
          context,
          title: 'Signed in',
          message: isPremium
              ? 'Backup and restore are getting ready.'
              : 'Your routines stay on this device unless you unlock Personal Premium.',
        );
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
    final canUseGoogleSignIn =
        supabaseConfig.googleWebClientId?.isNotEmpty == true;
    final isBusy =
        authState.status == AuthStatus.authenticating ||
        _isBlockingBackupSetup(accountState);

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
                    const SizedBox(height: 44),
                    const _SignInHero(),
                    const SizedBox(height: 28),
                    const _SignInPerks(),
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
                        filled: !canUseGoogleSignIn,
                        onTap: isBusy
                            ? null
                            : () => showEmailOtpSheet(context, ref),
                      ),
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
        return 'Preparing your backup...';
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
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
            icon: Icon(
              LucideIcons.chevronLeft,
              size: 16,
              color: colorScheme.onSurface,
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
            color: colorScheme.onSurface.withValues(alpha: 0.30),
          ),
        ),
      ],
    );
  }
}

class _SignInHero extends StatelessWidget {
  const _SignInHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Your routines,\n'),
              TextSpan(
                text: 'secured.',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          style: GoogleFonts.dmSerifDisplay(
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
              const TextSpan(text: 'Sign in to back up your data. '),
              TextSpan(
                text: 'Pebble works completely offline',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(
                text:
                    ' - creating an account just connects backup and restore when you choose to use them.',
              ),
            ],
          ),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.65,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _SignInPerks extends StatelessWidget {
  const _SignInPerks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SignInPerk(
          title: 'Keep Your Recent History',
          body:
              'Back up supported routine runs so restore has something ready if you change phone.',
        ),
        SizedBox(height: 14),
        _SignInPerk(
          title: 'Save Space on Your Phone',
          body:
              'Proof photos can be backed up with Premium so local storage stays easier to manage.',
        ),
        SizedBox(height: 14),
        _SignInPerk(
          title: 'Switch Devices Easily',
          body:
              'Sign in on another device and restore your backed-up routines without manual exports.',
        ),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: ' - $body'),
              ],
            ),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              height: 1.45,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
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
        style: GoogleFonts.outfit(
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
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            height: 1.6,
            color: colorScheme.onSurface.withValues(alpha: 0.28),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary.withValues(alpha: 0.62),
            textStyle: GoogleFonts.outfit(
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
            textStyle: const TextStyle(
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
            textStyle: GoogleFonts.outfit(
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
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
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
