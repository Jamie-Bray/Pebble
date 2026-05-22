import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';
import 'package:pebble_routines/features/templates/ui/templates_providers.dart';

class TemplatesGalleryScreen extends ConsumerWidget {
  const TemplatesGalleryScreen({super.key});

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
            message: 'Getting the checks ready.',
            icon: LucideIcons.listChecks,
          ),
          error: (Object error, StackTrace stackTrace) =>
              const _TemplatesStatusView(
                title: 'Templates are unavailable',
                message: 'Please try again in a moment.',
                icon: LucideIcons.circleAlert,
              ),
          data: (List<Template> templates) {
            final grouped = groupTemplatesByCategory(templates);

            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  const SliverToBoxAdapter(child: _TemplatesHeader()),
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
                            accent: _accentForGroup(tokens, entry.key),
                            templates: entry.value,
                          ),
                          const SizedBox(height: 18),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  const _TemplatesHeader();

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
            backgroundColor: tokens.templatesSurface,
            iconColor: tokens.templatesTextSecondary,
          ),
          const SizedBox(height: 24),
          Text(
            'Templates',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: tokens.templatesTextPrimary,
              fontWeight: FontWeight.w800,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ready-made checklists for routines you repeat.',
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
  });

  final String title;
  final Color accent;
  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TemplateSectionHeader(title: title, count: templates.length),
        const SizedBox(height: 6),
        for (var index = 0; index < templates.length; index += 1) ...<Widget>[
          _TemplateCard(template: templates[index], accent: accent),
          if (index != templates.length - 1) const SizedBox(height: 8),
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
    final foundation = context.darkFoundation;
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
                  color: foundation.textMuted,
                ),
              ),
            ),
            Text(
              '$count template${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foundation.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.accent});

  final Template template;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _templateTokensFor(context);
    final foundation = context.darkFoundation;

    return Semantics(
      button: true,
      label: 'Open ${template.title}',
      child: Material(
        color: tokens.templatesSurfaceRaised,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.05),
          onTap: () => context.push('/templates/${template.id}'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.templatesBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: foundation.shadowSoft,
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 96,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.82),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
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
                          '${template.stepCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.templatesTextSecondary,
                            fontWeight: FontWeight.w800,
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

Color _accentForGroup(PebbleTemplatesTokens tokens, String group) {
  return switch (group) {
    'Leaving & Locking Up' => tokens.templatesAccentGroup1,
    'Daily Care' => tokens.templatesAccentGroup2,
    'Travel & Handovers' => tokens.templatesAccentGroup3,
    _ => tokens.templatesAccentGroup1,
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
