import 'package:flutter_test/flutter_test.dart';
import 'package:clockodile/features/report/normalize.dart';

import 'fixtures.dart';

void main() {
  test('spec example A: two contiguous sessions share one rounded boundary',
      () {
    final rows = normalizeDay([
      row(1, at(9, 51), at(10, 13)),
      row(2, at(10, 14), at(10, 40)),
    ]);
    expect(rows[0].normStart, at(9, 45)); // day start floors
    expect(rows[0].normEnd, at(10, 15)); // shared boundary, nearest
    expect(rows[1].normStart, at(10, 15)); // same instant — no gap/overlap
    expect(rows[1].normEnd, at(10, 45)); // day end ceils
  });

  test('spec example B: real gap rounds outward and may shrink', () {
    final rows = normalizeDay([
      row(1, at(9, 0), at(10, 13)),
      row(2, at(10, 41), at(11, 20)),
    ]);
    expect(rows[0].normEnd, at(10, 15)); // ceil
    expect(rows[1].normStart, at(10, 30)); // floor
  });

  test('overlapping sessions are contiguous; boundary at rounded midpoint',
      () {
    // ends 10:20, next starts 10:12 → midpoint 10:16 → nearest 10:15
    final rows = normalizeDay([
      row(1, at(9, 30), at(10, 20)),
      row(2, at(10, 12), at(11, 0)),
    ]);
    expect(rows[0].normEnd, at(10, 15));
    expect(rows[1].normStart, at(10, 15));
  });

  test('single session floors start, ceils end', () {
    final rows = normalizeDay([row(1, at(9, 51), at(10, 13))]);
    expect(rows.single.normStart, at(9, 45));
    expect(rows.single.normEnd, at(10, 15));
  });

  test('short session between shared boundaries can collapse to zero length',
      () {
    final rows = normalizeDay([
      row(1, at(9, 0), at(10, 8)),
      row(2, at(10, 8), at(10, 9)),
      row(3, at(10, 9), at(11, 0)),
    ]);
    // both shared boundaries round to 10:15 — visible in preview, accepted
    expect(rows[1].normStart, at(10, 15));
    expect(rows[1].normEnd, at(10, 15));
  });

  test('seconds are truncated before rounding: 9:11–9:15:47 → 9:00–9:15', () {
    final rows = normalizeDay(
        [row(1, at(9, 11), DateTime(2026, 7, 18, 9, 15, 47))]);
    expect(rows.single.normStart, at(9, 0));
    expect(rows.single.normEnd, at(9, 15));
  });

  test('empty input, empty output', () {
    expect(normalizeDay([]), isEmpty);
  });

  test('grouped order: clients by first appearance, chronological within',
      () {
    final rows = normalizeDay([
      row(1, at(9, 0), at(9, 30), clientId: 1, client: 'Acme'),
      row(2, at(9, 30), at(10, 0), clientId: 2, client: 'Globex'),
      row(3, at(10, 0), at(10, 30), clientId: 1, client: 'Acme'),
    ]);
    expect(groupByClient(rows).map((r) => r.session.id).toList(), [1, 3, 2]);
  });
}
