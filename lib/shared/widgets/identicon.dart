import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A Client's picture: a 5x5 grid, mirrored left to right, drawn from a hash
/// of the client id (ADR 0004). The id never changes, so neither does this —
/// a rename keeps the picture.
({List<bool> cells, double hue}) identicon(int clientId) {
  final h = md5.convert(utf8.encode('$clientId')).bytes;
  return (
    // Row-major; column x reads the same byte as column 4 - x.
    cells: [
      for (var y = 0; y < 5; y++)
        for (var x = 0; x < 5; x++) h[min(x, 4 - x) * 5 + y].isOdd,
    ],
    hue: h[15] * 360 / 255,
  );
}

class Identicon extends StatelessWidget {
  /// Entry rows, group headers, report labels.
  static const small = 20.0;

  /// The clients list.
  static const normal = 32.0;

  final int clientId;
  final double size;
  const Identicon(this.clientId, {super.key, this.size = normal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (:cells, :hue) = identicon(clientId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: CustomPaint(
        painter: _IdenticonPainter(
          cells,
          // Mid saturation; lighter on dark so the blocks stay readable.
          HSLColor.fromAHSL(1, hue, .5, dark ? .65 : .45).toColor(),
        ),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  final List<bool> cells;
  final Color color;
  _IdenticonPainter(this.cells, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // 5 cells plus one cell of margin each side.
    final cell = size.width / 7;
    final paint = Paint()..color = color;
    for (var i = 0; i < 25; i++) {
      if (!cells[i]) continue;
      canvas.drawRect(
        Rect.fromLTWH(cell * (i % 5 + 1), cell * (i ~/ 5 + 1), cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_IdenticonPainter old) =>
      old.color != color || !listEquals(old.cells, cells);
}
