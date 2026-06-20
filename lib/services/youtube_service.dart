import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media.dart';
import 'playlist_scraper.dart';

enum LinkKind { video, playlist, invalid }

class ParsedLink {
  ParsedLink(this.kind, this.id);
  final LinkKind kind;
  final String id;
}

/// Understands the messy variety of YouTube URLs the user might paste and
/// fetches metadata for playlists.
class YoutubeService {
  /// Decide whether a pasted string points at a playlist or a single video.
  ///
  /// A link that carries a `list=` parameter is treated as a playlist (that is
  /// what the user asked for: "if I paste the link of a playlist ... all the
  /// videos should be shown as a list"). Otherwise we look for a video id.
  static ParsedLink parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return ParsedLink(LinkKind.invalid, '');

    final playlistId = PlaylistId.parsePlaylistId(text);
    if (playlistId != null) {
      return ParsedLink(LinkKind.playlist, playlistId);
    }

    final videoId = VideoId.parseVideoId(text);
    if (videoId != null) {
      return ParsedLink(LinkKind.video, videoId);
    }

    return ParsedLink(LinkKind.invalid, '');
  }

  /// Best-effort title for a single video. Falls back to a generic title if the
  /// network is unavailable — the player itself will fill in the real title
  /// from its metadata stream once it loads.
  static Future<VideoItem> buildSingle(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final v = await yt.videos.get(videoId);
      return VideoItem(
        videoId: videoId,
        title: v.title,
        thumbnailUrl: v.thumbnails.mediumResUrl,
        durationSeconds: v.duration?.inSeconds,
      );
    } catch (_) {
      return VideoItem(videoId: videoId, title: 'Video');
    } finally {
      yt.close();
    }
  }

  /// Fetch the full list of videos for a playlist.
  ///
  /// Uses our own [PlaylistScraper] because youtube_explode_dart's playlist
  /// video parser is broken against the current YouTube page format.
  static Future<PlaylistData> fetchPlaylist(String playlistId) async {
    final result = await PlaylistScraper.fetch(playlistId);
    return PlaylistData(
      playlistId: playlistId,
      title: result.title.isEmpty ? 'Playlist' : result.title,
      videos: result.videos,
    );
  }
}
