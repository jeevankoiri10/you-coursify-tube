import 'package:flutter/material.dart';

import '../models/library.dart';
import '../state/library_controller.dart';
import '../widgets/add_link_form.dart';
import 'folder_screen.dart';

/// The Directory tab: your folders. Open one to see (and play) the links saved
/// inside it.
class DirectoryTab extends StatelessWidget {
  const DirectoryTab({super.key, required this.controller});

  final LibraryController controller;

  Future<void> _createFolder(BuildContext context) async {
    final name = await promptFolderName(context);
    if (name != null && name.trim().isNotEmpty) {
      await controller.createFolder(name);
    }
  }

  Future<void> _confirmDeleteFolder(BuildContext context, Folder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text(
            'Links inside will be moved to General, not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteFolder(folder.id);
  }

  @override
  Widget build(BuildContext context) {
    final folders = controller.folders;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createFolder(context),
        backgroundColor: const Color(0xFFFF4D4D),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Folders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final folder in folders)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: const Color(0xFF1C1C20),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x33FF4D4D),
                  child: Icon(Icons.folder, color: Color(0xFFFF4D4D)),
                ),
                title: Text(folder.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${controller.itemCountInFolder(folder.id)} links'),
                trailing: folder.id == LibraryController.defaultFolderId
                    ? const Icon(Icons.chevron_right)
                    : PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'delete') {
                            _confirmDeleteFolder(context, folder);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                              value: 'delete', child: Text('Delete folder')),
                        ],
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FolderScreen(
                      controller: controller,
                      folderId: folder.id,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
