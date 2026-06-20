import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../state/library_controller.dart';

/// Writes automatic JSON snapshots of the library to a folder on the device, so
/// data survives even if the user never exports manually. Keeps a rolling set
/// of timestamped files plus a `latest.json` pointer.
class AutoBackupService {
  static const _dirName = 'backups';
  static const _maxFiles = 15;

  /// App-specific external files dir on Android (no permission needed, visible
  /// under the app's Android/data files folder); falls back to the documents
  /// dir elsewhere.
  static Future<Directory> _dir() async {
    Directory base;
    try {
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> directoryPath() async => (await _dir()).path;

  /// Writes a new timestamped backup and refreshes `latest.json`.
  static Future<File> backup(
    LibraryController controller, {
    required int timestampMs,
  }) async {
    final dir = await _dir();
    final json = controller.exportJson();
    final file = File('${dir.path}/backup_$timestampMs.json');
    await file.writeAsString(json);
    await File('${dir.path}/latest.json').writeAsString(json);
    await _rotate(dir);
    return file;
  }

  static Future<void> _rotate(Directory dir) async {
    final backups = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('backup_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first (by timestamp)
    for (final f in backups.skip(_maxFiles)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static Future<File?> latest() async {
    final file = File('${(await _dir()).path}/latest.json');
    return await file.exists() ? file : null;
  }

  static Future<DateTime?> latestTime() async {
    final file = await latest();
    if (file == null) return null;
    return file.lastModified();
  }
}
