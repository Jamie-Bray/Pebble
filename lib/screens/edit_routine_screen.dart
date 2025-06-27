import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../services/routine_service.dart';

class EditRoutineScreen extends StatefulWidget {
  final Routine? routine;

  const EditRoutineScreen({Key? key, this.routine}) : super(key: key);

  @override
  State<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class StepModel {
  final String id;
  String label;
  String? notes;
  bool photoRequired;
  String? sectionId; // null = unassigned
  StepModel({
    required this.id,
    required this.label,
    this.notes,
    this.photoRequired = false,
    this.sectionId,
  });
  StepModel copyWith(
      {String? label, String? notes, bool? photoRequired, String? sectionId}) {
    return StepModel(
      id: id,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      photoRequired: photoRequired ?? this.photoRequired,
      sectionId: sectionId ?? this.sectionId,
    );
  }
}

class SectionModel {
  final String id;
  String name;
  SectionModel({required this.id, required this.name});
  SectionModel copyWith({String? name}) =>
      SectionModel(id: id, name: name ?? this.name);
}

class EditHistory<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];
  void push(T state) {
    _undoStack.add(state);
    _redoStack.clear();
  }

  T? undo(T current) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  T? redo(T current) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
}

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<SectionModel> _sections;
  late List<StepModel> _steps;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _errorText;
  String? _pendingDeleteSectionId;
  String? _editingSectionId;
  String? _editingStepId;
  String? _suggestedSection;
  bool _useSections = true; // Toggle for section organisation
  String? _activeSectionId; // Section currently being edited/added
  final _uuid = Uuid();
  final EditHistory<List<SectionModel>> _sectionHistory = EditHistory();
  final EditHistory<List<StepModel>> _stepHistory = EditHistory();

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    _titleController = TextEditingController(text: routine?.title ?? '');
    _descriptionController =
        TextEditingController(text: routine?.description ?? '');
    _sections = _initSections(routine);
    _steps = _initSteps(routine);
    _titleController.addListener(_onTitleChanged);
    _useSections =
        _sections.isNotEmpty && _steps.any((s) => s.sectionId != null);
    print('initState: sections=$_sections');
    print('initState: steps=$_steps');
    print(
        'initState: useSections=$_useSections, activeSectionId=$_activeSectionId');
  }

  List<SectionModel> _initSections(Routine? routine) {
    final sectionNames = routine?.categories ?? [];
    if (sectionNames.isEmpty) {
      return [];
    }
    return sectionNames
        .map((name) => SectionModel(id: _uuid.v4(), name: name))
        .toList();
  }

  List<StepModel> _initSteps(Routine? routine) {
    if (routine == null) {
      // Add a default step for new routines
      return [
        StepModel(
          id: _uuid.v4(),
          label: 'First step',
          sectionId: null,
        )
      ];
    }
    return routine.tasks
        .map((t) => StepModel(
              id: t.id,
              label: t.label,
              notes: t.notes,
              photoRequired: t.photoRequired,
              sectionId: _findSectionIdByName(t.category),
            ))
        .toList();
  }

  String _findSectionIdByName(String? name) {
    if (name == null) return '';
    final section = _sections.firstWhere((s) => s.name == name,
        orElse: () => SectionModel(id: '', name: ''));
    return section.id;
  }

  void _onTitleChanged() {
    setState(() {
      _hasChanges = true;
      _suggestedSection = _suggestSection(_titleController.text);
    });
  }

  String? _suggestSection(String routineName) {
    final name = routineName.toLowerCase();
    if (name.contains('car')) return 'Boot';
    if (name.contains('kitchen')) return 'Sink';
    if (name.contains('bed')) return 'Pillow';
    return null;
  }

  void _addSection([String? name]) {
    setState(() {
      final sectionName = name ?? _suggestedSection ?? 'Section';
      final section = SectionModel(id: _uuid.v4(), name: sectionName);
      _sections.add(section);
      _activeSectionId = section.id;
      _hasChanges = true;
    });
  }

  void _renameSection(String sectionId, String newName) {
    setState(() {
      final idx = _sections.indexWhere((s) => s.id == sectionId);
      if (idx != -1) _sections[idx].name = newName;
      _hasChanges = true;
    });
  }

  void _deleteSection(String sectionId) {
    setState(() {
      // Unassign steps in this section
      for (final step in _steps) {
        if (step.sectionId == sectionId) step.sectionId = null;
      }
      _sections.removeWhere((s) => s.id == sectionId);
      _hasChanges = true;
    });
  }

  void _addStep(String? sectionId) {
    setState(() {
      _steps.add(StepModel(
        id: _uuid.v4(),
        label: '',
        sectionId: sectionId?.isEmpty == true ? null : sectionId,
      ));
      _hasChanges = true;
    });
  }

  void _editStep(String stepId, String label,
      {String? notes, bool? photoRequired}) {
    setState(() {
      final idx = _steps.indexWhere((s) => s.id == stepId);
      if (idx != -1) {
        _steps[idx].label = label;
        _steps[idx].notes = notes;
        _steps[idx].photoRequired = photoRequired ?? false;
        _hasChanges = true;
      }
    });
  }

  void _deleteStep(String stepId) {
    setState(() {
      _steps.removeWhere((s) => s.id == stepId);
      _hasChanges = true;
    });
  }

  void _moveStep(String stepId, String? newSectionId, int newIndex) {
    setState(() {
      final idx = _steps.indexWhere((s) => s.id == stepId);
      if (idx != -1) {
        final step = _steps.removeAt(idx);
        step.sectionId = newSectionId;
        _steps.insert(newIndex, step);
        _hasChanges = true;
      }
    });
  }

  void _onReorderSection(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final section = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, section);
      _hasChanges = true;
    });
  }

  void _onReorderStep(String sectionId, int oldIndex, int newIndex) {
    setState(() {
      final sectionSteps =
          _steps.where((s) => s.sectionId == sectionId).toList();
      if (newIndex > oldIndex) newIndex--;
      final step = sectionSteps.removeAt(oldIndex);
      sectionSteps.insert(newIndex, step);
      // Update the main _steps list
      _steps.removeWhere((s) => s.sectionId == sectionId);
      _steps.addAll(sectionSteps);
      _hasChanges = true;
    });
  }

  bool get _hasUnassignedSteps => _steps.any((s) => s.sectionId == null);

  void _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final routineService =
          Provider.of<RoutineService>(context, listen: false);
      final isUpdating = widget.routine != null;
      final routine = Routine(
        id: widget.routine?.id ?? _uuid.v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categories: _useSections ? _sections.map((s) => s.name).toList() : [],
        tasks: _steps
            .map((s) => Task(
                  id: s.id,
                  label: s.label,
                  category: _sections
                      .firstWhere((sec) => sec.id == s.sectionId,
                          orElse: () => SectionModel(id: '', name: ''))
                      .name,
                  notes: s.notes,
                  photoRequired: s.photoRequired,
                  order: 0, // You can update this for ordering
                ))
            .toList(),
      );
      if (isUpdating) {
        await routineService.updateRoutine(routine);
      } else {
        await routineService.addRoutine(routine);
      }
      setState(() {
        _isSaving = false;
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorText = 'Failed to save routine.';
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Editing')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard')),
        ],
      ),
    );
    return discard == true;
  }

  void _saveHistory() {
    _sectionHistory
        .push(List<SectionModel>.from(_sections.map((s) => s.copyWith())));
    _stepHistory.push(List<StepModel>.from(_steps.map((s) => s.copyWith())));
  }

  void _undo() {
    final prevSections = _sectionHistory.undo(_sections);
    final prevSteps = _stepHistory.undo(_steps);
    if (prevSections != null && prevSteps != null) {
      setState(() {
        _sections = prevSections;
        _steps = prevSteps;
      });
    }
  }

  void _redo() {
    final nextSections = _sectionHistory.redo(_sections);
    final nextSteps = _stepHistory.redo(_steps);
    if (nextSections != null && nextSteps != null) {
      setState(() {
        _sections = nextSections;
        _steps = nextSteps;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    print(
        "build: _useSections=$_useSections, sections=${_sections.length}, steps=${_steps.length}, activeSectionId=$_activeSectionId");
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Routine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoutineHeader(theme),
              const SizedBox(height: 16),
              _buildSectionToggle(theme),
              const SizedBox(height: 16),
              _useSections
                  ? _buildSectionBuilder(theme)
                  : _buildFlatStepBuilder(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () async {
                      if (await _onWillPop()) Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRoutine,
                    child: const Text('Save Routine'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Routine Name',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Routine Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Routine name is required'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSectionToggle(ThemeData theme) {
    return Row(
      children: [
        Checkbox(
          value: _useSections,
          onChanged: (val) {
            setState(() {
              _useSections = val ?? true;
              if (!_useSections) {
                _sections.clear();
                _activeSectionId = null;
                for (final step in _steps) {
                  step.sectionId = null;
                }
              }
            });
          },
        ),
        const SizedBox(width: 8),
        Text('Organise into Sections?', style: theme.textTheme.bodyLarge),
      ],
    );
  }

  // --- Section Builder Flow ---
  Widget _buildSectionBuilder(ThemeData theme) {
    // Fallback for empty sections
    if (_sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text("No sections yet. Add one to begin.",
            style: theme.textTheme.bodyLarge),
      );
    }
    // If adding or editing a section
    if (_activeSectionId != null) {
      final section = _sections.firstWhere((s) => s.id == _activeSectionId);
      final sectionSteps =
          _steps.where((s) => s.sectionId == section.id).toList();
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: section.name,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => _renameSection(section.id, val),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Section name required'
                    : null,
              ),
              const SizedBox(height: 12),
              ...sectionSteps
                  .map((step) => _buildStepTile(theme, step, section.id))
                  .toList(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _addStep(section.id),
                icon: const Icon(Icons.add),
                label: const Text('Add Step'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _activeSectionId = null;
                      });
                    },
                    child: const Text('Save Section'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // Show all saved sections and allow adding more or saving routine
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._sections.map((section) {
          final sectionSteps =
              _steps.where((s) => s.sectionId == section.id).toList();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeSectionId = section.id;
                      });
                    },
                    child: Row(
                      children: [
                        Text(section.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...sectionSteps
                      .map((step) => _buildStepTile(theme, step, section.id))
                      .toList(),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _addStep(section.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Step'),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                final newSection = SectionModel(id: _uuid.v4(), name: '');
                setState(() {
                  _sections.add(newSection);
                  _activeSectionId = newSection.id;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Another Section'),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _activeSectionId = null;
                });
              },
              child: const Text('Done – Continue to Save Routine'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Flat Step Builder (no sections) ---
  Widget _buildFlatStepBuilder(ThemeData theme) {
    final flatSteps = _steps.where((s) => s.sectionId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (flatSteps.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No steps yet. Add your first step below!',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        if (flatSteps.isNotEmpty)
          ...flatSteps
              .map((step) => _buildStepTile(theme, step, null))
              .toList(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _addStep(null),
          icon: const Icon(Icons.add),
          label: const Text('Add Step'),
        ),
      ],
    );
  }

  // --- Step Tile ---
  Widget _buildStepTile(ThemeData theme, StepModel step, String? sectionId) {
    return Container(
      key: ValueKey(step.id),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: const Icon(Icons.drag_handle, size: 28),
        title: TextFormField(
          initialValue: step.label,
          decoration: const InputDecoration(
            border: InputBorder.none,
            labelText: 'Step label',
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: (val) => _editStep(step.id, val,
              notes: step.notes, photoRequired: step.photoRequired),
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Step label required'
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: step.notes,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: 'Notes (optional)',
              ),
              style: theme.textTheme.bodySmall,
              onChanged: (val) => _editStep(step.id, step.label,
                  notes: val, photoRequired: step.photoRequired),
            ),
            Row(
              children: [
                Checkbox(
                  value: step.photoRequired,
                  onChanged: (val) => _editStep(step.id, step.label,
                      notes: step.notes, photoRequired: val ?? false),
                ),
                const Text('Photo Required?'),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete step',
          onPressed: () => _deleteStep(step.id),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        minLeadingWidth: 48,
        minVerticalPadding: 16,
      ),
    );
  }
}
