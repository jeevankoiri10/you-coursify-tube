import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../services/youtube_service.dart';
import '../state/library_controller.dart';

/// The onboarding/add flow: paste a YouTube link, choose a folder to save it
/// into, then Start. Used on Home and inside a folder.
class AddLinkForm extends StatefulWidget {
  const AddLinkForm({
    super.key,
    required this.controller,
    this.fixedFolderId,
    this.autoOpen = true,
  });

  final LibraryController controller;

  /// When provided (e.g. adding from inside a folder) the folder chooser is
  /// hidden and the item always lands in this folder.
  final String? fixedFolderId;

  /// Whether to immediately open the player after saving.
  final bool autoOpen;

  @override
  State<AddLinkForm> createState() => _AddLinkFormState();
}

class _AddLinkFormState extends State<AddLinkForm> {
  final _linkController = TextEditingController();
  String? _selectedFolderId;
  bool _busy = false;
  String? _error;

  LibraryController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.fixedFolderId ??
        (_c.folders.isNotEmpty ? _c.folders.first.id : null);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _linkController.text = text;
      _linkController.selection =
          TextSelection.collapsed(offset: text.length);
      setState(() => _error = null);
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(title: 'New folder'),
    );
    if (name == null || name.trim().isEmpty) return;
    final folder = await _c.createFolder(name);
    setState(() => _selectedFolderId = folder.id);
  }

  Future<void> _start() async {
    final parsed = YoutubeService.parse(_linkController.text);
    if (parsed.kind == LinkKind.invalid) {
      setState(() => _error = "That doesn't look like a YouTube link.");
      return;
    }
    final folderId = _selectedFolderId;
    if (folderId == null) {
      setState(() => _error = 'Pick a folder first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final LibraryItem item;
      if (parsed.kind == LinkKind.playlist) {
        final playlist = await YoutubeService.fetchPlaylist(parsed.id);
        item = await _c.addItem(
          type: ItemType.playlist,
          folderId: folderId,
          playlist: playlist,
        );
      } else {
        final video = await YoutubeService.buildSingle(parsed.id);
        item = await _c.addItem(
          type: ItemType.video,
          folderId: folderId,
          video: video,
        );
      }

      _linkController.clear();
      if (!mounted) return;
      setState(() => _busy = false);

      if (widget.autoOpen) {
        await openItem(context, _c, item);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to folder')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not load that link. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFolderChooser = widget.fixedFolderId == null;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF1C1C20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _linkController,
              enabled: !_busy,
              autocorrect: false,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _start(),
              decoration: InputDecoration(
                hintText: 'Paste a YouTube video or playlist link',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _busy ? null : _paste,
                ),
              ),
            ),
            if (showFolderChooser) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFolderId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Save to folder',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: [
                        for (final f in _c.folders)
                          DropdownMenuItem(value: f.id, child: Text(f.name)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _selectedFolderId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'New folder',
                    onPressed: _busy ? null : _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFFFF4D4D),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_busy ? 'Loading…' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small reusable single-field text dialog (used for folder names).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});
  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Public helper so other screens can prompt for a folder name too.
Future<String?> promptFolderName(BuildContext context,
        {String title = 'New folder', String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial),
    );
