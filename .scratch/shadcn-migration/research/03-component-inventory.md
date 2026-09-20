# Component inventory: catui/Material → shadcn_flutter candidates

Ticket: [03-component-inventory-match](../issues/03-component-inventory-match.md)
Status: complete. **Inventory, not decision** — every row lists candidates and their
ceilings; the choosing happens in ticket 05.

Sources, in order of authority:

1. Offline shadcn docs in this repo: `.claude/skills/shadcn-flutter/components/**`,
   `.claude/skills/shadcn-flutter/guides/**` (cited as `components/<path>` /
   `guides/<file>`).
2. pub.dev API docs, `https://pub.dev/documentation/shadcn_flutter/latest/shadcn_flutter/`
   — used where the offline docs have no property table (`showToast`, `ToastOverlay`,
   `ToastLayer`, `ButtonStyle` constructors, `showOverlay`).
3. Current code: catui `lib/src/` at
   `~/AppData/Local/Pub/Cache/git/catui-c087d1ed…/`, and `lib/` in this repo.

A pervasive fact that colours everything below (`guides/interop.md`): **shadcn_flutter
depends on neither Material nor Cupertino.** A bare `ShadcnApp` installs no `Theme`,
no `Material`, no `ScaffoldMessenger`, and no Material localization delegates; any
Material widget under it *asserts at build time*. So "keep this one Material widget"
is not a free option — it costs `MaterialShadcnApp` or a `MaterialLayer` subtree.
That is consistent with the map's **no Material interop glue** decision, which means
every Material widget in the tree must actually go.

---

## Mapping table

### Third-party / house widgets being retired

| Current widget | shadcn candidate(s) | Key args | Limits / notes |
| --- | --- | --- | --- |
| `sonner_toast` (`SonnerOverlay`, `Sonner.overlayKey`, `Sonner.toast`, `Sonner.dismissAll`) | `showToast()` + `ToastLayer` (`components/feedback/toast.md`, pub.dev `showToast`) | `showToast({required BuildContext context, required ToastBuilder builder, ToastLocation location = bottomRight, bool dismissible = true, Curve curve, Duration entryDuration = 500ms, VoidCallback? onClosed, Duration showDuration = 5s}) → ToastOverlay` | `showDuration` is **non-nullable**; no persistent mode. No key/id. No update-in-place. See [Toast](#risky-1-toast) below. |
| `ClientField` (`RawAutocomplete`) | **`AutoComplete`** (only free-text-capable one), `Select`, `ItemPicker`, `Command` | `AutoComplete({required List<String> suggestions, required Widget child /* your TextField */, AutoCompleteMode mode = replaceWord, AutoCompleteCompleter completer, BoxConstraints? popoverConstraints, OverlayConfiguration? overlayConfiguration, bool? adaptiveOverlay})` | Only `AutoComplete` wraps a real `TextField`, so only it accepts text not in the list. See [Client field](#risky-2-client-field). |
| `CatDateTimeField` (3 uses: entry edit start/end, report) | **No single component.** `DatePicker` + `TimePicker` side by side, or `FormattedInput` for a typeable field | `DatePicker({DateTime? value, ValueChanged<DateTime?>? onChanged, Widget? placeholder, PromptMode? mode /* popover\|dialog */, CalendarView? initialView, CalendarViewType? initialViewType, Widget? dialogTitle, DateStateBuilder? stateBuilder, bool? enabled})`; `TimePicker({TimeOfDay? value, ValueChanged<TimeOfDay?>? onChanged, PromptMode mode, Widget? placeholder, bool? use24HourFormat, bool showSeconds = false, Widget? dialogTitle, bool? enabled})` | **Gap:** no combined date+time field (`components/form/date_picker.md`, `time_picker.md`). Both are trigger-widgets that open a popover or dialog — **not keyboard-typeable**. `TimePicker` values are `TimeOfDay`, `DatePicker` `DateTime`: recombining into one `DateTime` is app code, as `CatDateTimeField._pick` already does. `use24HourFormat` exists, so the Italian 24h read survives without `flutter_localizations`. |
| `showDatePicker` (Material, via `pickDay()` in `date_filter_bar.dart`) | `DatePicker` with `mode: PromptMode.dialog`, or `Calendar`/`CalendarView` inside your own `showOverlay` | as above; `components/utility/calendar.md` for the bare grid | No imperative `Future<DateTime?> showDatePicker(...)` equivalent in the docs — `DatePicker` is a *widget* with `value`/`onChanged`, not a function. `pickDay()`'s "one place for the allowed range" idiom does not survive as a function call; it becomes either a shared `DatePicker` config or a hand-rolled `showOverlay` + `Calendar`. **Flag: composition needed.** |
| `CatSegmented` (date filter bar) | `Tabs` / `TabList` (underline tabs), `Toggle`, `Chip`, or literally what catui already does (`PrimaryButton` when selected, `OutlineButton` otherwise) | `Tabs({required int index, required ValueChanged<int> onChanged, required List<TabChild> children, bool expand, EdgeInsetsGeometry? padding})`; `TabList({required List<TabChild> children, required int index, ValueChanged<int>? onChanged})`; `Chip({required Widget child, Widget? leading, Widget? trailing, VoidCallback? onPressed, AbstractButtonStyle? style})` | **No segmented-control component.** `Tabs`/`TabList` are tab strips (index-based, `TabChild` carries a content panel), not a joined pill group. `Switcher` is a swipe-transition content switcher, not a control. `Chip` has no selected state — selection is styled by hand via `style`. Nearest shape is `ButtonStyle.primary`/`.outline` in a `Row(...).gap(4)` — i.e. catui's own approach, minus catui. |
| `HoverTile` (list rows, `dense`) | **`Clickable`** (`components/other/clickable.md`); or `Button(style: ButtonStyle.ghost())`; `Basic` for the leading/title/subtitle/trailing arrangement | `Clickable({required Widget child, bool enabled, ValueChanged<bool>? onHover, ValueChanged<bool>? onFocus, WidgetStateProperty<Decoration?>? decoration, WidgetStateProperty<EdgeInsetsGeometry?>? padding, WidgetStateProperty<MouseCursor?>? mouseCursor, VoidCallback? onPressed, bool focusOutline, bool disableHoverEffect, WidgetStatesController? statesController, …})` | **No list-row primitive.** No `ListTile`. See [Hover row](#risky-3-hover-row). |
| `EditIconButton` / `DeleteIconButton` | `IconButton` / `Button(style: ButtonStyle.ghostIcon())` | `ButtonStyle` named ctors: `primary, secondary, outline, ghost, link, text, destructive, fixed, card, menu, menubar, muted`, each with an `…Icon` twin (`primaryIcon, secondaryIcon, outlineIcon, ghostIcon, linkIcon, textIcon, destructiveIcon, fixedIcon`). All take `{ButtonSize size = normal, ButtonDensity density = normal (icon for icon variants), ButtonShape shape = rectangle}`. `ButtonSize`: `xSmall, small, normal, large, xLarge`. `ButtonDensity`: `compact, dense, normal, comfortable, icon, iconDense, iconComfortable`. (pub.dev `ButtonStyle`; names cross-checked against `components/**`.) | Icon-only = an icon variant + `density: ButtonDensity.icon`, i.e. `IconButton(icon: …, variance: ButtonStyle.ghostIcon())`. No `tooltip:` argument on the button — wrap in `Tooltip(tooltip: TooltipContainer(child: Text(…)), child: …)` (`components/overlay/tooltip.md`). |
| `DangerButton` | `DestructiveButton` / `Button(style: ButtonStyle.destructive())` | same as `Button` | Direct hit. Loses nothing. |
| `intentHoverStyle()` (muted at rest → accent on hover) | `Clickable`/`Button` `onHover` + `WidgetStateProperty` styling, or `ButtonStyle.ghost()`'s stock hover | `Clickable.decoration`/`textStyle`/`iconTheme` are `WidgetStateProperty` | **No equivalent.** shadcn's ghost hover is a uniform muted fill; a *per-intent* hover colour (pencil→primary, trash→destructive) has no built-in. Cheapest replacement: use `ButtonStyle.ghostIcon()` for edit and `ButtonStyle.destructiveIcon()`/a ghost-with-destructive-foreground for delete, accepting that the intent colour is now always-on rather than on-hover. Otherwise hand-composed. **Flag.** |
| `EmptyState` (dimmed PNG + message) | **None.** | — | **Gap: no empty-state primitive** anywhere in `components/**` or `guides/**`. Stays a 25-line hand-composed widget: `Center` + `Column` + `Image.asset` + `Text(…).muted()`. It has no Material dependency today apart from the import, so it is nearly a no-op migration. |
| `CatPage` (toolbar / body / footer / fab / maxWidth / scroll) | `Scaffold` (`components/layout/scaffold.md`) | `Scaffold({List<Widget> headers = const [], List<Widget> footers = const [], required Widget child, double? loadingProgress, bool loadingProgressIndeterminate, bool floatingHeader, bool floatingFooter, Color? headerBackgroundColor, Color? footerBackgroundColor, Color? backgroundColor, bool? resizeToAvoidBottomInset})` | `headers`/`footers` cover toolbar/footer. **No `floatingActionButton` slot** — a FAB is a `Stack` + `Positioned` by hand, and `AppTokens.fabClearance` (88) stays a hand-held number. `maxWidth` and `scroll` are not Scaffold's job: `ConstrainedBox` + `SingleChildScrollView` as today. |
| `CatSection` (title + description + children + bottom divider + 48 gap) | `Card` / `SurfaceCard` (`components/layout/card.md`), or `Divider` + `Column(...).gap(…)` | `Divider({Color? color, double? height, double? thickness, double? indent, double? endIndent, Widget? child, EdgeInsetsGeometry? padding, AxisAlignmentGeometry? childAlignment})` — note `child`, so a labelled divider is free | No sectioning component. `guides/layout.md` gives the rhythm vocabulary instead: `Column(...).gap(8)`, `DensityGap(gapLg)`, `theme.paddingSm/Md/Lg`. shadcn's idiom for a settings section is a `Card` per section, not a bottom hairline. **Composition.** |
| `CatSectionHeader` (+ `.inline`) | `Text(...).h4()` / `.h3()` inside a `Row` with `Expanded` + trailing | `guides/typography.md` | No component; two lines of composition. The `tileMargin + gutter` left-edge alignment contract it exists to enforce dissolves with `HoverTile` (see below). |
| `CatSettingRow` (`_Label` + trailing, `formMaxWidth` cap) | `Basic` (`components/other/basic.md`) — `title`/`subtitle`/`leading`/`trailing` with `BasicTheme(trailingAlignment:)` — or a plain `Row` | `Basic({Widget? leading, Widget? title, Widget? subtitle, Widget? trailing, BasicTheme? theme})` (seen in `components/feedback/toast.md` examples) | `Basic` is the closest thing shadcn has to `ListTile`. No width cap, no description styling — `.muted().small()` by hand. |
| `CatTag` | `Badge` family: `PrimaryBadge`, `SecondaryBadge`, `OutlineBadge`, `DestructiveBadge` (`components/utility/badge.md`); or `Chip` | `BadgeTheme({AbstractButtonStyle? primaryStyle, secondaryStyle, outlineStyle, destructiveStyle})`; the badges themselves take a `child` | Good fit for the status-badge use. For the **key-cap** use in Help, `KeyboardShortcut` / `KeyboardDisplay` exists (`components/other/keyboard_shortcut.md`) and is a better fit than a badge. Arbitrary `background`/`foreground` per-tag needs `style:`. |
| `ClientDot` (colour disc) | `Avatar` (`components/display/avatar.md`) | `Avatar({required String initials, Color? backgroundColor, ImageProvider? provider, AvatarWidget? badge, AlignmentGeometry? badgeAlignment, double? badgeGap, double? size, double? borderRadius})` | Tied to ticket 06 (dicebear identicons). **Flag:** `provider` is an `ImageProvider` — a dicebear **SVG** is not one. Either render to raster or bring `flutter_svg`; `Avatar` will not take an SVG string. |
| `AppTokens` | see [AppTokens](#the-apptokens-question) below | | |
| `catConfirm` / `catTextInput` (`dialogs.dart`) | `AlertDialog` widget + `showOverlay(context, DialogConfiguration(), builder: …)` | `showOverlay<T>(BuildContext context, OverlayConfiguration configuration, {required WidgetBuilder builder, bool adaptive = true}) → OverlayCompleter<T?>` (pub.dev); `AlertDialog({Widget? leading, Widget? title, Widget? content, List<Widget>? actions, Widget? trailing, double? surfaceBlur, …})` | Close with `Navigator.pop(context, value)` as today (`components/feedback/alert_dialog.md` example). The `catConfirm(danger:)` flag becomes `DestructiveButton` in `actions`. `catTextInput` stays hand-composed: no text-prompt dialog helper exists. |
| `catSurfaceDecoration` | `SurfaceCard` / `OutlinedContainer` / `Card` | — | Direct. `OutlinedContainer` is the bordered box, `SurfaceCard` the raised one (both used in the docs' own examples). |

### Plain Material still in the tree

| Material widget | shadcn replacement | Notes |
| --- | --- | --- |
| `Scaffold` | `Scaffold` (shadcn's own, same name) | Different API: `headers`/`footers`/`child`, no `appBar`, no `floatingActionButton`, no `drawer`. |
| `AppBar` | `AppBar` (shadcn ships one) placed in `Scaffold.headers` | Confirmed present via `guides/interop.md`'s note that `SliverAppBar` moved out but `AppBar` did not. |
| `FloatingActionButton` | **None.** | **Gap.** No FAB component. `Stack` + `Positioned` + `PrimaryButton(style: …shape: ButtonShape.circle)`. The Entries and Clients screens both depend on one. **Flag.** |
| `AlertDialog` / `showDialog` | `AlertDialog` + `showOverlay(…, DialogConfiguration(), …)` | See above. |
| `TextField` | `TextField` (shadcn's own) | `placeholder: Widget`, not `decoration: InputDecoration`. Labels come from `FormField(label: Text(…), child: TextField(…))` inside a `Form` + `FormTableLayout` (`components/form/form.md`). Add-ons are `features: [InputFeature.clear(), .leading(), .trailing(), .hint(), .passwordToggle(), .copy(), .paste(), .revalidate()]`. **No `InputDecoration`, so `labelText`/`errorText` do not port one-to-one.** |
| `Switch` | `Switch` | `Switch({required bool value, ValueChanged<bool>? onChanged, Widget? leading, Widget? trailing, bool? enabled, double? gap, Color? activeColor, inactiveColor, activeThumbColor, inactiveThumbColor, BorderRadiusGeometry? borderRadius})`. Richer than Material's. |
| `Slider` | `Slider` (`components/form/slider.md`) | shadcn's `Slider` takes a `SliderValue` (supports ranged), not a bare `double` — check call sites. |
| `ListTile` | **None.** `Basic`, or `Clickable` + `Row` | **Gap.** No `ListTile`, no `dense:`, no `contentPadding:`, no `tileColor:`. |
| `Tooltip` | `Tooltip` | `Tooltip({required Widget child, required Widget tooltip})` — `tooltip` is a **Widget**, normally `TooltipContainer(child: Text(…))`, not a `message: String`. Every `tooltip: 'Modifica'` call site changes shape. |
| `CircularProgressIndicator` | `CircularProgressIndicator` (`components/other/circular_progress_indicator.md`) or `Spinner` (`components/other/spinner.md`) | Present. |
| `LinearProgressIndicator` | `LinearProgressIndicator` / `Progress` (`components/feedback/progress.md`) | Present. `Scaffold.loadingProgress` also gives a top-of-page bar for free. |
| `VerticalDivider` | `Divider` with `direction`, or `VerticalDivider` | `components/layout/divider.md` documents one Divider; a vertical variant is implied by the theme. Worth a compile check. |
| `InkWell` | `Clickable` | No ink ripple in shadcn at all — the interaction language is state-driven decoration, not splash. Visual change, accepted by the map's "shadcn look wins". |
| `IconButton` | `IconButton` with a `ButtonStyle.…Icon()` variance | See the button row. No `tooltip:`, no `visualDensity:`, no `iconSize:` — size comes from `ButtonSize`/`ButtonDensity` and `theme.iconTheme`. |
| `TextButton` / `FilledButton` / `OutlinedButton` | `TextButton` / `PrimaryButton` / `OutlineButton` | Names all exist (`components/**`: `PrimaryButton` ×111, `OutlineButton` ×28, `SecondaryButton` ×27, `TextButton` ×11, `DestructiveButton` ×7, `GhostButton` ×6, `LinkButton` ×3). `FilledButton` → `PrimaryButton`. |
| `Theme.of(context)` (13 uses in `lib/`) | `Theme.of(context)` — **shadcn's own**, returning shadcn `ThemeData` | Same call, different type. `guides/theming.md`: `ThemeData{colorScheme, radius, scaling, typography, iconTheme, density}`. **There is no `textTheme` and no `ColorScheme.onSurfaceVariant`** — see [Typography and colour](#typography-and-colour-access). |

### Shell

| Shape | Args | Preserves screen state across switches? |
| --- | --- | --- |
| `NavigationRail` (`components/other/rail.md`) | `{List<Widget> children, Key? selectedKey, ValueChanged<Key?>? onSelected, NavigationRailAlignment alignment, Axis direction, NavigationLabelType labelType, NavigationLabelPosition labelPosition, NavigationLabelSize labelSize, double? expandedSize, double? collapsedSize, bool expanded, List<Widget>? header, List<Widget>? footer, BoxConstraints? constraints, double? spacing, Color? backgroundColor, double? surfaceOpacity, double? surfaceBlur}` | **It holds no content at all** — it is the rail only, selection reported by `Key`. State preservation is entirely whatever you put beside it, so today's `IndexedStack` keeps working verbatim. This is the closest match to the current 64px rail, and the safest. |
| `Sidebar` (`components/other/sidebar.md`) | Same family as the rail (`children`/`header`/`footer`/`selectedKey`/`onSelected`/`labelType`/`expanded`/`constraints`) but full-width-item oriented | Same: rail-only, no content slot. |
| `Tabs` (`components/navigation/tabs.md`) | `{int index, ValueChanged<int> onChanged, List<TabChild> children, bool expand, EdgeInsetsGeometry? padding}` | `TabChild` carries a content panel. Docs **do not state** whether inactive panels are kept alive. Must be measured, or sidestepped by giving each `TabChild` a trivial panel and keeping an `IndexedStack` outside. |
| `TabPane` (`components/navigation/tab_pane.md`) | `{List<TabPaneData<T>> items, TabPaneItemBuilder<T> itemBuilder, int focused, ValueChanged<int> onFocused, ValueChanged<List<TabPaneData<T>>>? onSort, List<Widget> leading, List<Widget> trailing, Widget child, double? barHeight, …}` | `child` is a **single** content widget you swap yourself → state preservation is yours to arrange. IDE-style chrome; wrong register for a 5-screen desktop app. |
| `NavigationMenu` (`components/navigation/navigation_menu.md`) | — | Horizontal hover-dropdown menu bar (the shadcn/ui web idiom). Not a left rail. |
| `Menubar` (`components/navigation/menubar.md`) | — | File/Edit-style top menubar. Possible *addition*, not a replacement for the rail. |
| `Scaffold` slots | `headers` / `footers` | No `drawer`/`rail` slot — the rail sits inside `child` in a `Row`. |

**Shell conclusion:** `NavigationRail` + the existing `IndexedStack` is a one-for-one
swap that keeps state preservation an app-level fact rather than a component promise.
Every content-owning navigation component (`Tabs`, `TabPane`, `Switcher`) leaves the
keep-alive question undocumented.

---

## Risky 1: Toast

Our `app_toast.dart` + `ai_toast.dart` need three things. shadcn gives one and a
half.

**Mounting.** `ToastLayer` is the host (pub.dev `ToastLayer`): `ToastLayer({required
Widget child, int maxStackedEntries = 3, EdgeInsetsGeometry? padding, ExpandMode?
expandMode, Offset? collapsedOffset, double? collapsedScale, double?
collapsedOpacity, Curve? expandingCurve, Duration? expandingDuration, double?
spacing, BoxConstraints? toastConstraints})`. `guides/interop.md` states that
`ShadcnLayer` gives "full theme, toasts, overlays", so under a `ShadcnApp` the layer
is already installed and no manual mount is needed. The tunables match
`appToastConfig` closely: `maxVisibleToasts: 1` → `maxStackedEntries: 1`,
`width: 380` → `toastConstraints: BoxConstraints.tightFor(width: 380)` (default is a
fixed 320), `outerPadding` → `padding`. `alignment: bottomCenter` is **not** a layer
setting — it is per-call: `ToastLocation.bottomCenter`.

**1. Persistent (no auto-dismiss) — NO, workaround only.**
`showDuration` is `Duration showDuration = const Duration(seconds: 5)`: a
non-nullable positional default with no documented sentinel for "never". Unlike
`Sonner.toast(duration: null)`, there is no first-class persistent toast. The
workaround is `showDuration: const Duration(days: 365)`, which works but is a lie the
code has to carry. `dismissible: false` separately kills swipe-to-dismiss, which a
desktop app wants anyway (our card already ships its own close X for exactly this
reason).

**2. Action buttons that open dialogs — YES.**
`ToastBuilder` is `Widget Function(BuildContext context, ToastOverlay overlay)`, and
the docs' own example puts a `PrimaryButton` in the toast that calls
`overlay.close()` (`components/feedback/toast.md`, `toast_example_1.dart`). The
builder's `context` is a real tree context under the toast layer, so
`showOverlay(context, DialogConfiguration(), …)` from inside a toast is ordinary.
One caveat carried over from today: `AiToastHost` deliberately opens its dialogs
through `navigatorKey.currentContext` because the toast floats *above* the Navigator.
The docs do not state where `ToastLayer` sits relative to `ShadcnApp`'s Navigator, so
**keeping the `navigatorKey` hand-off is the safe port** and dropping it needs a
prototype (ticket 07).

**3. Dismiss / update by key from outside the tree — HALF.**
- *Dismiss:* yes, indirectly. `showToast` returns a `ToastOverlay` with
  `isShowing → bool` and `close() → void` (pub.dev `ToastOverlay`). That object is a
  plain Dart object, so `app_toast.dart` can hold it in its existing top-level
  variable and `dismissToast()` becomes `_current?.close()`. There is **no
  `Sonner.dismissAll()` equivalent and no key-based lookup** — you must keep the
  handle, and there is no way to reach a toast whose handle you lost.
- *Update:* **no.** `ToastOverlay` exposes no content mutation. The AI toast's live
  `pendingBytes` in `'Aggiorna (${formatBytes(…)})'` therefore means close + re-show
  on every change — which resets the entry animation. Either the builder reads the
  cubit itself (a `BlocBuilder` *inside* the toast, so the toast rebuilds without
  being re-raised) or the byte count leaves the toast text. **The
  `BlocBuilder`-inside-the-toast route is the one that keeps the current UX, and it
  is a real architectural change from today's "raise a fresh toast per state".**
- *Context:* `showToast` requires a `BuildContext`. Our `showToast(String, …)` is a
  context-free global. `navigatorKey.currentContext` covers it, but the shared
  helper's signature changes.

**The sticky-slot bookkeeping** in `app_toast.dart` (`_sticky`, `_generation`,
give-the-slot-back-on-dismiss) is app logic, not toast-library logic. It survives
unchanged on top of `ToastOverlay` handles, and `onClosed: VoidCallback?` replaces
`sonner`'s `onDismiss`.

## Risky 2: Client field

**Only `AutoComplete` accepts free text that is not in the option list.** The other
three are closed-set pickers.

| Candidate | Free text? | Distinguishing capability |
| --- | --- | --- |
| **`AutoComplete`** | **Yes** | It is not an input at all — it is a *popover wrapper around your own child*: `AutoComplete({required List<String> suggestions, required Widget child, …})` where `child` is a real `TextField` you own, with your own controller. The text is whatever the user typed; suggestions only offer to rewrite it. `mode: AutoCompleteMode` (`replaceWord` default / `replaceAll` / `append`) controls how a picked suggestion edits the text, and `completer: AutoCompleteCompleter` can transform the inserted string. **Filtering is entirely yours** — the widget does none; it just shows the `List<String>` you pass. That maps 1:1 onto today's `optionsBuilder` with its 3-character threshold. |
| `Select<T>` | No | Closed set over `T`. `{T? value, ValueChanged<T?>? onChanged, Widget? placeholder, SelectPopupBuilder popup, SelectValueBuilder<T> itemBuilder, bool canUnselect, bool? autoClosePopover, BoxConstraints? popupConstraints, bool filled, Widget? expandIcon, …}`. The popup can contain a search field (`SelectPopup` has search variants), but the *value* is always one of the items — there is no "commit what I typed". |
| `ItemPicker<T>` | No | Closed set, richer presentation: `{ItemChildDelegate<T> items /* ItemList or ItemBuilder */, ItemPickerBuilder<T> builder, T? value, ValueChanged<T?>? onChanged, ItemPickerLayout? layout /* grid default, or .list */, Widget? placeholder, Widget? title, PromptMode? mode, BoxConstraints? constraints}`, plus imperative `showItemPicker` / `showItemPickerDialog`. Built for grids of visual options (its doc examples are colour swatches); virtualizes via `ItemBuilder`. Overkill and wrong shape for a name field. |
| `Command` | No | Cmd+K palette: `{CommandBuilder builder /* query → Stream<List<Widget>> */, bool autofocus = true, Duration debounceDuration = 500ms, WidgetBuilder? emptyBuilder, loadingBuilder, ErrorWidgetBuilder? errorBuilder, Widget? searchPlaceholder, double? surfaceOpacity, surfaceBlur}`. It *has* a search input and async results — the closest to "type anything" — but it returns a **selected widget/action**, not the typed string, and `emptyBuilder` renders "no results" rather than offering to commit the query. You could smuggle a "Crea «$query»" row into `builder`'s stream, which is a real option but a heavier one. |

**Verdict for ticket 05: `AutoComplete` + `TextField`.** It is also the smallest diff
— `ClientField`'s whole `optionsViewBuilder` disappears (shadcn draws the popover),
`fieldViewBuilder` becomes a plain `TextField`, and `optionsBuilder` becomes the
`suggestions` list. What is lost: the **`ClientDot` leading marker on each suggestion
row** — `suggestions` is `List<String>`, so no per-option widget. With ticket 06
dropping client colour that may be moot, but if identicons are wanted in the
dropdown, `AutoComplete` cannot do it and `Command` or a hand-rolled `Popover`
becomes necessary. **Flag.**

## Risky 3: Hover row with trailing actions revealed on hover

**No `ListTile`, no hoverable list-row primitive.** This is composition by hand.

The pieces that do exist:

- **`Clickable`** (`components/other/clickable.md`) is the right base and is a
  genuine upgrade on `HoverTile`'s `MouseRegion` + `TweenAnimationBuilder`:
  `onHover: ValueChanged<bool>`, `onFocus: ValueChanged<bool>` (so the
  focus-within reveal that `HoverTile` hand-rolls with a `Focus(canRequestFocus:
  false, skipTraversal: true)` wrapper comes free), and `decoration`, `padding`,
  `margin`, `textStyle`, `iconTheme`, `transform` all as
  `WidgetStateProperty` — so the hover fill is declarative rather than a tween.
  Also `disableTransition: bool` and `statesController: WidgetStatesController?`
  for external state.
- **`Hover`** (`components/other/hover.md`) is *not* what we want: it is a
  delay-based hover detector (`waitDuration` defaults to **500ms**) built for hover
  cards. Using it for a row highlight would add half a second of lag.
- **`Basic`** supplies the leading/title/subtitle/trailing arrangement with
  `BasicTheme(trailingAlignment:)`.
- **`Button(style: ButtonStyle.ghost())`** gives a hover fill for free, but a ghost
  button wants its child to be button-shaped content and nests badly with the
  interactive icon buttons in the trailing slot (a button inside a button).

So the port is roughly `Clickable(onPressed:, onHover:, onFocus:, decoration:
WidgetStateProperty.resolveWith(…), child: Basic(leading:, title:, subtitle:,
trailing: …))`, with the app keeping its own `bool _revealed` to drive the
`Opacity` + `IgnorePointer` on the action row — because **nothing in shadcn reveals
a trailing widget on hover**; that part is unambiguously hand-written.

What is lost from `HoverTile`: `dense`, `contentPadding`, `tileColor`, reserved
trailing space (so rows don't shift), and the `tileMargin`/`tileRadius` inset-fill
idiom. All are three lines of `Padding`/`Container` each, but there are three of them
per row, in five screens. **This is the single biggest hand-composition cost in the
migration** and the strongest argument that the map's no-house-layer decision will
still produce one repeated local widget.

---

## The `AppTokens` question

`guides/layout.md` and `guides/theming.md` give shadcn's own token vocabulary:
`theme.radius` (a multiplier, default 0.5) feeding `radiusXs/Sm/Md/Lg/Xl/Xxl`
(`radius * 4/8/12/16/20/24`) and matching `theme.borderRadius*` getters;
`theme.paddingSm/Md/Lg`; `theme.scaling` and `AdaptiveScaling`; `theme.density`
plus `DensityGap(gapLg)`; `theme.iconTheme` (`IconThemeProperties`); and
`Column(...).gap(8)` / `Row(...).gap(8)` for rhythm.

| Token | Home in shadcn? | Notes |
| --- | --- | --- |
| `radius` (10) | **Yes** — `theme.radiusMd`/`theme.borderRadiusMd` | The map already fixes `radius: Rounded`. Stop passing a number; read the theme. catui's "10 not 16" reasoning is superseded by "shadcn look wins". |
| `tileRadius` (8) | **Yes** — `theme.radiusSm` | |
| `iconSize` (18) | **Yes** — `theme.iconTheme` + `ButtonSize`/`ButtonDensity` | Icon sizes come from the theme and the button density, not a constant. `density: Reduced` is already fixed by the map. |
| `hoverFade` (200ms) | **Partly** — `Clickable` animates state transitions itself (`disableTransition: bool` implies a default duration) | No named duration token exposed. If a specific duration is needed it is a `ComponentTheme` override, not a constant. |
| `disabledAlpha` (0.38) | **Yes, implicitly** — disabled is a `WidgetState` every component styles itself | No numeric token, and none needed: stop hand-computing disabled foregrounds. |
| `hoverOverlayAlpha` (0.12) | **Yes, implicitly** — same | Only needed by `intentHoverStyle`, which is itself being dropped. |
| `gutter` (16) | **Partly** — `theme.paddingMd`, `.gap(16)` | The *value* has a home; the *contract* (toolbars, section headers and rows share one left edge) does not. That contract lives in written convention now, per the map. |
| `pagePadding` (24) | **Partly** — `theme.paddingLg` | Same: value yes, page-level convention no. |
| `sectionGap` (48) | **No** | Twice `paddingLg`. No section-rhythm token exists because no section component exists. **Homeless — becomes convention or a local constant.** |
| `segmentGap` (4) | **Yes** — `.gap(4)` / `theme.paddingSm` | |
| `tileMargin` (8) | **No** — the inset-fill idiom is catui's, not shadcn's | Dies with `HoverTile`, or becomes a local constant. |
| `dotRadiusSmall/dotRadius/Middle/Large` (6/8/12/14) | **No** | `Avatar` has `size`, but these are our identity-dot scale steps. Tied to ticket 06; if identicons land, this becomes an avatar-size scale and is still ours. **Homeless.** |
| `formMaxWidth` (560) | **No** | No max-width or readable-measure token anywhere in the guides. **Homeless — a local constant.** |
| `pillMinHeight` (48) | **No** | Exists only to align pills with Material's 40px icon-button hover disc — a Material-specific fudge. **Dies with Material**; shadcn's `ButtonSize`/`ButtonDensity` sets consistent heights across a row for free. |
| `fabClearance` (88) | **No** | Derived from the Material FAB's 56+16. shadcn has no FAB at all, so both the FAB and its clearance are hand-built. **Homeless.** |
| `toolbarPadding` (16h / 12v) | **Partly** — `EdgeInsets.symmetric(horizontal: theme.paddingMd…)` | Value composable; the shared-toolbar contract is convention. |

**Summary: about half of `AppTokens` comes free from `ThemeData` (radius, icon size,
paddings, gaps, disabled and hover states), and the rest is either app-specific
geometry with no home in any design system (`formMaxWidth`, `sectionGap`,
`dotRadius*`, `fabClearance`) or Material-specific fudge that dies with Material
(`pillMinHeight`, `hoverOverlayAlpha`, `disabledAlpha`).** The homeless set is small
enough — five or six numbers — that a single file of local constants is honest, and
does not amount to re-creating the house layer the map ruled out.

## Typography and colour access

- **Typography** (`guides/typography.md`): extensions on `Text`, not a `textTheme`.
  Headings `.h1()` 30/Bold, `.h2()` 24/SemiBold, `.h3()` 20/SemiBold, `.h4()`
  18/SemiBold. Body `.p()` 14, `.lead()` 16 muted, `.large()` 16/SemiBold,
  `.small()` 12, `.muted()` (sets foreground to `mutedForeground`). Inline:
  `.italic()`, `.bold()`, `.semiBold()`, `.mono()`. They chain: `Text('x').large().bold()`.
  Custom base via `ThemeData(typography: Typography.sans(family: …, base: …))`.
  **There is no `Theme.of(context).textTheme`** — every `theme.textTheme.bodySmall`,
  `.labelMedium`, `.titleSmall`, `.bodyLarge` in the current code becomes an
  extension call. The mapping is approximate, not exact: `labelMedium` ≈ `.small()`,
  `titleSmall` ≈ `.h4()` or `.large()`, `bodySmall` ≈ `.small()`, `bodyLarge` ≈ `.p()`.
- **Colour** (`guides/colors.md`, `guides/theming.md`): `Theme.of(context).colorScheme`,
  a shadcn `ColorScheme` with the shadcn/ui token names — `background`, `foreground`,
  `card`, `cardForeground`, `popover`, `primary`, `primaryForeground`, `secondary`,
  `muted`, `mutedForeground`, `accent`, `accentForeground`, `destructive`, `border`,
  `input`, `ring`. Prebuilt schemes: `ColorSchemes.{light,dark}{Gray,Neutral,Slate,Stone,Zinc}`.
  Raw palette via `Colors.blue[500]` across 22 Tailwind ramps.
  **Material's `onSurfaceVariant`, `surfaceContainerHighest`, `outlineVariant`,
  `error`/`onError` do not exist.** The translation the current code needs:
  `onSurfaceVariant` → `mutedForeground`; `surfaceContainerHighest` → `muted` or
  `accent`; `outlineVariant` → `border`; `error`/`onError` → `destructive` /
  `destructiveForeground`. Exact names should be confirmed against
  `pub.dev/…/ColorScheme-class.html` before the mapping ticket locks them.

---

## Gaps: no shadcn component fits, hand composition required

1. **Empty state** — nothing in the library. Keep the existing hand-composed widget.
2. **FloatingActionButton** — no FAB. `Stack` + `Positioned` + a circular
   `PrimaryButton`. Affects Entries and Clients.
3. **`ListTile` / hoverable row with hover-revealed trailing actions** — `Clickable`
   + `Basic` + our own reveal. The biggest single cost.
4. **Segmented control** — no joined pill group. Selected/unselected button styles in
   a gapped `Row`, i.e. what `CatSegmented` already does.
5. **Combined date+time field** — `DatePicker` and `TimePicker` are separate, both
   popover/dialog-only, neither keyboard-typeable. Typeable means `FormattedInput`
   with hand-defined segments.
6. **Imperative `Future<DateTime?> pickDay(context)`** — `DatePicker` is a widget,
   not a function. The one-place-for-the-range idiom needs rebuilding.
7. **Per-intent hover colour** (`intentHoverStyle`) — no equivalent; either accept
   always-on intent colour from `ButtonStyle.destructiveIcon()` or hand-roll with
   `Clickable`'s `WidgetStateProperty` hooks.
8. **Section rhythm** (`CatSection`'s title + description + hairline + 48 gap) — no
   section component; `Card` or `Divider` + gaps, by convention.
9. **Toast: persistent and updatable** — `showDuration` has no infinite value
   (workaround: a very long `Duration`); `ToastOverlay` cannot update content
   (workaround: put a `BlocBuilder` inside the toast builder).
10. **Text-prompt dialog** (`catTextInput`) — no helper; `AlertDialog` + a
    `TextField` + `Navigator.pop`, as today.
11. **Identity dot / identicon** — `Avatar.provider` is an `ImageProvider`, so a
    dicebear SVG needs rasterizing or `flutter_svg`. Feeds ticket 06.
12. **Screen-state preservation across shell switches** — undocumented for `Tabs`,
    `TabPane` and `Switcher`. `NavigationRail` + the existing `IndexedStack` avoids
    the question entirely.
