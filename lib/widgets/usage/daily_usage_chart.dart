import 'package:flutter/material.dart';

import '../../models/day_usage.dart';
import '../../theme/app_colors.dart';
import '../../utils/duration_format.dart';
import '../../utils/weekday_labels.dart';

/// A clean, professional bar chart: one bar per day sitting in a faint
/// full-height track, with the value above and the weekday below.
///
/// Tapping a bar reports that day's offset via [onSelect]. The selected day is
/// emphasized with the accent color; the rest stay muted.
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

  static const _trackHeight = 92.0;
  static const _barWidth = 26.0;
  static const _barRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    final maxMs = days.fold<int>(
      0,
      (max, d) =>
          d.duration.inMilliseconds > max ? d.duration.inMilliseconds : max,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(day.offset),
              child: _DayColumn(
                day: day,
                isSelected: day.offset == selectedOffset,
                fillFraction: maxMs == 0
                    ? 0
                    : day.duration.inMilliseconds / maxMs,
                trackHeight: _trackHeight,
                barWidth: _barWidth,
                colors: colors,
                textTheme: textTheme,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.isSelected,
    required this.fillFraction,
    required this.trackHeight,
    required this.barWidth,
    required this.colors,
    required this.textTheme,
  });

  final DayUsage day;
  final bool isSelected;
  final double fillFraction;
  final double trackHeight;
  final double barWidth;
  final AppColors colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Keep a minimum visible nub even for tiny (but non-zero) usage.
    final filled = day.duration > Duration.zero
        ? (fillFraction * trackHeight).clamp(6.0, trackHeight)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day.duration > Duration.zero ? formatDuration(day.duration) : '',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: textTheme.labelSmall?.copyWith(
            color: isSelected ? colors.accent : colors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        // Filled bar sitting on a shared baseline (no track).
        SizedBox(
          height: trackHeight,
          width: barWidth,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: filled,
              width: barWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DailyUsageChart._barRadius),
                color: isSelected ? colors.chartBarSelected : colors.chartBar,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day.offset == 0 ? 'Auj.' : weekdayShortLabels[day.day.weekday - 1],
          style: textTheme.labelSmall?.copyWith(
            color: isSelected ? colors.accent : colors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
