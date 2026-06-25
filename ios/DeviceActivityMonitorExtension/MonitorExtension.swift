import DeviceActivity
import ManagedSettings
import UserNotifications

/// Reacts to the thresholds `MonitoringScheduler` (Runner target) registers:
/// shields the group's apps once the daily limit is crossed, and posts a
/// local notification for each warning multiple. Mirrors the
/// threshold-reaction half of `AppLimitService.kt`'s `poll()` on Android —
/// the other half (deciding *when* to check) is the OS's job here, not ours.
///
/// NOTE: this file's content is meant to replace the body of the class
/// Xcode generates when you create a target from its "Device Activity
/// Monitor Extension" template — see the setup guide for why creating the
/// target via that template (rather than by hand) matters.
class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Midnight rollover: lift yesterday's shield so it doesn't carry
        // into the freshly-started day before any new threshold fires.
        let groupId = activity.rawValue
        ManagedSettingsStore(named: ManagedSettingsStore.Name(groupId)).shield.applications = nil
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        let groupId = activity.rawValue
        guard let group = LimitsSharedStore.group(id: groupId) else { return }

        let eventName = event.rawValue
        if eventName == "\(groupId).dailyLimit" {
            applyShield(for: group)
        } else if eventName.hasPrefix("\(groupId).warning.") {
            postWarningNotification(for: group)
        }
    }

    private func applyShield(for group: StoredGroup) {
        guard let selection = group.selection else { return }
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(group.id))
        store.shield.applications =
            selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories =
            selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    private func postWarningNotification(for group: StoredGroup) {
        let content = UNMutableNotificationContent()
        content.title = group.nickname
        content.body = "Tu as atteint ton seuil d'avertissement aujourd'hui."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "stayfocus.warning.\(group.id).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
