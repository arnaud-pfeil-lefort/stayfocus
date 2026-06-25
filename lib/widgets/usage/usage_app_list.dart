import 'package:flutter/material.dart';

import '../../models/app_usage_info.dart';
import '../../screens/app_usage_screen.dart';
import '../../services/usage/source.dart';
import '../../utils/duration_format.dart';
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
            return const UsageMessage(
              icon: Icons.error_outline,
              text: 'Impossible de récupérer le temps d\'utilisation.',
            );
          }
          final usage = snapshot.data ?? const [];
          if (usage.isEmpty) {
            return const UsageMessage(
              icon: Icons.hourglass_empty,
              text: 'Aucune utilisation enregistrée sur cette période.',
            );
          }
          final total = usage.fold<Duration>(
            Duration.zero,
            (sum, app) => sum + app.usage,
          );
          final headerCount = header != null ? 1 : 0;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: usage.length + 1 + headerCount,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (header != null && index == 0) {
                return header!;
              }
              final localIndex = index - headerCount;
              if (localIndex == 0) {
                return ListTile(
                  title: Text(
                    'Total : ${formatDuration(total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text('${usage.length} applications utilisées'),
                );
              }
              final app = usage[localIndex - 1];
              return AppUsageCard(
                app: app,
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
}
