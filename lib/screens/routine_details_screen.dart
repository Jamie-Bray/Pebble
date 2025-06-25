import 'package:flutter/material.dart';
import '../models/routine.dart';
import 'edit_routine_screen.dart';

class RoutineDetailsScreen extends StatefulWidget {
  final Routine routine;

  const RoutineDetailsScreen({Key? key, required this.routine}) : super(key: key);

  @override
  State<RoutineDetailsScreen> createState() => _RoutineDetailsScreenState();
}

class _RoutineDetailsScreenState extends State<RoutineDetailsScreen> {
  String? selectedCategory;
  late Routine _routine;

  @override
  void initState() {
    super.initState();
    _routine = widget.routine;
  }

  List<String> get allCategories {
    final categories = <String>{};
    for (final task in _routine.tasks) {
      if (task.category != null && task.category!.isNotEmpty) {
        categories.add(task.category!);
      }
    }
    return categories.toList();
  }

  Map<String?, List<Task>> get groupedTasks {
    final map = <String?, List<Task>>{};
    for (final task in _routine.tasks) {
      final cat = task.category;
      map.putIfAbsent(cat, () => []).add(task);
    }
    return map;
  }

  void _showEditTaskSheet(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Label: ${task.label}'),
            if (task.notes != null && task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Notes: ${task.notes!}'),
              ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playRoutine() {
    Navigator.of(context).pushNamed(
      '/player',
      arguments: _routine,
    );
  }

  Future<void> _editRoutine() async {
    final updated = await Navigator.of(context).push<Routine>(
      MaterialPageRoute(
        builder: (context) => EditRoutineScreen(routine: _routine),
      ),
    );
    if (updated != null) {
      setState(() {
        _routine = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = groupedTasks;
    final categories = allCategories;
    final filtered = selectedCategory == null
        ? grouped
        : {
            selectedCategory: grouped[selectedCategory] ?? [],
          };

    return Scaffold(
      appBar: AppBar(
        title: Text(_routine.title),
        actions: [
          IconButton(
            key: const Key('editRoutineButton'),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Routine',
            onPressed: _editRoutine,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play Routine',
            onPressed: _playRoutine,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _routine.title,
              style: theme.textTheme.headlineMedium,
              key: const Key('routineTitle'),
            ),
            const SizedBox(height: 8),
            Text(
              _routine.description,
              style: theme.textTheme.bodyLarge,
              key: const Key('routineDescription'),
            ),
            const SizedBox(height: 16),
            if (categories.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedCategory == null,
                      onSelected: (_) {
                        setState(() => selectedCategory = null);
                      },
                    ),
                    ...categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: FilterChip(
                            label: Text(cat),
                            selected: selectedCategory == cat,
                            onSelected: (_) {
                              setState(() => selectedCategory = cat);
                            },
                          ),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: filtered.entries.expand((entry) {
                  final cat = entry.key;
                  final tasks = entry.value;
                  return [
                    if (cat != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          cat,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ...tasks.map((task) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(task.label),
                            leading: task.photoRequired
                                ? const Icon(Icons.camera_alt_outlined)
                                : null,
                            trailing: task.notes != null && task.notes!.isNotEmpty
                                ? const Icon(Icons.sticky_note_2_outlined)
                                : null,
                            onTap: () => _showEditTaskSheet(task),
                          ),
                        )),
                  ];
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 