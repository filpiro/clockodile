# 02 — ShadcnApp root

**What to build:** The app root is `ShadcnApp` with the locked theme knobs, both light and dark built from them, dark by default, still switched by the theme cubit. The window has a hand-made title bar. The retention purge runs before the app starts instead of behind a loading gate.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

Spec: `../../shadcn-migration/spec.md` (phase 1, sections 1 and 5)

- [ ] `shadcn_flutter: ^0.0.54` added; SDK floor `^3.13.0`
- [ ] Theme knobs exactly as the map's Notes and ticket 07 lock them (`radius: 0.7`, Solid, blur off, reduced density, Slate/Green)
- [ ] Design tokens dissolve into the theme; only the form max width survives as a shared constant
- [ ] Title bar: drag, minimise, maximise, close — no Material caption
- [ ] Startup gate deleted; purge awaited before `runApp`
- [ ] Theme test rewritten: green primary in both brightnesses, radius 0.7
- [ ] `pws -c flutter analyze` has no errors
- [ ] App may throw at runtime while screens are still catui — expected
