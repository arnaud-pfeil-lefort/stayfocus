import DeviceActivity
import Foundation
import ManagedSettings

/// Schedules/clears `DeviceActivity` monitoring and the `ManagedSettings`
/// shield for one group. Mirrors what `AppLimitService.kt` decides by
/// polling on Android — here we register thresholds once up front, and
/// `MonitorExtension.swift`'s callbacks react when the OS reports them
/// crossed. Called from `IosLimitsPlugin` after every group edit.
enum MonitoringScheduler {
    private static let center = DeviceActivityCenter()

    static func reschedule(group: StoredGroup) {
        let activity = DeviceActivityName(group.id)
        center.stopMonitoring([activity])

        guard let selection = group.selection,
            group.warningIntervalMinutes != nil || group.dailyLimitMinutes != nil
        else {
            ManagedSettingsStore(named: ManagedSettingsStore.Name(group.id)).shield.applications = nil
            return
        }

        // 0:00 to 23:59 rather than 24:00, which DateComponents won't accept
        // as an hour value — the common workaround for "the whole day".
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        // DeviceActivity has no "repeat every X minutes" primitive — only
        // one-shot-per-day thresholds — so a warning every X minutes is
        // realized as one event per multiple of X, up to the daily limit
        // (or a 4h cap if there's no daily limit).
        if let warningMinutes = group.warningIntervalMinutes {
            let cap = group.dailyLimitMinutes ?? 240
            var minute = warningMinutes
            while minute <= cap {
                let name = DeviceActivityEvent.Name("\(group.id).warning.\(minute)")
                events[name] = DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    threshold: DateComponents(minute: minute)
                )
                minute += warningMinutes
            }
        }

        if let dailyLimitMinutes = group.dailyLimitMinutes {
            let name = DeviceActivityEvent.Name("\(group.id).dailyLimit")
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: dailyLimitMinutes)
            )
        }

        do {
            try center.startMonitoring(activity, during: schedule, events: events)
        } catch {
            // Not surfaced to Dart yet — at minimum check Xcode's console
            // for this during manual testing.
            print("StayFocus: failed to start monitoring for group \(group.id): \(error)")
        }
    }

    static func stop(groupId: String) {
        center.stopMonitoring([DeviceActivityName(groupId)])
        ManagedSettingsStore(named: ManagedSettingsStore.Name(groupId)).shield.applications = nil
    }
}
