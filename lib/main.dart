import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/edit_routine_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/routine_player_screen.dart';
import 'services/theme_service.dart';
import 'services/routine_service.dart';
import 'theme.dart';
import 'models/routine.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(RoutineAdapter());
  Hive.registerAdapter(TaskAdapter());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => RoutineService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Pebble',
            theme: themeService.currentTheme,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
            onGenerateRoute: (settings) {
              if (settings.name == '/edit') {
                final routine = settings.arguments as Routine?;
                return MaterialPageRoute(
                  builder: (context) => EditRoutineScreen(routine: routine),
                );
              }
              if (settings.name == '/settings') {
                return MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                );
              }
              if (settings.name == '/player') {
                final routine = settings.arguments as Routine;
                return MaterialPageRoute(
                  builder: (context) => RoutinePlayerScreen(routine: routine),
                );
              }
              // Add other routes here as needed
              return null;
            },
          );
        },
      ),
    );
  }
}
