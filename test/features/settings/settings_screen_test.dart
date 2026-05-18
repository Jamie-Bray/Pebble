import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/settings/ui/appearance_screen.dart';
import 'package:pebble_routines/features/settings/ui/settings_screen.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings only shows wired user-visible controls', (
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

    expect(find.text('Theme & colours'), findsOneWidget);
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('About Pebble'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Visual anchor'), findsOneWidget);

    expect(find.text('Subscription Status (Dev Override)'), findsNothing);
    expect(find.text('Show Celebration'), findsNothing);
    expect(find.text('Sound effects'), findsNothing);
    expect(find.text('Support'), findsNothing);
  });

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

    expect(find.text('Visual anchor'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(prefs.getBool('showVisualAnchor'), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('theme picker shows curated sections for free users', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          subscriptionProvider.overrideWithValue(UserTier.personalFree),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const AppearanceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('INCLUDED'), findsOneWidget);
    expect(find.text('High Noon'), findsWidgets);
    expect(find.text('Amber Resin'), findsWidgets);
    expect(find.text('Pebble Dark'), findsNothing);
    expect(find.text('Matcha'), findsNothing);
    expect(
      find.text(
        'Current theme. Tap any card below to preview before switching.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('PREMIUM'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rose Quartz'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Colour Blind Safe'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paper & Ink'), findsOneWidget);
    expect(find.text('High Contrast Dark'), findsOneWidget);
    expect(find.text('Warm Sepia'), findsOneWidget);
    expect(find.text('Reduced Contrast'), findsOneWidget);
    expect(find.text('Colour Blind Safe'), findsOneWidget);
    expect(find.text('More accessibility options'), findsNothing);
  });

  testWidgets('theme cards open preview before applying', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          subscriptionProvider.overrideWithValue(UserTier.personalFree),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const AppearanceScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.text('PREMIUM'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Rose Quartz'));
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .ancestor(
            of: find.text('Rose Quartz'),
            matching: find.byType(InkWell),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Unlock Premium'), findsOneWidget);
    expect(find.text('Use this theme'), findsNothing);
    expect(
      find.text(
        'Preview available. Applying this theme requires Personal Premium.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Warm Sepia'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Warm Sepia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warm Sepia'));
    await tester.pumpAndSettle();

    expect(find.text('Use this theme'), findsOneWidget);
    expect(find.text('Unlock Premium'), findsNothing);
    expect(find.text('Warm tone for light sensitivity.'), findsOneWidget);
  });
}
