import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../state/library_controller.dart';
import '../utils/youtube_links.dart';

/// Writes/reads a single note. In Read mode, YouTube links in the body become
/// tappable and open inside the app. In Edit mode it's a plain text editor.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.controller,
    required this.note,
  });

  final LibraryController controller;
  final Note note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _reading;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _bodyController = TextEditingController(text: widget.note.body);
    // A brand-new, empty note opens in edit mode; an existing one opens in read
    // mode so its links are immediately tappable.
    _reading = widget.note.body.trim().isNotEmpty;
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _isEmpty =>
      _titleController.text.trim().isEmpty && _bodyController.text.trim().isEmpty;

  Future<void> _save() async {
    if (_isEmpty) {
      // Don't keep blank notes around.
      await widget.controller.deleteNote(widget.note.id);
      return;
    }
    widget.note.title = _titleController.text;
    widget.note.body = _bodyController.text;
    await widget.controller.saveNote(widget.note);
  }

  void _toggleMode() {
    setState(() => _reading = !_reading);
    if (_reading) _save();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
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
    if (ok == true) {
      await widget.controller.deleteNote(widget.note.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _save();
    }
  }

  @override
  void dispose() {
    _save();
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _save(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_reading ? 'Note' : 'Editing note'),
          actions: [
            IconButton(
              tooltip: _reading ? 'Edit' : 'Done',
              icon: Icon(_reading ? Icons.edit : Icons.check),
              onPressed: _toggleMode,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: _reading ? _buildReader() : _buildEditor(),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
          const Divider(),
          Expanded(
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText:
                    'Write your notes here…\n\nPaste YouTube links — switch to '
                    'read mode (✓) and tap them to watch inside the app.',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReader() {
    final title = _titleController.text.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        _LinkifiedText(
          text: _bodyController.text,
          onTapLink: (url) =>
              openYoutubeUrl(context, widget.controller, url),
        ),
      ],
    );
  }
}

/// Renders text with tappable YouTube links.
class _LinkifiedText extends StatefulWidget {
  const _LinkifiedText({required this.text, required this.onTapLink});
  final String text;
  final void Function(String url) onTapLink;

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final segments = linkifyYoutube(widget.text);
    final spans = <InlineSpan>[];
    for (final seg in segments) {
      if (seg.isYoutube) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onTapLink(seg.text);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: seg.text,
          style: const TextStyle(
            color: Color(0xFFFF6E6E),
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFFF6E6E),
          ),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(text: seg.text));
      }
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(
            fontSize: 16, height: 1.5, color: Colors.white),
        children: spans,
      ),
    );
  }
}
