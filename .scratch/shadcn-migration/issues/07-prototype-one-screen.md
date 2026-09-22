# Spike Attività on shadcn to prove the theme and the mapping

Type: prototype
Status: resolved
Blocked by: ~~01~~ (resolved), ~~05~~ (resolved)
Map: ../map.md

## Question

Does the mapping actually hold up, and does the theme look like anything we want? Cheapest way to know is one screen, thrown away.

`entries_view` is the richest target: a grouped list with hoverable rows and row actions, the Active Entry tile, the segmented date filter, the client autocomplete, a FAB, and an empty state. If it converts cleanly, little else will surprise us.

- Stand up a throwaway `ShadcnApp` with the real theme knobs from ticket 01, and rebuild Attività against fake data using the mapping from ticket 05.
- Run it on Windows (`pws -c flutter run -d windows`) and look at it. Screenshot it.
- **Two knob values are guesses and this spike is where they get settled.** "Rounded" radius has no API constant — `radius` is a bare `double` multiplier (default `0.5`) and `0.7` is only the docs' own "rounder corners" example. "Medium" `surfaceBlur` has no sourced value at all; it is a blur radius in logical pixels, `null` = off, and blur behind an opaque surface is invisible — so "Solid + Medium blur" may be self-cancelling. Eyeball both, then lock numbers.
- Report back, specifically: which mapping rows were wrong, what "Reduced" density plus "shadcn look wins" actually does to the list's information density (rows may get taller — that matters on a screen whose whole job is a long list), whether the hover/row-action pattern survives without `HoverTile`, and whether anything needs a `ComponentTheme` override after all.

Throwaway: it lives outside `lib/` or on a scratch branch, and is linked from this ticket as an asset. Use `/prototype`.

## Comments

### Spike findings (2026-09-22) — awaiting the human's eyeball on radius and blur

**Asset**: branch `prototype/07-attivita-shadcn` (commit `a50b7f1`), folder `.scratch/shadcn-migration/prototype-07/`. Screenshots in `prototype-07/shots/`. Run: `cd .scratch/shadcn-migration/prototype-07 && pws -c flutter run -d windows`. A knob bar at the bottom flips mode, radius, blur, opacity, density, empty data and the Active Entry tile live, and prints the measured row height.

**Mapping rows that were wrong** (in `style/components.md`):

1. `theme.paddingSm/Md/Lg` **do not exist** in 0.0.54. `ThemeData` has `radiusSm/Md/Lg` + `borderRadiusMd` etc., and `density` (`Density.reducedDensity` = `baseContainerPadding: 12, baseGap: 6, baseContentPadding: 12`). Page padding 24 must be a literal or derived from `density`.
2. Toggle snippet `ButtonStyle.outline(density: ButtonDensity.compact)` is wrong: compact strips all padding and the outline border, so Oggi/Ieri read as bare text (`shots/zoom_toggles.png`). `ButtonStyle.outline()` is right (`shots/zoom_toggles2.png`).
3. `DatePicker` is not a popover by default on desktop: it opens a centred dialog with Cancel/Save (`shots/datepop.png`). Strings are English and the week starts Sunday — feeds ticket 09 (Italian localization). `mode:` can switch it to popover if wanted.
4. `DateUtils` is Material — gone. A one-line `dateOnly()` replaces it.

**Density**: Reduced + shadcn look makes rows **denser, not taller**. `AppListRow` with a 32px identicon measures **51.5px**; the old `HoverTile` was a Material two-line `ListTile` (~72px). 7 rows + Active Entry tile + header fit easily in 900px.

**Hover / row actions without `HoverTile`**: survive. `Clickable` has **no default hover fill** — `AppListRow` must pass `decoration: WidgetStateProperty.resolveWith(...)` with `colorScheme.muted` + `theme.borderRadiusMd`. That is the only thing it has to add. Tooltips on icon buttons work as wrappers. Note: `ButtonStyle.destructiveIcon()` is a **filled** red square, so always-visible delete gives one red block per row (`shots/spike1.png`) — loud, but it follows the rule as written.

**`ComponentTheme` overrides**: none needed so far.

**Blur**: confirmed self-cancelling. With `surfaceOpacity: 1.0`, `surfaceBlur: 8` changes nothing visible behind a dialog (`shots/crop_dlg_b8_o10.png`). With opacity 0.8 the list text shows through as a blurred smudge (`shots/crop_dlg_b8_o08.png`).

**Radius**: only 0.7 was eyeballed by the agent; looks rounded without looking soft.

Not checked: toast appearance, light mode, the AutoComplete dropdown open.

## Answer

The mapping holds. Attività converts cleanly on shadcn_flutter 0.0.54 with fake data.

- **Theme knobs locked**: `radius: 0.7`, `surfaceOpacity: 1.0`, `surfaceBlur: null`. Blur is dropped because it is invisible behind a Solid surface — the human chose "blur off, stay Solid" over going frosted.
- **Mapping fixes**, folded into `style/components.md`: no `theme.paddingSm/Md/Lg` (page padding is a file-local `const`); Toggle is `ButtonStyle.outline()`, never `ButtonDensity.compact`; `DatePicker` opens a dialog by default on desktop.
- **Density**: rows are 51.5px, down from ~72px. Reduced + shadcn look is denser, not taller.
- **Row hover**: survives without `HoverTile`. `AppListRow` passes `Clickable` a `WidgetStateProperty` decoration (`colorScheme.muted`, `theme.borderRadiusMd`) — `Clickable` has no hover fill of its own.
- **`ComponentTheme` overrides**: none needed.
- **Open, not decided here**: `destructiveIcon` is a filled red square, one per row. It follows the written rule; flagged as loud for whoever builds the screen. `DatePicker` strings are English — ticket 09.

Asset: branch `prototype/07-attivita-shadcn` (`a50b7f1`).
