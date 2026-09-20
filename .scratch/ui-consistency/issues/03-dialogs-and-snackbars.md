# 03 — Shared dialogs and snackbars

**What to build:** Every confirmation, text prompt and feedback message behaves the same.
- One confirm dialog helper (title, optional body, confirm label, danger or neutral) used by: delete Entry, delete Client, lower retention, install AI, update AI files, delete AI.
- One text input dialog used by create Client and rename Client: both labelled "Nome", Enter submits, confirm disabled while the name is empty, focus lands in the field.
- One snackbar helper: a new message replaces the current one instead of queueing; failures show a short Italian message, not a raw exception string.

**Where:** all three helpers are built in catui (see `decisions.md`); the app passes
its own Italian titles and labels.

**Blocked by:** None — can start immediately.

**Status:** done (catui `76ccf3e`, app `0ba1779`)

- [x] All six confirm flows use the shared confirm dialog; danger ones use the red confirm, others the filled one
- [x] Create and rename Client look identical apart from title and initial text
- [x] Enter confirms the Client name dialog; empty name cannot be confirmed
- [x] Triggering two snackbars quickly shows only the latest
- [x] No snackbar displays a raw exception (`$err`) to the user

## Comments

**2026-09-16 — implemented.** catui gained `catConfirm`, `catTextInput` and
`catSnack` (`lib/src/dialogs.dart`, widget tests in `test/dialogs_test.dart`);
the app pins that ref and adopts all three. The Entry delete confirm landed in
`d4c61c3` alongside ticket 01 — the two efforts ran at the same time — the rest
in `0ba1779`.

Snackbar failure text no longer interpolates the exception: create/rename
collisions say the name is taken, save and export failures say what failed.
Two dialogs deliberately stay bespoke: the AI download modal (progress, not a
question) and the client colour picker (a slider, not a text field).
