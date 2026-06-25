import 'package:flutter/material.dart';

import '../models/app_usage_info.dart';
import '../models/day_usage.dart';
import '../services/usage/source.dart';
import '../theme/app_colors.dart';
import '../utils/duration_format.dart';
import '../utils/weekly_totals.dart';
import '../widgets/app_background.dart';
import '../widgets/usage/app_limit_card.dart';
import '../widgets/usage/daily_usage_chart.dart';
import '../widgets/usage/usage_card.dart';

/// Shows a single app's foreground usage per day over the last 7 days, styled
/// to match the rest of the app (background gradient, elevated cards, chart).
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
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(app: widget.app),
              Expanded(
                child: FutureBuilder<List<DayUsage>>(
                  future: _weeklyTotalsFuture,
                  builder: (context, snapshot) {
                    final days = snapshot.data;
                    if (days == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final total = days.fold<Duration>(
                      Duration.zero,
                      (sum, day) => sum + day.duration,
                    );
                    final average = Duration(
                      milliseconds: days.isEmpty
                          ? 0
                          : total.inMilliseconds ~/ days.length,
                    );
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _ChartCard(days: days),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                label: 'Total',
                                value: formatDuration(total),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatTile(
                                label: 'Moyenne / jour',
                                value: formatDuration(average),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppLimitCard(packageName: widget.app.packageName),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top bar: a round back button, the app icon and its name.
class _Header extends StatelessWidget {
  const _Header({required this.app});

  final AppUsageInfo app;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 20, 14),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: app.icon != null
                ? Image.memory(
                    app.icon!,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  )
                : Icon(Icons.apps_rounded, size: 22, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: colors.accent, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.days});

  final List<DayUsage> days;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return UsageCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('7 derniers jours', style: textTheme.titleMedium),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: DailyUsageChart(
              days: days,
              selectedOffset: null,
              onSelect: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;
    return UsageCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(color: colors.accent),
          ),
        ],
      ),
    );
  }
}
