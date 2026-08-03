import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../shared/utils/colors.dart';

part 'database.g.dart';

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().customConstraint('NOT NULL UNIQUE COLLATE NOCASE')();
  TextColumn get colorHex => text()();
}

/// An Entry (UI "Attività") is a named item of work against one Client.
/// Its time lives in [Sessions]; an Entry always has at least one.
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// A span of tracked time belonging to one Entry. end == null → Open Session;
/// at most one system-wide, derived, never stored.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime().nullable()();
}

/// Single-row table (id always 1).
class Settings extends Table {
  IntColumn get id => integer()();
  IntColumn get retentionDays => integer().withDefault(const Constant(60))();

  /// 'light' | 'dark' | 'system'
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One closed Session with its owning Entry and Client — the list/export row.
class SessionRow {
  final Session session;
  final Entry entry;
  final Client client;
  SessionRow(this.session, this.entry, this.client);
}

/// The Active Entry: the Entry owning the Open Session, plus its total
/// accumulated time across closed sessions (open elapsed excluded — the UI
/// ticks that on its own).
class ActiveEntry {
  final Entry entry;
  final Client client;
  final Session openSession;
  final Duration closedTotal;
  ActiveEntry(this.entry, this.client, this.openSession, this.closedTotal);
}

class ClientWithCount {
  final Client client;
  final int entryCount;
  ClientWithCount(this.client, this.entryCount);
}

@DriftDatabase(tables: [Clients, Entries, Sessions, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'clockodile'));

  AppDatabase.forTesting(super.executor);

  static const defaultRetentionDays = 60;
  static const minRetentionDays = 30;

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(settings);
      if (from < 3) {
        await m.createTable(sessions);
        // Each existing entry's start/end becomes its single session.
        await customStatement(
          'INSERT INTO sessions (entry_id, start, "end") '
          'SELECT id, start_time, end_time FROM entries',
        );
        await m.alterTable(TableMigration(entries));
      }
      if (from < 4) {
        await m.addColumn(settings, settings.themeMode);
      }
    },
  );

  // ---- retention ----

  Future<int> getRetentionDays() async {
    final row = await select(settings).getSingleOrNull();
    return row?.retentionDays ?? defaultRetentionDays;
  }

  Future<void> setRetentionDays(int days) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion(id: const Value(1), retentionDays: Value(days)),
      );

  /// 'light' | 'dark' | 'system'
  Future<String> getThemeMode() async {
    final row = await select(settings).getSingleOrNull();
    return row?.themeMode ?? 'system';
  }

  Future<void> setThemeMode(String mode) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion(id: const Value(1), themeMode: Value(mode)),
      );

  /// Purges whole Entries (sessions cascade) whose *newest* session started
  /// before the retention cutoff. The Active Entry is never purged.
  Future<void> purgeExpiredEntries() async {
    final days = await getRetentionDays();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await transaction(() async {
      final all = await select(sessions).get();
      final newestStart = <int, DateTime>{};
      final hasOpen = <int>{};
      for (final s in all) {
        if (s.end == null) hasOpen.add(s.entryId);
        final prev = newestStart[s.entryId];
        if (prev == null || s.start.isAfter(prev)) {
          newestStart[s.entryId] = s.start;
        }
      }
      final expired = [
        for (final e in newestStart.entries)
          if (e.value.isBefore(cutoff) && !hasOpen.contains(e.key)) e.key,
      ];
      if (expired.isNotEmpty) {
        await (delete(entries)..where((e) => e.id.isIn(expired))).go();
      }
    });
  }

  // ---- activation ----

  Stream<ActiveEntry?> watchActiveEntry() {
    final query = (select(sessions)..where((s) => s.end.isNull())).join([
      innerJoin(entries, entries.id.equalsExp(sessions.entryId)),
      innerJoin(clients, clients.id.equalsExp(entries.clientId)),
    ]);
    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      final session = rows.first.readTable(sessions);
      final entry = rows.first.readTable(entries);
      final total = await _closedTotal(entry.id);
      return ActiveEntry(entry, rows.first.readTable(clients), session, total);
    });
  }

  Future<Duration> _closedTotal(int entryId) async {
    final rows = await (select(
      sessions,
    )..where((s) => s.entryId.equals(entryId) & s.end.isNotNull())).get();
    return rows.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.end!.difference(s.start),
    );
  }

  /// Creates a new Entry born active: one Open Session ([startTime] defaults
  /// to now, backdating allowed). Any current Open Session is closed at now.
  Future<void> createEntry(
    String clientName,
    String note, {
    DateTime? startTime,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      await _closeOpenSession(now);
      final client = await matchOrCreateClient(clientName);
      final entryId = await into(entries).insert(
        EntriesCompanion.insert(clientId: client.id, note: Value(note.trim())),
      );
      await into(sessions).insert(
        SessionsCompanion.insert(entryId: entryId, start: startTime ?? now),
      );
    });
  }

  /// Activation: closes the Open Session (if any) and opens a new Session
  /// under [entryId], atomically. No-op when [entryId] is already active.
  Future<void> activateEntry(int entryId) {
    return transaction(() async {
      final open = await (select(
        sessions,
      )..where((s) => s.end.isNull())).getSingleOrNull();
      if (open?.entryId == entryId) return; // already active
      final now = DateTime.now();
      await _closeOpenSession(now);
      await into(
        sessions,
      ).insert(SessionsCompanion.insert(entryId: entryId, start: now));
    });
  }

  /// Stop: closes the Open Session, opens nothing. Zero active afterwards.
  Future<void> stopOpenSession() => _closeOpenSession(DateTime.now());

  Future<void> _closeOpenSession(DateTime at) => (update(
    sessions,
  )..where((s) => s.end.isNull())).write(SessionsCompanion(end: Value(at)));

  /// Case-insensitive match on name; creates with a generated color if absent.
  Future<Client> matchOrCreateClient(String name) async {
    name = name.trim();
    final existing =
        await (select(clients)
              ..where((c) => c.name.collate(Collate.noCase).equals(name)))
            .getSingleOrNull();
    if (existing != null) return existing;
    final id = await into(clients).insert(
      ClientsCompanion.insert(name: name, colorHex: randomClientColorHex()),
    );
    return Client(id: id, name: name, colorHex: '');
  }

  // ---- sessions list ----

  /// Closed sessions only, newest first — the Open Session is watched/pinned
  /// separately. Range filters on session start.
  Stream<List<SessionRow>> watchClosedSessions({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final query =
        (select(sessions)
              ..where((s) {
                Expression<bool> pred = s.end.isNotNull();
                if (from != null) {
                  pred = pred & s.start.isBiggerOrEqualValue(from);
                }
                if (to != null) pred = pred & s.start.isSmallerThanValue(to);
                return pred;
              })
              ..orderBy([(s) => OrderingTerm.desc(s.start)]))
            .join([
              innerJoin(entries, entries.id.equalsExp(sessions.entryId)),
              innerJoin(clients, clients.id.equalsExp(entries.clientId)),
            ]);
    if (limit != null) query.limit(limit);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => SessionRow(
              r.readTable(sessions),
              r.readTable(entries),
              r.readTable(clients),
            ),
          )
          .toList(),
    );
  }

  Future<List<Session>> sessionsOfEntry(int entryId) =>
      (select(sessions)
            ..where((s) => s.entryId.equals(entryId))
            ..orderBy([(s) => OrderingTerm.asc(s.start)]))
          .get();

  // ---- editing ----

  Future<void> updateEntryFields(
    int id, {
    required String clientName,
    required String note,
  }) {
    return transaction(() async {
      final client = await matchOrCreateClient(clientName);
      await (update(entries)..where((e) => e.id.equals(id))).write(
        EntriesCompanion(clientId: Value(client.id), note: Value(note.trim())),
      );
    });
  }

  /// [end] must be non-null for closed sessions; a closed session can never
  /// be reopened, so this never writes NULL over an existing end.
  Future<void> updateSession(
    int id, {
    required DateTime start,
    DateTime? end,
  }) => (update(sessions)..where((s) => s.id.equals(id))).write(
    SessionsCompanion(
      start: Value(start),
      end: end == null ? const Value.absent() : Value(end),
    ),
  );

  /// Returns false (and deletes nothing) if it is the entry's last session —
  /// an Entry always has at least one; delete the Entry instead.
  Future<bool> deleteSession(int id) {
    return transaction(() async {
      final session = await (select(
        sessions,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (session == null) return false;
      final count = countAll();
      final n =
          await ((selectOnly(sessions)
                    ..addColumns([count])
                    ..where(sessions.entryId.equals(session.entryId)))
                  .map((r) => r.read(count)!))
              .getSingle();
      if (n <= 1) return false;
      await (delete(sessions)..where((s) => s.id.equals(id))).go();
      return true;
    });
  }

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((e) => e.id.equals(id))).go(); // sessions cascade

  // ---- clients ----

  Stream<List<ClientWithCount>> watchClientsWithCounts() {
    final count = entries.id.count();
    final query =
        (select(clients)..orderBy([(c) => OrderingTerm.asc(c.name)])).join([
            leftOuterJoin(entries, entries.clientId.equalsExp(clients.id)),
          ])
          ..addColumns([count])
          ..groupBy([clients.id]);
    return query.watch().map(
      (rows) => rows
          .map((r) => ClientWithCount(r.readTable(clients), r.read(count) ?? 0))
          .toList(),
    );
  }

  Future<void> renameClient(int id, String name) =>
      (update(clients)..where((c) => c.id.equals(id))).write(
        ClientsCompanion(name: Value(name.trim())),
      );

  Future<void> setClientColor(int id, String colorHex) =>
      (update(clients)..where((c) => c.id.equals(id))).write(
        ClientsCompanion(colorHex: Value(colorHex)),
      );

  /// Returns false (and deletes nothing) if the client has linked entries.
  Future<bool> deleteClient(int id) {
    return transaction(() async {
      final inUse =
          await (selectOnly(entries)
                ..addColumns([entries.id])
                ..where(entries.clientId.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (inUse != null) return false;
      await (delete(clients)..where((c) => c.id.equals(id))).go();
      return true;
    });
  }
}
