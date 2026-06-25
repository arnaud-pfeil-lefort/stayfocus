import 'package:flutter/material.dart';

import '../../utils/usage_stages.dart';

/// A small pulsing badge used to flag apps with high usage.
///
/// Shows [UsageStage.icon] over [UsageStage.color]. The badge fades and
/// scales in a loop to draw the user's eye to how much time was spent.
class BlinkingWarningBadge extends StatefulWidget {
  const BlinkingWarningBadge({super.key, required this.stage});

  final UsageStage stage;

  @override
  State<BlinkingWarningBadge> createState() => _BlinkingWarningBadgeState();
}

class _BlinkingWarningBadgeState extends State<BlinkingWarningBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.15).animate(pulse),
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(pulse),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: stage.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: stage.color.withValues(alpha: 0.7),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(stage.icon, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }
}
