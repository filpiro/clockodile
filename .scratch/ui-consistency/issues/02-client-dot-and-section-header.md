# 02 — Shared client dot and section header, per-client totals in Report

**What to build:** Identity dots and group headers look the same on every screen.
- One client dot widget (size variant + fallback colour for an unknown hex) replaces every ad-hoc coloured circle: Attività rows, active Entry, Clienti rows (tappable size), Report client headers, colour-picker preview, autocomplete options.
- One section header (optional leading, title, optional trailing) replaces the Attività day header, the Report client header and the form section labels ("Sessioni", "Tema", "AI"), with one spacing rule.
- Report grouped mode shows each Client's normalized total in its header's trailing slot, like the day total in Attività. The footer's overall total stays.

**Where:** the section header is built in catui (see `decisions.md`); the client dot
stays in the app because it knows about Client colours.

**Blocked by:** None — can start immediately.

**Status:** ready-for-human

- [x] No screen builds a client colour circle directly; all use the shared dot
- [x] Day headers, client headers and form section labels share one widget and identical padding/typography
- [x] Report grouped mode shows a per-Client normalized total that matches the sum of its rows
- [x] Sum of per-Client totals equals the footer total (small test)

## Comments

**2026-09-16 — implemented, ready for a human look.**

catui `1d1148f` (pushed to `main`): `lib/src/section_header.dart` adds
`CatSectionHeader` — optional leading, title, optional trailing. Two padding
constants, one rhythm: `listPadding` (16/16/16/4) keeps the list gutter,
`.inline` drops the gutter for an already-padded column (forms). Typography is
`titleSmall`, per catui's "no type scale of its own" rule in DESIGN.md. The
gallery's own `_Section` now delegates to it; `test/section_header_test.dart`
covers the optional slots and the shared rhythm.

clockodile `c254c0e`, with `pubspec.yaml` pinned to `1d1148f`:

- `lib/shared/widgets/client_dot.dart` — `ClientDot` with a closed size ladder
  (`small`/`normal`/`tappable`/`large`) mapped onto the existing
  `AppTokens.dotRadius*`, an optional `onTap` for the Clienti row, and a
  `ClientDot.color` variant for the colour picker's live preview (no stored hex
  yet). The only `CircleAvatar` left in `lib/` is inside it.
- The unknown-hex fallback went into `hexToColor` itself rather than the widget,
  so every caller is covered (the board tiles too) and the autocomplete's
  `'#888888'` default could go away. Bad, short or null hex → `unknownClientColor`.
- Headers adopted at all five sites: Attività `_DayHeader`, Report `_ClientHeader`,
  "Sessioni", "Tema", "AI". The `SizedBox` gaps those labels used to carry are
  gone — the header owns the gap above now.
- `clientTotals()` in `normalize.dart` sums `normDuration` per client id and feeds
  each Report header's trailing slot. Rows reach the view through `groupByClient`
  in every mode, so a client's rows are always one contiguous run and the header
  total is the sum of exactly the rows under it. Footer total untouched.

Checks: `dart analyze` clean in both repos, full suite 128 passing,
`flutter build windows --debug` succeeds. Two-axis review found no standards
violation and no spec gap.

**Caveat on attribution:** a concurrent session was working tickets 01/03 in the
same worktrees. It swept this ticket's `report_view.dart` changes into its own
commit `0ba1779` and pinned `pubspec.yaml` to the catui ref. The content is
right; the commit boundaries are mixed.
