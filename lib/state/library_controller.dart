import 'package:flutter/foundation.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../services/storage.dart';
import '../utils/format.dart';

/// Single source of truth for the app. Holds the [Library] in memory, exposes
/// derived views (history, folder contents, current item) and persists every
/// change so a restart resumes exactly where the user left off.
class LibraryController extends ChangeNotifier {
  LibraryController(this._library) {
    _ensureDefaultFolder();
    _migrateProgress();
  }

  final Library _library;
  Library get library => _library;

  static const defaultFolderId = 'default';

  void _ensureDefaultFolder() {
    if (_library.folders.isEmpty) {
      _library.folders.add(
        Folder(
          id: defaultFolderId,
          name: 'General',
          createdAtMs: _now(),
        ),
      );
    }
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;
  String _id(String prefix) => '${prefix}_${_now()}_${_library.items.length}';

  /// Seed the centralized progress map from any per-item positions saved by
  /// older versions, so existing resume points aren't lost.
  void _migrateProgress() {
    void seed(VideoItem v) {
      if (_library.progress.containsKey(v.videoId)) return;
      if (v.positionSeconds > 0 || v.completed) {
        _library.progress[v.videoId] = VideoProgress(
          positionSeconds: v.positionSeconds,
          durationSeconds: v.durationSeconds,
          completed: v.completed,
          updatedAtMs: _now(),
        );
      }
    }

    for (final item in _library.items) {
      if (item.video != null) seed(item.video!);
      for (final v in item.playlist?.videos ?? const <VideoItem>[]) {
        seed(v);
      }
    }
  }

  // ---- Centralized progress (keyed by video id, shared app-wide) ---------

  VideoProgress progressFor(String videoId) =>
      _library.progress[videoId] ?? VideoProgress();

  /// Resume position for a video id, in seconds.
  double startFor(String videoId) => progressFor(videoId).positionSeconds;

  /// Persist playback progress for a video id. Shared by every screen, so the
  /// same URL resumes identically wherever it appears. Does not notify (called
  /// repeatedly during playback); callers refresh the UI via [touch] on return.
  Future<void> saveProgress(
    String videoId, {
    required double position,
    int? duration,
    bool? completed,
  }) async {
    final p = _library.progress.putIfAbsent(videoId, VideoProgress.new);
    p.positionSeconds = position;
    if (duration != null && duration > 0) p.durationSeconds = duration;
    if (completed != null) p.completed = completed;
    p.updatedAtMs = _now();
    await persist();
  }

  /// Status line for a video tile, e.g. "In progress · 12:34".
  String videoStatus(VideoItem v) {
    final p = progressFor(v.videoId);
    final base = p.completed
        ? 'Watched'
        : (p.positionSeconds > 1 ? 'In progress' : 'Not started');
    final dur = v.durationSeconds ?? p.durationSeconds;
    return dur != null ? '$base · ${formatDuration(dur)}' : base;
  }

  /// Watched fraction (0..1) for a progress bar.
  double videoFraction(VideoItem v) {
    final p = progressFor(v.videoId);
    final dur = v.durationSeconds ?? p.durationSeconds;
    if (dur == null || dur <= 0) return 0;
    return (p.positionSeconds / dur).clamp(0.0, 1.0);
  }

  // ---- Reads -------------------------------------------------------------

  List<Folder> get folders => _library.folders;

  List<LibraryItem> itemsInFolder(String folderId) =>
      _library.items.where((i) => i.folderId == folderId).toList()
        ..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));

  int itemCountInFolder(String folderId) =>
      _library.items.where((i) => i.folderId == folderId).length;

  /// Most-recently-opened items, newest first. This is the History.
  List<LibraryItem> get history {
    final opened = _library.items.where((i) => i.lastOpenedAtMs > 0).toList()
      ..sort((a, b) => b.lastOpenedAtMs.compareTo(a.lastOpenedAtMs));
    return opened;
  }

  LibraryItem? get current {
    final id = _library.currentItemId;
    if (id == null) return null;
    try {
      return _library.items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Folder folderById(String id) =>
      _library.folders.firstWhere((f) => f.id == id,
          orElse: () => Folder(id: id, name: 'Folder'));

  // ---- Writes ------------------------------------------------------------

  Future<Folder> createFolder(String name) async {
    final folder = Folder(id: _id('folder'), name: name.trim(), createdAtMs: _now());
    _library.folders.add(folder);
    await persist();
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String folderId, String name) async {
    folderById(folderId).name = name.trim();
    await persist();
    notifyListeners();
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderId == defaultFolderId) return; // keep a home for orphans
    _library.items
        .where((i) => i.folderId == folderId)
        .toList()
        .forEach((i) => i.folderId = defaultFolderId);
    _library.notes
        .where((n) => n.folderId == folderId)
        .toList()
        .forEach((n) => n.folderId = defaultFolderId);
    _library.folders.removeWhere((f) => f.id == folderId);
    await persist();
    notifyListeners();
  }

  /// Add a freshly built item (video or playlist) to a folder.
  Future<LibraryItem> addItem({
    required ItemType type,
    required String folderId,
    dynamic video,
    dynamic playlist,
  }) async {
    final item = LibraryItem(
      id: _id('item'),
      type: type,
      folderId: folderId,
      video: video,
      playlist: playlist,
      addedAtMs: _now(),
    );
    _library.items.add(item);
    await persist();
    notifyListeners();
    return item;
  }

  Future<void> deleteItem(String itemId) async {
    _library.items.removeWhere((i) => i.id == itemId);
    if (_library.currentItemId == itemId) _library.currentItemId = null;
    await persist();
    notifyListeners();
  }

  /// Mark an item as the active one and stamp it for History ordering.
  Future<void> markOpened(LibraryItem item) async {
    item.lastOpenedAtMs = _now();
    _library.currentItemId = item.id;
    await persist();
    notifyListeners();
  }

  // ---- Notes -------------------------------------------------------------

  /// Notes inside a folder, most recently updated first.
  List<Note> notesInFolder(String folderId) =>
      _library.notes.where((n) => n.folderId == folderId).toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

  int noteCountInFolder(String folderId) =>
      _library.notes.where((n) => n.folderId == folderId).length;

  /// Builds a fresh note for a folder. It is only added to the library once
  /// [saveNote] is called, so abandoning a blank note leaves nothing behind.
  Note createNote(String folderId) => Note(
        id: _id('note'),
        folderId: folderId,
        createdAtMs: _now(),
        updatedAtMs: _now(),
      );

  Future<void> saveNote(Note note) async {
    note.updatedAtMs = _now();
    if (!_library.notes.any((n) => n.id == note.id)) {
      _library.notes.add(note);
    }
    await persist();
    notifyListeners();
  }

  /// Removes a note. Also drops empty notes (used when leaving a blank one).
  Future<void> deleteNote(String noteId) async {
    _library.notes.removeWhere((n) => n.id == noteId);
    await persist();
    notifyListeners();
  }

  /// Called by the players to flush playback progress to disk. Does not notify
  /// listeners (no UI rebuild needed mid-playback).
  Future<void> persist() => Storage.save(_library);

  /// Rebuild the UI after a player mutated an item's progress in place.
  void touch() => notifyListeners();
}
