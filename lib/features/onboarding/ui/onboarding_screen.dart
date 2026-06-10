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

class _PebblePossibility {
  const _PebblePossibility({
    required this.title,
    required this.prompt,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String prompt;
  final IconData icon;
  final Color accent;
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

const _pebblePossibilities = [
  _PebblePossibility(
    title: 'The thing you only do sometimes',
    prompt:
        'Travel days, big appointments, setting up for a class, or getting ready for a one-off event.',
    icon: LucideIcons.calendarClock,
    accent: Color(0xFFC27D38),
  ),
  _PebblePossibility(
    title: 'The closing-down sweep',
    prompt:
        'Doors, tools, water, lights, chargers, and the small checks before you finish.',
    icon: LucideIcons.keyRound,
    accent: Color(0xFF4A7C74),
  ),
  _PebblePossibility(
    title: 'The handover',
    prompt: 'Notes, photos, and steps for the person who takes over next.',
    icon: LucideIcons.heartHandshake,
    accent: Color(0xFFA36F7B),
  ),
  _PebblePossibility(
    title: 'The reset after a messy task',
    prompt:
        'Clean, refill, put away, check the last detail, and know the job is actually finished.',
    icon: LucideIcons.paintbrush,
    accent: Color(0xFF7E7BB8),
  ),
  _PebblePossibility(
    title: 'The day with too many moving parts',
    prompt:
        'Documents, timings, supplies, handoffs, reminders, and other details to check.',
    icon: LucideIcons.route,
    accent: Color(0xFF5B8FD4),
  ),
  _PebblePossibility(
    title: 'The photo record',
    prompt: 'A finished setup, packed item, or locked space saved as a photo.',
    icon: LucideIcons.badgeCheck,
    accent: Color(0xFF8DA174),
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

class _PebblePossibilitiesScreen extends StatelessWidget {
  const _PebblePossibilitiesScreen({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      LucideIcons.arrowLeft,
                      size: 16,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PossibilitiesHero(),
                      const SizedBox(height: 18),
                      Text(
                        'Use it for checks that are personal, occasional, or specific to how you do a task.',
                        style: GoogleFonts.outfit(
                          color: foundation.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _PossibilityTags(),
                      const SizedBox(height: 20),
                      Text(
                        'Example checks',
                        style: GoogleFonts.dmSerifDisplay(
                          color: foundation.textPrimary,
                          fontSize: 25,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _PossibilityGrid(),
                      const SizedBox(height: 18),
                      const _PossibilityClosingThought(
                        text:
                            'If a check keeps coming back, Pebble can turn it into a routine you can run again.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                    Text('Continue onboarding'),
                    SizedBox(width: 8),
                    Icon(LucideIcons.arrowRight, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PossibilitiesHero extends StatelessWidget {
  const _PossibilitiesHero();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: foundation.shadowSoft,
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.lightbulb, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'WHAT CAN PEBBLE DO?',
                style: GoogleFonts.outfit(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Checks you only need sometimes.',
            style: GoogleFonts.dmSerifDisplay(
              color: foundation.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w400,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use Pebble for step-by-step routines you want ready when the task comes up.',
            style: GoogleFonts.outfit(
              color: foundation.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _PossibilityMiniStack(),
        ],
      ),
    );
  }
}

class _PossibilityMiniStack extends StatelessWidget {
  const _PossibilityMiniStack();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sideWidth = width * 0.56;
        final centerWidth = width * 0.62;

        return SizedBox(
          height: 146,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 24,
                width: sideWidth,
                child: _MiniPossibilityCard(
                  title: 'Before',
                  line: 'Run the checks',
                  icon: LucideIcons.listChecks,
                  accent: Color.lerp(accent, const Color(0xFFC27D38), 0.35)!,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: sideWidth,
                child: _MiniPossibilityCard(
                  title: 'During',
                  line: 'Follow each step',
                  icon: LucideIcons.circleCheck,
                  accent: Color.lerp(accent, const Color(0xFF5B8FD4), 0.36)!,
                ),
              ),
              Positioned(
                left: (width - centerWidth) / 2,
                bottom: 0,
                width: centerWidth,
                child: _MiniPossibilityCard(
                  title: 'After',
                  line: 'Mark it done',
                  icon: LucideIcons.badgeCheck,
                  accent: Color.lerp(accent, const Color(0xFFA36F7B), 0.4)!,
                  isLifted: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniPossibilityCard extends StatelessWidget {
  const _MiniPossibilityCard({
    required this.title,
    required this.line,
    required this.icon,
    required this.accent,
    this.isLifted = false,
  });

  final String title;
  final String line;
  final IconData icon;
  final Color accent;
  final bool isLifted;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLifted ? foundation.surfaceHigh : foundation.bgBase,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLifted ? 0.16 : 0.07),
            blurRadius: isLifted ? 24 : 14,
            offset: Offset(0, isLifted ? 12 : 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: foundation.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: foundation.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w300,
                    height: 1.1,
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

class _PossibilityTags extends StatelessWidget {
  const _PossibilityTags();

  static const _tags = [
    'monthly',
    'before a handoff',
    'after a task',
    'when a check repeats',
  ];

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags
          .map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: Text(
                tag,
                style: GoogleFonts.outfit(
                  color: foundation.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _PossibilityGrid extends StatelessWidget {
  const _PossibilityGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final spacing = columns == 1 ? 10.0 : 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _pebblePossibilities
              .map((possibility) {
                return SizedBox(
                  width: itemWidth,
                  child: _PossibilityCard(possibility: possibility),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _PossibilityCard extends StatelessWidget {
  const _PossibilityCard({required this.possibility});

  final _PebblePossibility possibility;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final tint = possibility.accent;

    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(possibility.icon, color: tint, size: 17),
          ),
          const SizedBox(height: 12),
          Text(
            possibility.title,
            style: GoogleFonts.outfit(
              color: foundation.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            possibility.prompt,
            style: GoogleFonts.outfit(
              color: foundation.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w300,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }
}

class _PossibilityClosingThought extends StatelessWidget {
  const _PossibilityClosingThought({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: foundation.textPrimary.withValues(alpha: 0.86),
                fontSize: 12.5,
                fontWeight: FontWeight.w300,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onBuildOwn,
            style: OutlinedButton.styleFrom(
              foregroundColor: foundation.textPrimary,
              side: BorderSide(color: foundation.borderSubtle, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Start from scratch instead'),
          ),
          const SizedBox(height: 4),
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
