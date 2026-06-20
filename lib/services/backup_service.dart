import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/library_controller.dart';
import '../utils/format.dart';

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

  /// Exports a flat, spreadsheet-friendly CSV of every link and note, then opens
  /// the share sheet. CSV is read-only (use JSON to fully restore).
  static Future<void> exportCsv(LibraryController controller) async {
    final csv = buildCsv(controller);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/you_coursify_tube_export.csv');
    // Prepend a BOM so Excel opens UTF-8 correctly.
    await file.writeAsString('﻿$csv');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'You Coursify Tube export (CSV)',
      text: 'You Coursify Tube data (CSV)',
    );
  }

  static String buildCsv(LibraryController controller) {
    final rows = <List<String>>[
      [
        'type',
        'folder',
        'title',
        'id',
        'url',
        'addedDate',
        'positionSeconds',
        'durationSeconds',
        'completed',
        'details',
      ],
    ];

    for (final folder in controller.folders) {
      for (final item in controller.itemsInFolder(folder.id)) {
        if (item.isPlaylist) {
          final p = item.playlist!;
          rows.add([
            'playlist',
            folder.name,
            p.title,
            p.playlistId,
            'https://www.youtube.com/playlist?list=${p.playlistId}',
            shortDate(item.addedAtMs),
            '',
            '',
            '',
            '${p.videos.length} videos; current ${p.currentIndex + 1}',
          ]);
        } else {
          final v = item.video!;
          final prog = controller.progressFor(v.videoId);
          rows.add([
            'video',
            folder.name,
            v.title,
            v.videoId,
            'https://www.youtube.com/watch?v=${v.videoId}',
            shortDate(item.addedAtMs),
            prog.positionSeconds.toStringAsFixed(0),
            '${v.durationSeconds ?? prog.durationSeconds ?? ''}',
            '${prog.completed}',
            '',
          ]);
        }
      }
      for (final note in controller.notesInFolder(folder.id)) {
        rows.add([
          'note',
          folder.name,
          note.displayTitle,
          note.id,
          '',
          shortDate(note.createdAtMs),
          '',
          '',
          '',
          note.body,
        ]);
      }
    }

    return rows.map(_csvRow).join('\r\n');
  }

  static String _csvRow(List<String> fields) => fields.map(_csvField).join(',');

  static String _csvField(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
