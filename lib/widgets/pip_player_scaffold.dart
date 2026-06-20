import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/format.dart';

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
          YoutubePlayer(
            controller: widget.controller,
            // Custom controls: center play/pause, bottom-right fullscreen.
            // Hidden in PiP, where the system shows its own controls.
            controlsBuilder: (context, isFullscreen) => _isPip
                ? const SizedBox.shrink()
                : _PlayerControls(
                    controller: widget.controller,
                    isFullscreen: isFullscreen,
                  ),
          ),
          if (!_isPip) Expanded(child: widget.below),
        ],
      ),
    );
  }
}

/// A minimal controls overlay drawn over the player: tap to show/hide, a big
/// center play/pause button, a seek bar, and a fullscreen button in the
/// bottom-right corner.
class _PlayerControls extends StatefulWidget {
  const _PlayerControls({required this.controller, required this.isFullscreen});

  final YoutubePlayerController controller;
  final bool isFullscreen;

  @override
  State<_PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<_PlayerControls> {
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  Timer? _hideTimer;

  bool _visible = true;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _valueSub = widget.controller.stream.listen((value) {
      if (!mounted) return;
      final playing = value.playerState == PlayerState.playing;
      final duration = value.metaData.duration;
      if (playing != _playing || duration != _duration) {
        setState(() {
          _playing = playing;
          if (duration > Duration.zero) _duration = duration;
        });
      }
      if (playing) _scheduleHide();
    });
    _stateSub = widget.controller.videoStateStream.listen((state) {
      if (mounted && _dragValue == null) {
        setState(() => _position = state.position);
      }
    });
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) setState(() => _visible = false);
    });
  }

  void _toggleVisible() {
    setState(() => _visible = !_visible);
    if (_visible) _scheduleHide();
  }

  void _togglePlay() {
    if (_playing) {
      widget.controller.pauseVideo();
    } else {
      widget.controller.playVideo();
    }
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _valueSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final sliderValue =
        (_dragValue ?? _position.inSeconds.toDouble()).clamp(0.0, maxSeconds);

    return Stack(
      children: [
        // Tap anywhere to toggle the controls.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleVisible,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black26,
                child: Stack(
                  children: [
                    // Center: play / pause.
                    Center(
                      child: IconButton(
                        iconSize: 58,
                        icon: Icon(
                          _playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlay,
                      ),
                    ),
                    // Bottom: seek bar + time + fullscreen (bottom-right).
                    Positioned(
                      left: 8,
                      right: 4,
                      bottom: 0,
                      child: Row(
                        children: [
                          Text(
                            formatDuration(_position.inSeconds),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12),
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                activeTrackColor: const Color(0xFFFF4D4D),
                                thumbColor: const Color(0xFFFF4D4D),
                                inactiveTrackColor: Colors.white30,
                              ),
                              child: Slider(
                                value: sliderValue,
                                max: maxSeconds,
                                onChanged: (v) =>
                                    setState(() => _dragValue = v),
                                onChangeEnd: (v) {
                                  widget.controller
                                      .seekTo(seconds: v, allowSeekAhead: true);
                                  setState(() {
                                    _position = Duration(seconds: v.round());
                                    _dragValue = null;
                                  });
                                  _scheduleHide();
                                },
                              ),
                            ),
                          ),
                          Text(
                            formatDuration(_duration.inSeconds),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          IconButton(
                            tooltip: 'Fullscreen',
                            icon: Icon(
                              widget.isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                widget.controller.toggleFullScreen(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
