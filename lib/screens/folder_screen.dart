import 'package:flutter/material.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../state/library_controller.dart';
import '../widgets/add_link_form.dart';
import '../widgets/item_tile.dart';

/// Shows the links saved inside one folder, and lets you add more to it.
class FolderScreen extends StatefulWidget {
  const FolderScreen({
    super.key,
    required this.controller,
    required this.folderId,
  });

  final LibraryController controller;
  final String folderId;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  LibraryController get _c => widget.controller;
  Folder get _folder => _c.folderById(widget.folderId);

  Future<void> _rename() async {
    final name = await promptFolderName(context,
        title: 'Rename folder', initial: _folder.name);
    if (name != null && name.trim().isNotEmpty) {
      await _c.renameFolder(widget.folderId, name);
      setState(() {});
    }
  }

  Future<void> _confirmDeleteItem(LibraryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this link?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _c.deleteItem(item.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final items = _c.itemsInFolder(widget.folderId);
        return Scaffold(
          appBar: AppBar(
            title: Text(_folder.name),
            actions: [
              IconButton(
                tooltip: 'Rename folder',
                icon: const Icon(Icons.drive_file_rename_outline),
                onPressed: _rename,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              AddLinkForm(
                controller: _c,
                fixedFolderId: widget.folderId,
                autoOpen: false,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'Saved links · ${items.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('No links in this folder yet.',
                        style: TextStyle(color: Colors.white38)),
                  ),
                )
              else
                for (final item in items)
                  ItemTile(
                    item: item,
                    onTap: () => openItem(context, _c, item),
                    onDelete: () => _confirmDeleteItem(item),
                  ),
            ],
          ),
        );
      },
    );
  }
}
