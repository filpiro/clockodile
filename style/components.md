# UI Components Inventory

Every visual component in the app, grouped by scope. Base for the style improvement work.
Theme today: catppuccin, built by `catTheme` in the `cat_ui` package — latte for light, mocha for dark, `themeMode` from Settings. `lib/shared/theme.dart` holds the app's two `ThemeData` finals and is the only place clockodile's accent is stated: `primary` is the flavor's own green, taken per flavor so it tracks brightness. `secondary` falls back to the flavor pink, and `cat_ui` defaults `primary` to mauve for apps that state nothing. Everything else is a manual ColorScheme mapping onto the flavor (secondary=pink, surface=base, containers=crust/mantle/surface0-2, error=red). Buttons (Filled/Elevated/Outlined/Text/Segmented) use 10px rounding instead of Material 3 stadium pills; FAB and chips keep defaults. `IconButton`s default to an 18px glyph in the stock 40px hit area, so hover-revealed row actions get breathing room.

## App shell (`lib/main.dart`)

| Component | Widget | Notes |
|---|---|---|
| Navigation rail | `NavigationRail` | 3 destinations (Attività, Clienti, Report), labels always visible |
| Rail bottom icons | `IconButton` ×2 | Impostazioni, Aiuto — `isSelected` state, outside destinations |
| Rail/content divider | `VerticalDivider` | width 1 |
| Screen host | `IndexedStack` | keeps all 5 screens alive |
| Startup loader | `CircularProgressIndicator` | shown while purge future resolves |

## Shared widgets (`lib/shared/widgets/`)

| Component | Widget | Used by | Notes |
|---|---|---|---|
| Hover row | `HoverTile` (custom) | Attività list, Active Entry tile, Clienti list, Report rows (`dense`) | `ListTile` + `MouseRegion`; hover fades `tileColor` to `surfaceContainerHighest` over 200ms (Material's `InkHighlight` duration). Highlight is driven from `MouseRegion`, not `ListTile.hoverColor`, because `InkResponse` ignores hover when every callback is null — non-tappable rows must still light up. Stock `hoverColor` forced transparent so the ink overlay doesn't stack. Actions revealed on hover only (opacity + `IgnorePointer`) |
| Edit action | `EditIconButton` (custom) | Attività rows, Active Entry tile | pencil, tooltip "Modifica"; `onSurfaceVariant` at rest → `primary` on hover |
| Delete action | `DeleteIconButton` (custom) | Attività rows, Clienti rows, Entry page sessions | trash2, tooltip overridable; `onSurfaceVariant` at rest → `error` on hover; dims to 38% when disabled |
| Destructive confirm | `DangerButton` (custom) | delete confirms in Attività, Clienti, Impostazioni | `FilledButton` on `error`/`onError` — filled, not hover-tinted: the user is committing, not browsing |
| Intent hover style | `intentHoverStyle()` (helper) | the three above + "Termina" | `WidgetStateProperty` foreground: idle → accent on hover, plus a matching 12% overlay tint |
| Client autocomplete | `ClientField` (custom) | Entry page | `RawAutocomplete`, dropdown from 3 chars; options: `Material(elevation 4)` + `ListView` of dense `ListTile`s, highlighted option = `secondaryContainer` bg, color dot per client |

## Attività screen (`lib/features/entries/entries_view.dart`)

| Component | Widget | Notes |
|---|---|---|
| New-entry FAB | `FloatingActionButton` | icon `add`, tooltip "Nuova attività" |
| Date filter chips | `ChoiceChip` ×4 | Oggi, Ieri, Data (calendar avatar + picked date label), Tutte — no checkmark, selected bg only |
| Active Entry tile | `_ActiveEntryTile` (custom, on `HoverTile`) | pinned above list; color dot, "in corso" badge (`primaryContainer` rounded container), subtitle "dalle · sessione · totale — nota", ticks every minute |
| Stop button | `FilledButton.tonalIcon` | "Termina", icon `circleStop`, hover-revealed; hovers to `error` via `intentHoverStyle` — deliberate: in this app red marks a strong action, not only irreversible data loss. Pill forced to 48px (`minimumSize`) instead of the stock 40 so it fills the tap box it already occupies and stops reading smaller than the edit button's 40px hover disc; row height is unchanged. Separated from the edit button by an 8px `SizedBox` local to this tile — not `HoverTile` spacing, which would also push edit/delete apart in every Entry row |
| Day header | `_DayHeader` (custom) | Italian day label left, day total right, `titleSmall` |
| Entry day row | `_EntryDayTile` (custom, on `HoverTile`) | color dot, client name, "HH:MM–HH:MM (h:mm)" or "N sessioni (h:mm)" + nota; tap = activate |
| Row hover actions | `EditIconButton` + `DeleteIconButton` | pencil (edit), trash (delete w/ confirm dialog) |
| Delete confirm | `AlertDialog` | "Eliminare l'attività?" + cascade warning; confirm is a `DangerButton` |
| Load more | `TextButton` | "Carica altre", only in Tutte |
| Empty state | `Text` centered | "Nessuna attività." |

## Entry page (`lib/features/entries/entry_edit_page.dart`)

| Component | Widget | Notes |
|---|---|---|
| Page scaffold | `Scaffold` + `AppBar` | title "Nuova/Modifica attività"; actions: `TextButton` Annulla + `FilledButton` Salva |
| Form column | `ConstrainedBox(560)` + `ListView` | centered |
| Client input | `ClientField` | no autofocus |
| Start picker (create) | `ListTile` + `showDatePicker`/`showTimePicker` | "Inizio", calendar icon |
| Session card (edit) | `Card` + dense `ListTile` | Inizio/Fine tappable stamps (`InkWell` columns), duration or validation error subtitle |
| Session delete | `DeleteIconButton` | disabled on last session (tooltip explains) |
| Open-end stamp | `InkWell` column | "non impostata — in corso", settable once |
| Note input | `TextField` | `OutlineInputBorder` |
| Loading sessions | `CircularProgressIndicator` | while sessions load |

## Report screen (`lib/features/report/report_view.dart`)

| Component | Widget | Notes |
|---|---|---|
| Filter chips | `ChoiceChip` ×3 | Oggi, Ieri, Data — no Tutte, no checkmark |
| Group toggle chip | `ChoiceChip` | "Raggruppa per cliente", default selected |
| Export button | `FilledButton.tonalIcon` | "Esporta CSV", disabled when empty |
| Client header (grouped) | `_ClientHeader` (custom) | color dot + name, `titleSmall` |
| Report row | `_ReportTile` (on `HoverTile`, `dense`) | normalized "HH:MM–HH:MM (h:mm) — nota"; subtitle client + real times; color dot only when ungrouped; zero-length rows in `error` color; tap copies the note, note-less rows aren't tappable but still highlight |
| Day total footer | `Text` `titleSmall` | "Totale normalizzato: h:mm" |
| Empty state | `Text` centered | "Nessuna sessione nel giorno scelto." |

## Clienti screen (`lib/features/clients/clients_view.dart`)

| Component | Widget | Notes |
|---|---|---|
| New-client FAB | `FloatingActionButton` | icon `add` |
| Client row | `HoverTile` | tappable color dot (opens hue picker), name, "N attività"; tap = rename |
| Delete action | `DeleteIconButton` | hover-revealed; blocked with snackbar if entries exist |
| Create dialog | `AlertDialog` | "Nuovo cliente", autofocused `TextField`, Annulla/Crea |
| Rename dialog | `AlertDialog` | autofocused `TextField`, Annulla/Salva |
| Color dialog | `AlertDialog` | preview `CircleAvatar` + hue `Slider` (fixed S/L), Annulla/Salva |
| Delete confirm | `AlertDialog` | Annulla/Elimina |
| Empty state | `Text` centered | "Nessun cliente." |

## Impostazioni screen (`lib/features/settings/settings_view.dart`)

| Component | Widget | Notes |
|---|---|---|
| Title | `Text` `titleLarge` | "Impostazioni" |
| Theme switch | `SegmentedButton<ThemeMode>` | Chiaro/Scuro/Sistema with icons, instant apply |
| Retention field | `TextFormField` (width 320) | digits only, helper + validator (min 30) |
| Save button | `FilledButton` | "Salva"; retention-shrink confirm `AlertDialog` first, whose confirm is a `DangerButton` |

## Aiuto screen (`lib/features/help/help_view.dart`)

| Component | Widget | Notes |
|---|---|---|
| Shortcut chips | `Container` rows | `surfaceContainerHighest` rounded box (110 wide) + description text |
| Intro texts | `Text` | shortcuts scope + tap-to-activate explanation |

## Global patterns

- **Feedback**: `SnackBar` everywhere (export result, save/create/delete errors, blocked actions)
- **Pickers**: Material `showDatePicker` + `showTimePicker`, locale `it`
- **Color dots**: `CircleAvatar` radius 6–14 with client hex color — the app's main visual identity
- **Confirmations**: `AlertDialog` with `TextButton` Annulla + `FilledButton` action
- **Hover-reveal actions**: desktop-only affordance via `HoverTile`; no touch fallback
- **Empty states**: bare centered `Text`, no illustration/icon
