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

Color hexToColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
