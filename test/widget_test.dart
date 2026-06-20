import 'package:flutter_test/flutter_test.dart';

import 'package:coursify_yt/models/app_state.dart';
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

  test('app state round-trips through json', () {
    final state = AppState(
      mode: LibraryMode.single,
      single: VideoItem(videoId: 'abc', title: 'Demo', positionSeconds: 42.5),
    );
    final restored = AppState.fromJson(state.toJson());
    expect(restored.mode, LibraryMode.single);
    expect(restored.single?.videoId, 'abc');
    expect(restored.single?.positionSeconds, 42.5);
  });
}
