import 'package:flutter/material.dart';

import '../navigation.dart';
import '../services/backup_service.dart';
import '../state/library_controller.dart';
import 'directory_tab.dart';
import 'home_tab.dart';

/// The root screen after launch: a bottom nav bar switching between Home (paste,
/// continue watching, history) and Directory (folders).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Home automatically resumes the last thing you were watching.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = widget.controller.current;
      if (current != null && mounted) {
        openItem(context, widget.controller, current);
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    try {
      await BackupService.export(widget.controller);
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  Future<void> _import() async {
    // Confirm the (destructive) replace before picking a file.
    final confirmed = await _confirmImport();
    if (!confirmed) return;
    try {
      final imported = await BackupService.pickAndImport(widget.controller);
      _snack(imported ? 'Data imported.' : 'Import cancelled.');
    } catch (e) {
      _snack('Import failed: not a valid backup. ($e)');
    }
  }

  Future<bool> _confirmImport() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import data?'),
        content: const Text(
          'This replaces ALL current folders, links and notes with the '
          'contents of the backup file you pick. Consider exporting first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final tabs = [
          HomeTab(controller: widget.controller),
          DirectoryTab(controller: widget.controller),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('You Coursify Tube'),
            centerTitle: false,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.import_export),
                tooltip: 'Backup',
                onSelected: (value) {
                  if (value == 'export') _export();
                  if (value == 'import') _import();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.upload_file),
                      title: Text('Export all data'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Import data'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'Directory',
              ),
            ],
          ),
        );
      },
    );
  }
}
