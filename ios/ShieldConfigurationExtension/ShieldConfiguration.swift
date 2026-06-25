import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the system block screen to match the tone used on Android's
/// overlay (`AppLimitService.kt`'s `buildBlockerView`): direct, a little
/// blunt, meant to actually move the user rather than just inform them.
///
/// Named `StayFocusShieldConfigurationDataSource` rather than the more
/// obvious `ShieldConfiguration` to avoid colliding with Apple's own
/// `ShieldConfiguration` struct (the return type below) — same name would
/// shadow it within this file.
///
/// NOTE: this file's content is meant to replace the body of the class
/// Xcode generates when you create a target from its "Shield Configuration
/// Extension" template — see the setup guide.
class StayFocusShieldConfigurationDataSource: ShieldConfigurationDataSource {
    private let accent = UIColor(red: 0xE5 / 255, green: 0x39 / 255, blue: 0x35 / 255, alpha: 1)
    private let background = UIColor(red: 0x1A / 255, green: 0x14 / 255, blue: 0x30 / 255, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName ?? "cette appli")
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName ?? "cette appli")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain ?? "ce site")
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain ?? "ce site")
    }

    private func makeConfiguration(name: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: background,
            title: ShieldConfiguration.Label(text: "STOP.", color: accent),
            subtitle: ShieldConfiguration.Label(
                text: "Tu as cramé ta limite sur \(name). Repose ce téléphone, "
                    + "lève-toi et va faire un truc qui compte — ta vie ne se vit "
                    + "pas en scrollant.",
                color: .white
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Bouge-toi", color: .white),
            primaryButtonBackgroundColor: accent
        )
    }
}
