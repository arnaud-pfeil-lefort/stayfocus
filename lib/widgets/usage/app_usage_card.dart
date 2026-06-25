import 'package:flutter/material.dart';

import '../../models/app_usage_info.dart';
import '../../theme/app_colors.dart';
import '../../utils/duration_format.dart';
import '../../utils/usage_stages.dart';
import 'usage_card.dart';
import 'usage_pulse_dot.dart';

/// A single app's usage row in a clean, Apple-like card.
///
/// Apps that cross a severity threshold get a sober but living alert: a gently
/// pulsing colored dot next to a colored duration, and — for the most severe
/// stages — a soft colored halo around the card.
class AppUsageCard extends StatelessWidget {
  const AppUsageCard({super.key, required this.app, required this.onTap});

  final AppUsageInfo app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;
    final stage = stageForUsage(app.usage);
    final durationColor = stage?.color ?? colors.textPrimary;

    Widget card = UsageCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                clipBehavior: Clip.antiAlias,
                child: app.icon != null
                    ? Image.memory(
                        app.icon!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.apps_rounded, size: 24, color: colors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  app.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              if (stage != null) ...[
                UsagePulseDot(color: stage.color),
                const SizedBox(width: 8),
              ],
              Text(
                formatDuration(app.usage),
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  color: durationColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );

    // Soft colored halo for the most severe stages.
    if (stage != null && stage.glow) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: UsageCard.radius,
          boxShadow: [
            BoxShadow(
              color: stage.color.withValues(alpha: 0.28),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: card,
      );
    }

    return card;
  }
}
