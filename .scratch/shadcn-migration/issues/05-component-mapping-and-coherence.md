# The mapping table, and the conventions that replace the house layer

Type: grilling
Status: open
Blocked by: ~~03~~ (resolved — see `../research/03-component-inventory.md`); ticket 01 also resolved
Map: ../map.md

## Question

Two outputs, and the second is the one that is easy to skip and expensive to skip.

Ticket 03 has done the inventory — `../research/03-component-inventory.md` holds the full table, the twelve gaps, and the API shapes. This ticket *chooses*, and writes the conventions.

**1. The mapping table.** One row per current widget → the shadcn widget and the variant/props it takes, for everything ticket 03 inventoried: the catui widgets, the third-party ones, and the plain Material still in the tree. Where no shadcn component fits, say what we compose instead — and keep it composed at the call site, not extracted into a new shared widget, unless the same composition appears three or more times.

**1a. The twelve gaps.** Research found no shadcn component for: empty state, FAB, hover-row-with-trailing-actions, segmented control, combined date+time field, imperative `pickDay()`, per-intent hover colour, section rhythm, persistent/updatable toast (→ ticket 10), text-prompt dialog, identicon-in-`Avatar` (→ ticket 06), keep-alive across shell switches (→ ticket 04). Decide the composition for each one this ticket owns.

**1c. The call-site shape changes** that are not colour: `Tooltip` takes a `Widget`, not `message: String`, and shadcn buttons have no `tooltip:` arg — every `tooltip: 'Modifica'` changes shape. `TextField` has no `InputDecoration` — `placeholder: Widget` plus `features: [InputFeature.clear(), …]`, labels and errors from `FormField` inside a `Form`. All 13 `Theme.of(…).textTheme` reads become `.h4()`/`.p()`/`.small()`/`.muted()` extensions. Button variants cover everything we have (`DangerButton` → `DestructiveButton` is a straight swap).

**1b. The colour-role remap.** shadcn's `ColorScheme` has **no** `surface`, `onSurface`, `surfaceVariant`, `error` or `outline` role. Its roles are background/foreground, card, popover, primary, secondary, muted, accent, destructive, border, input, ring, chart1–5. Every one of the 14 `Theme.of(context)` colour reads needs a deliberate target — `surface` → `background` or `card` is a judgement call per site, not a search-and-replace. Also note the trap: the theme knobs' "accent Green" lands on `primary`/`ring`, **not** on shadcn's `accent` role, which is the subtle hover fill and stays slate.

**2. The coherence conventions.** Dropping the house layer removes the thing that was *enforcing* consistency. The user's requirement is explicit: simplify the stack "without losing coherence in interactions, spacing, states, and overall user experience." So write down, as rules a future session can follow without re-deciding:
- **Interaction**: what hover, pressed, focused and disabled look like on a list row vs a button. Which of these shadcn gives for free and which we must pass every time.
- **Destructive intent**: the one way a delete or a "Termina" is styled and confirmed, replacing `DangerButton` + `intentHoverStyle()`.
- **Spacing**: page padding, gutter between controls, gap between sections, form max width — sourced from `ThemeData`/density where possible, and named constants only where the theme has no answer. Explicitly decide whether *any* of `AppTokens` survives as an in-repo constants file, since "no house layer" argues against it and 10 magic numbers scattered across 6 screens argues for it.
- **States**: loading, empty, and error presentation — one shape each.
- **Icon-only controls**: size, tooltip, and hit target.

**3. The one question this ticket must not dodge.** Research puts the hover row at roughly three rows of composition *per list row, across five screens* — `Clickable` + `Basic` + a hand-rolled `Opacity`/`IgnorePointer` reveal, since nothing in shadcn reveals a trailing widget on hover. That is the strongest counter-pressure to the no-house-layer decision. Either accept the repetition, or allow exactly one local widget for it and say so explicitly — a single named exception is a decision; five screens quietly diverging is the failure the coherence rules exist to prevent. Same question, smaller, for `AppTokens`: research says about half dissolves into `theme.radiusMd`/`paddingMd`/`WidgetState` styling and five or six constants are genuinely homeless (`formMaxWidth`, `sectionGap`, `dotRadius*`, `fabClearance`, `tileMargin`). Five constants in one local file, or inline literals?

Where should these rules physically live so they are actually read — `style/components.md` rewritten, a new `docs/adr/` entry, or a section of `spec.md`?

Use `/grilling`.
