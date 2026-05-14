import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';

class RoutineComposerStepRow extends StatelessWidget {
  const RoutineComposerStepRow({
    required this.rowKey,
    required this.index,
    required this.step,
    required this.isPrimaryEntryPoint,
    required this.controller,
    required this.focusNode,
    required this.isExpanded,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onDelete,
    required this.onToggleRequiresPhoto,
    required this.onToggleAllowSkip,
    required this.onVoiceTip,
    super.key,
  });

  final GlobalKey rowKey;
  final int index;
  final RoutineComposerStepDraft step;
  final bool isPrimaryEntryPoint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isExpanded;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onSubmitted;
  final VoidCallback onDelete;
  final VoidCallback onToggleRequiresPhoto;
  final VoidCallback onToggleAllowSkip;
  final VoidCallback onVoiceTip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        key: rowKey,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 7),
        child: isExpanded
            ? _buildActiveCard(context)
            : _buildSettledRow(context),
      ),
    );
  }

  Widget _buildSettledRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = step.text.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StepNumber(index: index, active: false),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text.isEmpty
                  ? (isPrimaryEntryPoint
                        ? 'Start with your first step'
                        : 'Step')
                  : text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: text.isEmpty
                    ? cs.onSurface.withValues(alpha: 0.36)
                    : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 9),
          _StepBadges(step: step),
        ],
      ),
    );
  }

  Widget _buildActiveCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StepNumber(index: index, active: true),
                const SizedBox(width: 11),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: onTap,
                    onChanged: _handleChanged,
                    onSubmitted: (_) => onSubmitted(),
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: null,
                    cursorColor: cs.primary,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      hintText: isPrimaryEntryPoint
                          ? 'Start with your first step'
                          : 'Step',
                      hintStyle: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.32),
                        height: 1.35,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Delete step',
                  child: IconButton(
                    onPressed: onDelete,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(36, 36),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      backgroundColor: cs.error.withValues(alpha: 0.08),
                      foregroundColor: cs.error.withValues(alpha: 0.86),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 15),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.62)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _StepOptionPill(
                    tooltip: step.requiresPhoto
                        ? 'Pebble will ask for a photo before this step can be marked complete.'
                        : 'This step will not ask for a photo when the routine is run.',
                    icon: LucideIcons.camera,
                    label: 'Require photo',
                    tone: _StepOptionTone.amber,
                    active: step.requiresPhoto,
                    onPressed: onToggleRequiresPhoto,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _StepOptionPill(
                    tooltip: step.allowSkip ? 'Optional step' : 'Required step',
                    icon: step.allowSkip
                        ? LucideIcons.circle
                        : LucideIcons.check,
                    label: step.allowSkip ? 'Optional' : 'Required',
                    tone: _StepOptionTone.sage,
                    active: !step.allowSkip,
                    onPressed: onToggleAllowSkip,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _StepOptionPill(
                    tooltip: step.guidanceAudio == null
                        ? 'Add voice tip'
                        : 'Voice tip recorded',
                    icon: step.guidanceAudio == null
                        ? LucideIcons.plus
                        : LucideIcons.check,
                    label: step.guidanceAudio == null
                        ? 'Voice tip'
                        : 'Voice tip ✓',
                    tone: _StepOptionTone.clay,
                    active: step.guidanceAudio != null,
                    onPressed: onVoiceTip,
                  ),
                ),
              ],
            ),
          ),
          if (step.requiresPhoto) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 13,
                    color: cs.onSurface.withValues(alpha: 0.48),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Pebble will ask for a photo before this step can be marked complete.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleChanged(String value) {
    if (value.contains('\n')) {
      final cleaned = value.replaceAll('\n', '');
      onChanged(cleaned);
      onSubmitted();
      return;
    }
    onChanged(value);
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.index, required this.active});

  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.34),
        ),
      ),
    );
  }
}

class _StepBadges extends StatelessWidget {
  const _StepBadges({required this.step});

  final RoutineComposerStepDraft step;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (step.requiresPhoto)
        const _StepBadge(icon: LucideIcons.camera, tone: _StepOptionTone.amber),
      if (step.allowSkip)
        const _StepBadge(
          icon: LucideIcons.circle,
          tone: _StepOptionTone.neutral,
        ),
      if (step.guidanceAudio != null)
        const _StepBadge(icon: LucideIcons.volume2, tone: _StepOptionTone.clay),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < badges.length; index += 1) ...[
          if (index > 0) const SizedBox(width: 5),
          badges[index],
        ],
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.icon, required this.tone});

  final IconData icon;
  final _StepOptionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _StepToneColors.resolve(context, tone, active: true);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 13, color: colors.foreground),
    );
  }
}

class _StepOptionPill extends StatelessWidget {
  const _StepOptionPill({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.tone,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final _StepOptionTone tone;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = _StepToneColors.resolve(context, tone, active: active);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 13),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.foreground,
              backgroundColor: colors.background,
              side: BorderSide(color: colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepOptionTone { neutral, amber, sage, clay }

class _StepToneColors {
  const _StepToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;

  static _StepToneColors resolve(
    BuildContext context,
    _StepOptionTone tone, {
    required bool active,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (!active || tone == _StepOptionTone.neutral) {
      return _StepToneColors(
        foreground: cs.onSurface.withValues(alpha: 0.38),
        background: Colors.transparent,
        border: cs.outline.withValues(alpha: 0.72),
      );
    }

    final color = switch (tone) {
      _StepOptionTone.amber => cs.primary,
      _StepOptionTone.sage => cs.secondary,
      _StepOptionTone.clay => cs.error,
      _StepOptionTone.neutral => cs.onSurface,
    };

    return _StepToneColors(
      foreground: color,
      background: color.withValues(alpha: 0.12),
      border: color.withValues(alpha: 0.30),
    );
  }
}
