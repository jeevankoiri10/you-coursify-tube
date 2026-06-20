import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_state.dart';
import '../services/storage.dart';
import '../services/youtube_service.dart';
import 'playlist_screen.dart';
import 'single_player_screen.dart';

/// The first thing you see when nothing is saved yet: a single field to paste a
/// YouTube video or playlist link.
class PasteScreen extends StatefulWidget {
  const PasteScreen({super.key});

  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _controller.text = data.text!.trim();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      setState(() => _error = null);
    }
  }

  Future<void> _open() async {
    final input = _controller.text.trim();
    final parsed = YoutubeService.parse(input);
    if (parsed.kind == LinkKind.invalid) {
      setState(() => _error = "That doesn't look like a YouTube link.");
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (parsed.kind == LinkKind.playlist) {
        final playlist = await YoutubeService.fetchPlaylist(parsed.id);
        await Storage.save(
          AppState(mode: LibraryMode.playlist, playlist: playlist),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
        );
      } else {
        final video = await YoutubeService.buildSingle(parsed.id);
        await Storage.save(AppState(mode: LibraryMode.single, single: video));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SinglePlayerScreen(video: video)),
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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.play_circle_fill,
                      size: 72, color: Color(0xFFFF4D4D)),
                  const SizedBox(height: 16),
                  Text(
                    'Floater',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste a YouTube video or playlist link.\n'
                    'It stays here and resumes where you left off.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _open(),
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/watch?v=...',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _busy ? null : _pasteFromClipboard,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8A80)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _open,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                    label: Text(_busy ? 'Loading…' : 'Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
