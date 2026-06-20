import 'package:flutter/material.dart';

import 'models/library.dart';
import 'screens/playlist_screen.dart';
import 'screens/single_player_screen.dart';
import 'services/youtube_service.dart';
import 'state/library_controller.dart';

/// Opens a saved item in the right player, stamping it for History and as the
/// current "continue watching" item. Refreshes the list on return.
Future<void> openItem(
  BuildContext context,
  LibraryController controller,
  LibraryItem item,
) async {
  await controller.markOpened(item);
  if (!context.mounted) return;
  final route = MaterialPageRoute(
    builder: (_) => item.isPlaylist
        ? PlaylistScreen(item: item, controller: controller)
        : SinglePlayerScreen(item: item, controller: controller),
  );
  await Navigator.of(context).push(route);
  controller.touch();
}

/// Opens a raw YouTube URL (e.g. tapped inside a note) in the in-app player,
/// without saving it to the library. Single videos play directly; playlists are
/// scraped and shown as a list. Playback stays inside the app.
Future<void> openYoutubeUrl(
  BuildContext context,
  LibraryController controller,
  String url,
) async {
  var normalized = url.trim();
  if (!normalized.startsWith('http')) normalized = 'https://$normalized';

  final parsed = YoutubeService.parse(normalized);
  if (parsed.kind == LinkKind.invalid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not a recognizable YouTube link.')),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final transientId =
      'note_${DateTime.now().microsecondsSinceEpoch}';
  try {
    final LibraryItem item;
    if (parsed.kind == LinkKind.playlist) {
      final playlist = await YoutubeService.fetchPlaylist(parsed.id);
      item = LibraryItem(
        id: transientId,
        type: ItemType.playlist,
        folderId: '',
        playlist: playlist,
      );
    } else {
      final video = await YoutubeService.buildSingle(parsed.id);
      item = LibraryItem(
        id: transientId,
        type: ItemType.video,
        folderId: '',
        video: video,
      );
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the loading spinner

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.isPlaylist
            ? PlaylistScreen(item: item, controller: controller)
            : SinglePlayerScreen(item: item, controller: controller),
      ),
    );
    controller.touch(); // refresh any tiles showing this URL's progress
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the loading spinner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open that link. $e')),
    );
  }
}
