/// The playable units: a single video or a playlist. Each remembers the exact
/// position the user left off at so playback can resume automatically.
library;

class VideoItem {
  VideoItem({
    required this.videoId,
    required this.title,
    this.thumbnailUrl,
    this.durationSeconds,
    this.positionSeconds = 0,
    this.completed = false,
  });

  final String videoId;
  String title;
  final String? thumbnailUrl;
  final int? durationSeconds;

  /// Where the user left off, in seconds — what makes "resume" work.
  double positionSeconds;
  bool completed;

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'positionSeconds': positionSeconds,
        'completed': completed,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        videoId: json['videoId'] as String,
        title: (json['title'] as String?) ?? 'Video',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
        completed: (json['completed'] as bool?) ?? false,
      );
}

/// Centralized playback progress for a single video id. Stored once per id in
/// the library so every place that video appears (a saved link, a playlist
/// entry, or a link inside a note) shares the same resume position.
class VideoProgress {
  VideoProgress({
    this.positionSeconds = 0,
    this.durationSeconds,
    this.completed = false,
    this.updatedAtMs = 0,
  });

  double positionSeconds;
  int? durationSeconds;
  bool completed;
  int updatedAtMs;

  Map<String, dynamic> toJson() => {
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'completed': completed,
        'updatedAtMs': updatedAtMs,
      };

  factory VideoProgress.fromJson(Map<String, dynamic> json) => VideoProgress(
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        completed: (json['completed'] as bool?) ?? false,
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// A saved playlist: every video plus which one we are currently on.
class PlaylistData {
  PlaylistData({
    required this.playlistId,
    required this.title,
    required this.videos,
    this.currentIndex = 0,
  });

  final String playlistId;
  final String title;
  final List<VideoItem> videos;
  int currentIndex;

  VideoItem get current => videos[currentIndex.clamp(0, videos.length - 1)];

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'title': title,
        'currentIndex': currentIndex,
        'videos': videos.map((v) => v.toJson()).toList(),
      };

  factory PlaylistData.fromJson(Map<String, dynamic> json) => PlaylistData(
        playlistId: json['playlistId'] as String,
        title: (json['title'] as String?) ?? 'Playlist',
        currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
        videos: ((json['videos'] as List?) ?? const [])
            .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
