import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';

void main() {
  group('step notes', () {
    test('are trimmed, capped, and blank means none', () {
      expect(cleanStepNote('  On the table  '), 'On the table');
      expect(cleanStepNote('   '), isNull);
      expect(cleanStepNote(null), isNull);
      expect(cleanStepNote(42), isNull);
      expect(cleanStepNote('n' * 400)!.length, maxStepNoteChars);
      // An emoji at the cut is never split in half.
      final emoji = '${'a' * 139}👋🏽';
      expect(cleanStepNote(emoji), '${'a' * 139}👋🏽');
    });

    test('survive a save and reload, and older sessions have none', () {
      final state = RoutineSessionStepState.initial(0).copyWith(
        status: SessionStepStatus.completed,
        completedAt: DateTime.utc(2026, 10, 8, 8, 2),
        note: 'Moved the straighteners onto the kitchen table',
      );
      final json = state.toJson();
      expect(json['note'], 'Moved the straighteners onto the kitchen table');
      final back = RoutineSessionStepState.fromJson(json);
      expect(back.note, 'Moved the straighteners onto the kitchen table');

      final older = RoutineSessionStepState.fromJson({
        'stepIndex': 0,
        'status': 'completed',
      });
      expect(older.note, isNull);
      expect(older.toJson().containsKey('note'), isFalse);
    });

    test('copyWith keeps a note unless it is cleared', () {
      final state = RoutineSessionStepState.initial(0).copyWith(note: 'Kept');
      expect(state.copyWith(status: SessionStepStatus.skipped).note, 'Kept');
      expect(state.copyWith(clearNote: true).note, isNull);
    });
  });
}
