import 'package:flutter/material.dart';

/// Outfit roles shared by everyday screens and the route-specific themes.
/// Sizes remain logical pixels; Flutter applies the user's text scaler.
abstract final class AppTypography {
  static const numbers = [FontFeature.tabularFigures()];
  static const pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );
  static const welcomeTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const listTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const body = TextStyle(fontSize: 14, height: 1.5);
  static const bodyLarge = TextStyle(fontSize: 16, height: 1.5);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const walletValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.6,
    fontFeatures: numbers,
  );
  static const receiptValue = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.6,
    fontFeatures: numbers,
  );
  static const chargingSoc = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -1.5,
    fontFeatures: numbers,
  );
  static const chargingPower = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w300,
    height: 1.15,
    letterSpacing: -1,
    fontFeatures: numbers,
  );
  static const chargingStat = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
    fontFeatures: numbers,
  );
  static const theme = TextTheme(
    headlineSmall: pageTitle,
    titleLarge: sectionTitle,
    titleMedium: listTitle,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
  );
}
