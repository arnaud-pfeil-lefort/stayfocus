import '../../models/app_usage_info.dart';


enum PermissionStatus { granted, denied, unsupported }


abstract class UsageSource {
  bool get isSupported;

  Future<PermissionStatus> checkPermission();
  Future<void> requestPermission();

  /// Apps used between [start] and [end], sorted by usage descending.
  Future<List<AppUsageInfo>> getUsage({
    required DateTime start,
    required DateTime end,
  });

  /// Total foreground usage time across all apps between [start] and [end].
  ///
  /// Cheaper than summing [getUsage], since it skips resolving app names and
  /// icons. Used to draw the per-day usage chart.
  Future<Duration> getTotalUsage({
    required DateTime start,
    required DateTime end,
  });
}
