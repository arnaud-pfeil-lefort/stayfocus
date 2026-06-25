package com.example.stayfocus.limits

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject

/// Native-side persistence for app limits and today's accumulated usage.
///
/// This is the single source of truth for limit config: both the Dart side
/// (via [LimitsPlugin]) and [AppLimitService] read/write through here, so the
/// service keeps enforcing limits even when the Flutter engine isn't running.
object LimitsStore {
    private const val PREFS_NAME = "stayfocus_limits"
    private const val KEY_LIMITS = "limits"
    private const val KEY_USAGE_DATE = "usage_date"
    private const val KEY_WARNED_MULTIPLE = "warned_multiple"

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /// Never returns a limit for StayFocus's own package: showing the
    /// blocking overlay over the activity the user is using to configure it
    /// steals window focus from itself and freezes the app (ANR). Filtering
    /// here also self-heals a limit that was mistakenly saved before this
    /// guard existed.
    fun loadLimits(context: Context): List<AppLimit> =
        AppLimit.listFromJson(prefs(context).getString(KEY_LIMITS, null))
            .filter { it.packageName != context.packageName }

    fun saveLimits(context: Context, limits: List<AppLimit>) {
        prefs(context).edit().putString(KEY_LIMITS, AppLimit.listToJson(limits)).apply()
    }

    /// Replaces (or removes, if both fields are null) the limit for
    /// [limit]'s package. Returns the updated full list.
    fun upsert(context: Context, limit: AppLimit): List<AppLimit> {
        val current = loadLimits(context).filter { it.packageName != limit.packageName }
        val isSelf = limit.packageName == context.packageName
        val updated = if (isSelf || (limit.warningIntervalMinutes == null && limit.dailyLimitMinutes == null)) {
            current
        } else {
            current + limit
        }
        saveLimits(context, updated)
        return updated
    }

    fun remove(context: Context, packageName: String): List<AppLimit> {
        val updated = loadLimits(context).filter { it.packageName != packageName }
        saveLimits(context, updated)
        return updated
    }

    /// Resets the per-day warning bookkeeping if the stored date doesn't
    /// match today (i.e. it's a new day).
    private fun ensureToday(context: Context) {
        val today = dateFormat.format(Date())
        val storedDate = prefs(context).getString(KEY_USAGE_DATE, null)
        if (storedDate != today) {
            prefs(context).edit()
                .putString(KEY_USAGE_DATE, today)
                .putString(KEY_WARNED_MULTIPLE, "{}")
                .apply()
        }
    }

    /// The highest warning multiple already notified today for [packageName]
    /// (0 if none yet), so the service doesn't repeat the same warning.
    fun getWarnedMultiple(context: Context, packageName: String): Int {
        ensureToday(context)
        val warned = JSONObject(prefs(context).getString(KEY_WARNED_MULTIPLE, "{}") ?: "{}")
        return if (warned.has(packageName)) warned.getInt(packageName) else 0
    }

    fun setWarnedMultiple(context: Context, packageName: String, multiple: Int) {
        ensureToday(context)
        val warned = JSONObject(prefs(context).getString(KEY_WARNED_MULTIPLE, "{}") ?: "{}")
        warned.put(packageName, multiple)
        prefs(context).edit().putString(KEY_WARNED_MULTIPLE, warned.toString()).apply()
    }
}
