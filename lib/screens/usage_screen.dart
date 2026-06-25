import 'package:flutter/material.dart';

import '../models/app_usage_info.dart';
import '../models/day_usage.dart';
import '../services/platform.dart';
import '../services/usage/source.dart';
import '../utils/day_range.dart';
import '../utils/weekly_totals.dart';
import '../widgets/app_background.dart';
import '../widgets/usage/usage_app_list.dart';
import '../widgets/usage/usage_chart_section.dart';
import '../widgets/usage/usage_message.dart';

/// Shows the apps used over the last 7 days, sorted by usage time.
///
/// Reading usage stats requires a special permission the user grants from
/// system settings, so this screen has three states: unsupported platform,
/// permission not yet granted, and the actual usage list.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen>
    with WidgetsBindingObserver {
  static const _lookback = Duration(days: 7);

  final UsageSource _source = createUsageSource();

  PermissionStatus? _permissionStatus;
  Future<List<AppUsageInfo>>? _usageFuture;
  Future<List<DayUsage>>? _dailyTotalsFuture;

  /// Days ago (0 = today) for the selected day, or null for "7 derniers jours".
  int? _selectedDayOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission can only be granted from system settings, so re-check
    // it whenever the user comes back to the app.
    if (state == AppLifecycleState.resumed) {
      _refreshPermission();
    }
  }

  Future<void> _refreshPermission() async {
    final status = await _source.checkPermission();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      if (status == PermissionStatus.granted) {
        _usageFuture = _loadUsage();
        _dailyTotalsFuture = _loadDailyTotals();
      }
    });
  }

  Future<List<AppUsageInfo>> _loadUsage() {
    final offset = _selectedDayOffset;
    if (offset == null) {
      final now = DateTime.now();
      return _source.getUsage(start: now.subtract(_lookback), end: now);
    }
    final range = dayRange(offset);
    return _source.getUsage(start: range.start, end: range.end);
  }

  Future<List<DayUsage>> _loadDailyTotals() => loadWeeklyTotals(
        (start, end) => _source.getTotalUsage(start: start, end: end),
      );

  Future<void> _refreshUsage() async {
    final usageFuture = _loadUsage();
    final dailyFuture = _loadDailyTotals();
    setState(() {
      _usageFuture = usageFuture;
      _dailyTotalsFuture = dailyFuture;
    });
    await Future.wait([usageFuture, dailyFuture]);
  }

  void _selectPeriod(int? dayOffset) {
    setState(() {
      _selectedDayOffset = dayOffset;
      _usageFuture = _loadUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(child: SafeArea(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    final status = _permissionStatus;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_source.isSupported) {
      return const UsageMessage(
        icon: Icons.info_outline,
        text: 'Le suivi du temps d\'utilisation n\'est pas encore '
            'disponible sur cette plateforme.',
      );
    }
    if (status == PermissionStatus.denied) {
      return UsageMessage(
        icon: Icons.lock_outline,
        text: 'StayFocus a besoin de l\'accès aux statistiques '
            'd\'utilisation pour afficher le temps passé sur chaque '
            'application.',
        action: FilledButton(
          onPressed: _source.requestPermission,
          child: const Text('Autoriser l\'accès'),
        ),
      );
    }
    return UsageAppList(
      usageFuture: _usageFuture,
      onRefresh: _refreshUsage,
      source: _source,
      header: UsageChartSection(
        dailyTotalsFuture: _dailyTotalsFuture,
        selectedOffset: _selectedDayOffset,
        onSelect: _selectPeriod,
      ),
    );
  }
}
