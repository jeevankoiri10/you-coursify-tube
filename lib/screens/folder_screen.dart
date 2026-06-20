import 'package:flutter/material.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../state/library_controller.dart';
import '../utils/format.dart';
import '../utils/youtube_links.dart';
import '../widgets/add_link_form.dart';
import '../widgets/item_tile.dart';
import 'note_editor_screen.dart';

/// Shows the links and notes saved inside one folder, and lets you add more.
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

  void _addNote() {
    final note = _c.createNote(widget.folderId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(controller: _c, note: note),
      ),
    );
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(controller: _c, note: note),
      ),
    );
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
        final notes = _c.notesInFolder(widget.folderId);
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addNote,
            backgroundColor: const Color(0xFFFF4D4D),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Add new note'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              AddLinkForm(
                controller: _c,
                fixedFolderId: widget.folderId,
                autoOpen: false,
              ),
              const SizedBox(height: 16),
              _SectionTitle('Saved links · ${items.length}'),
              if (items.isEmpty)
                const _EmptyHint('No links in this folder yet.')
              else
                // Grouped by the date each link was added (newest first).
                for (final group in _groupByDay(items)) ...[
                  _DateHeader(group.key),
                  for (final item in group.value)
                    ItemTile(
                      item: item,
                      showAddedDate: true,
                      onTap: () => openItem(context, _c, item),
                      onDelete: () => _confirmDeleteItem(item),
                    ),
                ],
              const SizedBox(height: 20),
              _SectionTitle('Notes · ${notes.length}'),
              if (notes.isEmpty)
                const _EmptyHint(
                    'No notes yet. Tap "Add new note" to write one.')
              else
                for (final note in notes) _NoteTile(note: note, onTap: () => _openNote(note)),
            ],
          ),
        );
      },
    );
  }
}

/// Groups items (already sorted newest-first) under date labels, preserving
/// order so "Today", "Yesterday", then older dates appear top to bottom.
List<MapEntry<String, List<LibraryItem>>> _groupByDay(List<LibraryItem> items) {
  final groups = <String, List<LibraryItem>>{};
  final order = <String>[];
  for (final item in items) {
    final label = dayLabel(item.addedAtMs);
    final list = groups.putIfAbsent(label, () {
      order.add(label);
      return [];
    });
    list.add(item);
  }
  return [for (final label in order) MapEntry(label, groups[label]!)];
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
      child: Row(
        children: [
          const Icon(Icons.event, size: 14, color: Color(0xFFFF4D4D)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF6E6E),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38)),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = note.body.trim();
    final hasLink = hasYoutubeLink(note.body);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      color: const Color(0xFF1C1C20),
      child: ListTile(
        leading: const Icon(Icons.sticky_note_2_outlined, color: Colors.white70),
        title: Text(
          note.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: preview.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
        trailing: hasLink
            ? const Icon(Icons.smart_display_outlined, color: Color(0xFFFF4D4D))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
