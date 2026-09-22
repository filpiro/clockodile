# 10 — Report screen

**What to build:** The report runs on shadcn. The board keeps its own geometry and tile hover; bars are `primary` on `border` gridlines; each label has a small identicon; the tooltip is shadcn `Tooltip`.

**Blocked by:** 01 — Client identicon; 05 — Shell + Aiuto

**Status:** ready-for-agent

**Model:** Opus, effort medium — board layout and tooltip are tricky, but specified

Spec: `../../shadcn-migration/spec.md` (phase 4 (Report board))

- [ ] Board geometry unchanged; tiles do not use the list row
- [ ] If `Tooltip` cannot anchor to a board tile, keep the board's own tooltip restyled with theme roles (spec § 5)
- [ ] Report board and board geometry tests green
- [ ] `pws -c flutter analyze` has no errors
- [ ] Eyeballed: bars, tooltip, labels
