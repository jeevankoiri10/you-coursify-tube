import 'package:flutter/material.dart';

import 'models/app_state.dart';
import 'screens/paste_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/single_player_screen.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load whatever was saved so we can open straight into the video/playlist
  // without ever asking the user to type a link again.
  final state = await Storage.load();
  runApp(FloaterApp(initialState: state));
}

class FloaterApp extends StatelessWidget {
  const FloaterApp({super.key, required this.initialState});

  final AppState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floater',
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
      ),
      home: _homeFor(initialState),
    );
  }

  Widget _homeFor(AppState state) {
    switch (state.mode) {
      case LibraryMode.single:
        if (state.single != null) {
          return SinglePlayerScreen(video: state.single!);
        }
        return const PasteScreen();
      case LibraryMode.playlist:
        if (state.playlist != null && state.playlist!.videos.isNotEmpty) {
          return PlaylistScreen(playlist: state.playlist!);
        }
        return const PasteScreen();
      case LibraryMode.empty:
        return const PasteScreen();
    }
  }
}
