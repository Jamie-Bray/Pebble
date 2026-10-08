import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/share/share_messages.dart';
import 'package:pebble_routines/core/share/shared_routine_link.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_controller.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';

/// The route an "Add to Pebble" link opens, with the link's data in `d`.
const String sharedRoutinePath = '/shared-routine';

String sharedRoutineLocation(SharedRoutine routine) => Uri(
  path: sharedRoutinePath,
  queryParameters: {'d': routine.data},
).toString();

/// Saves a shared routine as a new routine on this phone.
Future<Routine> addSharedRoutine(
  RoutineRepository repository,
  SharedRoutine shared,
) async {
  final now = DateTime.now();
  final routine = Routine(
    id: now.millisecondsSinceEpoch,
    title: shared.title,
    stepsJson: jsonEncode([for (final step in shared.steps) step.toJson()]),
    createdAt: now,
    emoji: RoutineIconCatalog.defaultKey,
    isPinned: false,
    version: 1,
    updatedAt: now,
    syncStatus: 'localOnly',
  );
  await repository.saveRoutine(routine);
  return routine;
}

/// What someone sees after tapping an "Add to Pebble" link: the routine's
/// steps and one button to add it. Nothing is saved until they press it.
class SharedRoutineScreen extends ConsumerStatefulWidget {
  const SharedRoutineScreen({super.key, required this.data});

  /// The link's data, or null when the link had none.
  final String? data;

  @override
  ConsumerState<SharedRoutineScreen> createState() =>
      _SharedRoutineScreenState();
}

class _SharedRoutineScreenState extends ConsumerState<SharedRoutineScreen> {
  late final SharedRoutine? _routine = widget.data == null
      ? null
      : SharedRoutine.fromData(widget.data!);
  bool _saving = false;

  bool get _fromOnboarding =>
      !(ref
              .read(sharedPreferencesProvider)
              .getBool('has_completed_onboarding') ??
          false);

  void _leave() {
    context.go(_fromOnboarding ? '/onboarding' : '/');
  }

  Future<void> _add(SharedRoutine shared) async {
    final stepCount = shared.steps.length;
    final currentRoutineCount =
        ref.read(routineListProvider).valueOrNull?.length ?? 0;
    if (!SubscriptionGuard.canCreateRoutine(
      context,
      ref,
      currentRoutineCount,
      stepCount: stepCount,
    )) {
      return;
    }
    setState(() => _saving = true);
    final fromOnboarding = _fromOnboarding;
    final routine = await addSharedRoutine(
      ref.read(routineRepositoryProvider),
      shared,
    );
    if (fromOnboarding) {
      final prefs = ref.read(sharedPreferencesProvider);
      await PlayerSettingsController.applyNewInstallDefaults(prefs);
      await prefs.setBool('has_completed_onboarding', true);
    }
    ref.read(navIndexProvider.notifier).state = 0;
    ref
        .read(homeRoutineHighlightProvider.notifier)
        .state = HomeRoutineHighlight(
      routineId: routine.id,
      message: '${routine.title} is ready',
    );
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // Keep the routine list loaded so the free plan's limit is checked
    // against the real count, even on a cold start from a link.
    ref.watch(routineListProvider);
    final routine = _routine;
    return Scaffold(
      backgroundColor: context.darkFoundation.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PebbleBackChrome(onBack: _leave),
            Expanded(
              child: routine == null
                  ? const _LinkProblem()
                  : _RoutinePreview(routine: routine),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: routine == null
                  ? PebbleButton.primary(
                      onPressed: _leave,
                      label: 'Back to home',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PebbleButton.primary(
                          key: const ValueKey('shared_routine_add'),
                          icon: LucideIcons.plus,
                          onPressed: _saving ? null : () => _add(routine),
                          label: 'Add to my routines',
                        ),
                        const SizedBox(height: 4),
                        PebbleButton.tertiary(
                          expand: true,
                          onPressed: _leave,
                          label: 'Not now',
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

class _RoutinePreview extends StatelessWidget {
  const _RoutinePreview({required this.routine});

  final SharedRoutine routine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    final secondary = context.readableSecondaryText;
    var number = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      children: [
        Text(
          'SHARED WITH YOU',
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.readableAccentText(theme.colorScheme.primary),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          routine.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: foundation.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add it to your routines, then change any step you like. '
          'It stays on this phone until you add it.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: secondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        for (final step in routine.steps) ...[
          if (step is InfoStep)
            _Line(leading: const Icon(LucideIcons.info, size: 16), step: step)
          else
            _Line(leading: Text('${++number}'), step: step),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.leading, required this.step});

  final Widget leading;
  final RoutineStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    final primary = theme.colorScheme.primary;
    final isNote = step is InfoStep;
    final requiresPhoto =
        step is CheckStep && (step as CheckStep).requiresPhoto;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: isNote ? Colors.transparent : foundation.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foundation.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(foundation.surfaceHigh, primary, 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.readableAccentText(primary),
                fontWeight: FontWeight.w800,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: context.readableAccentText(primary)),
                child: leading,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ShareMessages.stepLabel(step),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isNote
                          ? context.readableSecondaryText
                          : foundation.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  if (requiresPhoto) ...[
                    const SizedBox(height: 4),
                    Text(
                      'With a photo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.readableSecondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkProblem extends StatelessWidget {
  const _LinkProblem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This link doesn't work",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: context.darkFoundation.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Part of it may be missing. Ask the person who sent it to share '
            'the routine again.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.readableSecondaryText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
