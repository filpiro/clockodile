import 'package:clockodile/shared/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  // Guards the locked knobs: teal accent on Gray, radius 0.75, in both
  // brightnesses — nothing else would notice if one drifted.
  test('both brightnesses use the teal accent and radius 0.75', () {
    for (final theme in [lightTheme, darkTheme]) {
      expect(theme.colorScheme.primary, Colors.teal);
      expect(theme.radius, 0.75);
    }
    expect(lightTheme.colorScheme.brightness, Brightness.light);
    expect(darkTheme.colorScheme.brightness, Brightness.dark);
  });

  // Guards the soft-neutral surfaces: no pure white/near-black anywhere.
  test('surfaces use the soft-neutral palette, not pure white/black', () {
    final light = lightTheme.colorScheme;
    expect(light.background, const Color(0xFFF5F6F8));
    expect(light.card, const Color(0xFFF5F6F8));
    expect(light.popover, const Color(0xFFF5F6F8));

    final dark = darkTheme.colorScheme;
    expect(dark.foreground, const Color(0xFFE4E6EB));
    expect(dark.background, const Color(0xFF16181D));
    // Each rung of the elevation ramp must read as its own step, both
    // against the background and against its neighbours — otherwise
    // hovered rows, the identicon tile or dividers vanish into the page.
    final ramp = [dark.background, dark.card, dark.muted, dark.border];
    for (var i = 0; i < ramp.length; i++) {
      for (var j = i + 1; j < ramp.length; j++) {
        expect(ramp[i], isNot(ramp[j]), reason: 'ramp steps $i and $j clash');
      }
    }
  });
}
