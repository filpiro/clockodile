# 10 — Settings gets a layout

**What to build:** the Settings page stops being a stack of loose controls and
becomes a sequence of sections. A section is a title — larger than today's — with
an optional one-line description, then a body holding the interactive options,
closed by a light bottom border. `Tema`, `Conservazione` and `AI` are each one
section, and every future one inherits the same rhythm without restating it.

An option that carries a switch reads label-and-description on the left, control
on the right, edge to edge. Multiple options in one body are separated so they
don't run together.

Settings also fills the window instead of sitting in a narrow column. Filling the
window applies to the section, never to the control inside it: a button or the
theme picker keeps its natural width. Prose and single-column forms keep their
cap, so `Modifica Attività` and the Help page are unchanged.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] catui has a section widget: title, optional description, body, bottom
      border, and it owns all the spacing
- [x] catui has a setting-row widget: title and optional description left,
      control right
- [x] Settings is rebuilt on both; no spacing or text style is restated on the page
- [x] Settings fills the available width; the theme picker, buttons and switches
      keep their natural width
- [x] The Help page still caps its width; `Modifica Attività` is unchanged
- [x] Both repos committed, `pubspec.yaml` pinned to the new catui ref, app builds
