import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';

enum RoutineCreationChoice { template, scratch }

Future<void> openRoutineCreationChoice(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentRoutineCount =
      ref.read(routineListProvider).valueOrNull?.length ?? 0;
  if (!SubscriptionGuard.canCreateRoutine(context, ref, currentRoutineCount)) {
    return;
  }

  HapticFeedback.lightImpact();
  final choice = await showModalBottomSheet<RoutineCreationChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _RoutineCreationChoiceSheet(),
  );
  if (!context.mounted || choice == null) return;

  switch (choice) {
    case RoutineCreationChoice.template:
      context.push('/templates');
    case RoutineCreationChoice.scratch:
      context.push('/creator?fresh=1');
  }
}

class _RoutineCreationChoiceSheet extends StatelessWidget {
  const _RoutineCreationChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          decoration: BoxDecoration(
            color: foundation.surfaceLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: foundation.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: foundation.shadowSoft,
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foundation.borderSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Create a routine',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: foundation.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start from a calm template or build your own checklist from scratch.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foundation.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _CreationChoiceTile(
                icon: LucideIcons.layoutTemplate,
                title: 'Start from a template',
                subtitle: 'Pick a ready-made checklist and edit it later.',
                accent: cs.primary,
                onTap: () =>
                    Navigator.of(context).pop(RoutineCreationChoice.template),
              ),
              const SizedBox(height: 10),
              _CreationChoiceTile(
                icon: LucideIcons.plus,
                title: 'Create from scratch',
                subtitle: 'Name it, add your own steps, and save.',
                accent: cs.secondary,
                onTap: () =>
                    Navigator.of(context).pop(RoutineCreationChoice.scratch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreationChoiceTile extends StatelessWidget {
  const _CreationChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Material(
      color: foundation.surfaceHigh.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foundation.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
