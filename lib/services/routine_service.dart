import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/routine.dart';

class RoutineService extends ChangeNotifier {
  static const String _boxName = 'routinesBox';
  
  List<Routine> _routines = [];
  bool _isInitialized = false;

  List<Routine> get routines => List.unmodifiable(_routines);
  bool get isInitialized => _isInitialized;

  RoutineService() {
    _init();
  }

  Future<void> _init() async {
    print('DEBUG: Starting RoutineService initialization');
    
    // Open the box
    final box = await Hive.openBox<Routine>(_boxName);
    print('DEBUG: Hive box opened');
    
    // Read all routines from the box
    _routines = box.values.toList();
    print('DEBUG: Loaded ${_routines.length} routines from Hive');
    
    _isInitialized = true;
    print('DEBUG: RoutineService initialized');
    
    // Notify listeners that routines are loaded
    notifyListeners();

    // Listen for changes in the box
    box.listenable().addListener(() {
      _routines = box.values.toList();
      notifyListeners();
    });
  }

  Future<void> addRoutine(Routine routine) async {
    final box = await Hive.openBox<Routine>(_boxName);
    await box.put(routine.id, routine);
    // The listener will automatically update the local list and notify listeners
  }

  Future<void> updateRoutine(Routine routine) async {
    final box = await Hive.openBox<Routine>(_boxName);
    await box.put(routine.id, routine);
    // The listener will automatically update the local list and notify listeners
  }

  Future<void> deleteRoutine(String routineId) async {
    final box = await Hive.openBox<Routine>(_boxName);
    await box.delete(routineId);
    // The listener will automatically update the local list and notify listeners
  }

  Future<void> pinRoutine(String routineId) async {
    final box = await Hive.openBox<Routine>(_boxName);
    
    // First, unpin any currently pinned routine
    for (final routine in _routines) {
      if (routine.isPinned) {
        final unpinnedRoutine = routine.copyWith(isPinned: false);
        await box.put(unpinnedRoutine.id, unpinnedRoutine);
      }
    }
    
    // Then pin the selected routine
    final routineToPin = _routines.firstWhere((r) => r.id == routineId);
    final pinnedRoutine = routineToPin.copyWith(isPinned: true);
    await box.put(pinnedRoutine.id, pinnedRoutine);
    
    // The listener will automatically update the local list and notify listeners
  }

  Future<void> unpinRoutine(String routineId) async {
    final box = await Hive.openBox<Routine>(_boxName);
    final routineToUnpin = _routines.firstWhere((r) => r.id == routineId);
    final unpinnedRoutine = routineToUnpin.copyWith(isPinned: false);
    await box.put(unpinnedRoutine.id, unpinnedRoutine);
    // The listener will automatically update the local list and notify listeners
  }
  
  Routine? getRoutineById(String id) {
    try {
      return _routines.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }
} 