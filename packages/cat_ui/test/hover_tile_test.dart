import 'package:cat_ui/cat_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final highlight = lightTheme.colorScheme.surfaceContainerHighest;

  Color? tileColorOf(WidgetTester tester) =>
      tester.widget<ListTile>(find.byType(ListTile)).tileColor;

  Future<TestGesture> hoverOverTile(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(ListTile)));
    return mouse;
  }

  Future<void> pumpTile(WidgetTester tester, {VoidCallback? onTap}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: HoverTile(title: const Text('riga'), onTap: onTap),
        ),
      ),
    );
  }

  // The reason HoverTile drives its own highlight instead of leaning on
  // ListTile.hoverColor: InkResponse ignores hover when every callback is
  // null, which would leave the active entry and note-less report rows flat.
  testWidgets('highlights on hover even when not tappable', (tester) async {
    await pumpTile(tester);
    expect(tileColorOf(tester)!.a, 0);

    final mouse = await hoverOverTile(tester);
    await tester.pumpAndSettle();
    expect(tileColorOf(tester), highlight.withValues(alpha: 1));

    await mouse.moveTo(const Offset(600, 600));
    await tester.pumpAndSettle();
    expect(tileColorOf(tester)!.a, 0);
  });

  testWidgets('highlight fades in rather than snapping', (tester) async {
    await pumpTile(tester, onTap: () {});
    await hoverOverTile(tester);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tileColorOf(tester)!.a;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pumpAndSettle();
    expect(tileColorOf(tester)!.a, 1);
  });
}
