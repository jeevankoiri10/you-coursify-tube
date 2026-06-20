import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Wraps a YouTube player so it keeps playing in a floating Picture-in-Picture
/// window when the app is minimized, with system play/pause (and next/previous)
/// controls.
///
/// We drive PiP through [SimplePip] directly (instead of `PipWidget`) so the
/// player lives in a single widget tree: only the surrounding chrome toggles
/// between full-screen and PiP, so the underlying WebView is never rebuilt and
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
  late final SimplePip _pip;
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _isPip = false;
  bool? _lastPlaying;

  @override
  void initState() {
    super.initState();
    _pip = SimplePip(
      onPipEntered: () => setState(() => _isPip = true),
      onPipExited: () => setState(() => _isPip = false),
      onPipAction: _onAction,
    );
    _pip.setPipActionsLayout(
      widget.onNext != null
          ? PipActionsLayout.media // previous · play/pause · next
          : PipActionsLayout.mediaOnlyPause, // play/pause only
    );
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
        // Android 12+: enter PiP automatically when the user leaves the app.
        await _pip.setAutoPipMode(autoEnter: true);
      }
    } catch (_) {
      // PiP unsupported on this device — the app just behaves normally.
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
    return Scaffold(
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
      // The player is always the first child of this column; only the content
      // below it is added/removed for PiP, so the player element (and its
      // WebView) stays alive across the transition.
      body: Column(
        children: [
          YoutubePlayer(controller: widget.controller),
          if (!_isPip) Expanded(child: widget.below),
        ],
      ),
    );
  }
}
