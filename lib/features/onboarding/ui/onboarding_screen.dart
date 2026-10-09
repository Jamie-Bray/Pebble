import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/onboarding/data/onboarding_tour.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pebble_routines/features/settings/data/player_settings_controller.dart';

class _StarterStep {
  const _StarterStep(this.label, {this.requiresPhoto = false});

  final String label;
  final bool requiresPhoto;
}

class _StarterRoutine {
  const _StarterRoutine({
    required this.cardTitle,
    required this.subtitle,
    required this.previewTitle,
    required this.icon,
    required this.steps,
  });

  final String cardTitle;
  final String subtitle;
  final String previewTitle;
  final IconData icon;
  final List<_StarterStep> steps;
}

/// The practice run: a short departure check, tried in the real player.
/// It is removed afterwards (the check stays in History), so it never takes
/// one of the free plan's routines.
const _practiceRoutine = _StarterRoutine(
  cardTitle: 'Quick departure check',
  subtitle: 'Hair tools, the stove, the windows and the front door.',
  previewTitle: 'Quick departure check',
  icon: LucideIcons.house,
  steps: [
    _StarterStep('Hair tools unplugged', requiresPhoto: true),
    _StarterStep('Stove and oven dials off', requiresPhoto: true),
    _StarterStep('Windows latched'),
    _StarterStep('Front door locked', requiresPhoto: true),
  ],
);

const _defaultOnboardingThemeId = ThemeId.highNoon;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.initialPage = 0,
    this.replay = false,
  });

  final int initialPage;

  /// Opened from Settings with "Replay the intro": keep the person's theme.
  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _isCreatingStarter = false;
  late ThemeId _selectedThemeId;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, 1).toInt();
    _pageController = PageController(initialPage: _currentPage);
    // Ask early, so "Build it with AI" is ready after the practice run.
    Future.microtask(() => ref.read(routineAiStatusProvider));
    if (_currentPage == 0 && !widget.replay) {
      _selectedThemeId = _defaultOnboardingThemeId;
      Future.microtask(
        () => ref.read(themeProvider.notifier).setColorTheme(_selectedThemeId),
      );
    } else {
      _selectedThemeId = ref.read(currentColorThemeProvider);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPebblePossibilities() async {
    final shouldContinue = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => _PebblePossibilitiesScreen(
          onContinue: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (shouldContinue == true && mounted) {
      _goToPage(1);
    }
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await PlayerSettingsController.applyNewInstallDefaults(prefs);
    await OnboardingTour(prefs).start();
    await prefs.setBool('has_completed_onboarding', true);
  }

  Future<void> _completeToHome() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    ref.read(navIndexProvider.notifier).state = 0;
    GoRouter.of(context).go('/');
  }

  /// Skipping the practice run: straight to "Time to build your first
  /// routine".
  Future<void> _completeToFirstRoutine() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    GoRouter.of(context).go('/first-routine');
  }

  Future<void> _useStarterRoutine() async {
    if (_isCreatingStarter) return;

    setState(() => _isCreatingStarter = true);

    try {
      final routine = await _createStarterRoutine(_practiceRoutine);
      await _markOnboardingComplete();
      final prefs = await SharedPreferences.getInstance();
      await OnboardingTour(prefs).startPracticeRun(routine.id);

      if (!mounted) return;
      ref.read(navIndexProvider.notifier).state = 0;
      // The practice run: the real player on the routine just picked.
      GoRouter.of(context).go('/play/${routine.id}');
    } finally {
      if (mounted) {
        setState(() => _isCreatingStarter = false);
      }
    }
  }

  Future<Routine> _createStarterRoutine(_StarterRoutine starter) async {
    final now = DateTime.now();
    final routineSteps = starter.steps
        .map((step) {
          return RoutineStep.check(
            label: step.label,
            requiresPhoto: step.requiresPhoto,
            photoCount: step.requiresPhoto ? 1 : 0,
            photoPrompt: step.requiresPhoto ? 'Take photo' : null,
          );
        })
        .toList(growable: false);

    final routine = Routine(
      id: now.millisecondsSinceEpoch,
      title: starter.previewTitle,
      stepsJson: jsonEncode(routineSteps.map((step) => step.toJson()).toList()),
      createdAt: now,
      emoji: RoutineIconCatalog.defaultKey,
      colorHex: null,
      isPinned: false,
      pinnedAt: null,
      reminderDay: null,
      reminderTime: null,
      version: 1,
      updatedAt: now,
      cloudId: null,
      ownerUserId: null,
      syncStatus: 'localOnly',
      lastSyncedAt: null,
    );

    await ref.read(routineRepositoryProvider).saveRoutine(routine);
    return routine;
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = _currentPage == 0 && !widget.replay
        ? AppTheme.fromId(_defaultOnboardingThemeId)
        : AppTheme.fromId(_selectedThemeId);

    return AnimatedTheme(
      data: activeTheme,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          final foundation = context.darkFoundation;

          return Scaffold(
            backgroundColor: foundation.bgBase,
            body: SafeArea(
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _currentPage > 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: SizedBox(
                              height: PebbleBackButton.size,
                              child: Row(
                                children: [
                                  PebbleBackButton(
                                    onPressed: () =>
                                        _goToPage(_currentPage - 1),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: SizedBox(height: PebbleBackButton.size),
                          ),
                  ),
                  if (_currentPage != 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(2, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : foundation.borderSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      children: [
                        _WelcomePage(
                          onContinue: () => _goToPage(1),
                          onExplore: _openPebblePossibilities,
                          onSkip: _completeToHome,
                        ),
                        _StarterPreviewPage(
                          starter: _practiceRoutine,
                          isCreating: _isCreatingStarter,
                          onUseStarter: _useStarterRoutine,
                          onSkipPractice: _completeToFirstRoutine,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.onContinue,
    required this.onExplore,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onExplore;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeWordmark(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _WelcomeStatement(
                              primaryColor: foundation.textPrimary,
                              mutedColor: foundation.textSecondary,
                              accentColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            _WelcomeRule(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'For the checks you\nalready do.',
                              style: PebbleFonts.serif(
                                color: foundation.textPrimary.withValues(
                                  alpha: 0.94,
                                ),
                                fontSize: 21,
                                fontWeight: FontWeight.w400,
                                height: 1.32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text:
                                        'Pebble walks you through the checks you do ',
                                  ),
                                  TextSpan(
                                    text:
                                        'before you leave the house, lock up or go to bed. ',
                                    style: TextStyle(
                                      color: foundation.textPrimary.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        "Check off each step as you go and add a photo when you want proof. Pebble keeps the time, so you can look back instead of wondering whether you did it.",
                                  ),
                                ],
                              ),
                              style: PebbleFonts.sans(
                                color: foundation.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                height: 1.72,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _WelcomeActions(
            onContinue: onContinue,
            onExplore: onExplore,
            onSkip: onSkip,
          ),
        ],
      ),
    );
  }
}

class _WelcomeWordmark extends StatelessWidget {
  const _WelcomeWordmark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final lineColor = color.withValues(alpha: 0.35);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, lineColor]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The brand mark, not a record of steps: hide the cairn's own label.
        const ExcludeSemantics(
          child: PebbleCairn(total: 3, size: 44, showCount: false),
        ),
        const SizedBox(width: PebbleSpacing.xs),
        Text(
          'pebble.',
          semanticsLabel: 'Pebble',
          style: PebbleFonts.serif(
            color: color,
            fontSize: 26,
            fontStyle: FontStyle.italic,
            height: 1,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [lineColor, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeStatement extends StatelessWidget {
  const _WelcomeStatement({
    required this.primaryColor,
    required this.mutedColor,
    required this.accentColor,
  });

  final Color primaryColor;
  final Color mutedColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final style = PebbleFonts.serif(
      fontSize: 44,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.02,
      letterSpacing: -0.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A', style: style.copyWith(color: primaryColor)),
        _StruckWelcomeWord(
          text: 'habit tracker',
          textStyle: style.copyWith(color: mutedColor),
          strikeColor: accentColor,
        ),
        Text('reliable', style: style.copyWith(color: accentColor)),
        Text('kind of check.', style: style.copyWith(color: primaryColor)),
      ],
    );
  }
}

class _StruckWelcomeWord extends StatelessWidget {
  const _StruckWelcomeWord({
    required this.text,
    required this.textStyle,
    required this.strikeColor,
  });

  final String text;
  final TextStyle textStyle;
  final Color strikeColor;

  @override
  Widget build(BuildContext context) {
    // One line, scaled down if it has to be: the strike is drawn across the
    // word's own width, so it never lands between two wrapped lines.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Text(text, maxLines: 1, softWrap: false, style: textStyle),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(0, 0.08),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: strikeColor.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeRule extends StatelessWidget {
  const _WelcomeRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.3)]),
      ),
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({
    required this.onContinue,
    required this.onExplore,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onExplore;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PebbleButton.primary(
          onPressed: onContinue,
          label: 'Get started',
          trailingIcon: LucideIcons.arrowRight,
        ),
        const SizedBox(height: PebbleSpacing.sm),
        PebbleButton.secondary(
          onPressed: onExplore,
          icon: LucideIcons.sparkles,
          label: 'See what Pebble can do',
        ),
        const SizedBox(height: PebbleSpacing.xs),
        PebbleButton.tertiary(onPressed: onSkip, label: 'Skip setup'),
      ],
    );
  }
}

/// The optional "See what Pebble can do" explainer, reached from the welcome
/// step. It is pinned to the High Noon onboarding theme on purpose: the theme
/// picker comes immediately after, so this screen always shows the same warm
/// light palette as the first onboarding page.
class _PebblePossibilitiesScreen extends StatefulWidget {
  const _PebblePossibilitiesScreen({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_PebblePossibilitiesScreen> createState() =>
      _PebblePossibilitiesScreenState();
}

class _PebblePossibilitiesScreenState extends State<_PebblePossibilitiesScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  bool _motionStarted = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionStarted) return;
    _motionStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: render everything in its final state.
      _entrance.value = 1;
    } else {
      _entrance.forward();
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double begin, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.fromId(ThemeId.highNoon),
      child: Builder(
        builder: (context) {
          final foundation = context.darkFoundation;
          final accent = Theme.of(context).colorScheme.primary;

          return Scaffold(
            backgroundColor: foundation.bgBase,
            body: Stack(
              children: [
                // Atmosphere: a soft accent glow bleeding in behind the top so
                // the background isn't flat. Purely decorative.
                Positioned(
                  top: -150,
                  left: -40,
                  right: -40,
                  child: IgnorePointer(
                    child: Container(
                      height: 340,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 0.85,
                          colors: [
                            accent.withValues(alpha: 0.14),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      // Sticky top bar.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: Icon(
                                LucideIcons.arrowLeft,
                                size: 18,
                                color: foundation.textSecondary,
                              ),
                              label: Text(
                                'Back',
                                style: PebbleFonts.sans(
                                  color: foundation.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                6,
                                24,
                                128,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WHAT CAN PEBBLE DO?',
                                    style: PebbleFonts.sans(
                                      color: foundation.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Every check is saved with the time.',
                                    style: PebbleFonts.serif(
                                      color: foundation.textPrimary,
                                      fontSize: 33,
                                      fontWeight: FontWeight.w400,
                                      height: 1.08,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Text(
                                      'Use it for the daily leave-the-house check '
                                      'or a job you do twice a year. If you '
                                      'wonder later, you can look back and see '
                                      'when you did each step.',
                                      style: PebbleFonts.sans(
                                        color: foundation.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  _ExplainerRoutineCard(
                                    firstTick: _stagger(0.1, 0.42),
                                    secondTick: _stagger(0.24, 0.56),
                                    thirdTick: _stagger(0.38, 0.7),
                                    pulse: _pulse,
                                  ),
                                  const SizedBox(height: 14),
                                  Center(
                                    child: Text(
                                      'You see one step at a time, in order.',
                                      textAlign: TextAlign.center,
                                      style: PebbleFonts.sans(
                                        color: context.readableSecondaryText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Text(
                                    'Where it helps',
                                    style: PebbleFonts.serif(
                                      color: foundation.textPrimary,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w400,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'A few of the checks people tend to go back for.',
                                    style: PebbleFonts.sans(
                                      color: foundation.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _ExplainerMomentsCarousel(
                                    reveal: _stagger(0.55, 1),
                                  ),
                                ],
                              ),
                            ),
                            // Pinned CTA with a fade gradient behind it.
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      foundation.bgBase.withValues(alpha: 0),
                                      foundation.bgBase,
                                    ],
                                    stops: const [0, 0.4],
                                  ),
                                ),
                                child: PebbleButton.primary(
                                  onPressed: widget.onContinue,
                                  label: 'Continue',
                                  trailingIcon: LucideIcons.arrowRight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExplainerMoment {
  const _ExplainerMoment({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _explainerMoments = [
  _ExplainerMoment(
    icon: LucideIcons.power,
    title: '"Did I unplug the straighteners?"',
    description:
        "You're halfway down the street when you start to wonder. Open "
        'Pebble and you can see you checked them at 08:02, with a photo.',
  ),
  _ExplainerMoment(
    icon: LucideIcons.house,
    title: '"Are the windows actually shut?"',
    description:
        "You're miles away by now. The photo you took is with today's "
        "checklist, so you don't have to scroll your camera roll for it.",
  ),
  _ExplainerMoment(
    icon: LucideIcons.idCard,
    title: '"Where\'s my work pass?"',
    description:
        "You're at the barrier, rummaging in your bag. Pebble shows you "
        'checked it off at the front door this morning.',
  ),
  _ExplainerMoment(
    icon: LucideIcons.timer,
    title: '"How did I set this up last time?"',
    description:
        "It's the boiler timer you touch twice a year. The steps you "
        'saved last time are still there.',
  ),
];

enum _StepStatus { done, now, todo }

/// The one solid object on the page: the routine card with its stepping-stone
/// thread running through the tick circles.
class _ExplainerRoutineCard extends StatelessWidget {
  const _ExplainerRoutineCard({
    required this.firstTick,
    required this.secondTick,
    required this.thirdTick,
    required this.pulse,
  });

  final Animation<double> firstTick;
  final Animation<double> secondTick;
  final Animation<double> thirdTick;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: foundation.shadowSoft,
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Leaving for work',
                  style: PebbleFonts.serif(
                    color: foundation.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '3 of 5',
                style: PebbleFonts.sans(
                  color: foundation.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              // The thread: a line the tick circles render on top of, so they
              // read as stepping stones strung along it.
              Positioned(
                left: 11,
                top: 22,
                bottom: 30,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExplainerStep(
                    status: _StepStatus.done,
                    label: 'Hair straighteners off',
                    drawProgress: firstTick,
                  ),
                  _ExplainerStep(
                    status: _StepStatus.done,
                    label: 'Hob off',
                    drawProgress: secondTick,
                  ),
                  _ExplainerStep(
                    status: _StepStatus.done,
                    label: 'Windows shut',
                    drawProgress: thirdTick,
                    photoChipLabel: 'photo taken',
                  ),
                  _ExplainerStep(
                    status: _StepStatus.now,
                    label: 'Front door locked',
                    pulse: pulse,
                  ),
                  const _ExplainerStep(
                    status: _StepStatus.todo,
                    label: 'Lanyard in the bag',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExplainerStep extends StatelessWidget {
  const _ExplainerStep({
    required this.status,
    required this.label,
    this.drawProgress,
    this.pulse,
    this.photoChipLabel,
  });

  final _StepStatus status;
  final String label;
  final Animation<double>? drawProgress;
  final Animation<double>? pulse;
  final String? photoChipLabel;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final isDone = status == _StepStatus.done;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExplainerTick(
            status: status,
            drawProgress: drawProgress,
            pulse: pulse,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: PebbleFonts.sans(
                      color: isDone
                          ? context.readableSecondaryText
                          : foundation.textPrimary,
                      fontSize: 15,
                      fontWeight: status == _StepStatus.now
                          ? FontWeight.w500
                          : FontWeight.w400,
                      height: 1.35,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: foundation.textMuted.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  if (photoChipLabel != null) ...[
                    const SizedBox(height: 7),
                    _PhotoChip(label: photoChipLabel!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainerTick extends StatelessWidget {
  const _ExplainerTick({required this.status, this.drawProgress, this.pulse});

  final _StepStatus status;
  final Animation<double>? drawProgress;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    switch (status) {
      case _StepStatus.done:
        // Green-filled circle with a white check that draws in.
        return SizedBox(
          width: 24,
          height: 24,
          child: AnimatedBuilder(
            animation: drawProgress ?? const AlwaysStoppedAnimation<double>(1),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 13,
                    height: 13,
                    child: CustomPaint(
                      painter: _CheckPainter(
                        progress: (drawProgress?.value ?? 1).clamp(0.0, 1.0),
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2.4,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      case _StepStatus.now:
        // Accent ring on an opaque accent-tint fill, with a slow pulse.
        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (pulse != null)
                AnimatedBuilder(
                  animation: pulse!,
                  builder: (context, child) {
                    final t = pulse!.value;
                    return Transform.scale(
                      scale: 1 + 0.5 * t,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(
                              alpha: (0.5 * (1 - t)).clamp(0.0, 1.0).toDouble(),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Opaque so the thread reads as passing behind the stone.
                  color: Color.alphaBlend(
                    accent.withValues(alpha: 0.14),
                    foundation.bgBase,
                  ),
                  border: Border.all(color: accent, width: 2),
                ),
              ),
            ],
          ),
        );
      case _StepStatus.todo:
        // Thin grey ring on an opaque fill.
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: foundation.bgBase,
            border: Border.all(
              color: foundation.textMuted.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        );
    }
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.camera, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: PebbleFonts.sans(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The moments as swipeable cards: one story at a time instead of a wall of
/// text, with the next card peeking in from the right as the swipe affordance.
class _ExplainerMomentsCarousel extends StatefulWidget {
  const _ExplainerMomentsCarousel({required this.reveal});

  final Animation<double> reveal;

  @override
  State<_ExplainerMomentsCarousel> createState() =>
      _ExplainerMomentsCarouselState();
}

class _ExplainerMomentsCarouselState extends State<_ExplainerMomentsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return AnimatedBuilder(
      animation: widget.reveal,
      builder: (context, child) {
        return Opacity(
          opacity: widget.reveal.value.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - widget.reveal.value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          SizedBox(
            height: 224,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: _explainerMoments.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index == _explainerMoments.length - 1 ? 0 : 12,
                ),
                child: _ExplainerMomentCard(moment: _explainerMoments[index]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_explainerMoments.length, (index) {
              final isActive = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : foundation.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ExplainerMomentCard extends StatelessWidget {
  const _ExplainerMomentCard({required this.moment});

  final _ExplainerMoment moment;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(moment.icon, size: 18, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            moment.title,
            style: PebbleFonts.sans(
              color: foundation.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              moment.description,
              style: PebbleFonts.sans(
                color: foundation.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the checkmark stroke for a completed step, revealing it from the
/// short end to the long end as [progress] goes 0 -> 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width;
    Offset pt(double x, double y) => Offset(x / 24 * s, y / 24 * s);
    final a = pt(4, 12);
    final b = pt(9, 17);
    final c = pt(20, 6);
    final segments = [
      [a, b],
      [b, c],
    ];
    final lengths = segments
        .map((seg) => (seg[1] - seg[0]).distance)
        .toList(growable: false);
    final total = lengths[0] + lengths[1];
    var remaining = progress.clamp(0.0, 1.0) * total;
    final path = Path()..moveTo(a.dx, a.dy);
    for (var i = 0; i < segments.length; i++) {
      if (remaining <= 0) break;
      final segLength = lengths[i];
      if (remaining >= segLength) {
        path.lineTo(segments[i][1].dx, segments[i][1].dy);
        remaining -= segLength;
      } else {
        final lerp = Offset.lerp(
          segments[i][0],
          segments[i][1],
          remaining / segLength,
        )!;
        path.lineTo(lerp.dx, lerp.dy);
        remaining = 0;
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _StarterPreviewPage extends StatelessWidget {
  const _StarterPreviewPage({
    required this.starter,
    required this.isCreating,
    required this.onUseStarter,
    required this.onSkipPractice,
  });

  final _StarterRoutine starter;
  final bool isCreating;
  final VoidCallback onUseStarter;
  final VoidCallback onSkipPractice;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return _OnboardingPageFrame(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PebbleButton.primary(
            onPressed: onUseStarter,
            busy: isCreating,
            label: 'Start the practice run',
          ),
          const SizedBox(height: 12),
          Text(
            "It's only practice. Next, you'll build a routine of your own.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foundation.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          PebbleButton.tertiary(
            expand: true,
            onPressed: isCreating ? null : onSkipPractice,
            label: 'Skip the practice',
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OverTitle('PRACTICE RUN'),
          const SizedBox(height: 12),
          Text(
            'Try a quick check',
            style: PebbleFonts.serif(
              color: foundation.textPrimary,
              fontSize: 29,
              fontWeight: FontWeight.w400,
              height: 1.08,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "This is how every routine works: one step at a time. Photo steps ask for a picture first, so you can look back and see it was done.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foundation.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          _RoutinePreviewCard(starter: starter),
        ],
      ),
    );
  }
}

class _OnboardingPageFrame extends StatelessWidget {
  const _OnboardingPageFrame({required this.child, required this.bottom});

  final Widget child;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),
          const SizedBox(height: 18),
          bottom,
        ],
      ),
    );
  }
}

class _OverTitle extends StatelessWidget {
  const _OverTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.darkFoundation.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _RoutinePreviewCard extends StatelessWidget {
  const _RoutinePreviewCard({required this.starter});

  final _StarterRoutine starter;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foundation.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  starter.icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  starter.previewTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foundation.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...starter.steps.asMap().entries.map((entry) {
            return _PreviewStepRow(
              index: entry.key + 1,
              step: entry.value,
              isLast: entry.key == starter.steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _PreviewStepRow extends StatelessWidget {
  const _PreviewStepRow({
    required this.index,
    required this.step,
    required this.isLast,
  });

  final int index;
  final _StarterStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: foundation.borderSubtle),
            ),
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foundation.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foundation.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  if (step.requiresPhoto) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.camera,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Photo',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
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
}
