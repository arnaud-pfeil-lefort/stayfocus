import DeviceActivity
import SwiftUI
import UIKit

/// Triggers `DeviceActivityReportExtension` to run by briefly hosting a
/// `DeviceActivityReportView` off-screen (1x1pt, invisible), then waits for
/// it to have written its result via `LimitsSharedStore` before calling
/// back. This is not a passive read — the report only gets computed when
/// its view is actually rendered by the OS. See `ReportExtension.swift` and
/// the usage-bridge caveat documented on `IosLimitsService` (Dart side).
///
/// `ReportExtension` uses a single, static context identifier for every
/// group (Apple's report scenes aren't meant to be declared dynamically per
/// arbitrary user-created group), so it can only know which group a render
/// is for via `LimitsSharedStore.currentReportGroupId`. Calls here are
/// serialized through `queue` so two renders never overlap and clobber
/// that value — callers (Dart's `Future.wait` over several groups) don't
/// need to worry about this; they'll just resolve one at a time.
enum UsageReportDriver {
    private static let reportContext = DeviceActivityReport.Context("totalUsage")
    private static let queue = DispatchQueue(label: "com.example.stayfocus.usageReportDriver")
    private static var isBusy = false
    private static var pending: [(groupId: String, completion: () -> Void)] = []

    static func refresh(groupId: String, completion: @escaping () -> Void) {
        queue.async {
            pending.append((groupId, completion))
            drainIfIdle()
        }
    }

    private static func drainIfIdle() {
        guard !isBusy, let next = pending.first else { return }
        isBusy = true
        pending.removeFirst()
        DispatchQueue.main.async {
            render(groupId: next.groupId) {
                next.completion()
                queue.async {
                    isBusy = false
                    drainIfIdle()
                }
            }
        }
    }

    private static func render(groupId: String, completion: @escaping () -> Void) {
        guard let group = LimitsSharedStore.group(id: groupId), let selection = group.selection
        else {
            completion()
            return
        }
        LimitsSharedStore.setCurrentReportGroupId(groupId)

        let filter = DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: Calendar.current.startOfDay(for: Date()), end: Date())
            ),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )

        let report = DeviceActivityReport(reportContext, filter: filter)
        let hosting = UIHostingController(rootView: report)
        hosting.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        hosting.view.isHidden = true

        guard let rootViewController = UIApplication.shared.topMostViewController() else {
            completion()
            return
        }
        rootViewController.addChild(hosting)
        rootViewController.view.addSubview(hosting.view)
        hosting.didMove(toParent: rootViewController)

        // The extension needs a moment to render and write its result.
        // This fixed delay is a placeholder — verify in Xcode whether a
        // shorter/longer wait (or a completion signal written through the
        // App Group instead of a blind timer) is more reliable in practice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
            completion()
        }
    }
}
