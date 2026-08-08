import 'normalize.dart';

/// Fixed board scale: an hour is 96px, a quarter 24px. ponytail: no zoom
/// control — add one only if a day stops fitting comfortably on screen.
const pxPerMinute = 1.6;

DateTime _floorHour(DateTime t) => DateTime(t.year, t.month, t.day, t.hour);

DateTime _ceilHour(DateTime t) {
  final floor = _floorHour(t);
  return floor == t ? t : floor.add(const Duration(hours: 1));
}

/// The board's wall-clock axis: earliest normalized start floored to its hour,
/// latest normalized end ceiled to its hour. Never a full 00:00–24:00 axis.
/// Null for an empty day — the board isn't drawn at all.
///
/// [rows] may be in any display order (grouped rows are not chronological).
(DateTime start, DateTime end)? boardAxis(List<ReportRow> rows) {
  if (rows.isEmpty) return null;
  var first = rows.first.normStart;
  var last = rows.first.normEnd;
  for (final r in rows) {
    if (r.normStart.isBefore(first)) first = r.normStart;
    if (r.normEnd.isAfter(last)) last = r.normEnd;
  }
  assert(_noOverlap(rows), 'normalization must not produce overlapping rows');
  return (_floorHour(first), _ceilHour(last));
}

/// Normalization chains each row's end into the next row's start, so tiles
/// can never overlap. Asserted instead of building a lane fallback for a case
/// the normalizer cannot produce.
bool _noOverlap(List<ReportRow> rows) {
  final sorted = [...rows]..sort((a, b) => a.normStart.compareTo(b.normStart));
  for (var i = 0; i < sorted.length - 1; i++) {
    if (sorted[i].normEnd.isAfter(sorted[i + 1].normStart)) return false;
  }
  return true;
}

/// Vertical offset of [t] from the top of the board, in px.
double boardOffset(DateTime axisStart, DateTime t) =>
    t.difference(axisStart).inMinutes * pxPerMinute;

/// A tile's height in px — its normalized duration, no minimum clamp.
double tileHeight(Duration normDuration) =>
    normDuration.inMinutes * pxPerMinute;

/// A zero- or negative-length row (a shared boundary can land before the row's
/// start). It has no height to draw a tile in, so the board gives it a
/// hairline instead — never hides it.
bool isHairlineRow(Duration normDuration) => normDuration <= Duration.zero;

/// Every hour on the axis, both bounds included — one label and one gridline
/// each. Hours only, no quarter ticks.
List<DateTime> hourMarks(DateTime axisStart, DateTime axisEnd) => [
  for (
    var h = axisStart;
    !h.isAfter(axisEnd);
    h = h.add(const Duration(hours: 1))
  )
    h,
];
