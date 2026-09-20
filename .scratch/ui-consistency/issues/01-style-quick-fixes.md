# 01 — Style quick fixes: inputs, FAB clearance, small labels

**What to build:** Visual loose ends are gone across the app.
- Every text input (Cliente, Nota, retention days, client dialogs) uses the same outlined border with the house corner radius, set once in the app theme instead of per field.
- The Attività and Clienti lists leave room under the FAB, so the last row and its hover actions are never covered. "Carica altre" is centred with breathing room.
- The "in corso" badge and the Help key-caps are one reusable tag label that uses the house radius tokens, not hard-coded 10/6.
- The client autocomplete popup has rounded corners and the same highlight colour as hovered list rows.
- The AI status strip uses theme text styles and stays a thin strip, not a 48px bar.

**Where:** the input decoration theme and the tag label are built in catui (see
`decisions.md`), then adopted here against a pinned catui ref. The FAB clearance,
autocomplete popup and AI status strip are app-side.

**Blocked by:** None — can start immediately.

**Status:** done (catui `1d1148f`, app `d4c61c3`)

- [x] All text inputs render outlined with the house radius; no field sets its own border
- [x] Scrolled to the bottom, the last row of Attività and Clienti is fully clickable, including hover actions
- [x] "in corso" badge and Help key-caps share one tag label widget; no hard-coded radii remain there
- [x] Autocomplete popup corners match dialogs; highlighted option matches list hover colour
- [x] AI status strip height is visibly thinner and its text uses the theme text style
- [ ] Light and dark themes both checked — needs a human eye on the running app

Note: the Clienti FAB padding and the Nota field's border removal sit in
files the ticket-03 agent was editing at the same time; those two lines ride
along with its commit rather than `d4c61c3`.
