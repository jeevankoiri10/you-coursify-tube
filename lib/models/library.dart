import 'media.dart';

enum ItemType { video, playlist }

/// A single saved entry inside a folder: either a video or a playlist, plus the
/// bookkeeping needed for History and "continue watching".
class LibraryItem {
  LibraryItem({
    required this.id,
    required this.type,
    required this.folderId,
    this.video,
    this.playlist,
    this.addedAtMs = 0,
    this.lastOpenedAtMs = 0,
  });

  final String id;
  final ItemType type;
  String folderId;
  final VideoItem? video;
  final PlaylistData? playlist;
  final int addedAtMs;

  /// 0 means "never opened". Used to build the History list (most recent first).
  int lastOpenedAtMs;

  String get title =>
      type == ItemType.video ? (video?.title ?? 'Video') : (playlist?.title ?? 'Playlist');

  String? get thumbnailUrl {
    if (type == ItemType.video) return video?.thumbnailUrl;
    final vids = playlist?.videos ?? const [];
    return vids.isEmpty ? null : vids.first.thumbnailUrl;
  }

  bool get isPlaylist => type == ItemType.playlist;

  /// Short progress description for tiles.
  String get subtitle {
    if (type == ItemType.playlist) {
      final p = playlist!;
      return '${p.videos.length} videos · on ${p.currentIndex + 1}';
    }
    final v = video!;
    if (v.completed) return 'Watched';
    if (v.positionSeconds > 1) return 'In progress';
    return 'Not started';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'folderId': folderId,
        'video': video?.toJson(),
        'playlist': playlist?.toJson(),
        'addedAtMs': addedAtMs,
        'lastOpenedAtMs': lastOpenedAtMs,
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        id: json['id'] as String,
        type: ItemType.values
            .firstWhere((t) => t.name == json['type'], orElse: () => ItemType.video),
        folderId: (json['folderId'] as String?) ?? 'default',
        video: json['video'] == null
            ? null
            : VideoItem.fromJson(Map<String, dynamic>.from(json['video'] as Map)),
        playlist: json['playlist'] == null
            ? null
            : PlaylistData.fromJson(
                Map<String, dynamic>.from(json['playlist'] as Map)),
        addedAtMs: (json['addedAtMs'] as num?)?.toInt() ?? 0,
        lastOpenedAtMs: (json['lastOpenedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// A free-text study note. Any YouTube links in [body] are made tappable in the
/// UI and open inside the app.
class Note {
  Note({
    required this.id,
    this.folderId = 'default',
    this.title = '',
    this.body = '',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  String folderId;
  String title;
  String body;
  final int createdAtMs;
  int updatedAtMs;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first.trim();
    return firstLine.isEmpty ? 'Untitled note' : firstLine;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'folderId': folderId,
        'title': title,
        'body': body,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        folderId: (json['folderId'] as String?) ?? 'default',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// A named directory that groups saved links.
class Folder {
  Folder({required this.id, required this.name, this.createdAtMs = 0});

  final String id;
  String name;
  final int createdAtMs;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'createdAtMs': createdAtMs};

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Folder',
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// The whole persisted library: folders, the items they contain, and which item
/// is currently active (for Home's "continue watching").
class Library {
  Library({
    required this.folders,
    required this.items,
    required this.notes,
    required this.progress,
    this.currentItemId,
  });

  final List<Folder> folders;
  final List<LibraryItem> items;
  final List<Note> notes;

  /// Centralized resume position per video id, shared app-wide.
  final Map<String, VideoProgress> progress;
  String? currentItemId;

  Map<String, dynamic> toJson() => {
        'folders': folders.map((f) => f.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
        'currentItemId': currentItemId,
      };

  factory Library.fromJson(Map<String, dynamic> json) => Library(
        folders: ((json['folders'] as List?) ?? const [])
            .map((e) => Folder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: ((json['notes'] as List?) ?? const [])
            .map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        progress: ((json['progress'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(
            k as String,
            VideoProgress.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
        currentItemId: json['currentItemId'] as String?,
      );

  factory Library.empty() =>
      Library(folders: [], items: [], notes: [], progress: {});
}
