import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clockodile/features/report/normalize.dart';
import 'package:clockodile/features/report/report_board.dart';

import 'fixtures.dart';

// The geometry is unit-tested in board_geometry_test.dart. This one widget
// test exists only for the thing that can't be: that a tile too short for its
// content clips instead of throwing an overflow error.
void main() {
  testWidgets('board renders a mixed day without overflow', (tester) async {
    final rows = normalizeDay([
      row(1, at(9, 0), at(10, 8), note: 'nota lunga che deve essere clippata'),
      row(2, at(10, 8), at(10, 9)), // collapses to zero length
      row(3, at(10, 9), at(10, 40), client: 'Globex', clientId: 2),
      row(4, at(14, 0), at(15, 30)),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReportBoard(groupByClient(rows))),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Globex'), findsOneWidget);
    // Both axis bounds are labelled — they straddle the board box and used to
    // be clipped away. 9:00 (floored start) through 16:00 (ceiled end).
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
  });
}
