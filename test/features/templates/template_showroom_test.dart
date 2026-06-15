import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/onboarding/ui/onboarding_screen.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';
import 'package:pebble_routines/features/templates/domain/usecases/use_template_usecase.dart';
import 'package:pebble_routines/features/templates/ui/template_detail_screen.dart';
import 'package:pebble_routines/features/templates/ui/templates_gallery_screen.dart';
import 'package:pebble_routines/features/templates/ui/templates_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/premium_policy_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('template browse data', () {
    test('loads a reduced launch catalog from assets', () async {
      final templates = await TemplateRepository().loadTemplates();

      expect(templates, hasLength(12));
      expect(
        templates.map((Template template) => template.category).toSet(),
        equals(<String>{
          'Leaving & Locking Up',
          'Daily Care',
          'Work & Away',
        }),
      );
      expect(
        templates.map((Template template) => template.title).toList(),
        containsAll(<String>[
          'Everyday Departure Check',
          'Bedtime House Check',
          'Car Lock & Parking Check',
          'Big Trip Home Shutdown',
          'Medication Check',
          'Morning Pet Routine',
          'Essential School Morning Run',
          'Toddler Essentials Bag',
          'Hotel Checkout Sweep',
          'Office Switch-Off',
          'Gym & Sports Prep',
          'House Sitter Handover',
        ]),
      );
      expect(
        templates.where((Template template) => template.isFeatured),
        isEmpty,
      );

      final stepCounts = templates
          .map((Template template) => template.stepCount)
          .toSet();
      expect(stepCounts, equals(<int>{8, 9, 10}));
    });

    test('groups templates in the plain browse order', () {
      final grouped = groupTemplatesByCategory(
        sortTemplatesForBrowse(_sampleTemplates),
      );

      expect(
        grouped.keys,
        orderedEquals(<String>[
          'Leaving & Locking Up',
          'Daily Care',
          'Work & Away',
        ]),
      );
      expect(
        grouped['Daily Care']!.map((Template template) => template.title),
        orderedEquals(<String>['Morning Pet Routine']),
      );
    });

    test(
      'use-template use case creates a real routine from a template',
      () async {
        final repository = _FakeRoutineRepository();
        final template = _sampleTemplates.first;

        final routine = await UseTemplateUseCase(repository).call(template);

        expect(repository.savedRoutines, hasLength(1));
        expect(routine.title, template.title);
        expect(routine.id, isNot(0));

        final decodedSteps = (jsonDecode(routine.stepsJson) as List<dynamic>)
            .map(
              (dynamic item) =>
                  RoutineStep.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false);
        expect(decodedSteps.map(_stepLabel), orderedEquals(template.steps));
      },
    );

    test('photo markers are parsed into photo requirements', () async {
      final repository = _FakeRoutineRepository();
      final template = _sampleTemplates.first.copyWith(
        steps: <String>[
          'Lock the door and test the handle. (Take a photo of the lock)',
          'Check the hob and oven are off.',
        ],
      );

      expect(template.photoRequiredCount, 1);
      expect(Template.stepRequiresPhoto(template.steps.first), isTrue);
      expect(
        Template.cleanStepLabel(template.steps.first),
        'Lock the door and test the handle.',
      );

      final routine = await UseTemplateUseCase(repository).call(template);
      final decodedSteps = (jsonDecode(routine.stepsJson) as List<dynamic>)
          .map(
            (dynamic item) =>
                RoutineStep.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);

      expect(
        _stepLabel(decodedSteps.first),
        'Lock the door and test the handle.',
      );
      expect(_stepRequiresPhoto(decodedSteps.first), isTrue);
      expect(_stepRequiresPhoto(decodedSteps.last), isFalse);
    });
  });

  group('template browse widgets', () {
    testWidgets('gallery is a grouped list without catalogue chrome', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
              useMaterial3: true,
            ),
            home: const TemplatesGalleryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Templates'), findsOneWidget);
      expect(
        find.text(
          'Add a ready-made checklist, then personalise the steps any way you want.',
        ),
        findsOneWidget,
      );
      expect(find.text('LEAVING & LOCKING UP'), findsOneWidget);
      expect(find.text('DAILY CARE'), findsOneWidget);
      expect(find.text('WORK & AWAY'), findsOneWidget);
      expect(find.text('Everyday Departure Check'), findsOneWidget);
      expect(find.text('5 checks'), findsNothing);
      expect(find.text('5 steps'), findsNWidgets(3));
      expect(find.text('1 photo check'), findsOneWidget);
      expect(find.text('Featured'), findsNothing);
      expect(find.textContaining('Search'), findsNothing);
      expect(find.textContaining('Preview first'), findsNothing);
      expect(find.textContaining('Then customize'), findsNothing);
    });

    testWidgets('onboarding browse templates does not complete onboarding', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/onboarding',
            builder: (BuildContext context, GoRouterState state) {
              return const OnboardingScreen(initialPage: 2);
            },
          ),
          GoRoute(
            path: '/templates',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: Text(
                  state.uri.queryParameters['from'] == 'onboarding'
                      ? 'Templates from onboarding'
                      : 'Templates without onboarding',
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            theme: AppTheme.fromId(ThemeId.amberResin),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Browse all templates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse all templates'));
      await tester.pumpAndSettle();

      expect(prefs.getBool('has_completed_onboarding'), isFalse);
      expect(find.text('Templates from onboarding'), findsOneWidget);
    });

    testWidgets(
      'gallery back returns to onboarding when opened from onboarding',
      (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/templates?from=onboarding',
          routes: <RouteBase>[
            GoRoute(
              path: '/onboarding',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(body: Text('Onboarding templates'));
              },
            ),
            GoRoute(
              path: '/templates',
              builder: (BuildContext context, GoRouterState state) {
                return TemplatesGalleryScreen(
                  fromOnboarding:
                      state.uri.queryParameters['from'] == 'onboarding',
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              templateRepositoryProvider.overrideWithValue(
                _FakeTemplateRepository(_sampleTemplates),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.fromId(ThemeId.amberResin),
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(LucideIcons.chevronLeft).first);
        await tester.pumpAndSettle();

        expect(find.text('Onboarding templates'), findsOneWidget);
      },
    );

    testWidgets('gallery preserves onboarding source when opening details', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/templates?from=onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/templates',
            builder: (BuildContext context, GoRouterState state) {
              return TemplatesGalleryScreen(
                fromOnboarding:
                    state.uri.queryParameters['from'] == 'onboarding',
              );
            },
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: Text(
                  state.uri.queryParameters['from'] == 'onboarding'
                      ? 'Detail from onboarding'
                      : 'Detail without onboarding',
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.fromId(ThemeId.amberResin),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyday Departure Check'));
      await tester.pumpAndSettle();

      expect(find.text('Detail from onboarding'), findsOneWidget);
    });

    testWidgets('gallery uses the selected theme accent for template groups', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.fromId(ThemeId.deepGlacier);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: const TemplatesGalleryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final shieldIcon = tester.widget<Icon>(
        find.byIcon(LucideIcons.shieldCheck).first,
      );
      expect(shieldIcon.color, theme.colorScheme.primary);
    });

    testWidgets('detail back returns to onboarding template gallery', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        initialLocation:
            '/templates/tpl_anxiety_free_departure?from=onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/templates',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Text('Onboarding gallery'));
            },
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (BuildContext context, GoRouterState state) {
              return TemplateDetailScreen(
                templateId: state.pathParameters['id']!,
                fromOnboarding:
                    state.uri.queryParameters['from'] == 'onboarding',
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
            routineListProvider.overrideWith(
              (ref) => Stream<List<Routine>>.value(const <Routine>[]),
            ),
            subscriptionProvider.overrideWithValue(UserTier.personalPremium),
            premiumFeaturePolicyProvider.overrideWithValue(
              premiumFeaturePolicyForTier(UserTier.personalPremium),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.fromId(ThemeId.amberResin),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.chevronLeft).first);
      await tester.pumpAndSettle();

      expect(find.text('Onboarding gallery'), findsOneWidget);
    });

    testWidgets('using a template from onboarding completes onboarding', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final routineRepository = _FakeRoutineRepository();

      final router = GoRouter(
        initialLocation:
            '/templates/tpl_anxiety_free_departure?from=onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return Consumer(
                builder: (context, ref, child) {
                  final highlight = ref.watch(homeRoutineHighlightProvider);
                  return Scaffold(body: Text(highlight?.message ?? 'Home'));
                },
              );
            },
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (BuildContext context, GoRouterState state) {
              return TemplateDetailScreen(
                templateId: state.pathParameters['id']!,
                fromOnboarding:
                    state.uri.queryParameters['from'] == 'onboarding',
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
            routineRepositoryProvider.overrideWithValue(routineRepository),
            routineListProvider.overrideWith(
              (ref) => Stream<List<Routine>>.value(const <Routine>[]),
            ),
            subscriptionProvider.overrideWithValue(UserTier.personalPremium),
            premiumFeaturePolicyProvider.overrideWithValue(
              premiumFeaturePolicyForTier(UserTier.personalPremium),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.fromId(ThemeId.amberResin),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Add this template'));
      await tester.pumpAndSettle();

      expect(prefs.getBool('has_completed_onboarding'), isTrue);
      expect(find.text('Everyday Departure Check is ready'), findsOneWidget);
      expect(routineRepository.savedRoutines, hasLength(1));
    });

    testWidgets('detail screen previews steps and hands off to Home', (
      WidgetTester tester,
    ) async {
      final routineRepository = _FakeRoutineRepository();

      final router = GoRouter(
        initialLocation: '/templates/tpl_anxiety_free_departure',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return Consumer(
                builder: (context, ref, child) {
                  final highlight = ref.watch(homeRoutineHighlightProvider);
                  return Scaffold(body: Text(highlight?.message ?? 'Home'));
                },
              );
            },
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (BuildContext context, GoRouterState state) {
              return TemplateDetailScreen(
                templateId: state.pathParameters['id']!,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            templateRepositoryProvider.overrideWithValue(
              _FakeTemplateRepository(_sampleTemplates),
            ),
            routineRepositoryProvider.overrideWithValue(routineRepository),
            routineListProvider.overrideWith(
              (ref) => Stream<List<Routine>>.value(const <Routine>[]),
            ),
            subscriptionProvider.overrideWithValue(UserTier.personalPremium),
            premiumFeaturePolicyProvider.overrideWithValue(
              premiumFeaturePolicyForTier(UserTier.personalPremium),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              useMaterial3: true,
            ),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Everyday Departure Check'), findsOneWidget);
      expect(
        find.text('Check the common leaving-home items before you go.'),
        findsOneWidget,
      );
      expect(find.text('Good for'), findsNothing);
      expect(find.textContaining('Preview first'), findsNothing);
      expect(find.text('5 steps'), findsOneWidget);
      expect(find.text('Add this template'), findsOneWidget);
      expect(
        find.text(
          'Add it to your routines first, then personalise the steps any way you want.',
        ),
        findsOneWidget,
      );
      expect(find.text('Check the hob and oven are off.'), findsOneWidget);

      await tester.tap(find.text('Add this template'));
      await tester.pumpAndSettle();

      expect(routineRepository.savedRoutines, hasLength(1));
      expect(
        routineRepository.savedRoutines.single.title,
        'Everyday Departure Check',
      );
      expect(find.text('Everyday Departure Check is ready'), findsOneWidget);
    });
  });
}

String _stepLabel(RoutineStep step) {
  return step.maybeWhen(
    check:
        (
          String label,
          bool requiresPhoto,
          int photoCount,
          String? photoPrompt,
          bool allowSkip,
          bool allowGallery,
          StepGuidanceAudio? guidanceAudio,
        ) => label,
    orElse: () => '',
  );
}

bool _stepRequiresPhoto(RoutineStep step) {
  return step.maybeWhen(
    check:
        (
          String label,
          bool requiresPhoto,
          int photoCount,
          String? photoPrompt,
          bool allowSkip,
          bool allowGallery,
          StepGuidanceAudio? guidanceAudio,
        ) => requiresPhoto,
    orElse: () => false,
  );
}

class _FakeTemplateRepository extends TemplateRepository {
  _FakeTemplateRepository(this.templates);

  final List<Template> templates;

  @override
  Future<List<Template>> loadTemplates() async {
    return sortTemplatesForBrowse(templates);
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  final List<Routine> savedRoutines = <Routine>[];

  @override
  Stream<List<Routine>> watchRoutines() =>
      Stream<List<Routine>>.value(savedRoutines);

  @override
  Future<void> normalizeLegacyRoutineIcons() async {}

  @override
  Future<void> saveRoutine(Routine routine) async {
    savedRoutines.add(routine);
  }

  @override
  Future<void> deleteRoutine(int id) async {}

  @override
  Future<void> deleteRoutineReminder(RoutineReminder reminder) async {}

  @override
  Future<void> deleteRoutineRemindersForRoutine(int routineId) async {}

  @override
  Future<void> deleteAllRoutineReminders() async {}

  @override
  Future<Routine> duplicateRoutine(int id) {
    throw UnimplementedError();
  }

  @override
  Future<Routine?> getRoutineById(int id) async {
    for (final routine in savedRoutines) {
      if (routine.id == id) {
        return routine;
      }
    }
    return null;
  }

  @override
  Future<(int?, String?)> getRoutineReminder(int id) async => (null, null);

  @override
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {}

  @override
  Future<void> updateRoutinePinned(int id, bool isPinned) async {}

  @override
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async {
    return true;
  }

  @override
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  }) async {}

  @override
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId) {
    return Stream<RoutineRun?>.value(null);
  }
}

const List<Template> _sampleTemplates = <Template>[
  Template(
    id: 'tpl_anxiety_free_departure',
    title: 'Everyday Departure Check',
    description: 'Check the common leaving-home items before you go.',
    category: 'Leaving & Locking Up',
    goodFor: 'Check the common leaving-home items before you go.',
    searchTerms: <String>['lock up', 'windows'],
    steps: <String>[
      'Check the hob and oven are off.',
      'Close the windows you opened today.',
      'Turn off the lights you do not want left on.',
      'Pick up keys, phone, and wallet.',
      'Lock the door and test the handle.',
    ],
  ),
  Template(
    id: 'tpl_hotel_checkout',
    title: 'Hotel Checkout Sweep',
    description: 'Check the room essentials before you leave.',
    category: 'Work & Away',
    goodFor: 'Check the room essentials before you leave.',
    searchTerms: <String>['airport', 'passport'],
    steps: <String>[
      'Check passport or ID is with you.',
      'Check wallet, phone, and charger are packed.',
      'Make boarding pass or booking details easy to reach.',
      'Zip and count your bags.',
      'Lock the door and put keys in their travel place. (Take a photo of the room)',
    ],
  ),
  Template(
    id: 'tpl_morning_pet_routine',
    title: 'Morning Pet Routine',
    description: 'Check food, water, doors, and gates before you leave.',
    category: 'Daily Care',
    goodFor: 'Check food, water, doors, and gates before you leave.',
    searchTerms: <String>['pet', 'dog', 'cat'],
    steps: <String>[
      'Refresh the water bowl.',
      'Put out the next meal or confirm when it will be given.',
      'Give a toilet break if needed.',
      'Leave bed, toy, or comfort item ready.',
      'Close doors, gates, or bins your pet should not reach.',
    ],
  ),
];
