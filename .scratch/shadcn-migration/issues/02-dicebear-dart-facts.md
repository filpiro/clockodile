# dicebear in Dart/Flutter: what it renders and what deps it drags in

Type: research
Status: resolved
Map: ../map.md

## Question

Primary source: https://www.dicebear.com/integrations/dart/index.md and the package's own pub.dev page.

- Which Dart package is the real integration, at what version, and is it maintained?
- Does it generate locally (offline, pure Dart) or call the DiceBear HTTP API? This app is **local-only** — a network call per avatar is disqualifying, so state plainly which it is.
- Output format. If SVG, what renders it in Flutter — `flutter_svg`? Which version? The user said "add 2 missing packages"; name both concretely.
- The `identicon` style specifically: available in the Dart integration? What options does it take (size, background, colours, padding)?
- Seeding: what goes in as the seed, and is output deterministic for the same seed across versions? We would seed from a client name or id — say which is safer.
- Cost of generation: is it cheap enough to build inside a list row's `build`, or does it need caching?
- Licensing on the `identicon` style (DiceBear styles carry per-style licences) and whether attribution is required in a distributed desktop app.

Capture findings as Markdown in the repo and link them from this ticket.

## Answer

Findings: [`../research/02-dicebear.md`](../research/02-dicebear.md)

- **Offline, pure Dart.** "Generate avatars in Dart ... with no external service involved."
  Verified against the published archives: no `http`, no `dart:io` in `dicebear_core`.
  Style artwork ships as Dart string constants. Nothing to work around for local-only.
- **Three packages, not two** — DiceBear splits engine from styles:
  `dicebear_core: ^10.7.0`, `dicebear_styles: ^10.6.0`, `flutter_svg: ^2.3.0`.
  All first-party verified publishers, all Windows-supported, all compatible with
  Dart 3.13.1 / Flutter 3.47.1 (tightest constraint is flutter_svg's `sdk: ^3.9.0`,
  `flutter: >=3.35.0`). Both DiceBear repos are actively maintained, 0 open issues.
- **`identicon` is in stable 10.6.0**, importable as its own library
  (`package:dicebear_styles/identicon.dart`) so only its 6.1 KB is linked.
  Options include `rowColor`/`backgroundColor` as *arrays* — that is how identicons get
  constrained to the shadcn palette. There is no `padding`; `scale` is the padding lever.
- **Licence: CC0 1.0, attribution NOT required.** Stated on the style page and in the
  style file's own header. No obligation in a distributed desktop app. Per-style, so
  re-check if the style is ever swapped (the human-avatar styles are CC BY 4.0).
- **Seed from the client id, not the name** — renaming a client would otherwise change its
  avatar, and names aren't unique. Output is byte-identical per seed *for a fixed style
  definition*; a `dicebear_styles` major bump (11.0.0-rc.3 is in flight) may redraw
  everything. Cosmetic only here, since avatars are derived at render time, never stored.
- **Cache it.** `Style.parse` jsonDecodes 6 KB and schema-validates — hoist to a top-level
  `final`. `Avatar()` schema-validates options on every construction — memoize the SVG in a
  `Map<String, String>` keyed by seed. `SvgPicture.string` in `build` is fine. Leave
  `idRandomization` off; it breaks determinism and solves a DOM problem Flutter doesn't have.

**Open question for the spec:** `crypto` is already a direct dependency. A hash → mirrored
5×5 grid → `CustomPainter` identicon is ~30 lines with zero new deps and no SVG parsing.
Three packages plus a JSON-schema validator for a 32×32 decoration deserves an explicit
yes/no. DiceBear wins only if its specific *look* is what's wanted.
