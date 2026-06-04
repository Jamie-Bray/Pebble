import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_creation_choice_sheet.dart';
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
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/history/ui/styled_history_screen.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/ui/pebble_confirmation_sheet.dart';
import 'package:pebble_routines/features/account_backup/ui/account_backup_header_action.dart';
import 'package:pebble_routines/core/database/routine_step.dart';

import 'package:pebble_routines/core/ui/zen_components.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  static const double _collapsedRoutineSheetPeekHeight = 112;

  // Breathing animation controllers
  late AnimationController _breathingController;
  final ValueNotifier<double> _routineSheetExtent = ValueNotifier<double>(0);

  int? _focusedRoutineId;
  double _minSheetExtent = 0;
  double _maxSheetExtent = 0;

  Future<void> _openStyleSheet(Routine routine, ThemeData themeData) async {
    final cs = themeData.colorScheme;
    final hasPremiumStyleAccess = ref
        .read(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
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

        return _buildZenSanctuary(routines, themeData);
      },
    );
  }

  Widget _buildLoadingScreen(ThemeData themeData) {
    final foundation = context.darkFoundation;
    final cs = themeData.colorScheme;

    return Container(
      decoration: BoxDecoration(color: foundation.bgBase),
      child: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          strokeWidth: 2,
        ),
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
                            'A reliable checklist for the routines you repeat.',
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

  Widget _buildZenSanctuary(List<Routine> routines, ThemeData themeData) {
    final foundation = context.darkFoundation;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(color: foundation.bgBase),
        child: Stack(children: [_buildMasterpieceHome(routines, themeData)]),
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
    final collapsedHeight =
        _bottomNavHeight + bottomSafe + _collapsedRoutineSheetPeekHeight;
    return (collapsedHeight / hostHeight).clamp(0.12, 0.24);
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
        // Hero padding: bottom nav + the visible routine shelf teaser.
        final heroBottomPadding =
            _bottomNavHeight + bottomSafe + _collapsedRoutineSheetPeekHeight;

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
                    padding: EdgeInsets.fromLTRB(24, 0, 24, heroBottomPadding),
                    child: spotlightRoutine == null
                        ? const SizedBox.shrink()
                        : _HomeHeroStage(
                            routine: spotlightRoutine,
                            themeData: themeData,
                            steps: _stepsForRoutine(spotlightRoutine),
                            accentColor: _routineAccentColor(
                              spotlightRoutine,
                              themeData,
                              0,
                            ),
                            availableHeight:
                                constraints.maxHeight - heroBottomPadding,
                            onSettings: () {
                              HapticsService().lightImpact();
                              _showContextMenu(
                                context,
                                spotlightRoutine,
                                themeData,
                              );
                            },
                            onReminders: () {
                              HapticsService().lightImpact();
                              _openRoutineReminders(spotlightRoutine);
                            },
                            onEmail: () {
                              HapticsService().lightImpact();
                              _openRoutineEmail(spotlightRoutine);
                            },
                            onBegin: () {
                              HapticsService().lightImpact();
                              _onPlayRoutine(spotlightRoutine);
                            },
                            onPreviewStepTap: (stepIndex) {
                              HapticsService().lightImpact();
                              _onEditRoutine(
                                spotlightRoutine,
                                initialStepIndex: stepIndex,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
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
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
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
                        activeRoutineId: spotlightRoutine?.id,
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      height: 1,
                      letterSpacing: -0.3,
                      color: foundation.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Small steps, big ripples',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w300,
                      height: 1,
                      letterSpacing: 0.2,
                      color: foundation.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _buildHeaderIconButton(
              tooltip: 'App settings',
              icon: LucideIcons.slidersHorizontal,
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
      icon: Icon(icon, size: 15, color: foundation.textMuted),
      style: IconButton.styleFrom(
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        backgroundColor: foundation.textPrimary.withValues(alpha: 0.10),
        side: BorderSide(color: foundation.borderSubtle),
      ),
    );
  }

  Widget _buildRoutineLibrarySheet(
    List<Routine> visibleRoutines,
    ThemeData themeData, {
    required double hostHeight,
    required double bottomSafe,
    required double expandProgress,
    required int? activeRoutineId,
  }) {
    final foundation = context.darkFoundation;
    final hasMoreThanRestingRows = visibleRoutines.length > 3;
    final collapsedProgress = 1 - expandProgress;
    final bottomListPadding = _bottomNavHeight + bottomSafe + 20;
    final listFadeAlpha = 0.82 + (collapsedProgress * 0.14);
    final selectedIndex = visibleRoutines.indexWhere(
      (routine) => routine.id == activeRoutineId,
    );
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: expandProgress <= 0.05
          ? () {
              HapticsService().lightImpact();
              _animateRoutineSheetTo(_maxSheetExtent);
            }
          : null,
      onVerticalDragUpdate: expandProgress > 0.05
          ? (details) =>
                _handleRoutineSheetDismissDragUpdate(details, hostHeight)
          : (details) {
              if ((details.primaryDelta ?? 0) < 0) {
                HapticsService().lightImpact();
                _animateRoutineSheetTo(_maxSheetExtent);
              }
            },
      onVerticalDragEnd: expandProgress > 0.05
          ? _handleRoutineSheetDismissDragEnd
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          expandProgress <= 0.45 ? 14 : 14,
          24,
          expandProgress <= 0.45 ? 18 : 8,
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
                      height: 46,
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: const TextScaler.linear(1.0)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your Routines',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: foundation.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildCollapsedRoutineCountHint(
                                  count: visibleRoutines.length,
                                  activeIndex: selectedIndex < 0
                                      ? 0
                                      : selectedIndex,
                                  accent: themeData.colorScheme.primary,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('expanded-routines-header'),
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Your Routines',
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.3,
                                color: foundation.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'Hold to reorder',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: foundation.textPrimary.withValues(
                                alpha: 0.22,
                              ),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              if (expandProgress <= 0.05)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (visibleRoutines.isEmpty)
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
                            isSelected: activeRoutineId == routine.id,
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
    final softLockPolicy = ref.watch(routineLimitPolicyProvider);
    final isRestricted = softLockPolicy.isRoutineRestricted(index);
    final steps = _stepCountForRoutine(routine);
    final routineColor = _routineAccentColor(routine, themeData, index);
    final icon = RoutineIconCatalog.resolve(routine.emoji).icon;
    final metadata = <String>[
      '$steps ${steps == 1 ? 'step' : 'steps'}',
      if (routine.isPinned) 'Pinned',
      if (routine.reminderTime != null) 'Reminder set',
    ];
    final rowBackground = isRestricted
        ? foundation.surfaceHigh.withValues(alpha: 0.32)
        : isSelected
        ? routineColor.withValues(alpha: 0.06)
        : foundation.surfaceLow;
    final rowBorderColor = isRestricted
        ? foundation.borderSubtle.withValues(alpha: 0.72)
        : isSelected
        ? routineColor.withValues(alpha: 0.35)
        : foundation.borderSubtle;
    final titleColor = isRestricted
        ? foundation.textPrimary.withValues(alpha: 0.44)
        : foundation.textPrimary;
    final subtitle = isRestricted
        ? 'Premium ended – Upgrade to unlock'
        : metadata.join(' / ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticsService().lightImpact();
          if (isRestricted) {
            context.push(premiumRoute(source: PremiumEntrySource.routineLimit));
            return;
          }
          ref.read(homeRoutineHighlightProvider.notifier).state = null;
          if (_focusedRoutineId != routine.id) {
            setState(() => _focusedRoutineId = routine.id);
          }
          _animateRoutineSheetTo(_minSheetExtent);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: _routineSheetRowHeight,
          margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: rowBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rowBorderColor),
          ),
          child: Opacity(
            opacity: isRestricted ? 0.72 : 1,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isRestricted
                        ? foundation.textMuted.withValues(alpha: 0.48)
                        : routineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: foundation.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isRestricted ? LucideIcons.lock : icon,
                    size: 18,
                    color: isRestricted ? foundation.textMuted : routineColor,
                  ),
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
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isRestricted
                              ? FontWeight.w500
                              : FontWeight.w300,
                          color: isRestricted
                              ? themeData.colorScheme.primary.withValues(
                                  alpha: 0.74,
                                )
                              : foundation.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedOpacity(
                  opacity: isSelected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: routineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineCountDot(Color color, double alpha) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }

  Widget _buildCollapsedRoutineCountHint({
    required int count,
    required int activeIndex,
    required Color accent,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    final foundation = context.darkFoundation;
    final label = '$count ${count == 1 ? 'routine' : 'routines'}';
    final dotCount = count.clamp(1, 4);
    return Row(
      key: const ValueKey('home_routines_count_hint'),
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (var i = 0; i < dotCount; i++) ...[
          _buildRoutineCountDot(
            i == activeIndex.clamp(0, dotCount - 1)
                ? accent
                : foundation.textPrimary,
            i == activeIndex.clamp(0, dotCount - 1) ? 1 : 0.12,
          ),
          if (i != dotCount - 1) const SizedBox(width: 4),
        ],
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: foundation.textMuted,
          ),
        ),
      ],
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
    openRoutineCreationChoice(context, ref);
  }

  void _onPlayRoutine(Routine routine) {
    final routines = ref.read(routineListProvider).valueOrNull;
    final index = routines?.indexWhere((item) => item.id == routine.id) ?? -1;
    if (index >= 0 &&
        ref.read(routineLimitPolicyProvider).isRoutineRestricted(index)) {
      context.push(premiumRoute(source: PremiumEntrySource.routineLimit));
      return;
    }
    _clearHighlightFor(routine.id);
    context.push('/play/${routine.id}');
  }

  void _onViewHistory(Routine routine) {
    // Set global history search to this routine title and switch to History tab
    ref.read(historySearchQueryProvider.notifier).state = routine.title;
    ref.read(navIndexProvider.notifier).state = 1;
  }

  // Removed unused _onTogglePin (use _togglePinRoutine instead)

  Future<void> _onEditRoutine(Routine routine, {int? initialStepIndex}) async {
    // Ensure we edit the latest version from DB (quick-add or in-run patches may have changed it)
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    _clearHighlightFor(routine.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoutineComposerScreen.edit(
          routine: fresh,
          initialStepIndex: initialStepIndex,
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
    final hasPremiumStyleAccess = ref
        .read(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;
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

  int _stepCountForRoutine(Routine routine) {
    return _stepsForRoutine(routine).length;
  }

  List<RoutineStep> _stepsForRoutine(Routine routine) {
    try {
      final decoded = jsonDecode(routine.stepsJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(RoutineStep.fromJson)
            .toList();
      }
    } catch (_) {
      // Fall back to empty so malformed payloads don't crash home rendering.
    }
    return const [];
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

const _homeStepsPreviewExpandedKey = 'homeStepsPreviewExpanded';

class _HomeHeroStage extends ConsumerStatefulWidget {
  const _HomeHeroStage({
    required this.routine,
    required this.themeData,
    required this.steps,
    required this.accentColor,
    required this.availableHeight,
    required this.onSettings,
    required this.onReminders,
    required this.onEmail,
    required this.onBegin,
    required this.onPreviewStepTap,
  });

  final Routine routine;
  final ThemeData themeData;
  final List<RoutineStep> steps;
  final Color accentColor;
  final double availableHeight;
  final VoidCallback onSettings;
  final VoidCallback onReminders;
  final VoidCallback onEmail;
  final VoidCallback onBegin;
  final ValueChanged<int> onPreviewStepTap;

  @override
  ConsumerState<_HomeHeroStage> createState() => _HomeHeroStageState();
}

class _HomeHeroStageState extends ConsumerState<_HomeHeroStage> {
  late bool _isPreviewExpanded;

  @override
  void initState() {
    super.initState();
    _isPreviewExpanded =
        ref
            .read(sharedPreferencesProvider)
            .getBool(_homeStepsPreviewExpandedKey) ??
        false;
  }

  void _setPreviewExpanded(bool expanded) {
    if (_isPreviewExpanded == expanded) {
      return;
    }
    HapticsService().lightImpact();
    setState(() => _isPreviewExpanded = expanded);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(_homeStepsPreviewExpandedKey, expanded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final latestRun = ref.watch(latestRoutineRunProvider(widget.routine.id));
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxStageHeight = widget.availableHeight < 260
            ? 260.0
            : widget.availableHeight;
        final stageHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(260.0, maxStageHeight).toDouble()
            : maxStageHeight;
        final metrics = _HomeHeroMetrics.resolve(
          height: stageHeight,
          textScale: textScale,
        );
        final hero = Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              key: const ValueKey('home_hero_stage'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: metrics.topInset),
                Text(
                  'YOUR NEXT RIPPLE',
                  key: const ValueKey('home_hero_overline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: widget.themeData.colorScheme.primary.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
                SizedBox(height: metrics.overlineTitleGap),
                Text.rich(
                  key: const ValueKey('home_hero_title'),
                  _titleSpan(
                    widget.routine.title,
                    widget.themeData.colorScheme.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: metrics.titleFontSize,
                    fontWeight: FontWeight.w400,
                    height: 1.02,
                    letterSpacing: -1,
                    color: foundation.textPrimary,
                  ),
                ),
                SizedBox(height: metrics.titlePreviewGap),
                _HomeHeroPreviewCard(
                  steps: widget.steps,
                  height: metrics.previewHeight,
                  isExpanded: _isPreviewExpanded,
                  accentColor: widget.accentColor,
                  themeData: widget.themeData,
                  onSettings: widget.onSettings,
                  onReminders: widget.onReminders,
                  onEmail: widget.onEmail,
                  onToggleExpanded: () =>
                      _setPreviewExpanded(!_isPreviewExpanded),
                  onStepTap: widget.onPreviewStepTap,
                ),
                SizedBox(height: metrics.previewCtaGap),
                SizedBox(
                  key: const ValueKey('home_hero_cta_box'),
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    key: const ValueKey('home_hero_cta'),
                    onPressed: widget.onBegin,
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.themeData.colorScheme.primary,
                      foregroundColor: foundation.bgBase,
                      elevation: 0,
                      shadowColor: widget.themeData.colorScheme.primary
                          .withValues(alpha: 0.28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: metrics.ctaMetaGap),
                _HomeHeroMetaRow(
                  latestRun: latestRun,
                  lastRunTextFor: _lastRunText,
                  steps: widget.steps.length,
                ),
                SizedBox(height: metrics.bottomInset),
              ],
            ),
          ),
        );

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(metrics.effectiveTextScale)),
          child: hero,
        );
      },
    );
  }

  String _lastRunText(DateTime finishedAt) {
    final diff = DateTime.now().difference(finishedAt);
    if (diff.inMinutes < 1) return 'Last completed just now';
    if (diff.inHours < 1) return 'Last completed ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last completed ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last completed yesterday';
    return 'Last completed ${DateFormat('MMM d').format(finishedAt)}';
  }

  TextSpan _titleSpan(String title, Color accent) {
    final trimmed = title.trim().isEmpty ? 'Untitled routine' : title.trim();
    final hasTerminalPunctuation = RegExp(r'[.!?]$').hasMatch(trimmed);
    final body = hasTerminalPunctuation
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final punctuation = hasTerminalPunctuation
        ? trimmed.substring(trimmed.length - 1)
        : '.';

    return TextSpan(
      children: [
        TextSpan(text: body),
        TextSpan(
          text: punctuation,
          style: TextStyle(color: accent),
        ),
      ],
    );
  }
}

class _HomeHeroPreviewCard extends StatelessWidget {
  const _HomeHeroPreviewCard({
    required this.steps,
    required this.height,
    required this.isExpanded,
    required this.accentColor,
    required this.themeData,
    required this.onSettings,
    required this.onReminders,
    required this.onEmail,
    required this.onToggleExpanded,
    required this.onStepTap,
  });

  final List<RoutineStep> steps;
  final double height;
  final bool isExpanded;
  final Color accentColor;
  final ThemeData themeData;
  final VoidCallback onSettings;
  final VoidCallback onReminders;
  final VoidCallback onEmail;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final compact = height < 170;
    final effectiveHeight = isExpanded ? height : (compact ? 46.0 : 50.0);
    final topPadding = isExpanded ? (compact ? 6.0 : 8.0) : 5.0;
    final bottomPadding = isExpanded ? (compact ? 6.0 : 10.0) : 5.0;
    return Container(
      key: const ValueKey('home_hero_preview_card'),
      height: effectiveHeight,
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, bottomPadding),
      decoration: BoxDecoration(
        color: foundation.textPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Column(
        children: [
          _HomeHeroPreviewHeader(
            compact: compact,
            isExpanded: isExpanded,
            stepCount: steps.length,
            accentColor: accentColor,
            onToggleExpanded: onToggleExpanded,
            onSettings: onSettings,
            onReminders: onReminders,
            onEmail: onEmail,
          ),
          if (isExpanded) ...[
            SizedBox(height: compact ? 4 : 6),
            Expanded(
              child: _HomeHeroStepList(
                steps: steps,
                accentColor: accentColor,
                themeData: themeData,
                onStepTap: onStepTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeHeroPreviewHeader extends StatelessWidget {
  const _HomeHeroPreviewHeader({
    required this.compact,
    required this.isExpanded,
    required this.stepCount,
    required this.accentColor,
    required this.onToggleExpanded,
    required this.onSettings,
    required this.onReminders,
    required this.onEmail,
  });

  final bool compact;
  final bool isExpanded;
  final int stepCount;
  final Color accentColor;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSettings;
  final VoidCallback onReminders;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return SizedBox(
      key: const ValueKey('home_hero_preview_header'),
      height: compact ? 34 : 38,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Text(
                    '$stepCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Steps',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: foundation.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Routine actions',
            container: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HomeHeroPreviewIconButton(
                  key: const ValueKey('home_hero_preview_reminders'),
                  tooltip: 'Reminders',
                  icon: LucideIcons.bell,
                  compact: compact,
                  onPressed: onReminders,
                ),
                _HomeHeroPreviewIconButton(
                  key: const ValueKey('home_hero_preview_email'),
                  tooltip: 'Email',
                  icon: LucideIcons.mail,
                  compact: compact,
                  onPressed: onEmail,
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
                  color: foundation.borderSubtle.withValues(alpha: 0.78),
                ),
                _HomeHeroPreviewIconButton(
                  key: const ValueKey('home_hero_preview_settings'),
                  tooltip: 'Routine settings',
                  icon: LucideIcons.settings,
                  compact: compact,
                  onPressed: onSettings,
                ),
                Semantics(
                  label: isExpanded ? 'Hide steps' : 'Show steps',
                  button: true,
                  child: SizedBox(
                    key: const ValueKey('home_hero_preview_toggle'),
                    width: compact ? 28 : 32,
                    height: compact ? 28 : 32,
                    child: IconButton(
                      onPressed: onToggleExpanded,
                      tooltip: isExpanded ? 'Hide steps' : 'Show steps',
                      icon: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: isExpanded
                              ? accentColor
                              : foundation.textSecondary,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(compact ? 28 : 32, compact ? 28 : 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroPreviewIconButton extends StatelessWidget {
  const _HomeHeroPreviewIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final size = compact ? 28.0 : 32.0;
    return Semantics(
      label: tooltip,
      button: true,
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, size: 14, color: foundation.textMuted),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(size, size),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _HomeHeroMetaRow extends StatelessWidget {
  const _HomeHeroMetaRow({
    required this.latestRun,
    required this.lastRunTextFor,
    required this.steps,
  });

  final AsyncValue<RoutineRun?> latestRun;
  final String Function(DateTime finishedAt) lastRunTextFor;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return SizedBox(
      key: const ValueKey('home_hero_meta_row'),
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          latestRun.maybeWhen(
            data: (run) => run == null
                ? Text(
                    '$steps ${steps == 1 ? 'step' : 'steps'} ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.1,
                      color: foundation.textPrimary.withValues(alpha: 0.24),
                    ),
                  )
                : Flexible(
                    child: Row(
                      key: const ValueKey('home_hero_last_run_meta'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            lastRunTextFor(run.finishedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.1,
                              color: foundation.textPrimary.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: foundation.textPrimary.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        Text(
                          '$steps of $steps steps',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.1,
                            color: foundation.textPrimary.withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroStepList extends StatefulWidget {
  const _HomeHeroStepList({
    required this.steps,
    required this.accentColor,
    required this.themeData,
    required this.onStepTap,
  });

  final List<RoutineStep> steps;
  final Color accentColor;
  final ThemeData themeData;
  final ValueChanged<int> onStepTap;

  @override
  State<_HomeHeroStepList> createState() => _HomeHeroStepListState();
}

class _HomeHeroStepListState extends State<_HomeHeroStepList> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      final foundation = context.darkFoundation;
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'No steps yet.',
            style: widget.themeData.textTheme.bodyMedium?.copyWith(
              color: foundation.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
          stops: const [0.6, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.separated(
        key: const ValueKey('home_hero_preview_list'),
        controller: _controller,
        primary: false,
        shrinkWrap: false,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: widget.steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _HomeHeroStepRow(
            step: widget.steps[index],
            index: index + 1,
            accentColor: widget.accentColor,
            themeData: widget.themeData,
            onTap: () => widget.onStepTap(index),
          );
        },
      ),
    );
  }
}

class _HomeHeroStepRow extends StatelessWidget {
  const _HomeHeroStepRow({
    required this.step,
    required this.index,
    required this.accentColor,
    required this.themeData,
    required this.onTap,
  });

  final RoutineStep step;
  final int index;
  final Color accentColor;
  final ThemeData themeData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final label = step.when(
      check: (label, _, __, ___, ____, _____, ______) => label,
      info: (message) => message,
      timer: (duration) => 'Timer (${duration}s)',
    );

    final semanticsLabel = 'Edit step: $label';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                color: foundation.surfaceLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: foundation.textPrimary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: foundation.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: foundation.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeroMetrics {
  const _HomeHeroMetrics({
    required this.topInset,
    required this.overlineTitleGap,
    required this.titlePreviewGap,
    required this.previewCtaGap,
    required this.ctaMetaGap,
    required this.bottomInset,
    required this.titleFontSize,
    required this.previewHeight,
    required this.effectiveTextScale,
  });

  final double topInset;
  final double overlineTitleGap;
  final double titlePreviewGap;
  final double previewCtaGap;
  final double ctaMetaGap;
  final double bottomInset;
  final double titleFontSize;
  final double previewHeight;
  final double effectiveTextScale;

  static _HomeHeroMetrics resolve({
    required double height,
    required double textScale,
  }) {
    final tightForText = textScale >= 1.7;
    final tight = height < 440 || tightForText;
    final compact = tight || height < 540 || textScale >= 1.3;
    final effectiveScale = textScale.clamp(1.0, tight ? 1.04 : 1.28);
    final baseTopInset = tight
        ? 10.0
        : compact
        ? 20.0
        : 30.0;
    const heroLift = 0.0;
    final overlineTitleGap = tightForText ? 8.0 : 10.0;
    final previewExtension = tightForText ? 0.0 : 15.0;
    final titlePreviewGap = tight
        ? 12.0
        : compact
        ? 18.0
        : 20.0;
    final previewCtaGap = tight
        ? 10.0
        : compact
        ? 18.0
        : 20.0;
    final ctaMetaGap = tight
        ? 8.0
        : compact
        ? 12.0
        : 14.0;
    final bottomInset = tight
        ? 0.0
        : compact
        ? 12.0
        : 16.0;
    final titleFontSize = tight
        ? 34.0
        : compact
        ? 44.0
        : 46.0;
    final targetPreviewHeight =
        (tight
            ? 90.0
            : compact
            ? 150.0
            : 196.0) +
        previewExtension;
    final baseFixedHeight =
        baseTopInset +
        (13 * effectiveScale) +
        overlineTitleGap +
        (titleFontSize * 1.02 * 2 * effectiveScale) +
        titlePreviewGap +
        targetPreviewHeight +
        previewCtaGap +
        58 +
        ctaMetaGap +
        26 +
        bottomInset;
    final slack = height - baseFixedHeight;
    final dropCap = tightForText
        ? 0.0
        : tight
        ? 12.0
        : compact
        ? 34.0
        : 58.0;
    final verticalDrop = slack <= 0
        ? 0.0
        : (slack * 0.68).clamp(0.0, dropCap).toDouble();
    final topInset = math.max(0.0, baseTopInset + verticalDrop - heroLift);
    final fixedHeight =
        baseFixedHeight - baseTopInset - targetPreviewHeight + topInset;
    final previewMinHeight = tight ? 52.0 : 52.0;
    final remainingHeight = height - fixedHeight;
    final previewHeight = remainingHeight <= previewMinHeight
        ? remainingHeight.clamp(0.0, targetPreviewHeight).toDouble()
        : remainingHeight
              .clamp(previewMinHeight, targetPreviewHeight)
              .toDouble();

    return _HomeHeroMetrics(
      topInset: topInset,
      overlineTitleGap: overlineTitleGap,
      titlePreviewGap: titlePreviewGap,
      previewCtaGap: previewCtaGap,
      ctaMetaGap: ctaMetaGap,
      bottomInset: bottomInset,
      titleFontSize: titleFontSize,
      previewHeight: previewHeight,
      effectiveTextScale: effectiveScale,
    );
  }
}
