import 'package:catui/catui.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

/// How big the dot is, by where it sits.
enum ClientDotSize {
  /// Next to a group header's title.
  small(AppTokens.dotRadiusSmall),

  /// The default: a list row's leading mark.
  normal(AppTokens.dotRadius),

  /// A row whose dot is itself the tap target, so it needs a real hit area.
  tappable(AppTokens.dotRadiusMiddle),

  /// A dialog preview of the colour being chosen.
  large(AppTokens.dotRadiusLarge);

  final double radius;
  const ClientDotSize(this.radius);
}

/// A Client's identity colour as a dot. The one coloured circle in the app:
/// every screen that marks a row, header or preview with a Client colour uses
/// this, so the sizes stay a closed set and an unparseable hex degrades to a
/// neutral grey instead of throwing mid-build.
class ClientDot extends StatelessWidget {
  /// The stored `#RRGGBB`, or null for "no client yet".
  final String? colorHex;
  final ClientDotSize size;

  /// Set only where the dot is the control, not decoration — it takes a
  /// circular ink response of its own.
  final VoidCallback? onTap;

  const ClientDot(
    this.colorHex, {
    super.key,
    this.size = ClientDotSize.normal,
    this.onTap,
  }) : _color = null;

  /// A colour already resolved (the colour picker's live preview), not a
  /// stored hex.
  const ClientDot.color(
    Color color, {
    super.key,
    this.size = ClientDotSize.normal,
    this.onTap,
  }) : colorHex = null,
       _color = color;

  final Color? _color;

  @override
  Widget build(BuildContext context) {
    final dot = CircleAvatar(
      radius: size.radius,
      backgroundColor: _color ?? hexToColor(colorHex),
    );
    if (onTap == null) return dot;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: dot,
    );
  }
}
