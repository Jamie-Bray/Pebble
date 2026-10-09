import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/config/app_version.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/settings/ui/appearance_screen.dart';
import 'package:pebble_routines/features/settings/ui/settings_screen.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/premium_policy_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings only shows wired user-visible controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appVersionProvider.overrideWith((ref) => '2.3.4+56'),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Every switch is announced with its row title.
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Manage all your routine reminders'), findsOneWidget);
    expect(find.text('Routine focus guide'), findsOneWidget);
    expect(find.text('Buzz on step complete'), findsOneWidget);
    expect(find.text('Sound on step complete'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('About Pebble'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Theme & colours'), findsOneWidget);
    expect(find.text('About Pebble'), findsOneWidget);
    // The version comes from the installed build, not a fixed string.
    expect(
      find.text('Version 2.3.4 · Privacy, terms, deletion'),
      findsOneWidget,
    );

    // Account, backup and support are reachable from Settings too.
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Subscription Status (Dev Override)'), findsNothing);
    expect(find.text('Show Celebration'), findsNothing);
    expect(find.text('Sound effects'), findsNothing);
    expect(find.text('Support'), findsNothing);
  });

  for (final scale in const [1.0, 2.0]) {
    testWidgets('settings title clears the back button under an iPhone notch '
        '(text ${scale}x)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
      tester.view.viewPadding = const FakeViewPadding(
        top: 47 * 3,
        bottom: 34 * 3,
      );
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      final back = tester.getRect(find.bySemanticsLabel('Back').first);
      final title = tester.getRect(find.text('Settings'));
      expect(back.top, greaterThanOrEqualTo(47));
      expect(title.top, greaterThanOrEqualTo(back.bottom));
    });
  }

  testWidgets('visual anchor setting defaults on and persists changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Routine focus guide'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(prefs.getBool('showVisualAnchor'), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
  });

  testWidgets('step-complete feedback toggles default off and persist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Switch order: focus guide, buzz, sound.
    final switches = find.byType(Switch);
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(2)).value, isFalse);

    await tester.tap(switches.at(1));
    await tester.pump();
    await tester.tap(switches.at(2));
    await tester.pump(const Duration(milliseconds: 100));

    expect(prefs.getBool('stepCompleteHaptic'), isTrue);
    expect(prefs.getBool('stepCompleteSound'), isTrue);
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          subscriptionProvider.overrideWithValue(UserTier.personalFree),
          premiumFeaturePolicyProvider.overrideWithValue(
            premiumFeaturePolicyForTier(UserTier.personalFree),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapPebble(WidgetTester tester, ThemeId id) async {
    final pebble = find.byKey(ValueKey('theme_pebble_${id.name}'));
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('appearance_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(pebble, 240, scrollable: scrollable);
    // Centre it, clear of the choose bar pinned to the bottom of the screen.
    await Scrollable.ensureVisible(tester.element(pebble), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(pebble);
    await tester.pumpAndSettle();
  }

  testWidgets('theme picker shows every theme as a pebble for free users', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(find.text('Themes and colours'), findsOneWidget);
    expect(
      find.text('Swipe to look around. Nothing changes until you choose.'),
      findsOneWidget,
    );
    expect(find.text('FREE', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance_gallery')), findsOneWidget);
    // Every theme has a pebble, older Premium ones included.
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('appearance_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final premium = ThemeMetadata.byCategory(ThemePickerCategory.premium);
    final inPageOrder = <ThemeMetadata>[
      ...ThemeMetadata.byCategory(ThemePickerCategory.included),
      ...premium.where((t) => t.isVisibleOnMainPicker),
      ...premium.where((t) => t.showInMoreOptionsOnly),
      ...ThemeMetadata.byCategory(ThemePickerCategory.accessibility),
    ].map((t) => t.id).toList();
    expect(inPageOrder.toSet(), ThemeId.values.toSet());
    for (final id in inPageOrder) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('theme_pebble_${id.name}')),
        200,
        scrollable: scrollable,
      );
    }
  });

  testWidgets('tapping a pebble previews it before anything is applied', (
    tester,
  ) async {
    await pumpPicker(tester);

    // The theme in use is shown first, and its button is quiet.
    expect(find.text('High Noon is on'), findsOneWidget);

    await tapPebble(tester, ThemeId.roseQuartz);
    expect(find.text('See Personal Premium'), findsOneWidget);
    expect(
      find.text('Rose Quartz comes with Personal Premium. Looking is free.'),
      findsOneWidget,
    );

    await tapPebble(tester, ThemeId.warmSepia);
    expect(find.text('Use Warm Sepia'), findsOneWidget);
    expect(find.text('See Personal Premium'), findsNothing);
    expect(
      find.text('Warm tint for light sensitivity.', skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Use Warm Sepia'));
    await tester.pumpAndSettle();
    expect(find.text('Warm Sepia is on'), findsOneWidget);
  });
}
