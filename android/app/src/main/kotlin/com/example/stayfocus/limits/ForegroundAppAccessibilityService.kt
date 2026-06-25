package com.example.stayfocus.limits

import android.view.accessibility.AccessibilityEvent
import android.accessibilityservice.AccessibilityService

/// Reports foreground-app switches to [AppLimitService] the instant they
/// happen, via [AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED].
///
/// [AppLimitService] alone can only learn about a switch on its next poll
/// tick by re-querying [android.app.usage.UsageStatsManager], which lags
/// just enough (poll interval + the usage-stats commit delay) for a few
/// seconds of free use after returning to a blocked app from Recents/Home.
/// This service closes that gap: window-state-changed events are delivered
/// synchronously by the system, with no comparable delay.
///
/// Requires the user to manually enable "StayFocus" under
/// Settings > Accessibility, since this permission can't be granted through
/// a regular runtime dialog. See [LimitsPlugin] for the check/launch-settings
/// bridge and res/xml/accessibility_service_config.xml for its declared
/// event filter.
class ForegroundAppAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        AppLimitService.onForegroundAppChanged(packageName)
    }

    override fun onInterrupt() {}
}
