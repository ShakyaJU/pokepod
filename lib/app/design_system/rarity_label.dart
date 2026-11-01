import 'package:flutter/material.dart';

import '../../domain/achievements.dart';
import '../theme/app_theme.dart';
import '../theme/rarity.dart';

/// The rarity caption used on achievement cards and detail sheets.
///
/// The eight ordinary tiers keep their flat, readable [RarityStyle.labelColor]
/// exactly as before. Hyper Rare — the top tier — is painted with the
/// metallic-gold sheen from [rarityGradient], which is what separates it from
/// plain Rare gold at a glance while staying legible on light and dark
/// surfaces. The underlying string never changes, so semantics, selection and
/// tests still see "Hyper Rare".
class RarityLabel extends StatelessWidget {
  const RarityLabel({
    super.key,
    required this.rarity,
    this.size = 11,
    this.uppercase = false,
  });

  final AchievementRarity rarity;

  /// Font size of the caption (the cards use a smaller readout than the
  /// detail sheet).
  final double size;

  /// Whether to render the tier name in capitals, as the cards do.
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final label = uppercase ? rarity.label.toUpperCase() : rarity.label;
    final gradient = rarityGradient(rarity, Theme.of(context).brightness);
    if (gradient == null) {
      return Text(
        label,
        style: readoutStyle(
          context,
          size: size,
          color: rarityStyle(context, rarity).labelColor,
        ),
      );
    }
    // Paint the word with the metallic ramp instead of a single colour: the
    // white text acts as a mask, so the glyphs carry deep gold through
    // champagne while their shape and metrics stay identical.
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        label,
        style: readoutStyle(
          context,
          size: size,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}
