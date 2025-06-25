import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'routine.g.dart';

@HiveType(typeId: 0)
class Routine {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<String> categories;

  @HiveField(4)
  final List<Task> tasks;

  @HiveField(5)
  final bool isPinned;

  const Routine({
    required this.id,
    required this.title,
    this.description = '',
    this.categories = const [],
    this.tasks = const [],
    this.isPinned = false,
  });

  Routine copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? categories,
    List<Task>? tasks,
    bool? isPinned,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      tasks: tasks ?? this.tasks,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Routine &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      listEquals(other.categories, categories) &&
      listEquals(other.tasks, tasks);
  }

  @override
  int get hashCode {
    return id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      categories.hashCode ^
      tasks.hashCode;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categories': categories,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'isPinned': isPinned,
    };
  }

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      categories:
          (json['categories'] as List<dynamic>? ?? []).cast<String>(),
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}

@HiveType(typeId: 1)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String label;

  @HiveField(2)
  final String? category;

  @HiveField(3)
  final bool photoRequired;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  final int order;

  const Task({
    required this.id,
    required this.label,
    this.category,
    this.photoRequired = false,
    this.notes,
    required this.order,
  });

  Task copyWith({
    String? id,
    String? label,
    String? category,
    bool? photoRequired,
    String? notes,
    int? order,
  }) {
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      photoRequired: photoRequired ?? this.photoRequired,
      notes: notes ?? this.notes,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Task &&
      other.id == id &&
      other.label == label &&
      other.category == category &&
      other.photoRequired == photoRequired &&
      other.notes == notes &&
      other.order == order;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      label.hashCode ^
      category.hashCode ^
      photoRequired.hashCode ^
      notes.hashCode ^
      order.hashCode;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'category': category,
      'photoRequired': photoRequired,
      'notes': notes,
      'order': order,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      label: json['label'] as String,
      category: json['category'] as String?,
      photoRequired: json['photoRequired'] as bool? ?? false,
      notes: json['notes'] as String?,
      order: json['order'] as int,
    );
  }
}
