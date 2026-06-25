import '../models/day_usage.dart';
import 'day_range.dart';

/// Loads the last 7 days of usage (oldest first) by calling [getDuration] for
/// each day's `[start, end)` window.
///
/// Shared by the all-apps daily chart and a single app's weekly chart — only
/// the duration source differs.
Future<List<DayUsage>> loadWeeklyTotals(
  Future<Duration> Function(DateTime start, DateTime end) getDuration,
) {
  final offsets = List.generate(7, (i) => 6 - i);
  return Future.wait(
    offsets.map((offset) async {
      final range = dayRange(offset);
      final duration = await getDuration(range.start, range.end);
      return DayUsage(day: range.start, offset: offset, duration: duration);
    }),
  );
}
