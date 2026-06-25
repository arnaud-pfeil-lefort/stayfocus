import '../../models/app_usage_info.dart';
import 'source.dart';

/// iOS has no API for a third-party app to query "app X was used for Y
/// duration" — not even through native Swift code outside Apple's own
/// sandboxed Screen Time extensions. So this honestly reports unsupported
/// for the generic per-package query interface, same as [UnsupportedUsageSource].
///
/// The real iOS app-limiting feature lives in `IosLimitsService` and
/// `IosAppLimitsScreen` instead: a structurally different flow (the user
/// picks apps via Apple's own picker, keyed by an opaque id rather than a
/// package name) that doesn't fit the [UsageSource] abstraction. This class
/// exists mainly so that distinction is explicit in code, rather than
/// overloading `isSupported == false` to mean two different things.
class IosUsageSource implements UsageSource {
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
  }) async =>
      const [];

  @override
  Future<Duration> getTotalUsage({
    required DateTime start,
    required DateTime end,
  }) async =>
      Duration.zero;

  @override
  Future<Duration> getPackageUsage({
    required String packageName,
    required DateTime start,
    required DateTime end,
  }) async =>
      Duration.zero;
}
