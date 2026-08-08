import 'package:clockodile/data/db/database.dart';

/// A closed Session with its Entry and Client, as `watchClosedSessions` yields
/// it. Shared by the normalization and board tests.
SessionRow row(
  int id,
  DateTime start,
  DateTime end, {
  int clientId = 1,
  String client = 'Acme',
  String note = '',
}) {
  return SessionRow(
    Session(id: id, entryId: id, start: start, end: end),
    Entry(id: id, clientId: clientId, note: note),
    Client(id: clientId, name: client, colorHex: '#000000'),
  );
}

/// A wall-clock time on the tests' arbitrary reference day.
DateTime at(int h, int m) => DateTime(2026, 7, 18, h, m);
