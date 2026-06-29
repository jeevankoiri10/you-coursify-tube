import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// A full-screen WebView for signing in to a YouTube / Google account.
///
/// The platform WebView keeps a single, app-wide cookie store (Android's
/// [CookieManager], iOS's default `WKWebsiteDataStore`). The embedded player
/// used elsewhere in the app lives in that same store, so once the user signs
/// in here the player is authenticated too — which is what lets gated videos
/// ("Sign in to confirm you're not a bot", age-restricted, members-only) play.
class YoutubeSignInScreen extends StatefulWidget {
  const YoutubeSignInScreen({super.key});

  @override
  State<YoutubeSignInScreen> createState() => _YoutubeSignInScreenState();
}

class _YoutubeSignInScreenState extends State<YoutubeSignInScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  /// The YouTube browsing site (the post-login landing) — but not the
  /// `accounts.*` hosts, which are still part of the sign-in flow.
  bool _isYoutubeSite(Uri uri) {
    final host = uri.host;
    if (host.startsWith('accounts.')) return false;
    return host == 'm.youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'youtube.com';
  }

  void _finish() {
    if (_closed || !mounted) return;
    _closed = true;
    // Pop outside the navigation callback to avoid re-entrancy.
    Future.microtask(() {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  // Google rejects sign-in from WebViews it can't recognize ("This browser or
  // app may not be secure"). Presenting a normal mobile Chrome user agent
  // sidesteps that disallowed-user-agent block.
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // Reaching the YouTube site means the Google login finished and
            // redirected to the `continue` target. Close here instead of
            // letting the user land on YouTube and browse.
            if (uri != null && _isYoutubeSite(uri)) {
              _finish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    // Keep third-party cookies so the Google account session is written into
    // the shared cookie jar the player reads from.
    final cookieManager = WebViewCookieManager();
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController &&
        cookieManager.platform is AndroidWebViewCookieManager) {
      (cookieManager.platform as AndroidWebViewCookieManager)
          .setAcceptThirdPartyCookies(platformController, true);
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(
      Uri.parse(
        'https://accounts.google.com/ServiceLogin'
        '?continue=https://m.youtube.com/',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to YouTube'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
