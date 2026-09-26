# UI conventions and the shadcn_flutter mapping

There is no house style package. `catui` is gone, and nothing replaces it: this file
*is* the coherence layer. It holds the rules a session follows so that screens built
months apart still look like one app, plus the table saying what each retired widget
became.

Decided in [wayfinder ticket 05](../.scratch/shadcn-migration/issues/05-component-mapping-and-coherence.md).

**The governing principle**: reach for the simplest native shadcn_flutter component
that matches the behaviour actually needed. Do not preserve an abstraction just
because the old UI layer had one. Compose at the call site; a shared widget needs
three or more call sites *and* logic of its own to earn a file.

---

## 1. The rules

### Spacing

| Rule | Value |
|---|---|
| Page padding | `pagePadding` (24) — a `const` in the file that uses it; shadcn has no padding getter on `ThemeData` |
| Gutter between controls in a row | `.gap(8)` |
| Between sections | a `Divider`, then `.gap(24)` — no 48px section gap |
| Form / prose max width | `formMaxWidth` (560) — **the only shared constant in the repo** |
| List row padding | owned by `AppListRow`; no call site sets it |

Everything else comes from `ThemeData`: `theme.radiusSm/Md/Lg` (and `theme.borderRadiusMd` etc.),
`theme.iconTheme`, `theme.density`. Never hand-write a radius, an icon size, a disabled
alpha or a hover alpha — shadcn styles `WidgetState` itself. A number that appears in
exactly one file is a `const` at the top of that file, not a shared token.

### Colour roles

shadcn's `ColorScheme` has **no** `surface`, `onSurface`, `surfaceVariant`, `error` or
`outline`. The roles are: `background`, `foreground`, `card`, `popover`, `primary`,
`secondary`, `muted`, `accent`, `destructive`, `border`, `input`, `ring`, `chart1–5`.

- `background` is the page. The app is flat — sections are **not** cards.
- `card` / `popover` only where a genuinely raised surface exists: dialogs, toasts, popovers.
- `muted` / `mutedForeground` for inert fills and secondary text.
- `primary` for the single main action, and for the report bars.
- `border` for hairlines, dividers and gridlines.
- `destructive` for delete, for "Termina", and for invalid values.

**Trap**: the theme's accent colour (Green) lands on `primary` and `ring`, **not** on
shadcn's `accent` role — `accent` is the subtle hover fill and stays slate. Never reach
for `accent` expecting green.

Translations from the old Material roles: `onSurfaceVariant` → `mutedForeground`,
`surfaceContainerHighest` → `muted`, `outlineVariant` → `border`, `error`/`onError` →
`destructive`/`destructiveForeground`, `surface` → `background`.

### Typography

There is no `textTheme`. Text styling is extension methods that chain:
`Text('x').large().bold()`.

`.h1()` 30 · `.h2()` 24 · `.h3()` 20 · `.h4()` 18 · `.p()` 14 · `.lead()` 16 muted ·
`.large()` 16 semibold · `.small()` 12 · `.muted()` (sets `mutedForeground`) ·
`.italic()` `.bold()` `.semiBold()` `.mono()`.

From the old code: `titleSmall` → `.h4()`, `bodySmall`/`labelMedium` → `.small()`,
`bodyLarge` → `.p()`, and `.muted()` anywhere `onSurfaceVariant` was the colour.

### Interaction

`Clickable` supplies hover, pressed, focused and disabled as `WidgetStateProperty`
decoration — declarative, not a tween, and `onFocus` comes free so the focus-within
case needs no hand-rolling. There is **no ink ripple anywhere in shadcn**; the
interaction language is state-driven decoration.

- **List row**: `Clickable` gives the hover fill. Nothing else on a row changes on hover.
- **Button**: the `ButtonStyle` variant owns all four states. Never pass hover colours.
- **Disabled**: never hand-compute a faded foreground — pass `enabled: false`.

### Destructive intent

One way, everywhere:

- A text action is a `DestructiveButton`, colour always on (e.g. "Termina").
- An icon action (row delete, session delete) is **ghost, red only on hover**:
  `ButtonStyle.ghostIcon().withForegroundColor(hoverColor: colorScheme.destructive)`.
  A filled red square on every row was too loud (Attività eyeball).
- In a row, every icon is ghost at rest; nothing is coloured until hovered.
- Anything irreversible confirms through an `AlertDialog` whose confirm action is a
  `DestructiveButton`.

### Icon-only controls

`IconButton(variance: ButtonStyle.ghostIcon(), density: ButtonDensity.icon)`. Size comes
from `ButtonSize` under the app's `Density.reducedDensity` — never an `iconSize:`.

shadcn buttons have **no `tooltip:` argument**. A tooltip is a wrapper:

```dart
Tooltip(
  tooltip: const TooltipContainer(child: Text('Modifica')),
  child: IconButton(...),
)
```

Row actions do not write that wrapper: `AppListRow` bakes icon, style, tooltip and hit
target into its `onEdit`/`onDelete` slots. Only one-off icon buttons wrap by hand.

### States

- **Loading, page level**: `Scaffold.loadingProgress` — a top bar, free.
- **Loading, one control**: `Spinner` inline.
- **Empty**: `EmptyState` (`lib/shared/widgets/empty_state.dart`) — dimmed illustration
  above a `.muted()` message. Kept as-is; shadcn has no empty-state primitive.
- **Error, transient**: a toast.
- **Error, in place of content**: `.muted()` text where the content would be.

### Toggle groups

Mutually exclusive choices are `Toggle`s, not a segmented widget — shadcn has none, and
`MultipleChoice` is for multi-select we do not have.

```dart
Toggle(
  value: selected == Thing.a,
  style: const ButtonStyle.outline(), // not ButtonDensity.compact: it strips padding and border
  onChanged: (v) => setState(() => selected = v ? Thing.a : null),
  child: const Text('Oggi'),
)
```

Laid out in a `Wrap(spacing: 8)` or `Row(...).gap(8)`. Exclusion is one state field on
the parent. No fixed sizing — labels vary in width. `outline` because the selected state
already fills; never hand-swap primary/outline.

### Pages

`Scaffold(headers: [...], footers: [...], child: ...)`. The toolbar goes in `headers`,
the footer in `footers`. There is **no `AppPage` wrapper** — `maxWidth` and scrolling are
`ConstrainedBox` and `SingleChildScrollView` at the call site.

There is no FAB in shadcn and no slot for one. Primary page actions are normal
`PrimaryButton`s in the header.

### Sections

Flat, not carded: a title (`.h4()`), an optional `.muted().small()` description, the
content, then a `Divider`. A settings row is `Basic(title:, subtitle:, trailing:)` used
directly — no widget, no width cap of its own.

### Italian

The app is Italian-only; shadcn ships English only. `lib/shadcn_it.dart` holds
`ShadcnLocalizationsIt extends ShadcnLocalizationsEn` plus its delegate, passed as
`ShadcnApp(localizationsDelegates: [ShadcnLocalizationsIt.delegate])` — ours comes first,
so it wins. It overrides only the strings that reach our screens: month and weekday
names, `datePickerSelectYear`, `buttonCancel`/`buttonSave`, `timeHour`/`timeMinute`, the
picker placeholders, and the text-field context menu (`menuCut`, `menuCopy`, …). A string
it misses renders English; it never crashes.

**After any shadcn upgrade, diff `lib/l10n/shadcn_en.arb` in the package for new strings.**

Dates in the UI go through `lib/shared/utils/format.dart` (`dmy`, `dmyShort`, `hhmm`),
never through shadcn's `formatDateTime`. Times from `TimePicker` already render `09:05`,
24-hour. No `intl`, no `flutter_localizations`. Decided in
[wayfinder ticket 09](../.scratch/shadcn-migration/issues/09-italian-localization.md).

---

## 2. Shared widgets

The whole list.

| Widget | Why it exists |
|---|---|
| `AppListRow` (`lib/shared/widgets/app_list_row.dart`) | `Clickable` + `Basic`, with `onEdit`/`onDelete` rendering the action pair (icon, style, tooltip, hit target). 5 call sites, and it owns the row interaction language. Rows needing something else pass `trailing:` instead. |
| `EmptyState` (`lib/shared/widgets/empty_state.dart`) | Survives unchanged apart from `.muted()` text. shadcn has no equivalent. |
| `DateFilterBar` (`lib/shared/widgets/date_filter_bar.dart`) | Oggi / Ieri `Toggle`s beside a `DateField` — see *The date filter*. Shared by Attività and Report. |
| `Identicon` (`lib/shared/widgets/identicon.dart`) | A Client's picture, drawn from its id (ADR 0004). |
| `app_toast.dart` | `navigatorKey` and the toast helpers — see *Third-party* below. |
| `DateField` (`lib/shared/widgets/date_field.dart`) | `ObjectFormField<DateTime>` + shadcn's `DatePickerDialog`, displaying `dmyShort()` ("22/09/26"). Exists because `DatePicker` hard-codes US order ("September 22, 2026") in a `ShadcnLocalizations` *extension*, which no translation can override. Two call sites, but a correctness fix, not a style choice. |

Plus one constant, `formMaxWidth = 560`.

`ClientField` stays app code (it reads `ClientsCubit`), but shrinks to an `AutoComplete`
wrapping a plain `TextField`.

---

## 3. Mapping table

### catui → shadcn

| Retired | Becomes |
|---|---|
| `HoverTile` | `AppListRow` (`Clickable` + `Basic`) — actions always visible, no hover reveal |
| `EditIconButton` / `DeleteIconButton` | `AppListRow`'s `onEdit`/`onDelete`; standalone use is `IconButton` + `ButtonStyle.ghostIcon()` (delete adds a destructive hover foreground) |
| `DangerButton` | `DestructiveButton` |
| `intentHoverStyle()` | **Gone.** Intent colour is always on; see *Destructive intent* |
| `EmptyState` | Kept as-is |
| `CatPage` | `Scaffold` + `ConstrainedBox`/`SingleChildScrollView` at the call site |
| `CatSection` | `.h4()` title + `.muted().small()` description + `Divider` |
| `CatSectionHeader` | `Text(...).h4()` in a `Row` with `Expanded` + trailing |
| `CatSettingRow` | `Basic(title:, subtitle:, trailing:)` |
| `CatSegmented` | `Toggle`s, mutually exclusive |
| `CatTag` | `Badge` family — **except** the Aiuto key-caps, which become `KeyboardDisplay` |
| `CatDateTimeField` | `DateField` + `TimePicker` side by side. Not typeable; we never typed them |
| `ClientDot` | `Avatar` — identity handled by wayfinder ticket 06 |
| `catConfirm` | `AlertDialog` + `showOverlay(context, DialogConfiguration(), ...)`, confirm = `DestructiveButton` when destructive |
| `catTextInput` | Same, hand-composed with a `TextField`. No helper exists |
| `catSurfaceDecoration` | `OutlinedContainer` |
| `AppTokens` | Dissolved into `ThemeData`; only `formMaxWidth` survives |

### Material → shadcn

| Retired | Becomes |
|---|---|
| `Scaffold` | shadcn `Scaffold` — `headers`/`footers`/`child`, no `appBar`, no FAB, no drawer |
| `AppBar` | shadcn `AppBar` inside `Scaffold.headers` |
| `FloatingActionButton` | **Deleted.** `PrimaryButton` in the page header |
| `AlertDialog` / `showDialog` | `AlertDialog` + `showOverlay`, closed with `Navigator.pop(context, value)` |
| `TextField` | shadcn `TextField`. **No `InputDecoration`** — `placeholder: Widget`, `features: [InputFeature.clear(), ...]`, labels and errors from `FormField` inside a `Form` |
| `TextFormField` | `FormField` + `TextField` inside a `Form` |
| `Switch` | `Switch` (richer: `leading`/`trailing`/`gap`) |
| `Slider` | `Slider` — takes a `SliderValue`, not a `double` |
| `ListTile` | **None.** `Basic`, or `AppListRow` |
| `ChoiceChip` | `Toggle` |
| `Tooltip` | `Tooltip(tooltip: Widget, child:)` — a widget, not `message: String` |
| `InkWell` | `Clickable` |
| `IconButton` | `IconButton` + a `ButtonStyle....Icon()` variance |
| `FilledButton` | `PrimaryButton` |
| `OutlinedButton` | `OutlineButton` |
| `TextButton` | `TextButton` |
| `CircularProgressIndicator` | `CircularProgressIndicator` or `Spinner` |
| `LinearProgressIndicator` | `Progress`, or `Scaffold.loadingProgress` |
| `VerticalDivider` | `Divider` — the rail divider dies with the rail anyway |
| `SnackBar` | a toast |
| `showDatePicker` / `showTimePicker` | `DateField` / `TimePicker` widgets. **No imperative form exists** |
| `Theme.of(context)` | `Theme.of(context)` — shadcn's, returning shadcn `ThemeData` |

### Third-party

| Retired | Becomes |
|---|---|
| `sonner_toast` | `showToast()` + `ToastLayer`, already installed under `ShadcnApp`. Native stack, shadcn defaults (bottomRight, 320px); helper borrows `navigatorKey.currentContext`; AI toast uses `showDuration: Duration(days: 365)` and is closed and raised again on each state change. See wayfinder ticket 10 |
| `catppuccin_flutter` | Gone — see wayfinder ticket 06 |

---

## 4. The date filter

The one behaviour change this migration makes, because the control could not be ported
without deciding it.

The bar is a **date filter**, and there is always exactly one effective date.
A `DateField` is permanently visible; `Oggi` and `Ieri` are `Toggle` shortcuts beside it
in the same `Wrap`. They are mutually exclusive in both directions:

- picking a custom date clears Oggi/Ieri;
- selecting Ieri clears Oggi and the custom date;
- selecting Oggi clears Ieri and the custom date.

`Oggi` is the default. This fixes today's bug where the manually picked date survives a
switch back to Oggi.

**`Tutte` / `DateFilter.all` is removed**, along with everything behind it: the
pagination (`limit`, `loadMore`, `canLoadMore`, "Carica altre"), the `showAll` flag, and
the `Ctrl+3` shortcut. Activities are always viewed in a bounded window. `DateFilter.all`
was runtime state only — `limit` reached no further than
`db.watchClosedSessions(limit:)` — so **no schema change, no migration, no data loss**.

The cubit collapses `DateFilter filter` + `DateTime? pickedDay` into a single
`DateTime day`; the toggles derive their `value` by comparing it to today/yesterday. The
invalid state becomes unrepresentable.

A date *range* (two `DateField`s) is a plausible future want and explicitly not now.

### Known losses, accepted

- `AutoComplete` takes `List<String>` suggestions, so **no leading dot or avatar in the
  client dropdown**. Client colour was decorative; it is gone regardless.
- `DateField`/`TimePicker` open a dialog by default on desktop (`mode:` can make it a popover), **not keyboard-typeable**. We never
  typed them, and splitting date from time is an improvement: editing a time no longer
  forces a walk through the date step.
- No hover reveal on row actions. They are always visible and muted — better for
  keyboard, and one less interaction language.

---

## 5. Gaps found during the build

What shadcn did not do as expected, and what we did instead.

- **Title bar**: `window_manager`'s `WindowCaption` is a Material widget. The caption
  is hand-made in `lib/main.dart` from shadcn buttons; close turns `destructive` on
  hover, and the buttons have wider gaps than the defaults.
- **`Basic` top-aligns `leading`**. The identicon sat a few px above the text.
  `AppListRow` centres its leading widget. The report board tile nudges it down 2px
  instead: a short tile shows only the name, and a centred icon gets cut off.
- **Report board tiles** rest on `muted`, not solid `primary`; hover turns a thin left
  edge `primary`. Solid bars were too loud. This corrects "`primary` for the report
  bars" above: `primary` is the hover edge, not the fill.
- **Entry editor timestamps**: `DateField` above `TimePicker`, stacked, not side by
  side — side by side was too cramped at `formMaxWidth`.
- **`showToast` has no "forever"**. The sticky AI toast uses a one-year duration.

## Screen-by-screen inventory

Deleted. It inventoried a stack that no longer exists, and rewriting it before the
screens are built would be fiction. The execution effort regenerates it if it is still
wanted.
