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

    private var lastEventQueryTime = 0L
    private var cachedForegroundPackage: String? = null

    private var overlayView: View? = null
    private var overlayPackage: String? = null
    private var overlayShownAtMs = 0L

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
        cachedForegroundPackage = queryLatestForegroundPackage(lastEventQueryTime, now)
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
        val latestForeground = queryLatestForegroundPackage(lastEventQueryTime, now)
        if (latestForeground != null) cachedForegroundPackage = latestForeground
        lastEventQueryTime = now

        evaluate(cachedForegroundPackage)
    }

    /// Called by [ForegroundAppAccessibilityService] the instant a new
    /// window comes to the front. Only acts on monitored apps and StayFocus
    /// itself; system UI, IME, and unmonitored apps are intentionally ignored
    /// so that transient overlays (status bar, notification shade, etc.) don't
    /// cause the blocker to disappear. The poll recovers the real foreground
    /// app via UsageStats within 1 s whenever the user actually navigates away.
    private fun handleForegroundChange(packageName: String) {
        if (stopIfNoLimits()) return
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

    /// Returns the package name of the most recently resumed app within
    /// [fromMs, toMs), or null if the screen turned off in that window (no
    /// app can legitimately be "in foreground" past that point) or no
    /// transition happened.
    private fun queryLatestForegroundPackage(fromMs: Long, toMs: Long): String? {
        if (fromMs >= toMs) return null
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(fromMs, toMs)
        val event = UsageEvents.Event()
        var latestForeground: String? = null
        var screenWentOff = false
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    latestForeground = event.packageName
                    screenWentOff = false
                }
                // SCREEN_NON_INTERACTIVE (16) / DEVICE_SHUTDOWN (26): no app
                // can legitimately be in the foreground past this point.
                16, 26 -> {
                    latestForeground = null
                    screenWentOff = true
                }
            }
        }
        return if (screenWentOff) null else latestForeground
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
