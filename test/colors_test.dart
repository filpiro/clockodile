import 'package:clockodile/shared/utils/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a hex we cannot read degrades to grey instead of throwing', () {
    expect(hexToColor('#FF8800'), const Color(0xFFFF8800));
    // The autocomplete asks for a client that does not exist yet.
    expect(hexToColor(null), unknownClientColor);
    expect(hexToColor(''), unknownClientColor);
    expect(hexToColor('FF8800'), unknownClientColor); // no leading #
    expect(hexToColor('#GGHHII'), unknownClientColor);
    expect(hexToColor('#FF88'), unknownClientColor);
  });

  test('a generated colour round-trips through hex', () {
    final hex = randomClientColorHex();
    expect(colorToHex(hexToColor(hex)), hex);
  });
}
