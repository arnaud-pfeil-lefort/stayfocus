import 'package:flutter/material.dart';

import '../../models/ios_app_limit_group.dart';
import '../../utils/duration_format.dart';
import '../../utils/usage_stages.dart';
import 'usage_card.dart';
import 'usage_pulse_dot.dart';

const _cardRadius = BorderRadius.all(Radius.circular(12));

/// A single limit group's row — the iOS equivalent of [AppUsageCard], except
/// there's no app icon/name to show: a group can bundle several apps and
/// iOS never reveals which, so the user-typed nickname stands in for both.
class IosLimitGroupCard extends StatelessWidget {
  const IosLimitGroupCard({
    super.key,
    required this.group,
    required this.usageMs,
    required this.onTap,
  });

  final IosAppLimitGroup group;
  final int usageMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final usage = Duration(milliseconds: usageMs);
    final stage = stageForUsage(usage);

    Widget card = UsageCard(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.apps)),
        title: Text(group.nickname),
        subtitle: group.hasSelection ? null : const Text('Aucune appli choisie'),
        trailing: Text(formatDuration(usage)),
        onTap: onTap,
      ),
    );

    if (stage != null && stage.glow) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: _cardRadius,
          boxShadow: [
            BoxShadow(
              color: stage.color.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: card,
      );
    }

    if (stage == null) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -4,
          right: -4,
          child: UsagePulseDot(color: stage.color, size: 16),
        ),
      ],
    );
  }
}
