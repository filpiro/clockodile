# 05 — One date-time field on the Entry page

**What to build:** Start and end times look and behave the same when creating and editing an Entry, and match the outlined Cliente and Nota fields.
- One date-time field (label, value or placeholder, tap to pick date then time) used for the create-mode Inizio and for each Session's Inizio/Fine in edit mode.
- An Open Session's end shows a "in corso" placeholder and can be set, never cleared (existing rule).
- Session rows drop the nested card/list-tile layout: two fields, duration or validation error below, delete action on the side.
- Only one way to leave without saving: remove the duplicate "Annulla" next to the AppBar back arrow (or the arrow — pick one, keep Salva).

**Where:** the date-time field is built in catui (see `decisions.md`), with the
label and placeholder text passed in by the app.

**Blocked by:** 01 (outlined input style), 04 (date-picker helper).

**Status:** done

- [ ] Create and edit mode use the same date-time field widget
- [ ] Field looks like the outlined Cliente/Nota fields in both themes
- [ ] Open Session end shows "in corso" and can be set; invalid end still shows the error and blocks Salva
- [ ] Last Session delete stays disabled with its explanatory tooltip
- [ ] Exactly one cancel affordance on the page; Ctrl/Cmd+S still saves
