# 08 — Attività screen

**What to build:** The Attività list and the entry editor run on shadcn: dense rows, header button instead of the FAB, client field on `AutoComplete`, date filter on top.

**Blocked by:** ~~01 — Client identicon~~; 05 — Shell + Aiuto; 06 — AppListRow + EmptyState; 07 — DateField + single-date filter

**Status:** ready-for-agent

**Model:** Opus, effort medium — largest screen, but fully specified

Spec: `../../shadcn-migration/spec.md` (phase 4; reference branch `prototype/07-attivita-shadcn`)

- [ ] Entry editor stays a pushed route, content capped at the form max width
- [ ] Client field on `AutoComplete`, no identicon in its dropdown
- [ ] Attività widget tests green
- [ ] Integration test's create-entry steps tap the header button instead of the FAB
- [ ] `pws -c flutter analyze` has no errors
- [ ] Eyeballed on Windows, light and dark: ~51px rows, hover, muted actions, `dd/mm/yy`, Italian right-click menu
