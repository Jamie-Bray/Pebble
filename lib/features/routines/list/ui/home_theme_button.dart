import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/tokens.dart';

/// The gold pair shares a Home shortcut; other palettes keep their selection.
class HomeThemeButton extends ConsumerWidget {
  const HomeThemeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentColorThemeProvider);
    if (current != ThemeId.ivoryAndGold && current != ThemeId.inkAndGold) {
      return const SizedBox.shrink();
    }
    final dark = current == ThemeId.inkAndGold;
    final next = dark ? ThemeId.ivoryAndGold : ThemeId.inkAndGold;
    return Padding(
      padding: const EdgeInsets.only(right: PebbleSpacing.xs),
      child: IconButton(
        key: const ValueKey('home_theme_toggle'),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: context.darkFoundation.textPrimary,
          side: BorderSide(
            color: context.darkFoundation.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        tooltip: 'Switch to ${ThemeMetadata.get(next).name}',
        icon: Icon(dark ? LucideIcons.sun : LucideIcons.moon, size: 22),
        onPressed: () => ref.read(themeProvider.notifier).setColorTheme(next),
      ),
    );
  }
}
