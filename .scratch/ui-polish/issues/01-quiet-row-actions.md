# 01 — Quiet row actions

**What to build:** In the Entries list and the Clients list, a row's edit and delete actions stay out of the way until the user reaches for them. They are small ghost icon buttons, shown only while the row is hovered or while one of its buttons has keyboard focus. Delete turns destructive-red only when the pointer is on the delete icon itself — today hovering the row can already colour it, which is a bug. Clients gain an edit (pencil) action that opens the existing rename dialog, so both lists offer the same pair. On the running Entry's row, the pencil follows the same hide-until-hover rule, but "Termina" stays always visible.

**Blocked by:** None — can start immediately.

**Status:** done

**Recommended model:** Sonnet 5, medium effort — the red-on-row-hover bug may need digging into how shadcn_flutter propagates widget state (hover) from the row to nested buttons.

- [x] Edit and delete are hidden at rest, appear on row hover, and hide again when the pointer leaves
- [x] Tabbing into a row's action button makes the actions visible
- [x] Buttons are visibly smaller than today (small size, dense icon density), ghost style
- [x] Delete icon is red only while the pointer is over the delete button, never from row hover alone
- [x] Clients rows show a pencil that opens rename; tapping the row still renames too
- [x] Running Entry row: pencil hides until hover, "Termina" always visible
- [x] Hidden buttons take no clicks (no invisible hit targets)
- [x] Deleting a row does not leave another row showing its actions (existing keyed-row behaviour kept)
