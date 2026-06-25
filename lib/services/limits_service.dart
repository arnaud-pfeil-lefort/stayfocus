import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_limit.dart';

/// Bridges to the native Android side that actually enforces app limits:
/// [LimitsStore] persists the config, [AppLimitService] polls usage and
/// warns/blocks accordingly. See android/.../limits/LimitsPlugin.kt.
///
/// All methods are no-ops (returning empty/false) on non-Android platforms.
class LimitsService {
  static const _channel = MethodChannel('com.example.stayfocus/limits');

  bool get isSupported => Platform.isAndroid;

  /// StayFocus's own package name, so the UI can avoid offering to limit
  /// itself: the blocking overlay would steal focus from the very screen
  /// used to configure it and freeze the app.
  Future<String?> getOwnPackageName() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('getOwnPackageName');
  }

  Future<List<AppLimit>> getLimits() async {
    if (!isSupported) return const [];
    final result = await _channel.invokeMethod<List<Object?>>('getLimits');
    return (result ?? const [])
        .map((entry) => AppLimit.fromMap(entry as Map<Object?, Object?>))
        .toList();
  }

  /// Saves [limit], or removes it if it has no warning and no daily limit
  /// set. Starts or stops the native monitoring service as needed.
  Future<List<AppLimit>> setLimit(AppLimit limit) async {
    if (!isSupported) return const [];
    final result = limit.isEmpty
        ? await _channel.invokeMethod<List<Object?>>(
            'removeLimit',
            limit.packageName,
          )
        : await _channel.invokeMethod<List<Object?>>(
            'setLimit',
            limit.toMap(),
          );
    return (result ?? const [])
        .map((entry) => AppLimit.fromMap(entry as Map<Object?, Object?>))
        .toList();
  }

  Future<bool> hasOverlayPermission() async {
    if (!isSupported) return false;
    return Permission.systemAlertWindow.status.then((s) => s.isGranted);
  }

  Future<bool> requestOverlayPermission() async {
    if (!isSupported) return false;
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  Future<bool> hasNotificationPermission() async {
    if (!isSupported) return false;
    return Permission.notification.status.then((s) => s.isGranted);
  }

  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
