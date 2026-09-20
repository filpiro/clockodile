# 08 — List row shape, hover contrast, one right edge

**What to build:** every list row in `Attività`, `Clienti` and `Report` lights up
on hover with a fill you can actually see, inset from the page edges and rounded,
instead of today's full-bleed square wash that barely differs from the
background. A group header's trailing value (the day total) ends at the same
right edge as the row actions under it, so it reads as a column label rather
than floating mid-row.

Also in this ticket, because it is the same "a hovered icon needs air" problem:
on `Modifica Attività`, the gap between the end-time field and the delete icon
grows so the icon's hover disc stops touching the field.

The hover fill colour is a new house value rather than a re-used Material slot:
the current one sits one step off the page background and disappears. It is for
neutral rows only — the Report board keeps its own client-coloured hover, since a
grey wash would mud the client identity.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] catui exposes a `hoverSurface` colour mapped to the flavor's `overlay0`,
      and `HoverTile` uses it instead of `surfaceContainerHighest`
- [x] catui has `tileMargin` (8) and `tileRadius` (8) tokens; `HoverTile`'s fill
      is inset horizontally and rounded by them
- [x] `CatSectionHeader` and a row's content share the same left and right inset,
      so header trailing and row actions end at the same x
- [x] Report board hover is unchanged
- [x] `Modifica Attività`: hovering the delete icon no longer overlaps the
      end-time field
- [x] Both repos committed, `pubspec.yaml` pinned to the new catui ref, app builds
