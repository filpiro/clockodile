# 06 — AppListRow + EmptyState

**What to build:** The two shared widgets exist on shadcn: the list row (hover fill, always-visible muted actions) and the empty state.

**Blocked by:** 02 — ShadcnApp root

**Status:** ready-for-agent

**Model:** Opus, effort low — follows clear rules in the spec

Spec: `../../shadcn-migration/spec.md` (phase 3; `style/components.md` § 2)

- [ ] Row hover through a `Clickable` decoration (muted fill, medium radius), as the ticket 07 prototype did
- [ ] Row actions always visible and muted; no hover-reveal
- [ ] Widget tests for both
- [ ] `pws -c flutter analyze` has no errors
