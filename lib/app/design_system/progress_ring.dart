import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular progress indicator with an optional centre label.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    this.size = 84,
    this.strokeWidth = 8,
    this.label,
    this.semanticsLabel,
  });

  final double fraction;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            stroke: strokeWidth,
            color: scheme.primary,
            track: scheme.surfaceContainerHigh,
          ),
          child: Center(
            child: label == null
                ? null
                : Text(
                    label!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double fraction;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.stroke != stroke ||
      old.color != color ||
      old.track != track;
}
