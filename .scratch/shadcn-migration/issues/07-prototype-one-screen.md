# Spike Attività on shadcn to prove the theme and the mapping

Type: prototype
Status: open
Blocked by: ~~01~~ (resolved — see `../research/01-shadcn-app-and-theme.md`), 05
Map: ../map.md

## Question

Does the mapping actually hold up, and does the theme look like anything we want? Cheapest way to know is one screen, thrown away.

`entries_view` is the richest target: a grouped list with hoverable rows and row actions, the Active Entry tile, the segmented date filter, the client autocomplete, a FAB, and an empty state. If it converts cleanly, little else will surprise us.

- Stand up a throwaway `ShadcnApp` with the real theme knobs from ticket 01, and rebuild Attività against fake data using the mapping from ticket 05.
- Run it on Windows (`pws -c flutter run -d windows`) and look at it. Screenshot it.
- **Two knob values are guesses and this spike is where they get settled.** "Rounded" radius has no API constant — `radius` is a bare `double` multiplier (default `0.5`) and `0.7` is only the docs' own "rounder corners" example. "Medium" `surfaceBlur` has no sourced value at all; it is a blur radius in logical pixels, `null` = off, and blur behind an opaque surface is invisible — so "Solid + Medium blur" may be self-cancelling. Eyeball both, then lock numbers.
- Report back, specifically: which mapping rows were wrong, what "Reduced" density plus "shadcn look wins" actually does to the list's information density (rows may get taller — that matters on a screen whose whole job is a long list), whether the hover/row-action pattern survives without `HoverTile`, and whether anything needs a `ComponentTheme` override after all.

Throwaway: it lives outside `lib/` or on a scratch branch, and is linked from this ticket as an asset. Use `/prototype`.
