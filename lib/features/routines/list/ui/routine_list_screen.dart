import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_style_picker_sheet.dart';
import 'package:pebble_routines/features/routines/creator/ui/reorder_steps_screen.dart';
import 'package:pebble_routines/core/ui/zen_error_view.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_management_provider.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/settings/data/haptics_service.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/history/ui/styled_history_screen.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/ui/pebble_confirmation_sheet.dart';
import 'package:pebble_routines/features/account_backup/ui/account_backup_header_action.dart';
import 'package:pebble_routines/core/database/routine_step.dart';

import 'package:pebble_routines/core/ui/zen_components.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';

class RoutineListScreen extends ConsumerStatefulWidget {
  const RoutineListScreen({super.key});

  @override
  ConsumerState<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends ConsumerState<RoutineListScreen>
    with TickerProviderStateMixin {
  static const double _routineSheetRowHeight = 76;
  static const double _bottomNavHeight = 70;
  static const double _routineSheetHeaderHeight = 104;

  // Breathing animation controllers
  late AnimationController _breathingController;
  final ValueNotifier<double> _routineSheetExtent = ValueNotifier<double>(0);

  // Breathing animation
  late Animation<double> _breathingScale;
  int? _focusedRoutineId;
  double _minSheetExtent = 0;
  double _maxSheetExtent = 0;

  Future<void> _openStyleSheet(Routine routine, ThemeData themeData) async {
    final cs = themeData.colorScheme;
    final hasPremiumStyleAccess =
        ref.read(subscriptionProvider) != UserTier.personalFree;
    if (!hasPremiumStyleAccess) {
      _showPremiumStyleUpsell(routine, themeData);
      return;
    }

    final swatches = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
    ];

    await showModalBottomSheet<RoutineStylePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineStylePickerSheet.asScaffold(
        context: ctx,
        initialIconKey: routine.emoji ?? RoutineIconCatalog.defaultKey,
        initialColor: (routine.colorHex != null && routine.colorHex != 0)
            ? Color(routine.colorHex!)
            : themeData.colorScheme.primary,
        iconChoices: RoutineIconCatalog.all,
        swatches: swatches,
        hasPremiumIconAccess: hasPremiumStyleAccess,
        title: 'Style Studio',
      ),
    ).then((result) async {
      if (result != null && mounted) {
        final management = ref.read(routineManagementProvider);
        await management.updateRoutineAppearance(
          id: routine.id,
          iconKey: RoutineIconCatalog.sanitizeForStorage(
            result.iconKey,
            hasPremiumAccess: hasPremiumStyleAccess,
          ),
          colorHex: result.colorHex,
        );
      }
    });
  }

  void _showPremiumStyleUpsell(Routine routine, ThemeData themeData) {
    final accent = _routineAccentColor(routine, themeData, 0);
    final icon = RoutineIconCatalog.resolve(routine.emoji).icon;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.surface,
                Color.lerp(cs.surface, accent, 0.12) ?? cs.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: 0.24)),
            ),
          ),
          padding: const EdgeInsets.only(
            top: 8,
            left: 24,
            right: 24,
            bottom: 32,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 30, color: accent),
                      Positioned(
                        right: 13,
                        top: 13,
                        child: Icon(LucideIcons.lock, size: 14, color: accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock Routine Style',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Icons, colors and routine personality are included with Personal Premium.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor:
                        ThemeData.estimateBrightnessForColor(accent) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    HapticsService().heavyImpact();
                    Navigator.pop(ctx);
                    context.push(
                      premiumRoute(source: PremiumEntrySource.backup),
                    );
                  },
                  child: const Text(
                    'See Personal Premium',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Breathing animation - 4 second cycle
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _breathingScale = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Start animations
    _breathingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _routineSheetExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineListAsync = ref.watch(routineListProvider);
    final themeData = ref.watch(currentThemeDataProvider);
    final currentTheme = ref.watch(currentColorThemeProvider);

    return routineListAsync.when(
      loading: () => _buildLoadingScreen(themeData),
      error: (e, st) => _buildErrorScreen(e, themeData),
      data: (routines) {
        if (routines.isEmpty) {
          return _buildEmptyHome(currentTheme);
        }

        return _buildZenSanctuary(routines, themeData, currentTheme);
      },
    );
  }

  Widget _buildLoadingScreen(ThemeData themeData) {
    final foundation = context.darkFoundation;
    final cs = themeData.colorScheme;

    return Container(
      decoration: BoxDecoration(color: foundation.bgBase),
      child: Center(
        child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorScreen(dynamic error, ThemeData themeData) {
    final foundation = context.darkFoundation;

    return Container(
      decoration: BoxDecoration(color: foundation.bgBase),
      child: ZenErrorView(message: 'Error loading routines: $error'),
    );
  }

  Widget _buildEmptyHome(ThemeId currentTheme) {
    final foundation = context.darkFoundation;

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: Container(
        decoration: BoxDecoration(color: foundation.bgBase),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) => CustomPaint(
                  painter: AmbientParticlesPainter(
                    _breathingController.value,
                    currentTheme == ThemeId.nordicNight,
                  ),
                ),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const ZenHeader(extraActions: [AccountBackupHeaderAction()]),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            'Start with one routine.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.06,
                              color: foundation.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A calm checklist for the moments you repeat.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.36,
                              color: foundation.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openNewRoutine,
                              icon: const Icon(LucideIcons.plus, size: 18),
                              label: const Text('Create routine'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => context.push('/templates'),
                              icon: const Icon(
                                LucideIcons.layoutTemplate,
                                size: 17,
                              ),
                              label: const Text('Use template'),
                              style: TextButton.styleFrom(
                                foregroundColor: foundation.textSecondary,
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZenSanctuary(
    List<Routine> routines,
    ThemeData themeData,
    ThemeId currentTheme,
  ) {
    final foundation = context.darkFoundation;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: foundation.bgBase,
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 1.15,
            colors: [
              foundation.surfaceHigh.withValues(alpha: 0.98),
              foundation.bgBase,
            ],
            stops: const [0, 0.68],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) => CustomPaint(
                  painter: AmbientParticlesPainter(
                    _breathingController.value,
                    currentTheme == ThemeId.nordicNight,
                  ),
                ),
              ),
            ),
            _buildMasterpieceHome(routines, themeData),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterpieceHome(List<Routine> routines, ThemeData themeData) {
    final highlight = ref.watch(homeRoutineHighlightProvider);
    final highlightedRoutine = highlight == null
        ? null
        : routines
              .where((routine) => routine.id == highlight.routineId)
              .firstOrNull;
    final focusedRoutine = _focusedRoutineId == null
        ? null
        : routines
              .where((routine) => routine.id == _focusedRoutineId)
              .firstOrNull;

    final activeSessionsAsync = ref.watch(activeRoutineSessionsProvider);
    return activeSessionsAsync.when(
      loading: () => _buildRoutineHomeFrame(
        routines: routines,
        themeData: themeData,
        spotlightRoutine: _spotlightRoutine(
          routines,
          highlightedRoutine,
          focusedRoutine,
        ),
        highlight: highlight,
        resumeSession: null,
      ),
      error: (_, __) => _buildRoutineHomeFrame(
        routines: routines,
        themeData: themeData,
        spotlightRoutine: _spotlightRoutine(
          routines,
          highlightedRoutine,
          focusedRoutine,
        ),
        highlight: highlight,
        resumeSession: null,
      ),
      data: (sessions) => _buildRoutineHomeFrame(
        routines: routines,
        themeData: themeData,
        spotlightRoutine: _spotlightRoutine(
          routines,
          highlightedRoutine,
          focusedRoutine,
        ),
        highlight: highlight,
        resumeSession: sessions.isEmpty ? null : sessions.first,
      ),
    );
  }

  Routine? _spotlightRoutine(
    List<Routine> routines,
    Routine? highlightedRoutine,
    Routine? focusedRoutine,
  ) {
    final runs = ref.watch(routineHistoryVmProvider).valueOrNull ?? const [];
    return focusedRoutine ??
        highlightedRoutine ??
        selectHomeSpotlightRoutine(routines: routines, runs: runs);
  }

  double _collapsedSheetExtent({
    required double hostHeight,
    required double bottomSafe,
  }) {
    return 0.001;
  }

  double _expandedSheetExtent({
    required double hostHeight,
    required int visibleRoutineCount,
    required double bottomSafe,
  }) {
    final visibleRows = visibleRoutineCount >= 4
        ? 3.4
        : visibleRoutineCount.toDouble().clamp(1.0, 4.0);
    final expandedHeight =
        _routineSheetHeaderHeight +
        (visibleRows * _routineSheetRowHeight) +
        _bottomNavHeight +
        bottomSafe +
        18;
    return (expandedHeight / hostHeight).clamp(0.48, 0.68);
  }

  Future<void> _animateRoutineSheetTo(double extent) async {
    _routineSheetExtent.value = extent.clamp(_minSheetExtent, _maxSheetExtent);
  }

  void _handleRoutineSheetDismissDragUpdate(
    DragUpdateDetails details,
    double hostHeight,
  ) {
    if (hostHeight <= 0 ||
        _routineSheetExtent.value <= _minSheetExtent + 0.01) {
      return;
    }

    final delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      return;
    }

    final currentExtent = _routineSheetExtent.value.clamp(
      _minSheetExtent,
      _maxSheetExtent,
    );
    _routineSheetExtent.value = (currentExtent - (delta / hostHeight)).clamp(
      _minSheetExtent,
      _maxSheetExtent,
    );
  }

  void _handleRoutineSheetDismissDragEnd(DragEndDetails details) {
    if (_routineSheetExtent.value <= _minSheetExtent + 0.01) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final currentExtent = _routineSheetExtent.value.clamp(
      _minSheetExtent,
      _maxSheetExtent,
    );
    final shouldClose =
        velocity > 140 || currentExtent < (_maxSheetExtent - 0.04);

    _animateRoutineSheetTo(shouldClose ? _minSheetExtent : _maxSheetExtent);
  }

  Widget _buildRoutineHomeFrame({
    required List<Routine> routines,
    required ThemeData themeData,
    required Routine? spotlightRoutine,
    required HomeRoutineHighlight? highlight,
    required RoutineSessionResumeSummary? resumeSession,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final bottomSafe = mediaQuery.padding.bottom >= _bottomNavHeight
            ? mediaQuery.padding.bottom - _bottomNavHeight
            : mediaQuery.padding.bottom;
        final visibleRoutines = routines;
        final visibleRoutineCount = visibleRoutines.isEmpty
            ? 1
            : visibleRoutines.length.clamp(1, 4);

        final minExtent = _collapsedSheetExtent(
          hostHeight: constraints.maxHeight,
          bottomSafe: bottomSafe,
        );
        final maxExtent = _expandedSheetExtent(
          hostHeight: constraints.maxHeight,
          visibleRoutineCount: visibleRoutineCount,
          bottomSafe: bottomSafe,
        );

        _minSheetExtent = minExtent;
        _maxSheetExtent = maxExtent;
        // Hero padding: bottom nav + button + clear separation
        final heroBottomPadding = _bottomNavHeight + bottomSafe + 82;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final currentSize = _routineSheetExtent.value;
          final clampedSize = currentSize.clamp(minExtent, maxExtent);
          if ((clampedSize - currentSize).abs() > 0.001) {
            _routineSheetExtent.value = clampedSize;
          }
        });

        return Stack(
          children: [
            Column(
              children: [
                _buildHomeHeader(themeData),
                if (resumeSession != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                    child: _buildResumeCard(themeData, resumeSession),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(30, 0, 30, heroBottomPadding),
                    child: spotlightRoutine == null
                        ? const SizedBox.shrink()
                        : _buildHeroFocus(
                            themeData,
                            spotlightRoutine,
                            highlight: highlight,
                            availableHeight:
                                constraints.maxHeight - heroBottomPadding,
                          ),
                  ),
                ),
              ],
            ),
            _buildLibraryOverlayButton(themeData, bottomSafe),
            ValueListenableBuilder<double>(
              valueListenable: _routineSheetExtent,
              builder: (context, extent, _) {
                final currentExtent = extent == 0 ? minExtent : extent;
                if (currentExtent <= minExtent + 0.01) {
                  return const SizedBox.shrink();
                }

                return Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      HapticsService().lightImpact();
                      _animateRoutineSheetTo(minExtent);
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder<double>(
              valueListenable: _routineSheetExtent,
              builder: (context, extent, _) {
                final currentExtent = extent == 0
                    ? minExtent
                    : extent.clamp(minExtent, maxExtent);
                final expandProgress = maxExtent == minExtent
                    ? 0.0
                    : ((currentExtent - minExtent) / (maxExtent - minExtent))
                          .clamp(0.0, 1.0);
                final targetHeight = currentExtent * constraints.maxHeight;

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      height: targetHeight,
                      child: _buildRoutineLibrarySheet(
                        visibleRoutines,
                        themeData,
                        hostHeight: constraints.maxHeight,
                        bottomSafe: bottomSafe,
                        expandProgress: expandProgress,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeHeader(ThemeData themeData) {
    final foundation = context.darkFoundation;
    final colorScheme = themeData.colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 24, 22, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'pebble'),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ],
                    ),
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 25,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      color: foundation.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Small steps, big ripples',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      color: foundation.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _buildHeaderIconButton(
              tooltip: 'Settings',
              icon: LucideIcons.settings,
              onPressed: () => context.push('/settings'),
              themeData: themeData,
            ),
            const SizedBox(width: 2),
            const AccountBackupHeaderAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData themeData,
  }) {
    final foundation = context.darkFoundation;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: foundation.textSecondary),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        backgroundColor: foundation.surfaceLow.withValues(alpha: 0.58),
        side: BorderSide(color: foundation.borderSubtle),
      ),
    );
  }

  Widget _buildLibraryOverlayButton(ThemeData themeData, double bottomSafe) {
    final foundation = context.darkFoundation;
    // Grounding it right against the bottom nav bar without extreme overlap
    final bottomPadding = _bottomNavHeight + bottomSafe;

    return ValueListenableBuilder<double>(
      valueListenable: _routineSheetExtent,
      builder: (context, extent, _) {
        final currentExtent = extent == 0 ? _minSheetExtent : extent;
        // Fade out quickly as the sheet expands
        final opacity = (1.0 - (currentExtent / (_maxSheetExtent * 0.3))).clamp(
          0.0,
          1.0,
        );

        if (opacity <= 0) return const SizedBox.shrink();

        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: IgnorePointer(
            ignoring: opacity < 0.5,
            child: Opacity(
              opacity: opacity,
              child: GestureDetector(
                onTap: () {
                  HapticsService().lightImpact();
                  _animateRoutineSheetTo(_maxSheetExtent);
                },
                onVerticalDragUpdate: (details) {
                  if ((details.primaryDelta ?? 0) < 0 &&
                      _routineSheetExtent.value == _minSheetExtent) {
                    HapticsService().lightImpact();
                    _animateRoutineSheetTo(_maxSheetExtent);
                  }
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: foundation.surfaceLow,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    border: Border.all(color: foundation.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: foundation.shadowSoft,
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Your routines',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: foundation.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.chevronUp,
                        size: 16,
                        color: foundation.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroFocus(
    ThemeData themeData,
    Routine routine, {
    HomeRoutineHighlight? highlight,
    required double availableHeight,
  }) {
    final foundation = context.darkFoundation;
    final steps = _stepCountForRoutine(routine);
    const label = 'Your Next Ripple';
    final boundedHeight = availableHeight.clamp(280.0, 560.0);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale >= 1.35;
    final compactHero = largeText || boundedHeight < 380;
    final hideSecondaryActions = largeText || boundedHeight < 430;
    final heroTextScale = textScale.clamp(1.0, 1.35);
    final labelGapBase = compactHero
        ? 10.0
        : boundedHeight < 430
        ? 18.0
        : 24.0;
    final titleGapBase = compactHero
        ? 16.0
        : boundedHeight < 430
        ? 32.0
        : 50.0;
    final ctaGapBase = compactHero
        ? 14.0
        : boundedHeight < 460
        ? 22.0
        : 30.0;
    final bottomInsetBase = compactHero
        ? 14.0
        : boundedHeight < 430
        ? 24.0
        : 31.0;
    final topContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, compactHero ? 0 : -10),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: highlight == null ? 1.8 : 0.4,
              color: themeData.colorScheme.primary,
            ),
          ),
        ),
        SizedBox(height: labelGapBase),
        _buildHeroTitle(themeData, routine.title, compact: compactHero),
        SizedBox(height: titleGapBase),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroMetaPill(steps, routine),
              if (!hideSecondaryActions) ...[
                _buildHeroEditButton(themeData, routine),
                _buildHeroRemindersButton(themeData, routine),
                _buildHeroEmailButton(themeData, routine),
              ],
            ],
          ),
        ),
      ],
    );
    final cta = AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.scale(scale: _breathingScale.value, child: child);
      },
      child: FilledButton.icon(
        onPressed: () {
          HapticsService().lightImpact();
          _onPlayRoutine(routine);
        },
        icon: const Icon(LucideIcons.play, size: 18),
        label: const Text('Begin Routine'),
        style: FilledButton.styleFrom(
          backgroundColor: themeData.colorScheme.primary,
          foregroundColor: foundation.bgBase,
          elevation: 0,
          shadowColor: themeData.colorScheme.primary.withValues(alpha: 0.28),
          padding: EdgeInsets.symmetric(
            horizontal: compactHero ? 22 : 26,
            vertical: compactHero ? 13 : 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final hero = Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 420.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: compactHero
                      ? 20
                      : boundedHeight < 430
                      ? 26
                      : 32,
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: contentWidth, child: topContent),
                  ),
                ),
                SizedBox(height: ctaGapBase),
                const Spacer(),
                cta,
                SizedBox(height: bottomInsetBase),
              ],
            );
          },
        ),
      ),
    );

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(heroTextScale)),
      child: hero,
    );
  }

  Widget _buildHeroTitle(
    ThemeData themeData,
    String title, {
    bool compact = false,
  }) {
    final foundation = context.darkFoundation;
    final spec = _heroTitleSpec(title, compact: compact);
    final trimmed = title.trim().isEmpty ? 'Untitled routine' : title.trim();
    final hasTerminalPunctuation = RegExp(r'[.!?]$').hasMatch(trimmed);
    final body = hasTerminalPunctuation
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final punctuation = hasTerminalPunctuation
        ? trimmed.substring(trimmed.length - 1)
        : '.';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: body),
          TextSpan(
            text: punctuation,
            style: TextStyle(color: themeData.colorScheme.primary),
          ),
        ],
      ),
      maxLines: spec.maxLines,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.dmSerifDisplay(
        fontSize: spec.fontSize,
        fontWeight: FontWeight.w400,
        height: spec.lineHeight,
        color: foundation.textPrimary,
      ),
    );
  }

  _HeroTitleSpec _heroTitleSpec(String title, {bool compact = false}) {
    final length = title.trim().length;
    if (compact) {
      if (length <= 10) {
        return const _HeroTitleSpec(
          fontSize: 56,
          maxLines: 2,
          lineHeight: 0.95,
        );
      }
      if (length <= 22) {
        return const _HeroTitleSpec(
          fontSize: 48,
          maxLines: 2,
          lineHeight: 0.98,
        );
      }
      if (length <= 34) {
        return const _HeroTitleSpec(
          fontSize: 40,
          maxLines: 2,
          lineHeight: 1.02,
        );
      }
      return const _HeroTitleSpec(fontSize: 34, maxLines: 3, lineHeight: 1.04);
    }
    if (length <= 10) {
      return const _HeroTitleSpec(fontSize: 64, maxLines: 2, lineHeight: 0.95);
    }
    if (length <= 22) {
      return const _HeroTitleSpec(fontSize: 56, maxLines: 2, lineHeight: 0.98);
    }
    if (length <= 34) {
      return const _HeroTitleSpec(fontSize: 48, maxLines: 2, lineHeight: 1.02);
    }
    return const _HeroTitleSpec(fontSize: 40, maxLines: 3, lineHeight: 1.04);
  }

  Widget _buildHeroEditButton(ThemeData themeData, Routine routine) {
    final foundation = context.darkFoundation;
    return Transform.translate(
      offset: const Offset(0, 3),
      child: GestureDetector(
        onTap: () {
          HapticsService().lightImpact();
          _showContextMenu(context, routine, themeData);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: foundation.surfaceLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.settings, size: 13, color: foundation.textMuted),
              const SizedBox(width: 6),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroRemindersButton(ThemeData themeData, Routine routine) {
    final foundation = context.darkFoundation;
    return Transform.translate(
      offset: const Offset(0, 3),
      child: GestureDetector(
        onTap: () {
          HapticsService().lightImpact();
          _openRoutineReminders(routine);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: foundation.surfaceLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bell, size: 13, color: foundation.textMuted),
              const SizedBox(width: 6),
              Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroEmailButton(ThemeData themeData, Routine routine) {
    final foundation = context.darkFoundation;
    return Transform.translate(
      offset: const Offset(0, 3),
      child: GestureDetector(
        onTap: () {
          HapticsService().lightImpact();
          _openRoutineEmail(routine);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: foundation.surfaceLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.mail, size: 13, color: foundation.textMuted),
              const SizedBox(width: 6),
              Text(
                'Email',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetaPill(int steps, Routine routine) {
    final foundation = context.darkFoundation;
    return Transform.translate(
      offset: const Offset(0, 3),
      child: GestureDetector(
        onTap: () {
          HapticsService().lightImpact();
          _showStepsPreview(context, routine);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: foundation.surfaceLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.listChecks,
                size: 13,
                color: foundation.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '$steps ${steps == 1 ? 'step' : 'steps'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineLibrarySheet(
    List<Routine> visibleRoutines,
    ThemeData themeData, {
    required double hostHeight,
    required double bottomSafe,
    required double expandProgress,
  }) {
    final foundation = context.darkFoundation;
    final hasMoreThanRestingRows = visibleRoutines.length > 3;
    final collapsedProgress = 1 - expandProgress;
    final bottomListPadding = _bottomNavHeight + bottomSafe + 20;
    final listFadeAlpha = 0.82 + (collapsedProgress * 0.14);
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: expandProgress > 0.05
          ? (details) =>
                _handleRoutineSheetDismissDragUpdate(details, hostHeight)
          : null,
      onVerticalDragEnd: expandProgress > 0.05
          ? _handleRoutineSheetDismissDragEnd
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          expandProgress <= 0.45 ? 7 : 8,
          22,
          expandProgress <= 0.45 ? 7 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: foundation.borderSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: expandProgress <= 0.45
                  ? SizedBox(
                      key: const ValueKey('collapsed-routines-header'),
                      height: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Routine shelf',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: foundation.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            LucideIcons.chevronUp,
                            size: 14,
                            color: foundation.textMuted.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('expanded-routines-header'),
                      height: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Your Routines',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: foundation.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hold to move',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: foundation.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: foundation.surfaceLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: foundation.borderSubtle)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: foundation.shadowSoft,
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: CustomScrollView(
            physics: expandProgress <= 0.05
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
            slivers: [
              SliverToBoxAdapter(child: header),
              if (visibleRoutines.isEmpty)
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: expandProgress.clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 180),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                      child: _buildEmptyLibraryHint(themeData),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverReorderableList(
                    itemCount: visibleRoutines.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      unawaited(
                        _reorderRoutine(visibleRoutines, oldIndex, newIndex),
                      );
                    },
                    itemBuilder: (context, index) {
                      final routine = visibleRoutines[index];
                      return KeyedSubtree(
                        key: ValueKey('routine_library_${routine.id}'),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: _buildLibraryRow(
                            routine,
                            themeData,
                            isSelected: _focusedRoutineId == routine.id,
                            index: index,
                            isLast: index == visibleRoutines.length - 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomListPadding)),
            ],
          ),
        ),
        if (hasMoreThanRestingRows)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      foundation.surfaceLow.withValues(alpha: 0),
                      foundation.surfaceLow.withValues(alpha: listFadeAlpha),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLibraryRow(
    Routine routine,
    ThemeData themeData, {
    required bool isSelected,
    required int index,
    required bool isLast,
  }) {
    final foundation = context.darkFoundation;
    final steps = _stepCountForRoutine(routine);
    final routineColor = _routineAccentColor(routine, themeData, index);
    final icon = RoutineIconCatalog.resolve(routine.emoji).icon;
    final metadata = <String>[
      '$steps ${steps == 1 ? 'step' : 'steps'}',
      if (routine.isPinned) 'Pinned',
      if (routine.reminderTime != null) 'Reminder set',
    ];
    final rowBackground = isSelected
        ? Color.lerp(foundation.surfaceLow, routineColor, 0.16) ??
              foundation.surfaceLow
        : foundation.surfaceLow.withValues(alpha: 0.44);
    final rowBorderColor = isSelected
        ? routineColor.withValues(alpha: 0.58)
        : foundation.borderSubtle.withValues(alpha: 0.72);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticsService().lightImpact();
          ref.read(homeRoutineHighlightProvider.notifier).state = null;
          if (_focusedRoutineId != routine.id) {
            setState(() => _focusedRoutineId = routine.id);
          }
          _animateRoutineSheetTo(_minSheetExtent);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: _routineSheetRowHeight,
          margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: rowBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rowBorderColor),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: routineColor.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: routineColor.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: routineColor.withValues(
                    alpha: isSelected ? 0.22 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: routineColor.withValues(
                      alpha: isSelected ? 0.34 : 0.18,
                    ),
                  ),
                ),
                child: Icon(icon, size: 18, color: routineColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: foundation.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metadata.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? foundation.textSecondary
                            : foundation.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryHint(ThemeData themeData) {
    final foundation = context.darkFoundation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 12),
      child: Row(
        children: [
          Icon(
            LucideIcons.sparkles,
            size: 17,
            color: themeData.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'More routines will gather here.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foundation.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _routineAccentColor(Routine routine, ThemeData themeData, int index) {
    if (routine.colorHex != null && routine.colorHex != 0) {
      return Color(routine.colorHex!);
    }
    final palette = [
      themeData.colorScheme.primary,
      themeData.colorScheme.secondary,
      themeData.colorScheme.tertiary,
    ];
    return palette[index % palette.length];
  }

  Widget _buildResumeCard(
    ThemeData themeData,
    RoutineSessionResumeSummary session,
  ) {
    final colorScheme = themeData.colorScheme;
    final foundation = context.darkFoundation;
    return Material(
      color: foundation.surfaceLow,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Color.lerp(
                foundation.borderSubtle,
                colorScheme.primary,
                0.35,
              )!,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: foundation.shadowSoft,
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/play/${session.routineId}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            LucideIcons.play,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'IN PROGRESS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Resume ${session.routineTitleSnapshot}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: foundation.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Step ${session.displayStepNumber} of ${session.totalStepCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: foundation.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Discard progress',
                onPressed: () => _confirmDiscardResumeSession(session),
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: foundation.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscardResumeSession(
    RoutineSessionResumeSummary session,
  ) async {
    final shouldDiscard = await showPebbleConfirmationSheet(
      context: context,
      title: 'Discard saved progress?',
      body:
          'Your progress for "${session.routineTitleSnapshot}" will be removed. This cannot be undone.',
      cancelLabel: 'Keep progress',
      confirmLabel: 'Discard progress',
      isDestructive: true,
    );

    if (shouldDiscard != true || !mounted) {
      return;
    }

    await ref
        .read(routineSessionRepositoryProvider)
        .discardSession(session.sessionId);
  }

  Future<void> _openReorderRoutine(Routine routine) async {
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => ReorderStepsScreen(routine: fresh)),
    );
  }

  void _openNewRoutine() {
    final currentRoutineCount =
        ref.read(routineListProvider).valueOrNull?.length ?? 0;
    if (!SubscriptionGuard.canCreateRoutine(
      context,
      ref,
      currentRoutineCount,
    )) {
      return;
    }
    context.push('/creator');
  }

  void _onPlayRoutine(Routine routine) {
    _clearHighlightFor(routine.id);
    context.push('/play/${routine.id}');
  }

  void _onViewHistory(Routine routine) {
    // Set global history search to this routine title and switch to History tab
    ref.read(historySearchQueryProvider.notifier).state = routine.title;
    ref.read(navIndexProvider.notifier).state = 1;
  }

  // Removed unused _onTogglePin (use _togglePinRoutine instead)

  Future<void> _onEditRoutine(Routine routine) async {
    // Ensure we edit the latest version from DB (quick-add or in-run patches may have changed it)
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    _clearHighlightFor(routine.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoutineComposerScreen.edit(
          routine: fresh,
          onSaveComplete: (_) {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _openRoutineReminders(Routine routine) async {
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GlobalRemindersScreen(routine: fresh)),
    );
  }

  Future<void> _openRoutineEmail(Routine routine) async {
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GlobalRemindersScreen(routine: fresh, emailOnly: true),
      ),
    );
  }

  void _clearHighlightFor(int routineId) {
    final highlight = ref.read(homeRoutineHighlightProvider);
    if (highlight?.routineId == routineId) {
      ref.read(homeRoutineHighlightProvider.notifier).state = null;
    }
  }

  // Removed unused _onDeleteRoutine

  // Removed unused _confirmDeleteRoutine

  // Removed unused _buildCompactActionButton

  // Removed unused _showRoutineDialog

  // Removed unused _buildDialogActionButton

  void _showContextMenu(
    BuildContext context,
    Routine routine,
    ThemeData themeData,
  ) {
    final hasPremiumStyleAccess =
        ref.read(subscriptionProvider) != UserTier.personalFree;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final foundation = sheetContext.darkFoundation;
        final accent = _routineAccentColor(routine, themeData, 0);
        var deleteOpen = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.75;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: foundation.surfaceLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border(
                    top: BorderSide(color: foundation.borderSubtle),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: foundation.shadowSoft,
                      blurRadius: 34,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: foundation.borderSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildRoutineMenuHeader(
                            sheetContext,
                            routine,
                            accent,
                          ),
                          const SizedBox(height: 16),
                          _buildSectionHeader(sheetContext, 'MANAGE'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.pencil,
                            label: 'Edit',
                            subtitle: 'Adjust title, steps and details',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _onEditRoutine(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.listOrdered,
                            label: 'Reorder Steps',
                            subtitle: 'Drag steps into a new order',
                            accent: accent,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _openReorderRoutine(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.palette,
                            label: 'Style',
                            subtitle: hasPremiumStyleAccess
                                ? 'Change icon and accent color'
                                : 'Premium icon and color studio',
                            accent: accent,
                            premiumLocked: !hasPremiumStyleAccess,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _openStyleSheet(routine, themeData);
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildSectionHeader(sheetContext, 'INSIGHTS'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.trendingUp,
                            label: 'Stats & History',
                            subtitle: 'See how often you run this',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _onViewHistory(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.copy,
                            label: 'Duplicate Routine',
                            subtitle: 'Create an editable copy',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _duplicateRoutine(routine);
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildSectionHeader(sheetContext, 'REMOVE'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.trash2,
                            label: 'Delete Routine',
                            subtitle: deleteOpen
                                ? 'Confirm removal below'
                                : 'Reveal removal options',
                            accent: accent,
                            isDestructive: true,
                            trailingIcon: deleteOpen
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            onTap: () {
                              setSheetState(() => deleteOpen = !deleteOpen);
                            },
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: deleteOpen
                                ? Padding(
                                    key: const ValueKey('delete-inline'),
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 6,
                                    ),
                                    child: _buildDeleteConfirmationPanel(
                                      sheetContext,
                                      routine,
                                      onCancel: () {
                                        setSheetState(() => deleteOpen = false);
                                      },
                                      onDelete: () async {
                                        Navigator.pop(sheetContext);
                                        await _deleteRoutine(routine);
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('delete-hidden'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoutineMenuHeader(
    BuildContext context,
    Routine routine,
    Color accent,
  ) {
    final foundation = context.darkFoundation;
    final icon = RoutineIconCatalog.resolve(routine.emoji).icon;
    final steps = _stepCountForRoutine(routine);
    final meta = [
      '$steps ${steps == 1 ? 'step' : 'steps'}',
      if (routine.isPinned) 'Pinned',
    ].join(' - ');

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routine.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: foundation.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foundation.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final foundation = context.darkFoundation;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foundation.textMuted.withValues(alpha: 0.72),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildMenuRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool premiumLocked = false,
    IconData trailingIcon = LucideIcons.chevronRight,
  }) {
    final foundation = context.darkFoundation;
    final rowColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: foundation.borderSubtle)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rowColor.withValues(alpha: isDestructive ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: rowColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDestructive
                                  ? rowColor.withValues(alpha: 0.9)
                                  : foundation.textPrimary,
                            ),
                          ),
                        ),
                        if (premiumLocked) ...[
                          const SizedBox(width: 8),
                          Icon(LucideIcons.lock, size: 12, color: rowColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: foundation.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                trailingIcon,
                size: 18,
                color: isDestructive
                    ? rowColor.withValues(alpha: 0.55)
                    : foundation.textMuted.withValues(alpha: 0.62),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmationPanel(
    BuildContext context,
    Routine routine, {
    required VoidCallback onCancel,
    required VoidCallback onDelete,
  }) {
    final foundation = context.darkFoundation;
    final error = Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Remove "${routine.title}" from Home?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: foundation.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'History and photos stay available.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: foundation.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Keep'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: error.withValues(alpha: 0.14),
                    foregroundColor: error,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reorderRoutine(
    List<Routine> routines,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= routines.length ||
        newIndex >= routines.length) {
      return;
    }

    final movingRoutine = routines[oldIndex];
    final targetRoutine = routines[newIndex];
    if (movingRoutine.isPinned != targetRoutine.isPinned) {
      return;
    }

    final direction = oldIndex > newIndex
        ? RoutineMoveDirection.up
        : RoutineMoveDirection.down;
    final moveCount = (oldIndex - newIndex).abs();

    HapticsService().selectionClick();
    for (var i = 0; i < moveCount; i++) {
      final moved = await _moveRoutine(movingRoutine, direction);
      if (!moved) {
        return;
      }
    }
  }

  Future<bool> _moveRoutine(Routine routine, RoutineMoveDirection direction) {
    return ref
        .read(routineManagementProvider)
        .moveRoutine(routine.id, direction);
  }

  void _duplicateRoutine(Routine routine) {
    final currentRoutineCount =
        ref.read(routineListProvider).valueOrNull?.length ?? 0;
    final currentStepCount = _stepCountForRoutine(routine);
    if (!SubscriptionGuard.canCreateRoutine(
      context,
      ref,
      currentRoutineCount,
      stepCount: currentStepCount,
    )) {
      return;
    }
    final management = ref.read(routineManagementProvider);
    management.duplicateRoutine(routine.id);

    // Show beautiful zen notification
    ZenNotifications.showSuccess(
      context,
      message: 'Routine duplicated successfully',
      title: 'Duplicated',
    );
  }

  void _showStepsPreview(BuildContext context, Routine routine) {
    final foundation = context.darkFoundation;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<RoutineStep> steps = [];
    try {
      final decoded = jsonDecode(routine.stepsJson);
      if (decoded is List) {
        steps = decoded
            .map((e) => RoutineStep.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: foundation.surfaceLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: foundation.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: foundation.shadowSoft,
                blurRadius: 34,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: foundation.borderSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                routine.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildStepPreviewAction(
                      theme,
                      icon: LucideIcons.pencil,
                      label: 'Edit routine',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _onEditRoutine(routine);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStepPreviewAction(
                      theme,
                      icon: LucideIcons.listOrdered,
                      label: 'Reorder steps',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _openReorderRoutine(routine);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (steps.isEmpty)
                        _buildEmptyStepsPreview(theme)
                      else
                        for (var i = 0; i < steps.length; i++) ...[
                          _buildStepPreviewRow(steps[i], i + 1, theme),
                          if (i != steps.length - 1) const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepPreviewAction(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final foundation = context.darkFoundation;
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticsService().lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: foundation.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: colorScheme.primary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foundation.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStepsPreview(ThemeData theme) {
    final foundation = context.darkFoundation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Text(
        'No steps yet.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foundation.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStepPreviewRow(RoutineStep step, int index, ThemeData theme) {
    final foundation = context.darkFoundation;
    final colorScheme = theme.colorScheme;
    final requiresPhoto = step.hasPhotoRequirement;
    final label = step.when(
      check: (label, _, __, ___, ____, _____, ______) => label,
      info: (message) => message,
      timer: (duration) => 'Timer (${duration}s)',
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: requiresPhoto
              ? colorScheme.primary.withValues(alpha: 0.18)
              : foundation.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(
                foundation.surfaceHigh,
                colorScheme.primary,
                0.18,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foundation.textPrimary,
                      height: 1.34,
                    ),
                  ),
                  if (requiresPhoto) ...[
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.camera,
                              size: 12,
                              color: colorScheme.primary.withValues(
                                alpha: 0.78,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Photo',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.84,
                                ),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _stepCountForRoutine(Routine routine) {
    try {
      final decoded = jsonDecode(routine.stepsJson);
      if (decoded is List) {
        return decoded.length;
      }
    } catch (_) {
      // Fall back to zero so malformed payloads don't crash duplication checks.
    }
    return 0;
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final management = ref.read(routineManagementProvider);
    await management.deleteRoutine(routine.id);
    if (!mounted) return;

    ZenNotifications.showInfo(
      context,
      message: '"${routine.title}" is gone. History stays available.',
      title: 'Routine removed',
    );
  }
}

class _HeroTitleSpec {
  final double fontSize;
  final int maxLines;
  final double lineHeight;

  const _HeroTitleSpec({
    required this.fontSize,
    required this.maxLines,
    required this.lineHeight,
  });
}
