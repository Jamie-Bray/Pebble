import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
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

enum PlanType { monthly, annual }

extension PlanTypeMapping on PlanType {
  BillingPlan get billingPlan {
    return switch (this) {
      PlanType.monthly => BillingPlan.monthly,
      PlanType.annual => BillingPlan.yearly,
    };
  }

  String get label {
    return switch (this) {
      PlanType.monthly => 'Monthly',
      PlanType.annual => 'Annual',
    };
  }

  String get ctaCadence {
    return switch (this) {
      PlanType.monthly => 'month',
      PlanType.annual => 'year',
    };
  }
}

final premiumPaywallPlanProvider = StateProvider.autoDispose<PlanType>(
  (ref) => PlanType.annual,
);

enum StorePlatform { googlePlay, appStore, other }

extension StorePlatformRuntime on StorePlatform {
  static StorePlatform get current {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => StorePlatform.appStore,
      TargetPlatform.android => StorePlatform.googlePlay,
      _ => StorePlatform.other,
    };
  }
}

class PremiumPaywallCopy {
  const PremiumPaywallCopy._({
    required this.storeName,
    required this.renewalLine,
    required this.purchaseErrorLine,
    required this.consoleName,
  });

  final String storeName;
  final String renewalLine;
  final String purchaseErrorLine;
  final String consoleName;

  static PremiumPaywallCopy forPlatform(StorePlatform platform) {
    return switch (platform) {
      StorePlatform.appStore => const PremiumPaywallCopy._(
        storeName: 'App Store',
        renewalLine:
            'Renews automatically. Cancel anytime in the App Store subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            'The App Store could not complete that request. Please try again.',
        consoleName: 'App Store Connect',
      ),
      StorePlatform.googlePlay => const PremiumPaywallCopy._(
        storeName: 'Google Play',
        renewalLine:
            'Renews automatically. Cancel anytime in Google Play subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            'Google Play could not complete that request. Please try again.',
        consoleName: 'Play Console',
      ),
      StorePlatform.other => const PremiumPaywallCopy._(
        storeName: 'the store',
        renewalLine:
            'Renews automatically. Cancel anytime through your app store subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            'The store could not complete that request. Please try again.',
        consoleName: 'store console',
      ),
    };
  }
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
  bool _busy = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  PremiumPaywallCopy get _platformCopy =>
      PremiumPaywallCopy.forPlatform(StorePlatformRuntime.current);

  void _dismissPaywall() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<void> _startPremium() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final products = ref
          .read(purchaseRepositoryProvider)
          .personalPremiumProducts;
      final selectedPlan = _effectiveSelectedPlan(
        products,
        ref.read(premiumPaywallPlanProvider).billingPlan,
      );
      final result = await ref
          .read(purchaseRepositoryProvider)
          .purchasePersonalPremium(selectedPlan);
      await _continueAfterPurchase(result);
    } catch (error) {
      if (error is PurchaseCancelledException) return;
      _showNotice(
        _purchaseErrorMessage(error),
        title: 'Purchase not completed',
        type: NotificationType.error,
      );
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
      _showNotice(
        _purchaseErrorMessage(error),
        title: 'Could not restore',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _continueAfterPurchase(PurchaseResult result) async {
    if (!mounted) return;
    _showNotice(
      result.message,
      title: result.message.toLowerCase().contains('restored')
          ? 'Purchase restored'
          : 'Premium is on',
      type: NotificationType.success,
    );
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
    if (mounted) {
      await _showPostPurchaseSignInPrompt();
    }
  }

  Future<void> _showPostPurchaseSignInPrompt() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      isScrollControlled: true,
      builder: (dialogContext) => const _PremiumActivatedSheet(),
    );
    if (!mounted) return;
    if (result == true) {
      context.go('/sign-in');
      return;
    }
    context.go('/account-hub');
  }

  void _showNotice(
    String message, {
    required String title,
    required NotificationType type,
  }) {
    if (!mounted) return;
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

  Future<void> _openLegalUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showNotice(
        'Could not open that page.',
        title: 'Could not open',
        type: NotificationType.error,
      );
    }
  }

  String _purchaseErrorMessage(Object error) {
    if (error is PurchaseFlowException) {
      return error.message;
    }
    var message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.startsWith('PlatformException')) {
      return _platformCopy.purchaseErrorLine;
    }
    if (message.startsWith('Bad state: ')) {
      message = message.substring('Bad state: '.length).trim();
    } else if (message.startsWith('Bad state:')) {
      message = message.substring('Bad state:'.length).trim();
    }
    if (message.isNotEmpty) {
      return message;
    }
    return _platformCopy.purchaseErrorLine;
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final foundation = context.darkFoundation;
    final paywallTheme = parentTheme.copyWith(
      scaffoldBackgroundColor: foundation.bgBase,
      colorScheme: parentTheme.colorScheme.copyWith(
        surface: foundation.bgBase,
        onSurface: foundation.textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(parentTheme.textTheme).apply(
        bodyColor: foundation.textPrimary,
        displayColor: foundation.textPrimary,
      ),
    );

    return Theme(
      data: paywallTheme,
      child: Builder(
        builder: (context) {
          final purchaseRepository = ref.watch(purchaseRepositoryProvider);
          final products = purchaseRepository.personalPremiumProducts;
          final selectedPlan = _effectiveSelectedPlan(
            products,
            ref.watch(premiumPaywallPlanProvider).billingPlan,
          );
          final selectedProduct = _selectedProduct(products, selectedPlan);
          final selectedPlanPurchasable =
              selectedProduct.isPurchasable &&
              selectedProduct.hasValidOfferToken;
          final selectedPlanUnavailableReason =
              purchaseRepository.unavailableReason ??
              (!selectedPlanPurchasable
                  ? _planUnavailableMessage(selectedProduct.plan, _platformCopy)
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
                padding: EdgeInsets.fromLTRB(
                  24,
                  52,
                  24,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PaywallHeader(entrySource: widget.entrySource),
                    const SizedBox(height: 28),
                    const _SectionLabel('What Premium gives you'),
                    const SizedBox(height: 2),
                    const _FeaturesList(),
                    const SizedBox(height: 20),
                    const _TrustCard(),
                    if (selectedPlanUnavailableReason != null) ...[
                      const SizedBox(height: 16),
                      _UnavailableNotice(
                        message: selectedPlanUnavailableReason,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            extendBody: false,
            bottomNavigationBar: _PricingFooter(
              products: products,
              selectedPlan: selectedPlan,
              busy: _busy,
              purchasesEnabled: purchasesEnabled,
              platformCopy: _platformCopy,
              onStartPremium: _startPremium,
              onRestorePurchase:
                  _busy || !purchaseRepository.isPurchaseAvailable
                  ? null
                  : _restorePurchase,
              onOpenLegalUrl: _openLegalUrl,
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
            floatingActionButton: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 4),
                child: PebbleBackButton(
                  onPressed: _dismissPaywall,
                  backgroundColor: foundation.textPrimary.withValues(
                    alpha: 0.12,
                  ),
                  iconColor: foundation.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PremiumActivatedSheet extends StatelessWidget {
  const _PremiumActivatedSheet();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: foundation.surfaceLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: 0.42), width: 1),
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
                      color: foundation.surfaceHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PremiumActivatedIcon(accent: accent),
                  const SizedBox(height: 24),
                  Text(
                    'Premium activated',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: _serifStyle(context, fontSize: 30, height: 1.12),
                      children: [
                        const TextSpan(text: 'One last thing\nto '),
                        TextSpan(
                          text: 'unlock it all.',
                          style: TextStyle(
                            color: accent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sign in to back up your history, routines, and photos, and keep them ready across devices. Totally optional; Premium works right now without it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foundation.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      height: 1.62,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      Expanded(
                        child: _PremiumActivatedPill(
                          value: '21 days',
                          label: 'History',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _PremiumActivatedPill(
                          value: 'Cloud',
                          label: 'Backup',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _PremiumActivatedPill(
                          value: 'Recovery',
                          label: 'Account',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    color: foundation.borderSubtle.withValues(alpha: 0.72),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Sign in to back up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foundation.textSecondary,
                        side: BorderSide(
                          color: foundation.borderSubtle.withValues(
                            alpha: 0.86,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Continue without sign-in'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'You can always sign in later from Your Account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foundation.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumActivatedIcon extends StatelessWidget {
  const _PremiumActivatedIcon({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.shieldCheck, color: accent, size: 34),
    );
  }
}

class _PremiumActivatedPill extends StatelessWidget {
  const _PremiumActivatedPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: foundation.borderSubtle.withValues(alpha: 0.62),
        ),
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
                style: _serifStyle(context, fontSize: 18, height: 1),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foundation.textSecondary,
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

class _PaywallHeader extends StatelessWidget {
  const _PaywallHeader({required this.entrySource});

  final PremiumEntrySource entrySource;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    final body = switch (entrySource) {
      PremiumEntrySource.backup =>
        'Free keeps recent history on this device for 48 hours. Premium keeps recent checks for up to 21 days, with backup when you choose to turn it on.',
      PremiumEntrySource.proofPhotoLimit =>
        'Free includes one photo per step. Premium gives you more proof when one picture does not capture the full check.',
      PremiumEntrySource.guidanceAudio =>
        'Add a short voice prompt to a step, so future-you knows exactly what to check.',
      _ =>
        'Free includes 2 routines and 10 steps each. Premium gives you unlimited routines, longer recent history, and backup when you choose to turn it on.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PremiumBadge(),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: _serifStyle(context, fontSize: 42, height: 1.05),
            children: [
              const TextSpan(text: 'Build more.\n'),
              TextSpan(
                text: 'Worry less.',
                style: TextStyle(color: accent, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          body,
          style: TextStyle(
            color: foundation.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            height: 1.65,
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
    final accent = _premiumGlow(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, color: accent, size: 12),
            const SizedBox(width: 6),
            Text(
              'Pebble Premium',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foundation.textMuted.withValues(alpha: 0.72),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _PremiumFeature {
  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.freeLabel,
    required this.premiumLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final String freeLabel;
  final String premiumLabel;
}

const _premiumFeatures = [
  _PremiumFeature(
    icon: LucideIcons.infinity,
    title: 'Unlimited routines and steps',
    description:
        'Create checks for home, work, travel, pets, and everything else you want to run clearly.',
    freeLabel: '2 routines, 10 steps',
    premiumLabel: 'Unlimited',
  ),
  _PremiumFeature(
    icon: LucideIcons.cloud,
    title: 'Longer history and backup',
    description:
        'Keep recent checks for up to 21 days, and turn on backup so your routines can come with you if you reinstall Pebble or change phone.',
    freeLabel: '48 hours',
    premiumLabel: '21 days + backup',
  ),
  _PremiumFeature(
    icon: LucideIcons.camera,
    title: 'More photos per step',
    description:
        'Add up to four photos when one picture does not capture the full check.',
    freeLabel: '1 photo',
    premiumLabel: 'Up to 4',
  ),
  _PremiumFeature(
    icon: LucideIcons.mic,
    title: 'Voice tips',
    description:
        'Add a short voice prompt to a step, so future-you knows exactly what to check.',
    freeLabel: 'Not available',
    premiumLabel: 'Included',
  ),
];

class _FeaturesList extends StatelessWidget {
  const _FeaturesList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final feature in _premiumFeatures) _FeatureListItem(feature),
      ],
    );
  }
}

class _FeatureListItem extends StatelessWidget {
  const _FeatureListItem(this.feature);

  final _PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: foundation.borderSubtle.withValues(alpha: 0.64),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(feature.icon, color: accent, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: TextStyle(
                      color: foundation.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    feature.description,
                    style: TextStyle(
                      color: foundation.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ComparisonLine(
                    freeLabel: feature.freeLabel,
                    premiumLabel: feature.premiumLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({required this.freeLabel, required this.premiumLabel});

  final String freeLabel;
  final String premiumLabel;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: freeLabel,
            style: TextStyle(
              color: foundation.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: '  >  ',
            style: TextStyle(color: foundation.textMuted),
          ),
          TextSpan(
            text: premiumLabel,
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 12, height: 1),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: foundation.borderSubtle.withValues(alpha: 0.64),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.26)),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.lock, size: 15, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private by default',
                    style: TextStyle(
                      color: foundation.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Pebble has no ads, does not sell your data, and backup only starts when you choose to turn it on.',
                    style: TextStyle(
                      color: foundation.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingFooter extends ConsumerWidget {
  const _PricingFooter({
    required this.products,
    required this.selectedPlan,
    required this.busy,
    required this.purchasesEnabled,
    required this.platformCopy,
    required this.onStartPremium,
    required this.onRestorePurchase,
    required this.onOpenLegalUrl,
  });

  final List<PremiumProduct> products;
  final BillingPlan selectedPlan;
  final bool busy;
  final bool purchasesEnabled;
  final PremiumPaywallCopy platformCopy;
  final VoidCallback onStartPremium;
  final VoidCallback? onRestorePurchase;
  final ValueChanged<String> onOpenLegalUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final selectedProduct = _selectedProduct(products, selectedPlan);
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foundation.bgBase,
          border: Border(
            top: BorderSide(
              color: foundation.borderSubtle.withValues(alpha: 0.64),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanToggle(products: products, selectedPlan: selectedPlan),
              const SizedBox(height: 14),
              _PremiumActionButton(
                busy: busy,
                enabled: purchasesEnabled,
                label: _ctaLabel(selectedProduct),
                onPressed: onStartPremium,
              ),
              const SizedBox(height: 11),
              _FinePrint(platformCopy: platformCopy),
              const SizedBox(height: 6),
              _FooterLinks(
                onRestorePurchase: onRestorePurchase,
                onOpenLegalUrl: onOpenLegalUrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanToggle extends ConsumerWidget {
  const _PlanToggle({required this.products, required this.selectedPlan});

  final List<PremiumProduct> products;
  final BillingPlan selectedPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = _sortedProducts(products);
    return Row(
      children: [
        for (final product in sorted) ...[
          Expanded(
            child: _PlanOption(
              product: product,
              selected: product.plan == selectedPlan,
              onTap: () {
                ref.read(premiumPaywallPlanProvider.notifier).state =
                    _planTypeForBillingPlan(product.plan);
              },
            ),
          ),
          if (product != sorted.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final PremiumProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    final isAnnual = product.plan == BillingPlan.yearly;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.13)
              : foundation.textPrimary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.38)
                : foundation.borderSubtle.withValues(alpha: 0.68),
            width: 1.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isAnnual)
              Positioned(
                top: -21,
                right: -4,
                child: _PlanBadge(product.badgeLabel ?? 'Best value'),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAnnual ? 'Annual' : 'Monthly',
                  style: TextStyle(
                    color: selected ? accent : foundation.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _displayPrice(product),
                    style: _serifStyle(context, fontSize: 24, height: 1),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAnnual ? _annualPerLine(product) : 'per month',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foundation.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _premiumGlow(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _PremiumActionButton extends StatefulWidget {
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
  State<_PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<_PremiumActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    lowerBound: 0.99,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _premiumGlow(context);
    final enabled = widget.enabled && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => _controller.reverse() : null,
      onTapCancel: enabled ? () => _controller.forward() : null,
      onTapUp: enabled
          ? (_) {
              _controller.forward();
              widget.onPressed();
            }
          : null,
      child: ScaleTransition(
        scale: _controller,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? accent : accent.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(16),
          ),
          child: widget.busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _FinePrint extends StatelessWidget {
  const _FinePrint({required this.platformCopy});

  final PremiumPaywallCopy platformCopy;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Text(
      platformCopy.renewalLine,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: foundation.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w300,
        height: 1.6,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({
    required this.onRestorePurchase,
    required this.onOpenLegalUrl,
  });

  final VoidCallback? onRestorePurchase;
  final ValueChanged<String> onOpenLegalUrl;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final style = TextButton.styleFrom(
      foregroundColor: foundation.textSecondary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          onPressed: onRestorePurchase,
          style: style,
          child: const Text('Restore purchase'),
        ),
        Text('|', style: TextStyle(color: foundation.textMuted, fontSize: 11)),
        TextButton(
          onPressed: () => onOpenLegalUrl('https://pebbleroutines.com/terms'),
          style: style,
          child: const Text('Terms'),
        ),
        Text('|', style: TextStyle(color: foundation.textMuted, fontSize: 11)),
        TextButton(
          onPressed: () => onOpenLegalUrl('https://pebbleroutines.com/privacy'),
          style: style,
          child: const Text('Privacy'),
        ),
      ],
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
          children: [
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

TextStyle _serifStyle(
  BuildContext context, {
  required double fontSize,
  double height = 1,
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

Color _premiumGlow(BuildContext context) {
  final theme = Theme.of(context);
  return _legibleThemeAccent(theme, theme.colorScheme.primary);
}

Color _legibleThemeAccent(ThemeData theme, Color color) {
  final hsl = HSLColor.fromColor(color);
  final saturation = (hsl.saturation * 1.08).clamp(0.36, 0.88).toDouble();
  final lightness = theme.brightness == Brightness.dark
      ? hsl.lightness.clamp(0.58, 0.76).toDouble()
      : hsl.lightness.clamp(0.34, 0.50).toDouble();
  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

List<PremiumProduct> _sortedProducts(List<PremiumProduct> products) {
  return [
    ...products.where((product) => product.plan == BillingPlan.monthly),
    ...products.where((product) => product.plan == BillingPlan.yearly),
  ];
}

PremiumProduct _selectedProduct(
  List<PremiumProduct> products,
  BillingPlan selectedPlan,
) {
  return products.firstWhere(
    (product) => product.plan == selectedPlan,
    orElse: () {
      final sorted = _sortedProducts(products);
      if (sorted.isNotEmpty) return sorted.first;
      return selectedPlan == BillingPlan.yearly
          ? _fallbackYearlyProduct
          : _fallbackMonthlyProduct;
    },
  );
}

BillingPlan _effectiveSelectedPlan(
  List<PremiumProduct> products,
  BillingPlan selectedPlan,
) {
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
  if (purchasableProducts.isNotEmpty) {
    return purchasableProducts.first.plan;
  }
  final hasSelectedProduct = products.any(
    (product) => product.plan == selectedPlan,
  );
  if (hasSelectedProduct) {
    return selectedPlan;
  }
  return products.isEmpty ? selectedPlan : _sortedProducts(products).first.plan;
}

PlanType _planTypeForBillingPlan(BillingPlan plan) {
  return switch (plan) {
    BillingPlan.monthly => PlanType.monthly,
    BillingPlan.yearly => PlanType.annual,
  };
}

String _displayPrice(PremiumProduct product) {
  if (product.isPurchasable && product.priceLabel.trim().isNotEmpty) {
    return product.priceLabel;
  }
  return 'Loading';
}

String _ctaLabel(PremiumProduct product) {
  if (!product.isPurchasable || product.priceLabel.trim().isEmpty) {
    return 'Loading store price';
  }
  final plan = _planTypeForBillingPlan(product.plan);
  return 'Continue with ${product.priceLabel}/${plan.ctaCadence}';
}

String _annualPerLine(PremiumProduct product) {
  final monthly = _yearlyPerMonthLabel(product);
  return monthly == null ? 'per year' : 'per year, $monthly';
}

String? _yearlyPerMonthLabel(PremiumProduct product) {
  if (!product.isPurchasable) {
    return null;
  }
  final parsed = _parsePrice(product.priceLabel);
  if (parsed == null) {
    return null;
  }
  final monthly = parsed.value / 12;
  if (parsed.suffix == 'p') {
    return '${monthly.round()}p/month';
  }
  return '${parsed.prefix}${monthly.toStringAsFixed(2)}${parsed.suffix}/month';
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

String _planUnavailableMessage(BillingPlan plan, PremiumPaywallCopy copy) {
  final cadence = plan == BillingPlan.yearly ? 'Annual' : 'Monthly';
  final lowerCadence = plan == BillingPlan.yearly ? 'annual' : 'monthly';
  return '$cadence Pebble Premium is not available from ${copy.storeName} yet. Check the $lowerCadence base plan offer token in ${copy.consoleName}.';
}

const _fallbackMonthlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremium,
  basePlanId: PebbleBasePlanIds.monthly,
  plan: BillingPlan.monthly,
  title: 'Monthly',
  priceLabel: '',
  detailLabel: 'per month',
  isPurchasable: false,
);

const _fallbackYearlyProduct = PremiumProduct(
  productId: PebbleProductIds.personalPremium,
  basePlanId: PebbleBasePlanIds.yearly,
  plan: BillingPlan.yearly,
  title: 'Annual',
  priceLabel: '',
  detailLabel: 'per year',
  badgeLabel: 'Best value',
  isPurchasable: false,
);
