import 'package:flutter/foundation.dart';

/// A single day's total foreground usage across all apps, used to draw the
/// per-day usage chart.
@immutable
class DayUsage {
  const DayUsage({
    required this.day,
    required this.offset,
    required this.duration,
  });

  /// Midnight of the represented day.
  final DateTime day;

  /// Days ago that [day] represents (0 = today).
  final int offset;

  final Duration duration;
}
