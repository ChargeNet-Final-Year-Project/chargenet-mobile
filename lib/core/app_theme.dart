import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/constants.dart';

/// One light Material foundation for account, charging, and receipt routes.
abstract final class AppTheme {
  static const systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppDesign.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppDesign.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppDesign.primary,
        onPrimary: AppDesign.surface,
        primaryContainer: AppDesign.primaryTint,
        onPrimaryContainer: AppDesign.primary,
        secondary: AppDesign.primary,
        onSecondary: AppDesign.surface,
        secondaryContainer: AppDesign.primaryTint,
        onSecondaryContainer: AppDesign.primary,
        surface: AppDesign.surface,
        onSurface: AppDesign.ink,
        onSurfaceVariant: AppDesign.secondaryText,
        surfaceContainerLowest: AppDesign.surface,
        surfaceContainerLow: AppDesign.background,
        surfaceContainer: AppDesign.surfaceMuted,
        surfaceContainerHigh: AppDesign.surfaceMuted,
        surfaceContainerHighest: AppDesign.surfaceMuted,
        surfaceTint: Colors.transparent,
        outline: AppDesign.inputBorder,
        outlineVariant: AppDesign.border,
        error: AppDesign.danger,
        onError: AppDesign.surface,
      );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppDesign.fontFamily,
    textTheme: AppTypography.theme.apply(
      bodyColor: AppDesign.ink,
      displayColor: AppDesign.ink,
    ),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppDesign.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppDesign.surface,
      foregroundColor: AppDesign.ink,
      surfaceTintColor: Colors.transparent,
      // Let AppBar derive status-icon contrast from its actual background,
      // including the scanner's black camera chrome.
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelPadding: const EdgeInsets.only(top: 0, bottom: 2),
      indicatorColor: Colors.transparent,
      indicatorShape: const CircleBorder(),
      backgroundColor: AppDesign.surface,
      surfaceTintColor: Colors.transparent,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
          color: states.contains(WidgetState.selected)
              ? AppDesign.primary
              : AppDesign.secondaryText,
          height: 1.2,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppDesign.primary
              : AppDesign.secondaryText,
          size: 22,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppDesign.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KConstants.circularBorderRadius),
        side: const BorderSide(color: AppDesign.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppDesign.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: _inputBorder(AppDesign.inputBorder),
      enabledBorder: _inputBorder(AppDesign.inputBorder),
      focusedBorder: _inputBorder(AppDesign.primary, 1.5),
      errorBorder: _inputBorder(AppDesign.danger),
      focusedErrorBorder: _inputBorder(AppDesign.danger, 1.5),
      hintStyle: const TextStyle(color: AppDesign.secondaryText, fontSize: 14),
    ),
  );

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(KConstants.circularBorderRadius),
        borderSide: BorderSide(color: color, width: width),
      );
}
