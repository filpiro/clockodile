import 'package:flutter_test/flutter_test.dart';
import 'package:clockodile/features/report/board_geometry.dart';
import 'package:clockodile/features/report/normalize.dart';

import 'fixtures.dart';

void main() {
  test('empty day has no axis', () {
    expect(boardAxis(const []), isNull);
  });

  test('single-row day: axis floors the start and ceils the end to hours', () {
    final rows = normalizeDay([row(1, at(9, 51), at(10, 13))]);
    // normalized 9:45–10:15
    expect(boardAxis(rows), (at(9, 0), at(11, 0)));
  });

  test('axis spans the whole day content, gaps included', () {
    final rows = normalizeDay([
      row(1, at(9, 10), at(9, 40)),
      row(2, at(13, 5), at(14, 20)),
    ]);
    // normalized 9:00–9:45 and 13:00–14:30
    expect(boardAxis(rows), (at(9, 0), at(15, 0)));
  });

  test('axis is computed from the rows, not their display order', () {
    final rows = groupByClient(
      normalizeDay([
        row(1, at(9, 0), at(9, 30), clientId: 1),
        row(2, at(9, 30), at(10, 0), clientId: 2),
        row(3, at(10, 0), at(10, 30), clientId: 1),
      ]),
    );
    expect(rows.map((r) => r.session.id), [1, 3, 2]); // not chronological
    expect(boardAxis(rows), (at(9, 0), at(11, 0)));
  });

  test('offset and height are 1.6 px per minute, no clamp', () {
    expect(boardOffset(at(9, 0), at(10, 0)), 96);
    expect(boardOffset(at(9, 0), at(9, 15)), 24);
    expect(tileHeight(const Duration(minutes: 30)), 48);
    expect(tileHeight(Duration.zero), 0);
  });

  test('a gap leaves bare board between the two tiles', () {
    final rows = normalizeDay([
      row(1, at(9, 10), at(9, 40)),
      row(2, at(13, 5), at(14, 20)),
    ]);
    final (start, _) = boardAxis(rows)!;
    final firstBottom =
        boardOffset(start, rows[0].normStart) + tileHeight(rows[0].normDuration);
    expect(firstBottom, 72); // 9:00 → 9:45
    expect(boardOffset(start, rows[1].normStart), 384); // 9:00 → 13:00
  });

  test('a zero-length row has zero height and is not hidden', () {
    final rows = normalizeDay([
      row(1, at(9, 0), at(10, 8)),
      row(2, at(10, 8), at(10, 9)),
      row(3, at(10, 9), at(11, 0)),
    ]);
    expect(rows[1].normDuration, Duration.zero);
    expect(tileHeight(rows[1].normDuration), 0);
    final (start, _) = boardAxis(rows)!;
    expect(boardOffset(start, rows[1].normStart), 120); // 9:00 → 10:15, 75 min
  });

  test('hour marks cover both axis bounds, hours only', () {
    expect(hourMarks(at(9, 0), at(11, 0)), [at(9, 0), at(10, 0), at(11, 0)]);
    expect(hourMarks(at(9, 0), at(9, 0)), [at(9, 0)]);
  });
}
