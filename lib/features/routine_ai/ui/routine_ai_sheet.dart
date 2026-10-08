import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:uuid/uuid.dart';

/// Opens "Build with AI". When the person takes the draft, it is put in the
/// routine editor (`/creator`) to change and save; nothing is saved before
/// they tap Save there. Returns true when the editor was opened.
Future<bool> showRoutineAiBuilder(BuildContext context) async {
  final draft = await showModalBottomSheet<RoutineAiDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RoutineAiSheet(),
  );
  if (draft == null || !context.mounted) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  await container
      .read(routineComposerDraftRepositoryProvider)
      .createFreshDraft(seedData: routineAiSeedData(draft));
  container.invalidate(routineAiStatusProvider);
  if (!context.mounted) return false;
  unawaited(GoRouter.of(context).push('/creator'));
  return true;
}

/// "Build with AI" from Home or the + button: the builder, or the Personal
/// Premium page when the free build has been used.
Future<void> openRoutineAiBuilder(BuildContext context, WidgetRef ref) async {
  final status = ref.read(routineAiStatusProvider).valueOrNull;
  if (status != null && !status.canBuild) {
    unawaited(
      GoRouter.of(
        context,
      ).push(premiumRoute(source: PremiumEntrySource.aiBuilder)),
    );
    return;
  }
  await showRoutineAiBuilder(context);
}

/// The draft as the editor's starting point.
RoutineComposerSeedData routineAiSeedData(RoutineAiDraft draft) {
  const uuid = Uuid();
  return RoutineComposerSeedData(
    title: draft.name,
    iconKey: null,
    colorHex: null,
    steps: [
      for (final (index, step) in draft.steps.indexed)
        RoutineComposerStepDraft(
          id: uuid.v4(),
          text: step.label,
          requiresPhoto: step.photo,
          allowSkip: false,
          sortOrder: index,
        ),
    ],
  );
}

enum _Phase { describe, working, questions, draft, refused }

const _examples = ['Leaving the house', 'Bedtime', 'Leaving the car'];

class RoutineAiSheet extends ConsumerStatefulWidget {
  const RoutineAiSheet({super.key});

  @override
  ConsumerState<RoutineAiSheet> createState() => _RoutineAiSheetState();
}

class _RoutineAiSheetState extends ConsumerState<RoutineAiSheet> {
  final _description = TextEditingController();

  /// One build: "Try again" and the follow-up to the questions reuse it, so
  /// they count as the same build on the server.
  final String _buildKey = const Uuid().v4();

  _Phase _phase = _Phase.describe;
  bool _askedQuestions = false;
  List<RoutineAiQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  RoutineAiDraft? _draft;
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _hasDescription => _description.text.trim().length >= 3;

  Future<void> _build({bool askQuestions = false}) async {
    if (!_hasDescription) return;
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.working);
    final reply = await ref
        .read(routineAiClientProvider)
        .build(
          buildKey: _buildKey,
          description: _description.text.trim(),
          askQuestions: askQuestions,
          answers: [
            for (final entry in _answers.entries)
              if (entry.key < _questions.length)
                RoutineAiAnswer(
                  question: _questions[entry.key].question,
                  answer: entry.value,
                ),
          ],
        );
    if (!mounted) return;
    if (reply.draft case final draft?) {
      setState(() {
        _draft = draft;
        _phase = _Phase.draft;
      });
    } else if (reply.questions.isNotEmpty) {
      setState(() {
        _askedQuestions = true;
        _questions = reply.questions;
        _phase = _Phase.questions;
      });
    } else if (askQuestions && reply.reason == 'couldNotBuild') {
      // No useful questions: just draft it.
      await _build();
    } else {
      setState(() {
        _reason = reply.reason;
        _phase = _Phase.refused;
      });
    }
  }

  void _togglePhoto(int index) {
    final draft = _draft;
    if (draft == null) return;
    final steps = [...draft.steps];
    steps[index] = steps[index].copyWith(photo: !steps[index].photo);
    setState(() => _draft = RoutineAiDraft(name: draft.name, steps: steps));
  }

  void _removeStep(int index) {
    final draft = _draft;
    if (draft == null || draft.steps.length <= 1) return;
    final steps = [...draft.steps]..removeAt(index);
    setState(() => _draft = RoutineAiDraft(name: draft.name, steps: steps));
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          20 + (bottomInset > 0 ? 0 : MediaQuery.paddingOf(context).bottom),
        ),
        decoration: BoxDecoration(
          color: foundation.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: foundation.borderSubtle)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: foundation.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_phase),
                    child: switch (_phase) {
                      _Phase.describe => _buildDescribe(context),
                      _Phase.working => _buildWorking(context),
                      _Phase.questions => _buildQuestions(context),
                      _Phase.draft => _buildDraft(context),
                      _Phase.refused => _buildRefused(context),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String text) {
    return Text(
      text,
      style: PebbleFonts.serif(
        color: context.darkFoundation.textPrimary,
        fontSize: 27,
        fontWeight: FontWeight.w400,
        height: 1.1,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    return Text(
      text,
      style: PebbleType.of(
        context,
      ).body.copyWith(color: context.darkFoundation.textSecondary, height: 1.4),
    );
  }

  Widget _buildDescribe(BuildContext context) {
    final foundation = context.darkFoundation;
    final type = PebbleType.of(context);
    final status = ref.watch(routineAiStatusProvider).valueOrNull;
    final firstFree = status != null && !status.premium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'What do you want to check?'),
        const SizedBox(height: 8),
        _body(
          context,
          'Say it in a sentence, like what you always forget. Pebble drafts the steps and you can change any of them.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('routine-ai-description'),
          controller: _description,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText:
                'Leaving for work: hair straighteners, the hob and the back door',
            counterText: '',
            filled: true,
            fillColor: foundation.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PebbleRadius.sm),
              borderSide: BorderSide(color: foundation.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final example in _examples)
              ActionChip(
                label: Text(example),
                onPressed: () {
                  _description.text = example;
                  _description.selection = TextSelection.collapsed(
                    offset: example.length,
                  );
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        PebbleButton.primary(
          icon: LucideIcons.sparkles,
          onPressed: _hasDescription ? () => _build() : null,
          label: 'Build it',
        ),
        const SizedBox(height: 4),
        PebbleButton.tertiary(
          expand: true,
          onPressed: _hasDescription && !_askedQuestions
              ? () => _build(askQuestions: true)
              : null,
          label: 'Ask me a couple of questions first',
        ),
        const SizedBox(height: 10),
        Text(
          '${firstFree ? 'Your first AI-built routine is free. ' : ''}'
          'What you type goes to $aiPhotoProviderName to draft the steps and is not kept.',
          textAlign: TextAlign.center,
          style: type.caption.copyWith(color: foundation.textMuted),
        ),
      ],
    );
  }

  Widget _buildWorking(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 18),
          _body(context, 'Drafting your routine…'),
        ],
      ),
    );
  }

  Widget _buildQuestions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'A couple of questions'),
        const SizedBox(height: 8),
        _body(context, 'Tap what fits, or skip any you like.'),
        for (final (index, question) in _questions.indexed) ...[
          const SizedBox(height: 18),
          Text(
            question.question,
            style: PebbleType.of(context).bodyLarge.copyWith(
              color: context.darkFoundation.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in question.options)
                ChoiceChip(
                  label: Text(option),
                  selected: _answers[index] == option,
                  selectedColor: cs.primary.withValues(alpha: 0.18),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _answers[index] = option;
                    } else {
                      _answers.remove(index);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        PebbleButton.primary(
          icon: LucideIcons.sparkles,
          onPressed: () => _build(),
          label: 'Build it',
        ),
      ],
    );
  }

  Widget _buildDraft(BuildContext context) {
    final draft = _draft!;
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;
    final type = PebbleType.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'YOUR DRAFT',
          style: type.overline.copyWith(color: foundation.textMuted),
        ),
        const SizedBox(height: 6),
        _title(context, draft.name),
        const SizedBox(height: 14),
        for (final (index, step) in draft.steps.indexed)
          Container(
            key: ValueKey('routine-ai-step-$index'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: foundation.surfaceHigh,
              borderRadius: BorderRadius.circular(PebbleRadius.sm),
              border: Border.all(color: foundation.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.label,
                    style: type.body.copyWith(color: foundation.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: step.photo ? 'Photo on' : 'Photo off',
                  onPressed: () => _togglePhoto(index),
                  icon: Icon(
                    step.photo ? LucideIcons.camera : LucideIcons.cameraOff,
                    size: 18,
                    color: step.photo ? cs.primary : foundation.textMuted,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove step',
                  onPressed: draft.steps.length > 1
                      ? () => _removeStep(index)
                      : null,
                  icon: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: foundation.textMuted,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Tap the camera to choose which steps take a photo. You can rename, reorder or add steps next.',
          style: type.caption.copyWith(color: foundation.textSecondary),
        ),
        const SizedBox(height: 18),
        PebbleButton.primary(
          onPressed: () => Navigator.of(context).pop(draft),
          label: 'Use this routine',
        ),
        const SizedBox(height: 4),
        PebbleButton.tertiary(
          expand: true,
          icon: LucideIcons.refreshCw,
          onPressed: () => _build(),
          label: 'Try again',
        ),
      ],
    );
  }

  Widget _buildRefused(BuildContext context) {
    final (title, body) = switch (_reason) {
      'freeUsed' => (
        "You've used your free AI build",
        'Build more routines with AI with Personal Premium. You can still pick a template or start from scratch.',
      ),
      'dailyLimit' => (
        "That's today's AI builds",
        'You can build more tomorrow. You can still pick a template or start from scratch.',
      ),
      'tooManyTries' => (
        "That's all the tries for this one",
        'Use the last draft, or close this and start a new one.',
      ),
      'featureOff' || 'busy' => (
        "AI building isn't available right now",
        'Pick a template or start from scratch instead.',
      ),
      'offline' => (
        "Couldn't reach Pebble",
        'Check your connection and try again.',
      ),
      _ => (
        "Couldn't draft that one",
        'Try saying it a different way, with the things you want to check.',
      ),
    };
    final canRetry = _reason == 'offline' || _reason == 'couldNotBuild';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, title),
        const SizedBox(height: 8),
        _body(context, body),
        const SizedBox(height: 22),
        if (_reason == 'freeUsed')
          PebbleButton.primary(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              unawaited(
                router.push(premiumRoute(source: PremiumEntrySource.aiBuilder)),
              );
            },
            label: 'See Personal Premium',
          )
        else if (canRetry)
          PebbleButton.primary(
            onPressed: () => setState(() => _phase = _Phase.describe),
            label: 'Try again',
          )
        else if (_reason == 'tooManyTries' && _draft != null)
          PebbleButton.primary(
            onPressed: () => setState(() => _phase = _Phase.draft),
            label: 'Back to the draft',
          ),
        const SizedBox(height: 4),
        PebbleButton.tertiary(
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Close',
        ),
      ],
    );
  }
}
