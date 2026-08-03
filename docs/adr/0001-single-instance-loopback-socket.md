# 1. Single instance enforced by a bound loopback socket

Date: 2026-07-31

## Status

Accepted

## Context

Clockodile keeps at most one Open Session system-wide, and stores everything in
a single local SQLite file. Two copies of the app running against that file
would mean two writers: lock contention at best, and a UI showing an Open
Session that the other copy has already closed at worst. The app must therefore
run as a single instance.

Launching the app a second time is a normal user action — double-clicking the
shortcut when the window is buried or minimised. The second launch should
surface the existing window rather than fail silently, so whatever enforces the
lock needs a way to talk to the instance already holding it.

Options considered:

- **Named mutex (Win32 `CreateMutex`)** — the conventional Windows answer, but
  it only signals "taken"; raising the existing window needs a second mechanism
  on top, and reaching it from Dart means platform-channel or FFI glue.
- **Lock file beside the database** — no new dependency and naturally per-user,
  since the database directory already is. But a lock file outlives a crash, so
  it needs stale-lock detection (PID liveness checks, timestamps), and getting
  that wrong locks the user out of their own app.
- **Bound TCP socket on the loopback interface** — the OS refuses a second bind,
  and the same socket carries the "come to the front" message.

## Decision

The first instance binds `127.0.0.1:38573` and listens. A later launch fails to
bind, connects to the port to poke the owner, and exits. The owner treats any
inbound connection as "someone tried to launch me" and restores, shows and
focuses its window.

## Consequences

The socket doubles as the lock and as the IPC channel, so raising the existing
window needs no extra mechanism and no native code.

The lock cannot go stale. The OS releases a bound port when the process ends,
crashes included, so there is no liveness check to get wrong and no recovery
path to maintain — the main reason this was chosen over a lock file.

Focus is best-effort. Windows' foreground lock may refuse `focus()` from a
process that isn't already foreground; the taskbar button flashes instead. This
is accepted rather than worked around.

Two holes are known and accepted:

- **Port squatting.** If any other process holds 38573, `bind` fails, the poke
  lands on that stranger, and Clockodile calls `exit(0)`. The app then never
  launches, with no window and no message. The port sits below the Windows
  ephemeral range (49152+), so nothing takes it by accident, and the risk was
  judged not worth the handshake needed to detect it — the owner replying with a
  magic byte the challenger verifies before exiting.
- **The lock is machine-wide, the database is per-user.** `driftDatabase(name:
  'clockodile')` resolves under the user profile, but a loopback port is shared
  across all logged-in users. Under fast user switching, the second user's
  launch raises the first user's window and quits, so they can never open the
  app. Out of scope for a single-user desktop tool.

Neither is worth fixing until someone actually hits one.
