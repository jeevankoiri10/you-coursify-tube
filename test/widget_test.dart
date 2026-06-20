import 'package:flutter_test/flutter_test.dart';

import 'package:coursify_yt/models/library.dart';
import 'package:coursify_yt/models/media.dart';
import 'package:coursify_yt/services/youtube_service.dart';

void main() {
  test('parses a single video link', () {
    final parsed = YoutubeService.parse(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(parsed.kind, LinkKind.video);
    expect(parsed.id, 'dQw4w9WgXcQ');
  });

  test('parses a playlist link as a playlist', () {
    final parsed = YoutubeService.parse(
      'https://www.youtube.com/playlist?list=PL1234567890abcdefXY',
    );
    expect(parsed.kind, LinkKind.playlist);
  });

  test('rejects a non-youtube link', () {
    final parsed = YoutubeService.parse('https://example.com/hello');
    expect(parsed.kind, LinkKind.invalid);
  });

  test('library round-trips through json with folders and history', () {
    final library = Library(
      folders: [Folder(id: 'default', name: 'General', createdAtMs: 1)],
      items: [
        LibraryItem(
          id: 'item_1',
          type: ItemType.video,
          folderId: 'default',
          video: VideoItem(videoId: 'abc', title: 'Demo', positionSeconds: 42.5),
          addedAtMs: 10,
          lastOpenedAtMs: 20,
        ),
      ],
      currentItemId: 'item_1',
    );

    final restored = Library.fromJson(library.toJson());
    expect(restored.folders.single.name, 'General');
    expect(restored.items.single.video?.positionSeconds, 42.5);
    expect(restored.items.single.lastOpenedAtMs, 20);
    expect(restored.currentItemId, 'item_1');
  });
}
