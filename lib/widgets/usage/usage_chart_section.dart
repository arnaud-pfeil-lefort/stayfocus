import 'package:flutter/material.dart';

import '../../models/day_usage.dart';
import '../../theme/app_colors.dart';
import 'daily_usage_chart.dart';
import 'usage_card.dart';

/// Carded header for the app list: a titled panel holding the [DailyUsageChart]
/// with a control to reset to the 7-day aggregate. Placed as the first list
/// item so it scrolls away with the content.
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
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;
    final showingWeek = selectedOffset == null;

    return UsageCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Temps d\'écran', style: textTheme.titleMedium),
              const Spacer(),
              _PeriodChip(
                label: '7 derniers jours',
                active: showingWeek,
                onTap: showingWeek ? null : () => onSelect(null),
                colors: colors,
                textTheme: textTheme,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: FutureBuilder<List<DayUsage>>(
              future: dailyTotalsFuture,
              builder: (context, snapshot) {
                final days = snapshot.data;
                if (days == null) {
                  return const Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
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
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
    required this.textTheme,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final AppColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? colors.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: active ? colors.accent : colors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
