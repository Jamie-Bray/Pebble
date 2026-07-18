import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pebble_routines/core/theme/colors.dart';

/// Visual + value verification for the Sandstone signature theme.
///
/// The golden renders a faithful mini home-preview using the SAME theme tokens
/// production uses (`context.actionAccent`, `context.categoryAccentAt`), so the
/// palette in the image is exactly what ships. High Noon is rendered beside it
/// to prove single-accent themes are unchanged (grey badges, green action).
///
/// Building the real theme pulls in GoogleFonts, which cannot fetch in the test
/// sandbox; runtime fetching is disabled and the resulting font error is
/// consumed with `takeException` so it does not fail these colour checks.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Sandstone resolves to the intended multi-accent palette', (
    tester,
  ) async {
    final theme = AppTheme.fromId(ThemeId.sandstone);
    tester.takeException();
    final x = theme.extension<PebbleThemeX>()!;

    expect(theme.colorScheme.primary, const Color(0xFF3E5E45)); // forest
    expect(x.actionAccent, const Color(0xFFC4714A)); // terracotta
    expect(x.categoryAccents, const [
      Color(0xFF8DA174), // sage
      Color(0xFFC4714A), // terracotta
      Color(0xFFD9A85C), // tan
    ]);
    // Wrapping: a 4th step reuses the first colour.
    expect(x.categoryAccentAt(3), const Color(0xFF8DA174));
  });

  testWidgets('single-accent themes keep action == primary, one category', (
    tester,
  ) async {
    final theme = AppTheme.fromId(ThemeId.highNoon);
    tester.takeException();
    final x = theme.extension<PebbleThemeX>()!;
    expect(x.actionAccent, theme.colorScheme.primary);
    expect(x.categoryAccents.length, 1);
  });

  testWidgets('golden: Sandstone vs High Noon home preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemedPreview(id: ThemeId.sandstone),
                _ThemedPreview(id: ThemeId.highNoon),
              ],
            ),
          ),
        ),
      ),
    );
    tester.takeException(); // swallow the GoogleFonts fetch failure
    await tester.pump();

    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/sandstone_vs_highnoon.png'),
    );
  });
}

/// A compact stand-in for the home hero preview, built from the real theme so
/// the colours are identical to production.
class _ThemedPreview extends StatelessWidget {
  const _ThemedPreview({required this.id});

  final ThemeId id;

  static const _steps = [
    'Hair tools unplugged',
    'Stove and oven dials off',
    'Windows latched',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.fromId(id),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final foundation = context.darkFoundation;
          return Container(
            width: 360,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOUR NEXT RIPPLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: theme.colorScheme.primary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Everyday Departure Check',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    color: foundation.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _steps.length; i++) ...[
                  _badgeRow(context, i, _steps[i], foundation),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Start routine',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.actionAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.add, color: context.onActionAccent),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badgeRow(
    BuildContext context,
    int index,
    String label,
    PebbleDarkFoundation foundation,
  ) {
    final themeX = Theme.of(context).extension<PebbleThemeX>();
    final usesCategory = themeX != null && themeX.categoryAccents.length > 1;
    final categoryColor = usesCategory
        ? themeX.categoryAccentAt(index)
        : null;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  categoryColor ??
                  foundation.textPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: categoryColor != null
                    ? context.onActionAccent
                    : foundation.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: foundation.textMuted),
          ),
        ],
      ),
    );
  }
}
