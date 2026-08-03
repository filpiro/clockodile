# Entry Activation — Multi-Session Model

Terminology per `CONTEXT.md`: **Entry** (Attività) = named work item against one Client, with a note. **Session** = a start/end span belonging to one Entry. **Open Session** = `end IS NULL`, at most one system-wide, derived. **Active Entry** = the Entry owning the Open Session.

## Current behavior
Each Entry has a single `startTime`/`endTime` pair. Starting a new Entry closes the open one. No way to add time to an existing Entry except editing its times.

## New behavior

An Entry's time is the sum of its Sessions. Sessions can be non-contiguous and span multiple days.

### Core rule
At most one Session system-wide is open (`end IS NULL`). Its owning Entry is the Active Entry (radio-button behavior).

### Tapping an inactive Entry (list row tap)
- Close the Open Session if any (`end = now`), open a new Session under the tapped Entry (`start = now`, `end = NULL`) — one atomic transaction (guards double-tap / races).
- Identical for first activation and reactivation. Reactivation always inserts a **new** Session row; past Sessions are never reopened or edited by activation. No time constraints — an Entry idle for days can be reactivated.

### Tapping the Active Entry
No-op.

### Stop
The "Termina" button on the pinned tile closes the Open Session (`end = now`), no new Session opened — zero active. Atomic close-only operation. Manual close also possible via edit dialog (below).

## Data model
- New table `Sessions(id, entryId FK, start, end nullable)`. `Entries` loses `startTime`/`endTime`, keeps `clientId`, `note`.
- Invariant: every Entry has ≥ 1 Session (born with one; last Session not deletable — delete the Entry).
- Migration (schema v3): each existing Entry's `startTime`/`endTime` becomes its single Session row; an existing open entry becomes an Open Session.

## Creation (FAB "Nuova attività")
Unchanged semantics: creates an Entry with one Open Session (start editable, default now, backdating allowed), auto-closing any previous Open Session. New Entries are born active; no end field on create.

## Edit dialog
- Entry level: client, note.
- Sessions listed: closed Sessions' start/end editable (end ≥ start; no overlap validation, consistent with existing overlaps-allowed decision) and deletable, except the last remaining one.
- Open Session: shows start (editable); end starts empty and **can** be set — manual close with custom timestamp (forgot-to-stop case). Once closed, never clearable back to open.

## List display
- Day grouping is Session-based: an Entry appears under **each day** it has closed Sessions; its row shows that day's summed duration and session count (e.g. "2h 10m · 3 sessioni"). Day header totals sum that day's Sessions.
- Pinned Active Entry tile shows both: current Session elapsed and Entry total accumulated (e.g. "In corso · sessione 0:42 · totale 3:15"). Running Session is counted only in the pinned tile, never in day rows — no double counting. A reactivated Entry may appear pinned and in past day rows simultaneously.
- Row tap = activate (was: edit). Edit moves to a hover pencil icon beside the existing delete icon.

## Retention
Purge whole Entries (cascade Sessions) when the **newest** Session's start is older than the Retention Period. The Active Entry is never purged. Sessions are never purged individually — totals never silently shrink.

## Export (CSV)
One row per closed Session, same columns (`client, start, end, duration_hours, note` — note from the owning Entry); date filter applies to Session start; Open Session excluded. Note: export gets reworked in a next feature — keep this change minimal.

## Total time
`sum(end - start)` over closed Sessions + elapsed of the Open Session if owned by the Entry.
