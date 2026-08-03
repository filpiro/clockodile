---
name: cat_ui
version: 0.1.0
description: >-
  Catppuccin-based house style for desktop Flutter apps: a Material 3 theme
  mapped onto a catppuccin flavor, a token set, and the atomic widgets built
  on top of them.
omitted:
  - section: typography
    reason: >-
      cat_ui sets no text theme. Material's default scale is the house scale;
      apps use titleSmall/titleLarge/bodyMedium as-is. Adding a type scale is
      a decision nobody has needed yet.
  - section: elevation
    reason: >-
      No elevation overrides. Depth comes from the catppuccin surface ladder
      (crust/mantle/surface0-2), not from shadow. Widgets that need a raised
      layer use stock Material elevation.
colors:
  # Every value is a lookup into the catppuccin flavor the app passes to
  # catTheme, never a fixed hex. Swapping latte for mocha resolves all of
  # them at once — that is the whole point of the palette.
  primary: "{catppuccin.mauve}"
  onPrimary: "{catppuccin.base}"
  secondary: "{catppuccin.pink}"
  onSecondary: "{catppuccin.base}"
  surface: "{catppuccin.base}"
  onSurface: "{catppuccin.text}"
  onSurfaceVariant: "{catppuccin.subtext0}"
  secondaryContainer: "{catppuccin.surface1}"
  surfaceContainerHighest: "{catppuccin.surface2}"
  error: "{catppuccin.red}"
  onError: "{catppuccin.base}"
  outline: "{catppuccin.overlay0}"
rounded:
  md: 10px
  dotSm: 6px
  dot: 8px
  dotMd: 12px
  dotLg: 14px
spacing:
  formMaxWidth: 560px
  pillMinHeight: 48px
components:
  hoverTile:
    backgroundColor: transparent
  hoverTile-hover:
    backgroundColor: "{colors.surfaceContainerHighest}"
  editIconButton:
    textColor: "{colors.onSurfaceVariant}"
    size: 18px
  editIconButton-hover:
    textColor: "{colors.primary}"
  deleteIconButton:
    textColor: "{colors.onSurfaceVariant}"
    size: 18px
  deleteIconButton-hover:
    textColor: "{colors.error}"
  dangerButton:
    backgroundColor: "{colors.error}"
    textColor: "{colors.onError}"
    rounded: "{rounded.md}"
---

## Overview

A desktop-first house style: keyboard and mouse are the primary input, windows
are wide, and rows are dense enough that a list is scannable without scrolling.

Two things carry the identity. The **catppuccin palette**, which supplies every
colour through a `Flavor` rather than a fixed hex, so light and dark are the
same design resolved twice. And **hover as the disclosure mechanism** — rows
reveal their actions on hover instead of showing them always or hiding them
behind a menu. Neither survives a phone; this style is not for one.

Everything else is stock Material 3, deliberately. The style is defined by the
handful of places it departs, not by a wholesale reskin.

Consume it by depending on `cat_ui` alone — it re-exports `catppuccin_flutter`
and `lucide_icons_flutter`, so every app stays on the same glyphs and flavors:

```dart
import 'package:cat_ui/cat_ui.dart';

final darkTheme = catTheme(catppuccin.mocha, Brightness.dark);
```

## Colors

The source of truth for what each role *means* is the
[catppuccin style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md).
cat_ui maps those roles onto Material 3's `ColorScheme` and adds nothing of its
own. Surfaces follow the ladder: `base` for the page, `crust`/`mantle` for
lower containers, `surface0-2` for raised ones, `overlay0` for outlines.

**The accent is the app's, not the package's.** `catTheme` takes `primary` and
`secondary` as independent optionals, each falling back to the flavor's own
mauve and pink. An app states its accent in one place and passes it in:

```dart
// lib/shared/theme.dart in the consuming app
ThemeData _theme(Flavor flavor, Brightness brightness) =>
    catTheme(flavor, brightness, primary: flavor.green);

final lightTheme = _theme(catppuccin.latte, Brightness.light);
final darkTheme = _theme(catppuccin.mocha, Brightness.dark);
```

Take the accent *from the flavor* rather than fixing a hex, as above. Latte's
green is dark and mocha's is light; a single hardcoded value cannot be both,
and the earlier version of this package shipped one that under-contrasted on
latte for months.

`onPrimary` and `onSecondary` are not settable. Upstream's rule is "On Accent →
Base", and it holds because every catppuccin accent sits mid-range: the flavor's
base contrasts against all of them, in either brightness. An accent from outside
the palette voids that guarantee — legibility first, as upstream says.

### Deviations from upstream

- **Green as an accent.** Upstream reserves green for *Success*. Clockodile uses
  it as `primary`, so a green fill means "the app's accent", not "this
  succeeded". An app that needs a success colour should reach for a different
  role or say so explicitly rather than assume green is free.
- **`secondaryContainer` is `surface1`, not an accent.** Material would tint the
  navigation rail indicator and selected segments with the secondary hue; here
  they stay a neutral raised surface. Selection is signalled by depth, not
  colour, which keeps the accent meaningful for actions.
- **Red is an intent colour, not only a data-loss colour.** Controls that end
  something — not just ones that destroy rows — hover to `error`. See
  `intentHoverStyle` below.

## Layout

`spacing.formMaxWidth` (560) caps single-column forms so they stay readable in
a maximised window instead of stretching a text field across a monitor. Wrap
the form body, not the page:

```dart
Center(child: ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: AppTokens.formMaxWidth),
  child: ListView(...),
))
```

`spacing.pillMinHeight` (48) is for a pill button sitting next to an icon
button. Material's default pill is 40 tall, the same as an `IconButton`'s hover
disc, but the pill's visual weight reads smaller beside it. Forcing 48 fills the
tap box the pill already occupies; row height does not change.

Spacing otherwise is stock Material — no scale, no grid. Nothing in the style
depends on a gap being a particular number, so nothing is tokenised.

## Shapes

`rounded.md` (10) replaces Material 3's stadium pills on every button —
`Filled`, `Elevated`, `Outlined`, `Text` and `Segmented`. Not 16, which is the
FAB's radius: buttons are ~40 tall against the FAB's 56, so 10 preserves the
FAB's corner-to-height proportion. At 16 a 40px button is still a pill. The FAB
and chips keep their defaults.

The **dot scale** is the other shape decision. A filled `CircleAvatar` in an
identity colour is the main visual anchor of a list, and its radius carries
meaning:

| Token | Radius | Use |
|---|---|---|
| `rounded.dotSm` | 6 | beside a group header |
| `rounded.dot` | 8 | the default for a list row |
| `rounded.dotMd` | 12 | a row whose dot is itself tappable |
| `rounded.dotLg` | 14 | a preview inside a dialog |

12 exists only because a tappable dot needs the hit area; do not use it for
decoration. Pick from the scale — a fifth size is a decision, not a tweak.

## Components

Behaviour is the reason these exist. The tokens above describe their skin; what
follows is what a token cannot say.

### `HoverTile`

Any list row. It is a `ListTile` whose highlight is driven from a `MouseRegion`
rather than from `ListTile.hoverColor`, because `InkResponse` ignores hover when
every callback is null — a non-tappable row would otherwise stay flat while its
neighbours light up. Stock `hoverColor` is forced transparent so the ink overlay
does not stack on the colour being animated.

The fade is 200ms, matching Material's own `InkHighlight`, so a `HoverTile` and
a stock inkwell row look identical in motion. (The spec has no motion token
type; the value lives in `AppTokens.hoverFade`.)

`actions` are revealed on hover via opacity plus `IgnorePointer`, never by
inserting widgets — the space is always reserved, so rows do not reflow under
the cursor.

```dart
HoverTile(
  key: ValueKey(item.id),   // keyed: hover must not survive a reorder
  leading: CircleAvatar(radius: AppTokens.dotRadius, backgroundColor: c),
  title: Text(item.name),
  subtitle: Text(item.detail),
  onTap: () => open(item),
  actions: [DeleteIconButton(onPressed: () => remove(item))],
)
```

### `intentHoverStyle({idle, accent})`

The shared rule for controls that state their intent before the click: muted at
rest, accent on hover, plus a 12% overlay tint so the ripple agrees with the
foreground instead of fighting it. Disabled resolves to `idle` at 38% —
Material's own disabled opacity.

Use it for any control whose consequence is worth previewing, not only
destructive ones. A "stop"/"end" action hovering to `error` is correct here:
red marks a strong action, not exclusively irreversible data loss.

### `EditIconButton` / `DeleteIconButton`

`intentHoverStyle` pre-wired to `primary` and `error`. Both take an overridable
tooltip — override it when a disabled state has a *reason* worth explaining,
since a disabled button with a generic tooltip tells the user nothing.

Icon size comes from the global `iconButtonTheme` (18, not Material's 24). The
hit area stays 40; the smaller glyph buys breathing room where two or three
actions sit together at the end of a row.

### `DangerButton`

The confirm button in a dialog that destroys data: filled with `error`, not
hover-tinted. By the time a confirmation dialog is open the user is committing,
not browsing, so the button should look like what it does before the pointer
arrives. Pair it with a plain `TextButton` cancel.

### `EmptyState`

A dimmed illustration above a message, for any list that can legitimately be
empty. The asset ships inside the package. Keep the message a plain statement of
what is absent — it is not a place for instructions.

## Do's and Don'ts

**Do**

- State the accent once, in the app, taken from the flavor.
- Reach for `AppTokens` before typing a number. If the number you want is not
  there, decide whether it should be — a one-off is fine, a second copy is not.
- Use `HoverTile` for every list row, including rows with no tap action.
- Let widgets read `Theme.of(context).colorScheme`; the theme is the only
  colour source.
- Override a tooltip when a disabled control has a reason.

**Don't**

- Don't hardcode a corner radius or a dot radius. `rounded.md` and the dot scale
  exist so a new screen matches the existing ones without archaeology.
- Don't set `onPrimary`/`onSecondary`. If an accent needs a foreground other
  than base, that accent is outside the palette and the rest of the style stops
  guaranteeing contrast.
- Don't hardcode a hex, including "just for this one dot". Identity colours
  belong to the app's data, everything else to the flavor.
- Don't rely on hover alone for anything a user must be able to find. Hover
  reveal is a desktop affordance with no touch fallback; it is for actions that
  are discoverable in context, not for primary navigation.
- Don't add a component token here for something one screen needs. This file
  describes the house style; an app's own screens are the app's business.
