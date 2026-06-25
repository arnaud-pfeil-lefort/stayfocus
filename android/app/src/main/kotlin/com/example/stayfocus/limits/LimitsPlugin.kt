package com.example.stayfocus.limits

import android.content.Context
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
            else -> result.notImplemented()
        }
    }
}
