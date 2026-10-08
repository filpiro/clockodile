import 'package:clockodile/shared/widgets/app_list_row.dart';
import 'package:clockodile/shared/widgets/empty_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'hover.dart';

Widget _host(Widget child) => ShadcnApp(home: Scaffold(child: child));

/// Whether any box inside [finder] is painted with [color].
bool _paintedWith(WidgetTester tester, Finder finder, Color color) => tester
    .widgetList<OverflowDecoratedBox>(
      find.descendant(of: finder, matching: find.byType(OverflowDecoratedBox)),
    )
    .any(
      (box) => switch (box.decoration) {
        BoxDecoration(color: final c) ||
        ShapeDecoration(color: final c) => c == color,
        _ => false,
      },
    );

double _opacityOf(WidgetTester tester, IconData icon) => tester
    .widgetList<AnimatedOpacity>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .first
    .opacity;

void main() {
  setUp(() {
    // Hover highlights follow the focus highlight mode, which tests start
    // in touch mode.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('actions are hidden at rest and appear on row hover', (
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
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, LucideIcons.pencil), 0);
    expect(_opacityOf(tester, LucideIcons.trash2), 0);

    // Hidden buttons take no clicks (the tap falls through to the row itself).
    await tester.tap(find.byIcon(LucideIcons.pencil), warnIfMissed: false);
    await tester.tap(find.byIcon(LucideIcons.trash2), warnIfMissed: false);
    expect((edited, deleted), (0, 0));
    tapped = 0;

    final mouse = await hoverOver(tester, find.text('Acme'));
    addTearDown(mouse.removePointer);

    expect(_opacityOf(tester, LucideIcons.pencil), 1);
    expect(_opacityOf(tester, LucideIcons.trash2), 1);

    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();

    expect((tapped, edited, deleted), (1, 1, 1));
  });

  testWidgets('tabbing into an action button reveals it', (tester) async {
    await tester.pumpWidget(
      _host(
        AppListRow(
          title: const Text('Acme'),
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, LucideIcons.pencil), 0);

    // The row itself is a focus stop before its actions; tab through it.
    for (var i = 0; i < 3 && _opacityOf(tester, LucideIcons.pencil) == 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    expect(_opacityOf(tester, LucideIcons.pencil), 1);
  });

  testWidgets('hover paints the muted fill, and only hover', (tester) async {
    await tester.pumpWidget(
      _host(AppListRow(title: const Text('Acme'), onTap: () {})),
    );
    final muted = Theme.of(tester.element(find.byType(AppListRow)))
        .colorScheme
        .muted;
    expect(_paintedWith(tester, find.byType(AppListRow), muted), isFalse);

    final mouse = await hoverOver(tester, find.text('Acme'));
    addTearDown(mouse.removePointer);

    expect(_paintedWith(tester, find.byType(AppListRow), muted), isTrue);
  });

  testWidgets('row hover alone never reddens the delete icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppListRow(
          title: const Text('Acme'),
          onTap: () {},
          onDelete: () {},
        ),
      ),
    );
    final destructive = Theme.of(tester.element(find.byType(AppListRow)))
        .colorScheme
        .destructive;
    Color? deleteIconColor() =>
        IconTheme.of(tester.element(find.byIcon(LucideIcons.trash2))).color;

    // Hover a point on the row that is not the delete button itself.
    final mouse = await hoverOver(tester, find.text('Acme'));
    addTearDown(mouse.removePointer);

    expect(deleteIconColor(), isNot(destructive));

    await mouse.moveTo(tester.getCenter(find.byIcon(LucideIcons.trash2)));
    await tester.pumpAndSettle();

    expect(deleteIconColor(), destructive);
  });

  testWidgets('empty state shows its message', (tester) async {
    await tester.pumpWidget(_host(const EmptyState('Nessun cliente')));
    expect(find.text('Nessun cliente'), findsOneWidget);
  });
}
