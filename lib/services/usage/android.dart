import 'package:usage_stats/usage_stats.dart';

import '../../models/app_usage_info.dart';
import 'source.dart';

/// Per-package foreground time and last-used timestamp within a queried
/// window, in epoch milliseconds.
class _UsageTotals {
  const _UsageTotals(this.totalMs, this.lastUsedMs);

  final Map<String, int> totalMs;
  final Map<String, int> lastUsedMs;
}

class AndroidUsageSource implements UsageSource {
  static const _activityResumed = 1;
  static const _activityPaused = 2;
  static const _screenNonInteractive = 16;
  static const _deviceShutdown = 26;

  @override
  bool get isSupported => true;

  @override
  Future<PermissionStatus> checkPermission() async {
    final granted = await UsageStats.checkUsagePermission();
    return granted == true
        ? PermissionStatus.granted
        : PermissionStatus.denied;
  }

  @override
  Future<void> requestPermission() => UsageStats.grantUsagePermission();

  @override
  Future<List<AppUsageInfo>> getUsage({
    required DateTime start,
    required DateTime end,
  }) async {
    final totals = await _computeUsageTotals(start: start, end: end);
    final usedPackages =
        totals.totalMs.entries.where((entry) => entry.value > 0).toList();

    final result = await Future.wait(usedPackages.map((entry) async {
      final packageName = entry.key;
      final info = await UsageStats.getAppInfo(packageName);
      final icon = await UsageStats.getAppIcon(packageName);
      final lastUsed = totals.lastUsedMs[packageName];
      return AppUsageInfo(
        packageName: packageName,
        appName: info?.appName ?? packageName,
        usage: Duration(milliseconds: entry.value),
        lastTimeUsed: lastUsed != null
            ? DateTime.fromMillisecondsSinceEpoch(lastUsed)
            : null,
        icon: icon,
      );
    }));

    result.sort((a, b) => b.usage.compareTo(a.usage));
    return result;
  }

  @override
  Future<Duration> getTotalUsage({
    required DateTime start,
    required DateTime end,
  }) async {
    final totals = await _computeUsageTotals(start: start, end: end);
    final totalMs =
        totals.totalMs.values.fold<int>(0, (sum, value) => sum + value);
    return Duration(milliseconds: totalMs);
  }

  // queryAndAggregateUsageStats apportions time using the system's internal
  // daily buckets, which aren't aligned to local midnight: querying an
  // arbitrary window (e.g. a single calendar day) yields skewed totals.
  // Recomputing from raw foreground/background events is exact for any
  // [start, end) window. Look back a bit further than [start] to catch an
  // app that was already in the foreground when the window begins.
  Future<_UsageTotals> _computeUsageTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final queryStart = start.subtract(const Duration(days: 1));
    final rawEvents = await UsageStats.queryEvents(queryStart, end);
    final events = rawEvents
        .map((event) => (
              timestamp: int.tryParse(event.timeStamp ?? ''),
              event: event,
            ))
        .where((entry) => entry.timestamp != null)
        .toList()
      ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final resumedAt = <String, int>{};
    final totalMs = <String, int>{};
    final lastUsedMs = <String, int>{};

    void addInterval(String packageName, int fromMs, int toMs) {
      final clippedFrom = fromMs < startMs ? startMs : fromMs;
      final clippedTo = toMs > endMs ? endMs : toMs;
      if (clippedTo <= clippedFrom) return;
      totalMs[packageName] =
          (totalMs[packageName] ?? 0) + (clippedTo - clippedFrom);
      final previousLastUsed = lastUsedMs[packageName];
      if (previousLastUsed == null || clippedTo > previousLastUsed) {
        lastUsedMs[packageName] = clippedTo;
      }
    }

    for (final entry in events) {
      final event = entry.event;
      final timestamp = entry.timestamp!;
      final type = event.eventTypeValue;
      if (type == null) continue;

      // The screen turning off (or the device shutting down) ends any open
      // session: an app can't legitimately stay "in foreground" past that
      // point, even if its matching ACTIVITY_PAUSED event is missing.
      if (type == _screenNonInteractive || type == _deviceShutdown) {
        for (final entry in resumedAt.entries) {
          addInterval(entry.key, entry.value, timestamp);
        }
        resumedAt.clear();
        continue;
      }

      final packageName = event.packageName;
      if (packageName == null) continue;

      if (type == _activityResumed) {
        resumedAt[packageName] = timestamp;
      } else if (type == _activityPaused) {
        final openedAt = resumedAt.remove(packageName);
        if (openedAt != null) {
          addInterval(packageName, openedAt, timestamp);
        }
      }
    }

    // Apps still in the foreground at the end of the queried range. Only
    // extrapolate to [end] when the window includes the present moment: for
    // a fully historical window (e.g. a past calendar day), a dangling
    // ACTIVITY_RESUMED with no closing event means the closing event was
    // pruned from the system's history, not that the app ran until midnight.
    if (!end.isBefore(DateTime.now())) {
      for (final entry in resumedAt.entries) {
        addInterval(entry.key, entry.value, endMs);
      }
    }

    return _UsageTotals(totalMs, lastUsedMs);
  }
}
