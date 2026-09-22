# 05 — Shell + Aiuto

**What to build:** The window shows the shadcn icon-only navigation rail with Impostazioni and Aiuto pinned at the bottom. Aiuto is converted and is the first real screen visible inside the new shell.

**Blocked by:** ~~02 — ShadcnApp root~~

**Status:** ready-for-agent

**Model:** Opus, effort low — follows clear rules in the spec

Spec: `../../shadcn-migration/spec.md` (phase 2 and Aiuto from phase 4; ticket 04 of the map)

- [ ] Navigation stays an index + `IndexedStack`; the entry editor stays a pushed route
- [ ] Keyboard shortcuts unchanged
- [ ] Aiuto converted; help view test green
- [ ] `pws -c flutter analyze` has no errors
- [ ] Eyeballed: rail selection, Aiuto renders, title bar works, light and dark
