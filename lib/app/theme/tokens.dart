import 'package:flutter/material.dart';

/// Design tokens for PokéPod: colour, spacing, radii and motion.
class AppColors {
  const AppColors._();

  // Dark surfaces: obsidian + layered charcoal.
  static const obsidian = Color(0xFF0A0E12);
  static const surface1 = Color(0xFF10161C);
  static const surface2 = Color(0xFF161E26);
  static const surface3 = Color(0xFF1E2833);
  static const line = Color(0xFF2A3541);

  // Light surfaces.
  static const paper = Color(0xFFF2F6F7);
  static const paper1 = Color(0xFFFFFFFF);
  static const paper2 = Color(0xFFE9EFF1);
  static const paper3 = Color(0xFFDCE5E8);
  static const paperLine = Color(0xFFC6D2D6);

  // Brand accents.
  static const emerald = Color(0xFF2DD4A0);
  static const cyan = Color(0xFF5EEAF2);
  static const amber = Color(0xFFF5B642);
  static const violet = Color(0xFFA78BFA);
  static const rose = Color(0xFFF472B6);
  static const danger = Color(0xFFF87171);

  static const text = Color(0xFFE8EEF2);
  static const textDim = Color(0xFF8A97A3);
  static const inkLight = Color(0xFF0E1A21);
  static const inkLightDim = Color(0xFF52616B);
}

const List<Color> kAccents = [
  AppColors.emerald,
  AppColors.cyan,
  AppColors.amber,
  AppColors.violet,
  AppColors.rose,
];

const List<String> kAccentNames = [
  'Emerald',
  'Cyan',
  'Amber',
  'Violet',
  'Rose',
];

class Space {
  const Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Radii {
  const Radii._();
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 20;
}

class Motion {
  const Motion._();
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 700);
  static const Curve curve = Curves.easeOutCubic;
}

const Map<String, Color> kTypeColors = {
  'normal': Color(0xFFA8A77A),
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'electric': Color(0xFFF7D02C),
  'grass': Color(0xFF7AC74C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
};

Color typeColor(String type) => kTypeColors[type] ?? AppColors.textDim;
