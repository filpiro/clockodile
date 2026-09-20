# 06 — Consistent page frame, spacing tokens and Settings layout

**What to build:** Every tab sits in the same frame, and Impostazioni is laid out so it is clear what saves when.
- Spacing tokens (gutter, page padding) replace hard-coded 12/16/24 values; toolbar controls, section headers and list content share one left edge.
- One page frame (optional title, optional toolbar, optional FAB, optional max width, body) used by Attività, Clienti, Report, Impostazioni and Aiuto. One rule for titles: all tabs have one or none do.
- Aiuto scrolls when the window is short. Impostazioni respects the form max width.
- Impostazioni: theme and AI apply instantly as today; retention's save sits with the retention field (or saves on submit), so it no longer looks like it saves the AI section. Theme picker uses the house segmented style (icons kept). "Elimina modello" becomes a non-filled error-coloured button; the red filled button stays only inside the confirm dialog.

**Where:** the spacing tokens and the page frame are built in catui (see
`decisions.md`); the Settings page layout is app-side.

**Blocked by:** 01, 02, 03, 04 (they reshape the toolbars, headers and dialogs this frame wraps).

**Status:** done (catui 5271ce7 must be pushed before a clean checkout builds)

- [x] All five tabs use the shared page frame; title rule applied uniformly
- [x] Toolbar, header and row content left edges align on every list screen
- [x] No hard-coded page/toolbar padding values remain in screens (Report toolbar Wrap spacing 24 still literal)
- [x] Aiuto scrolls at minimum window height without overflow errors
- [x] Retention save is visually tied to retention only; lowering retention still asks for confirmation
- [x] Theme picker matches the house segmented style; "Elimina modello" is not a filled red button
