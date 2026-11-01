import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One badge implementation for every piece of Pokémon metadata (types,
/// generation, Legendary/Mythical, ...).
///
/// All badges share the same minimum height, padding, radius and a forced
/// strut so a long label such as "Generation IX" can never end up taller than
/// "Normal", with or without a leading icon, at any text scale.
class MetaBadge extends StatelessWidget {
  const MetaBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dot = false,
    this.dense = false,
  });

  final String label;

  /// Accent for the border, tint and icon. Defaults to a neutral tone.
  final Color? color;
  final IconData? icon;

  /// Shows a small coloured dot instead of an icon (used for types).
  final bool dot;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;
    final fontSize = dense ? 11.0 : 12.0;
    const lineHeight = 1.25;
    final slot = dense ? 12.0 : 14.0;

    Widget? leading;
    if (dot) {
      leading = Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      );
    } else if (icon != null) {
      leading = Icon(icon, size: slot, color: tint);
    }

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: dense ? 24 : 28),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          border: Border.all(color: tint.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              SizedBox(
                width: slot,
                height: slot,
                child: Center(child: leading),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                strutStyle: StrutStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  forceStrutHeight: true,
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
