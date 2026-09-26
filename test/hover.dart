import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moves a mouse pointer over [finder] and settles the reveal animation.
/// Row actions (see `RowAction`) only appear once the row registers hover.
Future<TestGesture> hoverOver(WidgetTester tester, Finder finder) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(finder));
  await tester.pumpAndSettle();
  return mouse;
}
