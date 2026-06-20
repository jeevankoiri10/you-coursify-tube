import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media.dart';

/// Scrapes the full list of videos in a YouTube playlist.
///
/// youtube_explode_dart's playlist parser is broken against the current
/// YouTube page format, so we do it ourselves: read the playlist page, pull
/// every video out of the new `lockupViewModel` blocks, then follow the
/// InnerTube continuation token to page through playlists with >100 videos.
class PlaylistScraper {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0 Safari/537.36';
  static const _fallbackApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const _fallbackClientVersion = '2.20240410.01.00';

  /// Safety cap so a pathological playlist can't loop forever.
  static const _maxVideos = 1000;

  static Future<PlaylistScrapeResult> fetch(String playlistId) async {
    final html = await _getHtml(playlistId);

    final videos = <VideoItem>[];
    final seen = <String>{};
    _collectFromHtml(html, videos, seen);

    final title = _scrapeBetween(html, '<meta property="og:title" content="', '"')
            ?.let(_unescapeHtml) ??
        'Playlist';

    final apiKey = _scrapeAfter(html, '"INNERTUBE_API_KEY":"') ?? _fallbackApiKey;
    final clientVersion =
        _scrapeAfter(html, '"INNERTUBE_CONTEXT_CLIENT_VERSION":"') ??
            _scrapeAfter(html, '"clientVersion":"') ??
            _fallbackClientVersion;

    var token = _htmlBrowseToken(html);
    var guard = 0;
    while (token != null && videos.length < _maxVideos && guard < 60) {
      guard++;
      final resp = await _browse(apiKey, clientVersion, token);
      if (resp == null) break;
      final before = videos.length;
      _collectLockups(resp, videos, seen);
      token = _findContinuationToken(resp);
      if (videos.length == before) break; // no progress; stop
    }

    if (videos.isEmpty) {
      throw Exception('No playable videos found in this playlist.');
    }
    return PlaylistScrapeResult(title: title, videos: videos);
  }

  static Future<String> _getHtml(String playlistId) async {
    final url = Uri.parse(
        'https://www.youtube.com/playlist?list=$playlistId&hl=en&gl=US');
    final res = await http.get(url, headers: {
      'User-Agent': _ua,
      'Accept-Language': 'en-US,en;q=0.9',
      'Cookie': 'CONSENT=YES+cb',
    });
    if (res.statusCode != 200) {
      throw Exception('YouTube returned HTTP ${res.statusCode}.');
    }
    return res.body;
  }

  static Future<Map<String, dynamic>?> _browse(
      String apiKey, String clientVersion, String token) async {
    final url = Uri.parse(
        'https://www.youtube.com/youtubei/v1/browse?key=$apiKey&prettyPrint=false');
    final res = await http.post(
      url,
      headers: {
        'User-Agent': _ua,
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': clientVersion,
            'hl': 'en',
            'gl': 'US',
          },
        },
        'continuation': token,
      }),
    );
    if (res.statusCode != 200) return null;
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---- Parsing the initial HTML ------------------------------------------

  /// Each video on the first page is a `"lockupViewModel": { ... }` object. We
  /// can't trust a single `ytInitialData` blob, so we brace-extract each marker.
  static void _collectFromHtml(
      String html, List<VideoItem> out, Set<String> seen) {
    const marker = '"lockupViewModel"';
    var from = 0;
    while (true) {
      final idx = html.indexOf(marker, from);
      if (idx < 0) break;
      from = idx + marker.length;
      final raw = _objectAfter(html, from);
      if (raw == null || !raw.contains('"contentId"')) continue;
      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        final v = _parseLockup(obj);
        if (v != null && seen.add(v.videoId)) out.add(v);
      } catch (_) {
        // skip malformed
      }
    }
  }

  // ---- Parsing continuation JSON -----------------------------------------

  /// Recursively finds every map that wraps a `lockupViewModel`.
  static void _collectLockups(
      dynamic node, List<VideoItem> out, Set<String> seen) {
    if (node is Map) {
      final lv = node['lockupViewModel'];
      if (lv is Map) {
        final v = _parseLockup(Map<String, dynamic>.from(lv));
        if (v != null && seen.add(v.videoId)) out.add(v);
      }
      for (final value in node.values) {
        _collectLockups(value, out, seen);
      }
    } else if (node is List) {
      for (final value in node) {
        _collectLockups(value, out, seen);
      }
    }
  }

  static VideoItem? _parseLockup(Map lockup) {
    final id = lockup['contentId'];
    if (id is! String || id.length < 6) return null;

    final ct = lockup['contentType'];
    if (ct is String && !ct.contains('VIDEO')) return null;

    String title = 'Video';
    final meta = _findFirst(lockup, 'lockupMetadataViewModel');
    if (meta is Map && meta['title'] is Map) {
      final content = meta['title']['content'];
      if (content is String && content.isNotEmpty) title = content;
    }

    int? duration;
    final badge = _findFirst(lockup, 'thumbnailBadgeViewModel');
    if (badge is Map && badge['text'] is String) {
      duration = _parseClock(badge['text'] as String);
    }

    return VideoItem(
      videoId: id,
      title: title,
      thumbnailUrl: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
      durationSeconds: duration,
    );
  }

  // ---- Continuation tokens -----------------------------------------------

  /// The grid's "load more" token from the initial HTML. The grid continuation
  /// is the `continuationCommand` whose first key is `token` (other
  /// continuationCommands on the page wrap an `innertubeCommand` instead).
  static String? _htmlBrowseToken(String html) {
    final m = RegExp(r'"continuationCommand":\{"token":"([^"]+)"')
        .firstMatch(html);
    return m?.group(1);
  }

  static String? _findContinuationToken(dynamic node) {
    if (node is Map) {
      final cc = node['continuationCommand'];
      if (cc is Map && cc['token'] is String) {
        final req = cc['request'];
        if (req == null || req == 'CONTINUATION_REQUEST_TYPE_BROWSE') {
          return cc['token'] as String;
        }
      }
      for (final value in node.values) {
        final found = _findContinuationToken(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findContinuationToken(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  // ---- Helpers -----------------------------------------------------------

  static dynamic _findFirst(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node[key];
      for (final value in node.values) {
        final found = _findFirst(value, key);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findFirst(value, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Parses "1:32" or "1:02:03" into seconds.
  static int? _parseClock(String text) {
    if (!RegExp(r'^\d+(:\d{2})+$').hasMatch(text)) return null;
    final parts = text.split(':').map(int.parse).toList();
    var seconds = 0;
    for (final p in parts) {
      seconds = seconds * 60 + p;
    }
    return seconds;
  }

  /// Brace-balanced extraction of the first `{...}` at or after [from].
  static String? _objectAfter(String html, int from) {
    var i = from;
    while (i < html.length && html[i] != '{') {
      i++;
    }
    if (i >= html.length) return null;
    var depth = 0;
    var inString = false;
    var escape = false;
    final start = i;
    for (; i < html.length; i++) {
      final c = html[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  static String? _scrapeAfter(String html, String marker) {
    final start = html.indexOf(marker);
    if (start < 0) return null;
    final from = start + marker.length;
    final end = html.indexOf('"', from);
    if (end < 0) return null;
    return html.substring(from, end);
  }

  static String? _scrapeBetween(String html, String open, String close) {
    final start = html.indexOf(open);
    if (start < 0) return null;
    final from = start + open.length;
    final end = html.indexOf(close, from);
    if (end < 0) return null;
    return html.substring(from, end);
  }

  static String _unescapeHtml(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class PlaylistScrapeResult {
  PlaylistScrapeResult({required this.title, required this.videos});
  final String title;
  final List<VideoItem> videos;
}
