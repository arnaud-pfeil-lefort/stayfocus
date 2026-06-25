import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' hide PermissionStatus;

import '../models/ios_app_limit_group.dart';
import 'usage/source.dart' show PermissionStatus;

/// Bridges to the native iOS side that enforces app-limit groups via
/// Apple's Screen Time stack (FamilyControls / ManagedSettings /
/// DeviceActivity). See ios/Runner/IosLimitsPlugin.swift.
///
/// Unlike [LimitsService] (Android), there is no per-package querying here:
/// iOS never reveals which apps were picked, so everything is keyed by an
/// opaque group [IosAppLimitGroup.id] the user labels with a nickname.
///
/// [getUsageMs] depends on an *unofficially documented* technique: a
/// `DeviceActivityReportExtension` writes an anonymous per-group usage total
/// into a shared App Group container, which this method reads back. Apple
/// has not published this as a supported data path — only informally
/// acknowledged it as "expected behavior" when raised as a privacy concern.
/// It could stop working in a future iOS release with no warning; treat a
/// stuck-at-zero reading as a possible sign of that, not necessarily a bug
/// in this code.
///
/// All methods are no-ops (returning empty/false/zero) on non-iOS platforms.
class IosLimitsService {
  static const _channel = MethodChannel('com.example.stayfocus/ios_limits');

  bool get isSupported => Platform.isIOS;

  Future<PermissionStatus> checkAuthorization() async {
    if (!isSupported) return PermissionStatus.unsupported;
    final granted = await _channel.invokeMethod<bool>('checkAuthorization');
    return granted == true ? PermissionStatus.granted : PermissionStatus.denied;
  }

  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    final granted = await _channel.invokeMethod<bool>('requestAuthorization');
    return granted == true;
  }

  Future<List<IosAppLimitGroup>> getGroups() async {
    if (!isSupported) return const [];
    final result = await _channel.invokeMethod<List<Object?>>('getGroups');
    return (result ?? const [])
        .map((entry) => IosAppLimitGroup.fromMap(entry as Map<Object?, Object?>))
        .toList();
  }

  /// Creates an empty group (no apps picked yet) with [nickname] and
  /// returns its generated id.
  Future<String> createGroup(String nickname) async {
    if (!isSupported) return '';
    final id = await _channel.invokeMethod<String>('createGroup', nickname);
    return id ?? '';
  }

  /// Presents the system `FamilyActivityPicker` for [groupId]. Returns
  /// whether a selection was made (never the selection itself — iOS keeps
  /// app identity opaque to our code).
  Future<bool> pickApps(String groupId) async {
    if (!isSupported) return false;
    final picked = await _channel.invokeMethod<bool>('pickApps', groupId);
    return picked == true;
  }

  /// Saves [group]'s nickname/limit minutes and re-schedules native
  /// monitoring accordingly.
  Future<List<IosAppLimitGroup>> saveGroup(IosAppLimitGroup group) async {
    if (!isSupported) return const [];
    final result = await _channel.invokeMethod<List<Object?>>(
      'saveGroup',
      group.toMap(),
    );
    return (result ?? const [])
        .map((entry) => IosAppLimitGroup.fromMap(entry as Map<Object?, Object?>))
        .toList();
  }

  Future<List<IosAppLimitGroup>> removeGroup(String id) async {
    if (!isSupported) return const [];
    final result = await _channel.invokeMethod<List<Object?>>('removeGroup', id);
    return (result ?? const [])
        .map((entry) => IosAppLimitGroup.fromMap(entry as Map<Object?, Object?>))
        .toList();
  }

  /// Today's cumulative usage for [groupId], in milliseconds, or 0 if
  /// nothing has been reported yet. See the class doc for the caveat on how
  /// this number is obtained.
  Future<int> getUsageMs(String groupId) async {
    if (!isSupported) return 0;
    final ms = await _channel.invokeMethod<int>('getUsageMs', groupId);
    return ms ?? 0;
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
