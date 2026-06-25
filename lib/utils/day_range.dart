/// The `[start, end)` window for the day [offset] days ago (0 = today).
///
/// For a past day, [end] is the following midnight; for today, [end] is now.
({DateTime start, DateTime end}) dayRange(int offset) {
  final now = DateTime.now();
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: offset));
  final end = offset == 0 ? now : day.add(const Duration(days: 1));
  return (start: day, end: end);
}
