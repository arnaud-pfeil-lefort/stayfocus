package com.example.stayfocus.limits

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Restarts the monitoring service after a reboot, so daily limits keep
/// being enforced without the user having to reopen StayFocus first.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        AppLimitService.syncRunningState(context)
    }
}
