import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_simple_sheet.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

/// What AI wrote about one photo, where the photo is shown: a small
/// "AI description" label, then the sentence. Screen readers hear both.
class AiDescriptionText extends StatelessWidget {
  const AiDescriptionText(this.description, {super.key});

  final String description;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Semantics(
      label: '$aiPhotoLabel: $description',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aiPhotoLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.readableSecondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: foundation.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

List<RoutineStep> _stepsOf(Routine routine) {
  try {
    return (jsonDecode(routine.stepsJson) as List)
        .whereType<Map>()
        .map((step) => RoutineStep.fromJson(Map<String, dynamic>.from(step)))
        .toList();
  } catch (_) {
    return const [];
  }
}

String _firstFiveNote(int photoSteps) =>
    'This routine has $photoSteps photo steps. AI describes the photos from '
    'the first $aiPhotoMaxSteps.';

/// The line under "AI photo descriptions" in a routine's actions.
String aiPhotoRowSubtitle({
  required AiPhotoSettings settings,
  required Routine routine,
  required bool hasPremium,
  required bool serverEnabled,
}) {
  if (settings.isOnFor(routine.id)) {
    if (!serverEnabled) return 'Unavailable right now';
    final photoSteps = photoStepCount(_stepsOf(routine));
    return photoSteps > aiPhotoMaxSteps
        ? 'On for the first $aiPhotoMaxSteps of $photoSteps photo steps'
        : 'On for this routine';
  }
  return hasPremium ? 'Off' : 'Describe your photos, with Premium';
}

/// Everything behind the "AI photo descriptions" row: the Premium gate, the
/// on state with its off switch, the consent
/// sheet and the completion email question.
Future<void> openAiPhotoSettings(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  if (!ref.read(authSessionProvider).isSignedIn) {
    ZenNotifications.showInfo(
      context,
      message: 'Sign in to use AI descriptions.',
    );
    return;
  }

  final settings = ref.read(aiPhotoControllerProvider);
  final controller = ref.read(aiPhotoControllerProvider.notifier);
  final steps = _stepsOf(routine);
  final photoSteps = photoStepCount(steps);

  if (settings.isOnFor(routine.id)) {
    final serverEnabled =
        ref.read(aiPhotoServerEnabledProvider).valueOrNull ?? false;
    final turnOff = await showPebbleSimpleSheet<bool>(
      context: context,
      builder: (sheetContext) => PebbleSimpleSheet(
        icon: LucideIcons.sparkles,
        title: 'AI photo descriptions',
        body: serverEnabled
            ? 'On for "${routine.title}".'
            : '$aiPhotoUnavailableMessage On for "${routine.title}".',
        content: const AiPhotoAllowanceText(),
        primaryLabel: 'Turn off',
        destructive: true,
        onPrimary: () => Navigator.of(sheetContext).pop(true),
        secondaryLabel: 'Keep on',
        onSecondary: () => Navigator.of(sheetContext).pop(false),
        detailsLabel: 'More details',
        onDetails: () =>
            showAiPhotoDetails(sheetContext, photoSteps: photoSteps),
      ),
    );
    if (turnOff == true) {
      await controller.turnOff(routine.id);
      if (context.mounted) {
        ZenNotifications.showInfo(
          context,
          message: 'AI photo descriptions are off.',
        );
      }
    }
    return;
  }

  // Withdrawing consent must remain available after Premium expires.
  if (!ref.read(premiumFeaturePolicyProvider).hasActiveLocalPremium) {
    unawaited(GoRouter.of(context).push(premiumRoute()));
    return;
  }

  if (photoSteps == 0) {
    ZenNotifications.showInfo(
      context,
      message: 'Add a photo step to this routine first.',
    );
    return;
  }

  final agreed = await showAiPhotoConsentSheet(
    context,
    routineName: routine.title,
    photoSteps: photoSteps,
  );
  if (agreed != true || !context.mounted) return;

  final sharedReminders = ref.read(sharedReminderPreferencesRepositoryProvider);
  try {
    await controller.turnOn(
      routineId: routine.id,
      routineKey: sharedReminders.routineKeyFor(
        routineId: routine.id,
        routineCloudId: routine.cloudId,
      ),
    );
  } on AiPhotoException catch (error) {
    if (context.mounted) {
      ZenNotifications.showError(context, message: error.message);
    }
    return;
  }
  if (!context.mounted) return;

  // One more question, only when this routine emails someone.
  SharedReminderContact? contact;
  try {
    contact = await sharedReminders.getForRoutine(
      routineId: routine.id,
      routineCloudId: routine.cloudId,
    );
  } catch (_) {
    // No contact found, or offline: the choice stays in the email settings.
  }
  if (!context.mounted) return;
  if (contact != null &&
      (contact.status == SharedReminderContactStatus.accepted ||
          contact.status == SharedReminderContactStatus.pending)) {
    final include = await showAiPhotoEmailQuestionSheet(
      context,
      contactEmail: contact.recipientEmail,
    );
    if (include != null) {
      await controller.setEmailDescriptions(routine.id, include);
    }
    if (!context.mounted) return;
  }
  ZenNotifications.showSuccess(
    context,
    message: 'AI photo descriptions are on for "${routine.title}".',
  );
}

class AiPhotoAllowanceText extends ConsumerWidget {
  const AiPhotoAllowanceText({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(aiPhotoAllowanceProvider);
    final allowance = result.valueOrNull;
    return Text(
      allowance != null
          ? '${allowance.remaining} of ${allowance.limit} remaining this month.'
          : result.isLoading
          ? 'Checking remaining allowance…'
          : 'Remaining allowance unavailable right now.',
      style: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: context.darkFoundation.textSecondary,
      ),
    );
  }
}

Future<T?> _showAiSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext context, StateSetter setState)
  children,
}) {
  final foundation = context.darkFoundation;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: foundation.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
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
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: foundation.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...children(context, setState),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _sheetParagraph(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: context.darkFoundation.textSecondary,
      ),
    ),
  );
}

/// The consent sheet, kept short on purpose: what happens in two lines,
/// the statement being agreed to word for word, and one "Turn on" button.
/// Everything else is one tap away in [showAiPhotoDetails]. Returns true only
/// when "Turn on" is pressed; closing it any other way is not consent.
Future<bool?> showAiPhotoConsentSheet(
  BuildContext context, {
  required String routineName,
  int photoSteps = 0,
}) {
  return showPebbleSimpleSheet<bool>(
    context: context,
    builder: (sheetContext) => PebbleSimpleSheet(
      icon: LucideIcons.sparkles,
      title: aiPhotoConsentShortTitle,
      body: aiPhotoConsentSummary(routineName),
      content: const PebbleStatementBox(text: aiPhotoConsentCheckLabel),
      primaryLabel: 'Turn on',
      onPrimary: () => Navigator.of(sheetContext).pop(true),
      onSecondary: () => Navigator.of(sheetContext).pop(false),
      detailsLabel: 'More details',
      onDetails: () => showAiPhotoDetails(sheetContext, photoSteps: photoSteps),
    ),
  );
}

/// The full explanation, word for word as agreed in consent version
/// [aiPhotoConsentVersion], on its own page.
Future<void> showAiPhotoDetails(BuildContext context, {int photoSteps = 0}) {
  return PebbleDetailsPage.push(
    context,
    title: 'AI photo descriptions',
    sections: [
      for (final paragraph in aiPhotoConsentBody) (null, paragraph),
      if (photoSteps > aiPhotoMaxSteps) (null, _firstFiveNote(photoSteps)),
      ('When it is on', aiPhotoOnDetail),
    ],
    footer: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(aiPhotoHowItWorksUrl),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(LucideIcons.externalLink, size: 16),
        label: const Text('Privacy policy'),
      ),
    ),
  );
}

/// Asked once, when AI is switched on for a routine that emails someone.
/// Neither answer is preselected and the two buttons carry equal weight;
/// closing the sheet leaves the descriptions out.
Future<bool?> showAiPhotoEmailQuestionSheet(
  BuildContext context, {
  required String contactEmail,
}) {
  return _showAiSheet<bool>(
    context,
    title: 'Add the descriptions to the completion email?',
    children: (context, _) => [
      _sheetParagraph(
        context,
        'This routine emails $contactEmail when you finish it. Pebble can '
        'add the AI descriptions to that email. The photos are never '
        'emailed.',
      ),
      _sheetParagraph(
        context,
        "You can change this in the routine's completion email settings.",
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Add descriptions'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Don't add"),
        ),
      ),
    ],
  );
}
