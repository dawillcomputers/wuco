import 'package:flutter/material.dart';

/// WEA palette, derived directly from the WUCO Executive Academy logo: a bright
/// editorial light surface carrying the logo's azure blue and deep navy.
///
/// Accents are named by role rather than hue so the tokens stay honest if the
/// brand ever shifts again.
abstract final class WEAColors {
  // Brand — sampled from the logo artwork.
  /// Wordmark navy. Doubles as the primary type colour and dark band ground.
  static const navy = Color(0xFF0A1E3D);
  static const navyDeep = Color(0xFF071730);

  /// Globe azure. 5.1:1 on white, so it is safe for small accent type.
  static const accent = Color(0xFF1B6FC4);
  static const accentBright = Color(0xFF2E8AE6);
  static const accentDeep = Color(0xFF12508F);

  /// Accent for use on navy grounds, where [accent] is too dark to read.
  static const accentSoft = Color(0xFF8FBEEA);

  // Surfaces.
  static const background = Color(0xFFFFFFFF);
  static const secondaryBackground = Color(0xFFF4F7FB);

  /// Ground for alternating sections, drawers and quiet panels.
  static const surfaceMuted = Color(0xFFF4F7FB);
  static const surface = Color(0xFFF7F9FC);
  static const card = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFEAF0F8);
  static const border = Color(0xFFDCE4EF);
  static const gridLine = Color(0xFFCBD9EA);

  // Typography.
  static const primaryText = navy;
  static const secondaryText = Color(0xFF4A5A70);
  static const mutedText = Color(0xFF64738A);

  /// Type on navy grounds — hero overlay, stat strip, footer.
  static const offWhite = Color(0xFFF5F8FC);

  // System states, darkened for legibility on light surfaces.
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB3261E);
  static const info = accent;
}
