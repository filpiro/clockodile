# 04 — Shared date filter bar and Report toolbar controls

**What to build:** Attività and Report share one toolbar for choosing the day, and Report's own controls read as separate, proper controls.
- One date filter bar (Oggi / Ieri / Data chip, optional Tutte) used by both screens, with one date-picker helper for the allowed date range. Used later by the Entry page too.
- Report's grouped / chronological toggle becomes a segmented control with icons and tooltips, visually separate from the date chips (icon support added to `CatSegmented` in catui — see `decisions.md`; the filter bar
and Report wiring stay in the app).
- Export CSV is a square tonal icon button with a tooltip, disabled when there are no rows.
- Keyboard shortcuts for filters keep working.

**Blocked by:** None — can start immediately.

**Status:** done — f171454

- [x] Attività and Report render the same filter bar widget with identical alignment
- [x] Only one date-picker helper exists; no screen calls the stock picker with its own range
- [x] Report mode toggle is a segmented control, not chips mixed into the date chips
- [x] Export is a square icon button; disabled on empty day; Ctrl/Cmd+S still exports
- [x] Ctrl/Cmd+1/2/3 still switch filters
