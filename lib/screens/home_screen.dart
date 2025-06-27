import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../services/routine_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _selectedTab = 0;
  String _sortOption = 'Favourite';

  void _onTabTapped(int index) {
    setState(() {
      _selectedTab = index;
    });
    // Implement navigation for History and Settings
    if (index == 2) {
      Navigator.of(context).pushNamed('/settings');
    }
  }

  void _openRoutineDetails(Routine routine) {
    Navigator.of(context).pushNamed(
      '/details',
      arguments: routine,
    );
  }

  void _startRoutine(Routine routine) {
    Navigator.of(context).pushNamed(
      '/player',
      arguments: routine,
    );
  }

  void _editRoutine(Routine routine) {
    Navigator.of(context).pushNamed(
      '/edit',
      arguments: routine,
    );
  }

  void _showRoutineActions(Routine routine) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildRoutineActionsSheet(routine),
    );
  }

  Widget _buildRoutineActionsSheet(Routine routine) {
    final routineService = Provider.of<RoutineService>(context, listen: false);
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            routine.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Start Routine'),
            onTap: () {
              Navigator.pop(context);
              _startRoutine(routine);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Routine'),
            onTap: () {
              Navigator.pop(context);
              _editRoutine(routine);
            },
          ),
          ListTile(
            leading: Icon(routine.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(routine.isPinned ? 'Unpin' : 'Pin to Top'),
            onTap: () {
              Navigator.pop(context);
              if (routine.isPinned) {
                routineService.unpinRoutine(routine.id);
              } else {
                routineService.pinRoutine(routine.id);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.pop(context);
              _duplicateRoutine(routine);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(routine);
            },
          ),
        ],
      ),
    );
  }

  void _duplicateRoutine(Routine routine) {
    final newRoutine = routine.copyWith(
      id: const Uuid().v4(),
      title: '${routine.title} (copy)',
      isPinned: false, // Duplicates are never pinned
    );
    Provider.of<RoutineService>(context, listen: false).addRoutine(newRoutine);
  }

  void _showDeleteConfirmation(Routine routine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: Text('Are you sure you want to delete "${routine.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<RoutineService>(context, listen: false)
                  .deleteRoutine(routine.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createNewRoutine() {
    Navigator.of(context).pushNamed(
      '/edit',
      arguments: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineService = Provider.of<RoutineService>(context);
    final themeService = Provider.of<ThemeService>(context);
    if (!routineService.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final routines = routineService.routines;
    final accent = Theme.of(context).colorScheme.primary;
    final themeBg = themeService.currentThemeMeta.headerImageAsset;

    // Ensure _sortOption is always valid for the dropdown
    final validSortOptions = ['Favourite', 'A-Z', 'Z-A', 'Recent'];
    if (!validSortOptions.contains(_sortOption)) {
      _sortOption = 'Favourite';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // HEADER: Illustrated background, greeting, search
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(themeBg),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: accent.withOpacity(0.15),
                            child: Text('J', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: accent)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hello', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w400)),
                              Text('Jamie', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          enabled: false,
                          decoration: const InputDecoration(
                            hintText: 'Search routines',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // MAIN CONTENT: My Routines section
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 0, right: 0, bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Routines',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          // Sorting dropdown
                          DropdownButton<String>(
                            value: _sortOption,
                            underline: SizedBox.shrink(),
                            icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.primary),
                            items: [
                              DropdownMenuItem(value: 'Favourite', child: Text('Favourite First')),
                              DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                              DropdownMenuItem(value: 'Z-A', child: Text('Z-A')),
                              DropdownMenuItem(value: 'Recent', child: Text('Recent')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sortOption = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: routines.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24, left: 12, right: 12),
                              itemCount: _sortedRoutines.length,
                              itemBuilder: (context, index) {
                                final routine = _sortedRoutines[index];
                                final animation = Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _controller,
                                  curve: Interval(
                                    (index * 0.05).clamp(0.0, 1.0),
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ));
                                return FadeTransition(
                                  opacity: _controller,
                                  child: SlideTransition(
                                    position: animation,
                                    child: _buildModernRoutineCard(context, routine, accent, index),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewRoutine,
        tooltip: 'Add new routine',
        child: const Icon(Icons.add),
        elevation: 4,
      ),
      bottomNavigationBar: _buildBottomNavBar(context, accent),
    );
  }

  Widget _buildModernRoutineCard(BuildContext context, Routine routine, Color accent, int index) {
    final cardBg = Colors.white;
    final iconBg = accent.withOpacity(0.12);
    final icon = Icons.list_alt_rounded;
    final taskCount = routine.tasks.length;
    final categoryCount = routine.categories.length;
    return InkWell(
      onTap: () => _startRoutine(routine),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$categoryCount categories • $taskCount tasks',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Vertically center star and 3-dots menu
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final routineService = Provider.of<RoutineService>(context, listen: false);
                          if (routine.isPinned) {
                            await routineService.unpinRoutine(routine.id);
                          } else {
                            await routineService.pinRoutine(routine.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: routine.isPinned
                                  ? Colors.amber.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.star,
                              color: routine.isPinned ? Colors.amber : Colors.grey.withOpacity(0.3),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          switch (value) {
                            case 'Edit':
                              _editRoutine(routine);
                              break;
                            case 'Duplicate':
                              _duplicateRoutine(routine);
                              break;
                            case 'Delete':
                              _showDeleteConfirmation(routine);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'Edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'Duplicate', child: Text('Duplicate')),
                          const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavBarItem(context, Icons.home_rounded, 'Home', 0, accent),
            _buildNavBarItem(context, Icons.history_rounded, 'History', 1, accent),
            _buildNavBarItem(context, Icons.settings_rounded, 'Settings', 2, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(BuildContext context, IconData icon, String label, int index, Color accent) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onTabTapped(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? accent : Colors.black38, size: 28),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? accent : Colors.black38,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 1200),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_task_rounded,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to Pebble',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first routine to get started. Build healthy habits, one step at a time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewRoutine,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Routine'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Routine> get _sortedRoutines {
    final routineService = Provider.of<RoutineService>(context, listen: false);
    List<Routine> sorted = List.from(routineService.routines);
    switch (_sortOption) {
      case 'A-Z':
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Z-A':
        sorted.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'Recent':
        // If you have a date field, sort by it; otherwise, leave as is
        break;
      case 'Favourite':
      default:
        sorted.sort((a, b) {
          if (a.isPinned == b.isPinned) return 0;
          return a.isPinned ? -1 : 1;
        });
    }
    return sorted;
  }
} 