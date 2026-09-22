# 04 — Italian strings for shadcn

**What to build:** Every shadcn string the user can see is Italian: picker dialogs, Cancel/Save, placeholders, and the right-click menu of every text field.

**Blocked by:** 02 — ShadcnApp root

**Status:** ready-for-agent

Spec: `../../shadcn-migration/spec.md` (phase 1; ticket 09 of the map)

- [ ] In-repo `ShadcnLocalizationsIt extends ShadcnLocalizationsEn`, hard-coded strings, overriding only the ~40 strings we show
- [ ] Its delegate is the app's localisation delegate; locale stays Italian
- [ ] A missed string renders English, never a compile error
- [ ] `pws -c flutter analyze` has no errors
