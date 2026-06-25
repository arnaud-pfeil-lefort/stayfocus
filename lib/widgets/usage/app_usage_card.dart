import 'package:flutter/material.dart';

import '../../models/app_usage_info.dart';
import '../../utils/duration_format.dart';
import '../../utils/usage_stages.dart';
import 'blinking_warning_badge.dart';
import 'usage_card.dart';

const _cardRadius = BorderRadius.all(Radius.circular(12));

/// A single app's usage row, shown as a shadowed [Card].
///
/// When usage is high enough, the most severe stages get a matching glow
/// around the card, plus a pulsing warning badge over the top-right corner.
class AppUsageCard extends StatelessWidget {
  const AppUsageCard({super.key, required this.app, required this.onTap});

  final AppUsageInfo app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = stageForUsage(app.usage);

    Widget card = UsageCard(
      child: ListTile(
        leading: app.icon != null
            ? Image.memory(app.icon!, width: 40, height: 40)
            : const Icon(Icons.apps, size: 40),
        title: Text(app.appName),
        trailing: Text(formatDuration(app.usage)),
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
          top: -8,
          right: -8,
          child: BlinkingWarningBadge(stage: stage),
        ),
      ],
    );
  }
}
