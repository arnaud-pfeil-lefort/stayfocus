/// A user-configured limit group on iOS: a set of apps/categories picked
/// through Apple's `FamilyActivityPicker`, identified by an opaque [id]
/// since iOS never reveals which apps were actually selected.
///
/// Unlike Android's [AppLimit] (keyed by a readable package name), iOS gives
/// us no identity at all — [nickname] is what the user types themselves to
/// label the group, since neither Dart nor most of the native Swift code can
/// ever know "this is Instagram".
class IosAppLimitGroup {
  const IosAppLimitGroup({
    required this.id,
    required this.nickname,
    this.warningIntervalMinutes,
    this.dailyLimitMinutes,
    this.hasSelection = false,
  });

  final String id;
  final String nickname;

  /// Notify every [warningIntervalMinutes] of cumulative daily usage across
  /// the group, or null if disabled. Must be a multiple of 15 (iOS's
  /// DeviceActivity threshold floor) when set.
  final int? warningIntervalMinutes;

  /// Block the group's apps once today's usage reaches this many minutes,
  /// or null if disabled. Must be a multiple of 15 when set.
  final int? dailyLimitMinutes;

  /// Whether the user has picked at least one app/category for this group
  /// via the system picker. A group can exist with a nickname and limit
  /// minutes configured before a selection is made — the UI uses this to
  /// prompt "choose apps" before the sliders make sense.
  final bool hasSelection;

  bool get isEmpty => warningIntervalMinutes == null && dailyLimitMinutes == null;

  IosAppLimitGroup copyWith({
    String? nickname,
    int? warningIntervalMinutes,
    bool clearWarning = false,
    int? dailyLimitMinutes,
    bool clearDailyLimit = false,
    bool? hasSelection,
  }) =>
      IosAppLimitGroup(
        id: id,
        nickname: nickname ?? this.nickname,
        warningIntervalMinutes: clearWarning
            ? null
            : (warningIntervalMinutes ?? this.warningIntervalMinutes),
        dailyLimitMinutes: clearDailyLimit
            ? null
            : (dailyLimitMinutes ?? this.dailyLimitMinutes),
        hasSelection: hasSelection ?? this.hasSelection,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'nickname': nickname,
        'warningIntervalMinutes': warningIntervalMinutes,
        'dailyLimitMinutes': dailyLimitMinutes,
        'hasSelection': hasSelection,
      };

  static IosAppLimitGroup fromMap(Map<Object?, Object?> map) => IosAppLimitGroup(
        id: map['id'] as String,
        nickname: map['nickname'] as String,
        warningIntervalMinutes: map['warningIntervalMinutes'] as int?,
        dailyLimitMinutes: map['dailyLimitMinutes'] as int?,
        hasSelection: map['hasSelection'] as bool? ?? false,
      );
}
