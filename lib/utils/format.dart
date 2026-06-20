/// Formats a number of seconds as `m:ss` or `h:mm:ss`.
String formatDuration(num? totalSeconds) {
  if (totalSeconds == null || totalSeconds <= 0) return '0:00';
  final s = totalSeconds.round();
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final seconds = s % 60;
  final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A grouping label for a moment in time: "Today", "Yesterday", or a date.
String dayLabel(int millis) {
  if (millis <= 0) return 'Earlier';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff >= 2 && diff <= 7) return '$diff days ago';
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// A compact absolute date like "Jun 16, 2026".
String shortDate(int millis) {
  if (millis <= 0) return 'unknown date';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
