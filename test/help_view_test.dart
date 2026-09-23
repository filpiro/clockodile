import 'package:clockodile/features/help/help_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Help page is prose: it caps its width, so its longest shortcut
/// description has to wrap inside that cap instead of overflowing the row.
void main() {
  testWidgets('a long shortcut description wraps, at any window width', (
    tester,
  ) async {
    for (final width in [600.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ShadcnApp(home: HelpView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'at $width wide');
      expect(find.byType(KeyboardDisplay), findsNWidgets(6));
    }
  });
}
