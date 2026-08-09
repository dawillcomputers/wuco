import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class WEATypography {
  static TextTheme textTheme() {
    final body = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    final heading = GoogleFonts.playfairDisplayTextTheme(body);
    return body.copyWith(
      displayLarge: heading.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.08,
        color: WEAColors.primaryText,
      ),
      displayMedium: heading.displayMedium?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.12,
        color: WEAColors.primaryText,
      ),
      headlineLarge: heading.headlineLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.16,
        color: WEAColors.primaryText,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: WEAColors.primaryText,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: WEAColors.primaryText,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: WEAColors.primaryText,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: WEAColors.primaryText,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.6,
        color: WEAColors.secondaryText,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: WEAColors.secondaryText,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: WEAColors.mutedText,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: .2,
      ),
    );
  }
}
