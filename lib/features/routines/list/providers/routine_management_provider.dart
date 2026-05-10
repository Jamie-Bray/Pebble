import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';

final routineManagementProvider = Provider<RoutineManagementActions>((ref) {
  final repo = ref.read(routineRepositoryProvider);
  final sessionRepo = ref.read(routineSessionRepositoryProvider);
  return RoutineManagementActions(repo, sessionRepo);
});

class RoutineManagementActions {
  final RoutineRepository _repository;
  final RoutineSessionRepository _sessionRepository;

  RoutineManagementActions(this._repository, this._sessionRepository);

  Future<void> pinRoutine(int id, bool isPinned) async {
    await _repository.updateRoutinePinned(id, isPinned);
  }

  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) {
    return _repository.moveRoutine(id, direction);
  }

  Future<void> duplicateRoutine(int id) async {
    await _repository.duplicateRoutine(id);
  }

  Future<void> deleteRoutine(int id) async {
    final activeSession = await _sessionRepository.getActiveSessionForRoutine(
      id,
    );
    if (activeSession != null) {
      await _sessionRepository.discardSession(activeSession.sessionId);
    }
    await _repository.deleteRoutine(id);
  }

  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {
    await _repository.updateRoutineAppearance(
      id: id,
      iconKey: iconKey,
      colorHex: colorHex,
    );
  }
}
