# 03 — Two-column Entry editor

**What to build:** The create / edit Entry page uses the width it has. Content sits in two columns, capped at 1120 px and centred. Left column: Cliente and Nota. Right column: everything about time — Inizio on create, the Sessioni list on edit. Each column scrolls on its own. Default page padding (24). A shadcn vertical divider separates the columns. When the page is too narrow for two columns (below about 720 px of content width), it falls back to one column in the order Cliente, Nota, then dates. The Nota field grows from 3 to 6 lines (was 8), then scrolls. The app's default window grows to 1100 × 720 so two columns show out of the box.

**Blocked by:** None — can start immediately.

**Status:** done

**Implemented in:** `cbca41d` — `flutter analyze` and all 161 tests pass.

**Recommended model:** GPT-6 Sol (`gpt-6-sol`), high effort — independent scrolling columns plus a width breakpoint are easy to get subtly wrong (unbounded heights, divider height, focus/shortcut behaviour).

**Previous recommendation:** Sonnet 5, high effort — independent scrolling columns plus a width breakpoint are easy to get subtly wrong (unbounded heights, divider height, focus/shortcut behaviour).

**Suggestion:** Base the breakpoint on available content width after page padding; check scrolling and keyboard focus at both sides of the breakpoint.

- [x] Wide window: two columns, left Cliente + Nota, right Inizio / Sessioni, vertical divider between
- [x] Content capped at 1120 px and centred on very wide windows
- [x] Each column scrolls independently when its content overflows
- [x] Narrow window: single column, order Cliente, Nota, dates
- [x] Nota grows 3 → 6 lines, then scrolls; AI summary button still sits inside the field's bottom-right
- [x] Default window size is 1100 × 720 and shows two columns on first launch
- [x] Ctrl/Cmd+S save, Annulla / Salva, session delete and validation messages still work
