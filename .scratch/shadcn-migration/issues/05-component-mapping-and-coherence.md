# The mapping table, and the conventions that replace the house layer

Type: grilling
Status: resolved
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

## Resolution

**The mapping table and the conventions live in [`style/components.md`](../../../style/components.md)**, rewritten in full. That file is the durable artifact; `spec.md` (ticket 08) links to it rather than restating it. The old per-screen inventory was deleted — it catalogued a stack that will not exist.

The decisions, in the order they were taken:

**Scope-setting**
- **One shared row widget, `AppListRow`** (`Clickable` + `Basic`) — 5 call sites earns it, and a widget in *this* repo is not the house layer. But the hover *reveal* is deleted: **row actions are always visible and muted.** That removes the hand-rolled `Opacity`/`IgnorePointer`, which was research's single biggest hand-composition cost.
- **`AppTokens` dissolves.** Theme tokens wherever they reach, approximating current values where they must; a value used in one file is a `const` in that file. **`formMaxWidth` (560) is the only shared constant left** — `sectionGap` dies to `Divider` + `.gap(paddingLg)`, `fabClearance` dies with the FAB, `tileMargin`/`pillMinHeight`/`hoverOverlayAlpha`/`disabledAlpha` were Material fudge.
- **Governing principle, set by the user and applied to every later answer:** the simplest native shadcn component that matches the behaviour Clockodile actually has — never an abstraction inherited from the old UI layer.
- **Conventions live in `style/components.md`**, not an ADR (these are standing conventions, not a decision record) and not `spec.md` (which dies with the migration).

**Composition**
- **Sections stay flat** — `.h4()` title + `.muted().small()` description + `Divider`. No `Card` per section: Settings is a list of settings and carding it over-segments the page.
- **`CatSettingRow` → bare `Basic`** used directly at its 3 sites. Only `AppListRow` and `EmptyState` are shared widgets. Nothing else.
- **`CatPage` → `Scaffold(headers:, footers:, child:)`** + `ConstrainedBox`/`SingleChildScrollView` at the call site. No `AppPage` wrapper.
- **The FAB is deleted**, not rebuilt. shadcn has no FAB and no slot; the primary action becomes a `PrimaryButton` in the page header. Kills `fabClearance` and the two clearance paddings.
- **`EmptyState` kept as-is**, illustration included, only the text style changes.

**Interaction language**
- **Destructive intent is always-on, never hover-revealed.** `DestructiveButton` / `destructiveIcon()`. **In a row, destructive is the only coloured icon** — everything else is ghost. `intentHoverStyle()` has no replacement and needs none.
- **Tooltips**: shadcn buttons have no `tooltip:` arg, and the scalable answer is not a generic wrapper widget — `AppListRow` bakes tooltip, icon and hit target into its `onEdit`/`onDelete` slots, so the volume disappears at the source. Only the 2 surviving one-off tooltips wrap by hand (there were 6; 2 were the deleted FABs, the rest are rail labels).
- **States**: `Scaffold.loadingProgress` for page waits, `Spinner` for one control, `EmptyState` for empty, toast for transient errors, `.muted()` text in place of content for a failed load.

**Colour and type**
- **Flat page ⇒ `background`**; `card`/`popover` only for genuinely raised surfaces. `muted` for inert fills, `primary` for the main action and the report bars, `border` for hairlines, `destructive` for delete/"Termina"/invalid. The 5 judgement sites resolved: window caption → `background`, entries row colouring → `muted`/`mutedForeground`, report negative values → `destructive`, the hand-styled settings button → `DestructiveButton`, report bars → `primary` on `border` gridlines.
- **The `accent` trap recorded**: the theme's Green lands on `primary`/`ring`, never on shadcn's `accent` role.
- **Typography**: extensions, not `textTheme`. `titleSmall` → `.h4()`, `bodySmall`/`labelMedium` → `.small()`, `bodyLarge` → `.p()`.

**Components chosen over research's candidates**
- **Segmented → `Toggle`**, mutually exclusive by one parent state field, `ButtonStyle.outline(density: compact)` in a `Wrap(spacing: 8)`. Not `Tabs`/`TabList` (navigation, not values) and not `MultipleChoice` (a real component, but Clockodile has no multi-select). Covers all 4 sites identically.
- **`ClientField` → `AutoComplete` + a plain `TextField`**, 3-char threshold preserved. Losing the per-suggestion dot is accepted — client colour was decorative.
- **`CatDateTimeField` → separate `DatePicker` + `TimePicker`.** Not typeable, which costs nothing (the user never typed them) and splitting them is an improvement: editing a time no longer forces a walk through the date step.
- **`pickDay()` deleted.** Its one caller is `DateFilterBar` itself, so the allowed range already lives in one place without the helper; the `DatePicker` carries it inline.

**The one behaviour change** (see `style/components.md` §4)
- The bar becomes a date filter with **always exactly one effective date**: a permanent `DatePicker` plus `Oggi`/`Ieri` shortcut toggles, mutually exclusive in both directions. Fixes the existing bug where a manually picked date survived a switch back to Oggi.
- **`Tutte` / `DateFilter.all` is removed entirely**, with its pagination (`limit`, `loadMore`, `canLoadMore`, "Carica altre"), the `showAll` flag and the `Ctrl+3` shortcut. Verified safe: `all` was runtime state only, `limit` reached no further than `db.watchClosedSessions(limit:)` — **no schema change, no migration, no data loss.**
- The cubit collapses `DateFilter` + `DateTime? pickedDay` into one `DateTime day`, making the invalid state unrepresentable. A date *range* is explicitly deferred.
