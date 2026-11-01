import 'package:flutter/material.dart';

/// Determinate progress bar with an explicit track color, so the unfilled part
/// can never be mistaken for progress.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
  });

  /// 0..1. Values outside the range (or not a number) are clamped.
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(safe * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: safe,
          minHeight: height,
          color: color ?? scheme.primary,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
