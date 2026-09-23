# 06 — AppListRow + EmptyState

**What to build:** The two shared widgets exist on shadcn: the list row (hover fill, always-visible muted actions) and the empty state.

**Blocked by:** ~~02 — ShadcnApp root~~

**Status:** done

**Model:** Opus, effort low — follows clear rules in the spec

Spec: `../../shadcn-migration/spec.md` (phase 3; `style/components.md` § 2)

- [x] Row hover through a `Clickable` decoration (muted fill, medium radius), as the ticket 07 prototype did
- [x] Row actions always visible and muted; no hover-reveal
- [x] Widget tests for both
- [x] `pws -c flutter analyze` has no errors
