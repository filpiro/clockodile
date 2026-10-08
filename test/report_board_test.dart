import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:clockodile/features/report/normalize.dart';
import 'package:clockodile/features/report/report_board.dart';
import 'package:clockodile/shared/widgets/identicon.dart';

import 'fixtures.dart';

// The geometry is unit-tested in board_geometry_test.dart. These widget tests
// cover what can't be: that a tile too short for its content clips instead of
// throwing an overflow error, and that hovering a tile shows its tooltip.
void main() {
  final rows = normalizeDay([
    row(1, at(9, 0), at(10, 8), note: 'nota lunga che deve essere clippata'),
    row(2, at(10, 8), at(10, 9)), // collapses to zero length
    row(3, at(10, 9), at(10, 40), client: 'Globex', clientId: 2),
    row(4, at(14, 0), at(15, 30)),
  ]);

  Future<void> pumpBoard(WidgetTester tester) => tester.pumpWidget(
    ShadcnApp(home: Scaffold(child: ReportBoard(groupByClient(rows)))),
  );

  testWidgets('board renders a mixed day without overflow', (tester) async {
    await pumpBoard(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Globex'), findsOneWidget);
    // Every labelled tile carries its client's identicon; the zero-length
    // hairline has no label.
    expect(find.byType(Identicon), findsNWidgets(3));
    // Both axis bounds are labelled — they straddle the board box and used to
    // be clipped away. 9:00 (floored start) through 16:00 (ceiled end).
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
  });

  testWidgets('hovering a tile shows its tooltip', (tester) async {
    await pumpBoard(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Globex')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('reale 10:09–10:40'), findsOneWidget);
  });
}
