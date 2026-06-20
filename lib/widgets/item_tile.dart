import 'package:flutter/material.dart';

import '../models/library.dart';

/// A row representing one saved link (video or playlist) for History and folder
/// listings.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

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
                  errorBuilder: (context, error, stack) =>
                      Container(color: Colors.white12),
                )
              else
                Container(color: Colors.white12),
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
      subtitle: Text(
        item.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
