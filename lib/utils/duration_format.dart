/// Formats [duration] as a short French label, e.g. "1 h 23 min" or "45 min".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return '$minutes min';
  }
  if (minutes == 0) {
    return '$hours h';
  }
  return '$hours h $minutes min';
}

/// Formats [duration] like [formatDuration] but without the trailing "min"
/// unit, e.g. "1 h 23" or "45 min" — used for compact chart labels.
String formatDurationCompact(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return '$minutes min';
  }
  if (minutes == 0) {
    return '$hours h';
  }
  return '$hours h $minutes';
}
