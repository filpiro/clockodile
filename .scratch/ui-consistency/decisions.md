# Decisions — ui-consistency

## Where shared UI lives: catui, not the app

**Decided by the user, 2026-09-16.** House-generic pieces are built in the `catui`
package (https://github.com/filpiro/catui, `main`), not copied into
`lib/shared/widgets` first. Only pieces that know about Clockodile's domain
(Client, Entry, Session, the date filters) stay in this repo.

In catui:

- input decoration theme (outlined, house radius) — ticket 01
- tag label (badge / key-cap) — ticket 01
- section header (leading, title, trailing) — ticket 02
- confirm dialog, text input dialog, snackbar helper — ticket 03
- `CatSegmented` icon support — ticket 04
- date-time field — ticket 05
- spacing tokens + page frame — ticket 06
- hover fade helper + focus-reveal row actions (with `HoverTile` moving over) — ticket 07

Stays in the app: `ClientDot`, the date filter bar and its picker helper, the
Report toolbar wiring, and the Settings page layout.

## Workflow per ticket

catui is a git dependency, so a ticket that touches both repos lands in this order:

1. Change catui, keeping the old API in place if anything already uses it.
2. Point `pubspec.yaml` at the new catui commit (pin the ref, don't leave `main`
   floating mid-ticket).
3. Adopt it in Clockodile and delete whatever it replaced.

A ticket is done only when both repos are committed and the app builds against
the pinned catui ref.

## Review round 2 — layout, colour and surfaces

**Decided by the user, 2026-09-20**, after a pass over the running app. Tickets
for this round are not written yet; the user asks for them when ready.

### Width: lists and settings stretch, prose and forms cap

A page fills the window unless its content is prose or a single-column form.
`AppTokens.formMaxWidth` stays, but only Entry edit and Help use it. Settings
loses its cap.

Inside a stretched page the *section* stretches, never the control: a button, a
`CatSegmented` or a switch keeps its intrinsic width and sits left, or right in
a `spaceBetween` row. Stretching a three-way theme picker across 1600px is the
bug, not the fix.

### One right edge

A group header's trailing value (the day total) and a row's trailing actions end
at the same x. With the tile margin below, both text columns run from
`tileMargin + gutter` to `tileMargin + gutter`, so the header reads as a column
label rather than floating mid-row.

### List rows: inset fill, real contrast

The hover fill is inset horizontally (`tileMargin`, 8) and rounded (`tileRadius`,
8 — not the button radius, a 56px row at 10 reads as a pill). The fill colour is
a new catui theme value `hoverSurface`, mapped to `flavor.overlay0`: the old
`surface2` is one step off the page background and disappeared.

`hoverSurface` is for neutral rows only. The Report board keeps its own
client-coloured hover; a grey wash would mud the client identity.

### Settings anatomy

Two new catui widgets, because the Settings page's mess was each block
re-inventing its own spacing:

- `CatSection({title, description, child})` — larger title, optional
  `bodySmall` description, body spacing, and a light `outlineVariant` bottom
  border. One section = title + body.
- `CatSettingRow({title, description, trailing})` — label left, control right,
  `spaceBetween`. Replaces the `SwitchListTile` with zeroed padding.

`CatSectionHeader` stays as it is, for list day-headers.

### Retention is a choice, not a number

Three segments — 30, 45, 60 — written on tap. No free-text field, no `Salva`
button, no fallback for an out-of-set stored value: this is a single-user app and
the stored value is already 45. The confirm before shrinking the Retention Period
stays, because shrinking still destroys Entries.

### Toast: `sonner_toast`, in the app, not in catui

The bottom strip becomes a sonner-style toast, bottom **centre**, fixed 380 wide,
single slot (a new toast replaces the outstanding one, as `catSnack` already
did), with an always-present close X — swipe alone is a touch gesture and this is
a desktop app.

`sonner_toast` supplies only the overlay, stacking and motion; it ships no UI. So
it is an app-level dependency, configured and used in Clockodile like the
autocomplete, and never a `catui` dependency. The card *inside* it is built from
catui tokens and the shared surface recipe.

`ai_status_strip.dart` is deleted: a widget that renders nothing 95% of the time
is a side effect, not a widget. A `BlocListener` on `AiCubit` at the app shell
shows the toast, sticky (no duration) with its action button, and keeps
`navigatorKey` for the dialogs that action opens.

`catSnack` stays in catui for other consumers; Clockodile stops importing it.

### One surface recipe for dialog and toast

Dialogs get a catppuccin surface: `mantle` background, 1px `outlineVariant`,
`AppTokens.radius`. catui exposes that recipe (`catSurfaceDecoration`) so the
app's toast card can wear the same skin; `dialogTheme` reads it too. Without a
shared recipe the two match until one of them changes. The date picker is out of
scope for this round.

### Elsewhere

- Entry edit: the gap between the end-time field and the delete icon goes to 16,
  so a hovered icon's 40px disc stops touching the field. App-side, no new token.
- `settings_ai_test.dart` and `ai_status_strip_test.dart` are rewritten with the
  widgets they cover; they are the only proof the AI error states still reach the
  screen.
