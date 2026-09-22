import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:clockodile/data/db/database.dart';

/// The v4 shape, written out by hand: opening it with the current AppDatabase
/// must add the AI columns, drop the client colour, and touch nothing else.
const _schema4 = '''
CREATE TABLE clients (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  color_hex TEXT NOT NULL);
CREATE TABLE entries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL REFERENCES clients (id),
  note TEXT NOT NULL DEFAULT '');
CREATE TABLE sessions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  entry_id INTEGER NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
  start INTEGER NOT NULL,
  "end" INTEGER);
CREATE TABLE settings (
  id INTEGER NOT NULL,
  retention_days INTEGER NOT NULL DEFAULT 60,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  PRIMARY KEY (id));
INSERT INTO clients (name, color_hex) VALUES ('Acme', '#ff0000'), ('Beta', '#00ff00');
INSERT INTO entries (client_id, note) VALUES (1, 'vecchia nota'), (2, ''), (1, 'aperta');
INSERT INTO sessions (entry_id, start, "end") VALUES
  (1, 1000, 2000), (2, 3000, 4000), (2, 5000, 6000), (3, 7000, NULL);
INSERT INTO settings (id, retention_days, theme_mode) VALUES (1, 90, 'dark');
PRAGMA user_version = 4;
''';

void main() {
  test(
    'a schema-4 database opens at 7 with every row and setting intact',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_schema4);
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final settings = await db.getSettings();

      expect(
        [for (final c in await db.select(db.clients).get()) (c.id, c.name)],
        [(1, 'Acme'), (2, 'Beta')],
      );
      expect(
        [
          for (final e in await db.select(db.entries).get())
            (e.id, e.clientId, e.note),
        ],
        [(1, 1, 'vecchia nota'), (2, 2, ''), (3, 1, 'aperta')],
      );
      expect(
        [
          for (final s in await db.select(db.sessions).get())
            (
              s.id,
              s.entryId,
              s.start.millisecondsSinceEpoch,
              s.end?.millisecondsSinceEpoch,
            ),
        ],
        [
          (1, 1, 1000000, 2000000),
          (2, 2, 3000000, 4000000),
          (3, 2, 5000000, 6000000),
          (4, 3, 7000000, null),
        ],
      );
      final clientColumns = raw
          .select('PRAGMA table_info(clients)')
          .map((r) => r['name']);
      expect(clientColumns, ['id', 'name']);
      expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
      expect(raw.userVersion, 7);
      expect(settings.retentionDays, 90);
      expect(settings.themeMode, 'dark');
      expect(settings.aiEnabled, isFalse);
      expect(settings.aiProvider, AiProviderKind.claudeCode.name);
      expect(settings.aiClaudeModel, 'sonnet');
      expect(settings.aiClaudeEffort, 'high');
      expect(settings.aiCodexModel, '');
      expect(settings.aiWslMode, isFalse);
    },
  );
}
