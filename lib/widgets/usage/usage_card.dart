import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared chrome for cards: a clean, Apple-like surface with a 1px hairline
/// border, generous rounding and a soft, low-contrast shadow. Both the per-app
/// rows and the charts use it so they read as one family.
class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        boxShadow: [
          // Two layers for a soft, lifted elevation (no border).
          BoxShadow(
            color: colors.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: colors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}
