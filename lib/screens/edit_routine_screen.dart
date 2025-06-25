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

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<Task> _tasks;
  int _taskOrder = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine?.title ?? '');
    _descriptionController = TextEditingController(text: widget.routine?.description ?? '');
    _tasks = widget.routine?.tasks.map((t) => t.copyWith()).toList() ?? [];
    _taskOrder = _tasks.isNotEmpty ? _tasks.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1 : 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addOrEditTask({Task? task, int? index}) async {
    // Get a list of unique categories from the current tasks
    final existingCategories = _tasks
        .map((t) => t.category)
        .where((c) => c != null && c.isNotEmpty)
        .map((c) => c!)
        .toSet()
        .toList();

    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _TaskEditor(
          task: task,
          order: task?.order ?? _taskOrder,
          existingCategories: existingCategories, // Pass the list
        ),
      ),
    );
    print('DEBUG: Bottom sheet returned: \\${result?.label}, category: \\${result?.category}, notes: \\${result?.notes}, photoRequired: \\${result?.photoRequired}');
    if (result != null) {
      setState(() {
        if (index != null) {
          _tasks[index] = result;
        } else {
          _tasks.add(result);
          _taskOrder++;
        }
        print('DEBUG: _tasks after add:');
        for (final t in _tasks) {
          print('  label: \\${t.label}, category: \\${t.category}, notes: \\${t.notes}, photoRequired: \\${t.photoRequired}');
        }
      });
    }
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, task);
      // Update order field for all tasks
      for (int i = 0; i < _tasks.length; i++) {
        _tasks[i] = _tasks[i].copyWith(order: i);
      }
    });
  }

  void _saveRoutine() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final routineService = Provider.of<RoutineService>(context, listen: false);
      final isUpdating = widget.routine != null;

      final newRoutine = Routine(
        id: widget.routine?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tasks: List<Task>.from(_tasks),
        categories: _tasks.map((t) => t.category).whereType<String>().toSet().toList(),
      );

      if (isUpdating) {
        routineService.updateRoutine(newRoutine);
      } else {
        routineService.addRoutine(newRoutine);
      }

      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.routine != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Routine' : 'Create New Routine'),
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: const Text('Save & Start'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Give Your Routine a Name', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Routine name is required' : null,
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
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organise Your Tasks (Optional)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Organise tasks into categories?', style: theme.textTheme.bodyMedium),
                      Switch(
                        value: true, // Always enabled for now
                        onChanged: null,
                        activeColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Create categories like "Kitchen", "Bathroom" etc.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const Key('addTaskButton'),
                    onPressed: () => _addOrEditTask(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 0,
                    ),
                  ),
                  if (_tasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tasks.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Card(
                          key: ValueKey(task.id),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(task.label),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Category',
                                  onPressed: () => _addOrEditTask(task: task, index: index),
                                ),
                                IconButton(
                                  key: Key('deleteTaskButton_$index'),
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete Category',
                                  onPressed: () => _deleteTask(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveRoutine,
                  child: const Text('Save & Start'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskEditor extends StatefulWidget {
  final Task? task;
  final int order;
  final List<String> existingCategories; // Receive the list

  const _TaskEditor({
    Key? key,
    this.task,
    required this.order,
    this.existingCategories = const [], // Default to empty list
  }) : super(key: key);

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late TextEditingController _labelController;
  late TextEditingController _categoryController; // This will be managed by Autocomplete
  late TextEditingController _notesController;
  bool _photoRequired = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.task?.label ?? '');
    // Category controller is now handled by Autocomplete's fieldViewBuilder
    _notesController = TextEditingController(text: widget.task?.notes ?? '');
    _photoRequired = widget.task?.photoRequired ?? false;
    _labelController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    // No need to dispose _categoryController here as it's managed by the Autocomplete fieldViewBuilder
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_labelController.text.trim().isEmpty) return;
    final task = Task(
      id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      photoRequired: _photoRequired,
      order: widget.order,
    );
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.task == null ? 'Add Task' : 'Edit Task', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return widget.existingCategories.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _categoryController.text = selection;
            },
            fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              _categoryController = fieldController; // Use the Autocomplete's controller
              if (widget.task?.category != null) {
                fieldController.text = widget.task!.category!;
              }
              return TextField(
                controller: fieldController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _photoRequired,
                onChanged: (val) => setState(() => _photoRequired = val ?? false),
              ),
              const Text('Photo required'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _labelController.text.trim().isEmpty
                    ? null
                    : _submit,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add this at the end of the file for test visibility
typedef TaskEditor = _TaskEditor; 