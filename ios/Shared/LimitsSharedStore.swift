import FamilyControls
import Foundation

/// One stored limit group: mirrors `IosAppLimitGroup` on the Dart side, plus
/// the actual app/category selection that Dart is never shown.
struct StoredGroup: Codable {
    let id: String
    var nickname: String
    var warningIntervalMinutes: Int?
    var dailyLimitMinutes: Int?
    var selection: FamilyActivitySelection?

    var hasSelection: Bool {
        guard let selection else { return false }
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }
}

/// Native-side persistence for iOS limit groups, shared between the main
/// app and all three Screen Time extensions via an App Group container —
/// extensions run in separate sandboxed processes that can't see the host
/// app's regular `UserDefaults`. Mirrors the role of `LimitsStore.kt` on
/// Android.
///
/// IMPORTANT (manual Xcode step): add this file to all four targets
/// (Runner + DeviceActivityMonitorExtension + ShieldConfigurationExtension +
/// DeviceActivityReportExtension) in Xcode's File Inspector — Xcode only
/// adds a new file to the target you created it from by default.
enum LimitsSharedStore {
    static let appGroupId = "group.com.example.stayfocus"

    private static let groupsKey = "groups"
    private static let usageMsKeyPrefix = "usage_ms_"
    private static let usageDateKeyPrefix = "usage_date_"
    private static let currentReportGroupIdKey = "current_report_group_id"

    private static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            fatalError(
                "App Group \(appGroupId) is missing from this target's entitlements"
            )
        }
        return defaults
    }

    static func loadGroups() -> [StoredGroup] {
        guard let data = defaults.data(forKey: groupsKey) else { return [] }
        return (try? JSONDecoder().decode([StoredGroup].self, from: data)) ?? []
    }

    static func saveGroups(_ groups: [StoredGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: groupsKey)
    }

    static func group(id: String) -> StoredGroup? {
        loadGroups().first { $0.id == id }
    }

    /// Replaces (or inserts) the group matching `group.id`.
    static func upsert(_ group: StoredGroup) {
        var groups = loadGroups()
        groups.removeAll { $0.id == group.id }
        groups.append(group)
        saveGroups(groups)
    }

    static func remove(id: String) {
        var groups = loadGroups()
        groups.removeAll { $0.id == id }
        saveGroups(groups)
        clearUsage(groupId: id)
    }

    // MARK: - Usage bridge
    //
    // Written by ReportExtension.swift, read back by
    // IosLimitsPlugin.getUsageMs. This is the unofficially-documented
    // numeric bridge described in IosLimitsService's doc comment — only the
    // anonymous per-group total ever gets written here, never per-app data.

    /// Today's cumulative usage for `groupId`, in milliseconds. Returns 0 if
    /// nothing has been written yet today (stale numbers from a previous
    /// day are never returned).
    static func usageMs(groupId: String) -> Int {
        guard defaults.string(forKey: usageDateKeyPrefix + groupId) == todayKey() else {
            return 0
        }
        return defaults.integer(forKey: usageMsKeyPrefix + groupId)
    }

    static func setUsageMs(groupId: String, ms: Int) {
        defaults.set(ms, forKey: usageMsKeyPrefix + groupId)
        defaults.set(todayKey(), forKey: usageDateKeyPrefix + groupId)
    }

    // MARK: - Current report target
    //
    // `ReportExtension`'s context identifier is the same for every group
    // (Apple's report scenes are declared statically, not one per
    // dynamically-created group), so it has no way to know *which* group a
    // given render pass is for. `UsageReportDriver` sets this immediately
    // before triggering a render, and serializes calls so two renders never
    // overlap and clobber this value.

    static func setCurrentReportGroupId(_ id: String) {
        defaults.set(id, forKey: currentReportGroupIdKey)
    }

    static func currentReportGroupId() -> String? {
        defaults.string(forKey: currentReportGroupIdKey)
    }

    private static func clearUsage(groupId: String) {
        defaults.removeObject(forKey: usageMsKeyPrefix + groupId)
        defaults.removeObject(forKey: usageDateKeyPrefix + groupId)
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
