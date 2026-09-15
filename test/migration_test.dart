import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:clockodile/data/db/database.dart';

/// The v4 shape, written out by hand: opening it with the current AppDatabase
/// must add the AI columns and touch nothing else.
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
INSERT INTO clients (name, color_hex) VALUES ('Acme', '#ff0000');
INSERT INTO entries (client_id, note) VALUES (1, 'vecchia nota');
INSERT INTO sessions (entry_id, start, "end") VALUES (1, 1000, 2000);
INSERT INTO settings (id, retention_days, theme_mode) VALUES (1, 90, 'dark');
PRAGMA user_version = 4;
''';

void main() {
  test(
    'a schema-4 database opens at 6 with every row and setting intact',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_schema4);
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final settings = await db.getSettings();

      expect((await db.select(db.clients).getSingle()).name, 'Acme');
      expect((await db.select(db.entries).getSingle()).note, 'vecchia nota');
      expect((await db.select(db.sessions).getSingle()).entryId, 1);
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
