import 'package:flutter/material.dart';

import '../state/library_controller.dart';
import '../utils/youtube_links.dart';
import 'note_editor_screen.dart';

/// The Notes tab: write study notes, paste YouTube links into them, and tap the
/// links to open them inside the app.
class NotesTab extends StatelessWidget {
  const NotesTab({super.key, required this.controller});

  final LibraryController controller;

  void _openEditor(BuildContext context, {String? noteId}) {
    final note = noteId == null
        ? controller.createNote()
        : controller.notes.firstWhere((n) => n.id == noteId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(controller: controller, note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = controller.notes;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: const Color(0xFFFF4D4D),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New note'),
      ),
      body: notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No notes yet.\n\nTap "New note" to write one. Paste YouTube '
                  'links inside and they become tappable — they open right here '
                  'in the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final preview = note.body.trim();
                final hasLink = hasYoutubeLink(note.body);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  color: const Color(0xFF1C1C20),
                  child: ListTile(
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
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ),
                    trailing: hasLink
                        ? const Icon(Icons.smart_display_outlined,
                            color: Color(0xFFFF4D4D))
                        : const Icon(Icons.chevron_right),
                    onTap: () => _openEditor(context, noteId: note.id),
                  ),
                );
              },
            ),
    );
  }
}
