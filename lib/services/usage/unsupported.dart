import '../../models/app_usage_info.dart';
import 'source.dart';

/// Fallback used on platforms without a usage-stats implementation yet
/// (everything except Android, for now).
class UnsupportedUsageSource implements UsageSource {
  @override
  bool get isSupported => false;

  @override
  Future<PermissionStatus> checkPermission() async =>
      PermissionStatus.unsupported;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<List<AppUsageInfo>> getUsage({
    required DateTime start,
    required DateTime end,
  }) async => const [];

  @override
  Future<Duration> getTotalUsage({
    required DateTime start,
    required DateTime end,
  }) async => Duration.zero;

  @override
  Future<Duration> getPackageUsage({
    required String packageName,
    required DateTime start,
    required DateTime end,
  }) async => Duration.zero;
}
