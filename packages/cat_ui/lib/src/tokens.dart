import 'package:flutter/painting.dart';

/// The numbers the house style is made of. Every magic value that more than one
/// widget depends on lives here, so a new screen can match the existing ones
/// without archaeology.
abstract final class AppTokens {
  /// Accent shared by both brightnesses.
  // TODO: under-contrasts on latte — pending the palette pass.
  static const Color primary = Color(0xFFCEEFA7);

  /// FAB-style rounding instead of Material 3 full-stadium pills.
  /// 10, not the FAB's 16: buttons are ~40px tall vs the FAB's 56, so 10
  /// matches the FAB's corner-to-height proportion (16 would still read as a pill).
  static const double radius = 10;

  /// 18, not the stock 24: the hit area stays 40px, so a smaller glyph buys
  /// breathing room around hover-revealed row actions. The nav rail passes
  /// iconSize directly and keeps its own 20.
  static const double iconSize = 18;

  /// Matches Material's InkHighlight fade, so rows driving their own highlight
  /// look identical to any that rely on the stock ink overlay.
  static const Duration hoverFade = Duration(milliseconds: 200);

  /// Material's own disabled opacity.
  static const double disabledAlpha = 0.38;

  /// Hover ripple tint strength for [intentHoverStyle].
  static const double hoverOverlayAlpha = 0.12;

  /// Identity colour dots, in the three sizes the app uses:
  /// dense rows, inline lists, dialog previews.
  static const double dotRadiusDense = 6;
  static const double dotRadius = 8;
  static const double dotRadiusLarge = 14;

  /// Single-column forms stay readable rather than stretching to the window.
  static const double formMaxWidth = 560;

  /// Pills sitting next to a 40px icon-button hover disc are forced up to 48 so
  /// they fill the tap box they already occupy instead of reading smaller.
  static const double pillMinHeight = 48;
}
