import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.fromId(ThemeId.highNoon),
  home: Scaffold(
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  ),
);

void main() {
  testWidgets('primary is a full-width 56 capsule in DM Sans 600', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PebbleButton.primary(label: 'Start', onPressed: () => taps++)),
    );
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, 56);
    expect(size.width, 800 - 48);

    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
    final text = style.textStyle!.resolve({})!;
    expect(text.fontFamily, 'DMSans_600');
    expect(text.fontSize, 17);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  for (final id in ThemeId.values) {
    testWidgets('${id.name}: primary label is readable on its fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.fromId(id),
          home: Scaffold(
            body: PebbleButton.primary(label: 'Start', onPressed: () {}),
          ),
        ),
      );
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      final ratio = contrastRatio(
        style.foregroundColor!.resolve({})!,
        style.backgroundColor!.resolve({})!,
      );
      // ignore: avoid_print
      print('primary button ${id.name}: ${ratio.toStringAsFixed(2)}');
      // Reduced Contrast is deliberately soft and only promises 3:1.
      expect(
        ratio,
        greaterThanOrEqualTo(
          id == ThemeId.reducedContrast
              ? kMinLargeTextContrast
              : kMinBodyTextContrast,
        ),
      );
    });
  }

  testWidgets('busy shows a spinner, keeps the label and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PebbleButton.primary(
          label: 'Complete step',
          busy: true,
          onPressed: () => taps++,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Complete step'), findsOneWidget);
    await tester.tap(find.text('Complete step'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('secondary is tonal with no border; tertiary is text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            PebbleButton.secondary(
              label: 'Stay here',
              icon: LucideIcons.sparkles,
              onPressed: () {},
            ),
            PebbleButton.tertiary(label: 'Skip for now', onPressed: () {}),
            PebbleButton.compact(label: 'Play', onPressed: () {}),
          ],
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNWidgets(2));
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Stay here')).height,
      52,
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Skip for now')).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Play')).height,
      40,
    );
  });

  testWidgets('grows with 2x text instead of clipping', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        PebbleButton.primary(
          label: 'Continue with £29.99 per year after the trial',
          onPressed: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(56));
  });
}
