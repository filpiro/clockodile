# 01 — Report: "Ordine cronologico" day board

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## What to build

The Report screen currently offers one presentation choice: a "Raggruppa per cliente" toggle that, when switched off, falls back to a flat chronological list. Replace that toggle with a radio pair — **"Raggruppa per cliente"** and **"Ordine cronologico"** — behaving like the day filter chips: exactly one selected at any time, never zero. "Raggruppa per cliente" stays the default; the old flat list is dropped, since the new mode supersedes it.

"Ordine cronologico" renders the same day's normalized Report rows as a **vertical time board**: a single full-width column on a wall-clock axis, each Session drawn as a tile whose height *is* its normalized duration, against an hour reference gutter on the left. It answers "what did my day actually look like" at a glance — shape and gaps, not just a list of numbers.

The board is presentation only. It changes nothing about which Sessions are included, how they are normalized, the day total, or the CSV export — all three stay identical in both modes.

### Board geometry

- Tiles are positioned and sized by **normalized** times only (the same times the total and the CSV use). Real Session times appear in the tooltip, never in the geometry.
- Fixed scale, **1.6 px per minute** — an hour is 96px, a quarter 24px. No zoom control.
- Axis is bounded by the day's content: from the first row's normalized start floored to its hour, to the last row's normalized end ceiled to its hour. Never a full 00:00–24:00 axis.
- Left gutter (~56px) carries `HH:00` labels, with a hairline gridline across the full board width at each hour. Hours only — no quarter ticks.
- Gaps between non-contiguous Sessions are bare background. Nothing is drawn in them.
- No "now" marker.

### Tile

- Neutral surface fill with a 4px client-color left border. Body text stays readable in both themes; no per-tile contrast maths, no colored fills.
- Content is a **clipped column**, client name first, then `HH:MM–HH:MM (h:mm)`, then the note. Height alone decides how much survives — a short tile ends up showing only the client name. There is no minimum tile height: a tile is always true to its duration.
- Tooltip carries everything a short tile clips: client, normalized range, duration, real range, note.
- Interaction parity with the list rows: tap copies the note (rows without a note aren't tappable), hover highlights.
- Contiguous Sessions share a boundary and so touch exactly. A 1px inner border in the surface color keeps them reading as two tiles without altering the geometry.

### Edge cases

- Zero-length and negative-length rows exist today (a shared boundary can land before the row's start) and are already error-colored in the list. On the board they render as a 2px full-width error-colored hairline at their normalized start, with the tooltip as their only text. They are never hidden.
- Normalization guarantees tiles never overlap (each row's end is the next row's start). Assert that in debug rather than building a lane/column fallback for a case the normalizer cannot produce.
- An empty day keeps the existing empty state in both modes — no gutter, no axis.

### Notes for the implementer

- The mode is not persisted across restarts, matching today's grouping toggle.
- Extract the board geometry (axis range, tile offset, tile height) as pure functions next to the existing normalization logic and unit-test them there. No widget test — a stack of positioned boxes tests the framework, not this feature.
- Update the Report screen table in the UI component inventory. The domain glossary and the ADRs need no change: view modes are presentation, and the Report term already states what the data is.

## Acceptance criteria

- [ ] "Raggruppa per cliente" and "Ordine cronologico" are mutually exclusive chips; selecting one deselects the other and neither can be deselected into an empty state.
- [ ] "Raggruppa per cliente" is selected on launch and behaves exactly as it does today.
- [ ] The grouping flag is gone from the Report state, replaced by a two-value mode; nothing in the codebase still reads a boolean grouping flag.
- [ ] Switching mode changes only the presentation: the day's rows, the day total footer, and the exported CSV (contents and order) are identical in both modes.
- [ ] The board's axis starts at the first row's normalized start floored to the hour and ends at the last row's normalized end ceiled to the hour.
- [ ] Every hour on the axis has a label in the left gutter and a hairline gridline across the board; no quarter-hour ticks.
- [ ] A tile's height equals its normalized duration at 1.6 px per minute, with no minimum-height clamp.
- [ ] A tile too short for its full content shows the client name and nothing else, clipped — not an overflow error, not an ellipsised jumble.
- [ ] Every tile has a tooltip carrying client, normalized range, duration, real range and note.
- [ ] Tapping a tile with a note copies the note and confirms it, matching the list rows; a tile without a note is not tappable but still highlights on hover.
- [ ] Two contiguous tiles are visually separable while their combined height still equals their combined duration.
- [ ] A zero-length or negative-length row is visible on the board as an error-colored hairline with a working tooltip.
- [ ] Board geometry is covered by unit tests over pure functions, including a single-row day, a day with a gap, and a zero-length row.
- [ ] An empty day shows the existing empty state in both modes.
- [ ] The UI component inventory's Report table describes both modes and the board.
