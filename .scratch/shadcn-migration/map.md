# Map: catui → shadcn_flutter migration

Label: `wayfinder:map`

## Destination

A locked migration plan at `.scratch/shadcn-migration/spec.md`: the component-by-component mapping, the theme translation, the shell/routing shape, the client-identity change, and a phased build order — enough that execution sessions can build it without re-deciding anything. Planning only: no production code changes in this map beyond throwaway prototypes.

## Notes

- **Domain**: Clockodile, single-user local-only desktop time tracker (Flutter, Windows). Read `CONTEXT.md` and `docs/adr/` before deciding anything domain-shaped.
- **Skills every session consults**: `/shadcn-flutter` (offline docs live at `.claude/skills/shadcn-flutter/`), `/grilling`, `/domain-modeling`, `/research`, `/prototype`.
- **Environment**: Flutter is on Windows, agent runs in WSL. Every Flutter/Dart command goes through `pws -c ...`. See `CLAUDE.md`.
- **Current UI surface**: ~2000 LOC — 5 screens (`entries`, `clients`, `report`, `help`, `settings`), `entry_edit_page`, 5 shared widgets, plus the `catui` git dep (12 src files) and `sonner_toast`.
- **ShadcnApp theme knobs, given and fixed**: themeMode Dark, baseColors Slate, accentColors Green, radius Rounded (`0.7`), density Reduced, scaling Default, surfaceOpacity Solid (`1.0`), surfaceBlur off (`null`) — numbers locked by ticket 07.

## Decisions so far

- **Destination is a plan, not a build** — the map ends at `spec.md`; execution is a separate effort.
- **No house layer** — `catui` is dropped as a dependency and *not* replaced by an in-repo equivalent. Screens call shadcn primitives directly. Coherence (interaction, spacing, states) is held by written convention instead of by widgets.
- **Big-bang cutover** — `ShadcnApp` at the root and every screen converted in one branch. No Material interop glue is written.
- **Tests fixed per screen** — each screen's migration updates its own widget tests. No goldens.
- **Light/dark toggle survives** — `ThemeCubit` and the Settings row stay; both shadcn schemes are built from the same knobs, Dark is the default.
- **shadcn look wins** — shadcn's default spacing, typography and component appearance is accepted wherever it differs from today's catppuccin skin.
- **Shell adopts shadcn idioms** — the 64px icon rail / `IndexedStack` shape is not preserved for its own sake.
- **Client colour is dropped for generated identicons** — `catppuccin_flutter` does not return as a direct dep; client identity becomes a generated identicon avatar (dicebear later rejected, see ticket 06).
- [Which shadcn component covers each thing we currently put on screen](issues/03-component-inventory-match.md) — candidates inventoried: `AutoComplete` is the only free-text client field, `Clickable`+`Basic` the hover row, and shadcn's toast can be dismissed by handle but never persists or updates in place; twelve shapes (empty state, FAB, list row, segmented control, date+time field, …) have no component and must be hand-composed.
- **[dicebear in Dart/Flutter: what it renders and what deps it drags in](issues/02-dicebear-dart-facts.md)** — dicebear is offline pure Dart (no HTTP), needs three deps (`dicebear_core`/`dicebear_styles`/`flutter_svg`), identicon is CC0 with no attribution — but `crypto` + `CustomPainter` could do it in ~30 lines with zero new deps.
- [shadcn_flutter setup facts: version, platform, ShadcnApp, and the theme knobs](issues/01-shadcn-app-and-theme-facts.md) — 0.0.54 needs Flutter >=3.47.0/Dart >=3.13.0 (we're on 3.47.1/3.13.1, compatible); `ShadcnApp` is a 1:1 `MaterialApp` swap keeping `builder`/`shortcuts`/`navigatorKey`; theme is `ColorSchemes.darkSlate.green` + `Density.reducedDensity` + `surfaceOpacity: 1.0`, with "Rounded" radius and "Medium" blur having no sourced numeric value; no blockers, but 0.0.54 drops Material so `Scaffold`/`IconButton`/`WindowCaption` must go and `ColorScheme` has no `surface` role.
- [What is the app shell, and how does go_router drive it](issues/04-shell-and-routing.md) — **no go_router**: nav stays `setState(_index)` + `IndexedStack`, the editor stays a `Navigator.push`; shell becomes shadcn `NavigationRail` (icon-only, Settings/Aiuto bottom group), layers stay in `ShadcnApp.builder`, `WindowCaption` hand-rolled over `DragToMoveArea`, and the purge `FutureBuilder` is deleted in favour of `await` before `runApp`.

- [The mapping table, and the conventions that replace the house layer](issues/05-component-mapping-and-coherence.md) — the full table and the coherence rules now live in [`style/components.md`](../../style/components.md), rewritten; `AppTokens` dissolves into `ThemeData` leaving `formMaxWidth` as the repo's only shared constant; two shared widgets total (`AppListRow`, `EmptyState`); row actions are always visible and muted, so the hover-reveal composition is deleted; sections stay flat, the FAB is deleted for a header button, segmented controls become mutually-exclusive `Toggle`s, and the date filter drops `Tutte` for an always-one-date model.
- [Client identity after colour: dropping colorHex for identicons](issues/06-client-identity-without-colour.md) — own ~30-line `CustomPainter` identicon seeded by client id, no dicebear; `colorHex` column dropped by migration with all other rows kept; two sizes (20/32px); report keeps `primary` bars with identicon beside the label; ADR 0004.
- [Spike Attività on shadcn to prove the theme and the mapping](issues/07-prototype-one-screen.md) — mapping holds with 3 doc fixes (no `theme.padding*`, Toggle not `compact`, `DatePicker` is a dialog); rows get denser (51.5px vs ~72); hover survives via a `Clickable` decoration in `AppListRow`; no `ComponentTheme` needed; radius locked `0.7`, blur off because it is invisible behind Solid.
- [Italian: shadcn ships English strings only](issues/09-italian-localization.md) — in-repo `ShadcnLocalizationsIt extends ShadcnLocalizationsEn` overriding only the ~40 strings we show (pickers, Cancel/Save, text-field context menu); `DatePicker` replaced by a shared `DateField` over `ObjectFormField` showing `dmyShort()` because shadcn's US date order is an unoverridable extension; `flutter_localizations` removed.
- [The AI toast: persistent, self-updating, opens dialogs](issues/10-ai-toast.md) — no live counter existed (progress is in the install modal); shadcn's native stack replaces our sticky/hand-back bookkeeping; shadcn defaults (bottomRight, 320px, stack of 3); helper borrows `navigatorKey.currentContext` so the 7 callers do not change; AI toast is closed and raised again per state with `Duration(days: 365)`; `navigatorKey` hand-off stays (confirmed from source: toast builds above the Navigator).
- [Assemble spec.md: the phased build order](issues/08-write-the-spec.md) — **destination reached**: [`spec.md`](spec.md) written; identicon first, then root/theme/toast/Italian → shell → shared widgets → screens → dep removal → docs; `sdk: ^3.13.0`; report board keeps its geometry with a shadcn `Tooltip`; ADR 0005 in the docs phase.

## Not yet specified

Nothing. The way is clear.

## Out of scope

- Rebuilding or rewriting `catui` on shadcn primitives — ruled out by the no-house-layer decision. If a shared package is ever wanted again, it is a fresh effort.
- Any change to timer, session or entry domain logic beyond what dropping client colour forces — **with one named exception**: the date filter collapses to a single `DateTime day` and `DateFilter.all` plus its pagination is removed, decided in ticket 05. Runtime state only, no schema change.
- Mobile and web targets. This is a Windows desktop app.
- Golden-test infrastructure.
- What happens to the `catui` repo itself once this app stops consuming it — a question for that repo, not this app.
- Per-screen ticket slicing — belongs to the execution effort that starts from `spec.md`.
