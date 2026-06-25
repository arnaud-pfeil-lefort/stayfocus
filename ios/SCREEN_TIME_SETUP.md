# Finishing the iOS app-limiting feature in Xcode

Everything that *can* be done from a text editor is already in place: the
Dart UI/services, `ios/Runner/Runner.entitlements`, the deployment-target
bump, and every Swift file's content. What's left needs Xcode itself,
running on a Mac, with a real iPhone/iPad — none of this works in the
Simulator, and none of it could be done or tested from this environment.

Read this start to finish before touching Xcode — steps 3 and 5 are the
ones most likely to be skipped by accident and cause confusing build/runtime
failures later.

## 0. Prerequisites

- A Mac with Xcode (recent version — `DeviceActivityReport` needs the iOS
  16 SDK or later, already reflected in the deployment-target bump).
- A real iPhone or iPad. The Simulator cannot run `FamilyActivityPicker`,
  the shield, or any `DeviceActivity*` extension.
- An Apple ID added to Xcode (Settings → Accounts). A free/personal team is
  enough to build and test locally — see §6 for the one thing that *does*
  need a paid account and Apple's approval (App Store distribution only,
  not testing).

## 1. Open the right project file

```
flutter pub get
open ios/Runner.xcworkspace
```

Open the `.xcworkspace`, not `.xcodeproj` — Flutter/CocoaPods wiring lives
in the workspace.

## 2. Sanity-check what's already done

In Xcode's navigator, confirm you see (all already on disk, just verify
they show up):
- `Runner/Runner.entitlements` with `com.apple.developer.family-controls`
  and an App Group entry for `group.com.example.stayfocus`.
- Runner target's deployment target reads 16.0 (Build Settings).

If `Runner.entitlements` doesn't appear in the navigator at all, something
went wrong with the project-file edit — re-add it via "Add Files to
Runner..." pointing at the existing file rather than recreating it.

## 3. Register the capabilities with your Apple ID (don't skip this)

Hand-editing the entitlements file gets it into the *build*, but doesn't
register the App Group / Family Controls capability against your
provisioning profile with Apple. You still need to:

1. Select the **Runner** target → **Signing & Capabilities**.
2. Click **+ Capability** → add **App Groups**. Xcode should detect
   `group.com.example.stayfocus` already in the entitlements file — tick it
   (or let Xcode create it if it offers to).
3. Click **+ Capability** → add **Family Controls**.

If Xcode complains it can't register the App Group (free account
limitation, rare but possible), that's a sign-in/team issue to resolve
before continuing — not a code problem.

## 4. Create the three extension targets

For each one: **File → New → Target…**, search for the exact template name
below, and use the exact product name shown (the Swift files already
written reference these names).

| Template to search for | Target product name | Prepared file (copy its code in) |
|---|---|---|
| "Device Activity Monitor Extension" | `DeviceActivityMonitorExtension` | `ios/DeviceActivityMonitorExtension/MonitorExtension.swift` |
| "Shield Configuration Extension" | `ShieldConfigurationExtension` | `ios/ShieldConfigurationExtension/ShieldConfiguration.swift` |
| "Device Activity Report Extension" | `DeviceActivityReportExtension` | `ios/DeviceActivityReportExtension/ReportExtension.swift` |

When Xcode asks, **embed each in the Runner target's app bundle** (the
template wizard does this by default — don't change it).

**For each new target, do NOT add the prepared file as an extra file.**
Xcode generates its own starter `.swift` file (with the right class name
stub) inside a same-named folder, alongside an auto-generated `Info.plist`
that declares the correct, exact `NSExtensionPointIdentifier` for that
extension type — getting that identifier right by hand is easy to get
subtly wrong and hard to debug, which is why creating the target via the
template (rather than writing the `Info.plist` by hand) matters. Instead:

1. Open the starter `.swift` file Xcode generated for that target.
2. Delete its contents and paste in the contents of the matching file from
   the table above.
3. Leave the rest of what the template generated (`Info.plist`, folder)
   untouched.

For each of the three new targets, also:
- Set its deployment target to 16.0 in Build Settings (should already
  inherit this from the project default, but verify).
- **Signing & Capabilities** → add **App Groups** → tick
  `group.com.example.stayfocus` (same group as Runner).
- Add **Family Controls** too, for all three, even though the report
  extension may not strictly need it — keeping all three consistent avoids
  one-off debugging later.

## 5. Add the shared/main-app Swift files to the project (the step most likely to be missed)

Files already written to disk are **not** part of the Xcode project model
until you explicitly add them — Xcode doesn't watch the filesystem.

**`ios/Shared/LimitsSharedStore.swift`** — right-click a group in the
navigator (e.g. create a new "Shared" group) → **Add Files to "Runner"...**
→ select this file → in the dialog's target-membership checkboxes, **tick
all four targets**: Runner, DeviceActivityMonitorExtension,
ShieldConfigurationExtension, DeviceActivityReportExtension. This is the one
file every process needs, since it's the only thing they all share data
through.

**Runner-only files** — right-click the `Runner` group → **Add Files to
"Runner"...** → select all of:
- `ios/Runner/IosLimitsPlugin.swift`
- `ios/Runner/MonitoringScheduler.swift`
- `ios/Runner/UsageReportDriver.swift`
- `ios/Runner/UIApplication+TopViewController.swift`

Target membership for these four: **Runner only**.

If you skip this step, the build will fail at the `AppDelegate.swift`
reference to `IosLimitsPlugin` with an "undefined symbol"/"cannot find
type" error — that's the signal to come back here.

## 6. Build and run on a real device

Select your device (not a Simulator) as the run destination. First build
should go through Xcode directly (extension targets need to be embedded
correctly, which `flutter run` alone won't always get right on the first
try) — subsequent Dart-only changes can go back to `flutter run`/hot
restart.

## 7. Manual test script

1. Open the app → the Usage screen should show `IosAppLimitsScreen`'s
   permission prompt (Family Controls not yet authorized).
2. Tap "Autoriser" → the system authorization sheet should appear.
3. Tap "+" → name a group "Test" → the system `FamilyActivityPicker` sheet
   should appear → pick 1-2 apps you can quickly reopen.
4. Open "Test" → enable both toggles → set warning to 15 min, daily limit
   to 15 min (the minimum, for a fast test).
5. Actually use one of the picked apps continuously:
   - At ~15 min: a local notification should fire, named "Test".
   - Past 15 min: the picked app should show **our** shield (red "STOP." /
     "Bouge-toi" button) — if you see Apple's plain default shield instead,
     the `ShieldConfigurationExtension` isn't wired correctly (re-check §4).
   - Tap "Bouge-toi" → should return to the home screen.
6. Back in StayFocus, pull-to-refresh `IosAppLimitsScreen` → the usage
   number for "Test" should become a real, plausible minute count, not 0.
   **If it stays at 0**, see the troubleshooting note below — this is the
   single riskiest part of the whole feature.
7. Wait past local midnight (or just trust the logic / re-test the next
   day) → shield should lift, no spurious notification.
8. Edit the group's minutes → new thresholds should take effect without a
   reinstall.
9. Delete the group → shield lifts immediately, monitoring stops.
10. **Android regression check**: quickly re-verify the Android permission
    → usage list → `AppLimitCard` flow still behaves identically — the only
    Android-adjacent change was one new `Platform.isIOS` branch in
    `usage_screen.dart`, but verify rather than assume.

### If step 6 stays at 0 ms

In rough order of likelihood:
- The App Group string doesn't match exactly across all 4 targets'
  entitlements (`group.com.example.stayfocus`, case-sensitive, must be
  byte-identical everywhere).
- `UsageReportDriver`'s 1-second fixed delay isn't enough on a slow first
  run (cold-starting the extension process) — try a longer delay or add
  logging (`print` statements are visible in Xcode's device console,
  filtered by process name `DeviceActivityReportExtension`) to confirm
  whether `makeConfiguration` ever actually runs.
- `DeviceActivityReportScene`'s exact protocol shape (property names,
  `makeConfiguration` signature) drifted from what's written here in a
  newer/older SDK than assumed — Xcode's own error messages on this file
  will be the fastest way to spot a real signature mismatch; fix to match
  what the compiler expects rather than what's documented here.

## Don't forget before any App Store submission (not now)

`com.apple.developer.family-controls` needs a *separate* approval request
to Apple — https://developer.apple.com/contact/request/family-controls-distribution
— before this app can be submitted to the App Store. Not required for
local development/testing, and not something to action now; just don't
forget it exists the day this app is ever submitted.
