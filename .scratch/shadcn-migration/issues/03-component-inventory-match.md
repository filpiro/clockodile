# Which shadcn component covers each thing we currently put on screen

Type: research
Status: resolved
Map: ../map.md

## Question

Inventory-building, not deciding — produce the candidate list with real API surfaces so the mapping ticket can choose. Source: `.claude/skills/shadcn-flutter/components/**` and pub.dev API docs.

For each item below, name the candidate shadcn component(s), the constructor arguments that matter, and anything the docs say it *cannot* do:

**Third-party / house widgets being retired**
- `sonner_toast` (`SonnerOverlay`, `Sonner.overlayKey`, config, swipe-to-dismiss, motion) → shadcn Toast: how is it mounted, is there an overlay/host widget, can a toast be persistent (no timeout), can it carry buttons that open dialogs, can it be targeted/dismissed by key from outside the widget tree?
- `RawAutocomplete` client field (`client_field.dart`) → AutoComplete vs Select vs ItemPicker vs Command: which allows free text that is *not* in the list (we create clients by typing a new name)?
- `CatDateTimeField` (3 uses) and `showDatePicker` → DatePicker / TimePicker / FormattedInput: is there a combined date+time field, and is it keyboard-typeable or popover-only?
- `CatSegmented` (date filter bar) → Tabs / TabList / Switcher / Chip: which is the segmented-control shape?
- `HoverTile` (list rows, `dense` variant) → is there a hoverable list-row primitive, or is this `Clickable`/`Button` with a ghost variant?
- `EditIconButton` / `DeleteIconButton` / `DangerButton` / `intentHoverStyle()` → Button variants: what variants exist (ghost, outline, destructive, …), and how is an icon-only button expressed?
- `EmptyState` → is there an empty-state primitive, or is this composed by hand?
- `CatPage` / `CatSection` / `CatSectionHeader` / `CatSettingRow` / `CatTag` → Scaffold + Card + Divider + Badge/Chip equivalents; what the layout guide says about page padding, gaps and section rhythm.
- `AppTokens` (radius, iconSize, gutter, pagePadding, sectionGap, dotRadius, formMaxWidth, pillMinHeight, hoverFade, disabledAlpha) → which of these come from `ThemeData`/density/scaling for free and which have no home.

**Plain Material still in the tree**
`Scaffold`, `AppBar`, `FloatingActionButton`, `AlertDialog`/`showDialog`, `TextField`, `Switch`, `Slider`, `ListTile`, `Tooltip`, `CircularProgressIndicator`, `LinearProgressIndicator`, `VerticalDivider`, `InkWell`, `IconButton`, `TextButton`/`FilledButton`/`OutlinedButton`, `Theme.of(context)` (14 uses — what replaces it).

**Shell**
Navigation shapes available for a desktop left-rail-ish app: NavigationMenu, Menubar, Tabs/TabPane, Sidebar-anything, Scaffold's slots. Note for each whether it preserves screen state across switches.

**Typography/colour access**
The `.h1()`/`.p()`/`.muted()` extension set, and how to read theme colours in a widget.

Capture findings as Markdown in the repo and link them from this ticket.

## Answer

Full inventory: [research/03-component-inventory.md](../research/03-component-inventory.md)
— mapping table (current widget | candidates | key args | limits), plus prose on the
three risky items and the `AppTokens` question.

**The three risky ones**

- **Toast.** `showToast(context:, builder:, location:, dismissible:, showDuration:,
  onClosed:) → ToastOverlay`, hosted by `ToastLayer` which `ShadcnApp` already
  installs. Persistent: **no** — `showDuration` is non-nullable, default 5s, no
  sentinel; workaround is an absurdly long `Duration`. Action buttons that open
  dialogs: **yes** — the builder gets a real context and a `ToastOverlay` handle
  (keep the `navigatorKey` hand-off, since the layer's position relative to the
  Navigator is undocumented). Dismiss from outside: **yes, by holding the returned
  `ToastOverlay` and calling `close()`** — there is no key lookup and no
  `dismissAll()`. Update in place: **no** — `ToastOverlay` exposes only `isShowing`
  and `close()`, so the AI toast's live byte count needs a `BlocBuilder` *inside*
  the toast builder rather than a re-raise per state.
- **Client field.** Only **`AutoComplete`** takes free text: it is a popover wrapper
  around *your own* `TextField`, filtering is entirely yours (`suggestions:
  List<String>`), and `mode`/`completer` control how a pick edits the text. `Select`,
  `ItemPicker` and `Command` are all closed-set — `Command` has a search box but
  returns a chosen item, not the query. Cost of `AutoComplete`: suggestions are plain
  strings, so no per-option `ClientDot`/identicon in the dropdown.
- **Hover row with trailing actions.** No `ListTile`, no row primitive. `Clickable`
  is the right base and is better than what we have (`onHover` *and* `onFocus`, plus
  `WidgetStateProperty` decoration/padding/textStyle/iconTheme), `Basic` supplies the
  leading/title/subtitle/trailing arrangement — but **nothing reveals a trailing
  widget on hover**, so the `Opacity`/`IgnorePointer` reveal stays hand-written.
  `Hover` is the wrong tool (500ms `waitDuration`, built for hover cards). Biggest
  single hand-composition cost in the migration.

**Where nothing fits (hand composition required):** empty state, FloatingActionButton,
list row / `ListTile`, segmented control, combined date+time field, imperative
`pickDay()` (DatePicker is a widget, not a function), per-intent hover colour
(`intentHoverStyle`), section rhythm (`CatSection`), persistent+updatable toast,
text-prompt dialog, identicon in `Avatar` (`provider` is an `ImageProvider`, not SVG),
and keep-alive across shell switches (undocumented for `Tabs`/`TabPane`/`Switcher`).

**Shell:** `NavigationRail` (`children`/`selectedKey`/`onSelected`/`expanded`/
`labelType`/`header`/`footer`) is the closest match and holds no content, so today's
`IndexedStack` keeps working and state preservation stays an app-level fact.

**`AppTokens`:** roughly half comes free from `ThemeData` — `radius`→`theme.radiusMd`,
`tileRadius`→`radiusSm`, `iconSize`→`theme.iconTheme` + `ButtonSize`/`ButtonDensity`,
`gutter`/`pagePadding`→`paddingMd`/`paddingLg`, `segmentGap`→`.gap(4)`, and
`disabledAlpha`/`hoverOverlayAlpha`/`hoverFade` dissolve into `WidgetState` styling.
Homeless: `formMaxWidth`, `sectionGap`, `dotRadius*`, `fabClearance`, `tileMargin`.
Dead with Material: `pillMinHeight`. Five or six constants, not a house layer.

**Also worth flagging for the mapping ticket:** there is no `Theme.of(context).textTheme`
— all 13 `Theme.of` uses become `.h1()`/`.p()`/`.muted()`/`.small()` extensions — and
Material's `onSurfaceVariant` / `surfaceContainerHighest` / `outlineVariant` / `error`
become `mutedForeground` / `muted` / `border` / `destructive`. `Tooltip` takes a
**Widget** (`TooltipContainer`), not a `message:` string, so every tooltip call site
changes shape. And `TextField` has no `InputDecoration`: labels come from
`FormField(label:)` inside a `Form`.
