import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

abstract final class WEAAppTheme {
  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: WEAColors.accent,
      onPrimary: Colors.white,
      secondary: WEAColors.navy,
      onSecondary: Colors.white,
      surface: WEAColors.background,
      onSurface: WEAColors.primaryText,
      error: WEAColors.error,
      onError: Colors.white,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      borderSide: const BorderSide(color: WEAColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: WEAColors.background,
      textTheme: WEATypography.textTheme(),
      dividerColor: WEAColors.border,
      dividerTheme: const DividerThemeData(
        color: WEAColors.border,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: WEAColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WEAInsets.radius),
          side: const BorderSide(color: WEAColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WEAColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WEAColors.accent,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: WEAColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: WEAColors.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WEAColors.surface,
        labelStyle: const TextStyle(color: WEAColors.secondaryText),
        hintStyle: const TextStyle(color: WEAColors.mutedText),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: WEAColors.accent, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: WEAColors.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WEAColors.elevated,
        side: const BorderSide(color: WEAColors.border),
        labelStyle: const TextStyle(color: WEAColors.secondaryText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WEAColors.accent,
        linearTrackColor: WEAColors.elevated,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: WEAColors.navy,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: WEAColors.offWhite),
      ),
    );
  }
}
