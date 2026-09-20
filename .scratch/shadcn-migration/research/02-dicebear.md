# DiceBear in Dart/Flutter — facts for the identicon avatar decision

Ticket: [`issues/02-dicebear-dart-facts.md`](../issues/02-dicebear-dart-facts.md)
Researched: 2026-09-20. All version numbers are "latest on pub.dev at that date".

## Headline: it is OFFLINE, pure Dart

> "Generate avatars in Dart (3.4 or higher) and in Flutter apps, **with no external service involved**."
> — <https://www.dicebear.com/integrations/dart/index.md>

Verified against the published source, not just the prose: `dicebear_core-10.7.0` has no
`http`/`dart:io`/socket dependency anywhere. Its only deps are `dicebear_schema` (pure data)
and `json_schema` (validation). The whole pipeline is `Style.parse(jsonString)` →
`Resolver` → `Renderer` → an SVG string built in memory. The style artwork ships *inside*
`dicebear_styles` as Dart string constants (`lib/identicon.dart` is a 6.1 KB JSON blob).

**No network call per avatar. No network call ever.** This clears the local-only constraint.

(There is also a DiceBear HTTP API at `api.dicebear.com` — it exists, it is a separate product,
and the Dart packages do not use it. Nothing to work around.)

## The two packages to add

```yaml
dependencies:
  dicebear_core: ^10.7.0    # engine
  dicebear_styles: ^10.6.0  # style definitions, incl. identicon
  flutter_svg: ^2.3.0       # renders the SVG string into a widget
```

That is **three** additions, not two — the "2 missing packages" framing undercounts, because
DiceBear splits engine and styles. All three are required.

| Package | Version | Publisher | Published | SDK constraint | Licence |
|---|---|---|---|---|---|
| `dicebear_core` | 10.7.0 | `dicebear.com` (verified) | 2026-08-26 | `sdk: ^3.4.0` | MIT |
| `dicebear_styles` | 10.6.0 | `dicebear.com` (verified) | 2026-08-26 | `sdk: ^3.0.0` | per-style (identicon = CC0 1.0) |
| `flutter_svg` | 2.3.0 | `flutter.dev` (verified) | 2026-05-08 | `sdk: ^3.9.0`, `flutter: >=3.35.0` | MIT |

Transitive, pulled automatically: `dicebear_schema ^1.5.1`, `json_schema ^5.2.2`, and
flutter_svg's `http ^1.0.0` + `vector_graphics*`.

### Compatibility with this repo

`pubspec.yaml` declares `environment: sdk: ^3.10.7`; the toolchain is Dart 3.13.1 / Flutter 3.47.1.
Every constraint above is satisfied with room to spare (`^3.9.0` ⊂ 3.13.1, `>=3.35.0` ⊂ 3.47.1).
All three packages list Windows as a supported platform. No null-safety concerns — all are
Dart-3-only packages, so sound null safety is a given.

Source: `https://pub.dev/api/packages/<name>` (the `latest.pubspec` field), read directly.

### Maintenance signals

- `github.com/dicebear/dicebear` — 9.7k stars, MIT, **0 open issues**, last push 2026-09-19 (yesterday).
- `github.com/dicebear/styles` — 0 open issues, last push 2026-09-07 (`v11.0.0-rc.3`).
- Both actively developed. `dicebear_core` shows only 2 likes / 2.39k downloads on pub.dev —
  the Dart port is new, but it is first-party and published by the verified `dicebear.com` publisher,
  not a community re-implementation.
- **Caveat:** `dicebear_styles 11.0.0-rc.3` is in prerelease. A major bump is imminent.

## Output format and rendering

`Avatar` exposes three serializations (read from `dcx/lib/src/avatar.dart`):

- `avatar.svg` (and `toString()`) → SVG 1.1 markup as a `String`
- `avatar.toDataUri()` → `data:image/svg+xml;charset=utf-8,...`
- `avatar.toJson()` → `{'svg': ..., 'options': ...}`

Flutter has no built-in SVG support, so `flutter_svg`'s `SvgPicture.string(...)` is what turns
`avatar.svg` into a widget. `flutter_svg` explicitly supports raw-string SVG sources.

## The `identicon` style

Available in stable `dicebear_styles 10.6.0` — confirmed by unpacking the published archive:
`lib/identicon.dart` is present (62 styles ship as individual top-level libraries so you only
pay app-size for what you import).

Import it as its own library to avoid pulling in all 62:

```dart
import 'package:dicebear_styles/identicon.dart';
```

### Options accepted (from <https://www.dicebear.com/styles/identicon/index.md>)

Core options: `seed`, `size` (1–4096), `idRandomization`, `title`, `flip`, `fontFamily`,
`fontWeight`, `scale` (0–10), `borderRadius` (0–50), `rotate` (-360–360),
`translateX`/`translateY` (-1000–1000).

Identicon-specific:

| Option | Type | Values |
|---|---|---|
| `rowVariant` | enum (array allowed) | `ooxoo`, `oxoxo`, `oxxxo`, `xooox`, `xoxox`, `xxoxx`, `xxxxx` |
| `rowProbability` | number | 0–100 |
| `rowColor` | color (array allowed) | hex, `#` optional |
| `rowColorFill` | enum | `solid`, `linear`, `radial` |
| `rowColorFillStops` / `rowColorAngle` | range | / -360–360 |
| `rowColorOrder` | enum | `random`, `fixed` |
| `backgroundColor` + `backgroundColorFill` / `FillStops` / `Angle` / `Order` | same shape as `rowColor` | |

Notes for our use:

- **Padding**: there is no `padding` option. `scale` (0–100 in the playground, `0–10` range per
  the table — see *unknowns*) shrinks the artwork inside the viewBox, which is the padding lever.
- **Colour**: `rowColor` and `backgroundColor` take arrays; the engine picks deterministically
  from the array using the seed. This is how you constrain identicons to the shadcn palette —
  pass the accent ramp as a `rowColor` array instead of letting DiceBear pick arbitrary hues.
- `size` emits width/height on the `<svg>`; in Flutter you'd normally omit it and let
  `SvgPicture`'s `width`/`height` do the sizing.

### Licence verdict

The style file's own header, verbatim from `dicebear_styles-10.6.0/lib/identicon.dart`:

```
// Artist: DiceBear (https://www.dicebear.com)
// License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
```

**CC0 1.0 — public domain dedication. Attribution is NOT required.** The style page states this
outright: "attribution is not required". Shipping generated identicons in a distributed desktop
app carries no credit obligation and no copyleft.

This is the cheapest licence in the DiceBear catalogue — many other styles (the human-avatar
ones) are CC BY 4.0 and *would* require attribution. Identicon avoids that entirely. If the
style is ever swapped, re-check the licence; it is per-style, not per-package.

## Seeding

The seed is a plain `String` passed as `{'seed': '...'}`. "The same seed always produces the
same avatar", byte-identical, and DiceBear claims cross-implementation identity (the Dart port
reproduces the JS port's output — the source goes as far as matching JS number-serialization
quirks and `URIError` behaviour, which is a strong signal they test for parity).

**Seed from the client's stable id, not its name.** Renaming a client would otherwise silently
change its avatar, which is exactly the visual-identity break the avatar exists to prevent.
Names are also not unique; ids are.

### Determinism across versions — the real caveat

Determinism is guaranteed *for a fixed style definition*. It is **not** guaranteed across
style-package major versions: the artwork JSON is what changes in a major bump, and
`dicebear_styles` already has `11.0.0-rc.3` in flight. So:

- Pin with a caret and accept that `dicebear_styles 11.x` may redraw every avatar.
- This is cosmetic only for us — avatars are derived at render time from the client id, never
  persisted — so a redraw on upgrade is a visual change, not data loss. Acceptable.
- If byte-stability ever matters, pin exactly (`dicebear_styles: 10.6.0`).

Second caveat: `idRandomization: true` is recommended by the docs for pages with multiple
avatars (to avoid SVG element-id collisions). **Leave it off.** It injects randomness and breaks
determinism, and the DOM-collision problem it solves is a browser problem — each `SvgPicture` in
Flutter renders in its own isolated picture, so ids cannot collide.

## Cost: cache it, don't build it in `build()`

Not free. Reading the source:

1. `Style.parse(identicon)` does a `jsonDecode` of a 6.1 KB string **plus** full draft-07 JSON
   Schema validation of the definition. The docs say it plainly: "Build it once from the decoded
   definition JSON, then reuse it when rendering multiple avatars."
2. `Avatar(style, options)` validates the options map against a compiled JSON Schema on
   *every* construction, then resolves colours and renders the XML by string building.

So the rule for a list row:

- `Style.parse` → exactly once, a top-level `final`. Never in `build`.
- `Avatar(...).svg` → memoize per seed in a `Map<String, String>`. Clients are a bounded,
  small set in this app, so an unbounded map is fine; there is no need for an LRU.
- `SvgPicture.string` itself is fine to call in `build` — flutter_svg keeps an internal picture
  cache, and re-passing the identical string hits it.

Uncached `Avatar()` construction per row per frame during a scroll would mean a schema
validation plus a string-build per row per frame. That is the thing to avoid, and one `Map`
avoids it.

## Minimal working snippet

```dart
import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/identicon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Parsed once: Style.parse decodes 6KB of JSON and schema-validates it.
final _identicon = Style.parse(identicon);

/// Rendering is deterministic per seed, so the SVG is worth keeping.
final _svgCache = <String, String>{};

String _identiconSvg(String seed) => _svgCache.putIfAbsent(
      seed,
      () => Avatar(_identicon, {
        'seed': seed,
        // Constrain to the app palette; DiceBear picks from the list by seed.
        'rowColor': ['22c55e', '3b82f6', 'a855f7', 'f59e0b'],
        'backgroundColor': ['1e293b'],
        'scale': 70,
      }).svg,
    );

class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.seed, this.size = 32});

  /// The client's stable id — never its name, which can be renamed.
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SvgPicture.string(
          _identiconSvg(seed),
          width: size,
          height: size,
        ),
      );
}
```

(`scale: 70` is the padding lever — see the unknown about its range below.)

## Unknown / not stated

- **`scale`'s real range.** The options table on the identicon page says `range: 0 to 10`, but
  the DiceBear playground and every other style's docs treat `scale` as a percentage (0–100,
  default 100). The table is likely a docs bug. **Verify against `OptionsDescriptor` or a
  `pws -c dart run` spike before relying on a specific value** — an out-of-range value throws
  `OptionsValidationError`, so this fails loudly rather than silently.
- **Default values** for identicon's options (`rowProbability`, `rowVariant`, `backgroundColor`)
  are not published in the docs table — it lists names and value ranges only. Read them off
  `OptionsDescriptor` at runtime if they matter.
- **`dicebear_styles` package-level licence**: pub.dev shows "Unknown"; the archive ships a
  `LICENSE` file that is per-style, and the per-style header inside `identicon.dart` is the
  authoritative statement (CC0 1.0). The *package* licence being ambiguous does not affect the
  identicon style's CC0 grant, but it is why the pub.dev badge looks unhelpful.
- **Benchmark numbers.** No measured µs-per-avatar figure exists anywhere; the "cache it"
  advice above is reasoned from the source (schema validation + string building), not measured.
  If avatars are ever rendered in bulk, measure.
- **Whether `dicebear_styles 11.0.0` changes identicon's artwork.** The RC changelog mentions
  cats/dogs work, not identicon, but a major bump is a major bump. Unstated.
- **App-size cost** of the three packages on a Windows release build. Not measured.
  `identicon.dart` alone is 6.1 KB; `json_schema` and `vector_graphics_compiler` are the
  larger unknowns.

## Offline alternatives, if DiceBear is ever rejected

Not needed — DiceBear is offline, so this section is insurance, not a recommendation.

1. **`jovial_svg`** instead of `flutter_svg` as the renderer. Same job, different trade-offs
   (pre-compiled binary SVG format, generally faster at render time). Only worth it if
   flutter_svg measurably underperforms.
2. **Roll the identicon ourselves.** Genuinely small: hash the seed (`crypto` is *already* a
   direct dependency of this project), take the first N bits, mirror a 5×5 grid horizontally,
   pick a hue from another slice of the hash, paint it with `CustomPainter`. That is roughly
   30 lines, zero new dependencies, zero SVG, zero licence questions, and it renders faster
   than parsing SVG. It gives GitHub-style identicons rather than DiceBear's exact artwork.
3. **First letter in a seeded colour chip.** Zero dependencies, ~10 lines, and for a
   single-user desktop app with a handful of clients it is arguably sufficient.

Given `crypto` is already in `pubspec.yaml`, option 2 deserves an explicit yes/no from the
spec before three dependencies go in for a 32×32 decoration. DiceBear is the right call if the
*look* is what's wanted; it is three dependencies plus a JSON-schema validator for something
`crypto` + `CustomPainter` already covers.

## Sources

- <https://www.dicebear.com/integrations/dart/index.md>
- <https://www.dicebear.com/how-to-use/dart-library/index.md>
- <https://www.dicebear.com/styles/identicon/index.md>
- <https://pub.dev/packages/dicebear_core>, <https://pub.dev/packages/dicebear_styles>, <https://pub.dev/packages/flutter_svg>
- `https://pub.dev/api/packages/{dicebear_core,dicebear_styles,dicebear_schema,flutter_svg}` (pubspec metadata)
- Published archives `dicebear_core-10.7.0.tar.gz` and `dicebear_styles-10.6.0.tar.gz`, unpacked and read
- GitHub API: `dicebear/dicebear`, `dicebear/styles` (commits, open issues, licence)
