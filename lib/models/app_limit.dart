/// User-configured limit for a single app: an optional periodic warning and
/// an optional daily usage cap that triggers blocking.
///
/// Both fields are optional independently; a limit with both null shouldn't
/// be persisted (it's equivalent to having no limit at all).
class AppLimit {
  const AppLimit({
    required this.packageName,
    this.warningIntervalMinutes,
    this.dailyLimitMinutes,
  });

  final String packageName;

  /// Notify the user every [warningIntervalMinutes] of cumulative daily
  /// usage of this app, or null if warnings are disabled.
  final int? warningIntervalMinutes;

  /// Block the app once today's cumulative usage reaches this many minutes,
  /// or null if blocking is disabled.
  final int? dailyLimitMinutes;

  bool get isEmpty => warningIntervalMinutes == null && dailyLimitMinutes == null;

  Map<String, Object?> toMap() => {
        'packageName': packageName,
        'warningIntervalMinutes': warningIntervalMinutes,
        'dailyLimitMinutes': dailyLimitMinutes,
      };

  static AppLimit fromMap(Map<Object?, Object?> map) => AppLimit(
        packageName: map['packageName'] as String,
        warningIntervalMinutes: map['warningIntervalMinutes'] as int?,
        dailyLimitMinutes: map['dailyLimitMinutes'] as int?,
      );
}
