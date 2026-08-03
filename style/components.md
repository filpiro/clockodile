# UI Components Inventory

Every visual component in this app, grouped by scope — what clockodile puts on screen, not how the style works.

The house style itself — theme, tokens, shared widgets and the rules for using them — is `packages/cat_ui/DESIGN.md`. Read that first; this file assumes it.

Clockodile's only style decision: `lib/shared/theme.dart` passes the flavor's green as `primary` (latte for light, mocha for dark, `themeMode` from Settings). Everything else is cat_ui's.

## App shell (`lib/main.dart`)

| Component | Widget | Notes |
|---|---|---|
| Navigation rail | `NavigationRail` | 3 destinations (Attività, Clienti, Report), labels always visible |
| Rail bottom icons | `IconButton` ×2 | Impostazioni, Aiuto — `isSelected` state, outside destinations |
| Rail/content divider | `VerticalDivider` | width 1 |
| Screen host | `IndexedStack` | keeps all 5 screens alive |
| Startup loader | `CircularProgressIndicator` | shown while purge future resolves |

## From cat_ui

Behaviour and rationale live in `packages/cat_ui/DESIGN.md`; this is only where each one is used.

| Component | Used by |
|---|---|
| `HoverTile` | Attività list, Active Entry tile, Clienti list, Report rows (`dense`) |
| `EditIconButton` | Attività rows, Active Entry tile |
| `DeleteIconButton` | Attività rows, Clienti rows, Entry page sessions |
| `DangerButton` | delete confirms in Attività, Clienti, Impostazioni |
| `intentHoverStyle()` | the four above, plus "Termina" |
| `EmptyState` | Attività, Report, Clienti |

## Shared widgets (`lib/shared/widgets/`)

| Component | Widget | Used by | Notes |
|---|---|---|---|
| Client autocomplete | `ClientField` (custom) | Entry page | `RawAutocomplete`, dropdown from 3 chars; options: `Material(elevation 4)` + `ListView` of dense `ListTile`s, highlighted option = `secondaryContainer` bg, color dot per client. Stays in the app: it reads `ClientsCubit` and knows the Client entity |

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
| Empty state | `EmptyState` | "Nessuna attività." |

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
| Empty state | `EmptyState` | "Nessuna sessione nel giorno scelto." |

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
| Empty state | `EmptyState` | "Nessun cliente." |

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
- **Empty states**: `EmptyState` from cat_ui — dimmed 96px illustration above the message
