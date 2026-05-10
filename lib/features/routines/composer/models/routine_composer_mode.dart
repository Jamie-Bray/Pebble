enum RoutineComposerMode { create, edit }

extension RoutineComposerModeX on RoutineComposerMode {
  String get storageValue => switch (this) {
    RoutineComposerMode.create => 'create',
    RoutineComposerMode.edit => 'edit',
  };

  static RoutineComposerMode fromStorage(String value) {
    return switch (value) {
      'edit' => RoutineComposerMode.edit,
      _ => RoutineComposerMode.create,
    };
  }
}
