import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_list_screen.dart';
import 'package:pebble_routines/features/history/ui/styled_history_screen.dart';
import 'package:pebble_routines/core/ui/zen_components.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_creation_choice_sheet.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/background_pattern.dart';
import 'package:pebble_routines/features/settings/data/wallpaper_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navIndexProvider);
    final currentTheme = ref.watch(currentColorThemeProvider);
    final hideChrome = ref
        .watch(routineListProvider)
        .maybeWhen(data: (l) => l.isEmpty, orElse: () => false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        final route = ModalRoute.of(context);
        if (didPop || route?.isCurrent != true) {
          return;
        }

        if (idx != 0) {
          ref.read(navIndexProvider.notifier).state = 0;
          return;
        }

        await SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackgroundPattern(
                type: ref.watch(wallpaperProvider),
                color: Theme.of(context).colorScheme.onSurface,
                opacity: 0.08,
              ),
            ),
            IndexedStack(
              index: idx,
              children: const [RoutineListScreen(), StyledHistoryScreen()],
            ),
          ],
        ),
        bottomNavigationBar: hideChrome
            ? null
            : _buildFloatingPillBar(idx, currentTheme),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: null,
      ),
    );
  }

  Widget _buildFloatingPillBar(int selectedIndex, ThemeId currentTheme) {
    final foundation = context.darkFoundation;
    final isDusk =
        Theme.of(context).brightness == Brightness.dark ||
        (Theme.of(context).extension<PebbleThemeX>()?.gradient != null);

    final borderColor = isDusk
        ? foundation.borderSubtle.withValues(alpha: 0.8)
        : Colors.black.withValues(alpha: 0.05);
    final bgColor = isDusk
        ? foundation.surfaceLow.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.7);

    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            padding: const EdgeInsets.fromLTRB(34, 7, 34, 7),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(top: BorderSide(color: borderColor, width: 1.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  icon: selectedIndex == 0
                      ? LucideIcons.house
                      : LucideIcons.house,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () {
                    ref.read(navIndexProvider.notifier).state = 0;
                  },
                ),
                _buildCreateAnchor(),
                _buildNavItem(
                  icon: selectedIndex == 1
                      ? LucideIcons.history
                      : LucideIcons.history,
                  label: 'History',
                  isSelected: selectedIndex == 1,
                  onTap: () {
                    ref.read(navIndexProvider.notifier).state = 1;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAnchor() {
    return ZenBounceButton(
      onTap: () {
        openRoutineCreationChoice(context, ref);
      },
      child: SizedBox(
        width: 68,
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Color.lerp(
                        Theme.of(context).colorScheme.primary,
                        Colors.black,
                        0.12,
                      ) ??
                      Theme.of(context).colorScheme.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.plus,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
