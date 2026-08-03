/// "2:35" — hours unpadded, minutes padded (spec: h:mm in UI).
String formatHm(Duration d) =>
    '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

/// ISO 8601 local, second precision, for CSV.
String isoLocal(DateTime t) => t.toIso8601String().split('.').first;

String twoDigits(int n) => n.toString().padLeft(2, '0');

/// "14:05"
String hhmm(DateTime t) => '${twoDigits(t.hour)}:${twoDigits(t.minute)}';

/// "2026-07-10" (sortable key + CSV filename; UI uses [dmy])
String ymd(DateTime t) => '${t.year}-${twoDigits(t.month)}-${twoDigits(t.day)}';

/// "10/07/2026" — Italian UI date format.
String dmy(DateTime t) => '${twoDigits(t.day)}/${twoDigits(t.month)}/${t.year}';

/// "10/07/26" — compact form for the date-picker filter chip.
String dmyShort(DateTime t) =>
    '${twoDigits(t.day)}/${twoDigits(t.month)}/${twoDigits(t.year % 100)}';

/// "Oggi", "Ieri", else dd/MM/yyyy. [day] must be date-only (midnight).
String italianDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Oggi';
  if (day == today.subtract(const Duration(days: 1))) return 'Ieri';
  return dmy(day);
}
