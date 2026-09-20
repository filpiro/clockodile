# 11 — Retention Period as three choices

**What to build:** the Retention Period stops being a free-text number with a
`Salva` button and becomes three choices — 30, 45 or 60 days — picked the same
way the theme is picked. Choosing writes immediately, like every other setting on
the page, so the save button and its validation message disappear.

Shrinking the Retention Period still destroys Entries, so the existing
confirmation before a shrink stays exactly as it is, and the purge runs after it
is accepted.

No fallback for a stored value outside the three: single user, stored value is
already 45.

**Blocked by:** 10 — Settings gets a layout.

**Status:** done

- [x] Retention Period is three segments, 30 / 45 / 60, inside the Settings
      section from ticket 10
- [x] Picking a value persists it at once; no `Salva` button, no text field, no
      validator
- [x] Picking a shorter Retention Period still asks for confirmation and only
      then purges; cancelling leaves the stored value untouched
- [x] The settings tests cover the new control
