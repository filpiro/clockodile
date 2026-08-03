import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clockodile/data/db/database.dart';

// If this fails to load sqlite3 natively on Windows, put sqlite3.dll next to
// the dart executable or run on CI — see PLAN.md risks.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Entry> entryNamed(String note) async =>
      (await db.select(db.entries).get()).firstWhere((e) => e.note == note);

  test('creating a second entry closes the first session; exactly one open',
      () async {
    await db.createEntry('Acme', 'a');
    await db.createEntry('Globex', 'b');

    final sessions = await db.select(db.sessions).get();
    expect(sessions.length, 2);
    expect(sessions.where((s) => s.end == null).length, 1);

    final active = await db.watchActiveEntry().first;
    expect(active!.client.name, 'Globex');
  });

  test('activation opens a new session and closes the previous open one',
      () async {
    await db.createEntry('Acme', 'first');
    await db.createEntry('Globex', 'second');
    final first = await entryNamed('first');

    await db.activateEntry(first.id); // reactivation

    final sessions = await db.select(db.sessions).get();
    expect(sessions.length, 3); // never edits past sessions, always inserts
    expect(sessions.where((s) => s.end == null).length, 1);
    final active = await db.watchActiveEntry().first;
    expect(active!.entry.id, first.id);
  });

  test('activating the already-active entry is a no-op', () async {
    await db.createEntry('Acme', 'only');
    final entry = await entryNamed('only');
    final before = await db.select(db.sessions).get();

    await db.activateEntry(entry.id);

    final after = await db.select(db.sessions).get();
    expect(after.length, before.length);
    expect(after.single.end, isNull); // still open, untouched
  });

  test('stop closes the open session and opens nothing', () async {
    await db.createEntry('Acme', 'x');
    await db.stopOpenSession();

    expect(await db.watchActiveEntry().first, isNull);
    final sessions = await db.select(db.sessions).get();
    expect(sessions.single.end, isNotNull);
  });

  test('client match is case-insensitive, no duplicate row', () async {
    await db.createEntry('mario', '');
    await db.createEntry('MARIO', '');

    final clients = await db.select(db.clients).get();
    expect(clients.length, 1);
    expect(clients.single.name, 'mario');
  });

  test('deleteClient blocked with entries, allowed without', () async {
    await db.createEntry('Acme', '');
    final client = (await db.select(db.clients).get()).single;

    expect(await db.deleteClient(client.id), false);
    expect((await db.select(db.clients).get()).length, 1);

    await db.delete(db.entries).go();
    expect(await db.deleteClient(client.id), true);
    expect(await db.select(db.clients).get(), isEmpty);
  });

  test('deleteSession blocked on the last session of an entry', () async {
    await db.createEntry('Acme', 'multi');
    final entry = await entryNamed('multi');
    await db.stopOpenSession();
    await db.activateEntry(entry.id);
    await db.stopOpenSession();

    final sessions = await db.sessionsOfEntry(entry.id);
    expect(sessions.length, 2);
    expect(await db.deleteSession(sessions.first.id), true);
    final last = (await db.sessionsOfEntry(entry.id)).single;
    expect(await db.deleteSession(last.id), false); // last one stays
  });

  test('deleting an entry cascades to its sessions', () async {
    await db.createEntry('Acme', 'gone');
    final entry = await entryNamed('gone');
    await db.deleteEntry(entry.id);
    expect(await db.select(db.sessions).get(), isEmpty);
  });

  test('watchClosedSessions respects date range and excludes open', () async {
    final today = DateTime(2026, 7, 11, 9);
    final yesterday = DateTime(2026, 7, 10, 9);
    await db.createEntry('Acme', '', startTime: yesterday);
    // closes yesterday's session, opens today's
    await db.createEntry('Acme', '', startTime: today);

    final all = await db.watchClosedSessions().first;
    expect(all.length, 1); // open one excluded

    final onlyYesterday = await db
        .watchClosedSessions(
            from: DateTime(2026, 7, 10), to: DateTime(2026, 7, 11))
        .first;
    expect(onlyYesterday.length, 1);

    final onlyToday = await db
        .watchClosedSessions(
            from: DateTime(2026, 7, 11), to: DateTime(2026, 7, 12))
        .first;
    expect(onlyToday, isEmpty); // today's session is still open
  });

  test('purge keys off the newest session; active entry never purged',
      () async {
    final ancient = DateTime.now().subtract(const Duration(days: 400));
    final recent = DateTime.now().subtract(const Duration(days: 5));

    // old-closed: single ancient session → purged
    await db.createEntry('Acme', 'old-closed', startTime: ancient);
    // revived: ancient session + recent one → newest is recent → kept whole
    await db.createEntry('Acme', 'revived', startTime: ancient);
    await db.stopOpenSession();
    final revived = await entryNamed('revived');
    await db.activateEntry(revived.id);
    await db.stopOpenSession();
    await db.updateSession(
        (await db.sessionsOfEntry(revived.id)).last.id,
        start: recent,
        end: recent.add(const Duration(hours: 1)));
    // old-open: ancient but active → kept
    await db.createEntry('Acme', 'old-open', startTime: ancient);

    await db.purgeExpiredEntries(); // default 60 days

    final notes = (await db.select(db.entries).get()).map((e) => e.note);
    expect(notes, unorderedEquals(['revived', 'old-open']));
    // revived keeps ALL its sessions — totals never shrink
    expect((await db.sessionsOfEntry(revived.id)).length, 2);
    // client survives even if all its entries were purgeable
    expect((await db.select(db.clients).get()).length, 1);
  });

  test('retention setting round-trips and defaults to 60', () async {
    expect(await db.getRetentionDays(), 60);
    await db.setRetentionDays(90);
    expect(await db.getRetentionDays(), 90);
    await db.setRetentionDays(30);
    expect(await db.getRetentionDays(), 30);
  });

  test('updateSession never reopens: absent end keeps stored value', () async {
    await db.createEntry('Acme', '');
    await db.stopOpenSession();
    final session = (await db.select(db.sessions).get()).single;

    await db.updateSession(session.id, start: session.start, end: null);

    final row = await (db.select(db.sessions)
          ..where((s) => s.id.equals(session.id)))
        .getSingle();
    expect(row.end, isNotNull);
  });

  test('active entry total counts closed sessions only', () async {
    await db.createEntry('Acme', 'tot',
        startTime: DateTime.now().subtract(const Duration(hours: 2)));
    await db.stopOpenSession();
    final entry = await entryNamed('tot');
    final closed = (await db.sessionsOfEntry(entry.id)).single;
    await db.updateSession(closed.id,
        start: closed.start, end: closed.start.add(const Duration(hours: 1)));
    await db.activateEntry(entry.id);

    final active = (await db.watchActiveEntry().first)!;
    expect(active.closedTotal, const Duration(hours: 1));
  });
}
