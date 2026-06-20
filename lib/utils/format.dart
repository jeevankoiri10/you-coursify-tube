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
