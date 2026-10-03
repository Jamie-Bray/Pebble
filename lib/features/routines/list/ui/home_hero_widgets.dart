import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';

/// How backup shows on the Home avatar: an 8 px dot, or nothing when backup
/// is off (DESIGN_DIRECTION.md §5 Home 3).
enum HomeBackupDot { none, backedUp, paused }

HomeBackupDot homeBackupDotFor(AccountBackupChipState chip) {
  if (!chip.show || chip.label == 'Backup off') return HomeBackupDot.none;
  if (chip.tone == AccountBackupChipTone.positive) {
    return HomeBackupDot.backedUp;
  }
  return HomeBackupDot.paused;
}

/// The Account control in the Home header: the same 44 glass circle as
/// Settings, with backup reduced to a status dot (green backed up, amber
/// paused or needing attention, none when off). The full status is in the
/// hint for screen readers and on the Account screen.
class HomeAccountButton extends ConsumerWidget {
  const HomeAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chip = ref.watch(accountBackupChipStateProvider);
    final dot = homeBackupDotFor(chip);
    final foundation = context.darkFoundation;
    final dotColor = switch (dot) {
      HomeBackupDot.backedUp => context.done,
      HomeBackupDot.paused => Theme.of(context).colorScheme.tertiary,
      HomeBackupDot.none => null,
    };
    return Semantics(
      hint: chip.show ? chip.label : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PebbleGlassIconButton(
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

/// "5 steps · 1 photo · Reminder 8:15 AM". Replaces the unlabelled icon bar;
/// tapping it opens the routine's actions sheet (edit, reminders, emails…).
class HomeRoutineMetaLine extends StatelessWidget {
  const HomeRoutineMetaLine({
    super.key,
    required this.stepCount,
    required this.photoStepCount,
    required this.nextReminder,
    required this.onTap,
  });

  final int stepCount;
  final int photoStepCount;
  final DateTime? nextReminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '$stepCount ${stepCount == 1 ? 'step' : 'steps'}',
      if (photoStepCount > 0)
        '$photoStepCount ${photoStepCount == 1 ? 'photo' : 'photos'}',
      if (nextReminder != null)
        'Reminder ${formatCheckTime(context, nextReminder!)}',
    ];
    final color = context.readableSecondaryText;
    return Semantics(
      button: true,
      label: '${parts.join(', ')}. Routine actions',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Routine settings',
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('home_hero_routine_meta'),
            borderRadius: PebbleRadius.pillAll,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PebbleType.of(context).caption.copyWith(
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: PebbleSpacing.xs),
                  Icon(LucideIcons.ellipsis, size: 16, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moment 3: the Home hero after a run. A soft done-tinted card with the
/// cairn, "CHECKED", the time large, what was done and this run's photos.
class HomeCheckedCard extends ConsumerWidget {
  const HomeCheckedCard({
    super.key,
    required this.routineId,
    required this.routineTitle,
    required this.finishedAt,
    required this.tally,
    required this.photoPaths,
    this.compact = false,
  });

  final int routineId;
  final String routineTitle;
  final DateTime finishedAt;
  final RunStepTally tally;
  final List<String> photoPaths;
  final bool compact;

  static const int maxThumbs = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = Color.alphaBlend(context.doneContainer, foundation.bgBase);
    final onFill = [fill];
    final accent = ensureContrast(
      context.done,
      backgrounds: onFill,
      strongest: foundation.textPrimary,
    );
    final secondary = ensureContrast(
      foundation.textSecondary,
      backgrounds: onFill,
      strongest: foundation.textPrimary,
    );
    final overline = tally.skipped > 0
        ? 'Checked · ${tally.skipped} skipped'
        : 'Checked';
    final total = tally.total;
    final summary = total == 0
        ? routineTitle
        : tally.skipped == 0 && tally.done >= total
        ? '$routineTitle · all $total ${total == 1 ? 'step' : 'steps'}'
        : '$routineTitle · ${tally.done} of $total '
              '${total == 1 ? 'step' : 'steps'}';
    final time = formatCheckTime(context, finishedAt);
    final shown = photoPaths.take(maxThumbs).toList();
    final extra = photoPaths.length - shown.length;

    return Semantics(
      container: true,
      label: '$routineTitle, checked at $time. $summary',
      child: Container(
        key: const ValueKey('home_hero_checked_card'),
        width: double.infinity,
        padding: EdgeInsets.all(compact ? PebbleSpacing.md : PebbleSpacing.lg),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: PebbleRadius.lgAll,
          // A floating surface (§3.4): the one card on Home that lifts.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'cairn-$routineId',
                    child: PebbleCairn(
                      total: total == 0 ? 1 : total,
                      skipped: tally.skipped,
                      size: 40,
                      showCount: false,
                    ),
                  ),
                  const SizedBox(width: PebbleSpacing.sm),
                  Expanded(
                    child: Text(
                      overline.toUpperCase(),
                      key: const ValueKey('home_hero_checked_overline'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.overline.copyWith(color: accent),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? PebbleSpacing.xs : PebbleSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PebbleBigTime(
                  at: finishedAt,
                  style: type.displayXL.copyWith(
                    fontSize: compact ? 48 : 56,
                    color: foundation.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: PebbleSpacing.xxs),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.body.copyWith(color: secondary),
              ),
              if (shown.isNotEmpty) ...[
                SizedBox(height: compact ? PebbleSpacing.sm : PebbleSpacing.md),
                Row(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(width: PebbleSpacing.xs),
                      PhotoThumb(
                        key: ValueKey('home_checked_photo_$i'),
                        size: 48,
                        overlayLabel: i == shown.length - 1 && extra > 0
                            ? '+$extra'
                            : null,
                        load: () => ref
                            .read(routineSessionProofStorageProvider)
                            .resolveStoredFile(shown[i]),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
