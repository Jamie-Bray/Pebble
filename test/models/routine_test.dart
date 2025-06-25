import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/models/routine.dart';

void main() {
  group('Task', () {
    final task = Task(
      id: '1',
      label: 'Test Task',
      category: 'Morning',
      notes: 'Some notes',
      photoRequired: true,
      order: 1,
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = task.copyWith(label: 'Updated Task');
      expect(updated.label, 'Updated Task');
      expect(updated.id, task.id);
    });

    test('equality and hashCode', () {
      final task2 = Task(
        id: '1',
        label: 'Test Task',
        category: 'Morning',
        notes: 'Some notes',
        photoRequired: true,
        order: 1,
      );
      expect(task, equals(task2));
      expect(task.hashCode, equals(task2.hashCode));
    });

    test('JSON serialization', () {
      final json = task.toJson();
      expect(json, {
        'id': '1',
        'label': 'Test Task',
        'category': 'Morning',
        'photoRequired': true,
        'notes': 'Some notes',
        'order': 1,
      });
      final fromJson = Task.fromJson(json);
      expect(fromJson, equals(task));
    });
  });

  group('Routine', () {
    final task = Task(
      id: '1',
      label: 'Test Task',
      category: 'Morning',
      notes: 'Some notes',
      photoRequired: true,
      order: 1,
    );
    final routine = Routine(
      id: 'r1',
      title: 'Morning Routine',
      description: 'Start your day right',
      categories: ['Morning'],
      tasks: [task],
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = routine.copyWith(title: 'Updated Routine');
      expect(updated.title, 'Updated Routine');
      expect(updated.id, routine.id);
    });

    test('equality and hashCode', () {
      final routine2 = Routine(
        id: 'r1',
        title: 'Morning Routine',
        description: 'Start your day right',
        categories: ['Morning'],
        tasks: [task],
      );
      expect(routine, equals(routine2));
      expect(routine.hashCode, equals(routine2.hashCode));
    });

    test('JSON serialization', () {
      final json = routine.toJson();
      expect(json, {
        'id': 'r1',
        'title': 'Morning Routine',
        'description': 'Start your day right',
        'categories': ['Morning'],
        'tasks': [
          {
            'id': '1',
            'label': 'Test Task',
            'category': 'Morning',
            'photoRequired': true,
            'notes': 'Some notes',
            'order': 1,
          }
        ],
        'isPinned': false,
      });
      final fromJson = Routine.fromJson(json);
      expect(fromJson, equals(routine));
    });
  });
} 