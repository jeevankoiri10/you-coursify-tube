import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/storage.dart';
import 'state/library_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved library (folders, links, positions, history) so the app
  // reopens straight into the content and resumes automatically.
  final library = await Storage.load();
  runApp(CoursifyApp(controller: LibraryController(library)));
}

class CoursifyApp extends StatelessWidget {
  const CoursifyApp({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'You Coursify Tube',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101012),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D4D),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF18181B)),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF18181B),
          indicatorColor: const Color(0x33FF4D4D),
        ),
      ),
      home: HomeShell(controller: controller),
    );
  }
}
