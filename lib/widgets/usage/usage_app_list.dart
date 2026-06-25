import 'package:flutter/material.dart';

import '../../models/app_usage_info.dart';
import '../../utils/duration_format.dart';
import 'usage_message.dart';

/// The scrollable list of per-app usage for the currently selected period,
/// with a pull-to-refresh affordance.
class UsageAppList extends StatelessWidget {
  const UsageAppList({
    super.key,
    required this.usageFuture,
    required this.onRefresh,
  });

  final Future<List<AppUsageInfo>>? usageFuture;
  final Future<void> Function() onRefresh;

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
          return ListView.separated(
            itemCount: usage.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    'Total : ${formatDuration(total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text('${usage.length} applications utilisées'),
                );
              }
              final app = usage[index - 1];
              return ListTile(
                leading: app.icon != null
                    ? Image.memory(app.icon!, width: 40, height: 40)
                    : const Icon(Icons.apps, size: 40),
                title: Text(app.appName),
                subtitle: Text(app.packageName),
                trailing: Text(formatDuration(app.usage)),
              );
            },
          );
        },
      ),
    );
  }
}
