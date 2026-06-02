import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';
import 'package:pebble_routines/features/templates/domain/usecases/use_template_usecase.dart';
import 'package:pebble_routines/features/templates/ui/templates_providers.dart';

class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({
    super.key,
    required this.templateId,
    this.fromOnboarding = false,
  });

  final String templateId;
  final bool fromOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final templateAsync = ref.watch(templateByIdProvider(templateId));

    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: ColoredBox(
        color: foundation.bgBase,
        child: templateAsync.when(
          loading: () => const _DetailStatusView(
            title: 'Loading template',
            message: 'Getting the checklist ready.',
          ),
          error: (Object error, StackTrace stackTrace) =>
              const _DetailStatusView(
                title: 'Template unavailable',
                message: 'Please try again in a moment.',
              ),
          data: (Template? template) {
            if (template == null) {
              return const _DetailStatusView(
                title: 'Template not found',
                message: 'This template is no longer available.',
              );
            }

            return _TemplateDetailContent(
              template: template,
              fromOnboarding: fromOnboarding,
            );
          },
        ),
      ),
    );
  }
}

class _TemplateDetailContent extends ConsumerWidget {
  const _TemplateDetailContent({
    required this.template,
    required this.fromOnboarding,
  });

  final Template template;
  final bool fromOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foundation = context.darkFoundation;
    final photoRequiredCount = template.photoRequiredCount;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          PebbleBackChrome(
            onBack: fromOnboarding
                ? () => context.go('/templates?from=onboarding')
                : null,
          ),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          template.category.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          template.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: foundation.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.04,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          template.description,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foundation.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _TemplateSummaryStrip(
                          stepCount: template.stepCount,
                          photoRequiredCount: photoRequiredCount,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'STEPS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foundation.textMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (
                          var index = 0;
                          index < template.steps.length;
                          index += 1
                        ) ...<Widget>[
                          Builder(
                            builder: (context) {
                              return _StepLine(
                                index: index + 1,
                                text: Template.cleanStepLabel(
                                  template.steps[index],
                                ),
                                requiresPhoto: Template.stepRequiresPhoto(
                                  template.steps[index],
                                ),
                              );
                            },
                          ),
                          if (index != template.steps.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final currentRoutineCount =
                          ref.read(routineListProvider).valueOrNull?.length ??
                          0;
                      if (!SubscriptionGuard.canCreateRoutine(
                        context,
                        ref,
                        currentRoutineCount,
                        stepCount: template.stepCount,
                      )) {
                        return;
                      }

                      final routine = await ref
                          .read(useTemplateUseCaseProvider)
                          .call(template);
                      if (fromOnboarding) {
                        await ref
                            .read(sharedPreferencesProvider)
                            .setBool('has_completed_onboarding', true);
                      }
                      ref.read(navIndexProvider.notifier).state = 0;
                      ref
                          .read(homeRoutineHighlightProvider.notifier)
                          .state = HomeRoutineHighlight(
                        routineId: routine.id,
                        message: '${routine.title} is ready',
                      );

                      if (!context.mounted) return;
                      context.go('/');
                    },
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Add this template'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add it to your routines first, then personalise the steps any way you want.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foundation.textMuted,
                    fontWeight: FontWeight.w500,
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

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.index,
    required this.text,
    required this.requiresPhoto,
  });

  final int index;
  final String text;
  final bool requiresPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foundation = context.darkFoundation;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: requiresPhoto
              ? colorScheme.primary.withValues(alpha: 0.18)
              : foundation.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                children: <Widget>[
                  Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foundation.textPrimary,
                      height: 1.34,
                    ),
                  ),
                  if (requiresPhoto) ...<Widget>[
                    const SizedBox(height: 8),
                    const _PhotoRequiredBadge(),
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

class _TemplateSummaryStrip extends StatelessWidget {
  const _TemplateSummaryStrip({
    required this.stepCount,
    required this.photoRequiredCount,
  });

  final int stepCount;
  final int photoRequiredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foundation.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: <Widget>[
            Icon(
              LucideIcons.listChecks,
              size: 15,
              color: foundation.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              '$stepCount steps',
              style: theme.textTheme.bodySmall?.copyWith(
                color: foundation.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (photoRequiredCount > 0) ...<Widget>[
              const SizedBox(width: 14),
              Icon(
                LucideIcons.camera,
                size: 14,
                color: colorScheme.primary.withValues(alpha: 0.78),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$photoRequiredCount photo${photoRequiredCount == 1 ? '' : 's'} required',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foundation.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoRequiredBadge extends StatelessWidget {
  const _PhotoRequiredBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              LucideIcons.camera,
              size: 12,
              color: colorScheme.primary.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 5),
            Text(
              'Photo',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary.withValues(alpha: 0.84),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStatusView extends StatelessWidget {
  const _DetailStatusView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foundation = context.darkFoundation;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                LucideIcons.listChecks,
                size: 42,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: foundation.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foundation.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
