import 'package:flutter/foundation.dart';

import '../models/library.dart';
import '../services/storage.dart';

/// Single source of truth for the app. Holds the [Library] in memory, exposes
/// derived views (history, folder contents, current item) and persists every
/// change so a restart resumes exactly where the user left off.
class LibraryController extends ChangeNotifier {
  LibraryController(this._library) {
    _ensureDefaultFolder();
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

  /// Called by the players to flush playback progress to disk. Does not notify
  /// listeners (no UI rebuild needed mid-playback).
  Future<void> persist() => Storage.save(_library);

  /// Rebuild the UI after a player mutated an item's progress in place.
  void touch() => notifyListeners();
}
