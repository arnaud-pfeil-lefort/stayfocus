import 'dart:typed_data';

/// Aggregated foreground usage for a single installed app over a queried period.
class AppUsageInfo {
  const AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.usage,
    this.lastTimeUsed,
    this.icon,
  });

  final String packageName;
  final String appName;
  final Duration usage;
  final DateTime? lastTimeUsed;
  final Uint8List? icon;
}
