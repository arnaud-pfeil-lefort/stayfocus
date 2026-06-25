import 'package:flutter/material.dart';

import '../../models/day_usage.dart';
import '../../utils/duration_format.dart';
import '../../utils/weekday_labels.dart';

/// A row of bars, one per day, with height proportional to usage time.
///
/// Tapping a bar reports that day's offset via [onSelect].
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({
    super.key,
    required this.days,
    required this.selectedOffset,
    required this.onSelect,
  });

  /// Ordered oldest (offset 6) to newest (offset 0).
  final List<DayUsage> days;
  final int? selectedOffset;
  final ValueChanged<int> onSelect;

  static const _maxBarHeight = 78.0;
  static const _minBarHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final maxMs = days.fold<int>(
      0,
      (max, d) =>
          d.duration.inMilliseconds > max ? d.duration.inMilliseconds : max,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(day.offset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    day.duration > Duration.zero
                        ? formatDuration(day.duration)
                        : '',
                    style: textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxMs == 0
                        ? _minBarHeight
                        : (day.duration.inMilliseconds / maxMs * _maxBarHeight)
                            .clamp(_minBarHeight, _maxBarHeight),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: day.offset == selectedOffset
                          ? colorScheme.primary
                          : colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day.offset == 0
                        ? 'Auj.'
                        : weekdayShortLabels[day.day.weekday - 1],
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight:
                          day.offset == selectedOffset ? FontWeight.bold : null,
                      color: day.offset == selectedOffset
                          ? colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
