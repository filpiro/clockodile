# Client identity after colour: dropping colorHex for dicebear identicons

Type: grilling
Status: open
Blocked by: ~~02~~ (resolved — see `../research/02-dicebear.md`)
Map: ../map.md

## Question

This is a domain change riding along with a UI migration, so it gets decided deliberately. `CONTEXT.md` currently defines **Client** as having "a name (unique, case-insensitive) **and a color**". Colour reaches: `Clients.colorHex` (a non-nullable `TextColumn`), `randomClientColorHex()`/`hexToColor()`/`unknownClientColor`, `setClientColor()`, `ClientDot` (4 sizes), the colour control in `clients_view`, the client field, the report board's bars, plus `colors_test.dart` and `fixtures.dart`.

Decide:
- **Does `colorHex` leave the schema?** Drop the column (a Drift migration, and `migration_test.dart` covers migrations already), keep it unused, or keep it and stop showing it. Dropping is cleanest and is also the only option that actually removes code — but say what is lost.
- **Existing rows.** There is real user data with real colours. Is discarding it acceptable, or is there any path where a user notices and cares?
- **dicebear, or thirty lines?** Research found dicebear is three packages (`dicebear_core`, `dicebear_styles`, `flutter_svg`) plus a runtime JSON-schema validation on every `Avatar()` construction, for a 32px decoration — while `crypto` is *already* a direct dependency and a hash → mirrored grid → `CustomPainter` identicon is about thirty lines with no new deps and no licence question. dicebear earns its place only if its specific look is the point. Decide explicitly, and if dicebear wins, decide the caching (hoist `Style` to a top-level final, memoise SVG per seed — uncached it schema-validates per row per frame).
- **The seed, again.** Research recommends the client id over the name: renaming would otherwise silently change the avatar, and names are not unique in the DB sense.
- **What the identicon is seeded from.** Client id (stable under rename, meaningless if data moves) or name (changes on rename, portable). Pick one and say why. Note that `CONTEXT.md` calls the name unique and case-insensitive — decide whether the seed is the raw name or the normalised one.
- **The report board.** Its bars are colour-coded per client today; an avatar cannot fill a bar. What distinguishes clients there instead — a legend with avatars, shadcn's chart/tracker colours, labels alone? This is the part of the change with no obvious answer.
- **How the avatar actually renders.** shadcn's `Avatar` takes an `ImageProvider` — a dicebear **SVG is not one**. So it is `flutter_svg` beside `Avatar` rather than inside it, or rasterise, or the `CustomPainter` route (which sidesteps this entirely). Note too that the client field's dropdown is `AutoComplete`, whose `suggestions` is a `List<String>` — **no per-option widget**, so identicons cannot appear in the dropdown at all. If they must, the client field needs a different component.
- **Where an avatar appears and at what size**, replacing `ClientDot`'s four sizes: list rows, group headers, the client field's options, the report.
- **The client-creation flow.** Creating a client by typing a name currently also generates a colour. What, if anything, replaces that step.
- **Docs.** `CONTEXT.md`'s Client definition changes; decide whether this earns an ADR alongside 0001–0003.

Use `/grilling` and `/domain-modeling`.
