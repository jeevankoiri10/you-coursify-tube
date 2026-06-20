import 'package:flutter/material.dart';

import 'models/library.dart';
import 'screens/playlist_screen.dart';
import 'screens/single_player_screen.dart';
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
