import 'package:flutter/material.dart';

import '../models/library.dart';
import '../state/library_controller.dart';
import '../utils/format.dart';

/// A row representing one saved link (video or playlist) for History and folder
/// listings.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.controller,
    required this.onTap,
    this.onDelete,
    this.showAddedDate = false,
  });

  final LibraryItem item;
  final LibraryController controller;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  /// When true, shows the added date under the item (used in folders).
  final bool showAddedDate;

  /// Status line: for a video this is "In progress · 12:34" (centralized
  /// status + total duration); for a playlist it is the playlist summary.
  String get _statusLine {
    if (item.type == ItemType.video && item.video != null) {
      return controller.videoStatus(item.video!);
    }
    return item.subtitle;
  }

  Widget _fallbackThumb() => Container(
        color: Colors.white12,
        child: Icon(
          item.isPlaylist ? Icons.playlist_play : Icons.videocam,
          color: Colors.white38,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: SizedBox(
        width: 84,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.thumbnailUrl != null)
                Image.network(
                  item.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _fallbackThumb(),
                )
              else
                _fallbackThumb(),
              // Type indicator: playlist badge on the right, video icon badge
              // on the bottom-left.
              if (item.isPlaylist)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    color: Colors.black54,
                    child: const Icon(Icons.playlist_play,
                        size: 18, color: Colors.white),
                  ),
                )
              else
                Positioned(
                  left: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 13, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (showAddedDate)
            Text(
              'Added ${shortDate(item.addedAtMs)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
      trailing: onDelete == null
          ? const Icon(Icons.play_arrow)
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onDelete,
              tooltip: 'Remove',
            ),
      onTap: onTap,
    );
  }
}
