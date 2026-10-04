import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// The kinds in Pebble's one button set (DESIGN_DIRECTION.md §3.7).
enum PebbleButtonKind {
  /// Filled action colour, 56 high, full width. One per screen.
  primary,

  /// Tonal: action at 10% with an action-coloured label, 52 high, no border.
  secondary,

  /// Text only in the readable secondary colour, at least 44 high.
  tertiary,

  /// Text in the error colour; filled red only inside a final confirmation.
  destructive,

  /// Tonal capsule, 40 high, caption-sized label. Inline.
  compact,
}

/// Pebble's button. Every kind is a capsule, uses the DM Sans `button` style,
/// grows with large text instead of clipping, and gives a 0.97 press scale
/// (skipped under Reduce Motion).
///
/// While [busy] the button shows a spinner, ignores taps and keeps its
/// enabled colours.
class PebbleButton extends StatefulWidget {
  const PebbleButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.busy = false,
    this.expand = true,
    this.semanticsLabel,
  }) : kind = PebbleButtonKind.primary,
       filled = true;

  const PebbleButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.busy = false,
    this.expand = true,
    this.semanticsLabel,
  }) : kind = PebbleButtonKind.secondary,
       filled = false;

  const PebbleButton.tertiary({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
    this.semanticsLabel,
  }) : kind = PebbleButtonKind.tertiary,
       filled = false;

  /// Red text. Pass [filled] only for the final step of a destructive
  /// confirmation sheet.
  const PebbleButton.destructive({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
    this.filled = false,
    this.semanticsLabel,
  }) : kind = PebbleButtonKind.destructive;

  const PebbleButton.compact({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
    this.semanticsLabel,
  }) : kind = PebbleButtonKind.compact,
       filled = false;

  final PebbleButtonKind kind;
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool busy;

  /// Fill the available width (default for primary and secondary).
  final bool expand;

  /// Destructive only: a filled red button.
  final bool filled;
  final String? semanticsLabel;

  static const double primaryHeight = 56;
  static const double secondaryHeight = 52;
  static const double tertiaryHeight = 44;
  static const double compactHeight = 40;

  @override
  State<PebbleButton> createState() => _PebbleButtonState();
}

class _PebbleButtonState extends State<PebbleButton> {
  static const double maxLabelScale = 1.6;

  bool _pressed = false;

  bool get _interactive => widget.onPressed != null && !widget.busy;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final type = PebbleType.of(context);
    final foundation = context.darkFoundation;
    final fg = foundation.textPrimary;

    // The doc's `action` role: the structural primary (equal to
    // actionAccent in every single-accent theme).
    final action = cs.primary;
    final tonalLabel = context.readableAccentText(action);

    late final Color background;
    late final Color foreground;
    late final double minHeight;
    late final TextStyle textStyle;
    var horizontalPadding = PebbleSpacing.xl;

    switch (widget.kind) {
      case PebbleButtonKind.primary:
        background = context.readableActionFill;
        foreground = cs.onPrimary;
        minHeight = PebbleButton.primaryHeight;
        textStyle = type.button;
      case PebbleButtonKind.secondary:
        background = action.withValues(alpha: 0.10);
        foreground = tonalLabel;
        minHeight = PebbleButton.secondaryHeight;
        textStyle = type.button;
      case PebbleButtonKind.tertiary:
        background = Colors.transparent;
        foreground = context.readableSecondaryText;
        minHeight = PebbleButton.tertiaryHeight;
        textStyle = type.body.copyWith(fontWeight: FontWeight.w500);
        horizontalPadding = PebbleSpacing.md;
      case PebbleButtonKind.destructive:
        background = widget.filled ? cs.error : Colors.transparent;
        foreground = widget.filled ? cs.onError : cs.error;
        minHeight = widget.filled
            ? PebbleButton.primaryHeight
            : PebbleButton.tertiaryHeight;
        textStyle = widget.filled
            ? type.button
            : type.body.copyWith(fontWeight: FontWeight.w500);
        horizontalPadding = widget.filled ? PebbleSpacing.xl : PebbleSpacing.md;
      case PebbleButtonKind.compact:
        background = action.withValues(alpha: 0.10);
        foreground = tonalLabel;
        minHeight = PebbleButton.compactHeight;
        textStyle = type.caption.copyWith(fontWeight: FontWeight.w600);
        horizontalPadding = PebbleSpacing.md;
    }

    final hasFill = background.a > 0;
    final disabledBackground = hasFill
        ? fg.withValues(alpha: 0.08)
        : Colors.transparent;
    final disabledForeground = fg.withValues(alpha: 0.38);
    final iconSize = widget.kind == PebbleButtonKind.compact ? 16.0 : 20.0;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: PebbleSpacing.xs,
        ),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      textStyle: WidgetStatePropertyAll(textStyle),
      iconSize: WidgetStatePropertyAll(iconSize),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !widget.busy
            ? disabledBackground
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !widget.busy
            ? disabledForeground
            : foreground,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !widget.busy
            ? disabledForeground
            : foreground,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? foreground.withValues(alpha: 0.10)
            : states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
            ? foreground.withValues(alpha: 0.06)
            : null,
      ),
    );

    final leading = widget.busy
        ? SizedBox(
            width: iconSize - 2,
            height: iconSize - 2,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        : widget.icon == null
        ? null
        : Icon(widget.icon, size: iconSize);

    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      semanticsLabel: widget.semanticsLabel,
    );

    final content = (leading == null && widget.trailingIcon == null)
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: PebbleSpacing.xs),
              ],
              Flexible(child: label),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: PebbleSpacing.xs),
                Icon(widget.trailingIcon, size: iconSize),
              ],
            ],
          );

    final onPressed = _interactive ? widget.onPressed : null;
    // Labels scale with the system text size up to 1.6x (17 → 27pt, about
    // what the old 15pt labels reached at 2x) and wrap beyond the width, so
    // a pinned footer of buttons never takes over the screen at 2x.
    final scaledContent = MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: content,
    );
    Widget button = hasFill
        ? FilledButton(onPressed: onPressed, style: style, child: scaledContent)
        : TextButton(onPressed: onPressed, style: style, child: scaledContent);

    if (widget.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return button;

    return Listener(
      onPointerDown: _interactive ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: PebbleMotion.tap,
        curve: _pressed ? Curves.easeOut : PebbleMotion.settleCurve,
        child: button,
      ),
    );
  }
}
