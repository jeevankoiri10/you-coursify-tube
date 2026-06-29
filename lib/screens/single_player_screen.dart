import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../state/library_controller.dart';
import '../widgets/web_pip_player_scaffold.dart';
import 'youtube_signin_screen.dart';

/// Plays one saved video, forever. Starts where you left off, loops back to the
/// start when it ends, and continuously saves your position.
class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen({
    super.key,
    required this.item,
    required this.controller,
  });

  final LibraryItem item;
  final LibraryController controller;

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen>
    with WidgetsBindingObserver {
  final WebPlayerHandle _handle = WebPlayerHandle();
  VideoItem get _video => widget.item.video!;
  late final double _initialStart;
  double _lastPosition = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    // Resume from the centralized progress for this video id (shared with any
    // other place the same URL appears).
    _initialStart = widget.controller.startFor(_video.videoId);
    _lastPosition = _initialStart;
    WidgetsBinding.instance.addObserver(this);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
  }

  void _onProgress(double position, int? duration) {
    _lastPosition = position;
  }

  Future<void> _onEnded() async {
    _lastPosition = 0;
    await widget.controller.saveProgress(
      _video.videoId,
      position: 0,
      duration: _video.durationSeconds,
      completed: true,
    );
    _handle.replay();
  }

  Future<void> _persist() async {
    await widget.controller.saveProgress(
      _video.videoId,
      position: _lastPosition,
      duration: _video.durationSeconds,
    );
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YoutubeSignInScreen()),
    );
    _handle.reload(); // retry playback with the signed-in session
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _persist();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebPipPlayerScaffold(
      videoId: _video.videoId,
      startSeconds: _initialStart,
      title: _video.title,
      handle: _handle,
      onProgress: _onProgress,
      onEnded: _onEnded,
      onSignIn: _openSignIn,
      below: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Looping. Reopens right here.\n'
            'Minimize the app to keep watching in a floating window.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }
}
