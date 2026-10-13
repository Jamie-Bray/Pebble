import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';
import 'package:pebble_routines/features/templates/ui/templates_providers.dart';

class TemplatesGalleryScreen extends ConsumerWidget {
  const TemplatesGalleryScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = _templateTokensFor(context);
    final catalogAsync = ref.watch(templateCatalogProvider);

    return Scaffold(
      backgroundColor: tokens.templatesBg,
      body: ColoredBox(
        color: tokens.templatesBg,
        child: catalogAsync.when(
          loading: () => const _TemplatesStatusView(
            title: 'Loading templates',
            message: 'One moment.',
            icon: LucideIcons.listChecks,
          ),
          error: (Object error, StackTrace stackTrace) =>
              const _TemplatesStatusView(
                title: "Couldn't load templates",
                message: 'Go back and try again.',
                icon: LucideIcons.circleAlert,
              ),
          data: (List<Template> templates) {
            final grouped = groupTemplatesByCategory(templates);

            return SafeArea(
              bottom: false,
              child: AdaptiveContentWidth(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _TemplatesHeader(fromOnboarding: fromOnboarding),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        2,
                        20,
                        36 + MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                          for (final entry in grouped.entries) ...<Widget>[
                            _TemplateGroup(
                              title: entry.key,
                              accent: _accentForGroup(context, entry.key),
                              templates: entry.value,
                              fromOnboarding: fromOnboarding,
                            ),
                            const SizedBox(height: 18),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  const _TemplatesHeader({required this.fromOnboarding});

  final bool fromOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _templateTokensFor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PebbleBackButton(
            onPressed: fromOnboarding
                ? () => context.go('/onboarding?step=templates')
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Templates',
            style: PebbleType.of(
              context,
            ).title1.copyWith(color: tokens.templatesTextPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Start from a ready-made checklist and change it to suit you.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: tokens.templatesTextSecondary,
              height: 1.36,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateGroup extends StatelessWidget {
  const _TemplateGroup({
    required this.title,
    required this.accent,
    required this.templates,
    required this.fromOnboarding,
  });

  final String title;
  final Color accent;
  final List<Template> templates;
  final bool fromOnboarding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TemplateSectionHeader(title: title, count: templates.length),
        const SizedBox(height: 6),
        for (var index = 0; index < templates.length; index += 1) ...<Widget>[
          _TemplateCard(
            template: templates[index],
            accent: accent,
            fromOnboarding: fromOnboarding,
          ),
          if (index != templates.length - 1)
            Divider(
              height: 2,
              thickness: 2,
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.30),
                _templateTokensFor(context).templatesBorder,
              ),
            ),
        ],
      ],
    );
  }
}

class _TemplateSectionHeader extends StatelessWidget {
  const _TemplateSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = _templateTokensFor(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: tokens.templatesTextMuted,
                ),
              ),
            ),
            Text(
              '$count template${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.templatesTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.accent,
    required this.fromOnboarding,
  });

  final Template template;
  final Color accent;
  final bool fromOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _templateTokensFor(context);

    return Semantics(
      button: true,
      label: 'Open ${template.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.05),
          onTap: () => context.push(
            '/templates/${template.id}${fromOnboarding ? '?from=onboarding' : ''}',
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 4),
                _TemplateIconAnchor(
                  icon: _iconForTemplate(template),
                  accent: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          template.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: tokens.templatesTextPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          template.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.templatesTextSecondary,
                            height: 1.32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          template.photoRequiredCount > 0
                              ? '${template.stepCount} steps · '
                                    '${template.photoRequiredCount} photo '
                                    'check${template.photoRequiredCount == 1 ? '' : 's'}'
                              : '${template.stepCount} steps',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tokens.templatesTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: tokens.templatesTextSecondary.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateIconAnchor extends StatelessWidget {
  const _TemplateIconAnchor({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = _templateTokensFor(context);

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(tokens.templatesSurface, accent, 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }
}

class _TemplatesStatusView extends StatelessWidget {
  const _TemplatesStatusView({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _templateTokensFor(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 42, color: tokens.templatesAccentGroup1),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.templatesTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.templatesTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

PebbleTemplatesTokens _templateTokensFor(BuildContext context) {
  final theme = Theme.of(context);
  final existing = theme.extension<PebbleTemplatesTokens>();
  if (existing != null) return existing;
  final colorScheme = theme.colorScheme;
  return PebbleTemplatesTokens.fromFoundation(
    foundation: context.darkFoundation,
    accent: colorScheme.primary,
  );
}

Color _accentForGroup(BuildContext context, String group) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (group) {
    'Leaving and locking up' => colorScheme.primary,
    'Daily care' => colorScheme.secondary,
    'Work and away' => colorScheme.tertiary,
    _ => colorScheme.primary,
  };
}

IconData _iconForTemplate(Template template) {
  return switch (template.id) {
    'tpl_anxiety_free_departure' => LucideIcons.shieldCheck,
    'tpl_deep_sleep_bedtime_scan' => LucideIcons.bedDouble,
    'tpl_car_security' => LucideIcons.carFront,
    'tpl_big_trip_shutdown' => LucideIcons.house,
    'tpl_med_check' => LucideIcons.pill,
    'tpl_morning_pet_routine' => LucideIcons.pawPrint,
    'tpl_school_morning_run' => LucideIcons.school,
    'tpl_toddler_survival_bag' => LucideIcons.baby,
    'tpl_hotel_checkout' => LucideIcons.luggage,
    'tpl_office_switch_off' => LucideIcons.briefcaseBusiness,
    'tpl_gym_prep' => LucideIcons.dumbbell,
    'tpl_house_sitter_handover' => LucideIcons.clipboardCheck,
    _ => LucideIcons.listChecks,
  };
}
