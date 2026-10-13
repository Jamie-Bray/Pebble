import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/core/share/pebble_share.dart';
import 'package:pebble_routines/core/share/share_messages.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/home_widget/home_widget_publisher.dart';
import 'package:pebble_routines/core/home_widget/home_widget_setup.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_ui.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/routine_ai/ui/routine_ai_sheet.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_style_picker_sheet.dart';
import 'package:pebble_routines/features/routines/creator/ui/reorder_steps_screen.dart';
import 'package:pebble_routines/core/ui/zen_error_view.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/routines/list/providers/home_hero_state_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/ui/home_hero_widgets.dart';
import 'package:pebble_routines/features/routines/list/ui/home_theme_button.dart';
import 'package:pebble_routines/features/onboarding/data/onboarding_tour.dart';
import 'package:pebble_routines/core/ui/pebble_hint.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_management_provider.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/core/ui/pebble_stones.dart';
import 'package:pebble_routines/features/routines/cover/routine_cover.dart';
import 'package:pebble_routines/features/routines/cover/routine_cover_view.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/history/ui/styled_history_screen.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/ui/pebble_confirmation_sheet.dart';
import 'package:pebble_routines/core/database/routine_step.dart';

import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_lapse_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/subscription/ui/premium_lapse_ui.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';
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

class _RoutineListScreenState extends ConsumerState<RoutineListScreen> {
  static const double _routineRowHeight = 64;
  static const double _bottomNavHeight = 70;

  final ScrollController _homeScrollController = ScrollController();

  int? _focusedRoutineId;

  Future<void> _openStyleSheet(Routine routine, ThemeData themeData) async {
    // Open to everyone: the free icons and stones are for making a routine
    // your own; locked ones open Personal Premium.
    final hasPremiumStyleAccess = ref
        .read(premiumFeaturePolicyProvider)
        .canUsePremiumThemes;

    final result = await showModalBottomSheet<RoutineStylePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineStylePickerSheet.asScaffold(
        context: ctx,
        initialIconKey: routine.emoji ?? RoutineIconCatalog.defaultKey,
        initialColorHex: routine.colorHex,
        routineTitle: routine.title,
        hasPremiumAccess: hasPremiumStyleAccess,
        onPremiumTap: () =>
            ctx.push(premiumRoute(source: PremiumEntrySource.premiumTheme)),
        initialCover: ref.read(routineCoverProvider(routine.id)),
        onPickPhoto: () async {
          final file = await ref
              .read(routinePlayerPhotoPickerProvider)
              .pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1600,
              );
          return file?.path;
        },
      ),
    );
    if (result == null || !mounted) return;
    final existingCover = ref.read(routineCoverProvider(routine.id));
    // A new photo needs Premium; one chosen earlier stays if untouched.
    final cover =
        result.cover is RoutineCoverPhoto &&
            !hasPremiumStyleAccess &&
            result.cover != existingCover
        ? existingCover
        : result.cover;
    if (cover != existingCover) {
      await saveRoutineCover(ref, routine.id, cover);
      if (!mounted) return;
    }
    await ref
        .read(routineManagementProvider)
        .updateRoutineAppearance(
          id: routine.id,
          iconKey: result.iconKey,
          // 0 means "the theme's colour" (null would keep the old one).
          colorHex: result.colorHex ?? 0,
        );
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
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
          return _buildEmptyHome(currentTheme, themeData);
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
      child: const ZenErrorView(
        title: "Couldn't load your routines",
        message: 'Close Pebble and open it again.',
      ),
    );
  }

  Widget _buildEmptyHome(ThemeId currentTheme, ThemeData themeData) {
    final foundation = context.darkFoundation;
    final aiOn =
        ref.watch(routineAiStatusProvider).valueOrNull?.enabled ?? false;

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: Container(
        decoration: BoxDecoration(color: foundation.bgBase),
        // Flat page (DESIGN_DIRECTION.md §3.4): no ambient particles.
        child: Stack(
          children: [
            AdaptiveContentWidth(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Same header as the populated Home, so the wordmark,
                  // tagline and settings control never change under the user.
                  SliverToBoxAdapter(child: _buildHomeHeader(themeData)),
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
                            // The stone waits where the first routine will
                            // go. It leaves once there is one.
                            const PebbleStones(
                              scene: PebbleStonesScene.ripple,
                              size: 148,
                            ),
                            const SizedBox(height: PebbleSpacing.xl),
                            Text(
                              'Start with one routine.',
                              style: PebbleFonts.serif(
                                fontSize: 36,
                                fontWeight: FontWeight.w400,
                                height: 1.06,
                                letterSpacing: -0.6,
                                color: foundation.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              aiOn
                                  ? 'Say what you check in a sentence and Pebble drafts the steps, or make the checklist yourself.'
                                  : 'Make a checklist for something you check often, like leaving the house.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.36,
                                color: foundation.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (aiOn) ...[
                              PebbleButton.primary(
                                onPressed: () =>
                                    openRoutineAiBuilder(context, ref),
                                icon: LucideIcons.sparkles,
                                label: 'Build with AI',
                              ),
                              const SizedBox(height: PebbleSpacing.xs),
                              PebbleButton.secondary(
                                onPressed: () =>
                                    context.push('/creator?fresh=1'),
                                icon: LucideIcons.plus,
                                label: 'Start from scratch',
                              ),
                            ] else
                              PebbleButton.primary(
                                onPressed: () =>
                                    context.push('/creator?fresh=1'),
                                icon: LucideIcons.plus,
                                label: 'Start from scratch',
                              ),
                            const SizedBox(height: PebbleSpacing.xs),
                            PebbleButton.tertiary(
                              expand: true,
                              onPressed: () => context.push('/templates'),
                              icon: LucideIcons.layoutTemplate,
                              label: 'Use a template',
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
    // Every kept run, so the routine done last still leads after Free hides
    // it from History.
    final runs = ref.watch(storedRoutineRunsProvider).valueOrNull ?? const [];
    return focusedRoutine ??
        highlightedRoutine ??
        selectHomeSpotlightRoutine(routines: routines, runs: runs);
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
        final width = mediaQuery.size.width;
        final gutter = PebbleSpacing.gutter(width);
        final latestRuns = _latestRunByRoutine();
        final otherRoutines = routines
            .where((routine) => routine.id != spotlightRoutine?.id)
            .toList();

        return Stack(
          children: [
            // The hero routine's header: soft and dimmed behind the top of
            // Home, fading out before the main button.
            if (spotlightRoutine != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: constraints.maxHeight * 0.46,
                child: Consumer(
                  builder: (context, ref, _) {
                    final cover = ref.watch(
                      routineCoverProvider(spotlightRoutine.id),
                    );
                    return RoutineAccentScope(
                      colorHex: spotlightRoutine.colorHex,
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : PebbleMotion.standard,
                        child: cover == null
                            ? const SizedBox.expand()
                            : RoutineCoverBackdrop(
                                key: ValueKey(
                                  '${spotlightRoutine.id}:${cover.encode()}',
                                ),
                                cover: cover,
                              ),
                      ),
                    );
                  },
                ),
              ),
            // One scrolling page: the routine up next, then every routine
            // with when it was last checked. Nothing hides behind a drawer,
            // so Home has no empty middle. Content caps at 640 on wide
            // screens.
            AdaptiveContentWidth(
              child: CustomScrollView(
                key: const ValueKey('home_scroll'),
                controller: _homeScrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHomeHeader(themeData)),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverList.list(
                      children: [
                        // The hero routine's own saved run shows as Resume
                        // in the hero; the card is for another routine's.
                        if (resumeSession != null &&
                            resumeSession.routineId != spotlightRoutine?.id)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildResumeCard(
                              themeData,
                              resumeSession,
                              compact: mediaQuery.size.height < 720,
                            ),
                          )
                        else
                          const _HomeLapseNotice(),
                        if (spotlightRoutine != null)
                          _HomeHeroStage(
                            routine: spotlightRoutine,
                            steps: _stepsForRoutine(spotlightRoutine),
                            accentColor: _routineAccentColor(
                              spotlightRoutine,
                              themeData,
                              0,
                            ),
                            onSettings: () {
                              _showContextMenu(
                                context,
                                spotlightRoutine,
                                themeData,
                              );
                            },
                            onBegin: () {
                              _onPlayRoutine(spotlightRoutine);
                            },
                            onStyle: () =>
                                _openStyleSheet(spotlightRoutine, themeData),
                          ),
                        if (otherRoutines.isNotEmpty)
                          _buildRoutineListHeader(otherRoutines, latestRuns),
                      ],
                    ),
                  ),
                  if (otherRoutines.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: gutter - 4),
                      sliver: SliverReorderableList(
                        itemCount: otherRoutines.length,
                        // onReorderItem already adjusts newIndex for the
                        // removed item.
                        onReorderItem: (oldIndex, newIndex) {
                          if (oldIndex < 0 ||
                              oldIndex >= otherRoutines.length ||
                              newIndex < 0 ||
                              newIndex >= otherRoutines.length) {
                            return;
                          }
                          unawaited(
                            _reorderRoutine(
                              routines,
                              routines.indexWhere(
                                (routine) =>
                                    routine.id == otherRoutines[oldIndex].id,
                              ),
                              routines.indexWhere(
                                (routine) =>
                                    routine.id == otherRoutines[newIndex].id,
                              ),
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final routine = otherRoutines[index];
                          return KeyedSubtree(
                            key: ValueKey('routine_library_${routine.id}'),
                            child: ReorderableDelayedDragStartListener(
                              index: index,
                              child: _buildLibraryRow(
                                routine,
                                themeData,
                                latestRun: latestRuns[routine.id],
                                isSelected: false,
                                index: index,
                                isFirst: index == 0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (otherRoutines.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: PebbleSpacing.sm),
                        child: Text(
                          'Hold a routine to reorder',
                          textAlign: TextAlign.center,
                          style: PebbleType.of(context).caption.copyWith(
                            fontStyle: FontStyle.italic,
                            color: context.readableSecondaryText,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _bottomNavHeight + bottomSafe + PebbleSpacing.xl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The newest kept run of each routine, for the "last checked" column.
  Map<int, RoutineRun> _latestRunByRoutine() {
    final runs = ref.watch(routineHistoryVmProvider).valueOrNull ?? const [];
    final latest = <int, RoutineRun>{};
    for (final run in runs) {
      final id = int.tryParse(run.routineId);
      if (id == null) continue;
      final current = latest[id];
      if (current == null || run.finishedAt.isAfter(current.finishedAt)) {
        latest[id] = run;
      }
    }
    return latest;
  }

  bool _isToday(DateTime at) {
    final local = at.toLocal();
    final now = ref.read(homeClockProvider)().toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Widget _buildRoutineListHeader(
    List<Routine> routines,
    Map<int, RoutineRun> latestRuns,
  ) {
    final foundation = context.darkFoundation;
    final restricted = ref.watch(restrictedRoutineIdsProvider);
    final checkedToday = routines.where((routine) {
      if (restricted.contains(routine.id)) return false;
      final run = latestRuns[routine.id];
      return run != null && _isToday(run.finishedAt);
    }).length;
    final count = routines.length;
    final hint = checkedToday > 0
        ? '$checkedToday checked today'
        : '$count ${count == 1 ? 'routine' : 'routines'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, PebbleSpacing.xxl, 2, 6),
      child: Wrap(
        key: const ValueKey('home_routines_header'),
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: PebbleSpacing.sm,
        children: [
          Semantics(
            header: true,
            child: Text(
              'More routines',
              style: PebbleFonts.serif(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2,
                color: foundation.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              hint,
              key: const ValueKey('home_routines_count_hint'),
              style: PebbleType.of(
                context,
              ).caption.copyWith(color: context.readableSecondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHeader(ThemeData themeData) {
    final foundation = context.darkFoundation;
    final colorScheme = themeData.colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PebbleSpacing.gutter(width),
          PebbleSpacing.lg,
          PebbleSpacing.gutter(width),
          PebbleSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'pebble'),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                style: PebbleFonts.serif(
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  height: 1,
                  letterSpacing: -0.3,
                  color: foundation.textPrimary,
                ),
              ),
            ),
            const HomeThemeButton(),
            PebbleGlassIconButton(
              flat: true,
              tooltip: 'App settings',
              icon: LucideIcons.settings,
              onPressed: () => context.push('/settings'),
            ),
            const SizedBox(width: PebbleSpacing.xs),
            const HomeAccountButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryRow(
    Routine routine,
    ThemeData themeData, {
    required RoutineRun? latestRun,
    required bool isSelected,
    required int index,
    required bool isFirst,
  }) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final isRestricted = ref
        .watch(restrictedRoutineIdsProvider)
        .contains(routine.id);
    final steps = _stepCountForRoutine(routine);
    final routineColor = _routineAccentColor(routine, themeData, index);
    final icon = RoutineIconCatalog.resolve(routine.emoji).icon;
    final metadata = <String>[
      '$steps ${steps == 1 ? 'step' : 'steps'}',
      if (_isWidgetRoutine(routine)) 'Shown on widget',
      if (routine.reminderTime != null) 'Reminder set',
    ];
    final subtitle = isRestricted
        ? 'Locked on Free, but still saved.'
        : metadata.join(' · ');
    final checkedToday = latestRun != null && _isToday(latestRun.finishedAt);
    final secondary = context.readableSecondaryText;

    // When it was last checked: the record is the point of Home, so each
    // routine answers "did I do it?" without being opened.
    final Widget status;
    if (isRestricted) {
      status = Icon(LucideIcons.lock, size: 16, color: secondary);
    } else if (latestRun == null) {
      status = Text(
        'Not checked yet',
        style: type.caption.copyWith(color: secondary),
      );
    } else if (checkedToday) {
      final done = ensureContrast(
        context.done,
        backgrounds: [foundation.bgBase],
        strongest: foundation.textPrimary,
      );
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, size: 15, color: done),
          const SizedBox(width: 4),
          Text(
            formatCheckTime(context, latestRun.finishedAt),
            style: type.caption.copyWith(
              color: done,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    } else {
      status = Text(
        _lastCheckedDay(latestRun.finishedAt),
        style: type.caption.copyWith(color: secondary),
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: [
        routine.title,
        subtitle,
        if (!isRestricted)
          latestRun == null
              ? 'Not checked yet'
              : 'Last checked ${_lastCheckedDay(latestRun.finishedAt)}, '
                    '${formatCheckTime(context, latestRun.finishedAt)}',
      ].join('. '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirst)
            Divider(
              height: 1,
              thickness: 1,
              indent: 52,
              color: foundation.borderSubtle,
            ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: PebbleRadius.smAll,
              onTap: () {
                if (isRestricted) {
                  showLockedRoutineSheet(context, routine);
                  return;
                }
                ref.read(homeRoutineHighlightProvider.notifier).state = null;
                if (_focusedRoutineId != routine.id) {
                  setState(() => _focusedRoutineId = routine.id);
                }
                if (_homeScrollController.hasClients) {
                  unawaited(
                    _homeScrollController.animateTo(
                      0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? const Duration(milliseconds: 1)
                          : PebbleMotion.emphasized,
                      curve: PebbleMotion.emphasizedCurve,
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: PebbleMotion.quick,
                constraints: const BoxConstraints(minHeight: _routineRowHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected && !isRestricted
                      ? routineColor.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: PebbleRadius.smAll,
                ),
                child: Opacity(
                  opacity: isRestricted ? 0.6 : 1,
                  child: Row(
                    children: [
                      _RoutineStone(
                        color: isRestricted
                            ? foundation.textMuted
                            : routineColor,
                        icon: icon,
                      ),
                      const SizedBox(width: PebbleSpacing.sm),
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
                                color: foundation.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: type.caption.copyWith(color: secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PebbleSpacing.sm),
                      status,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Yesterday" or "3 Oct" for the routine list (today shows the time).
  String _lastCheckedDay(DateTime finishedAt) {
    final at = finishedAt.toLocal();
    final now = ref.read(homeClockProvider)().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat.MMMd().format(at);
  }

  Color _routineAccentColor(Routine routine, ThemeData themeData, int index) {
    final own = context.routineAccent(routine.colorHex);
    if (own != null) return own;
    final palette = [
      themeData.colorScheme.primary,
      themeData.colorScheme.secondary,
      themeData.colorScheme.tertiary,
    ];
    return palette[index % palette.length];
  }

  Widget _buildResumeCard(
    ThemeData themeData,
    RoutineSessionResumeSummary session, {
    bool compact = false,
  }) {
    final foundation = context.darkFoundation;
    final isDark = themeData.brightness == Brightness.dark;
    final type = PebbleType.of(context);
    final action = context.actionAccent;
    // Card style (DESIGN_DIRECTION.md §3.4): one surface, no double outline
    // or shadow. The whole card resumes; Discard lives behind "…".
    return Semantics(
      container: true,
      child: Material(
        key: const ValueKey('home_resume_card'),
        color: isDark ? foundation.surfaceLow : foundation.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: PebbleRadius.lgAll,
          side: isDark
              ? BorderSide.none
              : BorderSide(
                  color: foundation.textPrimary.withValues(alpha: 0.10),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/play/${session.routineId}'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              PebbleSpacing.md,
              compact ? PebbleSpacing.xs : PebbleSpacing.sm,
              PebbleSpacing.xxs,
              compact ? PebbleSpacing.xs : PebbleSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.withValues(alpha: 0.10),
                    borderRadius: PebbleRadius.smAll,
                  ),
                  child: Icon(LucideIcons.play, color: action, size: 20),
                ),
                const SizedBox(width: PebbleSpacing.sm),
                Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        'Resume ${session.routineTitleSnapshot}, step '
                        '${session.displayStepNumber} of '
                        '${session.totalStepCount}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resume ${session.routineTitleSnapshot}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.headline.copyWith(
                            fontSize: 16,
                            color: foundation.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'In progress · step ${session.displayStepNumber} '
                          'of ${session.totalStepCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.caption.copyWith(
                            color: context.readableSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmDiscardResumeSession(session),
                  style: TextButton.styleFrom(
                    foregroundColor: context.readableSecondaryText,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
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
          'Pebble will delete your progress on "${session.routineTitleSnapshot}". You can\'t undo this.',
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

  void _onPlayRoutine(Routine routine) {
    if (ref.read(restrictedRoutineIdsProvider).contains(routine.id)) {
      showLockedRoutineSheet(context, routine);
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

  /// Whether [routine] is the one the home-screen widget shows.
  bool _isWidgetRoutine(Routine routine) {
    if (!supportsHomeScreenWidget || !routine.isPinned) return false;
    final routines = ref.read(routineListProvider).valueOrNull ?? [routine];
    return selectWidgetRoutine(routines)?.id == routine.id;
  }

  /// "Show on widget" makes this the widget's one routine; "Remove from
  /// widget" leaves the widget empty.
  Future<void> _toggleWidgetRoutine(Routine routine) async {
    final management = ref.read(routineManagementProvider);
    final routines = ref.read(routineListProvider).valueOrNull ?? [routine];
    if (_isWidgetRoutine(routine)) {
      await clearWidgetRoutine(
        routines: routines,
        setPinned: management.pinRoutine,
      );
      if (!mounted) return;
      ZenNotifications.showSuccess(
        context,
        title: 'Removed from widget',
        message: '"${routine.title}" is no longer on your widget.',
      );
      return;
    }
    await chooseWidgetRoutine(
      routine: routine,
      routines: routines,
      setPinned: management.pinRoutine,
    );
    if (!mounted) return;
    await confirmWidgetRoutineChosen(context, ref, routine);
  }

  Future<void> _onEditRoutine(Routine routine, {int? initialStepIndex}) async {
    // Ensure we edit the latest version from DB (quick-add or in-run patches may have changed it)
    final repo = ref.read(routineRepositoryProvider);
    final fresh = await repo.getRoutineById(routine.id) ?? routine;
    if (!mounted) return;
    _clearHighlightFor(routine.id);
    unawaited(
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
    // Ask the server again each time the actions open; the row keeps showing
    // the last answer while this loads.
    ref.invalidate(aiPhotoServerEnabledProvider);
    // The first time a routine's settings open after onboarding, one hint.
    final tour = ref.read(onboardingTourProvider);
    final showHint = tour.shouldShow(PebbleHint.routineSettings);
    if (showHint) unawaited(tour.markSeen(PebbleHint.routineSettings));
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final foundation = sheetContext.darkFoundation;
        final accent = _routineAccentColor(routine, themeData, 0);
        var deleteOpen = false;
        var showSettingsHint = showHint;
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
                          if (showSettingsHint) ...[
                            const SizedBox(height: 12),
                            PebbleHintBubble(
                              key: const ValueKey('routine-settings-hint'),
                              message:
                                  "Everything for this routine is here: change its steps, set reminders, or give it a style.",
                              pointsDown: false,
                              onDismiss: () =>
                                  setSheetState(() => showSettingsHint = false),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildSectionHeader(sheetContext, 'MANAGE'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.pencil,
                            label: 'Edit',
                            subtitle: 'Change the name and steps',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _onEditRoutine(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.bell,
                            label: 'Reminders',
                            subtitle: 'Choose when Pebble reminds you',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openRoutineReminders(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.mail,
                            label: 'Completion emails',
                            subtitle: 'Email someone when you finish',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openRoutineEmail(routine);
                            },
                          ),
                          // Shown only while the server has the feature
                          // switched on, or to someone who already uses it.
                          Consumer(
                            builder: (rowContext, rowRef, _) {
                              final ai = rowRef.watch(
                                aiPhotoControllerProvider,
                              );
                              final serverEnabled =
                                  rowRef
                                      .watch(aiPhotoServerEnabledProvider)
                                      .valueOrNull ??
                                  false;
                              if (!aiPhotoFeatureVisible ||
                                  (!serverEnabled && !ai.isOn)) {
                                return const SizedBox.shrink();
                              }
                              final hasPremium = rowRef
                                  .watch(premiumFeaturePolicyProvider)
                                  .hasActiveLocalPremium;
                              return _buildMenuRow(
                                sheetContext,
                                icon: LucideIcons.scanText,
                                label: 'AI photo descriptions',
                                subtitle: aiPhotoRowSubtitle(
                                  settings: ai,
                                  routine: routine,
                                  hasPremium: hasPremium,
                                  serverEnabled: serverEnabled,
                                ),
                                accent: accent,
                                premiumLocked:
                                    !hasPremium && !ai.isOnFor(routine.id),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  openAiPhotoSettings(context, ref, routine);
                                },
                              );
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.listOrdered,
                            label: 'Reorder steps',
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
                            subtitle: 'Change the icon and colour',
                            accent: accent,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _openStyleSheet(routine, themeData);
                            },
                          ),
                          // Only Android ships a home-screen widget; iOS has
                          // no WidgetKit extension, so don't offer it there.
                          if (supportsHomeScreenWidget)
                            _buildMenuRow(
                              sheetContext,
                              icon: _isWidgetRoutine(routine)
                                  ? LucideIcons.pinOff
                                  : LucideIcons.pin,
                              label: _isWidgetRoutine(routine)
                                  ? 'Remove from widget'
                                  : 'Show on widget',
                              subtitle: _isWidgetRoutine(routine)
                                  ? 'Shown on your home screen widget'
                                  : 'Start it from your home screen',
                              accent: accent,
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await _toggleWidgetRoutine(routine);
                              },
                            ),
                          const SizedBox(height: 18),
                          _buildSectionHeader(sheetContext, 'MORE'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.trendingUp,
                            label: 'History',
                            subtitle: "See when you've run it",
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _onViewHistory(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.copy,
                            label: 'Duplicate routine',
                            subtitle: 'Make a copy you can edit',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _duplicateRoutine(routine);
                            },
                          ),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.share,
                            label: 'Share routine',
                            subtitle: 'Send the steps as a checklist',
                            accent: accent,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              ref
                                  .read(pebbleShareProvider)
                                  .shareText(
                                    context,
                                    ShareMessages.routineChecklistFor(routine),
                                    subject: ShareMessages.routineSubject(
                                      routine.title,
                                    ),
                                  );
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildSectionHeader(sheetContext, 'REMOVE'),
                          const SizedBox(height: 8),
                          _buildMenuRow(
                            sheetContext,
                            icon: LucideIcons.trash2,
                            label: 'Delete routine',
                            subtitle: deleteOpen
                                ? 'Confirm below'
                                : "You'll be asked to confirm",
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
      if (_isWidgetRoutine(routine)) 'Shown on widget',
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
                  color: context.readableSecondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.readableSecondaryText,
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
                        color: context.readableSecondaryText,
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
            'Delete "${routine.title}"?',
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
            'Its history and photos stay in History.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.readableSecondaryText,
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
    // The copy appearing in the list is its own confirmation.
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
    if (ref.read(aiPhotoControllerProvider).isOnFor(routine.id)) {
      // Withdraws the consent too when no other routine uses AI.
      unawaited(
        ref.read(aiPhotoControllerProvider.notifier).turnOff(routine.id),
      );
    }
    if (!mounted) return;

    ZenNotifications.showInfo(
      context,
      message: 'Its history and photos are still in History.',
      title: '"${routine.title}" deleted',
    );
  }
}

const _homeStepsPreviewExpandedKey = 'homeStepsPreviewExpanded';
const _homePreviewStepCount = 3;

class _HomeHeroStage extends ConsumerStatefulWidget {
  const _HomeHeroStage({
    required this.routine,
    required this.steps,
    required this.accentColor,
    required this.onSettings,
    required this.onBegin,
    required this.onStyle,
  });

  final Routine routine;
  final List<RoutineStep> steps;
  final Color accentColor;
  final VoidCallback onSettings;
  final VoidCallback onBegin;
  final VoidCallback onStyle;

  @override
  ConsumerState<_HomeHeroStage> createState() => _HomeHeroStageState();
}

class _HomeHeroStageState extends ConsumerState<_HomeHeroStage> {
  late bool _isPreviewExpanded;
  bool _styleCardDismissed = false;

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
    if (_isPreviewExpanded == expanded) return;
    setState(() => _isPreviewExpanded = expanded);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(_homeStepsPreviewExpandedKey, expanded),
    );
  }

  void _dismissStyleCard() {
    if (_styleCardDismissed) return;
    setState(() => _styleCardDismissed = true);
    unawaited(ref.read(onboardingTourProvider).markSeen(PebbleHint.styleCard));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(onboardingTourVersionProvider);
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final state = ref.watch(homeHeroStateProvider(widget.routine.id));
    final nextReminder = ref
        .watch(routineNextReminderProvider(widget.routine.id))
        .valueOrNull;
    final steps = widget.steps;
    final canExpand = steps.length > _homePreviewStepCount;
    final shownCount = _isPreviewExpanded || !canExpand
        ? steps.length
        : _homePreviewStepCount;
    final checked = state.kind == HomeHeroKind.checked;
    final inProgress = state.kind == HomeHeroKind.inProgress;
    final latestRun = state.latestRun;
    final tally = state.tally;
    final metaParts = <String>[
      '${steps.length} ${steps.length == 1 ? 'step' : 'steps'}',
      if (steps
          .where((step) => step is CheckStep && step.requiresPhoto)
          .isNotEmpty)
        '${steps.where((step) => step is CheckStep && step.requiresPhoto).length} photo',
      if (nextReminder != null)
        'Reminder ${formatCheckTime(context, nextReminder)}',
    ];
    final icon = RoutineIconCatalog.resolve(widget.routine.emoji).icon;
    final statusText = inProgress && state.session != null
        ? 'Saved at step ${state.session!.displayStepNumber} of '
              '${state.session!.totalStepCount}'
        : latestRun == null
        ? 'Not checked yet'
        : checked && tally != null && tally.skipped > 0
        ? 'Checked ${tally.done} of ${tally.total} · '
              '${tally.skipped} skipped · '
              '${formatCheckTime(context, latestRun.finishedAt)}'
        : '${checked ? 'Checked' : 'Last checked'} '
              '${_dayLabel(latestRun.finishedAt)} · '
              '${formatCheckTime(context, latestRun.finishedAt)}';
    final canOpenCheck = latestRun != null && !inProgress;
    final statusColor = ensureContrast(
      context.done,
      backgrounds: [foundation.bgBase],
      strongest: foundation.textPrimary,
    );

    return Column(
      key: const ValueKey('home_hero_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _RoutineStone(color: widget.accentColor, icon: icon),
            ),
            const SizedBox(width: PebbleSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          key: const ValueKey('home_hero_title'),
                          _titleSpan(widget.routine.title, widget.accentColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PebbleFonts.serif(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            height: 1.08,
                            letterSpacing: -0.6,
                            color: foundation.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('home_hero_settings'),
                        tooltip: 'Routine settings',
                        onPressed: widget.onSettings,
                        icon: const Icon(LucideIcons.squarePen, size: 20),
                        color: context.readableAccentText(widget.accentColor),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    metaParts.join(' · '),
                    key: const ValueKey('home_hero_routine_meta'),
                    softWrap: true,
                    style: type.caption.copyWith(
                      color: context.readableSecondaryText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: PebbleSpacing.lg),
        Material(
          key: const ValueKey('home_hero_status'),
          color: Color.alphaBlend(context.doneContainer, foundation.bgBase),
          borderRadius: PebbleRadius.mdAll,
          child: InkWell(
            onTap: canOpenCheck
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RoutineRunDetailScreen(run: latestRun),
                    ),
                  )
                : null,
            borderRadius: PebbleRadius.mdAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PebbleSpacing.md,
                  vertical: PebbleSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      inProgress
                          ? LucideIcons.rotateCcw
                          : latestRun == null
                          ? LucideIcons.circle
                          : LucideIcons.check,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: PebbleSpacing.sm),
                    Expanded(
                      child: Text(
                        statusText,
                        key: const ValueKey('home_hero_status_text'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: type.body.copyWith(
                          color: foundation.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (canOpenCheck)
                      Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: context.readableSecondaryText,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: PebbleSpacing.lg),
        Text(
          'Steps',
          style: type.overline.copyWith(color: context.readableSecondaryText),
        ),
        const SizedBox(height: PebbleSpacing.xs),
        if (steps.isEmpty)
          Text('No steps yet.', style: type.body)
        else
          Column(
            key: const ValueKey('home_hero_preview_list'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < shownCount; i++)
                _HomeHeroStepRow(step: steps[i], index: i + 1, isFirst: i == 0),
            ],
          ),
        if (canExpand)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('home_hero_preview_toggle'),
              onPressed: () => _setPreviewExpanded(!_isPreviewExpanded),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: context.readableAccentText(widget.accentColor),
              ),
              child: Text(
                _isPreviewExpanded
                    ? 'Show fewer'
                    : 'Show all ${steps.length} steps',
              ),
            ),
          ),
        const SizedBox(height: PebbleSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('home_hero_cta_box'),
            child: checked
                ? PebbleButton.secondary(
                    key: const ValueKey('home_hero_cta'),
                    expand: false,
                    onPressed: widget.onBegin,
                    icon: LucideIcons.rotateCcw,
                    label: 'Run again',
                  )
                : PebbleButton.primary(
                    key: const ValueKey('home_hero_cta'),
                    expand: false,
                    onPressed: widget.onBegin,
                    icon: inProgress ? LucideIcons.rotateCcw : LucideIcons.play,
                    label: inProgress ? 'Resume' : 'Start',
                  ),
          ),
        ),
        if (!_styleCardDismissed &&
            ref.read(onboardingTourProvider).shouldShowStyleCard)
          Padding(
            padding: const EdgeInsets.only(top: PebbleSpacing.lg),
            child: HomeMakeItYoursCard(
              onOpen: () {
                _dismissStyleCard();
                widget.onStyle();
              },
              onDismiss: _dismissStyleCard,
            ),
          ),
      ],
    );
  }

  String _dayLabel(DateTime finishedAt) {
    final at = finishedAt.toLocal();
    final now = ref.read(homeClockProvider)().toLocal();
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'today';
    if (day == today.subtract(const Duration(days: 1))) return 'yesterday';
    return DateFormat.MMMd().format(at);
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

/// A routine's icon on a small stone in its colour, as in the routine list.
class _RoutineStone extends StatelessWidget {
  const _RoutineStone({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: color,
        // Slightly uneven corners, so it reads as a pebble, not a button.
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(16, 18),
            topRight: Radius.elliptical(20, 16),
            bottomRight: Radius.elliptical(17, 19),
            bottomLeft: Radius.elliptical(19, 17),
          ),
        ),
      ),
      child: Icon(icon, size: 17, color: context.darkFoundation.bgBase),
    );
  }
}

/// A read-only step preview. Editing is available from the routine icon above.
class _HomeHeroStepRow extends StatelessWidget {
  const _HomeHeroStepRow({
    required this.step,
    required this.index,
    required this.isFirst,
  });

  final RoutineStep step;
  final int index;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final label = step.when(
      check: (label, _, __, ___, ____, _____, ______) => label,
      info: (message) => message,
      timer: (duration) => 'Timer (${duration}s)',
    );
    final themeX = Theme.of(context).extension<PebbleThemeX>();
    final numberColor = themeX != null && themeX.categoryAccents.length > 1
        ? themeX.categoryAccentAt(index - 1)
        : context.readableSecondaryText;

    return Semantics(
      label: 'Step $index, $label',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: PebbleSpacing.xs),
        decoration: BoxDecoration(
          border: isFirst
              ? null
              : Border(top: BorderSide(color: foundation.borderSubtle)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                style: PebbleType.of(context).caption.copyWith(
                  color: numberColor,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PebbleType.of(
                  context,
                ).body.copyWith(color: foundation.textPrimary),
              ),
            ),
            if (step.hasPhotoRequirement) ...[
              const SizedBox(width: PebbleSpacing.xs),
              Icon(
                LucideIcons.camera,
                size: 16,
                color: context.readableSecondaryText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows [PremiumLapseNoticeCard] with spacing only when it has something to
/// say, so Home looks unchanged for everyone else.
class _HomeLapseNotice extends ConsumerWidget {
  const _HomeLapseNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(premiumLapseSummaryProvider).needsAttention) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: PremiumLapseNoticeCard(),
    );
  }
}
