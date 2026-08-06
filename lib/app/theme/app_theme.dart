import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

abstract final class WEAAppTheme {
  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      primary: WEAColors.gold,
      onPrimary: WEAColors.background,
      secondary: WEAColors.brightGold,
      onSecondary: WEAColors.background,
      surface: WEAColors.surface,
      onSurface: WEAColors.primaryText,
      error: WEAColors.error,
      onError: WEAColors.primaryText,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      borderSide: const BorderSide(color: WEAColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: WEAColors.background,
      textTheme: WEATypography.textTheme(),
      dividerColor: WEAColors.border,
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
          backgroundColor: WEAColors.gold,
          foregroundColor: WEAColors.background,
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
          foregroundColor: WEAColors.brightGold,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: WEAColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WEAColors.surface,
        labelStyle: const TextStyle(color: WEAColors.secondaryText),
        hintStyle: const TextStyle(color: WEAColors.mutedText),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: WEAColors.gold, width: 1.5),
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
        color: WEAColors.gold,
        linearTrackColor: WEAColors.elevated,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: WEAColors.elevated,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: WEAColors.primaryText),
      ),
    );
  }
}
