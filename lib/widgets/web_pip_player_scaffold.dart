import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// A normal mobile-Chrome user agent. YouTube serves a real, playable page (and
/// honors the signed-in session) to this; the embedded iframe player it would
/// otherwise reject with "sign in to confirm you're not a bot".
const String youtubeMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// Imperative handle the owning screen uses to drive the player (loop a single
/// video, or relay PiP play/pause).
class WebPlayerHandle {
  _WebPipPlayerScaffoldState? _state;

  void play() => _state?._runVideo('v.play();');
  void pause() => _state?._runVideo('v.pause();');
  void replay() => _state?._runVideo('v.currentTime=0; v.play();');

  /// Reloads the current video (e.g. to retry playback after signing in).
  void reload() => _state?._load();
}

/// Plays a single YouTube video inside an in-app WebView, showing *only* the
/// player (YouTube's top bar is hidden and scrolling is locked), and keeps it
/// running in Picture-in-Picture when the app is minimized.
///
/// The UI is identical to the previous iframe-based player: a 16:9 player on
/// top with [below] beneath it. Only the playback engine differs — this one
/// loads the real watch page so a signed-in session unblocks gated videos.
class WebPipPlayerScaffold extends StatefulWidget {
  const WebPipPlayerScaffold({
    super.key,
    required this.videoId,
    required this.startSeconds,
    required this.title,
    required this.below,
    required this.onProgress,
    required this.onEnded,
    required this.handle,
    required this.onSignIn,
    this.onNext,
    this.onPrevious,
  });

  /// The video currently playing. Changing this (e.g. a playlist advancing)
  /// loads the new video, resuming at [startSeconds].
  final String videoId;
  final double startSeconds;
  final String title;
  final Widget below;

  /// Reports playback position (and total duration once known) every second.
  final void Function(double position, int? duration) onProgress;

  /// Fired when the current video finishes.
  final VoidCallback onEnded;

  final WebPlayerHandle handle;

  /// Opens the sign-in flow. Called from the player's account icon and the
  /// "please sign in" banner shown when YouTube gates the video.
  final VoidCallback onSignIn;

  /// Optional playlist controls, surfaced as PiP next/previous buttons.
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  State<WebPipPlayerScaffold> createState() => _WebPipPlayerScaffoldState();
}

class _WebPipPlayerScaffoldState extends State<WebPipPlayerScaffold> {
  late final WebViewController _web;
  late final SimplePip _pip;
  bool _isPip = false;
  bool _loading = true;
  bool _signInNeeded = false;
  bool _autoPipAvailable = false;
  bool _fullscreen = false;
  bool? _lastPlaying;
  Timer? _pipKeepAlive;
  bool _pipShouldPlay = false;

  // Hides YouTube's chrome, locks scrolling to the player, autoplays, and
  // reports progress/end back over the FlutterPlayer channel.
  static const String _isolateAndTrack = '''
(function(){
  function injectCss(){
    if(document.getElementById('__fcss')) return;
    var css=document.createElement('style');
    css.id='__fcss';
    css.textContent=[
      // YouTube's top bar / search.
      'ytm-mobile-topbar-renderer,.mobile-topbar-header,header.mobile-topbar-header,ytm-masthead,#masthead{display:none!important;}',
      // In-player suggestions, end-screen cards and info cards that navigate away.
      '.ytp-pause-overlay,.ytp-pause-overlay-container,.ytp-endscreen-content,.html5-endscreen,.ytp-ce-element,.ytp-ce-covering-overlay,.ytp-cards-teaser,.ytp-cards-button,.ytp-suggestion-set,.ytp-related-on-error-overlay,.iv-branding,.annotation,.ytp-autonav-endscreen-upnext-container{display:none!important;}'
    ].join('');
    (document.head||document.documentElement).appendChild(css);
  }
  function snap(){ try{ window.scrollTo(0,0); }catch(_){} }
  // Make the page always look "visible" so YouTube's player doesn't auto-pause
  // when minimized to Picture-in-Picture (it pauses on the visibilitychange /
  // blur the system fires when backgrounding).
  function keepVisible(){
    if(window.__fvis) return; window.__fvis=true;
    try{
      Object.defineProperty(document,'hidden',{configurable:true,get:function(){return false;}});
      Object.defineProperty(document,'visibilityState',{configurable:true,get:function(){return 'visible';}});
      Object.defineProperty(document,'webkitHidden',{configurable:true,get:function(){return false;}});
      Object.defineProperty(document,'webkitVisibilityState',{configurable:true,get:function(){return 'visible';}});
    }catch(_){}
    ['visibilitychange','webkitvisibilitychange','pagehide','blur'].forEach(function(ev){
      try{ document.addEventListener(ev,function(e){ e.stopImmediatePropagation(); },true); }catch(_){}
      try{ window.addEventListener(ev,function(e){ e.stopImmediatePropagation(); },true); }catch(_){}
    });
  }
  // While keeping alive in PiP, make pause() a no-op so neither YouTube nor the
  // system can pause the video — it just keeps running like it's fullscreen.
  // (Cleared for the PiP pause button via window.__fkeep.)
  function blockPause(){
    if(window.__fpatch) return; window.__fpatch=true;
    try{
      var proto=HTMLMediaElement.prototype, orig=proto.pause;
      proto.pause=function(){ if(window.__fkeep) return; return orig.apply(this,arguments); };
    }catch(_){}
  }
  // Remember the video this page started on; if YouTube swaps it in place
  // (autoplay-next without a full navigation), force it back.
  var expected=(new URLSearchParams(location.search)).get('v');
  function pin(){
    try{
      var cur=(new URLSearchParams(location.search)).get('v');
      if(expected && cur && cur!==expected){
        location.replace('https://m.youtube.com/watch?v='+expected);
      }
    }catch(_){}
  }
  function unmute(){
    try{
      var v=document.querySelector('video');
      if(v){ v.muted=false; v.volume=1; }
      var b=document.querySelector('.ytp-unmute,button.ytp-unmute');
      if(b) b.click();
    }catch(_){}
  }
  function checkSignIn(){
    try{
      var t=(document.body&&document.body.innerText)||'';
      if(/not a bot|Sign in to confirm|confirmer que vous|vous .tes un robot/i.test(t)){
        if(window.FlutterPlayer) FlutterPlayer.postMessage(JSON.stringify({event:'signin'}));
      }
    }catch(_){}
  }
  function hook(){
    var v=document.querySelector('video');
    if(!v){ setTimeout(hook,400); return; }
    if(!v.__fh){
      v.__fh=true;
      v.addEventListener('ended', function(){
        if(window.FlutterPlayer) FlutterPlayer.postMessage(JSON.stringify({event:'ended'}));
      });
      var p=v.play(); if(p&&p.catch) p.catch(function(){});
      // Autoplay starts muted under the browser autoplay policy; unmute once
      // (a few retries since YouTube re-mutes briefly while it starts).
      [0,400,1000,2000,3500].forEach(function(d){ setTimeout(unmute,d); });
    }
  }
  if(typeof window.__fkeep==='undefined') window.__fkeep=false;
  keepVisible(); blockPause(); injectCss(); snap(); hook();
  window.addEventListener('scroll', snap, true);
  if(!window.__ft){
    window.__ft=setInterval(function(){
      injectCss(); pin(); checkSignIn();
      var v=document.querySelector('video');
      if(v&&window.FlutterPlayer){
        FlutterPlayer.postMessage(JSON.stringify({
          event:'progress', time:v.currentTime||0,
          duration:(isFinite(v.duration)?v.duration:null), paused:v.paused}));
      }
    },1000);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    widget.handle._state = this;
    _setupPip();

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    _web = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(youtubeMobileUserAgent)
      ..addJavaScriptChannel('FlutterPlayer', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Never let the page navigate to a video other than the one the
            // app asked for (blocks autoplay-next and any stray suggestion).
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isForeignVideo(uri)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _signInNeeded = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
            _web.runJavaScript(_isolateAndTrack);
            // Re-apply the keep-playing flag (a fresh page resets it).
            _setKeepPlaying(_isPip && _pipShouldPlay);
          },
        ),
      );

    // Allow autoplay without a tap, and keep third-party cookies so the
    // signed-in session carries into playback.
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      final cookies = WebViewCookieManager().platform;
      if (cookies is AndroidWebViewCookieManager) {
        cookies.setAcceptThirdPartyCookies(platform, true);
      }
    }

    _load();
  }

  String _watchUrl() {
    final start = widget.startSeconds.floor();
    final t = start > 1 ? '&t=${start}s' : '';
    return 'https://m.youtube.com/watch?v=${widget.videoId}$t';
  }

  /// True when [uri] is a YouTube video page for a *different* video than the
  /// one currently meant to be playing.
  bool _isForeignVideo(Uri uri) {
    final host = uri.host;
    final isYouTube = host.contains('youtube.com') || host.contains('youtu.be');
    if (!isYouTube) return false;
    String? v;
    if (host.contains('youtu.be')) {
      v = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (uri.path == '/watch') {
      v = uri.queryParameters['v'];
    } else {
      return false; // not a watch navigation (search, channel, consent, etc.)
    }
    return v != null && v != widget.videoId;
  }

  void _load() => _web.loadRequest(Uri.parse(_watchUrl()));

  @override
  void didUpdateWidget(WebPipPlayerScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The owning screen advanced to a different video — load it.
    if (oldWidget.videoId != widget.videoId) _load();
  }

  void _onJsMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (data['event'] == 'ended') {
      widget.onEnded();
    } else if (data['event'] == 'signin') {
      if (!_signInNeeded && mounted) setState(() => _signInNeeded = true);
    } else if (data['event'] == 'progress') {
      final time = (data['time'] as num?)?.toDouble() ?? 0;
      final duration = (data['duration'] as num?)?.round();
      widget.onProgress(time, duration);
      _syncPlaying(!(data['paused'] as bool? ?? true));
    }
  }

  void _runVideo(String body) {
    _web.runJavaScript("var v=document.querySelector('video'); if(v){ $body }");
  }

  void _syncPlaying(bool playing) {
    if (playing == _lastPlaying) return;
    _lastPlaying = playing;
    _pip.setIsPlaying(playing);
    // PiP should auto-trigger only while a video is actually playing — never
    // when paused or otherwise idle.
    _setAutoPip(playing);
  }

  // --- Picture-in-Picture (unchanged behaviour from the iframe scaffold) ---

  void _setupPip() {
    _pip = SimplePip(
      onPipEntered: () {
        setState(() => _isPip = true);
        _startPipKeepAlive();
      },
      onPipExited: () {
        setState(() => _isPip = false);
        _stopPipKeepAlive();
      },
      onPipAction: _onPipAction,
    );
    _pip.setPipActionsLayout(
      widget.onNext != null
          ? PipActionsLayout.media
          : PipActionsLayout.mediaOnlyPause,
    );
    _initAutoPip();
  }

  Future<void> _initAutoPip() async {
    try {
      _autoPipAvailable = await SimplePip.isAutoPipAvailable;
      // Start disarmed — auto-PiP is only armed while a video plays.
      if (_autoPipAvailable) await _pip.setAutoPipMode(autoEnter: false);
    } catch (_) {}
  }

  Future<void> _setAutoPip(bool enabled) async {
    if (!_autoPipAvailable) return;
    try {
      await _pip.setAutoPipMode(autoEnter: enabled);
    } catch (_) {}
  }

  Future<void> _enterPip() async {
    try {
      await _pip.enterPipMode();
    } catch (_) {}
  }

  /// Android pauses the WebView's <video> when the app backgrounds into PiP —
  /// once on entry and again periodically. Re-assert play every couple seconds
  /// while in PiP so it keeps running, but only when it's meant to be playing
  /// (so the PiP pause button still works).
  void _startPipKeepAlive() {
    _pipShouldPlay = true;
    _setKeepPlaying(true); // in-page pause listener resumes instantly
    widget.handle.play();
    // Light backup in case a pause event is ever missed (no-op while playing).
    _pipKeepAlive?.cancel();
    _pipKeepAlive = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isPip && _pipShouldPlay) widget.handle.play();
    });
  }

  void _stopPipKeepAlive() {
    _pipKeepAlive?.cancel();
    _pipKeepAlive = null;
    _setKeepPlaying(false);
  }

  /// Toggles the in-page flag that auto-resumes the video the instant it is
  /// paused (used to keep PiP playback continuous).
  void _setKeepPlaying(bool keep) {
    _web.runJavaScript('window.__fkeep=$keep;');
  }

  // --- Landscape fullscreen ------------------------------------------------

  Future<void> _toggleFullscreen() async {
    final entering = !_fullscreen;
    setState(() => _fullscreen = entering);
    if (entering) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Keep BOTH system bars visible (not immersive): the status bar shows
      // time/battery, and keeping the bottom bar lifts YouTube's seek bar up
      // off the screen edge so it's visible and reachable. Non-immersive also
      // means taps reach the player's controls instead of toggling the bars.
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } else {
      await _exitFullscreenSystemUi();
    }
  }

  Future<void> _exitFullscreenSystemUi() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _onPipAction(PipAction action) {
    switch (action) {
      case PipAction.play:
        _pipShouldPlay = true;
        _setKeepPlaying(true);
        widget.handle.play();
      case PipAction.pause:
        _pipShouldPlay = false;
        _setKeepPlaying(false); // let the PiP pause button actually pause
        widget.handle.pause();
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
    _stopPipKeepAlive();
    // Don't leave auto-PiP armed once the player is gone.
    _setAutoPip(false);
    // Never leave the device locked to landscape / immersive after leaving.
    if (_fullscreen) _exitFullscreenSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In PiP or fullscreen the surrounding app chrome (AppBar, below content)
    // is hidden and the player fills the available space.
    final chromeless = _isPip || _fullscreen;
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: chromeless
            ? null
            : AppBar(
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: 'Sign in to YouTube',
                    icon: const Icon(Icons.account_circle_outlined),
                    onPressed: widget.onSignIn,
                  ),
                  IconButton(
                    tooltip: 'Fullscreen (landscape)',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: _toggleFullscreen,
                  ),
                  IconButton(
                    tooltip: 'Play in a floating window',
                    icon: const Icon(Icons.picture_in_picture_alt),
                    onPressed: _enterPip,
                  ),
                ],
              ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Fill the screen in PiP/fullscreen; otherwise 16:9 capped to the
            // available height (avoids overflow in landscape / small windows).
            final playerHeight = chromeless
                ? constraints.maxHeight
                : (constraints.maxWidth * 9 / 16)
                    .clamp(0.0, constraints.maxHeight);
            return Column(
              children: [
                if (_signInNeeded && !chromeless)
                  Material(
                    color: const Color(0xFF4A3B00),
                    child: InkWell(
                      onTap: widget.onSignIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline,
                                color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'YouTube needs you to sign in. Tap the account '
                                'icon at the top right to sign in, then it will '
                                'play.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.account_circle, color: Colors.amber),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: constraints.maxWidth,
                  height: playerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      WebViewWidget(controller: _web),
                      if (_loading && !_isPip)
                        const ColoredBox(
                          color: Colors.black,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_fullscreen)
                        // Small, top-left, semi-transparent so it stays clear
                        // of YouTube's own controls (seek bar, cast, menu).
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Material(
                            color: Colors.black38,
                            shape: const CircleBorder(),
                            child: IconButton(
                              iconSize: 18,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(4),
                              tooltip: 'Exit fullscreen',
                              icon: const Icon(Icons.fullscreen_exit,
                                  color: Colors.white70),
                              onPressed: _toggleFullscreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!chromeless) Expanded(child: widget.below),
              ],
            );
          },
        ),
      ),
    );
  }
}
