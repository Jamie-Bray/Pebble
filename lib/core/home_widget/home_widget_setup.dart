import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/home_widget/home_widget_publisher.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';

/// Whether this platform has a Pebble home-screen widget. Only Android ships
/// one (`pebble_routine_widget_info.xml`); there is no iOS WidgetKit
/// extension yet, so every widget control stays hidden on iOS.
bool get supportsHomeScreenWidget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The platform calls the widget setup needs, behind a provider so tests can
/// replace them. Every call is best-effort: a launcher that can't answer
/// reads as "unknown", never as an error.
class HomeWidgetHost {
  const HomeWidgetHost();

  /// How many Pebble widgets are on the home screen, or null if unknown.
  Future<int?> installedWidgetCount() async {
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      return widgets.length;
    } catch (_) {
      return null;
    }
  }

  /// Whether the launcher can add the widget for the user (Android 8+, and
  /// only some launchers).
  Future<bool> canRequestPinWidget() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to show its "Add widget" prompt.
  Future<void> requestPinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: homeWidgetProviderName,
      );
    } catch (_) {
      // The numbered steps in the sheet still work.
    }
  }
}

final homeWidgetHostProvider = Provider<HomeWidgetHost>(
  (ref) => const HomeWidgetHost(),
);

/// Makes [routine] the one routine on the widget. The widget shows a single
/// routine, so every other routine stops being "on the widget". The chosen
/// routine is pinned first, so the widget never flashes empty in between.
Future<void> chooseWidgetRoutine({
  required Routine routine,
  required Iterable<Routine> routines,
  required Future<void> Function(int id, bool pinned) setPinned,
}) async {
  await setPinned(routine.id, true);
  for (final other in routines) {
    if (other.id != routine.id && other.isPinned) {
      await setPinned(other.id, false);
    }
  }
}

/// Takes every routine off the widget, which then shows its empty state.
Future<void> clearWidgetRoutine({
  required Iterable<Routine> routines,
  required Future<void> Function(int id, bool pinned) setPinned,
}) async {
  for (final routine in routines) {
    if (routine.isPinned) await setPinned(routine.id, false);
  }
}

/// After a routine is chosen for the widget: a short confirmation if the
/// widget is already on the home screen, otherwise the setup sheet.
Future<void> confirmWidgetRoutineChosen(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final count = await ref.read(homeWidgetHostProvider).installedWidgetCount();
  if (!context.mounted) return;
  if (count != null && count > 0) {
    ZenNotifications.showSuccess(
      context,
      title: 'Shown on widget',
      message: '"${routine.title}" is on your home screen widget now.',
    );
    return;
  }
  await showHomeWidgetSetupSheet(context);
}

/// The numbered steps for adding the widget by hand on [platform]. iOS has
/// its steps ready for when an iOS widget ships.
List<String> homeWidgetSetupSteps(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
      return const [
        'Touch and hold an empty spot on your Home Screen.',
        'Tap Edit, then Add Widget, and find Pebble Routines.',
        'Tap Add Widget, then Done.',
      ];
    default:
      return const [
        'Touch and hold an empty spot on your home screen.',
        'Tap Widgets and find Pebble Routines.',
        'Drag the Pebble widget to your home screen.',
      ];
  }
}

/// "Add Pebble to your home screen": an Add widget button where the launcher
/// supports it, and always three short steps to do it by hand.
Future<void> showHomeWidgetSetupSheet(BuildContext context) {
  final foundation = context.darkFoundation;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: foundation.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const HomeWidgetSetupSheet(),
  );
}

class HomeWidgetSetupSheet extends ConsumerStatefulWidget {
  const HomeWidgetSetupSheet({super.key});

  @override
  ConsumerState<HomeWidgetSetupSheet> createState() =>
      _HomeWidgetSetupSheetState();
}

class _HomeWidgetSetupSheetState extends ConsumerState<HomeWidgetSetupSheet> {
  late final Future<bool> _canRequestPin = ref
      .read(homeWidgetHostProvider)
      .canRequestPinWidget();

  Future<void> _addWidget() async {
    await ref.read(homeWidgetHostProvider).requestPinWidget();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    final routines =
        ref.watch(routineListProvider).valueOrNull ?? const <Routine>[];
    final widgetRoutine = selectWidgetRoutine(routines);
    final steps = homeWidgetSetupSteps(defaultTargetPlatform);

    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: foundation.textSecondary,
      height: 1.4,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: foundation.borderSubtle,
                ),
              ),
            ),
            const SizedBox(height: PebbleSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                'Add Pebble to your home screen',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: foundation.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: PebbleSpacing.xs),
            Text(
              widgetRoutine == null
                  ? 'The widget starts one routine with a tap. To choose it, '
                        "open a routine's menu and tap Show on widget."
                  : 'The widget shows "${widgetRoutine.title}". Tap it '
                        'there to start.',
              style: bodyStyle,
            ),
            const SizedBox(height: PebbleSpacing.lg),
            for (var i = 0; i < steps.length; i++)
              _SetupStep(number: i + 1, text: steps[i]),
            const SizedBox(height: PebbleSpacing.md),
            FutureBuilder<bool>(
              future: _canRequestPin,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: PebbleSpacing.xs),
                  child: PebbleButton.primary(
                    label: 'Add widget',
                    onPressed: _addWidget,
                  ),
                );
              },
            ),
            Center(
              child: PebbleButton.tertiary(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: PebbleSpacing.sm),
      child: Semantics(
        label: 'Step $number. $text',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: PebbleSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foundation.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
