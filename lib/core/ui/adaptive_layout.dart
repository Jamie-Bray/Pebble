import 'package:flutter/widgets.dart';

/// Tier-1 large-screen support: shared primitives that keep phone layouts
/// untouched while stopping content from stretching edge-to-edge on tablets
/// and landscape phones.
///
/// Modal bottom sheets need nothing here: Material 3 already caps them at
/// 640dp and centers them (BottomSheet resolves
/// `widget.constraints ?? bottomSheetTheme.constraints ?? defaults` and the
/// M3 default is `BoxConstraints(maxWidth: 640)`).

/// Width cap for single-column content on large screens. Chosen to match the
/// M3 bottom-sheet default so capped screens and sheets read as one system.
/// Portrait phones are narrower than this, so the cap is a no-op there.
const double kContentMaxWidth = 640;

/// Column count for photo/thumbnail grids by available width: phones keep
/// [phoneColumns], tablets step up so thumbnails keep a sensible size.
int adaptiveGridColumns(double width, {int phoneColumns = 2}) {
  if (width >= 900) {
    return phoneColumns + 2;
  }
  if (width >= 600) {
    return phoneColumns + 1;
  }
  return phoneColumns;
}

/// Centers [child] and caps its width at [maxWidth]. Wrap a screen's
/// top-level scroll view in this; backgrounds and app bars should stay
/// outside so they keep filling the full screen.
class AdaptiveContentWidth extends StatelessWidget {
  const AdaptiveContentWidth({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
