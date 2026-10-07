import 'package:flutter/material.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// Shows a [PebbleSimpleSheet] (or any sheet body) on the standard surface.
Future<T?> showPebbleSimpleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final foundation = context.darkFoundation;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: foundation.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// A short decision sheet: a title, at most a line or two, an optional
/// block (a consent statement, a list), one primary button, one quiet
/// secondary, and an optional "More details" link.
///
/// The point is restraint: anything longer than two lines belongs behind
/// [detailsLabel], not in the body.
class PebbleSimpleSheet extends StatelessWidget {
  const PebbleSimpleSheet({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryBusy = false,
    this.destructive = false,
    this.secondaryLabel = 'Not now',
    this.onSecondary,
    this.detailsLabel,
    this.onDetails,
    this.icon,
  });

  final String title;
  final String? body;
  final Widget? content;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryBusy;
  final bool destructive;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? detailsLabel;
  final VoidCallback? onDetails;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: PebbleRadius.pillAll,
                  color: foundation.borderSubtle,
                ),
              ),
            ),
            const SizedBox(height: PebbleSpacing.xl),
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      context.doneContainer,
                      foundation.surfaceLow,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: foundation.textPrimary),
                ),
              ),
              const SizedBox(height: PebbleSpacing.md),
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                style: type.sheetTitle.copyWith(color: foundation.textPrimary),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: PebbleSpacing.xs),
              Text(
                body!,
                style: type.body.copyWith(color: context.readableSecondaryText),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: PebbleSpacing.md),
              content!,
            ],
            const SizedBox(height: PebbleSpacing.xl),
            if (destructive)
              PebbleButton.destructive(
                label: primaryLabel,
                onPressed: onPrimary,
                busy: primaryBusy,
                filled: true,
                expand: true,
              )
            else
              PebbleButton.primary(
                label: primaryLabel,
                onPressed: onPrimary,
                busy: primaryBusy,
              ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: PebbleSpacing.xs),
              PebbleButton.tertiary(
                label: secondaryLabel!,
                expand: true,
                onPressed: onSecondary ?? () => Navigator.of(context).pop(),
              ),
            ],
            if (detailsLabel != null && onDetails != null) ...[
              const SizedBox(height: PebbleSpacing.xxs),
              Center(
                child: TextButton(
                  onPressed: onDetails,
                  child: Text(
                    detailsLabel!,
                    style: type.caption.copyWith(
                      color: context.readableSecondaryText,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A quoted statement in a soft box: what the person is agreeing to, shown
/// word for word, right above the button that agrees to it.
class PebbleStatementBox extends StatelessWidget {
  const PebbleStatementBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    return Container(
      padding: const EdgeInsets.all(PebbleSpacing.md),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: PebbleRadius.mdAll,
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Text(
        text,
        style: type.caption.copyWith(
          color: foundation.textPrimary.withValues(alpha: 0.82),
          height: 1.45,
        ),
      ),
    );
  }
}

/// A plain page of detail text ("How backup works"), pushed on demand so the
/// main screens can stay short.
class PebbleDetailsPage extends StatelessWidget {
  const PebbleDetailsPage({
    super.key,
    required this.title,
    required this.sections,
    this.footer,
  });

  final String title;

  /// Optional extra at the end, such as a link to the privacy policy.
  final Widget? footer;

  /// (heading, paragraph) pairs. A null heading is a plain paragraph.
  final List<(String?, String)> sections;

  static Future<void> push(
    BuildContext context, {
    required String title,
    required List<(String?, String)> sections,
    Widget? footer,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PebbleDetailsPage(title: title, sections: sections, footer: footer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    return Scaffold(
      backgroundColor: foundation.bgBase,
      appBar: AppBar(
        backgroundColor: foundation.bgBase,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: type.headline.copyWith(color: foundation.textPrimary),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            for (final (heading, paragraph) in sections) ...[
              if (heading != null) ...[
                Text(
                  heading,
                  style: type.headline.copyWith(color: foundation.textPrimary),
                ),
                const SizedBox(height: PebbleSpacing.xxs),
              ],
              Text(
                paragraph,
                style: type.body.copyWith(color: context.readableSecondaryText),
              ),
              const SizedBox(height: PebbleSpacing.lg),
            ],
            ?footer,
          ],
        ),
      ),
    );
  }
}
