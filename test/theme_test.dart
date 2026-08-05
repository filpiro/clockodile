import 'package:catui/catui.dart';
import 'package:clockodile/shared/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Guards the accent that moved out of catui: the package now defaults to
  // mauve, so if this app ever stops passing green nothing else would notice.
  test('both brightnesses use the flavor green as primary', () {
    expect(lightTheme.colorScheme.primary, catppuccin.latte.green);
    expect(darkTheme.colorScheme.primary, catppuccin.mocha.green);
  });
}
