import DeviceActivity
import SwiftUI

/// Entry point Apple's extension host loads. Declares the one report scene
/// `UsageReportDriver` (Runner target) renders for every group — see that
/// file for why a single shared context, rather than one per group, is
/// what we have to work with here.
///
/// NOTE: this file's content (this struct and `TotalUsageReportScene`
/// below) is meant to replace the body Xcode generates when you create a
/// target from its "Device Activity Report Extension" template — see the
/// setup guide.
@main
struct ReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalUsageReportScene()
    }
}

/// Sums every app/category duration delivered for the current render pass
/// — already scoped to a single group's selection by the `DeviceActivityFilter`
/// `UsageReportDriver` builds — and writes that anonymous total into the
/// App Group container via `LimitsSharedStore`, keyed by whichever group id
/// `LimitsSharedStore.currentReportGroupId` names at the time this runs.
///
/// This write-out is the unofficially-documented technique described in
/// `IosLimitsService`'s doc comment (Dart side): Apple's framework hands
/// real per-app `Duration` values to this code specifically so it can
/// render a view, not so it can be exported — but nothing here ever writes
/// per-app data out, only the user's own pre-aggregated group total, which
/// community reports suggest Apple tolerates (see that doc comment for the
/// full caveat). The view itself can be empty; its only job is to exist
/// long enough for `makeConfiguration` to run.
struct TotalUsageReportScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("totalUsage")
    let content: (Int) -> EmptyReportView = { _ in EmptyReportView() }

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> Int {
        var totalSeconds: TimeInterval = 0
        for await datum in data {
            for await segment in datum.activitySegments {
                for await category in segment.categories {
                    for await application in category.applications {
                        totalSeconds += application.totalActivityDuration ?? 0
                    }
                }
            }
        }

        let totalMs = Int(totalSeconds * 1000)
        if let groupId = LimitsSharedStore.currentReportGroupId() {
            LimitsSharedStore.setUsageMs(groupId: groupId, ms: totalMs)
        }
        return totalMs
    }
}

/// Discarded visually — see `TotalUsageReportScene`'s doc comment. Kept as
/// a real (if trivial) view rather than `Color.clear` so it's obvious this
/// is intentional, not a placeholder someone forgot to fill in.
struct EmptyReportView: View {
    var body: some View {
        Color.clear.frame(width: 1, height: 1)
    }
}
