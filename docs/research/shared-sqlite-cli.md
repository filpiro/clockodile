# Research: one SQLite database shared by the app and a CLI

Ticket: [#20](https://github.com/filpiro/clockodile/issues/20) (part of map #6). Date: 2026-10-24.

## Short answer

Yes, a separate CLI can open the app's SQLite file while the app runs, if both processes run **on Windows** and both connections set WAL and a busy timeout. Build the CLI as a Windows `.exe` (`dart compile exe`) from this repo, reusing `AppDatabase`. Call it from WSL as `clockodile_cli.exe ...`. WSL interop starts it as a normal Windows process, so it gets native Windows file locking. Do not open the file from a Linux process through `/mnt/c`. The running app does not see CLI writes by itself. Poll `PRAGMA data_version` in the app, then call `markTablesUpdated` so the drift streams re-query. A local HTTP or pipe API is not needed for correctness. Its only extra value is instant UI refresh.

## Current state (verified in this repo)

- `AppDatabase()` opens `driftDatabase(name: 'clockodile')` (`lib/data/db/database.dart:119`). drift_flutter 0.3.1 resolves this to `getApplicationDocumentsDirectory()/clockodile.sqlite` (`drift_flutter-0.3.1/lib/src/native.dart`). On this machine that is `C:\Users\filippo.pirola.PL\Documents\clockodile.sqlite`.
- `beforeOpen` runs only `PRAGMA foreign_keys = ON` (`database.dart:110`). Neither drift 2.34.4 nor drift_flutter sets `journal_mode` or `busy_timeout`. drift's own docs say WAL must be enabled by the app: "To enable write-ahead logging, issue a call to [Database.execute] setting `pragma journal_mode = WAL;`" (`drift-2.34.4/lib/native.dart`, `createInBackground` doc).
- The live file reports `journal_mode = delete` and `user_version = 7` (read with `immutable=1`, so no lock was taken).
- `DriftNativeOptions.setup` (`void Function(CommonDatabase db)`) is the hook for per-connection pragmas (`drift_flutter-0.3.1/lib/src/connect.dart`).
- The UI reads through drift streams: `watchActiveEntry`, `watchClosedSessions`, `watchClientsWithCounts` (`database.dart:216`, `:298`, `:390`).
- ADR 0001 binds `127.0.0.1:38573` as the single-instance lock. Any inbound connection means "raise the window". No other IPC exists.

## 1. Two processes on one file: locking, WAL, busy timeout

- In the default rollback journal (`delete`) mode, a writer blocks readers. drift's docs: "In the default journaling mode used by sqlite3, concurrent reads and writes are forbidden." (`drift-2.34.4/lib/native.dart`)
- WAL: "readers do not block writers and a writer does not block readers", but "there can only be one writer at a time". WAL can still return `SQLITE_BUSY` in rare cases, "so applications should be prepared for that happenstance." ([sqlite.org/wal.html](https://www.sqlite.org/wal.html) §1, §2.2, §9)
- WAL needs shared memory: "All processes using a database must be on the same host computer; WAL does not work over a network filesystem." ([sqlite.org/wal.html](https://www.sqlite.org/wal.html) §1)
- `PRAGMA busy_timeout = ms` makes a connection retry a locked database for up to `ms` milliseconds instead of failing at once with `SQLITE_BUSY`. Each connection has one busy handler ([sqlite.org/pragma.html#pragma_busy_timeout](https://www.sqlite.org/pragma.html#pragma_busy_timeout)). Set it on **both** connections.
- WAL is persistent: once a connection sets it, the file stays in WAL mode ([sqlite.org/wal.html](https://www.sqlite.org/wal.html), "Persistence of WAL mode"). The file then gets `-wal` and `-shm` sidecar files. Any backup or copy code must handle those files.

Recommended setup for both app and CLI:

```dart
driftDatabase(
  name: 'clockodile',
  native: DriftNativeOptions(
    setup: (db) {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA busy_timeout = 5000');
    },
  ),
);
```

Keep CLI transactions short, and use `transaction()` for multi-statement writes. Two writers serialize on the WAL write lock.

## 2. The app seeing rows the CLI wrote

- drift invalidates streams only for writes made through the same drift database object. Other writers are invisible to it. `markTablesUpdated(tables)` re-runs "all streams listening on any of the [tables]". It is a public API "you can also call yourself to manually dispatch table updates" (`drift-2.34.4/lib/src/runtime/api/connection_user.dart:108`).
- `PRAGMA data_version` changes "if changes were committed to the database by any other connection in the interim". It is "unchanged for commits made on the same database connection", and it behaves the same "in separate processes" ([sqlite.org/pragma.html#pragma_data_version](https://www.sqlite.org/pragma.html#pragma_data_version)). The docs name the use case: programs "that display database content on-screen".

Cheapest design: in the app, a `Timer.periodic` of about 1 to 2 s runs `PRAGMA data_version`. When the value changes, call `markTablesUpdated([clients, entries, sessions, settings])`. The app's own writes never trigger it. The query is a header read, so idle polling costs almost nothing.

Optional push instead of polling: after a write, the CLI could poke the app over loopback. The ADR 0001 socket treats every connection as "raise window". Reusing it would need a message protocol, so polling is simpler.

Also re-check app state that lives outside drift streams. Example: a timer or cubit holding the Open Session. The CLI may close that session and open another. After `markTablesUpdated`, `watchActiveEntry` emits the new row, so any code driven by that stream follows it.

## 3. WSL to Windows

- Microsoft documents that WSL "can run Windows tools directly from the WSL command line using `[tool-name].exe`". These tools "run as the active Windows user", and "piping, redirects, and even backgrounding work as expected". "Parameters are passed to the Windows binary unmodified." ([learn.microsoft.com/windows/wsl/filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems#run-windows-tools-from-linux))
  - So a Windows CLI `.exe` called from WSL is a real Windows process on the same host. It uses Windows file locks and WAL shared memory, like the app, and it resolves `Documents` the same way.
  - Pass Windows paths, not `/mnt/c/...` paths, because arguments are not translated. The CLI should find the DB itself (the same `getApplicationDocumentsDirectory` logic, or `%USERPROFILE%`), so callers never pass a path.
  - stdout and the exit code come back to the WSL shell, which fits Claude Code.
- A Linux process (Linux `sqlite3`, or a Linux-built Dart CLI) opening `/mnt/c/.../clockodile.sqlite` is a different case. Linux SQLite uses POSIX `fcntl` locks, and Windows SQLite uses `LockFileEx`. Microsoft's WSL docs do not say whether locks taken through `/mnt/c` are visible to Windows processes, and they advise against working across OS file systems (same page). WAL shared memory cannot cross the VM boundary either. Treat this path as a network filesystem in SQLite's terms: unsafe ([sqlite.org/wal.html](https://www.sqlite.org/wal.html) §1, [sqlite.org/useovernet.html](https://www.sqlite.org/useovernet.html)). Not tested here.

## 4. Schema version hazard

`database.dart` notes that "an older build opening an upgraded file writes its own lower user_version back". A CLI with a stale `schemaVersion` would do exactly that. Rule: the CLI lives in this repo (for example `bin/clockodile_cli.dart`) and imports the same `AppDatabase`. Build it together with the app. Better still, the CLI refuses to run when the file's `user_version` is above its own `schemaVersion`.

## Verdict: direct DB access vs. talking to the running app

| | Windows CLI `.exe` on the shared file | CLI talks to app (HTTP or pipe) |
|---|---|---|
| Works when the app is closed | yes | no |
| New code | WAL and busy pragmas, `data_version` poll, CLI entry point | server in app, protocol, auth on a port every local user can reach |
| Instant UI refresh | 1 to 2 s poll | yes |
| Domain rules (one Open Session) | shared through `AppDatabase` methods | enforced in app |

Recommendation: Windows CLI `.exe` on the shared file. Use the WAL and `busy_timeout` setup on both sides, plus a `data_version` poll in the app.

## Not verified

- No cross-process test was run. Windows has no Python or `sqlite3` CLI installed here, and Flutter/Dart were not run.
- How `/mnt/c` handles locks from WSL2 was not tested. The advice above avoids that path entirely.
