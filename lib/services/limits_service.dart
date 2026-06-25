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

  /// Whether the user has enabled StayFocus's accessibility service, which
  /// is what lets the blocking overlay reappear instantly when switching
  /// back to a blocked app instead of waiting on the next usage-stats poll.
  ///
  /// Unlike the permissions above, this isn't a [Permission] from
  /// permission_handler: accessibility services have no runtime-permission
  /// dialog, so it's checked and toggled on the native side directly (see
  /// LimitsPlugin.kt).
  Future<bool> hasAccessibilityPermission() async {
    if (!isSupported) return false;
    final result = await _channel.invokeMethod<bool>(
      'hasAccessibilityPermission',
    );
    return result ?? false;
  }

  /// Opens Settings > Accessibility, where the user must enable StayFocus
  /// manually — there's no dialog that can grant this directly.
  Future<void> openAccessibilitySettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }
}
