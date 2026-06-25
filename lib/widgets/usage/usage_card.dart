import 'package:flutter/material.dart';

/// Shared chrome for usage cards: a white background with a pronounced
/// shadow. Used for both the per-app rows and the usage charts so they read
/// as the same family of "card".
class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    return Card(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.9),
      margin: EdgeInsets.zero,
      child: content,
    );
  }
}
