import 'package:clockodile/shared/widgets/app_list_row.dart';
import 'package:clockodile/shared/widgets/empty_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget _host(Widget child) => ShadcnApp(home: Scaffold(child: child));

/// Whether any box inside the row is painted with [color].
bool _rowPainted(WidgetTester tester, Color color) => tester
    .widgetList<OverflowDecoratedBox>(
      find.descendant(
        of: find.byType(AppListRow),
        matching: find.byType(OverflowDecoratedBox),
      ),
    )
    .any(
      (box) => switch (box.decoration) {
        BoxDecoration(color: final c) ||
        ShapeDecoration(color: final c) => c == color,
        _ => false,
      },
    );

void main() {
  testWidgets('actions are visible without hover and fire their callbacks', (
    tester,
  ) async {
    var tapped = 0, edited = 0, deleted = 0;
    await tester.pumpWidget(
      _host(
        AppListRow(
          title: const Text('Acme'),
          subtitle: const Text('3 attività'),
          onTap: () => tapped++,
          onEdit: () => edited++,
          onDelete: () => deleted++,
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();

    expect((tapped, edited, deleted), (1, 1, 1));
  });

  testWidgets('hover paints the muted fill, and only hover', (tester) async {
    // Hover highlights follow the focus highlight mode, which tests start
    // in touch mode.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await tester.pumpWidget(
      _host(AppListRow(title: const Text('Acme'), onTap: () {})),
    );
    final muted = Theme.of(tester.element(find.byType(AppListRow)))
        .colorScheme
        .muted;
    expect(_rowPainted(tester, muted), isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('Acme')));
    await tester.pumpAndSettle();

    expect(_rowPainted(tester, muted), isTrue);
  });

  testWidgets('empty state shows its message', (tester) async {
    await tester.pumpWidget(_host(const EmptyState('Nessun cliente')));
    expect(find.text('Nessun cliente'), findsOneWidget);
  });
}
