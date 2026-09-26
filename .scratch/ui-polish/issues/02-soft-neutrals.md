# 02 — Soft neutrals

**What to build:** The app stops using pure white and near-pure black, so it feels calmer (Catppuccin was the reference for mood only — not its palette). In light mode, page background, cards and popovers are the off-white `#f5f6f8`. In dark mode, text is `#e4e6eb`, the background is `#16181d`, and the other dark grays (card, muted, border, input…) are lifted to sit consistently above that background. The teal accent stays exactly as it is. Contrast of text and muted text must remain readable in both modes.

**Blocked by:** None — can start immediately.

**Status:** ready-for-human (implementation done; needs an eyeball pass on Windows)

**Recommended model:** Sonnet 5, medium effort — needs a consistent pass across every neutral token of both colour schemes.

Note: builds on the Gray base + teal accent theme (uncommitted at the time of writing). Keep that base.

- [x] No `#ffffff` used as a surface in light mode; page, card, popover are `#f5f6f8`
- [x] Dark foreground is `#e4e6eb`; dark background is `#16181d`
- [x] Dark card / muted / border / input grays re-tuned relative to the new background, still distinguishable (hovered list rows, identicon tile, dividers visible)
- [x] Accent (primary) unchanged in both modes
- [x] Theme test updated to guard the new background/foreground values alongside the accent and radius
- [ ] Checked by eye in both modes on Entries, Clients, Report, Settings and a dialog
