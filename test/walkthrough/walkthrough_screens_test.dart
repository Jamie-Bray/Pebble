// Visual walkthrough CAPTURE HARNESS - not a regular test.
//
// Renders every user-facing screen of the real app (real router, real
// theme, real screens, in-memory drift DB, fake store/auth) at phone size and
// writes PNG screenshots to WALKTHROUGH_OUT. Skipped unless WALKTHROUGH=1, so
// it never affects `flutter test`.
//
//   WALKTHROUGH=1 WALKTHROUGH_OUT=/abs/out WALKTHROUGH_FONTS=/abs/fonts \
//     flutter test test/walkthrough/walkthrough_screens_test.dart
//
// The app's fonts (DM Sans, DM Serif Display) are bundled under
// assets/fonts/: they are registered from FontManifest.json below, and
// google_fonts loads its own copies from the asset bundle, so no download or
// WALKTHROUGH_FONTS directory is needed. WALKTHROUGH_FONTS is still honoured
// (a directory of `<Family>_<variant>.ttf` files plus a manifest.txt of
// `<family name> <file> <hash>` lines) for any extra font a capture needs.
//
// Note: `flutter test` always starts flutter_tester with --use-test-fonts, so
// any text whose style has no fontFamily (common in button styles) renders as
// Ahem boxes. The walkthrough was captured with a locally patched flutter_tools
// that drops that flag when FLUTTER_TESTER_REAL_FONTS=1, so such text falls
// back to Roboto as on Android. Without the patch, those labels show as boxes. Layout errors (overflow etc.) are logged per screenshot to
// WALKTHROUGH_OUT/_layout_errors.txt.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/revenuecat_purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/revenuecat_runtime_config.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/main.dart';

final bool _enabled = Platform.environment['WALKTHROUGH'] == '1';
final String _outDir =
    Platform.environment['WALKTHROUGH_OUT'] ??
    '${Directory.systemTemp.path}/pebble_walkthrough';
final String? _fontsDir = Platform.environment['WALKTHROUGH_FONTS'];
final String? _only = Platform.environment['WALKTHROUGH_ONLY'];
final String _supportDir = '$_outDir/../walkthrough_support';

void _mockPathProvider(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => _supportDir,
  );
  // just_audio has no host side in tests; answering its main channel lets a
  // voice-tip player be disposed when the player moves past that step.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async => <String, dynamic>{},
  );
}

// ---------------------------------------------------------------------------
// Devices
// ---------------------------------------------------------------------------

class _Device {
  const _Device(
    this.id,
    this.size,
    this.dpr,
    this.top,
    this.bottom,
    this.platform,
  );
  final String id;
  final Size size;
  final double dpr;
  final double top;
  final double bottom;
  final TargetPlatform platform;
}

// iPhone 14/15 class: 390x844pt @3x, 47pt status bar, 34pt home indicator.
const _iphone = _Device(
  'iphone',
  Size(390, 844),
  3,
  47,
  34,
  TargetPlatform.iOS,
);
// Small Android: 360x640dp, 24dp status bar, 3-button nav handled by system.
const _small = _Device(
  'small',
  Size(360, 640),
  2,
  24,
  0,
  TargetPlatform.android,
);

// ---------------------------------------------------------------------------
// Account / store scenarios
// ---------------------------------------------------------------------------

enum _Account {
  signedOutFree,
  signedInFree,
  signedInPremium,
  premiumEnded,
  // Subscription lifecycle states.
  premiumGrace,
  premiumCancelled,
  premiumBillingIssue,
}

enum _Store { loaded, unavailable, pending, purchaseSucceeds }

const _userId = '6f1c2a9e-1b7d-4c3e-9a51-2f0d8e7b4c11';
const _email = 'jamie.rivera@example.com';

class _TestAccountController extends SubscriptionAccountController {
  _TestAccountController(super.db, SubscriptionAccountState initial)
    : super(loadOnInit: false) {
    state = initial;
  }
}

SubscriptionAccountState _accountState(_Account account) {
  switch (account) {
    case _Account.signedOutFree:
      return const SubscriptionAccountState.initial();
    case _Account.signedInFree:
      return const SubscriptionAccountState(
        entitlementTier: UserTier.personalFree,
        pendingTier: null,
        bootstrapStatus: BootstrapStatus.idle,
        userId: _userId,
        email: _email,
        authProvider: 'google',
        lastBootstrapAt: null,
        lastSyncAt: null,
        lastSyncError: null,
      );
    case _Account.signedInPremium:
      final now = DateTime.now();
      return SubscriptionAccountState(
        entitlementTier: UserTier.personalPremium,
        pendingTier: null,
        bootstrapStatus: BootstrapStatus.ready,
        userId: _userId,
        email: _email,
        authProvider: 'google',
        lastBootstrapAt: now.subtract(const Duration(days: 12)),
        lastSyncAt: now.subtract(const Duration(minutes: 4)),
        lastSyncError: null,
        entitlementStatus: EntitlementStatus.personalPremium,
        entitlementSource: EntitlementSource.serverVerified,
        lastEntitlementCheckAt: now.subtract(const Duration(minutes: 4)),
        entitlementPeriodEndsAt: now.add(const Duration(days: 23)),
      );
    case _Account.premiumEnded:
      final now = DateTime.now();
      return SubscriptionAccountState(
        entitlementTier: UserTier.personalFree,
        pendingTier: null,
        bootstrapStatus: BootstrapStatus.idle,
        userId: null,
        email: null,
        authProvider: null,
        lastBootstrapAt: null,
        lastSyncAt: null,
        lastSyncError: null,
        entitlementStatus: EntitlementStatus.expired,
        entitlementSource: EntitlementSource.revenueCat,
        lastEntitlementCheckAt: now.subtract(const Duration(days: 30)),
        entitlementExpiredAt: now.subtract(const Duration(days: 30)),
        entitlementLapseNoticedAt: now.subtract(const Duration(days: 30)),
      );
    case _Account.premiumGrace:
      final now = DateTime.now();
      return SubscriptionAccountState(
        entitlementTier: UserTier.personalFree,
        pendingTier: null,
        bootstrapStatus: BootstrapStatus.idle,
        userId: _userId,
        email: _email,
        authProvider: 'google',
        lastBootstrapAt: null,
        lastSyncAt: null,
        lastSyncError: null,
        entitlementStatus: EntitlementStatus.expired,
        entitlementSource: EntitlementSource.revenueCat,
        lastEntitlementCheckAt: now.subtract(const Duration(hours: 1)),
        entitlementExpiredAt: now.subtract(const Duration(days: 2)),
        entitlementLapseNoticedAt: now.subtract(const Duration(days: 2)),
      );
    case _Account.premiumCancelled:
    case _Account.premiumBillingIssue:
      final now = DateTime.now();
      return _accountState(_Account.signedInPremium).copyWith(
        entitlementPeriodEndsAt: now.add(const Duration(days: 9)),
        entitlementWillRenew: account == _Account.premiumCancelled
            ? false
            : true,
        entitlementBillingIssueAt: account == _Account.premiumBillingIssue
            ? now.subtract(const Duration(days: 1))
            : null,
      );
  }
}

bool _isSignedIn(_Account a) =>
    a == _Account.signedInFree ||
    a == _Account.signedInPremium ||
    a == _Account.premiumGrace ||
    a == _Account.premiumCancelled ||
    a == _Account.premiumBillingIssue;

bool _hasBackupConsent(_Account a) =>
    a == _Account.signedInPremium ||
    a == _Account.premiumCancelled ||
    a == _Account.premiumBillingIssue;

class _FakePurchases extends ChangeNotifier implements PurchaseRepository {
  @override
  bool get isLoadingProducts => false;

  @override
  Future<void> retryLoadProducts() async {}
  _FakePurchases(this.store);
  final _Store store;

  bool get _ok => store != _Store.unavailable;

  @override
  bool get isPurchaseAvailable => _ok;
  @override
  bool get billingAvailable => _ok;
  @override
  DateTime? get lastPurchaseCheckAt => DateTime.now();
  @override
  Set<String> get loadedProductIds =>
      _ok ? {PebbleProductIds.personalPremium} : const {};
  @override
  String? get manageSubscriptionsUrl =>
      'https://apps.apple.com/account/subscriptions';
  @override
  String? get unavailableReason => _ok
      ? null
      : 'Could not load store products. Check your connection and try again.';
  @override
  List<PremiumProduct> get personalPremiumProducts => _ok
      ? const [
          PremiumProduct(
            productId: PebbleProductIds.personalPremium,
            basePlanId: PebbleBasePlanIds.monthly,
            plan: BillingPlan.monthly,
            title: 'Monthly',
            priceLabel: '£3.99',
            detailLabel: 'per month. Cancel anytime.',
            offerToken: r'$rc_monthly',
            isPurchasable: true,
          ),
          PremiumProduct(
            productId: PebbleProductIds.personalPremium,
            basePlanId: PebbleBasePlanIds.yearly,
            plan: BillingPlan.yearly,
            title: 'Yearly',
            priceLabel: '£29.99',
            detailLabel: 'per year. Best value.',
            badgeLabel: 'Best value',
            offerToken: r'$rc_annual',
            isPurchasable: true,
          ),
        ]
      : getPlaceholderPremiumCatalog(isPurchasable: false);
  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    switch (store) {
      case _Store.pending:
        throw PurchaseFlowException(
          revenueCatMessageForPurchasesError(
            rc.PurchasesErrorCode.paymentPendingError,
          ),
          isPending: true,
        );
      case _Store.purchaseSucceeds:
        return PurchaseResult(
          tier: UserTier.personalPremium,
          plan: plan,
          requiresSignIn: false,
          message: 'Welcome to Personal Premium.',
        );
      case _Store.loaded:
      case _Store.unavailable:
        throw const PurchaseCancelledException();
    }
  }

  @override
  Future<PurchaseResult> restorePurchases() async =>
      throw const PurchaseFlowException('No purchases to restore.');
  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}
  @override
  Future<void> logOut() async {}
}

class _FakeAuth implements AuthRepository {
  @override
  bool get isConfigured => true;
  @override
  Future<AuthIdentity?> currentIdentity() async => null;
  @override
  Future<void> requestEmailOtp(String email) async {}
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async =>
      const AuthIdentity(userId: _userId, email: _email, provider: 'email');
  @override
  Future<AuthIdentity> signInWithGoogle() async =>
      const AuthIdentity(userId: _userId, email: _email, provider: 'google');
  @override
  Future<AuthIdentity> signInWithApple() async =>
      const AuthIdentity(userId: _userId, email: _email, provider: 'apple');
  @override
  Future<void> upsertProfile({required AuthIdentity identity}) async {}
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

enum _Seed { empty, populated, fiveRoutines }

String _steps(List<RoutineStep> steps) =>
    jsonEncode(steps.map((s) => s.toJson()).toList());

Routine _routine({
  required int id,
  required String title,
  required List<RoutineStep> steps,
  String? icon,
  int? color,
  bool pinned = false,
  required DateTime created,
}) {
  return Routine(
    id: id,
    title: title,
    stepsJson: _steps(steps),
    createdAt: created,
    emoji: icon,
    colorHex: color,
    isPinned: pinned,
    pinnedAt: pinned ? created : null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: created,
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

final _leaveHomeSteps = <RoutineStep>[
  const RoutineStep.check(label: 'Stove and oven dials off'),
  const RoutineStep.check(label: 'Hair tools unplugged'),
  const RoutineStep.check(label: 'Windows latched'),
  const RoutineStep.check(
    label: 'Back door locked',
    requiresPhoto: true,
    photoCount: 1,
    photoPrompt: 'Photo of the locked handle',
  ),
  const RoutineStep.check(label: 'Keys, wallet, phone'),
];

final _morningSteps = <RoutineStep>[
  const RoutineStep.check(
    label: 'Open the curtains',
    guidanceAudio: StepGuidanceAudio(
      localPath: 'routine_guidance_audio/morning_curtains.m4a',
      durationMs: 7400,
      mimeType: 'audio/mp4',
      byteSize: 58210,
    ),
  ),
  const RoutineStep.check(label: 'Glass of water'),
  const RoutineStep.check(
    label: 'Take morning medication',
    requiresPhoto: true,
    photoCount: 1,
    photoPrompt: 'Photo of today\'s pill box slot',
    allowSkip: true,
  ),
  const RoutineStep.check(label: 'Make the bed', allowSkip: true),
];

final _windDownSteps = <RoutineStep>[
  const RoutineStep.check(label: 'Phone on charger outside the bedroom'),
  const RoutineStep.check(label: 'Lights off downstairs'),
  const RoutineStep.check(label: 'Front door locked and chained'),
  const RoutineStep.check(label: 'Set tomorrow\'s alarm'),
];

Future<void> _seed(LocalDb db, _Seed seed) async {
  if (seed == _Seed.empty) return;
  final now = DateTime.now();
  final routines = [
    _routine(
      id: 1,
      title: 'Leaving the house',
      steps: _leaveHomeSteps,
      icon: 'house',
      pinned: true,
      created: now.subtract(const Duration(days: 40)),
    ),
    _routine(
      id: 2,
      title: 'Morning reset',
      steps: _morningSteps,
      icon: 'leaf',
      created: now.subtract(const Duration(days: 30)),
    ),
    _routine(
      id: 3,
      title: 'Wind down',
      steps: _windDownSteps,
      icon: 'moon',
      created: now.subtract(const Duration(days: 20)),
    ),
  ];
  if (seed == _Seed.fiveRoutines) {
    routines.addAll([
      _routine(
        id: 4,
        title: 'Gym bag',
        steps: _windDownSteps.take(3).toList(),
        icon: 'dumbbell',
        created: now.subtract(const Duration(days: 12)),
      ),
      _routine(
        id: 5,
        title: 'Plant watering',
        steps: _windDownSteps.take(2).toList(),
        icon: 'leaf',
        created: now.subtract(const Duration(days: 6)),
      ),
    ]);
  }
  for (final r in routines) {
    await db.routineDao.insertOrUpdateRoutine(r);
  }

  // Reminders.
  for (final day in [1, 2, 3, 4, 5]) {
    await db.routineReminderDao.addReminder(
      RoutineRemindersCompanion.insert(
        routineId: 1,
        dayOfWeek: day,
        time: '8:15 AM',
      ),
    );
  }
  await db.routineReminderDao.addReminder(
    RoutineRemindersCompanion.insert(
      routineId: 3,
      dayOfWeek: 7,
      time: '10:00 PM',
    ),
  );

  // History runs.
  Future<void> run(
    Routine r,
    List<RoutineStep> steps,
    Duration ago, {
    Set<int> skipped = const {},
    int minutes = 6,
  }) async {
    final end = now.subtract(ago);
    final start = end.subtract(Duration(minutes: minutes));
    final id = 'run-${r.id}-${ago.inHours}';
    final data = {
      'sessionId': 'session-$id',
      'startTime': start.toIso8601String(),
      'endTime': end.toIso8601String(),
      'baseRoutineId': r.id,
      'baseRoutineVersion': 1,
      'effectiveSteps': steps.map((s) => s.toJson()).toList(),
      'steps': [
        for (var i = 0; i < steps.length; i++)
          {
            'stepIndex': i,
            'label': steps[i].maybeWhen(
              check: (label, _, _, _, _, _, _) => label,
              orElse: () => 'Step',
            ),
            'completedAt': skipped.contains(i)
                ? null
                : start
                      .add(
                        Duration(
                          seconds: (minutes * 60 ~/ steps.length) * (i + 1),
                        ),
                      )
                      .toIso8601String(),
            'completed': !skipped.contains(i),
            'skipped': skipped.contains(i),
            'photos': <String>[],
            'proofAssets': <Object>[],
          },
      ],
    };
    await db.routineRunDao.insertOrUpdateRun(
      RoutineRun(
        id: id,
        routineId: '${r.id}',
        routineTitle: r.title,
        finishedAt: end,
        stepCompletionData: jsonEncode(data),
        ownerUserId: null,
        syncStatus: 'localOnly',
        lastSyncedAt: null,
        syncMetadataJson: null,
        updatedAt: end,
      ),
    );
  }

  // Older than the 6 h "Checked" window, so Home shows its ready state.
  await run(routines[0], _leaveHomeSteps, const Duration(hours: 7));
  await run(routines[1], _morningSteps, const Duration(hours: 9), skipped: {3});
  await run(routines[2], _windDownSteps, const Duration(hours: 15), minutes: 4);
  await run(routines[0], _leaveHomeSteps, const Duration(hours: 27));
  await run(
    routines[1],
    _morningSteps,
    const Duration(hours: 29),
    skipped: {2},
  );
  await run(routines[0], _leaveHomeSteps, const Duration(hours: 51));
  await run(routines[2], _windDownSteps, const Duration(hours: 63));
  await run(
    routines[0],
    _leaveHomeSteps,
    const Duration(hours: 99),
    minutes: 9,
  );
}

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  GoogleFonts.config.allowRuntimeFetching = false;

  // App + package fonts declared in pubspecs (DMSans, DMSerifDisplay,
  // MaterialIcons, Lucide).
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  // Roboto (Material default on Android) from the Flutter SDK cache; also
  // aliased as the iOS system font families since SF Pro is not available.
  final sdkFonts = Directory(
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  );
  final robotoFiles = sdkFonts.existsSync()
      ? sdkFonts
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'/Roboto-[A-Za-z]+\.ttf$').hasMatch(f.path))
            .toList()
      : <File>[];
  for (final family in [
    // Text with no fontFamily falls back to the platform font on devices but
    // to the Ahem-like 'FlutterTest' font in tests; map it to Roboto.
    'FlutterTest',
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    final loader = FontLoader(family);
    for (final f in robotoFiles) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  // Google Fonts used by the app, registered under google_fonts' own family
  // names so GoogleFonts.dmSans(...) etc. resolve to real glyphs.
  // They are also copied into a fake "application support" directory under
  // google_fonts' cache naming, so its own loader finds them instead of
  // throwing (fetching is disabled in tests).
  final dir = _fontsDir;
  Directory(_supportDir).createSync(recursive: true);
  if (dir != null && File('$dir/manifest.txt').existsSync()) {
    for (final line in File('$dir/manifest.txt').readAsLinesSync()) {
      final m = RegExp(r'^(.+_\w+) (\S+\.ttf) ([0-9a-f]+)$').firstMatch(line);
      if (m == null) continue;
      final file = File('$dir/${m.group(2)}');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      final cached = File('$_supportDir/${m.group(1)}_${m.group(3)}.ttf');
      if (!cached.existsSync()) cached.writeAsBytesSync(bytes);
      final loader = FontLoader(m.group(1)!)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  }
}

// ---------------------------------------------------------------------------
// Completion emails (no network): a fixed contact state per capture.
// ---------------------------------------------------------------------------

SharedReminderContact _contact(
  SharedReminderContactStatus status, {
  bool notify = true,
  bool includeName = true,
}) => SharedReminderContact(
  id: 'contact-1',
  routineKey: 'local:1',
  recipientEmail: 'sam.taylor@example.com',
  status: status,
  notifyWhenFinished: notify,
  includeRoutineName: includeName,
  includeStepCount: true,
  updatedAt: DateTime(2026, 10, 3, 9),
);

class _FakeSharedReminders extends SharedReminderPreferencesRepository {
  _FakeSharedReminders(this.contact) : super(null);

  SharedReminderContact? contact;

  @override
  bool get isAvailable => true;

  @override
  Future<SharedReminderContact?> getForRoutine({
    required int routineId,
    String? routineCloudId,
  }) async => contact;

  @override
  Future<SharedReminderContact> requestContact({
    required int routineId,
    required String recipientEmail,
    String? routineCloudId,
    bool resend = false,
    bool includeRoutineName = true,
    bool includeStepCount = true,
  }) async => contact = _contact(SharedReminderContactStatus.pending);

  @override
  Future<SharedReminderCompletionResult> sendCompletionReminder({
    required int routineId,
    required String routineTitle,
    required String runId,
    required String sessionId,
    required DateTime completedAt,
    required int completedSteps,
    required int totalSteps,
    String? routineCloudId,
    Duration retryDelay = const Duration(seconds: 4),
  }) async => contact?.canSendCompletionEmail == true
      ? SharedReminderCompletionResult(
          sent: true,
          recipientEmail: contact!.recipientEmail,
        )
      : const SharedReminderCompletionResult(sent: false);
}

// ---------------------------------------------------------------------------
// Photos: the "camera" hands back sample images from the support directory
// (sample_photo_1.jpg, sample_photo_2.jpg), copied fresh each time because
// the player deletes the picker's temp file once the photo is saved.
// ---------------------------------------------------------------------------

/// flutter_image_compress has no host side in tests: "re-encode" a capture
/// by copying it to the requested target, which is all a capture needs.
class _CopyImageCompress implements FlutterImageCompressPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #compressAndGetFile) {
      final source = invocation.positionalArguments[0] as String;
      final target = invocation.positionalArguments[1] as String;
      File(source).copySync(target);
      return Future<XFile?>.value(XFile(target));
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakePhotoPicker implements RoutinePlayerPhotoPicker {
  int _count = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  }) async {
    final sample = File('$_supportDir/sample_photo_${_count % 2 + 1}.jpg');
    if (!sample.existsSync()) return null;
    final copy = sample.copySync('$_supportDir/picked_${_count++}.jpg');
    return XFile(copy.path);
  }

  @override
  Future<XFile?> retrieveLostPhoto() async => null;
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

final _rootKey = GlobalKey();
final _layoutLog = StringBuffer();

class _Env {
  _Env(this.tester, this.device, this.db, this.prefs);
  final WidgetTester tester;
  final _Device device;
  final LocalDb db;
  final SharedPreferences prefs;
  final List<String> errors = [];

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(PebbleApp)));

  GoRouter get router =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  Future<void> settle([int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets real async work (drift transactions, file IO) finish.
  Future<void> realWait([int rounds = 5]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> go(String location) async {
    router.go(location);
    await settle();
  }

  Future<void> push(String location) async {
    unawaited(router.push<void>(location));
    await settle();
  }

  Future<void> tapFinder(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await settle();
  }

  Future<void> scrollDown(double dy, {Finder? within}) async {
    if (within == null && find.byType(Scrollable).evaluate().isEmpty) return;
    final target = within ?? find.byType(Scrollable).first;
    await tester.drag(target, Offset(0, -dy), warnIfMissed: false);
    await settle();
  }

  bool has(String text) => find.text(text).evaluate().isNotEmpty;

  Future<void> tapText(String text, {bool last = false}) async {
    final f = find.text(text);
    await tester.ensureVisible(last ? f.last : f.first);
    await tester.pump();
    await tester.tap(last ? f.last : f.first, warnIfMissed: false);
    await settle();
  }

  Future<void> shot(String name) async {
    await settle(4);
    await shotNow(name);
  }

  /// Captures the current frame without settling first, for motion strips.
  Future<void> shotNow(String name) async {
    final boundary =
        _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final shotName = '${device.id}__$name';
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: device.dpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory(_outDir).createSync(recursive: true);
      File(
        '$_outDir/$shotName.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    if (errors.isNotEmpty) {
      _layoutLog.writeln('=== $shotName');
      for (final e in errors) {
        _layoutLog.writeln(e);
      }
      errors.clear();
    }
    // ignore: avoid_print
    print('captured $shotName');
  }
}

String _summarise(FlutterErrorDetails details) {
  final lines = details.toString().split('\n');
  final out = <String>[details.exceptionAsString().split('\n').first];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('relevant error-causing widget')) {
      out.add(lines[i].trim());
      if (i + 1 < lines.length) out.add(lines[i + 1].trim());
      if (i + 2 < lines.length) out.add(lines[i + 2].trim());
    }
  }
  return out.join('\n  ');
}

typedef _Script = Future<void> Function(_Env env);

void _capture(
  String name,
  _Script script, {
  _Device device = _iphone,
  double textScale = 1,
  ThemeId theme = ThemeId.highNoon,
  bool onboarded = true,
  _Seed seed = _Seed.populated,
  _Account account = _Account.signedOutFree,
  _Store store = _Store.loaded,
  Map<String, Object> extraPrefs = const {},
  SharedReminderContact? sharedContact,
  bool fakeSharedReminders = false,
}) {
  final skip =
      !_enabled ||
      (_only != null && _only!.isNotEmpty && !name.contains(_only!));
  testWidgets(name, skip: skip, (tester) async {
    WidgetsApp.debugAllowBannerOverride = false;
    // flutter_test draws BoxShadow/elevation as hard shapes by default.
    debugDisableShadows = false;
    _mockPathProvider(tester);
    FlutterImageCompressPlatform.instance = _CopyImageCompress();
    await _loadFonts();
    final originalOnError = FlutterError.onError;
    final env0 = <String>[];
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('google_fonts') ||
          text.contains('allowRuntimeFetching')) {
        return;
      }
      env0.add(_summarise(details));
    };
    debugDefaultTargetPlatformOverride = device.platform;
    tester.view.physicalSize = device.size * device.dpr;
    tester.view.devicePixelRatio = device.dpr;
    tester.view.padding = FakeViewPadding(
      top: device.top * device.dpr,
      bottom: device.bottom * device.dpr,
    );
    tester.view.viewPadding = FakeViewPadding(
      top: device.top * device.dpr,
      bottom: device.bottom * device.dpr,
    );
    tester.platformDispatcher.textScaleFactorTestValue = textScale;

    final prefsValues = <String, Object>{
      'has_completed_onboarding': onboarded,
      'color_theme': theme.index,
      ...extraPrefs,
    };
    if (_hasBackupConsent(account)) {
      prefsValues['pebble.cloud_backup_consent.$_userId'] = jsonEncode(
        CloudBackupConsentRecord(
          userId: _userId,
          feature: cloudBackupConsentFeature,
          featureEnabled: true,
          appVersion: cloudBackupConsentAppVersion,
          privacyVersion: cloudBackupConsentPrivacyVersion,
          termsVersion: cloudBackupConsentTermsVersion,
          consentTextHash: cloudBackupConsentTextHash,
          consentedAt: DateTime.now().subtract(const Duration(days: 12)),
          withdrawnAt: null,
        ).toJson(),
      );
    }
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDb.forTesting(NativeDatabase.memory());
    await tester.runAsync(() => _seed(db, seed));

    final env = _Env(tester, device, db, prefs);
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _rootKey,
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              localDbProvider.overrideWithValue(db),
              appRuntimeConfigProvider.overrideWithValue(
                appRuntimeConfigFromEnvironment(),
              ),
              supabaseRuntimeConfigProvider.overrideWithValue(
                const SupabaseRuntimeConfig(
                  enabled: false,
                  url: '',
                  anonKey: '',
                  googleWebClientId: 'walkthrough-web-client',
                ),
              ),
              revenueCatRuntimeConfigProvider.overrideWithValue(
                const RevenueCatRuntimeConfig(
                  androidApiKey: 'goog_walkthrough',
                  iosApiKey: 'appl_walkthrough',
                ),
              ),
              authRepositoryProvider.overrideWithValue(_FakeAuth()),
              routinePlayerPhotoPickerProvider.overrideWithValue(
                _FakePhotoPicker(),
              ),
              if (fakeSharedReminders || sharedContact != null)
                sharedReminderPreferencesRepositoryProvider.overrideWithValue(
                  _FakeSharedReminders(sharedContact),
                ),
              purchaseRepositoryProvider.overrideWith(
                (ref) => _FakePurchases(store),
              ),
              subscriptionAccountControllerProvider.overrideWith(
                (ref) => _TestAccountController(db, _accountState(account)),
              ),
              if (_isSignedIn(account))
                authSessionProvider.overrideWithValue(
                  const AuthSessionSummary(
                    isSignedIn: true,
                    userId: _userId,
                    email: _email,
                    provider: 'google',
                  ),
                ),
            ],
            child: const PebbleApp(),
          ),
        ),
      );
      await env.settle(20);
      env.errors.addAll(env0);
      env0.clear();
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('google_fonts') ||
            text.contains('allowRuntimeFetching')) {
          return;
        }
        env.errors.add(_summarise(details));
      };
      await script(env);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
      FlutterError.onError = originalOnError;
      debugDefaultTargetPlatformOverride = null;
      WidgetsApp.debugAllowBannerOverride = true;
      debugDisableShadows = true;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
      Directory(_outDir).createSync(recursive: true);
      File(
        '$_outDir/_layout_errors.txt',
      ).writeAsStringSync(_layoutLog.toString(), mode: FileMode.append);
      _layoutLog.clear();
    }
  });
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

Future<void> _onboardingPage(_Env env, int page) async {
  final pv = env.tester.widget<PageView>(find.byType(PageView).first);
  pv.controller!.jumpToPage(page);
  await env.settle();
}

Future<void> _openPlayer(_Env env, int id) async {
  await env.push('/play/$id');
  await env.settle(20);
}

/// Opens the hero routine's actions sheet from the Home meta line and taps
/// [label] in it.
Future<void> _openRoutineAction(_Env env, String label) async {
  await env.tapFinder(find.byTooltip('Routine settings').first);
  await env.tapText(label, last: true);
}

/// Runs "Leaving the house" end to end with one photo on the photo step,
/// then taps Done, landing on Home in its Checked state.
Future<void> _runLeavingHouseToHome(_Env env) async {
  await _openPlayer(env, 1);
  for (var i = 0; i < 3; i++) {
    await _tapPrimary(env);
    await env.realWait(2);
  }
  await env.tapText('Add');
  await env.realWait(12);
  await _tapPrimary(env);
  await env.realWait(2);
  await _tapPrimary(env);
  await env.realWait(10);
  await env.settle(20);
  await env.realWait(4);
}

Future<void> _tapPrimary(_Env env) async {
  await env.tapFinder(find.byType(FilledButton).last);
  await env.settle(20);
}

void _onboardingSet(
  String prefix, {
  _Device device = _iphone,
  double textScale = 1,
}) {
  _capture(
    '$prefix onboarding',
    device: device,
    textScale: textScale,
    onboarded: false,
    seed: _Seed.empty,
    (env) async {
      await env.shot('${prefix}onboarding_1_welcome');
      await env.scrollDown(400);
      await env.shot('${prefix}onboarding_1_welcome_scrolled');
      await _onboardingPage(env, 1);
      await env.shot('${prefix}onboarding_2_theme');
      await env.scrollDown(500);
      await env.shot('${prefix}onboarding_2_theme_scrolled');
      await _onboardingPage(env, 2);
      await env.shot('${prefix}onboarding_3_starting_point');
      await env.scrollDown(500);
      await env.shot('${prefix}onboarding_3_starting_point_scrolled');
      await _onboardingPage(env, 3);
      await env.shot('${prefix}onboarding_4_starter_preview');
      await env.scrollDown(500);
      await env.shot('${prefix}onboarding_4_starter_preview_scrolled');
    },
  );
}

void main() {
  // ---- Onboarding --------------------------------------------------------
  _onboardingSet('');
  _onboardingSet('', device: _small);
  _onboardingSet('a11y2x_', textScale: 2.0);
  _capture('onboarding possibilities', onboarded: false, seed: _Seed.empty, (
    env,
  ) async {
    final explore = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('What can Pebble do'),
    );
    if (explore.evaluate().isNotEmpty) {
      await env.tapFinder(explore.first);
    } else {
      await env.tapFinder(find.byType(TextButton).first);
    }
    await env.shot('onboarding_possibilities');
    await env.scrollDown(500);
    await env.shot('onboarding_possibilities_scrolled');
    await env.scrollDown(800);
    await env.shot('onboarding_possibilities_end');
  });

  // ---- Home --------------------------------------------------------------
  _capture('home populated', (env) async {
    await env.shot('home_populated');
    await env.tapText('Your Routines');
    await env.settle(10);
    await env.shot('home_routines_sheet_open');
    await env.tapFinder(find.byIcon(LucideIcons.plus).last);
    await env.shot('home_create_choice_sheet');
  });
  _capture('home premium', account: _Account.signedInPremium, (env) async {
    await env.shot('home_premium');
    await env.tapText('Your Routines');
    await env.settle(10);
    await env.shot('home_premium_routines_sheet_open');
  });
  // Moment 3: Home after a run.
  for (final cfg in [
    (ThemeId.highNoon, _iphone, 1.0, ''),
    (ThemeId.nordicNight, _iphone, 1.0, 'theme_nordicNight_'),
    (ThemeId.highNoon, _small, 1.0, ''),
    (ThemeId.highNoon, _iphone, 2.0, 'a11y2.0x_'),
  ]) {
    _capture(
      'home checked ${cfg.$1.name} ${cfg.$2.id} ${cfg.$3}',
      theme: cfg.$1,
      device: cfg.$2,
      textScale: cfg.$3,
      account: _Account.signedInPremium,
      extraPrefs: const {'has_seen_camera_rationale': true},
      (env) async {
        await _runLeavingHouseToHome(env);
        if (cfg.$2 == _iphone && cfg.$3 == 1.0 && cfg.$1 == ThemeId.highNoon) {
          await env.shot('player_complete_photo');
        }
        await env.tapText('Done');
        await env.realWait(6);
        await env.settle(10);
        await env.realWait(4);
        await env.shot('${cfg.$4}home_checked');
      },
    );
  }
  _capture('home empty', seed: _Seed.empty, (env) async {
    await env.shot('home_empty');
  });
  _capture('home small', device: _small, (env) async {
    await env.shot('home_populated');
    await env.tapText('Your Routines');
    await env.settle(10);
    await env.shot('home_routines_sheet_open');
  });
  _capture('home small empty', device: _small, seed: _Seed.empty, (env) async {
    await env.shot('home_empty');
  });
  for (final scale in [1.6, 2.0]) {
    _capture('home a11y $scale', textScale: scale, (env) async {
      await env.shot('a11y${scale}x_home_populated');
      await env.tapText('Your Routines');
      await env.settle(10);
      await env.shot('a11y${scale}x_home_routines_sheet_open');
    });
  }
  _capture('home a11y empty', textScale: 2.0, seed: _Seed.empty, (env) async {
    await env.shot('a11y2.0x_home_empty');
  });

  // ---- History -----------------------------------------------------------
  _capture('history', (env) async {
    env.container.read(navIndexProvider.notifier).state = 1;
    await env.settle();
    await env.shot('history_list');
    await env.scrollDown(500);
    await env.shot('history_list_scrolled');
    await env.scrollDown(-2000);
    final run = find.text('Morning reset');
    if (run.evaluate().isNotEmpty) {
      await env.tapFinder(run.first);
      await env.shot('history_run_detail');
      await env.scrollDown(500);
      await env.shot('history_run_detail_scrolled');
    }
  });
  _capture('history empty', seed: _Seed.empty, (env) async {
    env.container.read(navIndexProvider.notifier).state = 1;
    await env.settle();
    await env.shot('history_empty');
  });

  // ---- Composer ----------------------------------------------------------
  _capture('composer new', (env) async {
    await env.push('/creator?fresh=1');
    await env.shot('composer_new');
  });
  _capture('composer edit', account: _Account.signedInPremium, (env) async {
    await env.push('/edit/2');
    await env.shot('composer_edit');
    await env.scrollDown(400);
    await env.shot('composer_edit_scrolled');
  });
  _capture('composer edit free', (env) async {
    await env.push('/edit/2');
    await env.shot('composer_edit_free');
  });

  // ---- Player ------------------------------------------------------------
  _capture('player', account: _Account.signedInPremium, (env) async {
    await _openPlayer(env, 1);
    await env.shot('player_step1');
    await _tapPrimary(env);
    await env.shot('player_step2');
    await _tapPrimary(env);
    await _tapPrimary(env);
    await env.shot('player_photo_step');
  });
  _capture('player complete', account: _Account.signedInPremium, (env) async {
    await _openPlayer(env, 3);
    for (var i = 0; i < 4; i++) {
      await _tapPrimary(env);
      await env.realWait(3);
    }
    await env.realWait(10);
    await env.settle(30);
    await env.shot('player_complete');
  });
  _capture(
    'player complete nordicNight',
    theme: ThemeId.nordicNight,
    account: _Account.signedInPremium,
    (env) async {
      await _openPlayer(env, 3);
      for (var i = 0; i < 4; i++) {
        await _tapPrimary(env);
        await env.realWait(3);
      }
      await env.realWait(10);
      await env.settle(30);
      await env.shot('theme_nordicNight_complete');
    },
  );
  _capture(
    'player complete sandstone',
    theme: ThemeId.sandstone,
    account: _Account.signedInPremium,
    (env) async {
      await _openPlayer(env, 3);
      for (var i = 0; i < 4; i++) {
        await _tapPrimary(env);
        await env.realWait(3);
      }
      await env.realWait(10);
      await env.settle(30);
      await env.shot('theme_sandstone_complete');
    },
  );
  // Moment 1: the trail of checked steps, and the check-off as a strip.
  _capture('player trail', account: _Account.signedInPremium, (env) async {
    await _openPlayer(env, 1);
    await _tapPrimary(env);
    await env.realWait(2);
    await _tapPrimary(env);
    await env.realWait(2);
    await env.shot('player_trail');
    await _tapPrimary(env);
    await env.realWait(2);
    await env.shot('player_trail_photo_step');
  });
  _capture(
    'player trail nordicNight',
    theme: ThemeId.nordicNight,
    account: _Account.signedInPremium,
    (env) async {
      await _openPlayer(env, 1);
      await _tapPrimary(env);
      await env.realWait(2);
      await _tapPrimary(env);
      await env.realWait(2);
      await env.shot('theme_nordicNight_player_trail');
    },
  );
  _capture('player check motion', account: _Account.signedInPremium, (
    env,
  ) async {
    await _openPlayer(env, 3);
    await _tapPrimary(env);
    await env.realWait(2);
    await env.settle(10);
    await env.tester.tap(find.byType(FilledButton).last);
    var elapsed = 0;
    await env.tester.pump();
    for (final ms in [120, 220, 330, 450, 800]) {
      while (elapsed < ms) {
        await env.tester.pump(const Duration(milliseconds: 10));
        elapsed += 10;
      }
      await env.shotNow('motion_check_${ms.toString().padLeft(3, '0')}ms');
    }
  });
  // Moment 2: completion with photos and a skip, light and dark.
  for (final theme in [ThemeId.highNoon, ThemeId.nordicNight]) {
    final prefix = theme == ThemeId.highNoon ? '' : 'theme_${theme.name}_';
    _capture(
      'player complete photos ${theme.name}',
      theme: theme,
      account: _Account.signedInPremium,
      extraPrefs: const {'has_seen_camera_rationale': true},
      (env) async {
        // Same routine without its voice tip: just_audio has no host side
        // here, and disposing its player mid-run fails in the harness.
        await env.tester.runAsync(() async {
          final morning = await env.db.routineDao.getRoutineById(2);
          await env.db.routineDao.insertOrUpdateRoutine(
            morning!.copyWith(
              stepsJson: _steps([
                const RoutineStep.check(label: 'Open the curtains'),
                ..._morningSteps.skip(1),
              ]),
            ),
          );
        });
        await env.realWait(2);
        await _openPlayer(env, 2);
        await _tapPrimary(env);
        await env.realWait(2);
        await _tapPrimary(env);
        await env.realWait(2);
        for (var i = 0; i < 2; i++) {
          await env.tapText('Add');
          await env.realWait(12);
        }
        await _tapPrimary(env);
        await env.realWait(3);
        await env.tapText('Skip step');
        await env.realWait(10);
        await env.settle(20);
        await env.realWait(6);
        await env.shot('${prefix}player_complete_photos_skip');
      },
    );
  }
  _capture('player complete motion', account: _Account.signedInPremium, (
    env,
  ) async {
    final navigator = Navigator.of(
      env.tester.element(find.byType(Scaffold).first),
    );
    unawaited(
      navigator.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: RoutineCompleteScreen(
                routineName: 'Leaving the house',
                routineId: 1,
                totalStepsCompleted: 5,
                totalPhotosSaved: 0,
                finishedAt: DateTime(2026, 10, 3, 8, 4),
                showPhotoSummary: false,
                onBackToHome: () {},
                onReviewRoutine: () {},
              ),
            ),
          ),
        ),
      ),
    );
    var elapsed = 0;
    await env.tester.pump();
    for (final ms in [260, 420, 560, 700, 820, 980, 1400]) {
      while (elapsed < ms) {
        await env.tester.pump(const Duration(milliseconds: 10));
        elapsed += 10;
      }
      await env.shotNow('motion_complete_${ms.toString().padLeft(4, '0')}ms');
    }
  });
  _capture('player voice', account: _Account.signedInPremium, (env) async {
    await _openPlayer(env, 2);
    await env.shot('player_voice_step');
  });
  _capture('player locked', (env) async {
    await _openPlayer(env, 2);
    await env.realWait();
    await env.shot('player_locked_routine');
  });
  _capture('player small', device: _small, account: _Account.signedInPremium, (
    env,
  ) async {
    await _openPlayer(env, 1);
    await env.shot('player_step1');
    await _tapPrimary(env);
    await _tapPrimary(env);
    await _tapPrimary(env);
    await env.shot('player_photo_step');
  });
  for (final scale in [1.6, 2.0]) {
    _capture(
      'player a11y $scale',
      textScale: scale,
      account: _Account.signedInPremium,
      (env) async {
        await _openPlayer(env, 1);
        await env.shot('a11y${scale}x_player_step1');
        await _tapPrimary(env);
        await _tapPrimary(env);
        await _tapPrimary(env);
        await env.shot('a11y${scale}x_player_photo_step');
      },
    );
  }

  // ---- Reminders ---------------------------------------------------------
  _capture('reminders', (env) async {
    await env.push('/reminders');
    await env.realWait(8);
    await env.shot('reminders_global');
    await env.scrollDown(500);
    await env.shot('reminders_global_scrolled');
  });
  _capture('reminders empty', seed: _Seed.empty, (env) async {
    await env.push('/reminders');
    await env.realWait(8);
    await env.shot('reminders_global_empty');
  });

  // ---- Templates ---------------------------------------------------------
  _capture('templates', (env) async {
    await env.push('/templates');
    await env.shot('templates_gallery');
    await env.scrollDown(600);
    await env.shot('templates_gallery_scrolled');
    await env.go('/');
    await env.push('/templates/tpl_anxiety_free_departure');
    await env.shot('template_detail');
    await env.scrollDown(600);
    await env.shot('template_detail_scrolled');
  });

  // ---- Paywall -----------------------------------------------------------
  void paywall(
    String prefix, {
    _Device device = _iphone,
    double textScale = 1,
    ThemeId theme = ThemeId.highNoon,
    _Store store = _Store.loaded,
  }) {
    _capture(
      'paywall $prefix',
      device: device,
      textScale: textScale,
      theme: theme,
      store: store,
      (env) async {
        await env.push('/premium?source=routine_limit');
        await env.shot('${prefix}paywall');
        await env.scrollDown(600);
        await env.shot('${prefix}paywall_scrolled');
        await env.scrollDown(900);
        await env.shot('${prefix}paywall_end');
      },
    );
  }

  paywall('');
  paywall('store_unavailable_', store: _Store.unavailable);
  paywall('', device: _small);
  paywall('a11y1.6x_', textScale: 1.6);
  paywall('a11y2.0x_', textScale: 2.0);
  paywall('dark_nordic_', theme: ThemeId.nordicNight);

  // ---- Account -----------------------------------------------------------
  _capture('sign in', (env) async {
    await env.push('/sign-in');
    await env.shot('sign_in');
    await env.scrollDown(600);
    await env.shot('sign_in_scrolled');
  });
  for (final account in [
    _Account.signedOutFree,
    _Account.signedInFree,
    _Account.signedInPremium,
    _Account.premiumEnded,
  ]) {
    _capture('account ${account.name}', account: account, (env) async {
      await env.push('/account-hub');
      await env.shot('account_hub_${account.name}');
      await env.scrollDown(600);
      await env.shot('account_hub_${account.name}_scrolled');
      await env.scrollDown(900);
      await env.shot('account_hub_${account.name}_end');
      await env.go('/');
      await env.push('/cloud-backup');
      await env.shot('cloud_backup_${account.name}');
      await env.scrollDown(600);
      await env.shot('cloud_backup_${account.name}_scrolled');
    });
  }

  // ---- Settings ----------------------------------------------------------
  _capture('settings', (env) async {
    await env.push('/settings');
    await env.shot('settings');
    await env.scrollDown(600);
    await env.shot('settings_scrolled');
    await env.tapText('Theme & colours');
    await env.shot('appearance');
    await env.scrollDown(600);
    await env.shot('appearance_scrolled');
    await env.scrollDown(900);
    await env.shot('appearance_end');
  });
  _capture('settings premium', account: _Account.signedInPremium, (env) async {
    await env.push('/settings');
    await env.tapText('Theme & colours');
    await env.shot('appearance_premium');
  });
  _capture('about', (env) async {
    await env.push('/settings');
    await env.scrollDown(900);
    await env.tapText('About Pebble');
    await env.shot('legal_about');
    await env.scrollDown(600);
    await env.shot('legal_about_scrolled');
    await env.scrollDown(900);
    await env.shot('legal_about_end');
  });

  // ---- Themes ------------------------------------------------------------
  for (final theme in ThemeId.values) {
    _capture(
      'theme ${theme.name}',
      theme: theme,
      account: _Account.signedInPremium,
      (env) async {
        await env.shot(
          'theme_${theme.index.toString().padLeft(2, '0')}_${theme.name}_home',
        );
      },
    );
  }
  for (final theme in [
    ThemeId.nordicNight,
    ThemeId.highContrastDark,
    ThemeId.sandstone,
  ]) {
    _capture(
      'theme screens ${theme.name}',
      theme: theme,
      account: _Account.signedInPremium,
      (env) async {
        await _openPlayer(env, 1);
        await env.shot('theme_${theme.name}_player');
        await env.go('/');
        env.container.read(navIndexProvider.notifier).state = 1;
        await env.settle();
        await env.shot('theme_${theme.name}_history');
        await env.push('/edit/2');
        await env.shot('theme_${theme.name}_composer');
      },
    );
  }

  // ---- Extra flows -------------------------------------------------------
  _capture('home actions', (env) async {
    await env.tapFinder(find.byTooltip('Routine settings').first);
    await env.shot('home_routine_actions_menu');
    await env.tapText('Reorder steps');
    await env.realWait();
    await env.shot('reorder_steps');
  });
  _capture('home style free', (env) async {
    await env.tapFinder(find.byTooltip('Routine settings').first);
    await env.tapText('Style');
    await env.shot('home_style_upsell_free');
  });
  _capture('home actions premium', account: _Account.signedInPremium, (
    env,
  ) async {
    await env.tapFinder(find.byTooltip('Routine settings').first);
    await env.tapText('Style');
    await env.shot('home_style_studio_premium');
  });
  _capture('home reminders bell', (env) async {
    await _openRoutineAction(env, 'Reminders');
    await env.realWait(6);
    await env.shot('routine_reminders_from_home');
  });
  _capture('home email free', (env) async {
    await _openRoutineAction(env, 'Completion emails');
    await env.realWait(6);
    await env.shot('routine_email_alerts_from_home');
  });
  _capture('home email premium', account: _Account.signedInPremium, (
    env,
  ) async {
    await _openRoutineAction(env, 'Completion emails');
    await env.realWait(6);
    await env.shot('routine_email_alerts_premium');
  });
  // Completion emails: every contact state the sender can see.
  for (final entry in <String, SharedReminderContact?>{
    'none': null,
    'pending': _contact(SharedReminderContactStatus.pending),
    'accepted': _contact(SharedReminderContactStatus.accepted),
    'accepted_off_hidden_name': _contact(
      SharedReminderContactStatus.accepted,
      notify: false,
      includeName: false,
    ),
    'declined': _contact(SharedReminderContactStatus.declined),
    'blocked': _contact(SharedReminderContactStatus.blocked),
  }.entries) {
    _capture(
      'email contact ${entry.key}',
      account: _Account.signedInPremium,
      sharedContact: entry.value,
      fakeSharedReminders: true,
      (env) async {
        await _openRoutineAction(env, 'Completion emails');
        await env.realWait(6);
        await env.shot('email_contact_${entry.key}');
        await env.scrollDown(700);
        await env.shot('email_contact_${entry.key}_scrolled');
      },
    );
  }
  _capture(
    'email invite sheet',
    account: _Account.signedInPremium,
    fakeSharedReminders: true,
    (env) async {
      await _openRoutineAction(env, 'Completion emails');
      await env.realWait(6);
      await env.tapText('Add someone to notify', last: true);
      await env.realWait(4);
      await env.shot('email_invite_sheet');
    },
  );
  _capture(
    'player complete email sent',
    account: _Account.signedInPremium,
    sharedContact: _contact(SharedReminderContactStatus.accepted),
    (env) async {
      await _openPlayer(env, 3);
      for (var i = 0; i < 4; i++) {
        await _tapPrimary(env);
        await env.realWait(3);
      }
      await env.realWait(10);
      await env.settle(30);
      await env.shot('player_complete_email_sent');
    },
  );
  _capture('reminder editor', (env) async {
    await env.push('/reminders');
    await env.realWait(8);
    await env.tapText('New reminder');
    await env.realWait(4);
    await env.shot('reminder_new_step1');
    final pick = find.text('Leaving the house');
    if (pick.evaluate().isNotEmpty) {
      await env.tapFinder(pick.last);
      await env.realWait(4);
      await env.shot('reminder_editor_sheet');
    }
  });
  _capture('reminder editor existing', (env) async {
    await env.push('/reminders');
    await env.realWait(8);
    await env.tapFinder(find.textContaining('8:15 AM').first);
    await env.realWait(4);
    await env.shot('reminder_editor_existing');
  });
  _capture('resume card', account: _Account.signedInPremium, (env) async {
    await _openPlayer(env, 3);
    await _tapPrimary(env);
    await env.realWait(3);
    await _tapPrimary(env);
    await env.realWait(3);
    await env.tapFinder(find.byTooltip('Back').first);
    await env.realWait(3);
    await env.shot('player_leave_prompt');
    if (env.has('Leave and save')) {
      await env.tapText('Leave and save');
      await env.realWait(5);
    }
    await env.go('/');
    await env.realWait(5);
    await env.shot('home_with_resume');
  });
  _capture('player free photo', (env) async {
    await _openPlayer(env, 1);
    await _tapPrimary(env);
    await _tapPrimary(env);
    await _tapPrimary(env);
    await env.shot('player_photo_step_free');
  });
  _capture('composer step options', account: _Account.signedInPremium, (
    env,
  ) async {
    await env.push('/edit/2');
    await env.tapText('Take morning medication');
    await env.shot('composer_photo_step_expanded');
    await env.tapText('Glass of water');
    await env.shot('composer_plain_step_expanded');
  });
  _capture('composer voice free', (env) async {
    await env.push('/edit/1');
    await env.tapText('Voice tip');
    await env.realWait(3);
    await env.shot('composer_voice_tip_free');
  });
  _capture('composer voice premium', account: _Account.signedInPremium, (
    env,
  ) async {
    await env.push('/edit/1');
    await env.tapText('Voice tip');
    await env.realWait(3);
    await env.shot('composer_voice_tip_recorder');
  });
  _capture('composer small', device: _small, (env) async {
    await env.push('/edit/2');
    await env.shot('composer_edit');
  });
  _capture('about tabs', (env) async {
    await env.push('/settings');
    await env.scrollDown(900);
    await env.tapText('About Pebble');
    await env.tapText('Terms');
    await env.shot('legal_about_terms');
    await env.tapText('Delete');
    await env.shot('legal_about_delete');
    await env.scrollDown(600);
    await env.shot('legal_about_delete_scrolled');
  });
  _capture('sign in email', (env) async {
    await env.push('/sign-in');
    await env.tapText('Continue with Email');
    await env.realWait(3);
    await env.shot('sign_in_email_sheet');
  });
  _capture('delete account', account: _Account.signedInPremium, (env) async {
    await env.push('/account-hub');
    await env.tapText('Delete account');
    await env.realWait(3);
    await env.shot('account_delete_confirm');
  });
  _capture('sign in small', device: _small, (env) async {
    await env.push('/sign-in');
    await env.shot('sign_in');
  });
  _capture('account small', device: _small, account: _Account.premiumEnded, (
    env,
  ) async {
    await env.push('/account-hub');
    await env.shot('account_hub_premiumEnded');
  });

  _capture(
    'home small premium',
    device: _small,
    account: _Account.signedInPremium,
    (env) async {
      await env.shot('home_premium');
    },
  );
  for (final scale in [1.6, 2.0]) {
    _capture(
      'home a11y premium $scale',
      textScale: scale,
      account: _Account.signedInPremium,
      (env) async {
        await env.shot('a11y${scale}x_home_premium');
      },
    );
  }

  for (final cfg in [(_small, 1.0), (_iphone, 1.6)]) {
    _capture(
      'resume ${cfg.$1.id} ${cfg.$2}',
      device: cfg.$1,
      textScale: cfg.$2,
      (env) async {
        await _openPlayer(env, 3);
        await _tapPrimary(env);
        await env.realWait(3);
        await env.tapFinder(find.byTooltip('Back').first);
        await env.realWait(3);
        if (env.has('Leave and save')) {
          await env.tapText('Leave and save');
          await env.realWait(5);
        }
        await env.go('/');
        await env.realWait(5);
        await env.shot(
          '${cfg.$2 == 1.0 ? '' : 'a11y${cfg.$2}x_'}home_with_resume',
        );
      },
    );
  }

  // ---- Subscription lifecycle (SUBSCRIPTION_REVIEW.md) --------------------
  _capture('sub pending purchase', store: _Store.pending, (env) async {
    await env.push('/premium?source=routine_limit');
    await env.tapFinder(find.textContaining('Continue with').first);
    await env.settle(10);
    await env.shot('sub_pending_purchase');
  });
  _capture('sub purchase signed out', store: _Store.purchaseSucceeds, (
    env,
  ) async {
    await env.push('/premium?source=routine_limit');
    await env.tapFinder(find.textContaining('Continue with').first);
    await env.settle(20);
    await env.shot('sub_purchase_success_signed_out');
  });
  _capture('sub cancelled', account: _Account.premiumCancelled, (env) async {
    await env.push('/account-hub');
    await env.shot('sub_account_cancelled_still_active');
  });
  _capture('sub billing issue', account: _Account.premiumBillingIssue, (
    env,
  ) async {
    await env.push('/account-hub');
    await env.shot('sub_account_billing_issue');
  });
  _capture(
    'sub grace home',
    account: _Account.premiumGrace,
    seed: _Seed.fiveRoutines,
    (env) async {
      await env.realWait(5);
      await env.shot('sub_grace_home');
      await env.push('/account-hub');
      await env.realWait(3);
      await env.shot('sub_grace_account');
      await env.scrollDown(600);
      await env.shot('sub_grace_account_scrolled');
      await env.scrollDown(900);
      await env.shot('sub_grace_account_end');
    },
  );
  _capture(
    'sub lapsed five',
    account: _Account.premiumEnded,
    seed: _Seed.fiveRoutines,
    (env) async {
      await env.realWait(5);
      await env.shot('sub_lapsed_home');
      await env.tapText('Your Routines');
      await env.settle(10);
      await env.shot('sub_lapsed_routines_sheet');
      await env.tapText('Morning reset', last: true);
      await env.settle(10);
      await env.shot('sub_locked_routine_sheet');
      await env.tapText('Choose 2 routines to keep');
      await env.settle(10);
      await env.shot('sub_keep_routines_sheet');
    },
  );
  _capture(
    'sub lapsed account',
    account: _Account.premiumEnded,
    seed: _Seed.fiveRoutines,
    (env) async {
      await env.push('/account-hub');
      await env.realWait(3);
      await env.shot('sub_lapsed_account');
      await env.scrollDown(600);
      await env.shot('sub_lapsed_account_scrolled');
      await env.scrollDown(900);
      await env.shot('sub_lapsed_account_end');
    },
  );
  _capture(
    'sub locked player',
    account: _Account.premiumEnded,
    seed: _Seed.fiveRoutines,
    (env) async {
      await _openPlayer(env, 2);
      await env.realWait();
      await env.shot('sub_premium_ended_locked_routine');
    },
  );
  _capture(
    'sub resubscribe',
    account: _Account.premiumEnded,
    seed: _Seed.fiveRoutines,
    (env) async {
      await env.push('/account-hub');
      await env.realWait(3);
      await env.tapText('Renew Premium');
      await env.settle(10);
      await env.shot('sub_resubscribe_paywall');
    },
  );
  _capture('sub delete with premium', account: _Account.signedInPremium, (
    env,
  ) async {
    await env.push('/account-hub');
    await env.tapText('Delete account');
    await env.realWait(3);
    await env.shot('sub_delete_account_sheet');
  });
}
