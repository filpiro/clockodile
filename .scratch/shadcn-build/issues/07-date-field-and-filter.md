# 07 — DateField + single-date filter

**What to build:** The date filter always holds one day; the 'Tutte' option and its pagination are gone. Dates are picked through a shared date field that shows `dd/mm/yy`, never shadcn's US order.

**Blocked by:** 04 — Italian strings for shadcn

**Status:** ready-for-agent

Spec: `../../shadcn-migration/spec.md` (phase 3; `style/components.md` § 4)

- [ ] Shared date field over shadcn's form field with the date picker dialog
- [ ] Filter state is a single day; `DateFilter.all` removed; runtime state only, no schema change
- [ ] Tests for the filter cubit and the date field
- [ ] `pws -c flutter analyze` has no errors
