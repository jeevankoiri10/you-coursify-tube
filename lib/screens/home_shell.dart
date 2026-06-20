import 'package:flutter/material.dart';

import '../navigation.dart';
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
