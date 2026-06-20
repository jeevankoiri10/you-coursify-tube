import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../state/library_controller.dart';
import '../widgets/pip_player_scaffold.dart';

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
  late final YoutubePlayerController _player;
  VideoItem get _video => widget.item.video!;
  double _lastPosition = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    // Resume from the centralized progress for this video id (shared with any
    // other place the same URL appears).
    _lastPosition = widget.controller.startFor(_video.videoId);
    WidgetsBinding.instance.addObserver(this);

    _player = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );

    _player.loadVideoById(
      videoId: _video.videoId,
      startSeconds: _lastPosition,
    );

    _player.stream.listen((value) {
      if (!mounted) return;
      if (value.playerState == PlayerState.ended) {
        _lastPosition = 0;
        widget.controller.saveProgress(
          _video.videoId,
          position: 0,
          duration: _video.durationSeconds,
          completed: true,
        );
        _player.seekTo(seconds: 0, allowSeekAhead: true);
        _player.playVideo();
      }
      final title = value.metaData.title;
      if (title.isNotEmpty && title != _video.title) {
        _video.title = title;
        widget.controller.touch();
        setState(() {});
      }
    });

    _player.videoStateStream.listen((state) {
      _lastPosition = state.position.inMilliseconds / 1000.0;
    });

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
  }

  Future<void> _persist() async {
    await widget.controller.saveProgress(
      _video.videoId,
      position: _lastPosition,
      duration: _video.durationSeconds,
    );
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
    _player.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PipPlayerScaffold(
      controller: _player,
      title: _video.title,
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
