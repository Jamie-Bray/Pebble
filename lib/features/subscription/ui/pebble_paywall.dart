import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String get _storeName {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'App Store'
        : 'Google Play';
  }

  Future<void> _startPremium() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final products = ref
          .read(purchaseRepositoryProvider)
          .personalPremiumProducts;
      final selectedPlan = _effectiveSelectedPlan(products, _selectedPlan);
      final result = await ref
          .read(purchaseRepositoryProvider)
          .purchasePersonalPremium(selectedPlan);
      await _continueAfterPurchase(result);
    } catch (error) {
      if (error is PurchaseCancelledException) return;
      _showSnackBar(_purchaseErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restorePurchase() async {
    if (_busy) return;
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
    }
    if (mounted) {
      context.go('/account-hub');
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

  Future<void> _openLegalUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showSnackBar('Could not open that page.');
    }
  }

  String _purchaseErrorMessage(Object error) {
    var message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.startsWith('Bad state: ')) {
      message = message.substring('Bad state: '.length).trim();
    } else if (message.startsWith('Bad state:')) {
      message = message.substring('Bad state:'.length).trim();
    }
    if (message.isNotEmpty) {
      return message;
    }
    return '$_storeName could not complete that request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final foundation = context.darkFoundation;
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
          final selectedPlan = _effectiveSelectedPlan(products, _selectedPlan);
          final selectedProduct = _selectedProduct(products, selectedPlan);
          final purchaseUnavailableReason =
              purchaseRepository.unavailableReason;
          final selectedPlanPurchasable =
              selectedProduct.isPurchasable &&
              selectedProduct.hasValidOfferToken;
          final selectedPlanUnavailableReason =
              purchaseUnavailableReason ??
              (!selectedPlanPurchasable
                  ? _planUnavailableMessage(selectedProduct.plan)
                  : null);
          final purchasesEnabled =
              purchaseRepository.isPurchaseAvailable && selectedPlanPurchasable;

          return Scaffold(
            backgroundColor: foundation.bgBase,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: PebbleBackButton(
                        backgroundColor: Colors.transparent,
                        iconColor: null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SimplePaywallHeader(entrySource: widget.entrySource),
                    const SizedBox(height: 24),
                    const _FeaturesList(),
                    const SizedBox(height: 24),
                    _PlanSelection(
                      products: products,
                      selectedPlan: selectedPlan,
                      onSelected: (plan) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPlan = plan);
                      },
                    ),
                    const SizedBox(height: 18),
                    _PremiumActionButton(
                      busy: _busy,
                      enabled: purchasesEnabled,
                      label: _ctaLabel(selectedProduct),
                      onPressed: _startPremium,
                    ),
                    const SizedBox(height: 12),
                    const _CancelNote(),
                    const SizedBox(height: 8),
                    _SubscriptionTermsLinks(onOpen: _openLegalUrl),
                    if (selectedPlanUnavailableReason != null) ...[
                      const SizedBox(height: 12),
                      _UnavailableNotice(
                        message: selectedPlanUnavailableReason,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _RestoreLink(
                      onTap: _busy || !purchaseRepository.isPurchaseAvailable
                          ? null
                          : _restorePurchase,
                    ),
                    const SizedBox(height: 22),
                    const _DataSecurityNote(),
                    const SizedBox(height: 12),
                    const _FairUseNote(),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
      PremiumEntrySource.routineLimit ||
      PremiumEntrySource.stepLimit => 'Routines without limits',
      PremiumEntrySource.proofPhotoLimit => 'More proof when you need it',
      PremiumEntrySource.guidanceAudio => 'Your routines, in your voice',
      PremiumEntrySource.backup => 'Keep your history longer',
      PremiumEntrySource.premiumTheme => 'Make Pebble feel like yours',
      _ => 'Routines without limits',
    };
    final body = switch (entrySource) {
      PremiumEntrySource.routineLimit || PremiumEntrySource.stepLimit =>
        'Free includes 2 routines and 10 steps per routine. Premium removes the caps, keeps your history longer, and unlocks the practical extras.',
      PremiumEntrySource.proofPhotoLimit =>
        'Premium lets you save up to 4 proof photos per step, with longer history and private backup for the proof you choose.',
      PremiumEntrySource.guidanceAudio =>
        'Add short voice tips to steps, unlock every routine limit, and keep your evidence and history available for longer.',
      PremiumEntrySource.backup =>
        'Free keeps recent history on this device for 48 hours. Premium keeps recent history for 21 days, with optional backup after sign-in.',
      _ =>
        'Everything in Free, plus the tools that make Pebble genuinely yours.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PremiumBadge(),
        const SizedBox(height: 16),
        Text(title, style: _serifStyle(context, fontSize: 40, height: 1.08)),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            fontSize: 15,
            height: 1.48,
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
        const _Eyebrow('CHOOSE YOUR PLAN'),
        const SizedBox(height: 14),
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
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.fromLTRB(14, 17, 14, 14),
            decoration: BoxDecoration(
              color: selected
                  ? Color.lerp(foundation.surfaceLow, cs.primary, 0.06)
                  : foundation.surfaceLow.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.68)
                    : foundation.borderSubtle,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.plan == BillingPlan.yearly
                            ? 'YEARLY'
                            : 'MONTHLY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: foundation.textMuted,
                        ),
                      ),
                    ),
                    _PlanRadio(selected: selected, color: cs.primary),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    product.priceLabel,
                    style: _serifStyle(context, fontSize: 32, height: 1.1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isYearly ? 'per year' : 'per month',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foundation.textMuted,
                  ),
                ),
                if (isYearly) ...[
                  const SizedBox(height: 2),
                  Text(
                    _yearlyPerMonthLabel(product),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: foundation.textMuted),
                  ),
                  const SizedBox(height: 10),
                  const _SmallSaveBadge(label: 'BEST VALUE'),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cancel anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: foundation.textMuted),
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
    final foundation = context.darkFoundation;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : foundation.borderSubtle,
          width: 2,
        ),
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
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    final foundation = context.darkFoundation;
    return Text(
      'Cancel anytime. No free-trial small print.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: foundation.textMuted,
      ),
    );
  }
}

class _SubscriptionTermsLinks extends StatelessWidget {
  const _SubscriptionTermsLinks({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Auto-renews until canceled.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foundation.textMuted,
          ),
        ),
        TextButton(
          onPressed: () => onOpen('https://pebbleroutines.com/terms'),
          child: const Text('Terms'),
        ),
        TextButton(
          onPressed: () => onOpen('https://pebbleroutines.com/privacy'),
          child: const Text('Privacy'),
        ),
      ],
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
        _Eyebrow('PEBBLE PREMIUM INCLUDES'),
        SizedBox(height: 16),
        _FeatureListItem(
          icon: LucideIcons.infinity,
          tint: _PremiumTint.blue,
          title: 'Unlimited routines & steps',
          body:
              'Build every routine you actually need, with no cap on routines and no cap on steps.',
          upgradeLabel: 'Free: 2 routines / 10 steps -> Premium: unlimited',
        ),
        _FeatureListItem(
          icon: LucideIcons.cloud,
          tint: _PremiumTint.green,
          title: 'Backup & longer history',
          body:
              'Keep recent history longer on this device. Sign in later if you want supported backup for reinstalling or changing phone.',
          upgradeLabel: 'Free: 48 hrs -> Premium: 21 days',
        ),
        _FeatureListItem(
          icon: LucideIcons.audioLines,
          tint: _PremiumTint.amber,
          title: 'Voice tips on steps',
          body:
              'Record short step guidance and play it back during the routine.',
        ),
        _FeatureListItem(
          icon: LucideIcons.images,
          tint: _PremiumTint.purple,
          title: 'More proof photos',
          body:
              'Save up to 4 photos per step when one angle is not enough reassurance.',
          upgradeLabel: 'Free: 1 photo -> Premium: 4 per step',
        ),
        _FeatureListItem(
          icon: LucideIcons.bell,
          tint: _PremiumTint.green,
          title: 'Shared reminders',
          body:
              'Let a trusted person know when a routine is done or missed. Automatic, quiet, and in your control.',
        ),
        _FeatureListItem(
          icon: LucideIcons.palette,
          tint: _PremiumTint.purple,
          title: 'Premium themes & style',
          body:
              'Unlock every premium theme, icon set, and accent colour so Pebble feels genuinely yours.',
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
    this.upgradeLabel,
  });

  final IconData icon;
  final _PremiumTint tint;
  final String title;
  final String body;
  final String? upgradeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _tintColors(context, tint);
    final foundation = context.darkFoundation;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
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
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: foundation.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: foundation.textSecondary,
                  ),
                ),
                if (upgradeLabel != null) ...[
                  const SizedBox(height: 7),
                  _UpgradePill(label: upgradeLabel!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradePill extends StatelessWidget {
  const _UpgradePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: cs.primary,
          ),
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
    final foundation = context.darkFoundation;
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          'Restore purchase \u00B7 I already have Premium',
          style: TextStyle(color: foundation.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

class _DataSecurityNote extends StatelessWidget {
  const _DataSecurityNote();
  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, size: 16, color: foundation.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Pebble only backs up routine data and proof photos you choose. Your camera roll is never scanned.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: foundation.textMuted,
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
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _CinemaColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CinemaColors.gold.withValues(alpha: 0.28)),
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
              'Pebble Premium',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foundation.textPrimary,
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
    final foundation = context.darkFoundation;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foundation.textMuted,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
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
  return GoogleFonts.dmSerifDisplay(
    color: foundation.textPrimary,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
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

class _SmallSaveBadge extends StatelessWidget {
  const _SmallSaveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _CinemaColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CinemaColors.gold.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foundation.textPrimary,
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
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.surfaceLow.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Fair use: Photo uploads pause at 1 GB active storage or 500 uploads per 30 days. Routine sync keeps working regardless. Your camera roll is not scanned.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foundation.textMuted,
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
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.surfaceLow.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(LucideIcons.info, color: foundation.textMuted, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foundation.textSecondary,
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

BillingPlan _effectiveSelectedPlan(
  List<PremiumProduct> products,
  BillingPlan selectedPlan,
) {
  final hasSelectedProduct = products.any(
    (product) => product.plan == selectedPlan,
  );
  if (!hasSelectedProduct && products.isNotEmpty) {
    return _sortedProducts(products).first.plan;
  }
  final hasSelectedPlan = products.any(
    (product) =>
        product.plan == selectedPlan &&
        product.isPurchasable &&
        product.hasValidOfferToken,
  );
  if (hasSelectedPlan) {
    return selectedPlan;
  }
  final purchasableProducts = _sortedProducts(
    products
        .where((product) => product.isPurchasable && product.hasValidOfferToken)
        .toList(),
  );
  if (purchasableProducts.isEmpty) {
    return selectedPlan;
  }
  return purchasableProducts.first.plan;
}

String _ctaLabel(PremiumProduct product) {
  final cadence = product.plan == BillingPlan.yearly ? 'yearly' : 'monthly';
  return 'Start $cadence - ${product.priceLabel}';
}

String _yearlyPerMonthLabel(PremiumProduct product) {
  final parsed = _parsePrice(product.priceLabel);
  if (parsed == null) {
    return 'best annual value';
  }
  final monthly = parsed.value / 12;
  if (parsed.suffix == 'p') {
    return 'about ${monthly.round()}p / month';
  }
  return 'about ${parsed.prefix}${monthly.toStringAsFixed(2)} / month';
}

_ParsedPrice? _parsePrice(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final numeric = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(trimmed);
  if (numeric == null) {
    return null;
  }
  final value = double.tryParse(numeric.group(1)!.replaceAll(',', '.'));
  if (value == null) {
    return null;
  }
  final prefix = trimmed.substring(0, numeric.start);
  final suffix = trimmed.substring(numeric.end).trim();
  return _ParsedPrice(
    value: suffix == 'p' ? value / 100 : value,
    prefix: suffix == 'p' ? '' : prefix,
    suffix: suffix,
  );
}

class _ParsedPrice {
  const _ParsedPrice({
    required this.value,
    required this.prefix,
    required this.suffix,
  });

  final double value;
  final String prefix;
  final String suffix;
}

String _planUnavailableMessage(BillingPlan plan) {
  final storeName = defaultTargetPlatform == TargetPlatform.iOS
      ? 'App Store'
      : 'Google Play';
  final consoleName = defaultTargetPlatform == TargetPlatform.iOS
      ? 'App Store Connect'
      : 'Play Console';
  final cadence = plan == BillingPlan.yearly ? 'Yearly' : 'Monthly';
  final lowerCadence = plan == BillingPlan.yearly ? 'yearly' : 'monthly';
  return '$cadence Pebble Premium is not available from $storeName yet. Check the $lowerCadence base plan offer token in $consoleName.';
}

const _fallbackMonthlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremium,
  basePlanId: PebbleBasePlanIds.monthly,
  plan: BillingPlan.monthly,
  title: 'Monthly',
  priceLabel: '\$0.99',
  detailLabel: 'per month. Cancel anytime.',
  isPurchasable: false,
);

const _fallbackYearlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremium,
  basePlanId: PebbleBasePlanIds.yearly,
  plan: BillingPlan.yearly,
  title: 'Yearly',
  priceLabel: '\$6.99',
  detailLabel: 'per year. About \$0.58 / month.',
  badgeLabel: 'Best value',
  isPurchasable: false,
);
