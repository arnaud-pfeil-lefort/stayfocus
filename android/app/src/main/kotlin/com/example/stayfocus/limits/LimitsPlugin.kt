package com.example.stayfocus.limits

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/// Bridges the Dart side to [LimitsStore]/[AppLimitService]: reading and
/// writing limit config is the only thing Flutter needs to do natively,
/// everything else (polling, notifications, blocking) runs in the service.
class LimitsPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.stayfocus/limits")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getLimits" -> {
                result.success(LimitsStore.loadLimits(context).map { it.toMap() })
            }
            "getOwnPackageName" -> {
                result.success(context.packageName)
            }
            "setLimit" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("invalid_args", "Expected a map", null)
                    return
                }
                val updated = LimitsStore.upsert(context, AppLimit.fromMap(args))
                AppLimitService.syncRunningState(context)
                result.success(updated.map { it.toMap() })
            }
            "removeLimit" -> {
                val packageName = call.arguments as? String
                if (packageName == null) {
                    result.error("invalid_args", "Expected a package name string", null)
                    return
                }
                val updated = LimitsStore.remove(context, packageName)
                AppLimitService.syncRunningState(context)
                result.success(updated.map { it.toMap() })
            }
            "hasAccessibilityPermission" -> {
                result.success(isAccessibilityServiceEnabled(context))
            }
            "openAccessibilitySettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /// Accessibility services have no runtime-permission dialog — the user
    /// must flip them on manually in Settings > Accessibility — so this is
    /// the only way to know whether ours is enabled: read the system list of
    /// enabled services and look for our component in it.
    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expected = ComponentName(context, ForegroundAppAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (ComponentName.unflattenFromString(splitter.next()) == expected) return true
        }
        return false
    }
}
