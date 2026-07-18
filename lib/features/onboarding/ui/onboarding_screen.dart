import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _starterRoutines = [
  _StarterRoutine(
    cardTitle: 'Everyday Departure Check',
    subtitle:
        'Check heat tools, stove, windows, lights, keys, and the final lock before you leave.',
    previewTitle: 'Everyday Departure Check',
    icon: LucideIcons.house,
    steps: [
      _StarterStep('Hair tools unplugged', requiresPhoto: true),
      _StarterStep('Stove and oven dials off', requiresPhoto: true),
      _StarterStep('Windows latched'),
      _StarterStep('Front door locked', requiresPhoto: true),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Medication Check',
    subtitle:
        'A simple routine for checking medication before you mark it done.',
    previewTitle: 'Medication Check',
    icon: LucideIcons.pill,
    steps: [
      _StarterStep('Go to your medication spot'),
      _StarterStep('Fill a glass of water'),
      _StarterStep('Set out what you need', requiresPhoto: true),
      _StarterStep('Mark it done straight away'),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Hotel Checkout Sweep',
    subtitle:
        'A quick hotel-room sweep for passports, chargers, drawers, and the safe.',
    previewTitle: 'Hotel Checkout Sweep',
    icon: LucideIcons.luggage,
    steps: [
      _StarterStep('Check the safe', requiresPhoto: true),
      _StarterStep('Sweep every wall outlet'),
      _StarterStep('Check drawers and nightstand'),
      _StarterStep('Touch passport, wallet, and phone'),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Car Lock & Parking Check',
    subtitle:
        'Check the windows, lights, valuables, lock, parking spot, and keys.',
    previewTitle: 'Car Lock & Parking Check',
    icon: LucideIcons.car,
    steps: [
      _StarterStep('Windows fully up'),
      _StarterStep('No valuables visible'),
      _StarterStep('Lock and listen for the clack'),
      _StarterStep('Photograph the parking spot', requiresPhoto: true),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Morning Pet Routine',
    subtitle:
        'Check food, water, medication, gates, doors, and collar before you leave.',
    previewTitle: 'Morning Pet Routine',
    icon: LucideIcons.heart,
    steps: [
      _StarterStep('Clean and fill the bowl'),
      _StarterStep('Fresh water filled', requiresPhoto: true),
      _StarterStep('Give medication if needed'),
      _StarterStep('Gates and doors checked'),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Gym & Sports Prep',
    subtitle:
        'Avoid arriving without trainers, towel, headphones, pass, or lock.',
    previewTitle: 'Gym & Sports Prep',
    icon: LucideIcons.dumbbell,
    steps: [
      _StarterStep('Trainers in the bag'),
      _StarterStep('Fresh kit and socks packed'),
      _StarterStep('Padlock checked', requiresPhoto: true),
      _StarterStep('Bottle filled and sealed'),
    ],
  ),
];

const _defaultOnboardingThemeId = ThemeId.highNoon;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _isCreatingStarter = false;
  late ThemeId _selectedThemeId;
  _StarterRoutine _selectedStarter = _starterRoutines.first;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, 3).toInt();
    _pageController = PageController(initialPage: _currentPage);
    if (_currentPage == 0) {
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
    await prefs.setBool('has_completed_onboarding', true);
  }

  Future<void> _completeToHome() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    ref.read(navIndexProvider.notifier).state = 0;
    GoRouter.of(context).go('/');
  }

  Future<void> _completeToCreator() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    GoRouter.of(context).go('/creator?fresh=1');
  }

  Future<void> _completeToTemplates() async {
    if (!mounted) return;
    GoRouter.of(context).go('/templates?from=onboarding');
  }

  Future<void> _useStarterRoutine() async {
    if (_isCreatingStarter) return;

    setState(() => _isCreatingStarter = true);

    try {
      final routine = await _createStarterRoutine(_selectedStarter);
      await _markOnboardingComplete();

      if (!mounted) return;
      ref.read(navIndexProvider.notifier).state = 0;
      ref
          .read(homeRoutineHighlightProvider.notifier)
          .state = HomeRoutineHighlight(
        routineId: routine.id,
        message: '${routine.title} is ready',
      );
      GoRouter.of(context).go('/');
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
    final activeTheme = _currentPage == 0
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
                              height: 40,
                              child: Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _goToPage(_currentPage - 1),
                                    icon: Icon(
                                      LucideIcons.arrowLeft,
                                      size: 16,
                                      color: foundation.textSecondary,
                                    ),
                                    label: Text(
                                      'Back',
                                      style: TextStyle(
                                        color: foundation.textSecondary,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: SizedBox(height: 40),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
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
                        _ThemePickerPage(
                          selectedThemeId: _selectedThemeId,
                          onThemeSelected: (themeId) async {
                            setState(() => _selectedThemeId = themeId);
                            await ref
                                .read(themeProvider.notifier)
                                .setColorTheme(themeId);
                          },
                          onContinue: () async {
                            if (mounted) _goToPage(2);
                          },
                          onDecideLater: () => _goToPage(2),
                        ),
                        _StartingPointPage(
                          starters: _starterRoutines,
                          onStarterSelected: (starter) {
                            setState(() => _selectedStarter = starter);
                            _goToPage(3);
                          },
                          onBrowseTemplates: _completeToTemplates,
                          onBuildOwn: _completeToCreator,
                          onSkip: _completeToHome,
                        ),
                        _StarterPreviewPage(
                          starter: _selectedStarter,
                          isCreating: _isCreatingStarter,
                          onUseStarter: _useStarterRoutine,
                          onPickAnother: () => _goToPage(2),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _WelcomeWordmark(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 28),
                        _WelcomeStatement(
                          primaryColor: foundation.textPrimary,
                          mutedColor: foundation.textSecondary,
                          accentColor: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 22),
                        _WelcomeRule(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'For routines you repeat.\nNot goals. Not streaks.',
                          style: GoogleFonts.dmSerifDisplay(
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
                                text: 'Pebble is for the checks that matter ',
                              ),
                              TextSpan(
                                text:
                                    'before you leave, lock up, head out, or finish up. ',
                                style: TextStyle(
                                  color: foundation.textPrimary.withValues(
                                    alpha: 0.82,
                                  ),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    'The ones you do every day, once a month, or whenever the task comes up. Follow the steps, check them off, and move on with your day.',
                              ),
                            ],
                          ),
                          style: GoogleFonts.outfit(
                            color: foundation.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            height: 1.72,
                          ),
                        ),
                        const SizedBox(height: 8),
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
        Text(
          'Pebble',
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 2.4,
            height: 1,
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
    final style = GoogleFonts.dmSerifDisplay(
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
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(text, style: textStyle),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, 0.08),
            child: Container(
              width: 238,
              height: 2,
              decoration: BoxDecoration(
                color: strikeColor.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
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
    final foundation = context.darkFoundation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Choose your theme'),
              SizedBox(width: 8),
              Icon(LucideIcons.arrowRight, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onExplore,
          style: OutlinedButton.styleFrom(
            foregroundColor: foundation.textPrimary,
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.24),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.sparkles, size: 17),
              SizedBox(width: 8),
              Text('What can Pebble do?'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: foundation.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          child: const Text('Skip setup, go straight in'),
        ),
      ],
    );
  }
}

/// The optional "What can Pebble do?" explainer, reached from the welcome
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
                                style: GoogleFonts.outfit(
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
                                    style: GoogleFonts.outfit(
                                      color: foundation.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Step out the door with total confidence.',
                                    style: GoogleFonts.dmSerifDisplay(
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
                                      'Daily routine or twice-a-year job: Pebble '
                                      'logs each step as you do it, so the doubt '
                                      'that hits later already has an answer.',
                                      style: GoogleFonts.outfit(
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
                                      'One step at a time, so nothing gets skipped.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: foundation.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Text(
                                    "Moments it's made for",
                                    style: GoogleFonts.dmSerifDisplay(
                                      color: foundation.textPrimary,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w400,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "The routines you'd normally double-check, "
                                    "and why the camera roll won't cut it.",
                                    style: GoogleFonts.outfit(
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
                                child: FilledButton(
                                  onPressed: widget.onContinue,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 17,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Continue onboarding'),
                                      SizedBox(width: 8),
                                      Icon(LucideIcons.arrowRight, size: 17),
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
        'The doubt hits halfway down the street. Open Pebble: you ticked '
        'it off two minutes ago, with a photo. No going back to check.',
  ),
  _ExplainerMoment(
    icon: LucideIcons.house,
    title: '"Are the windows actually shut?"',
    description:
        "The worry lands when you're miles away. Your photo is pinned to "
        "today's checklist, not buried somewhere in your camera roll.",
  ),
  _ExplainerMoment(
    icon: LucideIcons.idCard,
    title: '"Where\'s my work pass?"',
    description:
        "You're at the barrier with your bag half-open. No digging: you "
        'ticked it off on the way out the door.',
  ),
  _ExplainerMoment(
    icon: LucideIcons.timer,
    title: '"How did I set this up last time?"',
    description:
        'The boiler timer you only touch twice a year. Your steps from '
        "last time are still here, so there's no guessing.",
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
                  style: GoogleFonts.dmSerifDisplay(
                    color: foundation.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '3 of 5',
                style: GoogleFonts.outfit(
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
                    photoChipLabel: 'photo to be sure',
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
                    style: GoogleFonts.outfit(
                      color: isDone
                          ? foundation.textMuted
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
            style: GoogleFonts.outfit(
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
            style: GoogleFonts.outfit(
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
              style: GoogleFonts.outfit(
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

class _ThemePickerPage extends StatelessWidget {
  const _ThemePickerPage({
    required this.selectedThemeId,
    required this.onThemeSelected,
    required this.onContinue,
    required this.onDecideLater,
  });

  final ThemeId selectedThemeId;
  final Future<void> Function(ThemeId themeId) onThemeSelected;
  final VoidCallback onContinue;
  final VoidCallback onDecideLater;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final themes = [
      ThemeMetadata.get(ThemeId.highNoon),
      ThemeMetadata.get(ThemeId.amberResin),
      ThemeMetadata.get(ThemeId.softPink),
      ThemeMetadata.get(ThemeId.sageMist),
    ];
    final hint = _themeCardSpec(selectedThemeId).hint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAKE IT YOURS',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a look\nthat works for you.',
                    style: GoogleFonts.dmSerifDisplay(
                      color: foundation.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can change this any time in settings.',
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: themes
                        .map((theme) {
                          return _ThemePreviewCard(
                            metadata: theme,
                            isSelected: selectedThemeId == theme.id,
                            onTap: () => onThemeSelected(theme.id),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 16,
                    width: double.infinity,
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue'),
                    SizedBox(width: 8),
                    Icon(LucideIcons.arrowRight, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onDecideLater,
                style: TextButton.styleFrom(
                  foregroundColor: foundation.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: const Text("I'll decide later"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeCardSpec {
  const _ThemeCardSpec({
    required this.type,
    required this.hint,
    required this.swatch,
    required this.label,
    required this.mockCard,
    required this.accent,
    required this.text,
    required this.subtle,
    required this.check,
  });

  final String type;
  final String hint;
  final Color swatch;
  final Color label;
  final Color mockCard;
  final Color accent;
  final Color text;
  final Color subtle;
  final Color check;
}

_ThemeCardSpec _themeCardSpec(ThemeId id) {
  switch (id) {
    case ThemeId.highNoon:
      return const _ThemeCardSpec(
        type: 'Warm light',
        hint: 'Looking at High Noon - warm and light',
        swatch: Color(0xFFEFE8D8),
        label: Color(0xFFEFE8D8),
        mockCard: Color(0xBFFFFFFF),
        accent: Color(0xFF3E5E45),
        text: Color(0xFF2A2218),
        subtle: Color(0xFF7A6E5E),
        check: Color(0xFF1B1714),
      );
    case ThemeId.amberResin:
      return const _ThemeCardSpec(
        type: 'Warm dark',
        hint: 'Looking at Amber Resin - warm and dark',
        swatch: Color(0xFF171411),
        label: Color(0xFF1E1916),
        mockCard: Color(0xE6241F1B),
        accent: Color(0xFFD4A853),
        text: Color(0xFFF0EAE0),
        subtle: Color(0xFF8A7E72),
        check: Color(0xFF1B1714),
      );
    case ThemeId.softPink:
      return const _ThemeCardSpec(
        type: 'Soft light',
        hint: 'Looking at Soft Pink - soft and gentle',
        swatch: Color(0xFFF0E5E6),
        label: Color(0xFFF0E5E6),
        mockCard: Color(0xB3FFFFFF),
        accent: Color(0xFFA0606B),
        text: Color(0xFF2E2022),
        subtle: Color(0xFF907078),
        check: Colors.white,
      );
    case ThemeId.sageMist:
      return const _ThemeCardSpec(
        type: 'Forest dark',
        hint: 'Looking at Sage Mist - forest dark',
        swatch: Color(0xFF1A2018),
        label: Color(0xFF202820),
        mockCard: Color(0xD91E281C),
        accent: Color(0xFF6B9E72),
        text: Color(0xFFDDE8D8),
        subtle: Color(0xFF6E8070),
        check: Color(0xFF1B1714),
      );
    default:
      final fallbackTheme = AppTheme.fromId(id);
      final fallbackFoundation = fallbackTheme
          .extension<PebbleDarkFoundation>();
      return _ThemeCardSpec(
        type: ThemeMetadata.get(id).subtitle,
        hint: 'Looking at ${ThemeMetadata.get(id).name}',
        swatch: fallbackTheme.scaffoldBackgroundColor,
        label: fallbackTheme.colorScheme.surface,
        mockCard: fallbackTheme.colorScheme.surfaceContainerHigh,
        accent: fallbackTheme.colorScheme.primary,
        text: fallbackTheme.colorScheme.onSurface,
        subtle:
            fallbackFoundation?.textSecondary ??
            fallbackTheme.colorScheme.onSurface.withValues(alpha: 0.68),
        check: fallbackTheme.colorScheme.onPrimary,
      );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.metadata,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMetadata metadata;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = _themeCardSpec(metadata.id);
    final selectedColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${metadata.name}, ${spec.type}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedScale(
            scale: isSelected ? 1 : 0.985,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: spec.swatch,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  30,
                                  10,
                                  12,
                                ),
                                child: _ThemeMiniRoutine(spec: spec),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: isSelected
                                    ? Container(
                                        key: const ValueKey('selected'),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: selectedColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: spec.check,
                                        ),
                                      )
                                    : Container(
                                        key: const ValueKey('accent'),
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: spec.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: spec.label,
                      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            metadata.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSerifDisplay(
                              color: spec.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spec.type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: spec.subtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                              height: 1,
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
        ),
      ),
    );
  }
}

class _ThemeMiniRoutine extends StatelessWidget {
  const _ThemeMiniRoutine({required this.spec});

  final _ThemeCardSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _ThemeMiniStep(spec: spec, widthFactor: 1),
        const SizedBox(height: 5),
        _ThemeMiniStep(spec: spec, widthFactor: 0.42),
        const SizedBox(height: 5),
        Opacity(
          opacity: 0.5,
          child: _ThemeMiniStep(spec: spec, widthFactor: 1),
        ),
      ],
    );
  }
}

class _ThemeMiniStep extends StatelessWidget {
  const _ThemeMiniStep({required this.spec, required this.widthFactor});

  final _ThemeCardSpec spec;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: spec.mockCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: spec.accent, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: spec.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartingPointPage extends StatelessWidget {
  const _StartingPointPage({
    required this.starters,
    required this.onStarterSelected,
    required this.onBrowseTemplates,
    required this.onBuildOwn,
    required this.onSkip,
  });

  final List<_StarterRoutine> starters;
  final ValueChanged<_StarterRoutine> onStarterSelected;
  final VoidCallback onBrowseTemplates;
  final VoidCallback onBuildOwn;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STARTING POINT',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a routine\nto start with.',
                    style: GoogleFonts.dmSerifDisplay(
                      color: foundation.textPrimary,
                      fontSize: 29,
                      fontWeight: FontWeight.w400,
                      height: 1.08,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap one to see the steps inside. You can change everything later.',
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...starters.map(
                    (starter) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StarterChoiceCard(
                        starter: starter,
                        onTap: () => onStarterSelected(starter),
                      ),
                    ),
                  ),
                  _BrowseTemplatesTile(onTap: onBrowseTemplates),
                  const SizedBox(height: 8),
                  _BuildOwnTile(onTap: onBuildOwn),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: foundation.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

class _StarterChoiceCard extends StatelessWidget {
  const _StarterChoiceCard({required this.starter, required this.onTap});

  final _StarterRoutine starter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: foundation.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(starter.icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    starter.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    starter.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: foundation.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseTemplatesTile extends StatelessWidget {
  const _BrowseTemplatesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(LucideIcons.layoutGrid, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse all templates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'More ready-made routines in the library',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

class _BuildOwnTile extends StatelessWidget {
  const _BuildOwnTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: foundation.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(LucideIcons.pencil, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start from scratch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Build your own routine, step by step',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: foundation.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterPreviewPage extends StatelessWidget {
  const _StarterPreviewPage({
    required this.starter,
    required this.isCreating,
    required this.onUseStarter,
    required this.onPickAnother,
  });

  final _StarterRoutine starter;
  final bool isCreating;
  final VoidCallback onUseStarter;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return _OnboardingPageFrame(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: isCreating ? null : onUseStarter,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isCreating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Use this starter routine'),
          ),
          const SizedBox(height: 12),
          Text(
            "You can customize every step or add your own later. You're never locked in.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foundation.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isCreating ? null : onPickAnother,
            style: TextButton.styleFrom(
              foregroundColor: foundation.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Pick another starting point'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OverTitle('YOUR FIRST ROUTINE'),
          const SizedBox(height: 12),
          Text(
            "Here's how this could work",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: foundation.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Each Pebble routine is made of small steps. You go through them one at a time, and some steps can ask for a photo.',
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
