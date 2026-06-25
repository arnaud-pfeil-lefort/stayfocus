import 'package:flutter/material.dart';

/// A small colored dot that gently pulses (scale + opacity), used to flag an
/// app whose usage has crossed a severity threshold.
class UsagePulseDot extends StatefulWidget {
  const UsagePulseDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  State<UsagePulseDot> createState() => _UsagePulseDotState();
}

class _UsagePulseDotState extends State<UsagePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.15).animate(_pulse),
      child: FadeTransition(
        opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
