import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/routine_ai/ui/routine_ai_sheet.dart';

/// The end of onboarding, after the practice run: "Time to build your own",
/// with AI (when the server has it on), a template, or from scratch.
class FirstRoutineScreen extends ConsumerWidget {
  const FirstRoutineScreen({super.key});

  void _skip(BuildContext context, WidgetRef ref) {
    ref.read(navIndexProvider.notifier).state = 0;
    GoRouter.of(context).go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;
    final ai = ref.watch(routineAiStatusProvider).valueOrNull;
    final aiOn = ai?.enabled ?? false;

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'YOUR FIRST ROUTINE',
                        style: PebbleType.of(context).overline.copyWith(
                          color: cs.primary,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Time to build\nyour own.',
                        style: PebbleFonts.serif(
                          color: foundation.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          height: 1.06,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Make a checklist for something you really check. You can change any step later.',
                        style: PebbleType.of(context).body.copyWith(
                          color: foundation.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (aiOn) ...[
                        _FirstRoutineChoice(
                          key: const ValueKey('first-routine-ai'),
                          icon: LucideIcons.sparkles,
                          title: 'Build it with AI',
                          subtitle: ai!.premium
                              ? 'Say it in a sentence and Pebble drafts the steps.'
                              : ai.canBuild
                              ? 'Say it in a sentence and Pebble drafts the steps. Your first one is free.'
                              : 'Build more routines with AI with Personal Premium.',
                          accent: cs.primary,
                          highlighted: true,
                          onTap: () => openRoutineAiBuilder(context, ref),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _FirstRoutineChoice(
                        icon: LucideIcons.layoutTemplate,
                        title: 'Pick a template',
                        subtitle: 'Ready-made checklists you can change.',
                        accent: cs.secondary,
                        onTap: () => GoRouter.of(context).push('/templates'),
                      ),
                      const SizedBox(height: 10),
                      _FirstRoutineChoice(
                        icon: LucideIcons.plus,
                        title: 'Start from scratch',
                        subtitle: 'Name it and add your own steps.',
                        accent: cs.secondary,
                        onTap: () =>
                            GoRouter.of(context).push('/creator?fresh=1'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PebbleButton.tertiary(
                expand: true,
                onPressed: () => _skip(context, ref),
                label: 'Skip for now',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstRoutineChoice extends StatelessWidget {
  const _FirstRoutineChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);

    return Material(
      color: highlighted
          ? accent.withValues(alpha: 0.10)
          : foundation.surfaceHigh.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(highlighted ? 18 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? accent.withValues(alpha: 0.45)
                  : foundation.borderSubtle,
            ),
          ),
          child: Row(
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
                      title,
                      style: type.bodyLarge.copyWith(
                        color: foundation.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: type.caption.copyWith(
                        color: foundation.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: foundation.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
