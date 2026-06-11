import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';

class AccountBackupHeaderAction extends ConsumerWidget {
  const AccountBackupHeaderAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chip = ref.watch(accountBackupChipStateProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chip.show) ...[
          _BackupStatusChip(state: chip),
          const SizedBox(width: 8),
        ],
        Semantics(
          button: true,
          label: 'Your account',
          child: Tooltip(
            message: 'Your account',
            child: InkResponse(
              radius: 24,
              onTap: () {
                context.push('/account-hub');
              },
              child: SizedBox(
                width: 40,
                height: 48,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.58),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.userRound,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupStatusChip extends StatelessWidget {
  const _BackupStatusChip({required this.state});

  final AccountBackupChipState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = switch (state.tone) {
      AccountBackupChipTone.positive => colorScheme.primary,
      AccountBackupChipTone.neutral => colorScheme.onSurface.withValues(
        alpha: 0.62,
      ),
      AccountBackupChipTone.attention => colorScheme.error,
    };
    final icon = switch (state.tone) {
      AccountBackupChipTone.positive => LucideIcons.cloudCheck,
      AccountBackupChipTone.neutral => LucideIcons.cloudOff,
      AccountBackupChipTone.attention => LucideIcons.cloudAlert,
    };

    return Semantics(
      button: true,
      label: 'Backup',
      hint: state.semanticsHint,
      child: Material(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () {
            context.push('/cloud-backup');
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 11, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: accent),
                const SizedBox(width: 5),
                Text(
                  state.label,
                  style: GoogleFonts.outfit(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
