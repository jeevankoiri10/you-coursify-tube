import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Wraps a YouTube player so it keeps playing in a floating Picture-in-Picture
/// window when the app is minimized, with system play/pause (and next/previous)
/// controls.
///
/// The player widget is always the first child of the same column, so switching
/// between full-screen and PiP layouts never rebuilds the underlying WebView —
/// playback continues seamlessly.
class PipPlayerScaffold extends StatefulWidget {
  const PipPlayerScaffold({
    super.key,
    required this.controller,
    required this.title,
    required this.below,
    this.onNext,
    this.onPrevious,
  });

  final YoutubePlayerController controller;
  final String title;

  /// Content shown beneath the player in normal (non-PiP) mode.
  final Widget below;

  /// Optional playlist controls, surfaced as PiP next/previous buttons.
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  State<PipPlayerScaffold> createState() => _PipPlayerScaffoldState();
}

class _PipPlayerScaffoldState extends State<PipPlayerScaffold> {
  final SimplePip _pip = SimplePip();
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _isPip = false;
  bool? _lastPlaying;

  @override
  void initState() {
    super.initState();
    _enableAutoPip();
    // Keep the PiP play/pause button icon in sync with the actual state.
    _sub = widget.controller.stream.listen((value) {
      final playing = value.playerState == PlayerState.playing;
      if (playing != _lastPlaying) {
        _lastPlaying = playing;
        _pip.setIsPlaying(playing);
      }
    });
  }

  Future<void> _enableAutoPip() async {
    try {
      if (await SimplePip.isAutoPipAvailable) {
        // Android 12+: entering PiP automatically when the user leaves the app.
        await _pip.setAutoPipMode(autoEnter: true);
      }
    } catch (_) {
      // PiP not supported on this device; the manual button still works where
      // available, and the app simply behaves normally otherwise.
    }
  }

  Future<void> _enterPip() async {
    try {
      await _pip.enterPipMode();
    } catch (_) {}
  }

  void _onAction(PipAction action) {
    switch (action) {
      case PipAction.play:
        widget.controller.playVideo();
      case PipAction.pause:
        widget.controller.pauseVideo();
      case PipAction.next:
        widget.onNext?.call();
      case PipAction.previous:
        widget.onPrevious?.call();
      default:
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.onNext != null
        ? PipActionsLayout.media // previous · play/pause · next
        : PipActionsLayout.mediaOnlyPause; // play/pause only

    return PipWidget(
      pipLayout: layout,
      onPipEntered: () => setState(() => _isPip = true),
      onPipExited: () => setState(() => _isPip = false),
      onPipAction: _onAction,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: _isPip
            ? null
            : AppBar(
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: 'Play in a floating window',
                    icon: const Icon(Icons.picture_in_picture_alt),
                    onPressed: _enterPip,
                  ),
                ],
              ),
        body: Column(
          children: [
            // Always the first child, with keepAlive so the WebView survives
            // the PiP transition.
            YoutubePlayer(controller: widget.controller, keepAlive: true),
            if (!_isPip) Expanded(child: widget.below),
          ],
        ),
      ),
    );
  }
}
