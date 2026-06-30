package com.example.stayfocus.limits

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import java.util.Calendar

/// Polls which app is in the foreground, accumulates today's usage for any
/// app the user has set a limit on, fires periodic warning notifications and
/// shows a full-screen blocking overlay once the daily limit is reached.
///
/// Runs as a foreground service so it keeps working while StayFocus itself
/// isn't open; [LimitsPlugin] starts/stops it whenever limits are edited, and
/// [BootReceiver] restarts it after a reboot.
class AppLimitService : Service() {
    companion object {
        private const val CHANNEL_MONITORING = "stayfocus_monitoring"
        private const val CHANNEL_WARNINGS = "stayfocus_warnings"
        private const val NOTIF_ID_MONITORING = 1
        private const val NOTIF_ID_WARNING = 2
        // [ForegroundAppAccessibilityService] reports app switches instantly,
        // so this poll is now only a safety net for warning/limit checks
        // while the same app stays in the foreground for a while.
        private const val POLL_INTERVAL_MS = 1000L
        /// How far back to look the first time we poll, so the service knows
        /// the current foreground app immediately instead of waiting for the
        /// next app switch.
        private const val INITIAL_LOOKBACK_MS = 60_000L

        /// The currently running instance, if any, so
        /// [ForegroundAppAccessibilityService] can report foreground-app
        /// changes the instant they happen instead of waiting for this
        /// service's own poll tick.
        @Volatile private var runningInstance: AppLimitService? = null

        fun start(context: Context) {
            val intent = Intent(context, AppLimitService::class.java)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AppLimitService::class.java))
        }

        /// Starts the service if any limit is configured, stops it otherwise.
        /// Call this after every limit edit.
        fun syncRunningState(context: Context) {
            if (LimitsStore.loadLimits(context).isNotEmpty()) {
                start(context)
            } else {
                stop(context)
            }
        }

        /// Called by [ForegroundAppAccessibilityService] the instant a new
        /// window comes to the front, so the overlay can reappear (or get
        /// dismissed) without waiting for the next poll tick. A no-op if the
        /// service isn't running (no limits configured).
        ///
        /// Posted onto the service's own poller thread rather than run
        /// inline, since this is called from the accessibility service's
        /// main-thread callback and [handleForegroundChange] touches the
        /// same overlay/cache state [poll] mutates from that thread.
        fun onForegroundAppChanged(packageName: String) {
            val instance = runningInstance ?: return
            instance.handler.post { instance.handleForegroundChange(packageName) }
        }
    }

    private lateinit var handlerThread: HandlerThread
    private lateinit var handler: Handler
    private lateinit var windowManager: WindowManager

    private data class ForegroundQuery(val foreground: String?, val backgrounded: String?)

    private var lastEventQueryTime = 0L
    private var cachedForegroundPackage: String? = null

    private var overlayView: View? = null
    private var overlayPackage: String? = null
    private var overlayShownAtMs = 0L

    // When the overlay hides, remember which app was blocked and when, so that
    // poll() can re-show it if the user returns to it via recents without
    // triggering a MOVE_TO_FOREGROUND (live-tile apps like Chrome never pause,
    // so UsageStats doesn't fire MOVE_TO_FOREGROUND when tapping their recents card).
    private var lastBlockedPackage: String? = null
    private var lastBlockedHideMs = 0L
    private var cachedLauncherPackage: String? = null

    private val tick = object : Runnable {
        override fun run() {
            try {
                poll()
            } finally {
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannels()
        handlerThread = HandlerThread("AppLimitServicePoller").apply { start() }
        handler = Handler(handlerThread.looper)
        val now = System.currentTimeMillis()
        lastEventQueryTime = now - INITIAL_LOOKBACK_MS
        cachedForegroundPackage = queryForegroundEvents(lastEventQueryTime, now).foreground
        lastEventQueryTime = now
        runningInstance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildMonitoringNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                NOTIF_ID_MONITORING,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIF_ID_MONITORING, notification)
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        if (runningInstance === this) runningInstance = null
        handler.removeCallbacks(tick)
        hideOverlay()
        handlerThread.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /// Periodic safety net: re-derives the foreground app from
    /// [UsageStatsManager] (in case an accessibility event was missed) and
    /// re-evaluates it. This is also what catches a limit being crossed
    /// while the same app stays in the foreground the whole time, since
    /// that doesn't trigger a window-state-changed event.
    private fun poll() {
        if (stopIfNoLimits()) return

        val now = System.currentTimeMillis()
        val fe = queryForegroundEvents(lastEventQueryTime, now, cachedForegroundPackage)
        lastEventQueryTime = now

        when {
            fe.foreground != null -> cachedForegroundPackage = fe.foreground
            fe.backgrounded != null && overlayView == null -> {
                // The current foreground app just went to background with nothing new
                // coming up. This is the "live tile" recents case: returning to Chrome
                // (for example) from recent apps doesn't fire MOVE_TO_FOREGROUND because
                // Chrome's window was never truly paused. Re-check the last blocked app.
                val pkg = lastBlockedPackage
                if (pkg != null && now - lastBlockedHideMs < 30_000L) {
                    cachedForegroundPackage = pkg
                }
            }
        }

        evaluate(cachedForegroundPackage)
    }

    private fun isLauncherPackage(packageName: String): Boolean {
        val cached = cachedLauncherPackage
        if (cached != null) return packageName == cached
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(homeIntent, 0)?.activityInfo?.packageName
        cachedLauncherPackage = resolved
        return packageName == resolved
    }

    private fun handleForegroundChange(packageName: String) {
        if (stopIfNoLimits()) return
        // After showing an overlay, two kinds of false-positive events fire:
        // 1. Our own package (TYPE_APPLICATION_OVERLAY being added to WindowManager)
        // 2. The launcher (recent-apps-closing animation, ~50 ms after Chrome event)
        // Both would hide the overlay immediately. Ignore any event that isn't
        // the overlaid package for 1000 ms after the overlay appears.
        if (overlayPackage != null &&
            packageName != overlayPackage &&
            System.currentTimeMillis() - overlayShownAtMs < 1000L) return
        // If the user navigated to a genuinely different app (not the launcher, not
        // StayFocus itself, not the previously-blocked app), the "return from recents"
        // recovery is no longer relevant — clear it so poll() doesn't re-block.
        if (packageName != lastBlockedPackage &&
            !isLauncherPackage(packageName) &&
            packageName != this.packageName) {
            lastBlockedPackage = null
        }
        cachedForegroundPackage = packageName
        evaluate(packageName)
    }

    /// Returns true (and stops the service) if no limit is configured
    /// anymore, so callers can bail out early.
    private fun stopIfNoLimits(): Boolean {
        if (LimitsStore.loadLimits(this).isNotEmpty()) return false
        stopSelf()
        return true
    }

    private fun evaluate(foregroundPackage: String?) {
        if (foregroundPackage == packageName) {
            // When the overlay appears, Android fires TYPE_WINDOW_STATE_CHANGED
            // for our own package even with FLAG_NOT_FOCUSABLE. Ignore these
            // false-positive events for 1000 ms after the overlay was shown —
            // the user cannot navigate to StayFocus that quickly.
            if (overlayPackage != null &&
                System.currentTimeMillis() - overlayShownAtMs < 1000L) return
            if (overlayPackage != null) hideOverlay()
            return
        }
        val limit = LimitsStore.loadLimits(this).firstOrNull { it.packageName == foregroundPackage }

        if (foregroundPackage == null || limit == null) {
            if (overlayPackage != null && overlayPackage != foregroundPackage) hideOverlay()
            return
        }

        // Computed straight from UsageStatsManager (same source as the
        // in-app usage chart) rather than an internal counter: a counter
        // that only starts from zero when the service begins tracking would
        // ignore whatever the user already used today before setting the
        // limit, or while the service wasn't running.
        val totalMs = todayUsageMs(foregroundPackage)

        val dailyLimitMinutes = limit.dailyLimitMinutes
        if (dailyLimitMinutes != null && totalMs >= dailyLimitMinutes * 60_000L) {
            showOverlay(foregroundPackage)
            return
        }

        val warningIntervalMinutes = limit.warningIntervalMinutes
        if (warningIntervalMinutes != null) {
            val intervalMs = warningIntervalMinutes * 60_000L
            val multiple = (totalMs / intervalMs).toInt()
            if (multiple > 0 && multiple > LimitsStore.getWarnedMultiple(this, foregroundPackage)) {
                sendWarningNotification(foregroundPackage, multiple * warningIntervalMinutes)
                LimitsStore.setWarnedMultiple(this, foregroundPackage, multiple)
            }
        }
    }

    /// Queries UsageStats events in [fromMs, toMs).
    /// Returns:
    ///   foreground  — the latest MOVE_TO_FOREGROUND package (net of any same-window
    ///                 background), or null if the screen went off or no app came up.
    ///   backgrounded — the package that was foreground (either in this window or
    ///                  [prevForeground]) and then went to background with nothing new
    ///                  coming up. Non-null only when foreground is null. Used to detect
    ///                  the recents-live-tile case where the launcher closes without a
    ///                  new MOVE_TO_FOREGROUND (because the returning app was never paused).
    private fun queryForegroundEvents(fromMs: Long, toMs: Long, prevForeground: String? = null): ForegroundQuery {
        if (fromMs >= toMs) return ForegroundQuery(null, null)
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(fromMs, toMs)
        val event = UsageEvents.Event()
        var latestForeground: String? = null
        var lastBackgrounded: String? = null
        var screenWentOff = false
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    latestForeground = event.packageName
                    lastBackgrounded = null
                    screenWentOff = false
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    // Match the current foreground: either set in this window or
                    // carried over from the previous poll via prevForeground.
                    val isCurrent = event.packageName == latestForeground ||
                        (latestForeground == null && event.packageName == prevForeground)
                    if (isCurrent) lastBackgrounded = event.packageName
                }
                // SCREEN_NON_INTERACTIVE (16) / DEVICE_SHUTDOWN (26): no app
                // can legitimately be in the foreground past this point.
                16, 26 -> {
                    latestForeground = null
                    lastBackgrounded = null
                    screenWentOff = true
                }
            }
        }
        if (screenWentOff) return ForegroundQuery(null, null)
        // If the foreground app also went to background (lastBackgrounded set and matches
        // latestForeground, or latestForeground was null and we matched prevForeground),
        // report it as backgrounded so the caller knows the launcher has closed.
        return if (lastBackgrounded != null) {
            ForegroundQuery(null, lastBackgrounded)
        } else {
            ForegroundQuery(latestForeground, null)
        }
    }

    /// Exact foreground time for [packageName] since local midnight, by
    /// replaying today's raw events — the same approach the in-app usage
    /// chart uses, so a daily limit lines up with what the user sees there.
    /// Looking back to the start of the previous day catches a session that
    /// was already open at midnight.
    private fun todayUsageMs(packageName: String): Long {
        val now = System.currentTimeMillis()
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startOfDay - 24 * 60 * 60 * 1000L, now)
        val event = UsageEvents.Event()
        var resumedAt: Long? = null
        var totalMs = 0L

        fun closeInterval(toMs: Long) {
            val openedAt = resumedAt ?: return
            val clippedFrom = maxOf(openedAt, startOfDay)
            val clippedTo = minOf(toMs, now)
            if (clippedTo > clippedFrom) totalMs += clippedTo - clippedFrom
            resumedAt = null
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (event.packageName != packageName) closeInterval(event.timeStamp)
                    if (event.packageName == packageName) resumedAt = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (event.packageName == packageName) closeInterval(event.timeStamp)
                }
                // SCREEN_NON_INTERACTIVE (16) / DEVICE_SHUTDOWN (26): no app
                // can legitimately be in the foreground past this point.
                16, 26 -> closeInterval(event.timeStamp)
            }
        }
        // Still open now (the app currently in the foreground): count up to now.
        closeInterval(now)
        return totalMs
    }

    private fun appLabel(packageName: String): String = try {
        val info = packageManager.getApplicationInfo(packageName, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (e: Exception) {
        packageName
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MONITORING,
                "Surveillance du temps d'écran",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { setShowBadge(false) },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_WARNINGS,
                "Avertissements de temps d'écran",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    private fun buildMonitoringNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_MONITORING)
            .setContentTitle("StayFocus")
            .setContentText("Surveillance des limites d'utilisation en cours")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()

    private fun sendWarningNotification(packageName: String, minutesUsed: Int) {
        val notification = NotificationCompat.Builder(this, CHANNEL_WARNINGS)
            .setContentTitle("${appLabel(packageName)} : $minutesUsed min aujourd'hui")
            .setContentText("Vous avez atteint votre seuil d'avertissement.")
            .setSmallIcon(applicationInfo.icon)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        try {
            NotificationManagerCompat.from(this).notify(NOTIF_ID_WARNING, notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted; warnings are best-effort.
        }
    }

    private fun showOverlay(packageName: String) {
        if (overlayPackage == packageName && overlayView != null) return
        hideOverlay()
        if (!Settings.canDrawOverlays(this)) return

        val view = buildBlockerView(packageName)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }

        try {
            windowManager.addView(view, params)
            overlayView = view
            overlayPackage = packageName
            overlayShownAtMs = System.currentTimeMillis()
        } catch (e: Exception) {
            // Overlay permission may have been revoked since the last check.
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        lastBlockedPackage = overlayPackage
        lastBlockedHideMs = System.currentTimeMillis()
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            // View was already detached.
        }
        overlayView = null
        overlayPackage = null
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(homeIntent)
    }

    /// dp -> px, since every size below is specified in dp for consistency
    /// across screen densities.
    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun buildBlockerView(packageName: String): View {
        val context = this
        val appName = appLabel(packageName)
        val accent = Color.parseColor("#E53935")

        val icon = TextView(context).apply {
            text = "✋"
            textSize = 52f
            gravity = Gravity.CENTER
        }
        val title = TextView(context).apply {
            text = "STOP."
            setTextColor(accent)
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, dp(8))
        }
        val subtitle = TextView(context).apply {
            text = "Tu as cramé ta limite sur $appName. Repose ce téléphone, " +
                "lève-toi et va faire un truc qui compte — ta vie ne se vit " +
                "pas en scrollant."
            setTextColor(Color.parseColor("#E6E6E6"))
            textSize = 15f
            gravity = Gravity.CENTER
            maxWidth = dp(280)
            setLineSpacing(dp(2).toFloat(), 1f)
            setPadding(0, 0, 0, dp(24))
        }
        val homeButton = Button(context).apply {
            text = "Bouge-toi"
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setAllCaps(false)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setColor(accent)
            }
            setPadding(dp(28), dp(12), dp(28), dp(12))
            setOnClickListener { goHome() }
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(36), dp(32), dp(32))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(28).toFloat()
                setColor(Color.parseColor("#1C1B29"))
                setStroke(dp(1), Color.parseColor("#33FFFFFF"))
            }
            elevation = dp(12).toFloat()
            addView(icon)
            addView(title)
            addView(subtitle)
            addView(homeButton)
        }

        return FrameLayout(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#1A1430"), Color.parseColor("#05050A")),
            )
            addView(
                card,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
        }
    }
}
