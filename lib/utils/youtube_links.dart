/// One piece of a note body: either plain text or a YouTube link.
class LinkSegment {
  LinkSegment(this.text, this.isYoutube);
  final String text;
  final bool isYoutube;
}

final _ytRegex = RegExp(
  r'((?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com|youtu\.be|youtube-nocookie\.com)\/[^\s]+)',
  caseSensitive: false,
);

/// Splits [text] into plain and YouTube-link segments so the UI can render the
/// links as tappable spans.
List<LinkSegment> linkifyYoutube(String text) {
  final segments = <LinkSegment>[];
  var last = 0;
  for (final match in _ytRegex.allMatches(text)) {
    if (match.start > last) {
      segments.add(LinkSegment(text.substring(last, match.start), false));
    }
    var link = match.group(0)!;
    var trailing = '';
    // Don't swallow trailing punctuation that's clearly not part of the URL.
    while (link.isNotEmpty && '.,;:!?)]}\'"'.contains(link[link.length - 1])) {
      trailing = link[link.length - 1] + trailing;
      link = link.substring(0, link.length - 1);
    }
    segments.add(LinkSegment(link, true));
    if (trailing.isNotEmpty) segments.add(LinkSegment(trailing, false));
    last = match.end;
  }
  if (last < text.length) {
    segments.add(LinkSegment(text.substring(last), false));
  }
  return segments;
}

/// Whether [text] contains at least one YouTube link.
bool hasYoutubeLink(String text) => _ytRegex.hasMatch(text);
