import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/routines/list/ui/home_theme_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> load(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(themeProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test(
    'new installs use ivory; previous theme indices keep their meaning',
    () async {
      final fresh = await load({});
      expect(fresh.read(currentColorThemeProvider), ThemeId.ivoryAndGold);
      // These are the indices shipped before the gold pair was appended.
      const shipped = [
        ThemeId.highNoon,
        ThemeId.nordicNight,
        ThemeId.paperAndInk,
        ThemeId.matcha,
        ThemeId.roseQuartz,
        ThemeId.deepGlacier,
        ThemeId.amberResin,
        ThemeId.terracotta,
        ThemeId.lavenderAsh,
        ThemeId.oatmealAndWalnut,
        ThemeId.midnightSlate,
        ThemeId.canopy,
        ThemeId.parchment,
        ThemeId.dusk,
        ThemeId.still,
        ThemeId.highContrastDark,
        ThemeId.warmSepia,
        ThemeId.reducedContrast,
        ThemeId.colourBlindSafe,
        ThemeId.softPink,
        ThemeId.sageMist,
        ThemeId.sandstone,
        ThemeId.tide,
        ThemeId.oliveGrove,
        ThemeId.heather,
        ThemeId.ember,
        ThemeId.seasonal,
      ];
      for (var i = 0; i < shipped.length; i++) {
        final saved = await load({'color_theme': i});
        expect(saved.read(currentColorThemeProvider), shipped[i]);
      }
    },
  );

  test('invalid stored indices safely fall back to ivory', () async {
    for (final index in [-1, ThemeId.values.length]) {
      final container = await load({'color_theme': index});
      expect(container.read(currentColorThemeProvider), ThemeId.ivoryAndGold);
    }
  });

  test('a choice during startup wins and survives a restart', () async {
    SharedPreferences.setMockInitialValues({
      'color_theme': ThemeId.highNoon.index,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(themeProvider.notifier)
        .setColorTheme(ThemeId.inkAndGold);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentColorThemeProvider), ThemeId.inkAndGold);
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(themeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restarted.read(currentColorThemeProvider), ThemeId.inkAndGold);
  });

  for (final id in [ThemeId.ivoryAndGold, ThemeId.inkAndGold]) {
    testWidgets('${id.name}: gold buttons and readable text on every surface', (
      tester,
    ) async {
      final theme = AppTheme.fromId(id);
      final f = theme.extension<PebbleDarkFoundation>()!;
      expect(ThemeMetadata.get(id).isPremium, isFalse);
      for (final bg in [f.bgBase, f.surfaceLow, f.surfaceHigh]) {
        expect(contrastRatio(f.textPrimary, bg), greaterThanOrEqualTo(7));
        expect(contrastRatio(f.textSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(theme.colorScheme.primary, bg),
          greaterThanOrEqualTo(4.5),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: PebbleButton.primary(label: 'Start', onPressed: () {}),
          ),
        ),
      );
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      final fill = style.backgroundColor!.resolve({})!;
      final label = style.foregroundColor!.resolve({})!;
      expect(fill, const Color(0xFFEDBF59));
      expect(label, const Color(0xFF192B3B));
      expect(contrastRatio(label, fill), greaterThanOrEqualTo(7));
    });
  }

  testWidgets(
    'Home toggle has a labelled 48px target and persists both choices',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(currentThemeDataProvider),
              home: const Scaffold(body: Center(child: HomeThemeButton())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('home_theme_toggle'));
      expect(tester.getSize(toggle).shortestSide, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      for (final (label, selected) in [
        ('Switch to Ink & Gold', ThemeId.inkAndGold),
        ('Switch to Ivory & Gold', ThemeId.ivoryAndGold),
      ]) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
        expect(container.read(currentColorThemeProvider), selected);
        expect(
          (await SharedPreferences.getInstance()).getInt('color_theme'),
          selected.index,
        );
      }
      await container
          .read(themeProvider.notifier)
          .setColorTheme(ThemeId.highContrastDark);
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      expect(
        container.read(currentColorThemeProvider),
        ThemeId.highContrastDark,
      );
    },
  );
}
