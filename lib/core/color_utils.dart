import 'package:chargenet_mobile/data/models.dart';
import 'package:flutter/material.dart';

/// Shown when a brand colour from the API is missing or malformed.
const Color kFallbackCpoColor = Color(0xFF64748B);

/// Either black or white meets normal-text contrast on an opaque brand swatch.
Color foregroundOnBrand(Color background) =>
    Color.alphaBlend(background, Colors.white).computeLuminance() > 0.179
    ? Colors.black
    : Colors.white;

/// Converts a brand hex token (`#0D9488` from the CPO catalogue) into a [Color].
///
/// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB` and `AARRGGBB`. Anything else
/// (empty, wrong length, non-hex characters) resolves to [fallback] instead of
/// throwing, because a bad colour must never take the map down.
Color colorFromHex(String hex, {Color fallback = kFallbackCpoColor}) {
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);

  // `#RGB` shorthand is expanded to `#RRGGBB` before the alpha is prepended.
  if (value.length == 3) {
    value = value.split('').map((digit) => '$digit$digit').join();
  }
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

/// The brand colour of the CPO behind [cpoId].
///
/// A session carries its CPO's id and name but not its colour, so the roaming
/// catalogue is the only source. An unlisted CPO — or a
/// catalogue that has not loaded yet — falls back to [kFallbackCpoColor] rather
/// than to an invisible tint.
Color cpoAccentColor(String cpoId, List<CpoPartner> cpos) {
  for (final cpo in cpos) {
    if (cpo.id == cpoId) return colorFromHex(cpo.colorHex);
  }
  return kFallbackCpoColor;
}
