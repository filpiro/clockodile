# Assemble spec.md: the phased build order

Type: grilling
Status: resolved
Blocked by: ~~04~~, ~~05~~, ~~06~~, ~~07~~, ~~09~~, ~~10~~ (resolved)
Map: ../map.md

## Question

The destination. Fold every resolved ticket into `.scratch/shadcn-migration/spec.md` so an execution session can start without re-deciding anything.

- **Dependency diff**: exactly what leaves `pubspec.yaml` (`catui`, `sonner_toast`, and whatever came in through catui's re-exports) and what arrives (`shadcn_flutter` only — no `go_router` per ticket 04, no dicebear per ticket 06), at which version. `flutter_localizations` leaves (ticket 09). Note `lucide_icons_flutter` drops out with **zero** call-site renames — shadcn bundles Lucide and every icon name we use already matches.
- **SDK floor.** `shadcn_flutter 0.0.54` requires Dart `>=3.13.0` / Flutter `>=3.47.0`. We are on 3.13.1 / 3.47.1 — compatible by one patch. `sdk: ^3.10.7` still resolves, but decide whether to bump it to `^3.13.0` for honesty, and note that anyone below Flutter 3.47.0 can no longer build.
- **Phase order** for a big-bang branch that is nonetheless committed in readable steps: root/theme → shell/routing → screens → the client-identity change → dependency removal → doc rewrites. Argue the order rather than asserting it — in particular, whether the client-identity change lands before or after the screens.
- **Per-phase done-condition**, including which tests must be green (`pws -c flutter test`) and what has to be eyeballed on Windows.
- **The files nobody will remember**: `style/components.md`, `CLAUDE.md`'s catui note, `CONTEXT.md`'s Client definition, `integration_test/app_test.dart`, `test/theme_test.dart`, and whether any ADR gets written.
- **Known risks and their fallbacks** — the "if shadcn's X cannot do Y, we do Z" list, so an execution session does not stall on a surprise.

Then graduate the remaining fog on the map, or rule it out of scope.

Use `/grilling`.

## Answer

Written: [`spec.md`](../spec.md). Decisions made in this session:

1. **SDK floor** bumped to `^3.13.0`. Flutter below 3.47.0 can no longer build.
2. **Identicon lands first** (phase 0, on today's catui UI), so every screen converts once and the Drift migration is tested alone.
3. **Per-commit bar**: `pws -c flutter analyze` clean + that phase's tests green. Full suite and integration test green only at the end of phase 5. The app may throw at runtime between phases 1 and 4; no glue is written.
4. **Report board**: geometry and tile hover stay; its tooltip becomes shadcn `Tooltip`; tiles do not use `AppListRow`.
5. **ADR 0005** "no house UI layer" is written in phase 6.
6. **Fallback rule**: build from shadcn + `widgets.dart`, never Material, record the gap in `style/components.md`; stop only for a new dependency.

Facts found: `CLAUDE.md` never named catui (no change). `README.md` does (phase 6). `integration_test/app_test.dart` taps `FloatingActionButton` 3× (phase 4).
