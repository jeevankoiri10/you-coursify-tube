import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/auto_backup_service.dart';
import 'services/storage.dart';
import 'state/library_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved library (folders, links, positions, history) so the app
  // reopens straight into the content and resumes automatically.
  final library = await Storage.load();
  final controller = LibraryController(library);

  // Fresh install / cleared data: if there's nothing saved yet but an on-device
  // backup snapshot exists, restore it automatically so the app fills back in.
  if (library.items.isEmpty && library.notes.isEmpty) {
    await _restoreFromBackup(controller);
  }

  runApp(CoursifyApp(controller: controller));
}

/// Loads the newest automatic backup snapshot into [controller], if one exists.
Future<void> _restoreFromBackup(LibraryController controller) async {
  try {
    final file = await AutoBackupService.latest();
    if (file == null) return;
    final json = await file.readAsString();
    if (json.trim().isEmpty) return;
    await controller.importJson(json); // replaces data and persists it
  } catch (_) {
    // Corrupt or unreadable snapshot — start clean rather than crash.
  }
}

class CoursifyApp extends StatefulWidget {
  const CoursifyApp({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<CoursifyApp> createState() => _CoursifyAppState();
}

class _CoursifyAppState extends State<CoursifyApp> with WidgetsBindingObserver {
  Timer? _timer;
  bool _dirty = false;
  int _lastBackupMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Any data change marks the library for the next auto-backup.
    widget.controller.addListener(_markDirty);
    // Periodically flush a backup while the app is open.
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _flush());
  }

  void _markDirty() => _dirty = true;

  Future<void> _flush({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Never back up more than once every 5s — collapses the rapid
    // inactive/hidden/paused lifecycle burst into a single write.
    if (now - _lastBackupMs < 5 * 1000) return;
    if (!force && !_dirty) return;
    _dirty = false;
    _lastBackupMs = now;
    try {
      await AutoBackupService.backup(widget.controller, timestampMs: now);
    } catch (_) {
      // Best-effort; manual export remains available.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _flush(force: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_markDirty);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      home: HomeShell(controller: widget.controller),
    );
  }
}
