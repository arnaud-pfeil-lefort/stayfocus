import 'package:flutter/material.dart';

import '../../models/day_usage.dart';
import 'daily_usage_chart.dart';

/// Header shown above the app list: a "Temps par jour" label, a button to
/// reset to the 7-day aggregate, and the [DailyUsageChart] itself.
class UsageChartSection extends StatelessWidget {
  const UsageChartSection({
    super.key,
    required this.dailyTotalsFuture,
    required this.selectedOffset,
    required this.onSelect,
  });

  final Future<List<DayUsage>>? dailyTotalsFuture;
  final int? selectedOffset;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temps par jour',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton(
                onPressed:
                    selectedOffset == null ? null : () => onSelect(null),
                child: const Text('7 derniers jours'),
              ),
            ],
          ),
          SizedBox(
            height: 150,
            child: FutureBuilder<List<DayUsage>>(
              future: dailyTotalsFuture,
              builder: (context, snapshot) {
                final days = snapshot.data;
                if (days == null) {
                  return const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return DailyUsageChart(
                  days: days,
                  selectedOffset: selectedOffset,
                  onSelect: onSelect,
                );
              },
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
