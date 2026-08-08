# Report — Session Normalization & Export

Terminology per `CONTEXT.md`: **Session** = a start/end span belonging to one Entry; **Report** = the portal-ready normalized view defined here.

## Purpose

The app records real, minute-precise Session timestamps (e.g. `9:51–10:13`). The portal where time is manually entered only accepts quarter-hour increments. The Report page generates a **normalized, portal-ready version** of one day's Sessions, rounding all timestamps to the nearest 15 minutes while preserving continuity between consecutive Sessions.

This is a **report/preview**, not a correction of stored data. Stored Sessions are never modified. The user reads the Report and types it into the portal, hand-adjusting anything that looks off. It must save time in the common case, not be perfect in every edge case.

## Page (new NavigationRail destination "Report")

- Filters: **Oggi / Ieri / Data** (picker). No "Tutte" — a Report is strictly one day.
- Day membership: a Session belongs to the Report iff its **start** falls on the chosen day (same convention as the entries list). Sessions of the same Entry from other days are ignored.
- The Open Session is always excluded.
- View mode, a radio pair of chips: **"Raggruppa per cliente"** (default) / **"Ordine cronologico"** — presentation only, see Output order. Not persisted across restarts.
- Preview list: one row per normalized Session — client, normalized `start–end`, duration, note; real times shown as secondary text for eyeballing the rounding.
- **Esporta CSV** button exporting exactly the previewed rows.
- Clicking a row copies its Entry note to the clipboard (snackbar "Nota copiata"); rows without a note are not tappable.
- The old raw export on the Attività screen is removed; `Ctrl+S` switches to Report and exports its current filter.

## Normalization

Input: the day's closed Sessions sorted by start. The chain is always chronological across all clients — the view mode has no effect on normalization.

All timestamps are **truncated to whole minutes** before any rounding — stored Sessions carry seconds, but the Report reasons at minute precision, matching what the UI displays. (Otherwise an end shown as `9:15` but stored as `9:15:47` would ceil to `9:30`.)

Treat the day as a chain of **boundary points**; where `end_i` and `start_(i+1)` are (nearly) the same instant they are ONE shared boundary, which is what keeps contiguous Sessions contiguous after rounding — no overlap, no gap.

### Boundary classification

For each consecutive pair, gap = `start_(i+1) − end_i`:

- **Contiguous** (gap < 5 minutes — hard-coded constant, including negative gaps from the app's allowed overlaps): one shared boundary at the **midpoint** of the two instants.
- **Real gap** (≥ 5 minutes): two independent boundaries; the gap may shrink but is never invented or exaggerated.

### Rounding rules

| Boundary | Rule |
|---|---|
| Interior shared boundary | nearest quarter (half-up) |
| First start of the day | floor |
| Last end of the day | ceil |
| End before a real gap | ceil |
| Start after a real gap | floor |

### Worked examples

**A — contiguous:** `9:51–10:13` + `10:14–10:40` (gap 1 min) → shared boundary `10:13/10:14` → midpoint → nearest = `10:15`; day-start floor `9:45`; day-end ceil `10:45` → `9:45–10:15`, `10:15–10:45`. No overlap, no gap.

**B — real gap:** end `10:13`, next start `10:41` (28 min) → `10:15` / `10:30`. Gap shrinks 28→15 min; acceptable.

## Output order

One row per normalized Session, always — Sessions are never merged, even same-client contiguous ones (they simply share a rounded boundary).

Rows are grouped by client — clients in order of first appearance in the day, each client's Sessions chronological. This is the one order, in both view modes and in the CSV; the board positions its tiles by time and so is indifferent to it.

## View modes

- **Raggruppa per cliente** (default): the list above, with a client header per run.
- **Ordine cronologico**: the same rows as a vertical time board — one full-width column on a wall-clock axis bounded by the day's content, each Session a tile whose height *is* its normalized duration at a fixed 1.6 px/minute. Geometry uses normalized times only; real times live in the tooltip.

## CSV

Columns: `client, start, end, duration_hours, note` — normalized times, duration computed from them, note from the owning Entry. Row order as above — identical in both view modes.

## Out of scope (v1, hand-fixed in the portal when needed)

- Work-hour context (`earliest_start` / `latest_end`, lunch window): **not built at all** — no settings, no clamping, no flags. Out-of-range roundings are visible in the preview. Add only when clamping logic exists.
- Very short Sessions distort (15-min resolution floor). No special handling.
- Daily total not guaranteed to equal real hours or 8h.
- Sessions spanning lunch or midnight: output as-is.
