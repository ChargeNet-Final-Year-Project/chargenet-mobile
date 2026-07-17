import 'package:flutter/material.dart';

/// Shared light appearance. Operator identity colours remain catalogue data.
abstract final class AppDesign {
  static const String fontFamily = 'Outfit';
  static const Color primary = Color(0xFF0B666B);
  static const Color primaryTint = Color(0xFFE7F2F2);
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF2F5);
  static const Color ink = Color(0xFF17232D);
  static const Color secondaryText = Color(0xFF52616B);
  static const Color border = Color(0xFFDCE3E8);
  static const Color inputBorder = Color(0xFF7D8D97);
  static const Color success = Color(0xFF166534);
  static const Color caution = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);
  static const Color offline = Color(0xFF64748B);
}
