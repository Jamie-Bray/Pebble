import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

class RoutineStylePickerResult {
  final String iconKey;

  /// A stone from [RoutinePalette], or null for the theme's own colour.
  final int? colorHex;

  const RoutineStylePickerResult({
    required this.iconKey,
    required this.colorHex,
  });
}

/// Style Studio: an icon and a colour for one routine. Open to everyone;
/// the free icons and the first four stones are free, the rest come with
/// Personal Premium.
class RoutineStylePickerSheet extends StatefulWidget {
  final String initialIconKey;
  final int? initialColorHex;
  final String routineTitle;
  final List<RoutineVisualIcon> iconChoices;
  final bool hasPremiumAccess;
  final VoidCallback? onPremiumTap;
  final ValueChanged<RoutineStylePickerResult>? onChanged;

  const RoutineStylePickerSheet({
    super.key,
    required this.initialIconKey,
    required this.initialColorHex,
    this.routineTitle = 'Routine',
    this.iconChoices = RoutineIconCatalog.all,
    required this.hasPremiumAccess,
    this.onPremiumTap,
    this.onChanged,
  });

  static Widget asScaffold({
    required BuildContext context,
    required String initialIconKey,
    required int? initialColorHex,
    required String routineTitle,
    required bool hasPremiumAccess,
    VoidCallback? onPremiumTap,
    String title = 'Style',
  }) {
    final foundation = context.darkFoundation;
    var current = RoutineStylePickerResult(
      iconKey: RoutineIconCatalog.resolve(initialIconKey).key,
      colorHex: initialColorHex,
    );
    return Scaffold(
      backgroundColor: foundation.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            PebbleSubpageHeader(
              title: title,
              subtitle: hasPremiumAccess
                  ? 'Pick an icon and colour for this routine.'
                  : 'Pick an icon and colour. More come with Personal Premium.',
            ),
            Expanded(
              child: RoutineStylePickerSheet(
                initialIconKey: initialIconKey,
                initialColorHex: initialColorHex,
                routineTitle: routineTitle,
                hasPremiumAccess: hasPremiumAccess,
                onPremiumTap: onPremiumTap,
                onChanged: (value) => current = value,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PebbleSpacing.lg,
            PebbleSpacing.xs,
            PebbleSpacing.lg,
            PebbleSpacing.md,
          ),
          child: Builder(
            builder: (context) => PebbleButton.primary(
              label: 'Save',
              onPressed: () => Navigator.pop(
                context,
                RoutineStylePickerResult(
                  iconKey: RoutineIconCatalog.sanitizeForStorage(
                    current.iconKey,
                    hasPremiumAccess: hasPremiumAccess,
                  ),
                  colorHex: RoutinePalette.sanitizeForStorage(
                    current.colorHex,
                    hasPremiumAccess: hasPremiumAccess,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<RoutineStylePickerSheet> createState() =>
      _RoutineStylePickerSheetState();
}

class _RoutineStylePickerSheetState extends State<RoutineStylePickerSheet> {
  late RoutineVisualIcon _icon;
  late int? _colorHex;

  @override
  void initState() {
    super.initState();
    _icon = RoutineIconCatalog.resolve(widget.initialIconKey);
    if (_icon.isPremium && !widget.hasPremiumAccess) {
      _icon = RoutineIconCatalog.resolve(RoutineIconCatalog.defaultKey);
    }
    _colorHex = widget.initialColorHex;
  }

  void _update({RoutineVisualIcon? icon, int? colorHex, bool clear = false}) {
    setState(() {
      if (icon != null) _icon = icon;
      if (clear) {
        _colorHex = null;
      } else if (colorHex != null) {
        _colorHex = colorHex;
      }
    });
    widget.onChanged?.call(
      RoutineStylePickerResult(iconKey: _icon.key, colorHex: _colorHex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        PebbleSpacing.lg,
        PebbleSpacing.xs,
        PebbleSpacing.lg,
        PebbleSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutineAccentScope(
            colorHex: _colorHex,
            child: _StylePreview(icon: _icon, title: widget.routineTitle),
          ),
          const SizedBox(height: PebbleSpacing.xl),
          Text('Colour', style: type.headline),
          const SizedBox(height: PebbleSpacing.xxs),
          Text(
            _colorName(),
            style: type.caption.copyWith(color: context.readableSecondaryText),
          ),
          const SizedBox(height: PebbleSpacing.sm),
          _buildColours(),
          const SizedBox(height: PebbleSpacing.xl),
          Text('Icon', style: type.headline),
          const SizedBox(height: PebbleSpacing.sm),
          _buildIcons(),
        ],
      ),
    );
  }

  String _colorName() {
    if (_colorHex == null || _colorHex == 0) return 'Theme colour';
    return RoutinePalette.match(_colorHex)?.name ?? 'Your earlier colour';
  }

  Widget _buildColours() {
    final brightness = Theme.of(context).brightness;
    final selectedStone = RoutinePalette.match(_colorHex);
    final noColour = _colorHex == null || _colorHex == 0;
    return Wrap(
      spacing: PebbleSpacing.sm,
      runSpacing: PebbleSpacing.sm,
      children: [
        _Swatch(
          color: context.done,
          label: 'Theme colour',
          selected: noColour,
          locked: false,
          ring: true,
          onTap: () => _update(clear: true),
        ),
        for (final stone in RoutinePalette.stones)
          _Swatch(
            color: stone.forBrightness(brightness),
            label: stone.name,
            selected: selectedStone?.key == stone.key,
            locked: stone.isPremium && !widget.hasPremiumAccess,
            onTap: stone.isPremium && !widget.hasPremiumAccess
                ? () => widget.onPremiumTap?.call()
                : () => _update(colorHex: stone.storedHex),
          ),
      ],
    );
  }

  Widget _buildIcons() {
    final accent = context.routineAccent(_colorHex) ?? context.done;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        crossAxisSpacing: PebbleSpacing.xs,
        mainAxisSpacing: PebbleSpacing.xs,
      ),
      itemCount: widget.iconChoices.length,
      itemBuilder: (context, index) {
        final choice = widget.iconChoices[index];
        final locked = choice.isPremium && !widget.hasPremiumAccess;
        return _IconTile(
          icon: choice.icon,
          label: locked ? '${choice.label}, Premium' : choice.label,
          selected: choice.key == _icon.key,
          locked: locked,
          accent: accent,
          onTap: locked
              ? () => widget.onPremiumTap?.call()
              : () => _update(icon: choice),
        );
      },
    );
  }
}

/// The routine as it will look: its icon, its name and a small cairn in its
/// colour.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.icon, required this.title});

  final RoutineVisualIcon icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final fill = Color.alphaBlend(context.doneContainer, foundation.bgBase);
    return Container(
      padding: const EdgeInsets.all(PebbleSpacing.md),
      decoration: BoxDecoration(color: fill, borderRadius: PebbleRadius.lgAll),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.done.withValues(alpha: 0.16),
              borderRadius: PebbleRadius.mdAll,
            ),
            child: Icon(icon.icon, size: 22, color: context.done),
          ),
          const SizedBox(width: PebbleSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.headline,
            ),
          ),
          const SizedBox(width: PebbleSpacing.sm),
          const ExcludeSemantics(
            child: PebbleCairn(total: 3, size: 44, showCount: false),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.ring = false,
  });

  final Color color;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  /// Drawn as a ring rather than a solid stone: "follow the theme".
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final onColor = color.computeLuminance() > 0.4
        ? const Color(0xFF1B1813)
        : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, Premium' : label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: PebbleMotion.quick,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ring ? null : color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? foundation.textPrimary
                  : ring
                  ? color
                  : Colors.transparent,
              width: ring && !selected ? 4 : 2.5,
              strokeAlign: ring
                  ? BorderSide.strokeAlignInside
                  : BorderSide.strokeAlignOutside,
            ),
          ),
          child: selected
              ? Icon(LucideIcons.check, size: 20, color: ring ? color : onColor)
              : locked
              ? Icon(
                  LucideIcons.lock,
                  size: 14,
                  color: onColor.withValues(alpha: 0.85),
                )
              : null,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.locked,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : foundation.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: PebbleRadius.smAll,
          side: BorderSide(
            color: selected ? accent : foundation.borderSubtle,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: PebbleRadius.smAll,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: locked
                      ? context.readableSecondaryText
                      : selected
                      ? accent
                      : foundation.textPrimary,
                ),
              ),
              if (locked)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(
                    LucideIcons.lock,
                    size: 10,
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
