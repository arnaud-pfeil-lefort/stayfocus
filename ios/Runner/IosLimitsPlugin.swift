import Flutter
import FamilyControls
import SwiftUI
import UIKit

/// Bridges the Dart side (`IosLimitsService`) to `LimitsSharedStore` /
/// `MonitoringScheduler` / `UsageReportDriver`. Parallel role to
/// `LimitsPlugin.kt` on Android, registered the same way from
/// `AppDelegate.swift`.
public class IosLimitsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.stayfocus/ios_limits",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(IosLimitsPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkAuthorization":
            result(AuthorizationCenter.shared.authorizationStatus == .approved)

        case "requestAuthorization":
            requestAuthorization(result: result)

        case "getGroups":
            result(LimitsSharedStore.loadGroups().map { $0.toFlutterMap() })

        case "createGroup":
            guard let nickname = call.arguments as? String else {
                result(FlutterError(code: "invalid_args", message: "Expected a nickname string", details: nil))
                return
            }
            result(createGroup(nickname: nickname))

        case "pickApps":
            guard let groupId = call.arguments as? String else {
                result(FlutterError(code: "invalid_args", message: "Expected a group id string", details: nil))
                return
            }
            pickApps(groupId: groupId, result: result)

        case "saveGroup":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
                return
            }
            result(saveGroup(args: args))

        case "removeGroup":
            guard let id = call.arguments as? String else {
                result(FlutterError(code: "invalid_args", message: "Expected a group id string", details: nil))
                return
            }
            result(removeGroup(id: id))

        case "getUsageMs":
            guard let groupId = call.arguments as? String else {
                result(FlutterError(code: "invalid_args", message: "Expected a group id string", details: nil))
                return
            }
            UsageReportDriver.refresh(groupId: groupId) {
                result(LimitsSharedStore.usageMs(groupId: groupId))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestAuthorization(result: @escaping FlutterResult) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                // The user may have declined, or authorization may already
                // be restricted by a parent/organization — either way fall
                // through to reporting the resulting status below.
            }
            result(AuthorizationCenter.shared.authorizationStatus == .approved)
        }
    }

    private func createGroup(nickname: String) -> String {
        let id = UUID().uuidString
        LimitsSharedStore.upsert(
            StoredGroup(
                id: id,
                nickname: nickname,
                warningIntervalMinutes: nil,
                dailyLimitMinutes: nil,
                selection: nil
            )
        )
        return id
    }

    private func pickApps(groupId: String, result: @escaping FlutterResult) {
        guard var group = LimitsSharedStore.group(id: groupId) else {
            result(false)
            return
        }
        guard let rootViewController = UIApplication.shared.topMostViewController() else {
            result(false)
            return
        }

        var hostingController: UIHostingController<PickerHost>?
        let host = PickerHost(
            selection: group.selection ?? FamilyActivitySelection(),
            onDone: { selection in
                group.selection = selection
                LimitsSharedStore.upsert(group)
                MonitoringScheduler.reschedule(group: group)
                hostingController?.dismiss(animated: true) {
                    result(true)
                }
            },
            onCancel: {
                hostingController?.dismiss(animated: true) {
                    result(false)
                }
            }
        )
        let controller = UIHostingController(rootView: host)
        hostingController = controller
        rootViewController.present(controller, animated: true)
    }

    private func saveGroup(args: [String: Any]) -> [[String: Any?]] {
        guard let id = args["id"] as? String else {
            return LimitsSharedStore.loadGroups().map { $0.toFlutterMap() }
        }
        var group = LimitsSharedStore.group(id: id)
            ?? StoredGroup(
                id: id,
                nickname: args["nickname"] as? String ?? "",
                warningIntervalMinutes: nil,
                dailyLimitMinutes: nil,
                selection: nil
            )
        group.nickname = args["nickname"] as? String ?? group.nickname
        group.warningIntervalMinutes = args["warningIntervalMinutes"] as? Int
        group.dailyLimitMinutes = args["dailyLimitMinutes"] as? Int
        LimitsSharedStore.upsert(group)
        MonitoringScheduler.reschedule(group: group)
        return LimitsSharedStore.loadGroups().map { $0.toFlutterMap() }
    }

    private func removeGroup(id: String) -> [[String: Any?]] {
        MonitoringScheduler.stop(groupId: id)
        LimitsSharedStore.remove(id: id)
        return LimitsSharedStore.loadGroups().map { $0.toFlutterMap() }
    }
}

private extension StoredGroup {
    func toFlutterMap() -> [String: Any?] {
        [
            "id": id,
            "nickname": nickname,
            "warningIntervalMinutes": warningIntervalMinutes,
            "dailyLimitMinutes": dailyLimitMinutes,
            "hasSelection": hasSelection,
        ]
    }
}

/// Wraps Apple's `FamilyActivityPicker` with our own Cancel/OK toolbar
/// buttons rather than relying on the picker's built-in chrome to dismiss
/// the `UIHostingController` it's presented in — verify in Xcode whether
/// this double-wraps navigation chrome and simplify if so.
private struct PickerHost: View {
    @State var selection: FamilyActivitySelection
    let onDone: (FamilyActivitySelection) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Choisir des applis")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { onDone(selection) }
                    }
                }
        }
    }
}
