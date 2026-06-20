import 'package:flutter/material.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../state/library_controller.dart';
import '../utils/format.dart';
import '../utils/youtube_links.dart';
import '../widgets/add_link_form.dart';
import '../widgets/item_tile.dart';
import 'note_editor_screen.dart';

/// One row in a folder: either a saved link or a note. They live in the same
/// date-ordered list and look alike.
class _Entry {
  _Entry.item(this.item) : note = null;
  _Entry.note(this.note) : item = null;

  final LibraryItem? item;
  final Note? note;

  int get dateMs => item?.addedAtMs ?? note!.createdAtMs;
}

/// Shows everything saved inside one folder — links and notes together, grouped
/// by the date they were added — and lets you add more.
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
    if (await _confirm('Remove this link?', item.title)) {
      await _c.deleteItem(item.id);
    }
  }

  Future<void> _confirmDeleteNote(Note note) async {
    if (await _confirm('Delete this note?', note.displayTitle)) {
      await _c.deleteNote(note.id);
    }
  }

  Future<bool> _confirm(String title, String detail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
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
    return ok == true;
  }

  /// Combined, date-sorted list of links and notes.
  List<MapEntry<String, List<_Entry>>> _grouped() {
    final entries = <_Entry>[
      for (final item in _c.itemsInFolder(widget.folderId)) _Entry.item(item),
      for (final note in _c.notesInFolder(widget.folderId)) _Entry.note(note),
    ]..sort((a, b) => b.dateMs.compareTo(a.dateMs));

    final groups = <String, List<_Entry>>{};
    final order = <String>[];
    for (final e in entries) {
      final label = dayLabel(e.dateMs);
      groups.putIfAbsent(label, () {
        order.add(label);
        return [];
      }).add(e);
    }
    return [for (final label in order) MapEntry(label, groups[label]!)];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final groups = _grouped();
        final total = _c.itemCountInFolder(widget.folderId) +
            _c.noteCountInFolder(widget.folderId);
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
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'In this folder · $total',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Nothing here yet.\nPaste a link above, or tap '
                      '"Add new note".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                )
              else
                for (final group in groups) ...[
                  _DateHeader(group.key),
                  for (final e in group.value)
                    if (e.item != null)
                      ItemTile(
                        item: e.item!,
                        controller: _c,
                        showAddedDate: true,
                        onTap: () => openItem(context, _c, e.item!),
                        onDelete: () => _confirmDeleteItem(e.item!),
                      )
                    else
                      _NoteTile(
                        note: e.note!,
                        onTap: () => _openNote(e.note!),
                        onDelete: () => _confirmDeleteNote(e.note!),
                      ),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
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

/// A note row styled to match [ItemTile]: thumbnail + title + subtitle + an
/// option (delete) button.
class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = note.body.trim();
    final hasLink = hasYoutubeLink(note.body);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: SizedBox(
        width: 84,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0x332E7DFF),
                child: const Icon(Icons.sticky_note_2, color: Color(0xFF82B1FF)),
              ),
              if (hasLink)
                Positioned(
                  left: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 13, color: Color(0xFFFF6E6E)),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        note.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.isEmpty
                ? (hasLink ? 'Note · has video link' : 'Note')
                : preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            'Added ${shortDate(note.createdAtMs)}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Remove',
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
