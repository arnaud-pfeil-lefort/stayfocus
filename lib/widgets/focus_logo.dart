import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The StayFocus brand mark, drawn as a vector so it can animate.
///
/// It's a ring with an opening at the top and a dot in the center. On appear
/// (and on tap) the ring spins one turn and overshoots slightly before settling
/// back — a small "bounce". The center dot stays put.
class FocusLogo extends StatefulWidget {
  const FocusLogo({
    super.key,
    required this.size,
    required this.color,
    this.dotColor,
    this.animateOnAppear = true,
    this.spinOnTap = true,
  });

  final double size;

  /// Color of the ring.
  final Color color;

  /// Color of the center dot; defaults to [color].
  final Color? dotColor;

  /// Whether to play the spin once when first shown.
  final bool animateOnAppear;

  /// Whether tapping replays the spin.
  final bool spinOnTap;

  @override
  State<FocusLogo> createState() => _FocusLogoState();
}

class _FocusLogoState extends State<FocusLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  // easeOutBack overshoots past the end then eases back — the "bounce".
  late final Animation<double> _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animateOnAppear) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (widget.spinOnTap) _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _spin,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          return Transform.rotate(
            angle: _turn.value * 2 * math.pi,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _FocusLogoPainter(
                ringColor: widget.color,
                dotColor: widget.dotColor ?? widget.color,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FocusLogoPainter extends CustomPainter {
  _FocusLogoPainter({required this.ringColor, required this.dotColor});

  final Color ringColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.12;
    final radius = (size.width - stroke) / 2;

    // Ring with a gap centered at the top.
    const gap = 1.15; // radians of opening
    const start = -math.pi / 2 + gap / 2; // start just past the top gap
    const sweep = 2 * math.pi - gap;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      ringPaint,
    );

    // Center dot.
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(center, size.width * 0.12, dotPaint);
  }

  @override
  bool shouldRepaint(_FocusLogoPainter old) =>
      old.ringColor != ringColor || old.dotColor != dotColor;
}
