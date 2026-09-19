# 07 — Shared hover fade, row actions reachable by keyboard

**What to build:** Hover feedback comes from one place, and row actions are never invisible-but-focused.
- One hover-fade helper drives the highlight for list rows and Report board tiles (same duration and colours as today).
- A row's hidden actions (edit, delete, Termina) also appear when focus is inside the row, so Tab never lands on an invisible button.

**Where:** the hover-fade helper is built in catui, and `HoverTile` moves there with
it (see `decisions.md`) — it is house-generic and already sits next to the row
action buttons catui owns.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] List rows and board tiles use the same hover helper; visual hover unchanged
- [x] Tabbing into a row reveals its actions; tabbing out hides them
- [x] Mouse hover behaviour unchanged (no row shifting, actions not clickable while hidden)
- [x] Widget test: focusing a row action makes it visible
