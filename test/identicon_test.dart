import 'package:clockodile/shared/widgets/identicon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an identicon is a mirrored grid fixed by the client id alone', () {
    final a = identicon(1);
    expect(identicon(1).cells, a.cells);
    expect(identicon(1).hue, a.hue);
    expect(a.cells, hasLength(25));
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        expect(a.cells[y * 5 + x], a.cells[y * 5 + 4 - x]);
      }
    }
  });

  test('identicons of different clients rarely collide', () {
    final grids = {for (var id = 1; id <= 50; id++) identicon(id).cells.join()};
    expect(grids.length, greaterThan(45));
  });
}
