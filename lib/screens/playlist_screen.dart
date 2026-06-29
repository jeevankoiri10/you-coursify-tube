import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../state/library_controller.dart';
import '../utils/clipboard.dart';
import '../utils/format.dart';
import '../widgets/web_pip_player_scaffold.dart';
import 'youtube_signin_screen.dart';

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
  final WebPlayerHandle _handle = WebPlayerHandle();
  PlaylistData get _playlist => widget.item.playlist!;
  double _lastPosition = 0;
  Timer? _saveTimer;

  VideoItem get _current => _playlist.current;

  @override
  void initState() {
    super.initState();
    _lastPosition = widget.controller.startFor(_current.videoId);
    WidgetsBinding.instance.addObserver(this);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
  }

  void _onProgress(double position, int? duration) {
    _lastPosition = position;
  }

  Future<void> _onEnded() async {
    await widget.controller.saveProgress(
      _current.videoId,
      position: 0,
      duration: _current.durationSeconds,
      completed: true,
    );
    _playNext();
  }

  Future<void> _persist() async {
    await widget.controller.saveProgress(
      _current.videoId,
      position: _lastPosition,
      duration: _current.durationSeconds,
    );
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _playlist.videos.length) return;
    // Save where we are on the current video before switching.
    await _persist();
    setState(() => _playlist.currentIndex = index);
    widget.controller.touch();
    // The new video id flows into WebPipPlayerScaffold, which loads it
    // resuming at this position.
    _lastPosition = widget.controller.startFor(_current.videoId);
    // Remember which video this playlist is on.
    await widget.controller.persist();
  }

  void _playNext() {
    final next = _playlist.currentIndex + 1;
    _playAt(next >= _playlist.videos.length ? 0 : next);
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

  void _playPrevious() {
    final prev = _playlist.currentIndex - 1;
    _playAt(prev < 0 ? _playlist.videos.length - 1 : prev);
  }

  @override
  Widget build(BuildContext context) {
    return WebPipPlayerScaffold(
      videoId: _current.videoId,
      startSeconds: _lastPosition,
      title: _playlist.title,
      handle: _handle,
      onProgress: _onProgress,
      onEnded: _onEnded,
      onSignIn: _openSignIn,
      onNext: _playNext,
      onPrevious: _playPrevious,
      below: Column(
        children: [
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
                  progress: widget.controller.progressFor(v.videoId),
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
    required this.progress,
    required this.isCurrent,
    required this.onTap,
  });

  final int index;
  final VideoItem video;
  final VideoProgress progress;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final watched = progress.positionSeconds;
    final total = video.durationSeconds ?? progress.durationSeconds;
    final fraction =
        (total != null && total > 0) ? (watched / total).clamp(0.0, 1.0) : 0.0;

    final subtitle = progress.completed
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
                      if (fraction > 0)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: fraction,
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
                        if (progress.completed)
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
              IconButton(
                icon: const Icon(Icons.link, size: 20),
                tooltip: 'Copy link',
                color: Colors.white54,
                onPressed: () => copyLink(context, video.url),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
