import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/routine.dart';

class RoutinePlayerScreen extends StatefulWidget {
  final Routine routine;

  const RoutinePlayerScreen({Key? key, required this.routine}) : super(key: key);

  @override
  State<RoutinePlayerScreen> createState() => _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends State<RoutinePlayerScreen> {
  int currentTaskIndex = 0;
  final Set<int> completedTasks = {};
  final Map<int, XFile?> taskPhotos = {};
  final ImagePicker _picker = ImagePicker();

  List<Task> get tasks => widget.routine.tasks;

  bool get isComplete => completedTasks.length == tasks.length;

  Future<void> _markTaskDone(int index) async {
    setState(() {
      completedTasks.add(index);
      if (currentTaskIndex < tasks.length - 1) {
        currentTaskIndex++;
      }
    });
  }

  Future<void> _takePhoto(int index) async {
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        taskPhotos[index] = photo;
      });
    }
  }

  void _finishRoutine() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = tasks.length;
    final completed = completedTasks.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.title),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$completed/$total Complete', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 24),
            if (isComplete)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.celebration, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Routine Complete', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _finishRoutine,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text('Step ${currentTaskIndex + 1} of $total', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isCurrent = index == currentTaskIndex;
                    final isDone = completedTasks.contains(index);
                    return Card(
                      color: isDone
                          ? theme.colorScheme.surfaceVariant
                          : isCurrent
                              ? theme.colorScheme.primaryContainer.withOpacity(0.2)
                              : null,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(task.label),
                        subtitle: task.photoRequired && taskPhotos[index] != null
                            ? const Text('Photo attached')
                            : null,
                        trailing: isDone
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        enabled: isCurrent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: null,
                        // Only current task is interactive
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final task = tasks[currentTaskIndex];
                  final isDone = completedTasks.contains(currentTaskIndex);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (task.photoRequired)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(taskPhotos[currentTaskIndex] == null ? 'Take Photo' : 'Retake Photo'),
                          onPressed: isDone
                              ? null
                              : () => _takePhoto(currentTaskIndex),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isDone
                            ? null
                            : (task.photoRequired && taskPhotos[currentTaskIndex] == null)
                                ? null
                                : () => _markTaskDone(currentTaskIndex),
                        child: const Text('Mark as Done'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
} 