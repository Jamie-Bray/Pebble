// lib/features/settings/ui/settings_screen.dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:pebble_routines/core/theme/theme_provider.dart";
import "package:pebble_routines/features/settings/ui/appearance_screen.dart";
import "package:pebble_routines/features/settings/ui/legal_about_screen.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";
import "package:go_router/go_router.dart";
import "package:pebble_routines/core/ui_kit/animated_background.dart";
import "package:pebble_routines/core/ui/adaptive_layout.dart";
import "package:pebble_routines/core/ui/zen_components.dart";
import "package:pebble_routines/core/ui/pebble_navigation.dart";
import "package:pebble_routines/features/settings/data/player_settings_provider.dart";

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final Animation<double> _ambient;

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _ambient = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeDataProvider);
    final playerSettings = ref.watch(playerSettingsControllerProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          PebbleDynamicBackground(
            theme: theme,
            ambientAnimation: _ambient,
            scrollOffset: _scrollOffset,
          ),
          AdaptiveContentWidth(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: ZenScreenHeader(
                    title: 'Settings',
                    subtitle: 'System configurations & preferences',
                  ),
                ),

                // Appearance & Subscription
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _FlowBlock(
                      title: 'Service',
                      children: [
                        _FlowTile(
                          icon: LucideIcons.bell,
                          title: 'Reminders',
                          subtitle: 'Manage all your routine reminders',
                          onTap: () {
                            context.push('/reminders');
                          },
                        ),
                        const _Hairline(),
                        _FlowSwitchTile(
                          icon: LucideIcons.focus,
                          title: 'Routine focus guide',
                          subtitle:
                              'Show a visual cue while you move through steps',
                          value: playerSettings.showVisualAnchor,
                          onChanged: (value) {
                            setState(() {
                              playerSettings.showVisualAnchor = value;
                            });
                          },
                        ),
                        const _Hairline(),
                        _FlowSwitchTile(
                          icon: LucideIcons.vibrate,
                          title: 'Buzz on step complete',
                          subtitle:
                              'A short vibration when you check off a step',
                          value: playerSettings.stepCompleteHaptic,
                          onChanged: (value) {
                            setState(() {
                              playerSettings.stepCompleteHaptic = value;
                            });
                          },
                        ),
                        const _Hairline(),
                        _FlowSwitchTile(
                          icon: LucideIcons.volume2,
                          title: 'Sound on step complete',
                          subtitle: 'A soft chime when you check off a step',
                          value: playerSettings.stepCompleteSound,
                          onChanged: (value) {
                            setState(() {
                              playerSettings.stepCompleteSound = value;
                            });
                          },
                        ),
                        const _Hairline(),
                        _FlowTile(
                          icon: Icons.palette_rounded,
                          title: 'Theme & colours',
                          subtitle: 'Choose a colour theme',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AppearanceScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // About group
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      40,
                    ), // More bottom padding for FAB clearance
                    child: _FlowBlock(
                      title: 'About',
                      children: [
                        _FlowTile(
                          icon: Icons.info_rounded,
                          title: 'About Pebble',
                          subtitle: 'Version 1.0.0 - Privacy, terms, deletion',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LegalAboutScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PebbleBackChrome(),
          ),
        ],
      ),
    );
  }
}

// ===== Flow style widgets matching AppearanceScreen vibe =====

class _FlowBlock extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FlowBlock({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.80),
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _FlowTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlowSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlowSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
