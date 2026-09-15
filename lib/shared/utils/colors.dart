import 'dart:math';

import 'package:flutter/painting.dart';

/// Random hue, fixed saturation/lightness for guaranteed readability (spec 4.1).
String randomClientColorHex({Random? random}) {
  final hue = (random ?? Random()).nextDouble() * 360;
  return colorToHex(hslToColor(hue));
}

Color hslToColor(
  double hue, {
  double saturation = 0.65,
  double lightness = 0.55,
}) => HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();

String colorToHex(Color color) {
  String c(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${c(color.r)}${c(color.g)}${c(color.b)}'.toUpperCase();
}

/// Neutral stand-in for a colour that isn't a `#RRGGBB` we can read — a client
/// still being typed in the autocomplete, or a row whose stored hex predates
/// the format. A grey dot beats a crash in the middle of a list build.
const unknownClientColor = Color(0xFF888888);

Color hexToColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
    return unknownClientColor;
  }
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? unknownClientColor : Color(0xFF000000 | value);
}
