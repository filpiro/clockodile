# Spec: catui → shadcn_flutter migration

Map: [map.md](map.md). Every decision below is made. The execution session builds; it does not re-decide.

**Where the detail lives** — this spec is the build order. It points at, and never restates:

- [`style/components.md`](../../style/components.md) — the mapping table, the coherence rules, the two shared widgets, `DateField`, the Italian rules, the date filter.
- [Ticket 04](issues/04-shell-and-routing.md) — shell, routing, title bar, startup.
- [Ticket 06](issues/06-client-identity-without-colour.md) + [ADR 0004](../../docs/adr/0004-client-identicon-replaces-colour.md) — identicon and the `colorHex` drop.
- [Ticket 07](issues/07-prototype-one-screen.md) — theme numbers; reference code on branch `prototype/07-attivita-shadcn` (`a50b7f1`).
- [Ticket 09](issues/09-italian-localization.md) — `ShadcnLocalizationsIt`.
- [Ticket 10](issues/10-ai-toast.md) — toast rewrite and its test changes.

## 1. Dependency diff (`pubspec.yaml`)

| Change | What |
|---|---|
| **Add** | `shadcn_flutter: ^0.0.54` (on `0.0.x`, pub's caret locks the patch: `>=0.0.54 <0.0.55`) |
| **Remove** | `catui` (git dep) — and with it the re-exported `catppuccin_flutter` and `lucide_icons_flutter` |
| **Remove** | `sonner_toast` |
| **Remove** | `flutter_localizations` |
| **Change** | `environment: sdk: ^3.10.7` → `sdk: ^3.13.0` |
| **Change** | `flutter: uses-material-design: true` → remove the line (no `Icons.*` in `lib/` today — verify with `grep -rn "Icons\." lib \| grep -v LucideIcons`) |
| **Not added** | `go_router` (ticket 04), `dicebear_*` / `flutter_svg` (ticket 06) |

- `lucide_icons_flutter` leaves with **zero** call-site renames. shadcn bundles Lucide; every `LucideIcons.*` name we use already matches. Only the import line changes.
- `crypto` stays; the identicon uses it.
- **SDK floor**: shadcn 0.0.54 needs Dart `>=3.13.0` / Flutter `>=3.47.0`. We build on 3.13.1 / 3.47.1. Anyone on Flutter below 3.47.0 can no longer build. That is accepted.

## 2. Phase order

One branch, big-bang. One commit (or a small group) per phase, in this order.

| # | Phase | Why here |
|---|---|---|
| 0 | Client identity | Plain Flutter + Drift, no shadcn. Lands on today's catui UI, so the DB migration is tested alone. Every screen after it is converted once, never twice for the dot. |
| 1 | Root, theme, toast, Italian | `ShadcnApp` is the root everything else hangs off. The toast and localisation live in `ShadcnApp`'s `builder` / delegates, so they move with the root. |
| 2 | Shell | Needs the root. Every screen sits inside it. |
| 3 | Shared widgets | `AppListRow`, `EmptyState`, `DateField`, client field. Every screen uses them; build them once before the screens. |
| 4 | Screens | Attività → Clienti → Report → Impostazioni (+ AI dialogs) → Aiuto. Attività first: the prototype already did it. Report after Clienti: it reuses the identicon label. |
| 5 | Dependency removal | Only possible when no file imports `catui` / `sonner_toast`. |
| 6 | Docs | Written last, against the code that exists. |

**Why the identicon goes first, not after the screens:** after the screens, every screen is built with the old `ClientDot` and then touched again. First, `client_dot.dart`, `colors.dart` and `colors_test.dart` are gone before any screen work starts.

**Between commits the app may not run.** From phase 1 to the end of phase 4, catui screens sit under `ShadcnApp` with no Material ancestors and can throw at runtime. That is accepted. No glue code is written to hide it.

## 3. Phases in detail

Rule for every commit: `pws -c flutter analyze` has no errors, and the tests named for that phase pass. The full suite and the integration test must pass only at the end of phase 5.

### Phase 0 — Client identity (ticket 06)

- Identicon `CustomPainter` (~30 lines, `crypto`, seed = client id), inside shadcn-free code for now; two sizes (20 / 32px).
- Drift migration drops **only** `colorHex`. Schema version +1.
- Delete: `randomClientColorHex()`, `hexToColor()`, `unknownClientColor`, `setClientColor()`, the colour control in `clients_view`, `lib/shared/utils/colors.dart`, `lib/shared/widgets/client_dot.dart`, `test/colors_test.dart`, colour in `test/fixtures.dart`.
- **Tests green**: `migration_test.dart` (must prove every client, entry and session row survives), `db_test.dart`, every test that built a client with a colour.
- **Eyeball on Windows**: run once against a **copy** of the real database file. Clients, entries, sessions all still there; identicons show in entry rows and clients list; rename a client — its identicon does not change.

### Phase 1 — Root, theme, toast, Italian

- Add `shadcn_flutter`, bump the SDK floor (section 1). `pws -c flutter pub get`.
- `MaterialApp` → `ShadcnApp` in `lib/main.dart`. Theme knobs as locked in the map's Notes: `ColorSchemes.darkSlate.green` (+ light), `radius: 0.7`, `Density.reducedDensity`, `surfaceOpacity: 1.0`, `surfaceBlur: null`. `ThemeCubit` still drives light/dark.
- `lib/shared/theme.dart` rewritten on shadcn `ThemeData`. `AppTokens` dissolves; only `formMaxWidth` stays (ticket 05).
- `await db.purgeExpiredEntries()` before `runApp`; delete the `FutureBuilder` gate (ticket 04).
- Title bar hand-rolled over `DragToMoveArea` (ticket 04).
- Toast rewrite per ticket 10: `app_toast.dart` on shadcn `showToast`, `navigatorKey` made reachable from it, `_sticky` / `_generation` / `appToastConfig` / `SonnerOverlay` deleted.
- `lib/shadcn_it.dart` + delegate per ticket 09. `localizationsDelegates: [ShadcnLocalizationsIt.delegate]`.
- **Tests green**: `test/theme_test.dart` rewritten — it now guards `primary` is the green accent in both brightnesses and `radius == 0.7`; `test/ai_toast_test.dart` per ticket 10 (harness `ShadcnApp`, "messages stack", 4s → 5s).
- **Eyeball**: none yet — screens are still catui. Only `analyze` + the two tests.

### Phase 2 — Shell (ticket 04)

- shadcn `NavigationRail`, icon-only; Impostazioni and Aiuto in a bottom group after a `Spacer`. `IndexedStack` + `setState(_index)` kept. `CallbackShortcuts` unchanged.
- **Tests green**: any shell/shortcut widget test that exists.
- **Eyeball**: after phase 4 (screens still broken here).

### Phase 3 — Shared widgets (`style/components.md` § 2)

- `AppListRow` (with the `Clickable` hover decoration from ticket 07), `EmptyState`, `DateField` (`lib/shared/widgets/date_field.dart`), client field on `AutoComplete`.
- `date_filter_bar.dart` rebuilt on the single-date model (`style/components.md` § 4); `DateFilter.all` and its pagination removed.
- **Tests green**: `entry_note_field_test.dart` and any test of these widgets.

### Phase 4 — Screens

One commit per screen, in order: Attività (`entries_view` + `entry_edit_page`), Clienti, Report, Impostazioni (+ `ai_install_dialogs`), Aiuto. Each commit updates that screen's own widget tests (no goldens).

**Report board (decided here, was fog):** `board_geometry.dart` stays as it is. Tiles keep their own `Positioned` layout and their own hover. The hand-made tooltip becomes shadcn `Tooltip`. Tiles do **not** use `AppListRow` — the board is a chart, not a list. Bars `primary` on `border` gridlines, small identicon beside each label (ticket 06).

- **Tests green per screen**: Attività — its view tests; Report — `report_board_test.dart`, `board_geometry_test.dart`; Impostazioni — `settings_ai_test.dart`; Aiuto — `help_view_test.dart`.
- **`integration_test/app_test.dart`** is updated alongside Attività and Clienti: the three `find.byType(FloatingActionButton)` taps become taps on the header button (find by its text), and `find.widgetWithText(TextField, ...)` targets the shadcn field.
- **Eyeball per screen** (on Windows, `pws -c flutter run`), both light and dark:
  - Attività: rows ~51px, hover fill, row actions visible and muted, date filter always one date, `DateField` shows `dd/mm/yy`, right-click on a text field shows Italian.
  - Clienti: identicon 32px, create/rename/delete.
  - Report: bars, tooltip, identicon beside labels.
  - Impostazioni: theme toggle flips light/dark, retention choices, AI install modal opens from the toast.
  - Aiuto: renders.
  - Always: title bar drag / minimise / maximise / close; rail selection; toast bottom-right, stacks, AI toast returns after a message closes.

### Phase 5 — Dependency removal

- Remove `catui`, `sonner_toast`, `flutter_localizations`, `uses-material-design` (section 1). `pws -c flutter pub get`.
- **Done when**: `grep -rn "catui\|catppuccin\|sonner\|package:flutter/material.dart" lib test integration_test` is empty; `pws -c flutter analyze` clean; **full** `pws -c flutter test` green; `pws -c flutter test integration_test` green on Windows.

### Phase 6 — Docs

- **ADR 0005** `docs/adr/0005-no-house-ui-layer.md`: catui is dropped for direct `shadcn_flutter`; coherence is held by `style/components.md`, not by a widget package. ~10 lines.
- **`README.md`**: remove the catui / catppuccin mentions; name `shadcn_flutter`.
- **`style/components.md`**: add every gap found during phases 1–4 (see the fallback rule), and fix what turned out wrong. Keep the `catui → shadcn` table: it explains where things went.
- **Already done, no change**: `CLAUDE.md` (never named catui), `CONTEXT.md` Client, ADR 0004.

## 4. Fallback rule

If shadcn cannot do something we did not expect: build it from shadcn parts plus plain Flutter widgets (`widgets.dart`, never Material), and write the gap into `style/components.md`. Stop and ask only if the fix needs a **new dependency**.

## 5. Known risks and their fallbacks

| Risk | Fallback |
|---|---|
| `shadcn_flutter` is `0.0.x` — any upgrade can break | Stay pinned to `0.0.54`. Upgrading is a separate effort. After any upgrade, diff `lib/l10n/shadcn_en.arb` (ticket 09). |
| Name clashes: shadcn exports `Scaffold`, `Card`, `Tooltip`, … like Material | Never import `package:flutter/material.dart`. Use `package:flutter/widgets.dart`. If one file truly needs both, `hide` the clashing names. |
| The Drift migration loses data | `migration_test.dart` proves rows survive. Before the first Windows run, copy the real DB file aside. |
| A shadcn string we show is missed in `ShadcnLocalizationsIt` | It shows English, not a crash (we extend `ShadcnLocalizationsEn`). Add the override when seen. |
| `NavigationRail` has no bottom slot | Column: rail items, `Spacer`, second group (ticket 04). If the rail refuses to share its column, use two `NavigationRail`s stacked. |
| shadcn `Tooltip` cannot anchor to a `Positioned` board tile | Keep the board's own tooltip, restyled with `colorScheme` roles. |
| `destructiveIcon` (filled red square per row) looks too loud | Follows the written rule; build it as written. Raise it at the Attività eyeball — changing it is a `style/components.md` edit, not a stall. |
| AI toast with `Duration(days: 365)` still expires, or the timer misbehaves | Ticket 10's close-and-raise on each state change re-creates it; no further fallback needed on a desktop session. |
| App throws at runtime between phases 1 and 4 | Expected (section 2). Judge only `analyze` + that phase's tests until phase 4 ends. |
| Material-only package widgets (`window_manager`'s `WindowCaption`) | Already replaced by the hand-rolled title bar. Any other one found: same fallback rule. |
