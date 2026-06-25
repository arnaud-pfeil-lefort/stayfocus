package com.example.stayfocus.limits

import org.json.JSONArray
import org.json.JSONObject

/// Per-package limit configuration set by the user from the Flutter UI.
///
/// Either field may be absent (null = disabled): a package can have only a
/// warning, only a daily block, both, or neither (in which case it shouldn't
/// be stored at all).
data class AppLimit(
    val packageName: String,
    val warningIntervalMinutes: Int?,
    val dailyLimitMinutes: Int?,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("packageName", packageName)
        put("warningIntervalMinutes", warningIntervalMinutes ?: JSONObject.NULL)
        put("dailyLimitMinutes", dailyLimitMinutes ?: JSONObject.NULL)
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "packageName" to packageName,
        "warningIntervalMinutes" to warningIntervalMinutes,
        "dailyLimitMinutes" to dailyLimitMinutes,
    )

    companion object {
        fun fromJson(json: JSONObject): AppLimit = AppLimit(
            packageName = json.getString("packageName"),
            warningIntervalMinutes = json.optIntOrNull("warningIntervalMinutes"),
            dailyLimitMinutes = json.optIntOrNull("dailyLimitMinutes"),
        )

        fun fromMap(map: Map<*, *>): AppLimit = AppLimit(
            packageName = map["packageName"] as String,
            warningIntervalMinutes = (map["warningIntervalMinutes"] as? Number)?.toInt(),
            dailyLimitMinutes = (map["dailyLimitMinutes"] as? Number)?.toInt(),
        )

        fun listToJson(limits: List<AppLimit>): String {
            val array = JSONArray()
            limits.forEach { array.put(it.toJson()) }
            return array.toString()
        }

        fun listFromJson(json: String?): List<AppLimit> {
            if (json == null) return emptyList()
            val array = JSONArray(json)
            return (0 until array.length()).map { fromJson(array.getJSONObject(it)) }
        }
    }
}

private fun JSONObject.optIntOrNull(name: String): Int? =
    if (isNull(name) || !has(name)) null else getInt(name)
