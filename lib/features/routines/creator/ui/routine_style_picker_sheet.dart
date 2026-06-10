import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';

class RoutineStylePickerResult {
  final String iconKey;
  final int colorHex;

  const RoutineStylePickerResult({
    required this.iconKey,
    required this.colorHex,
  });
}

class RoutineStylePickerSheet extends StatefulWidget {
  final String initialIconKey;
  final Color initialColor;
  final List<RoutineVisualIcon> iconChoices;
  final List<Color>? swatches;
  final bool hasPremiumIconAccess;
  final VoidCallback? onPremiumIconTap;
  final bool showInlineSave;
  final bool showInlinePreview;

  const RoutineStylePickerSheet({
    super.key,
    required this.initialIconKey,
    required this.initialColor,
    required this.iconChoices,
    this.swatches,
    required this.hasPremiumIconAccess,
    this.onPremiumIconTap,
    this.showInlineSave = true,
    this.showInlinePreview = true,
  });

  static Widget asScaffold({
    required BuildContext context,
    required String initialIconKey,
    required Color initialColor,
    required List<RoutineVisualIcon> iconChoices,
    List<Color>? swatches,
    required bool hasPremiumIconAccess,
    VoidCallback? onPremiumIconTap,
    String title = 'Style',
  }) {
    final cs = Theme.of(context).colorScheme;
    final GlobalKey<_RoutineStylePickerSheetState> key =
        GlobalKey<_RoutineStylePickerSheetState>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            PebbleSubpageHeader(
              title: title,
              subtitle: hasPremiumIconAccess
                  ? 'Premium icons and colors for this routine.'
                  : 'Unlock Premium to personalize routine style.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _LivePreviewWrapper(stateKey: key),
            ),
            Expanded(
              child: RoutineStylePickerSheet(
                key: key,
                initialIconKey: initialIconKey,
                initialColor: initialColor,
                iconChoices: iconChoices,
                swatches: swatches,
                hasPremiumIconAccess: hasPremiumIconAccess,
                onPremiumIconTap: onPremiumIconTap,
                showInlineSave: false,
                showInlinePreview: false,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final state = key.currentState;
                final icon = state?._selectedIcon;
                final color = state?._color ?? initialColor;
                Navigator.pop(
                  context,
                  RoutineStylePickerResult(
                    iconKey: RoutineIconCatalog.sanitizeForStorage(
                      icon?.key ?? initialIconKey,
                      hasPremiumAccess: hasPremiumIconAccess,
                    ),
                    colorHex: color.toARGB32(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor:
                    ThemeData.estimateBrightnessForColor(cs.primary) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save style',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildPinnedPreview({
    required BuildContext context,
    required RoutineVisualIcon icon,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            cs.surfaceContainerHighest.withValues(alpha: 0.34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.2),
      ),
      child: Row(
        children: [
          _IconBubble(icon: icon.icon, color: color, size: 68),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live style',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: cs.onSurface.withValues(alpha: 0.48),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Icon and accent preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PreviewDot(color: color),
                    const SizedBox(width: 6),
                    _PreviewDot(color: color.withValues(alpha: 0.62)),
                    const SizedBox(width: 6),
                    _PreviewDot(color: color.withValues(alpha: 0.34)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<RoutineStylePickerSheet> createState() =>
      _RoutineStylePickerSheetState();
}

class _RoutineStylePickerSheetState extends State<RoutineStylePickerSheet> {
  late RoutineVisualIcon _selectedIcon;
  late Color _color;
  final ValueNotifier<int> _previewTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _selectedIcon = RoutineIconCatalog.resolve(widget.initialIconKey);
    if (_selectedIcon.isPremium && !widget.hasPremiumIconAccess) {
      _selectedIcon = RoutineIconCatalog.resolve(RoutineIconCatalog.defaultKey);
    }
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _previewTick.dispose();
    super.dispose();
  }

  void _bumpPreview() {
    _previewTick.value++;
  }

  List<Color> _getThemeColors() {
    final cs = Theme.of(context).colorScheme;
    final expanded = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      const Color(0xFFFF5252),
      const Color(0xFFE53935),
      const Color(0xFFD81B60),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF1976D2),
      const Color(0xFF0288D1),
      const Color(0xFF00897B),
      const Color(0xFF388E3C),
      const Color(0xFF689F38),
      const Color(0xFFFBC02D),
      const Color(0xFFFFA000),
      const Color(0xFFF57C00),
      const Color(0xFFE64A19),
      const Color(0xFF8D6E63),
      const Color(0xFF616161),
      const Color(0xFF455A64),
    ];

    if (widget.swatches == null || widget.swatches!.isEmpty) return expanded;

    final merged = <Color>[...widget.swatches!, ...expanded];
    final seen = <int>{};
    final deduped = <Color>[];
    for (final c in merged) {
      if (seen.add(c.toARGB32())) deduped.add(c);
    }
    return deduped;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showInlinePreview) ...[
              _buildPreviewCard(),
              const SizedBox(height: 24),
            ],
            _buildIconSection(),
            const SizedBox(height: 24),
            _buildColorSection(),
            if (widget.showInlineSave) ...[
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildPreviewCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: 0.15),
            _color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _color.withValues(alpha: 0.28), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBubble(icon: _selectedIcon.icon, color: _color, size: 64),
          const SizedBox(width: 12),
          Text(
            'Style preview',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconSection() {
    final cs = Theme.of(context).colorScheme;
    final baseIcons = widget.iconChoices
        .where((icon) => !icon.isPremium)
        .toList();
    final premiumIcons = widget.iconChoices
        .where((icon) => icon.isPremium)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Icon',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.hasPremiumIconAccess
              ? 'Pick the signal that makes this routine instantly recognizable.'
              : 'Unlock Personal Premium to personalize icons and colors.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.hasPremiumIconAccess)
          _buildIconGrid(widget.iconChoices, isPremiumSection: false)
        else ...[
          _buildIconGrid(baseIcons, isPremiumSection: false),
          const SizedBox(height: 14),
          _PremiumLockedStrip(colorScheme: cs),
          const SizedBox(height: 12),
          _buildIconGrid(premiumIcons, isPremiumSection: true),
        ],
      ],
    );
  }

  Widget _buildIconGrid(
    List<RoutineVisualIcon> icons, {
    required bool isPremiumSection,
  }) {
    final cs = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final iconChoice = icons[index];
        final selected = iconChoice.key == _selectedIcon.key;
        final isLocked = iconChoice.isPremium && !widget.hasPremiumIconAccess;
        final baseTileColor = isPremiumSection
            ? const Color(0xFFB88746).withValues(alpha: 0.14)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isLocked) {
                widget.onPremiumIconTap?.call();
                return;
              }
              setState(() {
                _selectedIcon = iconChoice;
                _bumpPreview();
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? _color.withValues(alpha: 0.15)
                    : baseTileColor,
                border: Border.all(
                  color: selected ? _color : cs.outline.withValues(alpha: 0.22),
                  width: selected ? 2.2 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      iconChoice.icon,
                      size: 22,
                      color: isLocked
                          ? cs.onSurface.withValues(alpha: 0.72)
                          : _color.withValues(alpha: selected ? 1.0 : 0.85),
                    ),
                  ),
                  if (isLocked)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: cs.surface.withValues(alpha: 0.95),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          LucideIcons.lock,
                          size: 7,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Accent color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _getThemeColors().map((c) {
            final selected = c.toARGB32() == _color.toARGB32();
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _color = c;
                    _bumpPreview();
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? cs.onSurface
                          : Colors.white.withValues(alpha: 0.25),
                      width: selected ? 3 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: _getContrastColor(c),
                          size: 24,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: () {
          Navigator.pop(
            context,
            RoutineStylePickerResult(
              iconKey: RoutineIconCatalog.sanitizeForStorage(
                _selectedIcon.key,
                hasPremiumAccess: widget.hasPremiumIconAccess,
              ),
              colorHex: _color.toARGB32(),
            ),
          );
        },
        style: FilledButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: _getContrastColor(_color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Save style',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LivePreviewWrapper extends StatefulWidget {
  final GlobalKey<_RoutineStylePickerSheetState> stateKey;

  const _LivePreviewWrapper({required this.stateKey});

  @override
  State<_LivePreviewWrapper> createState() => _LivePreviewWrapperState();
}

class _LivePreviewWrapperState extends State<_LivePreviewWrapper> {
  ValueNotifier<int>? _notifier;

  void _tryAttach() {
    final state = widget.stateKey.currentState;
    if (state != null && _notifier != state._previewTick) {
      setState(() => _notifier = state._previewTick);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAttach());
  }

  @override
  void didUpdateWidget(covariant _LivePreviewWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateKey != widget.stateKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAttach());
      return;
    }
    _tryAttach();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.stateKey.currentState;
    if (_notifier == null || state == null) {
      return RoutineStylePickerSheet.buildPinnedPreview(
        context: context,
        icon: RoutineIconCatalog.resolve(RoutineIconCatalog.defaultKey),
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _notifier!,
      builder: (context, _, __) {
        final current = widget.stateKey.currentState;
        final icon =
            current?._selectedIcon ??
            RoutineIconCatalog.resolve(RoutineIconCatalog.defaultKey);
        final color = current?._color ?? Theme.of(context).colorScheme.primary;
        return RoutineStylePickerSheet.buildPinnedPreview(
          context: context,
          icon: icon,
          color: color,
        );
      },
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBubble({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = size;
    final iconSize = tileSize * 0.42;
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tileSize * 0.28),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}

class _PreviewDot extends StatelessWidget {
  final Color color;

  const _PreviewDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
    );
  }
}

class _PremiumLockedStrip extends StatelessWidget {
  final ColorScheme colorScheme;

  const _PremiumLockedStrip({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB88746).withValues(alpha: 0.2),
            const Color(0xFF7A5A2E).withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.lock,
            size: 15,
            color: colorScheme.onSurface.withValues(alpha: 0.76),
          ),
          const SizedBox(width: 8),
          Text(
            'Personal Premium styles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
