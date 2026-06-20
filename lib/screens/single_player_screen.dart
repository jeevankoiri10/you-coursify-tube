import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/app_state.dart';
import '../services/storage.dart';
import 'paste_screen.dart';

/// Plays one video, forever. It starts where you left off, loops back to the
/// start when it ends, and continuously saves your position so the next launch
/// resumes automatically.
class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen({super.key, required this.video});

  final VideoItem video;

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _controller;
  late final VideoItem _video;
  double _lastPosition = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _lastPosition = _video.positionSeconds;
    WidgetsBinding.instance.addObserver(this);

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );

    // Resume exactly where we stopped last time.
    _controller.loadVideoById(
      videoId: _video.videoId,
      startSeconds: _video.positionSeconds,
    );

    // Loop forever: when the video ends, jump back to the start and replay.
    _controller.stream.listen((value) {
      if (!mounted) return;
      if (value.playerState == PlayerState.ended) {
        _lastPosition = 0;
        _controller.seekTo(seconds: 0, allowSeekAhead: true);
        _controller.playVideo();
      }
      final title = value.metaData.title;
      if (title.isNotEmpty && title != _video.title) {
        _video.title = title;
        if (mounted) setState(() {});
      }
    });

    // Track the play head so we always know the resume point.
    _controller.videoStateStream.listen((state) {
      _lastPosition = state.position.inMilliseconds / 1000.0;
    });

    // Persist periodically while watching.
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _persist(),
    );
  }

  Future<void> _persist() async {
    _video.positionSeconds = _lastPosition;
    await Storage.save(AppState(mode: LibraryMode.single, single: _video));
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

  Future<void> _changeLink() async {
    await _persist();
    await Storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PasteScreen()),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Paste a different link',
            icon: const Icon(Icons.edit),
            onPressed: _changeLink,
          ),
        ],
      ),
      body: Column(
        children: [
          YoutubePlayer(controller: _controller),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Looping. Closes and reopens right here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
