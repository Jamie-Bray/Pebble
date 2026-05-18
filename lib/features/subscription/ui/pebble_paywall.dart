import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';

enum PremiumEntrySource {
  general,
  premiumTheme,
  backup,
  routineLimit,
  stepLimit,
  guidanceAudio,
  proofPhotoLimit,
}

extension PremiumEntrySourceParsing on PremiumEntrySource {
  static PremiumEntrySource fromQuery(String? value) {
    return switch (value) {
      'premium_theme' => PremiumEntrySource.premiumTheme,
      'backup' => PremiumEntrySource.backup,
      'routine_limit' => PremiumEntrySource.routineLimit,
      'step_limit' => PremiumEntrySource.stepLimit,
      'guidance_audio' => PremiumEntrySource.guidanceAudio,
      'proof_photo_limit' => PremiumEntrySource.proofPhotoLimit,
      _ => PremiumEntrySource.general,
    };
  }

  String get queryValue {
    return switch (this) {
      PremiumEntrySource.general => 'general',
      PremiumEntrySource.premiumTheme => 'premium_theme',
      PremiumEntrySource.backup => 'backup',
      PremiumEntrySource.routineLimit => 'routine_limit',
      PremiumEntrySource.stepLimit => 'step_limit',
      PremiumEntrySource.guidanceAudio => 'guidance_audio',
      PremiumEntrySource.proofPhotoLimit => 'proof_photo_limit',
    };
  }
}

String premiumRoute({PremiumEntrySource source = PremiumEntrySource.general}) {
  return source == PremiumEntrySource.general
      ? '/premium'
      : '/premium?source=${source.queryValue}';
}

class PebblePaywall extends ConsumerStatefulWidget {
  const PebblePaywall({
    super.key,
    this.entrySource = PremiumEntrySource.general,
  });

  final PremiumEntrySource entrySource;

  @override
  ConsumerState<PebblePaywall> createState() => _PebblePaywallState();
}

class _PebblePaywallState extends ConsumerState<PebblePaywall> {
  final ScrollController _scrollController = ScrollController();
  BillingPlan _selectedPlan = BillingPlan.yearly;
  bool _busy = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startPremium() async {
    if (_busy) return;
    final auth = ref.read(authSessionProvider);
    if (!auth.isSignedIn) {
      await ref.read(authControllerProvider.notifier).beginPremiumUpgrade();
      if (mounted) {
        _showSnackBar('Sign in first, then Google Play will handle checkout.');
        context.push('/sign-in');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .purchasePersonalPremium(_selectedPlan);
      await _continueAfterPurchase(result);
    } catch (error) {
      _showSnackBar(_purchaseErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restorePurchase() async {
    if (_busy) return;
    final auth = ref.read(authSessionProvider);
    if (!auth.isSignedIn) {
      await ref.read(authControllerProvider.notifier).beginPremiumUpgrade();
      if (mounted) {
        _showSnackBar('Sign in first so Pebble can verify Google Play.');
        context.push('/sign-in');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .restorePurchases();
      await _continueAfterPurchase(result);
    } catch (error) {
      _showSnackBar(_purchaseErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _continueAfterPurchase(PurchaseResult result) async {
    if (!mounted) return;
    _showSnackBar(result.message);
    final auth = ref.read(authSessionProvider);
    if (auth.isSignedIn) {
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
      if (mounted) {
        context.go('/account-hub');
      }
      return;
    }

    await ref.read(authControllerProvider.notifier).beginPremiumUpgrade();
    if (mounted) {
      context.push('/sign-in');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  String _purchaseErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isNotEmpty && !message.startsWith('Bad state:')) {
      return message;
    }
    return 'Google Play could not complete that request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final foundation = context.darkFoundation;
    final cs = parentTheme.colorScheme;
    final cinemaTheme = parentTheme.copyWith(
      scaffoldBackgroundColor: foundation.bgBase,
      colorScheme: parentTheme.colorScheme.copyWith(
        surface: foundation.bgBase,
        onSurface: foundation.textPrimary,
      ),
      textTheme: GoogleFonts.figtreeTextTheme(parentTheme.textTheme).apply(
        bodyColor: foundation.textPrimary,
        displayColor: foundation.textPrimary,
      ),
    );

    return Theme(
      data: cinemaTheme,
      child: Builder(
        builder: (context) {
          final purchaseRepository = ref.watch(purchaseRepositoryProvider);
          final products = purchaseRepository.personalPremiumProducts;
          final selectedProduct = _selectedProduct(products, _selectedPlan);
          final purchaseUnavailableReason =
              purchaseRepository.unavailableReason;
          final purchasesEnabled =
              purchaseRepository.isPurchaseAvailable &&
              selectedProduct.isPurchasable;

          return Scaffold(
            backgroundColor: foundation.bgBase,
            body: Stack(
              children: [
                Positioned.fill(child: _AmbientGlows(accent: cs.primary)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CinemaGrainPainter(baseColor: foundation.bgBase),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SimplePaywallHeader(entrySource: widget.entrySource),
                        const SizedBox(height: 32),

                        _PlanSelection(
                          products: products,
                          selectedPlan: _selectedPlan,
                          onSelected: (plan) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPlan = plan);
                          },
                        ),

                        const SizedBox(height: 24),

                        _PremiumActionButton(
                          busy: _busy,
                          enabled: purchasesEnabled,
                          label: _ctaLabel(selectedProduct),
                          onPressed: _startPremium,
                        ),

                        const SizedBox(height: 12),
                        const _CancelNote(),
                        if (purchaseUnavailableReason != null) ...[
                          const SizedBox(height: 12),
                          _UnavailableNotice(
                            message: purchaseUnavailableReason,
                          ),
                        ],
                        const SizedBox(height: 48),

                        const _FeaturesList(),

                        const SizedBox(height: 40),

                        _RestoreLink(
                          onTap:
                              _busy || !purchaseRepository.isPurchaseAvailable
                              ? null
                              : _restorePurchase,
                        ),

                        const SizedBox(height: 40),
                        const _DataSecurityNote(),
                        const SizedBox(height: 16),
                        const _FairUseNote(),
                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 20,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  left: 20,
                  child: const PebbleBackButton(
                    backgroundColor: Colors.transparent,
                    iconColor: null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AmbientGlows extends StatelessWidget {
  const _AmbientGlows({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        _AmbientGlow(
          color: accent,
          size: 320,
          top: -100,
          left: -80,
          opacity: 0.08,
        ),
        _AmbientGlow(
          color: cs.secondary,
          size: 320,
          top: 300,
          right: -100,
          opacity: 0.06,
        ),
        _AmbientGlow(
          color: cs.tertiary,
          size: 280,
          bottom: -100,
          left: -60,
          opacity: 0.05,
        ),
      ],
    );
  }
}

class _SimplePaywallHeader extends StatelessWidget {
  const _SimplePaywallHeader({required this.entrySource});
  final PremiumEntrySource entrySource;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final title = switch (entrySource) {
      PremiumEntrySource.routineLimit => 'You have reached the free limit.',
      _ => 'More of\nPebble.',
    };
    final body = switch (entrySource) {
      PremiumEntrySource.routineLimit =>
        'Pebble is free to use with no login and no ads. Free includes 2 routines; unlimited routines are part of Pebble Premium.',
      _ =>
        'Unlimited routines, proof photo backup, shared reminders, and every premium theme.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(alignment: Alignment.centerRight, child: _PremiumBadge()),
        const SizedBox(height: 52),
        const _Eyebrow('UNLOCK EVERYTHING'),
        const SizedBox(height: 14),
        Text(title, style: _serifStyle(context, fontSize: 56, height: 0.95)),
        const SizedBox(height: 24),
        Text(
          body,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: foundation.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PlanSelection extends StatelessWidget {
  const _PlanSelection({
    required this.products,
    required this.selectedPlan,
    required this.onSelected,
  });

  final List<PremiumProduct> products;
  final BillingPlan selectedPlan;
  final ValueChanged<BillingPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedProducts(products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('PICK A PLAN'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final product in sorted)
              _CompactPlanCard(
                product: product,
                selected: product.plan == selectedPlan,
                onTap: () => onSelected(product.plan),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompactPlanCard extends StatelessWidget {
  const _CompactPlanCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final PremiumProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isYearly = product.plan == BillingPlan.yearly;
    final color = isYearly ? _CinemaColors.blue : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have 2 plans, each gets half minus spacing.
        // If more, they wrap naturally.
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: cardWidth > 140 ? cardWidth : double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      product.plan == BillingPlan.yearly ? 'YEARLY' : 'MONTHLY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const Spacer(),
                    _PlanRadio(selected: selected, color: color),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    product.priceLabel,
                    style: _serifStyle(context, fontSize: 32, height: 1.1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isYearly ? 'per year.' : 'per month.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                if (isYearly) ...[
                  Text(
                    'About 46p / month.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SmallSaveBadge(label: 'SAVE 54%'),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cancel anytime.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 28), // Spacer to match yearly height
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? color : Colors.white24, width: 2),
      ),
      padding: const EdgeInsets.all(3),
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: busy || !enabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      child: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

class _CancelNote extends StatelessWidget {
  const _CancelNote();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Cancel anytime. No commitment.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: Colors.white38),
    );
  }
}

class _FeaturesList extends StatelessWidget {
  const _FeaturesList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow('WHAT YOU GET'),
        SizedBox(height: 16),
        _FeatureListItem(
          icon: LucideIcons.camera,
          tint: _PremiumTint.amber,
          title: 'Proof photo backup',
          isExclusive: true,
          body:
              'Take a photo as proof you completed a step. Stored privately and backed up securely - for reassurance later. Your camera roll is never scanned.',
        ),
        _FeatureListItem(
          icon: LucideIcons.infinity,
          tint: _PremiumTint.blue,
          title: 'Unlimited routines & steps',
          body:
              'Build every routine you actually need - not just the few you\'re allowed. No caps on routines, no caps on steps.',
        ),
        _FeatureListItem(
          icon: LucideIcons.bell,
          tint: _PremiumTint.green,
          title: 'Shared reminders',
          body:
              'Let a trusted person know when a routine is done or missed. Automatic, quiet, and entirely in your control.',
        ),
        _FeatureListItem(
          icon: LucideIcons.palette,
          tint: _PremiumTint.purple,
          title: 'Premium themes & style',
          body:
              'Unlock Aurora, Ember, Ocean, and more. Every theme, icon set, and accent colour - make Pebble feel genuinely yours.',
        ),
      ],
    );
  }
}

class _FeatureListItem extends StatelessWidget {
  const _FeatureListItem({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    this.isExclusive = false,
  });

  final IconData icon;
  final _PremiumTint tint;
  final String title;
  final String body;
  final bool isExclusive;

  @override
  Widget build(BuildContext context) {
    final colors = _tintColors(context, tint);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isExclusive) ...[
                      const SizedBox(width: 8),
                      _ExclusiveBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.5),
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

class _ExclusiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _CinemaColors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _CinemaColors.amber.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'EXCLUSIVE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: _CinemaColors.amber,
        ),
      ),
    );
  }
}

class _RestoreLink extends StatelessWidget {
  const _RestoreLink({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          'Restore purchase \u00B7 I already have Premium',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DataSecurityNote extends StatelessWidget {
  const _DataSecurityNote();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.info,
          size: 16,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Pebble only backs up routine data and proof photos you choose. Your camera roll is never scanned.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              LucideIcons.sparkles,
              color: _CinemaColors.gold,
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              'Personal Premium',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.27),
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }
}

class _CinemaGrainPainter extends CustomPainter {
  const _CinemaGrainPainter({required this.baseColor});

  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = baseColor;
    canvas.drawRect(Offset.zero & size, base);

    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
    const spacing = 17.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (
        double x = (y ~/ spacing).isEven ? 0 : spacing / 2;
        x < size.width;
        x += spacing
      ) {
        canvas.drawCircle(Offset(x, y), 0.55, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CinemaGrainPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}

enum _PremiumTint { amber, blue, green, purple }

class _TintColors {
  const _TintColors({required this.accent, required this.accentAlt});

  final Color accent;
  final Color accentAlt;
}

class _CinemaColors {
  static const amber = Color(0xFFFF8C42);
  static const blue = Color(0xFF7C9EFF);
  static const green = Color(0xFF4ADE80);
  static const purple = Color(0xFFC084FC);
  static const gold = Color(0xFFF0C060);
}

TextStyle _serifStyle(
  BuildContext context, {
  required double fontSize,
  double height = 1.0,
}) {
  final foundation = context.darkFoundation;
  return GoogleFonts.cormorantGaramond(
    color: foundation.textPrimary,
    fontSize: fontSize,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: height,
  );
}

_TintColors _tintColors(BuildContext context, _PremiumTint tint) {
  final tokens = Theme.of(context).extension<PebbleTemplatesTokens>();
  return switch (tint) {
    _PremiumTint.amber => _TintColors(
      accent: tokens?.templatesAccentGroup3 ?? _CinemaColors.amber,
      accentAlt: _CinemaColors.amber,
    ),
    _PremiumTint.blue => const _TintColors(
      accent: _CinemaColors.blue,
      accentAlt: Color(0xFF5B7BFF),
    ),
    _PremiumTint.green => const _TintColors(
      accent: _CinemaColors.green,
      accentAlt: Color(0xFF22C55E),
    ),
    _PremiumTint.purple => _TintColors(
      accent: tokens?.templatesAccentGroup2 ?? _CinemaColors.purple,
      accentAlt: _CinemaColors.blue,
    ),
  };
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.color,
    required this.size,
    this.opacity = 0.10,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final Color color;
  final double size;
  final double opacity;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  @override
  Widget build(BuildContext context) {
    final glow = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
    if (top == null && right == null && bottom == null && left == null) {
      return Center(child: glow);
    }
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: glow,
    );
  }
}

class _SmallSaveBadge extends StatelessWidget {
  const _SmallSaveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _CinemaColors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CinemaColors.green.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _CinemaColors.green,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _FairUseNote extends StatelessWidget {
  const _FairUseNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.026),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Fair use: Photo uploads pause at 1 GB active storage or 500 uploads per 30 days. Routine sync keeps working regardless. Your camera roll is not scanned.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.42),
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              LucideIcons.info,
              color: Colors.white.withValues(alpha: 0.42),
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.46),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<PremiumProduct> _sortedProducts(List<PremiumProduct> products) {
  return <PremiumProduct>[
    ...products.where((product) => product.plan == BillingPlan.yearly),
    ...products.where((product) => product.plan == BillingPlan.monthly),
  ];
}

PremiumProduct _selectedProduct(
  List<PremiumProduct> products,
  BillingPlan selectedPlan,
) {
  return products.firstWhere(
    (product) => product.plan == selectedPlan,
    orElse: () => selectedPlan == BillingPlan.yearly
        ? _fallbackYearlyProduct
        : _fallbackMonthlyProduct,
  );
}

String _ctaLabel(PremiumProduct product) {
  final suffix = product.plan == BillingPlan.yearly ? '/ year' : '/ month';
  return 'Start Premium \u00B7 ${product.priceLabel} $suffix';
}

const _fallbackMonthlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremiumMonthly,
  plan: BillingPlan.monthly,
  title: 'Monthly',
  priceLabel: '99p',
  detailLabel: 'per month. Cancel anytime.',
  isPurchasable: false,
);

const _fallbackYearlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremiumMonthly,
  plan: BillingPlan.yearly,
  title: 'Yearly',
  priceLabel: '\u00A35.49',
  detailLabel: 'per year. About 46p / month.',
  badgeLabel: 'Save 54%',
  isPurchasable: false,
);
