import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Wraps [child] with a very subtle vertical gradient: a faint violet/blue
/// wash at the top and bottom edges fading into a clean center.
///
/// The exact colors come from the active [AppColors] palette, so it adapts to
/// light and dark themes automatically.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.gradientTop,
            colors.gradientCenter,
            colors.gradientCenter,
            colors.gradientBottom,
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ),
      ),
      child: child,
    );
  }
}
