import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/library_controller.dart';

/// Exports the whole library to a JSON file and imports it back.
class BackupService {
  /// Writes the library to a temp .json file and opens the system share sheet
  /// so the user can save it (Files, Drive, email, …).
  static Future<void> export(LibraryController controller) async {
    final json = controller.exportJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/you_coursify_tube_backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'You Coursify Tube backup',
      text: 'You Coursify Tube data backup',
    );
  }

  /// Lets the user pick a previously exported .json file and replaces all
  /// current data with it. Returns false if the user cancelled the picker.
  static Future<bool> pickAndImport(LibraryController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;

    final picked = result.files.single;
    final bytes = picked.bytes;
    final content = bytes != null
        ? utf8.decode(bytes)
        : await File(picked.path!).readAsString();

    await controller.importJson(content);
    return true;
  }
}
