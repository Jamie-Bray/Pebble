import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    cardTitle: 'The Everyday Departure',
    subtitle:
        'For the "Did I leave the stove on?" moment. Capture a quick photo so you can leave the house with confidence.',
    previewTitle: 'The Everyday Departure',
    icon: LucideIcons.house,
    steps: [
      _StarterStep('Hair tools unplugged', requiresPhoto: true),
      _StarterStep('Stove and oven dials off', requiresPhoto: true),
      _StarterStep('Windows latched'),
      _StarterStep('Front door locked', requiresPhoto: true),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'Did I take it? Med Check',
    subtitle:
        'For autopilot moments where you need a clear, timestamped medication check.',
    previewTitle: 'Did I take it? Med Check',
    icon: LucideIcons.pill,
    steps: [
      _StarterStep('Go to your medication spot'),
      _StarterStep('Fill a glass of water'),
      _StarterStep('Count out the dose', requiresPhoto: true),
      _StarterStep('Mark it done straight away'),
    ],
  ),
  _StarterRoutine(
    cardTitle: 'No Item Left Behind Hotel Checkout',
    subtitle:
        'A quick hotel-room sweep for passports, chargers, drawers, and the safe.',
    previewTitle: 'No Item Left Behind Hotel Checkout',
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
        'Never second-guess if you locked the car. Get visual reassurance of your locks and your parking spot.',
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
        'Food, water, gates, medication, and evidence that your pet is set.',
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
  final _StarterRoutine _selectedStarter = _starterRoutines.first;

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
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }

  Future<void> _completeToHome() async {
    HapticFeedback.lightImpact();
    await _markOnboardingComplete();
    if (!mounted) return;
    ref.read(navIndexProvider.notifier).state = 0;
    GoRouter.of(context).go('/');
  }

  Future<void> _completeToCreator() async {
    HapticFeedback.lightImpact();
    await _markOnboardingComplete();
    if (!mounted) return;
    GoRouter.of(context).go('/creator?fresh=1');
  }

  Future<void> _completeToTemplates() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    GoRouter.of(context).go('/templates?from=onboarding');
  }

  Future<void> _useStarterRoutine() async {
    if (_isCreatingStarter) return;

    HapticFeedback.lightImpact();
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
                          onSkip: _completeToHome,
                        ),
                        _ThemePickerPage(
                          selectedThemeId: _selectedThemeId,
                          onThemeSelected: (themeId) async {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedThemeId = themeId);
                            await ref
                                .read(themeProvider.notifier)
                                .setColorTheme(themeId);
                          },
                          onContinue: () async {
                            HapticFeedback.lightImpact();
                            if (mounted) _goToPage(2);
                          },
                          onDecideLater: () => _goToPage(2),
                        ),
                        _StartingPointPage(
                          starters: _starterRoutines,
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
  const _WelcomePage({required this.onContinue, required this.onSkip});

  final VoidCallback onContinue;
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
                                    'The ones you do every day, once a month, or whenever life calls for them. Follow the steps, check them off, and free up your mind so you can get on with your day',
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
          _WelcomeActions(onContinue: onContinue, onSkip: onSkip),
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
  const _WelcomeActions({required this.onContinue, required this.onSkip});

  final VoidCallback onContinue;
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
                child: const Text('I’ll decide later'),
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

class _StartingPointPage extends StatefulWidget {
  const _StartingPointPage({
    required this.starters,
    required this.onBrowseTemplates,
    required this.onBuildOwn,
    required this.onSkip,
  });

  final List<_StarterRoutine> starters;
  final VoidCallback onBrowseTemplates;
  final VoidCallback onBuildOwn;
  final VoidCallback onSkip;

  @override
  State<_StartingPointPage> createState() => _StartingPointPageState();
}

class _StartingPointPageState extends State<_StartingPointPage> {
  late final PageController _templateController;
  int _currentTemplate = 0;

  @override
  void initState() {
    super.initState();
    _templateController = PageController();
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  void _moveTemplate(int delta) {
    final next =
        (_currentTemplate + delta + widget.starters.length) %
        widget.starters.length;
    HapticFeedback.selectionClick();
    _templateController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

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
                    'TEMPLATES',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'See how a routine\ncomes together.',
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
                    'Swipe through a few examples, then choose how you want to start.',
                    style: GoogleFonts.outfit(
                      color: foundation.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 11),
                  _StarterCarousel(
                    controller: _templateController,
                    starters: widget.starters,
                    currentIndex: _currentTemplate,
                    onPageChanged: (index) {
                      setState(() => _currentTemplate = index);
                      HapticFeedback.selectionClick();
                    },
                    onPrevious: () => _moveTemplate(-1),
                    onNext: () => _moveTemplate(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: foundation.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready-made templates',
                  style: GoogleFonts.outfit(
                    color: foundation.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'We have built routines with the right steps already in. Use one as a springboard, tweak it later, or start from scratch.',
                  style: GoogleFonts.outfit(
                    color: foundation.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w300,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: widget.onBrowseTemplates,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          Text('Check out templates'),
                          SizedBox(width: 8),
                          Icon(LucideIcons.arrowRight, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: widget.onBuildOwn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foundation.textPrimary,
                        side: BorderSide(
                          color: foundation.borderSubtle,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Start from scratch'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: foundation.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterCarousel extends StatelessWidget {
  const _StarterCarousel({
    required this.controller,
    required this.starters,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final PageController controller;
  final List<_StarterRoutine> starters;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Container(
      height: 286,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 42,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: starters.length,
              itemBuilder: (context, index) {
                return _StarterCarouselCard(starter: starters[index]);
              },
            ),
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CarouselCircleButton(
                icon: LucideIcons.chevronLeft,
                onPressed: onPrevious,
              ),
              _TemplateDots(count: starters.length, activeIndex: currentIndex),
              _CarouselCircleButton(
                icon: LucideIcons.chevronRight,
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarterCarouselCard extends StatelessWidget {
  const _StarterCarouselCard({required this.starter});

  final _StarterRoutine starter;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'READY-MADE EXAMPLE',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    starter.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    starter.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: foundation.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${starter.steps.length} steps',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: starter.steps
                  .asMap()
                  .entries
                  .map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == starter.steps.length - 1 ? 0 : 7,
                      ),
                      child: _StarterCarouselStepRow(
                        step: entry.value,
                        isFirst: entry.key == 0,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarterCarouselStepRow extends StatelessWidget {
  const _StarterCarouselStepRow({required this.step, required this.isFirst});

  final _StarterStep step;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: isFirst ? accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.5),
            ),
            child: isFirst
                ? Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: foundation.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          if (step.requiresPhoto) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.camera, size: 10, color: accent),
                  const SizedBox(width: 3),
                  Text(
                    'photo',
                    style: GoogleFonts.outfit(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarouselCircleButton extends StatelessWidget {
  const _CarouselCircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: foundation.textSecondary,
          backgroundColor: Colors.white.withValues(alpha: 0.025),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        icon: Icon(icon, size: 15),
      ),
    );
  }
}

class _TemplateDots extends StatelessWidget {
  const _TemplateDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? accent : accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
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
            'Each Pebble routine is made of small steps. You go through them one at a time, and some steps can ask for a photo if you want extra reassurance later.',
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
