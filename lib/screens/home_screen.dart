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

  void _onTabTapped(int index) {
    setState(() {
      _selectedTab = index;
    });
    // TODO: Implement navigation for History and Settings
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
    final themeBg = () {
      switch (themeService.currentThemeMode) {
        case AppThemeMode.blush:
          return 'assets/themes/pink_dawn.jpg';
        case AppThemeMode.night:
          return 'assets/themes/blue_mountains.jpg';
        case AppThemeMode.jungle:
          return 'assets/themes/green_forest.jpg';
        case AppThemeMode.blushNight:
          return 'assets/themes/yellow_sunset.jpg';
        default:
          return 'assets/themes/yellow_sunset.jpg';
      }
    }();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F3),
      body: Stack(
        children: [
          // Themed illustrated background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(
                themeBg,
                key: ValueKey(themeBg),
                fit: BoxFit.cover,
                height: MediaQuery.of(context).size.height * 0.32,
                width: double.infinity,
                alignment: Alignment.topCenter,
                color: Colors.white.withOpacity(0.08),
                colorBlendMode: BlendMode.srcOver,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hello Jamie',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Search routines',
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Routines',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _createNewRoutine,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.add, color: accent, size: 20),
                                const SizedBox(width: 6),
                                Text('New', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: routines.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: routines.length,
                          itemBuilder: (context, index) {
                            final routine = routines[index];
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
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context, accent),
    );
  }

  Widget _buildModernRoutineCard(BuildContext context, Routine routine, Color accent, int index) {
    final cardBg = Colors.white;
    final iconBg = accent.withOpacity(0.12);
    final icon = Icons.list_alt_rounded;
    final taskCount = routine.tasks.length;
    final completed = 0; // TODO: Replace with real completion logic
    final total = taskCount;
    final hasTasks = total > 0;
    final progress = hasTasks ? completed / total : 0.0;
    final isInProgress = false; // TODO: Add real in-progress logic
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              routine.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isInProgress)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('In progress', style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                        ],
                      ),
                      if (routine.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          routine.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasTasks)
                            Text('$completed/$total tasks complete', style: Theme.of(context).textTheme.bodySmall)
                          else
                            Text('${routine.categories.length} categories • $taskCount tasks', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hasTasks ? progress : 0.0,
                          minHeight: 5,
                          backgroundColor: accent.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.35)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editRoutine(routine),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: accent.withOpacity(0.18)),
                      foregroundColor: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (details) {
                      // Animate shrink
                    },
                    onTapUp: (details) {
                      // Animate back
                      _startRoutine(routine);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text('Start', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: accent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
} 