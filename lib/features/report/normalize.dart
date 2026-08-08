import '../../data/db/database.dart';

/// Gap below this (including negative gaps from allowed overlaps) means two
/// consecutive sessions share one boundary. ponytail: tunable in code only.
const contiguityThreshold = Duration(minutes: 5);

const _quarter = Duration(minutes: 15);

/// One normalized Report row: the original session plus its quarter-hour
/// boundaries. Stored data is never touched.
class ReportRow {
  final SessionRow source;
  final DateTime normStart;
  final DateTime normEnd;
  ReportRow(this.source, this.normStart, this.normEnd);

  Client get client => source.client;
  Entry get entry => source.entry;
  Session get session => source.session;
  Duration get normDuration => normEnd.difference(normStart);
}

// Rounding works in seconds since local midnight so quarter marks align with
// the wall clock regardless of timezone offset.
DateTime _round(DateTime t, int Function(int secs, int q) f) {
  final midnight = DateTime(t.year, t.month, t.day);
  final secs = t.difference(midnight).inSeconds;
  return midnight.add(Duration(seconds: f(secs, _quarter.inSeconds)));
}

DateTime _floorQ(DateTime t) => _round(t, (s, q) => (s ~/ q) * q);

DateTime _ceilQ(DateTime t) => _round(t, (s, q) => ((s + q - 1) ~/ q) * q);

/// Nearest quarter, half-up. Seconds-based: the shared-boundary midpoint can
/// land on :30 seconds.
DateTime _nearestQ(DateTime t) => _round(t, (s, q) => ((s + q ~/ 2) ~/ q) * q);

// The Report reasons at minute precision, matching the UI. Stored Sessions
// carry seconds, which would e.g. ceil an end shown as 9:15 (stored 9:15:47)
// to 9:30.
DateTime _minute(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);

DateTime _midpoint(DateTime a, DateTime b) =>
    DateTime.fromMillisecondsSinceEpoch(
      (a.millisecondsSinceEpoch + b.millisecondsSinceEpoch) ~/ 2,
    );

/// Normalizes one day's closed sessions to quarter-hour boundaries.
///
/// The chain is always chronological across all clients. Boundaries:
/// first start floors, last end ceils; a contiguous pair shares one boundary
/// (midpoint, rounded nearest); a real gap rounds outward (ceil / floor) so
/// it can shrink but is never invented.
List<ReportRow> normalizeDay(List<SessionRow> sessions) {
  if (sessions.isEmpty) return const [];
  final sorted = [...sessions]
    ..sort((a, b) => a.session.start.compareTo(b.session.start));

  final n = sorted.length;
  final starts = List<DateTime?>.filled(n, null);
  final ends = List<DateTime?>.filled(n, null);

  starts[0] = _floorQ(_minute(sorted.first.session.start));
  ends[n - 1] = _ceilQ(_minute(sorted.last.session.end!));

  for (var i = 0; i < n - 1; i++) {
    final end = _minute(sorted[i].session.end!);
    final nextStart = _minute(sorted[i + 1].session.start);
    if (nextStart.difference(end) < contiguityThreshold) {
      final shared = _nearestQ(_midpoint(end, nextStart));
      ends[i] = shared;
      starts[i + 1] = shared;
    } else {
      ends[i] = _ceilQ(end);
      starts[i + 1] = _floorQ(nextStart);
    }
  }

  return [
    for (var i = 0; i < n; i++) ReportRow(sorted[i], starts[i]!, ends[i]!),
  ];
}

/// Report row order: clients by first appearance in the day, each client's
/// rows chronological. The one order for preview and CSV in both view modes —
/// the board positions its tiles by time, so it doesn't care. Presentation
/// only — normalization is unaffected.
List<ReportRow> groupByClient(List<ReportRow> rows) {
  final byClient = <int, List<ReportRow>>{};
  for (final r in rows) {
    byClient.putIfAbsent(r.client.id, () => []).add(r);
  }
  return [for (final group in byClient.values) ...group];
}
