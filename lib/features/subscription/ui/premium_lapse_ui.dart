import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/providers/kept_routines_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_lapse_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

// Screens and sheets for the end of Personal Premium. The rules they explain:
// nothing is deleted at the moment Premium ends; extra routines lock (and the
// user picks which stay unlocked); history older than 48 hours stays visible
// for 7 days after the lapse is confirmed, and the date is always shown. After
// that it is hidden, not deleted: every plan keeps 21 days on the phone.

/// Sheet shown when a locked routine is tapped.
Future<void> showLockedRoutineSheet(BuildContext context, Routine routine) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) =>
        _LockedRoutineSheet(routine: routine, hostContext: context),
  );
}

class _LockedRoutineSheet extends ConsumerWidget {
  const _LockedRoutineSheet({required this.routine, required this.hostContext});

  final Routine routine;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(routineLimitPolicyProvider).freeRoutineLimit;
    return _SheetFrame(
      icon: LucideIcons.lock,
      title: 'This routine is locked',
      body:
          '"${routine.title}" is still saved. Free includes $limit routines, '
          'so it unlocks again when you renew Personal Premium. '
          'You can also choose which $limit routines to keep using.',
      children: [
        PebbleButton.primary(
          onPressed: () {
            Navigator.of(context).pop();
            GoRouter.of(
              hostContext,
            ).push(premiumRoute(source: PremiumEntrySource.routineLimit));
          },
          label: 'Renew Premium',
        ),
        const SizedBox(height: PebbleSpacing.sm),
        PebbleButton.secondary(
          onPressed: () {
            Navigator.of(context).pop();
            showKeepRoutinesSheet(hostContext, preselect: routine.id);
          },
          label: 'Choose $limit routines to keep',
        ),
        const SizedBox(height: PebbleSpacing.xxs),
        PebbleButton.tertiary(
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Not now',
        ),
      ],
    );
  }
}

/// Lets a lapsed subscriber pick which routines stay unlocked on Free.
/// [preselect] (the routine they just tapped) is ticked first.
Future<void> showKeepRoutinesSheet(BuildContext context, {int? preselect}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => KeepRoutinesSheet(preselect: preselect),
  );
}

class KeepRoutinesSheet extends ConsumerStatefulWidget {
  const KeepRoutinesSheet({super.key, this.preselect});

  final int? preselect;

  @override
  ConsumerState<KeepRoutinesSheet> createState() => _KeepRoutinesSheetState();
}

class _KeepRoutinesSheetState extends ConsumerState<KeepRoutinesSheet> {
  Set<int>? _selected;

  Set<int> _initialSelection(List<Routine> routines, int limit) {
    final current = unlockedRoutineIds(
      routines: routines,
      limit: limit,
      keptRoutineIds: ref.read(keptRoutinesProvider),
    );
    final preselect = widget.preselect;
    if (preselect == null || current.contains(preselect)) return current;
    // Swap the tapped routine in for the last of the current choice.
    final ordered = [
      for (final routine in routines)
        if (current.contains(routine.id)) routine.id,
    ];
    if (ordered.length >= limit) ordered.removeLast();
    return {preselect, ...ordered};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final routines = ref.watch(routineListProvider).valueOrNull ?? const [];
    final limit = ref.watch(routineLimitPolicyProvider).freeRoutineLimit;
    final selected = _selected ??= _initialSelection(routines, limit);
    final full = selected.length >= limit;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _SheetFrame(
        icon: LucideIcons.listChecks,
        title: 'Choose $limit routines to keep',
        body:
            'These stay unlocked on Free. The others stay saved and unlock '
            'again when you renew. Nothing is deleted.',
        scrollable: true,
        children: [
          for (final routine in routines)
            CheckboxListTile(
              key: ValueKey('keep-routine-${routine.id}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(routine.id),
              title: Text(
                routine.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_stepLabel(routineStepCount(routine))),
              onChanged: !selected.contains(routine.id) && full
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        selected.add(routine.id);
                      } else {
                        selected.remove(routine.id);
                      }
                    }),
            ),
          const SizedBox(height: 8),
          Text(
            full && routines.length > limit
                ? '${selected.length} of $limit chosen. Uncheck one to swap.'
                : '${selected.length} of $limit chosen',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          PebbleButton.primary(
            label: 'Save choice',
            onPressed: selected.isEmpty
                ? null
                : () async {
                    await ref
                        .read(keptRoutinesProvider.notifier)
                        .keep(Set<int>.of(selected));
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ZenNotifications.showSuccess(
                      context,
                      title: 'Routines updated',
                      message: 'Your choice is saved on this phone.',
                    );
                  },
          ),
          const SizedBox(height: PebbleSpacing.xxs),
          PebbleButton.tertiary(
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
        ],
      ),
    );
  }
}

String _stepLabel(int steps) => '$steps ${steps == 1 ? 'step' : 'steps'}';

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.icon,
    required this.title,
    required this.body,
    required this.children,
    this.scrollable = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = <Widget>[
      Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outline.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        body,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: cs.onSurface.withValues(alpha: 0.74),
        ),
      ),
      const SizedBox(height: 20),
      ...children,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: scrollable
            ? ListView(shrinkWrap: true, children: content)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
      ),
    );
  }
}

/// Home card that appears only when the end of Premium changes something the
/// user cares about: a removal date, or routines that are locked.
class PremiumLapseNoticeCard extends ConsumerWidget {
  const PremiumLapseNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(premiumLapseSummaryProvider);
    if (!summary.needsAttention) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final message = premiumLapseHeadline(summary);
    final limit = summary.freeRoutineLimit;

    return Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => GoRouter.of(context).push('/account-hub'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.clock3, size: 18, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium ended',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.76),
                      ),
                    ),
                    if (summary.hasMoreRoutinesThanFree) ...[
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => showKeepRoutinesSheet(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text('Choose your $limit routines'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-line summary used on Home. Routines come first: which ones stay
/// is the choice the user has to make. History only hides, so it comes
/// second and only when routines aren't affected.
String premiumLapseHeadline(PremiumLapseSummary summary) {
  final limit = summary.freeRoutineLimit;
  final total = summary.routineCount;
  if (summary.inGrace) {
    final date = summary.graceEndDateLabel;
    if (summary.hasMoreRoutinesThanFree) {
      return 'From $date, Free keeps $limit of your $total routines. '
          'Choose which $limit. Nothing is deleted.';
    }
    return 'From $date, History shows the last 48 hours. Nothing is deleted.';
  }
  final locked = summary.lockedRoutineCount;
  return 'Free keeps $limit of your $total routines. The other $locked '
      '${locked == 1 ? 'is' : 'are'} locked, not deleted.';
}
