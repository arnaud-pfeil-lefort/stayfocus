import 'package:flutter/material.dart';

import '../models/app_usage_info.dart';
import '../models/day_usage.dart';
import '../services/usage/source.dart';
import '../utils/duration_format.dart';
import '../utils/weekly_totals.dart';
import '../widgets/app_background.dart';
import '../widgets/usage/app_limit_card.dart';
import '../widgets/usage/daily_usage_chart.dart';
import '../widgets/usage/usage_card.dart';

/// Shows a single app's foreground usage per day over the last 7 days.
class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({super.key, required this.app, required this.source});

  final AppUsageInfo app;
  final UsageSource source;

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  late final Future<List<DayUsage>> _weeklyTotalsFuture = loadWeeklyTotals(
    (start, end) => widget.source.getPackageUsage(
      packageName: widget.app.packageName,
      start: start,
      end: end,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            app.icon != null
                ? Image.memory(app.icon!, width: 28, height: 28)
                : const Icon(Icons.apps, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(app.appName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<DayUsage>>(
                  future: _weeklyTotalsFuture,
                  builder: (context, snapshot) {
                    final days = snapshot.data;
                    if (days == null) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final total = days.fold<Duration>(
                      Duration.zero,
                      (sum, day) => sum + day.duration,
                    );
                    return UsageCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 150,
                            child: DailyUsageChart(
                              days: days,
                              selectedOffset: null,
                              onSelect: (_) {},
                            ),
                          ),
                          const Divider(height: 32),
                          Text(
                            'Total : ${formatDuration(total)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AppLimitCard(packageName: app.packageName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
