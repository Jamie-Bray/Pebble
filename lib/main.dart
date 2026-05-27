// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/theme_provider.dart';
import 'core/config/app_runtime_config.dart';
import 'core/navigation/app_shell.dart';
import 'data/remote/supabase_client_provider.dart';
import 'features/templates/ui/template_detail_screen.dart';
import 'features/templates/ui/templates_gallery_screen.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';
import 'package:pebble_routines/features/account_backup/ui/account_hub_screen.dart';
import 'package:pebble_routines/features/settings/ui/settings_screen.dart';
import 'package:pebble_routines/features/onboarding/ui/onboarding_screen.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'features/settings/data/player_settings_provider.dart';
import 'core/notifications/notification_service.dart';
// removed unused haptics service import
import 'core/database/local_db.dart';
import 'data/repositories/routine_repository.dart';
import 'data/repositories/routine_run_repository.dart';
import 'features/auth/ui/sign_in_screen.dart';
import 'features/routines/execution/ui/routine_player_screen.dart';
import 'features/routines/execution/data/repositories/routine_session_repository.dart';
import 'features/routines/list/providers/routine_list_provider.dart';
import 'features/sync/cloud_sync_coordinator.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'features/subscription/data/purchase_repository.dart';
import 'features/subscription/data/revenuecat_runtime_config.dart';
// duplicate import removed

class RoutineSessionEntry {
  final Routine routine;
  final String sessionId;

  const RoutineSessionEntry({required this.routine, required this.sessionId});
}

final routineSessionEntryProvider = FutureProvider.autoDispose
    .family<RoutineSessionEntry?, int>((ref, id) async {
      final routineRepo = ref.read(routineRepositoryProvider);
      final sessionRepo = ref.read(routineSessionRepositoryProvider);
      final routingContext = ref.read(sessionRoutingContextProvider);
      final routine = await routineRepo.getRoutineById(id);
      if (routine == null) {
        return null;
      }
      final session = await sessionRepo.startOrResumeSession(
        routine: routine,
        routingContext: routingContext,
      );
      return RoutineSessionEntry(
        routine: routine,
        sessionId: session.sessionId,
      );
    });

final _rootNavigatorKey = GlobalKey<NavigatorState>();

TimeOfDay? _parseReminderTime(String value) {
  try {
    final parsed = DateFormat('h:mm a').parse(value);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  } catch (_) {
    return null;
  }
}

bool _isOnboardingTemplateRequest(GoRouterState state) {
  final path = state.uri.path;
  final fromOnboarding = state.uri.queryParameters['from'] == 'onboarding';
  return fromOnboarding &&
      (path == '/templates' || path.startsWith('/templates/'));
}

int _onboardingInitialPage(GoRouterState state) {
  return state.uri.queryParameters['step'] == 'templates' ? 2 : 0;
}

Future<void> _resyncEnabledReminderNotifications(LocalDb db) async {
  final notifications = NotificationService();
  final hasPermission = await notifications.hasNotificationPermission();
  if (!hasPermission) return;

  final routines = await db.routineDao.watchAllRoutines().first;
  for (final routine in routines) {
    final existing = await db.routineReminderDao.getRemindersForRoutine(
      routine.id,
    );
    final hasLegacyReminder =
        routine.reminderDay != null &&
        routine.reminderTime != null &&
        routine.reminderDay! >= 1 &&
        routine.reminderDay! <= 7 &&
        _parseReminderTime(routine.reminderTime!) != null;
    if (existing.isEmpty && hasLegacyReminder) {
      await db.routineReminderDao.addReminder(
        RoutineRemindersCompanion(
          routineId: drift.Value(routine.id),
          dayOfWeek: drift.Value(routine.reminderDay!),
          time: drift.Value(routine.reminderTime!),
          isEnabled: const drift.Value(true),
        ),
      );
    }
  }

  final reminders = await db.routineReminderDao.getAllEnabledReminders();
  final routineIdsWithMultiReminders = <int>{};
  for (final reminder in reminders) {
    final time = _parseReminderTime(reminder.time);
    if (time == null) continue;

    final routine = await db.routineDao.getRoutineById(reminder.routineId);
    try {
      await notifications.scheduleRoutineReminder(
        routineId: reminder.routineId,
        title: routine?.title ?? 'Routine',
        dayOfWeek: reminder.dayOfWeek,
        time: time,
        reminderId: reminder.id,
        requestPermissionIfNeeded: false,
      );
      routineIdsWithMultiReminders.add(reminder.routineId);
    } catch (_) {
      // Skip individual failures so one broken reminder doesn't block startup.
    }
  }

  // Clean up legacy routine-level IDs now that reminder-level schedules are in use.
  for (final routineId in routineIdsWithMultiReminders) {
    await notifications.cancelRoutineReminder(routineId);
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final runtimeConfig = ref.watch(appRuntimeConfigProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;
      final isGoingToOnboarding = state.uri.path == '/onboarding';
      if (!hasCompletedOnboarding &&
          !isGoingToOnboarding &&
          !_isOnboardingTemplateRequest(state)) {
        return '/onboarding';
      }
      if (hasCompletedOnboarding && isGoingToOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(initialPage: _onboardingInitialPage(state)),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
        routes: [
          GoRoute(
            path: 'templates/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TemplateDetailScreen(
                templateId: id,
                fromOnboarding:
                    state.uri.queryParameters['from'] == 'onboarding',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => TemplatesGalleryScreen(
          fromOnboarding: state.uri.queryParameters['from'] == 'onboarding',
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/creator',
        builder: (context, state) => RoutineComposerScreen.newDraft(
          forceNewDraft: state.uri.queryParameters['fresh'] == '1',
          onSaveComplete: (routine) {
            ref.read(navIndexProvider.notifier).state = 0;
            ref
                .read(homeRoutineHighlightProvider.notifier)
                .state = HomeRoutineHighlight(
              routineId: routine.id,
              message: '${routine.title} is ready',
            );
            GoRouter.of(context).go('/');
          },
        ),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const GlobalRemindersScreen(),
      ),
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (context, state) => PebblePaywall(
          entrySource: PremiumEntrySourceParsing.fromQuery(
            state.uri.queryParameters['source'],
          ),
        ),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => PebblePaywall(
          entrySource: PremiumEntrySourceParsing.fromQuery(
            state.uri.queryParameters['source'],
          ),
        ),
      ),
      GoRoute(
        path: '/account-hub',
        name: 'account-hub',
        builder: (context, state) => const AccountHubScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/premium-onboarding',
        redirect: (context, state) => '/sign-in',
      ),
      GoRoute(
        path: '/edit/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          final id = int.tryParse(idStr ?? '');
          if (id == null) {
            return const SizedBox.shrink();
          }
          return Consumer(
            builder: (context, ref, _) => FutureBuilder<Routine?>(
              future: ref.read(routineRepositoryProvider).getRoutineById(id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                final routine = snapshot.data;
                if (routine == null) {
                  return const Scaffold(
                    body: Center(child: Text('Routine not found')),
                  );
                }
                return RoutineComposerScreen.edit(routine: routine);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          if (idStr == null) return const SizedBox.shrink();
          final id = int.tryParse(idStr);
          if (id == null) return const SizedBox.shrink();
          return Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(routineSessionEntryProvider(id));
              return async.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator.adaptive()),
                ),
                error: (e, st) => const Scaffold(
                  body: Center(child: Text('Could not load routine')),
                ),
                data: (entry) {
                  if (entry == null) {
                    return const _RoutineUnavailableScreen();
                  }
                  return RoutinePlayerScreen(sessionId: entry.sessionId);
                },
              );
            },
          );
        },
      ),
    ],
    debugLogDiagnostics: !runtimeConfig.isProduction,
    initialLocation: '/',
  );
});

class _RoutineUnavailableScreen extends StatelessWidget {
  const _RoutineUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 42,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'That routine has been removed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'There is no active routine to resume.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => GoRouter.of(context).go('/'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = LocalDb();
  final appRuntimeConfig = appRuntimeConfigFromEnvironment();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const googleWebClientId = String.fromEnvironment(
    'SUPABASE_GOOGLE_WEB_CLIENT_ID',
  );
  const revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  const revenueCatIosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  const revenueCatEntitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: PebbleProductIds.personalPremium,
  );
  const stagingSupabaseHost = 'lxvrvrrxdjbrjwsxzppl.supabase.co';
  if (appRuntimeConfig.isProduction) {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Production builds require SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    if (Uri.tryParse(supabaseUrl)?.host == stagingSupabaseHost) {
      throw StateError(
        'Production builds cannot use the staging Supabase URL.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (!revenueCatAndroidApiKey.startsWith('goog_')) {
          throw StateError(
            'Android production builds require REVENUECAT_ANDROID_API_KEY starting with goog_.',
          );
        }
      case TargetPlatform.iOS:
        if (!revenueCatIosApiKey.startsWith('appl_')) {
          throw StateError(
            'iOS production builds require REVENUECAT_IOS_API_KEY starting with appl_.',
          );
        }
      default:
        if (revenueCatAndroidApiKey.isEmpty && revenueCatIosApiKey.isEmpty) {
          throw StateError(
            'Production builds require a RevenueCat API key for the target platform.',
          );
        }
    }
  }
  final supabaseConfig = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty
      ? SupabaseRuntimeConfig(
          enabled: true,
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          googleWebClientId: googleWebClientId.isEmpty
              ? null
              : googleWebClientId,
        )
      : const SupabaseRuntimeConfig.disabled();
  const revenueCatConfig = RevenueCatRuntimeConfig(
    androidApiKey: revenueCatAndroidApiKey,
    iosApiKey: revenueCatIosApiKey,
    entitlementId: revenueCatEntitlementId,
  );

  if (supabaseConfig.enabled) {
    await Supabase.initialize(
      url: supabaseConfig.url,
      anonKey: supabaseConfig.anonKey,
    );
  }

  // Initialize services - MUST be awaited before runApp
  await NotificationService().init();
  await _resyncEnabledReminderNotifications(db);

  // Handle notification taps: navigate to player
  NotificationService().selectedRoutineIdStream.listen((routineId) {
    final context = _rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      GoRouter.of(context).go('/play/$routineId');
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localDbProvider.overrideWithValue(db),
        appRuntimeConfigProvider.overrideWithValue(appRuntimeConfig),
        supabaseRuntimeConfigProvider.overrideWithValue(supabaseConfig),
        revenueCatRuntimeConfigProvider.overrideWithValue(revenueCatConfig),
      ],
      child: const PebbleApp(),
    ),
  );
}

class PebbleApp extends ConsumerStatefulWidget {
  const PebbleApp({super.key});

  @override
  ConsumerState<PebbleApp> createState() => _PebbleAppState();
}

class _PebbleAppState extends ConsumerState<PebbleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      ref.read(purchaseRepositoryProvider);
      await ref.read(routineRunRepositoryProvider).enforceRetentionPolicy();
      await ref.read(cloudSyncCoordinatorProvider).kick();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPurchasesAndCloudAccess());
      ref.read(routineRunRepositoryProvider).enforceRetentionPolicy();
      ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  Future<void> _refreshPurchasesAndCloudAccess() async {
    try {
      await ref.read(purchaseRepositoryProvider).syncPurchasesSilently();
      await ref
          .read(authControllerProvider.notifier)
          .refreshCloudAccessAfterEntitlementChange();
    } catch (_) {
      // The visible account state keeps the last known entitlement and error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(currentThemeDataProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Pebble Routines',
      theme: themeData,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = mq.textScaler.scale(1);
        final clampedScale = scale.clamp(1.0, 3.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(clampedScale)),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}
