import 'package:clockodile/shared/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  // Guards the locked knobs: green accent on Slate, radius 0.7, in both
  // brightnesses — nothing else would notice if one drifted.
  test('both brightnesses use the green accent and radius 0.7', () {
    for (final theme in [lightTheme, darkTheme]) {
      expect(theme.colorScheme.primary, Colors.green);
      expect(theme.radius, 0.7);
    }
    expect(lightTheme.colorScheme.brightness, Brightness.light);
    expect(darkTheme.colorScheme.brightness, Brightness.dark);
  });
}
