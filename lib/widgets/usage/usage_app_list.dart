import 'package:flutter/material.dart';

import '../../models/app_usage_info.dart';
import '../../screens/app_usage_screen.dart';
import '../../services/usage/source.dart';
import '../../theme/app_colors.dart';
import '../../utils/duration_format.dart';
import '../../utils/usage_stages.dart';
import 'app_usage_card.dart';
import 'usage_message.dart';

/// The scrollable list of per-app usage for the currently selected period,
/// with a pull-to-refresh affordance. Tapping an app opens its weekly chart.
///
/// [header], if given, scrolls away with the list instead of staying pinned.
class UsageAppList extends StatelessWidget {
  const UsageAppList({
    super.key,
    required this.usageFuture,
    required this.onRefresh,
    required this.source,
    this.header,
  });

  final Future<List<AppUsageInfo>>? usageFuture;
  final Future<void> Function() onRefresh;
  final UsageSource source;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<List<AppUsageInfo>>(
        future: usageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _withHeader(
              const UsageMessage(
                icon: Icons.error_outline,
                text: 'Impossible de récupérer le temps d\'utilisation.',
              ),
            );
          }
          final usage = snapshot.data ?? const [];
          if (usage.isEmpty) {
            return _withHeader(
              const UsageMessage(
                icon: Icons.hourglass_empty,
                text: 'Aucune utilisation enregistrée sur cette période.',
              ),
            );
          }
          final total = usage.fold<Duration>(
            Duration.zero,
            (sum, app) => sum + app.usage,
          );
          final headerCount = header != null ? 1 : 0;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: usage.length + 1 + headerCount,
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              if (header != null && index == 0) {
                return header!;
              }
              final localIndex = index - headerCount;
              if (localIndex == 0) {
                final theme = Theme.of(context);
                final textTheme = theme.textTheme;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${usage.length} applications',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(formatDuration(total), style: textTheme.titleMedium),
                    ],
                  ),
                );
              }
              final appIndex = localIndex - 1;
              final app = usage[appIndex];
              // PREVIEW: force the three severity stages onto the first three
              // apps so the alert effects are visible. Remove this line to use
              // only real usage thresholds.
              final forcedStage = appIndex < usageStages.length
                  ? usageStages[appIndex]
                  : null;
              return AppUsageCard(
                app: app,
                forcedStage: forcedStage,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppUsageScreen(app: app, source: source),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the empty/error state while keeping the [header] (chart + title)
  /// visible at the top. Falls back to a plain centered message when there is
  /// no header. Always scrollable so pull-to-refresh keeps working.
  Widget _withHeader(Widget message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [?header, const SizedBox(height: 48), message],
    );
  }
}
