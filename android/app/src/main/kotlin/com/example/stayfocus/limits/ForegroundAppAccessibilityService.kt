package com.example.stayfocus.limits

import android.view.accessibility.AccessibilityEvent
import android.accessibilityservice.AccessibilityService

class ForegroundAppAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        AppLimitService.onForegroundAppChanged(packageName)
    }

    override fun onInterrupt() {}
}
