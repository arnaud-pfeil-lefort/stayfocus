import 'package:flutter/material.dart';

const _violet = Color(0xFF8B5CF6);

/// Wraps [child] with a subtle violet gradient fading in from the top and
/// bottom edges of the screen, used as the background for every screen.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _violet.withValues(alpha: 0.035),
            Colors.white,
            Colors.white,
            _violet.withValues(alpha: 0.035),
          ],
          stops: const [0.0, 0.45, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}
