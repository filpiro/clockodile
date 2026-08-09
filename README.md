<img src="assets/icon/icon.png" alt="Clockodile" width="128" />

# Clockodile

A single-user, local-only desktop time tracker. Flutter on Windows, Italian UI, SQLite (drift) on disk — no account, no sync, no server.

You run a timer against a client, and the app turns the resulting minute-precise spans into a quarter-hour report you can type into a billing portal.

## Domain

Full vocabulary in [`CONTEXT.md`](CONTEXT.md).

- **Client** — the party time is tracked against. Unique name (case-insensitive), a color.
- **Entry** (UI: *Attività*) — a named work item against exactly one Client, with a note. Its time is the sum of its **Sessions**, which may be non-contiguous and span days. Always has at least one Session.
- **Session** — a start time and an optional end time, belonging to one Entry. Created only by activating an Entry; a closed Session is never reopened.
- **Open Session** — `end IS NULL`. At most one system-wide, derived, never stored. Its owner is the **Active Entry**.

## Screens

Icon-only sidebar, five destinations.

### Attività
The entry list, grouped by day. Tapping an inactive row activates it: the Open Session (if any) is closed at `now` and a new Session opens under the tapped Entry — one atomic transaction, radio-button behavior. Tapping the Active Entry is a no-op. `Termina` on the pinned tile closes the Open Session without opening another.

An Entry appears under **each day** it has closed Sessions, its row showing that day's total and session count. The running Session is counted only in the pinned tile, never in day rows — no double counting. Editing lives behind a hover pencil; the edit dialog lists Sessions (start/end editable, deletable except the last) and can close the Open Session with a custom end time — the forgot-to-stop case. Overlaps are allowed and not validated.

### Clienti
Client CRUD: name and color.

### Report
A portal-ready view of **one day's** closed Sessions, all boundaries rounded to quarter-hour marks. Never a correction of stored data — stored Sessions are untouched.

Timestamps are truncated to whole minutes, then the day is treated as a chain of boundary points. Consecutive Sessions less than 5 minutes apart share **one** boundary (the midpoint, rounded half-up), so contiguous work stays contiguous after rounding. Real gaps get two independent boundaries — end ceils, next start floors — so a gap may shrink but is never invented. Day start floors, day end ceils.

Two view modes over the same rows: **Raggruppa per cliente** (default, client header per run) and **Ordine cronologico** (a vertical wall-clock board, tile height = normalized duration at 1.6 px/min). Rows export to CSV (`client, start, end, duration_hours, note`) in the same order in both modes. Clicking a row copies its note.

Details and worked examples: [`specs/time-normalize.md`](specs/time-normalize.md), model rationale in [`specs/task-activations.md`](specs/task-activations.md).

### Impostazioni
Theme (chiaro / scuro / sistema, applied instantly) and the **Retention Period**: how long an Entry is kept, counted from its most recent Session's start. Default 60 days, minimum 30, never disableable. Expired Entries are purged whole with their Sessions at startup; individual Sessions are never purged, and the Active Entry never is. Shortening retention warns before deleting.

### Aiuto
Keyboard shortcuts and usage notes.

## Shortcuts

`Ctrl` on Windows/Linux, `Cmd` on macOS. Shortcuts act on Attività and switch there first; an open dialog suppresses them.

| Key | Action |
|---|---|
| `Ctrl+N` | New Entry |
| `Ctrl+T` | Stop the Open Session |
| `Ctrl+1/2/3` | Filter: today / yesterday / all |
| `Ctrl+S` | Go to Report and export its current filter |
| `Ctrl+W` | Close window |

## Architecture

```
lib/
  data/db/        drift schema + generated code
  features/       clients, entries, report, settings, help — view + cubit each
  shared/         theme, formatting, small widgets
```

State is `flutter_bloc` cubits, one per feature, over a single `AppDatabase`. UI atoms, tokens and theme come from [`catui`](https://github.com/filpiro/catui) (Catppuccin + Lucide). The window uses a hidden native title bar with a themed `WindowCaption` drawn above the navigator.

