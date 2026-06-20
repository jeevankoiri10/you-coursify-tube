/// Data models that describe what the Floater app should show on launch.
///
/// The whole point of the app is that you never re-type a link: whatever you
/// last pasted (a single video or a whole playlist) is persisted, together with
/// the exact position you stopped at, so the next launch resumes instantly.
library;

enum LibraryMode { empty, single, playlist }

/// A single watchable video plus the playback progress we remember for it.
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

  /// Where the user left off, in seconds. This is what makes "resume" work.
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

  /// Index into [videos] of the "where I left off" entry.
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

/// The complete persisted state of the app.
class AppState {
  AppState({this.mode = LibraryMode.empty, this.single, this.playlist});

  LibraryMode mode;
  VideoItem? single;
  PlaylistData? playlist;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'single': single?.toJson(),
        'playlist': playlist?.toJson(),
      };

  factory AppState.fromJson(Map<String, dynamic> json) {
    final mode = LibraryMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => LibraryMode.empty,
    );
    return AppState(
      mode: mode,
      single: json['single'] == null
          ? null
          : VideoItem.fromJson(Map<String, dynamic>.from(json['single'] as Map)),
      playlist: json['playlist'] == null
          ? null
          : PlaylistData.fromJson(
              Map<String, dynamic>.from(json['playlist'] as Map)),
    );
  }
}
