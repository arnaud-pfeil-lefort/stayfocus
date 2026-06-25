import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A single severity stage in the usage-intensity scale: the minimum daily
/// usage duration at which it kicks in, and how the warning badge/border
/// look.
class UsageStage {
  const UsageStage({
    required this.threshold,
    required this.color,
    required this.icon,
    this.glow = false,
  });

  /// Minimum usage duration for this stage to apply.
  final Duration threshold;

  /// Badge fill, card border, and (if [glow] is set) glow color.
  final Color color;

  final IconData icon;

  /// Whether the card should also get a colored glow around it, for the
  /// most severe stages.
  final bool glow;
}

/// Escalating severity stages, ordered from mildest to most severe.
///
/// This is the single place that maps a usage duration to a stage — edit the
/// thresholds, colors or icons here, nowhere else.
// Not `const`: FontAwesomeIcons.skull is a `FaIconData`, and reading its
// underlying `.data` isn't a constant expression.
final usageStages = <UsageStage>[
  const UsageStage(
    threshold: Duration(minutes: 30),
    color: Color(0xFFFFC107), // amber
    icon: Icons.priority_high,
  ),
  const UsageStage(
    threshold: Duration(hours: 1),
    color: Color(0xFFD50000), // intense red
    icon: Icons.priority_high,
    glow: true,
  ),
  UsageStage(
    threshold: const Duration(hours: 2),
    color: const Color.fromARGB(255, 87, 2, 108), // the final stage
    icon: FontAwesomeIcons.skull.data,
    glow: true,
  ),
];

/// The most severe [UsageStage] reached by [usage], or null if [usage] is
/// below the mildest stage's threshold.
UsageStage? stageForUsage(Duration usage) {
  UsageStage? reached;
  for (final stage in usageStages) {
    if (usage < stage.threshold) break;
    reached = stage;
  }
  return reached;
}
