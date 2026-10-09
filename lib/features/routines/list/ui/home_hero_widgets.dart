import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';

/// How backup shows on the Home avatar: an 8 px dot, or nothing when backup
/// is off (DESIGN_DIRECTION.md §5 Home 3).
enum HomeBackupDot { none, backedUp, paused }

HomeBackupDot homeBackupDotFor(BackupStatus status) {
  return switch (status.phase) {
    BackupPhase.upToDate || BackupPhase.backingUp => HomeBackupDot.backedUp,
    // Changes waiting a moment are normal; only a real problem, or backup
    // paused while Premium is still wanted, earns the amber dot.
    BackupPhase.needsAttention ||
    BackupPhase.paused ||
    BackupPhase.signedOut => HomeBackupDot.paused,
    BackupPhase.waiting =>
      status.offline ? HomeBackupDot.none : HomeBackupDot.backedUp,
    BackupPhase.notIncluded ||
    BackupPhase.off ||
    BackupPhase.checking => HomeBackupDot.none,
  };
}

/// The Account control in the Home header: the same 44 glass circle as
/// Settings, with backup reduced to a status dot (green backed up, amber
/// paused or needing attention, none when off). The full status is in the
/// hint for screen readers and on the Account screen.
class HomeAccountButton extends ConsumerWidget {
  const HomeAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider);
    final dot = homeBackupDotFor(status);
    final foundation = context.darkFoundation;
    final dotColor = switch (dot) {
      HomeBackupDot.backedUp => context.done,
      HomeBackupDot.paused => Theme.of(context).colorScheme.tertiary,
      HomeBackupDot.none => null,
    };
    return Semantics(
      hint: status.phase == BackupPhase.notIncluded ? null : status.headline,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PebbleGlassIconButton(
            flat: true,
            tooltip: 'Your account',
            icon: LucideIcons.userRound,
            onPressed: () => context.push('/account-hub'),
          ),
          if (dotColor != null)
            Positioned(
              key: ValueKey('home_backup_dot_${dot.name}'),
              top: 4,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: foundation.bgBase, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Up to two earlier checks of the routine, under the Checked card, so
/// "when did I last do this?" rarely needs a trip to History.
class HomeEarlierChecks extends StatelessWidget {
  const HomeEarlierChecks({
    super.key,
    required this.runs,
    required this.onOpen,
  });

  final List<RoutineRun> runs;
  final ValueChanged<RoutineRun> onOpen;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) return const SizedBox.shrink();
    final type = PebbleType.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String dayLabel(DateTime at) {
      final day = DateTime(at.year, at.month, at.day);
      if (day == today) return 'Today';
      if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return MaterialLocalizations.of(context).formatMediumDate(at);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kept quiet: sentence case and caption size, so the past checks sit
        // behind the Checked card rather than competing with it.
        Text(
          'Earlier',
          style: type.caption.copyWith(color: context.readableSecondaryText),
        ),
        const SizedBox(height: PebbleSpacing.xs),
        for (final run in runs)
          InkWell(
            borderRadius: PebbleRadius.mdAll,
            onTap: () => onOpen(run),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dayLabel(run.finishedAt)} · '
                      '${formatCheckTime(context, run.finishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption.copyWith(
                        color: context.readableSecondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: PebbleSpacing.sm),
                  Text(
                    _tallyLabel(RunStepTally.fromRun(run)),
                    style: type.caption.copyWith(
                      color: context.readableSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _tallyLabel(RunStepTally tally) {
    final total = tally.total;
    if (total == 0) return 'Checked';
    final steps = total == 1 ? 'step' : 'steps';
    return tally.skipped == 0 && tally.done >= total
        ? 'all $total $steps'
        : '${tally.done} of $total $steps';
  }
}

/// "Make it yours": shown once on Home after a few checks, to point at Style
/// Studio. Tapping it opens Style; the cross hides it for good.
class HomeMakeItYoursCard extends StatelessWidget {
  const HomeMakeItYoursCard({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final foundation = context.darkFoundation;
    final brightness = Theme.of(context).brightness;
    return Material(
      key: const ValueKey('home_make_it_yours'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(PebbleRadius.md),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PebbleRadius.md),
            border: Border.all(color: foundation.borderSubtle),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final stone in RoutinePalette.stones.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: stone.forBrightness(brightness),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 14, height: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: PebbleSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Make it yours',
                      style: type.body.copyWith(
                        color: foundation.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Pick a colour, an icon and a header for this routine',
                      style: type.caption.copyWith(
                        color: context.readableSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide',
                onPressed: onDismiss,
                icon: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: context.readableSecondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
