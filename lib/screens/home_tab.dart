import 'package:flutter/material.dart';

import '../models/library.dart';
import '../navigation.dart';
import '../state/library_controller.dart';
import '../widgets/add_link_form.dart';
import '../widgets/item_tile.dart';

/// The Home tab: paste-and-start at the top, a "Continue watching" card for the
/// active item, and the History list of everything you've opened.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.current;
    final history = controller.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        AddLinkForm(controller: controller),
        const SizedBox(height: 20),
        if (current != null) ...[
          const _SectionHeader('Continue watching'),
          _ContinueCard(
            item: current,
            statusText: current.type == ItemType.video && current.video != null
                ? controller.videoStatus(current.video!)
                : current.subtitle,
            onTap: () => openItem(context, controller, current),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            const _SectionHeader('History'),
            const Spacer(),
            if (history.isNotEmpty)
              Text(
                '${history.length}',
                style: const TextStyle(color: Colors.white38),
              ),
          ],
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Nothing yet.\nPaste a link above to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38),
              ),
            ),
          )
        else
          for (final item in history)
            ItemTile(
              item: item,
              controller: controller,
              onTap: () => openItem(context, controller, item),
            ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.item,
    required this.statusText,
    required this.onTap,
  });
  final LibraryItem item;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: const Color(0xFF1C1C20),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
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
                  const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xCCFF4D4D),
                      child: Icon(Icons.play_arrow, size: 34, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(statusText,
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
