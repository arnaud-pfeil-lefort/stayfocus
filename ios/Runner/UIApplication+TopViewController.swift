import UIKit

extension UIApplication {
    /// The topmost presented view controller across all scenes — used to
    /// present the `FamilyActivityPicker` and to host the off-screen
    /// `DeviceActivityReportView` (see `IosLimitsPlugin` / `UsageReportDriver`).
    func topMostViewController() -> UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
