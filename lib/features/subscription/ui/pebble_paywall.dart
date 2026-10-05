import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/config/legal_links.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

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
    required this.storeNameInSentence,
    required this.renewalLine,
    required this.purchaseErrorLine,
    required this.consoleName,
  });

  final String storeName;

  /// [storeName] as it reads mid-sentence ("from the App Store").
  final String storeNameInSentence;
  final String renewalLine;
  final String purchaseErrorLine;
  final String consoleName;

  static PremiumPaywallCopy forPlatform(StorePlatform platform) {
    return switch (platform) {
      StorePlatform.appStore => const PremiumPaywallCopy._(
        storeName: 'App Store',
        storeNameInSentence: 'the App Store',
        renewalLine:
            'Renews automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID when you confirm. Cancel anytime in the App Store subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            "The App Store couldn't finish that. Try again.",
        consoleName: 'App Store Connect',
      ),
      StorePlatform.googlePlay => const PremiumPaywallCopy._(
        storeName: 'Google Play',
        storeNameInSentence: 'Google Play',
        renewalLine:
            'Renews automatically until cancelled. Cancel anytime in Google Play subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            "Google Play couldn't finish that. Try again.",
        consoleName: 'Play Console',
      ),
      StorePlatform.other => const PremiumPaywallCopy._(
        storeName: 'the store',
        storeNameInSentence: 'the store',
        renewalLine:
            'Renews automatically until cancelled. Cancel anytime through your app store subscription settings. Pebble also works free without Premium.',
        purchaseErrorLine:
            "The store couldn't finish that. Try again.",
        consoleName: 'store console',
      ),
    };
  }
}

/// Where the paywall is with the store's product list.
enum PaywallStoreState {
  /// Products are still being requested.
  loading,

  /// At least one plan can be bought.
  ready,

  /// The store answered without usable products, failed, or is taking too
  /// long. The paywall says so and offers Try again.
  unavailable,
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
  /// How long the paywall waits on the store before it stops saying
  /// "Checking" and offers Try again instead. Sandbox stores can stall.
  static const _slowStoreTimeout = Duration(seconds: 12);

  final ScrollController _scrollController = ScrollController();
  bool _busy = false;
  bool _retryingStore = false;
  bool _storeIsSlow = false;
  Timer? _slowStoreTimer;

  @override
  void initState() {
    super.initState();
    _startSlowStoreTimer();
  }

  @override
  void dispose() {
    _slowStoreTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startSlowStoreTimer() {
    _slowStoreTimer?.cancel();
    _storeIsSlow = false;
    _slowStoreTimer = Timer(_slowStoreTimeout, () {
      if (mounted) setState(() => _storeIsSlow = true);
    });
  }

  Future<void> _retryStore() async {
    if (_retryingStore) return;
    setState(() {
      _retryingStore = true;
      _startSlowStoreTimer();
    });
    try {
      await ref.read(purchaseRepositoryProvider).retryLoadProducts();
    } catch (error) {
      debugPrint('Paywall store retry failed: $error');
    } finally {
      if (mounted) setState(() => _retryingStore = false);
    }
  }

  PaywallStoreState _storeState(PurchaseRepository repository) {
    if (repository.isPurchaseAvailable) return PaywallStoreState.ready;
    final loading = repository.isLoadingProducts || _retryingStore;
    if (loading && !_storeIsSlow) return PaywallStoreState.loading;
    return PaywallStoreState.unavailable;
  }

  String _storeUnavailableMessage(PurchaseRepository repository) {
    if (repository.isLoadingProducts || _retryingStore) {
      return '${_platformCopy.storeName} is taking longer than usual to '
          'answer. Check your connection and try again.';
    }
    final reason = repository.unavailableReason?.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    return 'Prices could not be loaded from '
        '${_platformCopy.storeNameInSentence}. Check your connection and '
        'try again.';
  }

  PremiumPaywallCopy get _platformCopy =>
      PremiumPaywallCopy.forPlatform(StorePlatformRuntime.current);

  void _dismissPaywall() {
    // While a purchase is being verified, leaving would drop the
    // confirmation (and first-time backup consent) sheet on the floor.
    if (_busy) return;
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
      if (error is PurchasePendingException ||
          (error is PurchaseFlowException && error.isPending)) {
        // Payment is in progress with the store: real news, not a failure.
        _showNotice(
          error is PurchasePendingException
              ? error.message
              : (error as PurchaseFlowException).message,
          title: 'Payment pending',
          type: NotificationType.info,
        );
        return;
      }
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
        title: "Couldn't restore",
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
    // One confirmation per purchase: the sheet (or a single toast below) is
    // it. Stacking a "Premium is on" toast on top of the activation sheet
    // said the same thing twice.
    final auth = ref.read(authSessionProvider);
    if (!auth.isSignedIn) {
      await _showPostPurchaseSignInPrompt();
      return;
    }
    var consent = ref.read(cloudBackupConsentStateProvider);
    if (consent.isLoading) {
      await ref.read(cloudBackupConsentControllerProvider.notifier).load();
      if (!mounted) return;
      consent = ref.read(cloudBackupConsentStateProvider);
    }
    if (consent.isAccepted) {
      // Backup was already set up for this account (e.g. a resubscribe), so
      // there is nothing left to ask — but the moment still deserves a real
      // confirmation, not a toast that vanishes over the account screen.
      try {
        await ref
            .read(authControllerProvider.notifier)
            .refreshCloudAccessAfterEntitlementChange(
              refreshEntitlement: false,
            );
      } catch (_) {
        // Backup catches up on the next app resume; Premium itself is on.
      }
      if (!mounted) return;
      final backupIsOn =
          ref.read(personalCloudAccessProvider).status ==
          PersonalCloudAccessStatus.available;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        isScrollControlled: true,
        builder: (dialogContext) =>
            _PremiumResubscribedSheet(backupIsOn: backupIsOn),
      );
      if (mounted) {
        context.go('/account-hub');
      }
      return;
    }
    await _showPostPurchaseBackupPrompt();
  }

  Future<void> _showPostPurchaseBackupPrompt() async {
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      isScrollControlled: true,
      isDismissible: false,
      builder: (dialogContext) => const _PostPurchaseBackupSheet(),
    );
    if (!mounted) return;
    // No toast on top of the landing screen: the account hub shows the live
    // backup status, and the sheet was the confirmation moment.
    context.go('/account-hub');
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

  Future<void> _openManageSubscriptions() async {
    final url = ref.read(purchaseRepositoryProvider).manageSubscriptionsUrl;
    if (url == null || url.isEmpty) {
      _showNotice(
        'Subscription management is not available on this phone.',
        title: 'Not available',
        type: NotificationType.warning,
      );
      return;
    }
    await _openLegalUrl(url);
  }

  Future<void> _openLegalUrl(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showNotice(
        "Couldn't open that page.",
        title: "Couldn't open",
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
      textTheme: PebbleFonts.sansTextTheme(parentTheme.textTheme).apply(
        bodyColor: foundation.textPrimary,
        displayColor: foundation.textPrimary,
      ),
    );

    // An active subscriber should never be sold to. During a purchase the
    // busy flag keeps the normal layout up so the post-purchase sheets play
    // out over it rather than the screen swapping underneath them.
    final alreadyPremium =
        !_busy &&
        ref.watch(subscriptionLifecycleProvider).phase ==
            SubscriptionLifecyclePhase.activePremium;
    if (alreadyPremium) {
      return Theme(
        data: paywallTheme,
        child: Builder(
          builder: (context) => _AlreadyPremiumScreen(
            onDone: _dismissPaywall,
            onManagePlan: _openManageSubscriptions,
          ),
        ),
      );
    }

    return Theme(
      data: paywallTheme,
      child: Builder(
        builder: (context) {
          final purchaseRepository = ref.watch(purchaseRepositoryProvider);
          final storeState = _storeState(purchaseRepository);
          final products = purchaseRepository.personalPremiumProducts;
          final selectedPlan = _effectiveSelectedPlan(
            products,
            ref.watch(premiumPaywallPlanProvider).billingPlan,
          );
          final selectedProduct = _selectedProduct(products, selectedPlan);
          final selectedPlanPurchasable =
              selectedProduct.isPurchasable &&
              selectedProduct.hasValidOfferToken;
          final purchasesEnabled =
              storeState == PaywallStoreState.ready && selectedPlanPurchasable;
          final String? storeNotice = switch (storeState) {
            PaywallStoreState.unavailable =>
              purchaseRepository.unavailableReason == null &&
                      !selectedPlanPurchasable &&
                      selectedProduct.priceLabel.trim().isNotEmpty
                  ? _planUnavailableMessage(selectedProduct.plan, _platformCopy)
                  : _storeUnavailableMessage(purchaseRepository),
            PaywallStoreState.ready when !selectedPlanPurchasable =>
              _planUnavailableMessage(selectedProduct.plan, _platformCopy),
            _ => null,
          };

          // With large text or a short screen a pinned footer would cover
          // most of the page, so the plans scroll with the content instead.
          final mediaQuery = MediaQuery.of(context);
          final inlinePricing =
              _isLargeText(context) || mediaQuery.size.height < 700;

          final pricing = _PricingFooter(
            products: products,
            selectedPlan: selectedPlan,
            storeState: storeState,
            storeNotice: storeNotice,
            retrying: _retryingStore,
            busy: _busy,
            purchasesEnabled: purchasesEnabled,
            platformCopy: _platformCopy,
            inline: inlinePricing,
            onStartPremium: _startPremium,
            onRetryStore: _retryStore,
            onRestorePurchase: _busy || storeState == PaywallStoreState.loading
                ? null
                : _restorePurchase,
            onOpenLegalUrl: _openLegalUrl,
          );

          // No backing out while the store sheet is mid-purchase.
          return PopScope(
            canPop: !_busy,
            child: Scaffold(
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
                  28 + mediaQuery.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PaywallHeader(entrySource: widget.entrySource),
                    if (inlinePricing) ...[const SizedBox(height: 28), pricing],
                    const SizedBox(height: 28),
                    const _SectionLabel('What Premium gives you'),
                    const SizedBox(height: 2),
                    _FeaturesList(entrySource: widget.entrySource),
                    const SizedBox(height: 20),
                    const _TrustCard(),
                  ],
                ),
              ),
            ),
            extendBody: false,
            bottomNavigationBar: inlinePricing ? null : pricing,
            floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
            floatingActionButton: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                // Floating glass: scrolled content blurs out behind it.
                child: PebbleBackButton(onPressed: _dismissPaywall),
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Text scale above which the paywall stops pinning its price footer and
/// stacks side-by-side comparisons.
const double _largeTextScale = 1.3;

bool _isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) / 10 > _largeTextScale;

/// Post-purchase sheet for signed-in buyers: Premium is confirmed and backup
/// turns on with one tap, right here — no trip through account settings and
/// no separate consent checkbox screen.
class _PostPurchaseBackupSheet extends ConsumerStatefulWidget {
  const _PostPurchaseBackupSheet();

  @override
  ConsumerState<_PostPurchaseBackupSheet> createState() =>
      _PostPurchaseBackupSheetState();
}

class _PostPurchaseBackupSheetState
    extends ConsumerState<_PostPurchaseBackupSheet> {
  bool _busy = false;

  Future<void> _turnOnBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cloudBackupConsentControllerProvider.notifier).accept();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ZenNotifications.showError(
        context,
        title: "Couldn't turn on backup",
        message:
            "Premium is on. Pebble will try backup again when you're online.",
      );
      Navigator.of(context).pop(false);
      return;
    }
    // The consent record is what matters; the first backup pass is
    // best-effort here and self-heals on the next app start or resume.
    try {
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange(refreshEntitlement: false);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.42), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PremiumActivatedIcon(accent: accent),
                const SizedBox(height: 20),
                Text(
                  'Premium activated',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _premiumAccentText(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: _serifStyle(context, fontSize: 28, height: 1.14),
                    children: [
                      const TextSpan(text: 'Turn on backup\nfor '),
                      TextSpan(
                        text: 'this account?',
                        style: TextStyle(
                          color: _premiumAccentText(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pebble backs up routines, history, proof photos and voice '
                  'tips, which can include personal details. You can pause '
                  'backup any time in Your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foundation.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _turnOnBackup,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: const StadiumBorder(),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Text(
                            'Turn on backup',
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
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: foundation.textSecondary,
                      side: BorderSide(
                        color: foundation.borderSubtle.withValues(alpha: 0.86),
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      color: _premiumAccentText(context),
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
                        const TextSpan(text: 'Sign in to\n'),
                        TextSpan(
                          text: 'turn on backup.',
                          style: TextStyle(
                            color: _premiumAccentText(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Signing in lets Pebble back up your history, routines and photos, so you can restore them on another phone. It's optional. Premium already works without it.",
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
                        shape: const StadiumBorder(),
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
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Continue without sign-in'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'You can sign in later from Your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.readableSecondaryText,
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

/// Replaces the sales layout when the account already has active Premium:
/// confirmation of what is on, a route to plan management, and a way out.
class _AlreadyPremiumScreen extends StatelessWidget {
  const _AlreadyPremiumScreen({
    required this.onDone,
    required this.onManagePlan,
  });

  final VoidCallback onDone;
  final VoidCallback onManagePlan;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PremiumActivatedIcon(accent: accent),
                      const SizedBox(height: 24),
                      Text(
                        'Personal Premium',
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
                          style: _serifStyle(
                            context,
                            fontSize: 30,
                            height: 1.12,
                          ),
                          children: [
                            const TextSpan(text: 'You already\nhave '),
                            TextSpan(
                              text: 'Premium.',
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
                        'Everything in Premium is already on for this phone. To '
                        'change or cancel your plan, use your app store\'s '
                        'subscription settings.',
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
                              value: 'Unlimited',
                              label: 'Routines',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Done',
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
                        height: 52,
                        child: OutlinedButton(
                          onPressed: onManagePlan,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: foundation.textSecondary,
                            side: BorderSide(
                              color: foundation.borderSubtle.withValues(
                                alpha: 0.86,
                              ),
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Manage plan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: PebbleBackButton(
                onPressed: onDone,
                backgroundColor: foundation.textPrimary.withValues(alpha: 0.12),
                iconColor: foundation.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-purchase sheet for a resubscribe: sign-in and backup consent are
/// already in place, so this is pure confirmation — what turned on, and one
/// button out.
class _PremiumResubscribedSheet extends StatelessWidget {
  const _PremiumResubscribedSheet({required this.backupIsOn});

  final bool backupIsOn;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Align(
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
                      const TextSpan(text: 'Premium is\n'),
                      TextSpan(
                        text: 'active again.',
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
                  backupIsOn
                      ? 'Backup is already on for this account, so your '
                            'routines, history and proof photos will carry on '
                            'backing up.'
                      : 'Backup is set up for this account. Pebble will '
                            'reconnect it in the background.',
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
                        value: 'Unlimited',
                        label: 'Routines',
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
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
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
    // The paywall knows what wall the user just hit, so the headline names
    // that moment instead of a generic slogan.
    final (headlineLead, headlineAccent) = switch (entrySource) {
      PremiumEntrySource.proofPhotoLimit => (
        "When one photo\nisn't ",
        'enough.',
      ),
      PremiumEntrySource.backup => ('History that\n', 'lasts 21 days.'),
      PremiumEntrySource.routineLimit ||
      PremiumEntrySource.stepLimit => ('Room for every\n', 'routine.'),
      PremiumEntrySource.guidanceAudio => (
        'Say it once,\nhear it ',
        'every time.',
      ),
      _ => ('Keep three weeks\n', 'of checks.'),
    };
    final body = switch (entrySource) {
      PremiumEntrySource.backup =>
        'Free keeps history on this phone for 48 hours. Premium keeps it for 21 days, and backs it up if you turn backup on.',
      PremiumEntrySource.proofPhotoLimit =>
        'Free includes one photo per step. Premium lets you add up to four, for checks that need more than one angle.',
      PremiumEntrySource.guidanceAudio =>
        'Record a few seconds on any step saying what to check, and play it back when you get there.',
      _ =>
        'Free includes 2 routines with up to 10 steps each. Premium gives you unlimited routines, 21 days of history, and backup if you turn it on.',
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
              TextSpan(text: headlineLead),
              TextSpan(
                text: headlineAccent,
                style: TextStyle(
                  color: _premiumAccentText(context),
                  fontStyle: FontStyle.italic,
                ),
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
            Flexible(
              child: Text(
                'Personal Premium',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _premiumAccentText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
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
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.readableSecondaryText,
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
    description: 'As many routines as you need, with as many steps.',
    freeLabel: '2 routines, 10 steps',
    premiumLabel: 'Unlimited',
  ),
  _PremiumFeature(
    icon: LucideIcons.cloud,
    title: 'Longer history and backup',
    description:
        'Three weeks of history, backed up in case you reinstall or change phone.',
    freeLabel: '48 hours',
    premiumLabel: '21 days + backup',
  ),
  _PremiumFeature(
    icon: LucideIcons.camera,
    title: 'More photos per step',
    description: 'For checks that need more than one angle.',
    freeLabel: '1 photo',
    premiumLabel: 'Up to 4',
  ),
  _PremiumFeature(
    icon: LucideIcons.mic,
    title: 'Voice tips',
    description:
        'Record a short note on any step and play it back when you '
        'get there.',
    freeLabel: 'Not available',
    premiumLabel: 'Included',
  ),
];

class _FeaturesList extends StatelessWidget {
  const _FeaturesList({required this.entrySource});

  final PremiumEntrySource entrySource;

  /// The feature that matches the wall the user just hit, or null when they
  /// arrived without a specific reason.
  static int? _leadIndexFor(PremiumEntrySource source) {
    final title = switch (source) {
      PremiumEntrySource.routineLimit ||
      PremiumEntrySource.stepLimit => 'Unlimited routines and steps',
      PremiumEntrySource.backup => 'Longer history and backup',
      PremiumEntrySource.proofPhotoLimit => 'More photos per step',
      PremiumEntrySource.guidanceAudio => 'Voice tips',
      PremiumEntrySource.general || PremiumEntrySource.premiumTheme => null,
    };
    if (title == null) {
      return null;
    }
    final index = _premiumFeatures.indexWhere(
      (feature) => feature.title == title,
    );
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final leadIndex = _leadIndexFor(entrySource);
    final ordered = [
      if (leadIndex != null) _premiumFeatures[leadIndex],
      for (var i = 0; i < _premiumFeatures.length; i += 1)
        if (i != leadIndex) _premiumFeatures[i],
    ];
    return Column(
      children: [
        for (var i = 0; i < ordered.length; i += 1)
          _FeatureListItem(
            ordered[i],
            highlighted: leadIndex != null && i == 0,
          ),
      ],
    );
  }
}

class _FeatureListItem extends StatelessWidget {
  const _FeatureListItem(this.feature, {this.highlighted = false});

  final _PremiumFeature feature;

  /// True for the feature whose limit sent the user here: it leads the list
  /// inside a softly accented card so the page answers their exact moment.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    if (highlighted) {
      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 6),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: _content(context, foundation, accent),
      );
    }
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
        child: _content(context, foundation, accent),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    PebbleDarkFoundation foundation,
    Color accent,
  ) {
    return Row(
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
              const SizedBox(height: 11),
              _TierComparisonRow(
                freeLabel: feature.freeLabel,
                premiumLabel: feature.premiumLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two labelled tier pills side by side, so what-you-get-for-your-money is
/// readable at a glance without decoding an unlabelled comparison.
class _TierComparisonRow extends StatelessWidget {
  const _TierComparisonRow({
    required this.freeLabel,
    required this.premiumLabel,
  });

  final String freeLabel;
  final String premiumLabel;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    if (_isLargeText(context)) {
      // Side by side, large text breaks words mid-way ("Unlimite/d").
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TierPill(tier: 'Free', value: freeLabel, accented: false),
          const SizedBox(height: 6),
          _TierPill(tier: 'Premium', value: premiumLabel, accented: true),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TierPill(tier: 'Free', value: freeLabel, accented: false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              child: Icon(
                LucideIcons.arrowRight,
                size: 13,
                color: foundation.textMuted,
              ),
            ),
          ),
          Expanded(
            child: _TierPill(
              tier: 'Premium',
              value: premiumLabel,
              accented: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({
    required this.tier,
    required this.value,
    required this.accented,
  });

  final String tier;
  final String value;
  final bool accented;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accented
            ? accent.withValues(alpha: 0.12)
            : foundation.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accented
              ? accent.withValues(alpha: 0.32)
              : foundation.borderSubtle.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tier.toUpperCase(),
            style: TextStyle(
              color: accented
                  ? _premiumAccentText(context)
                  : context.readableSecondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accented
                  ? _premiumAccentText(context)
                  : foundation.textSecondary,
              fontSize: 12.5,
              fontWeight: accented ? FontWeight.w600 : FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
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
                    "Pebble has no ads and doesn't sell your data. Backup only starts if you turn it on.",
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
    required this.storeState,
    required this.storeNotice,
    required this.retrying,
    required this.busy,
    required this.purchasesEnabled,
    required this.platformCopy,
    required this.inline,
    required this.onStartPremium,
    required this.onRetryStore,
    required this.onRestorePurchase,
    required this.onOpenLegalUrl,
  });

  final List<PremiumProduct> products;
  final BillingPlan selectedPlan;
  final PaywallStoreState storeState;
  final String? storeNotice;
  final bool retrying;
  final bool busy;
  final bool purchasesEnabled;
  final PremiumPaywallCopy platformCopy;

  /// True when the footer scrolls with the page instead of being pinned.
  final bool inline;
  final VoidCallback onStartPremium;
  final VoidCallback onRetryStore;
  final VoidCallback? onRestorePurchase;
  final ValueChanged<String> onOpenLegalUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final selectedProduct = _selectedProduct(products, selectedPlan);
    final storeUnavailable = storeState == PaywallStoreState.unavailable;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanToggle(
          products: products,
          selectedPlan: selectedPlan,
          storeState: storeState,
        ),
        if (storeNotice != null) ...[
          const SizedBox(height: 12),
          _UnavailableNotice(
            title: storeUnavailable ? 'Prices unavailable' : null,
            message: storeNotice!,
          ),
        ],
        const SizedBox(height: 14),
        if (storeUnavailable)
          _PremiumActionButton(
            key: const ValueKey('paywall-retry-store'),
            busy: retrying,
            enabled: true,
            icon: LucideIcons.refreshCw,
            label: 'Try again',
            semanticsLabel: 'Try loading prices again',
            onPressed: onRetryStore,
          )
        else
          _PremiumActionButton(
            busy: busy,
            enabled: purchasesEnabled,
            showSpinnerLabel: storeState == PaywallStoreState.loading,
            label: storeState == PaywallStoreState.loading
                ? 'Checking the store...'
                : _ctaLabel(selectedProduct),
            onPressed: onStartPremium,
          ),
        const SizedBox(height: 11),
        _FinePrint(
          platformCopy: platformCopy,
          product: storeState == PaywallStoreState.ready
              ? selectedProduct
              : null,
        ),
        const SizedBox(height: 6),
        _FooterLinks(
          onRestorePurchase: onRestorePurchase,
          onOpenLegalUrl: onOpenLegalUrl,
        ),
      ],
    );
    if (inline) return content;
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
          child: content,
        ),
      ),
    );
  }
}

class _PlanToggle extends ConsumerWidget {
  const _PlanToggle({
    required this.products,
    required this.selectedPlan,
    required this.storeState,
  });

  final List<PremiumProduct> products;
  final BillingPlan selectedPlan;
  final PaywallStoreState storeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = _sortedProducts(products);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final product in sorted) ...[
            Expanded(
              child: _PlanOption(
                product: product,
                storeState: storeState,
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
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.product,
    required this.storeState,
    required this.selected,
    required this.onTap,
  });

  final PremiumProduct product;
  final PaywallStoreState storeState;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    final isAnnual = product.plan == BillingPlan.yearly;
    final largeText = _isLargeText(context);
    final badge = isAnnual
        ? _PlanBadge(product.badgeLabel ?? 'Best value')
        : null;
    final hasPrice = _hasPrice(product);
    final String priceText;
    final String perLine;
    if (hasPrice) {
      priceText = product.priceLabel;
      perLine = isAnnual ? _annualPerLine(product) : 'per month';
    } else if (storeState == PaywallStoreState.loading) {
      priceText = '...';
      perLine = 'Checking price';
    } else {
      priceText = '\u2014';
      perLine = 'Price unavailable';
    }
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
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
              // At large text the floating badge would sit on the plan name,
              // so it joins the card's own column instead.
              if (badge != null && !largeText)
                Positioned(top: -21, right: -4, child: badge),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null && largeText) ...[
                    badge,
                    const SizedBox(height: 6),
                  ],
                  Text(
                    isAnnual ? 'Annual' : 'Monthly',
                    style: TextStyle(
                      color: selected
                          ? _premiumAccentText(context)
                          : foundation.textSecondary,
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
                      priceText,
                      style: _serifStyle(context, fontSize: 24, height: 1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    perLine,
                    maxLines: 3,
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

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    super.key,
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticsLabel,
    this.showSpinnerLabel = false,
  });

  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? semanticsLabel;

  /// Shows a small spinner beside [label] (store still loading).
  final bool showSpinnerLabel;

  @override
  Widget build(BuildContext context) {
    // The app's one primary button: same colour, shape and type as every
    // other screen's main action.
    return PebbleButton.primary(
      label: label,
      icon: icon,
      busy: busy || showSpinnerLabel,
      semanticsLabel: semanticsLabel,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _FinePrint extends StatelessWidget {
  const _FinePrint({required this.platformCopy, required this.product});

  final PremiumPaywallCopy platformCopy;

  /// The plan the button buys, when its price is known. Its name, length and
  /// price lead the disclosure (App Store guideline 3.1.2).
  final PremiumProduct? product;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final selected = product;
    final summary = selected == null || !_hasPrice(selected)
        ? ''
        : 'Personal Premium ${selected.plan == BillingPlan.yearly ? 'Annual' : 'Monthly'}: '
              '${selected.priceLabel} per ${_planTypeForBillingPlan(selected.plan).ctaCadence}. ';
    return Text(
      '$summary${platformCopy.renewalLine}',
      textAlign: TextAlign.center,
      style: TextStyle(
        // textSecondary, not textMuted: the renewal terms must stay clearly
        // readable in every theme, including the dark ones.
        color: foundation.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        height: 1.55,
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
      foregroundColor: foundation.textPrimary.withValues(alpha: 0.82),
      // 48 high so each link is a full-size tap target.
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: PebbleFonts.sans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.underline,
      ),
    );
    final divider = Text(
      '|',
      style: TextStyle(color: foundation.textMuted, fontSize: 12),
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
        divider,
        TextButton(
          onPressed: () => onOpenLegalUrl(pebbleTermsUrl),
          style: style,
          child: const Text('Terms of Use'),
        ),
        divider,
        TextButton(
          onPressed: () => onOpenLegalUrl(pebblePrivacyPolicyUrl),
          style: style,
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.message, this.title});

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _premiumGlow(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foundation.surfaceLow.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  title == null ? LucideIcons.info : LucideIcons.cloudOff,
                  color: accent,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: TextStyle(
                          color: foundation.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      message,
                      style: TextStyle(
                        color: foundation.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  return PebbleFonts.serif(
    color: foundation.textPrimary,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: height,
  );
}

/// The paywall's accent is the app's own action colour (the theme primary),
/// not a re-saturated variant, so the CTA matches every other screen.
Color _premiumGlow(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

/// [_premiumGlow] for small accent text: firmed up toward the text colour
/// only where the theme's primary is too faint to read (never saturated).
Color _premiumAccentText(BuildContext context) =>
    context.readableAccentText(_premiumGlow(context));

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

bool _hasPrice(PremiumProduct product) =>
    product.isPurchasable && product.priceLabel.trim().isNotEmpty;

String _ctaLabel(PremiumProduct product) {
  if (!_hasPrice(product)) {
    return 'Price unavailable';
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
  // The cause is a store setup issue; say so in the logs, not to customers.
  debugPrint(
    '[Paywall] $cadence plan has no purchasable offer. Check the '
    '$lowerCadence base plan offer token in ${copy.consoleName}.',
  );
  return 'The $lowerCadence plan is not available from '
      '${copy.storeNameInSentence} right now. Try again in a moment.';
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
