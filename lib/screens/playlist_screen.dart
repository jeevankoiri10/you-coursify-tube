import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../state/library_controller.dart';
import '../utils/format.dart';

/// Plays a saved playlist. The current video sits at the top; below it is the
/// full list with a marker on "where you left off" and per-video progress.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.item,
    required this.controller,
  });

  final LibraryItem item;
  final LibraryController controller;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _player;
  PlaylistData get _playlist => widget.item.playlist!;
  double _lastPosition = 0;
  Timer? _saveTimer;

  VideoItem get _current => _playlist.current;

  @override
  void initState() {
    super.initState();
    _lastPosition = _current.positionSeconds;
    WidgetsBinding.instance.addObserver(this);

    _player = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );

    _player.loadVideoById(
      videoId: _current.videoId,
      startSeconds: _current.positionSeconds,
    );

    _player.stream.listen((value) {
      if (!mounted) return;
      if (value.playerState == PlayerState.ended) {
        _current.completed = true;
        _current.positionSeconds = 0;
        _playNext();
      }
      final title = value.metaData.title;
      if (title.isNotEmpty && title != _current.title) {
        _current.title = title;
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
    _current.positionSeconds = _lastPosition;
    await widget.controller.persist();
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _playlist.videos.length) return;
    _current.positionSeconds = _lastPosition;
    setState(() => _playlist.currentIndex = index);
    widget.controller.touch();
    _lastPosition = _current.positionSeconds;
    await _player.loadVideoById(
      videoId: _current.videoId,
      startSeconds: _current.positionSeconds,
    );
    await _persist();
  }

  void _playNext() {
    final next = _playlist.currentIndex + 1;
    _playAt(next >= _playlist.videos.length ? 0 : next);
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          YoutubePlayer(controller: _player),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Up next · ${_playlist.currentIndex + 1}/${_playlist.videos.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _playlist.videos.length,
              itemBuilder: (context, index) {
                final v = _playlist.videos[index];
                return _PlaylistTile(
                  index: index,
                  video: v,
                  isCurrent: index == _playlist.currentIndex,
                  onTap: () => _playAt(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.index,
    required this.video,
    required this.isCurrent,
    required this.onTap,
  });

  final int index;
  final VideoItem video;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final watched = video.positionSeconds;
    final total = video.durationSeconds;
    final progress =
        (total != null && total > 0) ? (watched / total).clamp(0.0, 1.0) : 0.0;

    final subtitle = video.completed
        ? 'Watched'
        : watched > 1
            ? 'Left off at ${formatDuration(watched)}'
                '${total != null ? ' / ${formatDuration(total)}' : ''}'
            : (total != null ? formatDuration(total) : 'Not started');

    return Material(
      color: isCurrent ? const Color(0x22FF4D4D) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.thumbnailUrl != null)
                        Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              Container(color: Colors.white12),
                        )
                      else
                        Container(color: Colors.white12),
                      if (isCurrent)
                        Container(
                          color: Colors.black45,
                          child: const Icon(Icons.equalizer,
                              color: Color(0xFFFF4D4D)),
                        ),
                      if (progress > 0)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFFFF4D4D)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${video.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (video.completed)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle,
                                size: 14, color: Color(0xFF7CB342)),
                          ),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
