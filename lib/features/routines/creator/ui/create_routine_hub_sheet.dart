import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_draft_snapshot.dart';

/// Bouncy button generic handler that scales to 0.97 and fires a light haptic tap
class ZenBounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ZenBounceButton({super.key, required this.child, required this.onTap});

  @override
  State<ZenBounceButton> createState() => _ZenBounceButtonState();
}

class _ZenBounceButtonState extends State<ZenBounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class CreateHubSheet extends ConsumerWidget {
  const CreateHubSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const CreateHubSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = context.darkFoundation;
    final draftAsync = ref.watch(latestCreateRoutineDraftProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 18, 24, bottomInset + 28),
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: foundation.borderSubtle, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: foundation.borderSubtle,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Create',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: foundation.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start fresh, continue a draft, or use a calm starting point.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.35,
                color: foundation.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            if (draftAsync.valueOrNull != null) ...[
              _CreateChoiceCard(
                icon: LucideIcons.fileClock,
                title: 'Resume draft',
                subtitle: _draftSubtitle(draftAsync.valueOrNull!),
                isPrimary: true,
                onTap: () => _handleResumeDraft(context, ref),
              ),
              const SizedBox(height: 12),
            ],
            _CreateChoiceCard(
              icon: LucideIcons.plus,
              title: 'Blank routine',
              subtitle: 'Write your own steps from scratch.',
              onTap: () =>
                  _handleBlankRoutine(context, ref, draftAsync.valueOrNull),
            ),
            const SizedBox(height: 12),
            _CreateChoiceCard(
              icon: LucideIcons.layoutTemplate,
              title: 'Browse templates',
              subtitle: 'Start from one of Pebble’s ready-made routines.',
              onTap: () {
                Navigator.of(context).pop();
                GoRouter.of(context).push('/templates');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _draftSubtitle(RoutineComposerDraftSnapshot draft) {
    final stepCount = draft.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    final title = draft.title.trim().isEmpty
        ? 'Untitled routine'
        : draft.title.trim();
    return '$title • $stepCount step${stepCount == 1 ? '' : 's'}';
  }

  Future<void> _handleBlankRoutine(
    BuildContext context,
    WidgetRef ref,
    RoutineComposerDraftSnapshot? draft,
  ) async {
    final currentDraft = draft == null
        ? null
        : await ref
              .read(routineComposerDraftRepositoryProvider)
              .latestCreateDraft();
    if (draft != null) {
      ref.invalidate(latestCreateRoutineDraftProvider);
    }

    if (!context.mounted) return;
    if (currentDraft == null) {
      Navigator.of(context).pop();
      GoRouter.of(context).push('/creator?fresh=1');
      return;
    }

    final action = await showModalBottomSheet<_CreateDraftAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => _CreateDraftChoiceSheet(draft: currentDraft),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case _CreateDraftAction.resume:
        Navigator.of(context).pop();
        GoRouter.of(context).push('/creator');
        break;
      case _CreateDraftAction.startFresh:
        await ref
            .read(routineComposerDraftRepositoryProvider)
            .clearCreateDrafts();
        ref.invalidate(latestCreateRoutineDraftProvider);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        GoRouter.of(context).push('/creator?fresh=1');
        break;
      case _CreateDraftAction.discard:
        await ref
            .read(routineComposerDraftRepositoryProvider)
            .clearCreateDrafts();
        ref.invalidate(latestCreateRoutineDraftProvider);
        break;
    }
  }

  Future<void> _handleResumeDraft(BuildContext context, WidgetRef ref) async {
    final currentDraft = await ref
        .read(routineComposerDraftRepositoryProvider)
        .latestCreateDraft();
    ref.invalidate(latestCreateRoutineDraftProvider);
    if (!context.mounted || currentDraft == null) return;
    Navigator.of(context).pop();
    GoRouter.of(context).push('/creator');
  }
}

enum _CreateDraftAction { resume, startFresh, discard }

class _CreateDraftChoiceSheet extends StatelessWidget {
  const _CreateDraftChoiceSheet({required this.draft});

  final RoutineComposerDraftSnapshot draft;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 18, 24, bottomInset + 24),
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: foundation.borderSubtle, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: foundation.borderSubtle,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Resume draft?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: foundation.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You already have a routine draft. Start fresh only if you are ready to replace it.',
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w400,
                color: foundation.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _DraftActionButton(
              icon: LucideIcons.fileClock,
              label: 'Resume draft',
              description: _draftSummary(draft),
              isPrimary: true,
              onTap: () {
                Navigator.of(context).pop(_CreateDraftAction.resume);
              },
            ),
            const SizedBox(height: 10),
            _DraftActionButton(
              icon: LucideIcons.plus,
              label: 'Start fresh',
              description: 'Replace this draft with a blank routine.',
              onTap: () {
                Navigator.of(context).pop(_CreateDraftAction.startFresh);
              },
            ),
            const SizedBox(height: 10),
            _DraftActionButton(
              icon: LucideIcons.trash2,
              label: 'Discard draft',
              description: 'Remove this draft from Create.',
              isDestructive: true,
              onTap: () {
                Navigator.of(context).pop(_CreateDraftAction.discard);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _draftSummary(RoutineComposerDraftSnapshot draft) {
    final stepCount = draft.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    final title = draft.title.trim().isEmpty
        ? 'Untitled routine'
        : draft.title.trim();
    return '$title - $stepCount step${stepCount == 1 ? '' : 's'}';
  }
}

class _DraftActionButton extends StatelessWidget {
  const _DraftActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foundation = context.darkFoundation;
    final accent = isDestructive
        ? cs.error
        : isPrimary
        ? cs.primary
        : foundation.textSecondary;

    return ZenBounceButton(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPrimary ? foundation.surfaceHigh : foundation.surfaceLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPrimary
                ? cs.primary.withValues(alpha: 0.22)
                : foundation.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? cs.error : foundation.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: foundation.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChoiceCard extends StatelessWidget {
  const _CreateChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foundation = context.darkFoundation;
    final accent = isPrimary ? cs.primary : foundation.textSecondary;

    return ZenBounceButton(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? foundation.surfaceHigh : foundation.surfaceLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPrimary
                ? cs.primary.withValues(alpha: 0.2)
                : foundation.borderSubtle,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: foundation.shadowSoft,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: foundation.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: foundation.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: foundation.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
