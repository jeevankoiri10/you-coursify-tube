import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coursify_yt/models/library.dart';
import 'package:coursify_yt/models/media.dart';
import 'package:coursify_yt/services/youtube_service.dart';
import 'package:coursify_yt/state/library_controller.dart';
import 'package:coursify_yt/utils/youtube_links.dart';

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
      notes: [
        Note(
          id: 'note_1',
          title: 'Study',
          body: 'Watch https://youtu.be/abc later',
          updatedAtMs: 5,
        ),
      ],
      progress: {
        'abc': VideoProgress(
            positionSeconds: 30, durationSeconds: 100, completed: false),
      },
      currentItemId: 'item_1',
    );

    final restored = Library.fromJson(library.toJson());
    expect(restored.folders.single.name, 'General');
    expect(restored.items.single.video?.positionSeconds, 42.5);
    expect(restored.items.single.lastOpenedAtMs, 20);
    expect(restored.notes.single.body, 'Watch https://youtu.be/abc later');
    expect(restored.progress['abc']?.positionSeconds, 30);
    expect(restored.currentItemId, 'item_1');
  });

  test('progress is centralized per video id and shared across the app',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final controller = LibraryController(Library.empty());
    // Save progress for a url's video id once...
    await controller.saveProgress('vid123', position: 55, duration: 200);
    // ...and every lookup of that id sees it, no matter where it came from.
    expect(controller.startFor('vid123'), 55);
    expect(controller.progressFor('vid123').durationSeconds, 200);
    // A different id is independent.
    expect(controller.startFor('other'), 0);
  });

  test('export then import restores the whole library', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final source = LibraryController(Library.empty());
    final folder = await source.createFolder('Maths');
    await source.addItem(
      type: ItemType.video,
      folderId: folder.id,
      video: VideoItem(videoId: 'v1', title: 'Lecture 1'),
    );
    await source.saveProgress('v1', position: 12, duration: 60);

    final json = source.exportJson();

    final target = LibraryController(Library.empty());
    await target.importJson(json);

    expect(target.folders.any((f) => f.name == 'Maths'), isTrue);
    expect(target.itemCountInFolder(folder.id), 1);
    expect(target.startFor('v1'), 12);
  });

  test('linkify splits youtube links out of note text', () {
    final segs = linkifyYoutube(
      'see https://youtu.be/abc and youtube.com/watch?v=xyz done',
    );
    final links = segs.where((s) => s.isYoutube).map((s) => s.text).toList();
    expect(links, ['https://youtu.be/abc', 'youtube.com/watch?v=xyz']);
  });
}
