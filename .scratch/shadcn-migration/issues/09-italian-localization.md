# Italian: shadcn ships English strings only

Type: grilling
Status: resolved
Blocked by: ~~01~~ (resolved — see `../research/01-shadcn-app-and-theme.md`)
Map: ../map.md

## Question

Graduated from the map's fog by ticket 01. The package ships exactly one locale — `shadcn_en.arb` / `ShadcnLocalizationsEn` — and auto-registers `ShadcnLocalizations.delegate`. `locale`, `supportedLocales` and `localizationsDelegates` all behave normally, so *our* strings are fine; shadcn's own built-in strings (date picker month and weekday names, dialog button labels, time picker parts, whatever else) render **English** under `Locale('it')`. This app is Italian-only and user-facing.

Decide:
- **How much English actually shows.** Enumerate the built-in strings that reach this app's screens, given the components ticket 05 selects. If the date picker is the only offender, this is small; if dialog buttons are affected, it is everywhere.
- **The fix.** Subclass `ShadcnLocalizations` with an Italian implementation and prepend our delegate, or upstream an `it` ARB to the package, or avoid the components that expose English strings. Weigh maintenance: a subclass must be re-checked when shadcn adds strings.
- **Where the Italian strings live** — an in-repo Dart class, our own ARB through `flutter_localizations`, or hard-coded.
- **Does `flutter_localizations` stay in pubspec?** It is there today for `GlobalMaterialLocalizations.delegates`; with Material gone, say what still needs it (`intl`-backed date formatting probably does).
- **Date and time formatting** — whether shadcn's pickers format via `intl`/locale or need explicit format strings passed. This is the other half of the map's old "Italian date/time formatting" fog patch.

Use `/grilling`.

## Resolution

The conventions now live in [`style/components.md` § Italian](../../../style/components.md) and the `DateField` row of § 2. This is the decision record.

**English that reaches our screens** if nothing is done (read from the `shadcn_flutter 0.0.54` source):

- `DatePicker` dialog — month names, weekday abbreviations, `datePickerSelectYear`, and `buttonCancel`/`buttonSave` (`ObjectFormField` dialog footer, `form/form_field.dart:454-460`).
- `TimePicker` dialog — `timeHour`, `timeMinute`, plus the same Cancel/Save.
- Picker placeholders — `placeholderDatePicker`, `placeholderTimePicker`.
- The right-click menu of **every** `TextField` — `menuCut`, `menuCopy`, `menuPaste`, `menuSelectAll`, `menuUndo`, `menuRedo`, `menuDelete`.
- `DatePicker`'s field text — `formatDateTime` builds `'${getMonth(m)} $d, $y'` (US order). It is an **extension** on `ShadcnLocalizations` (`locale/shadcn_localizations_extensions.dart:67`), so it is statically dispatched: no subclass can change it. Translated, it would read "settembre 22, 2026".
- Times are already fine: `formatTimeOfDay` pads and defaults to 24-hour — "09:05".

Dialog buttons are ours everywhere else (`AlertDialog` actions are app code), so this is small, not everywhere.

**Decisions**

1. **Fix: subclass, in repo.** `lib/shadcn_it.dart` — `ShadcnLocalizationsIt extends ShadcnLocalizationsEn` overriding only the ~40 strings above, plus its delegate. `ShadcnApp` puts app delegates *before* `ShadcnLocalizations.delegate` (`shadcn_app.dart:392-397`), so ours wins. Extending the English class means a string we miss renders English instead of failing to compile. No upstream ARB, no avoiding components.
2. **Strings hard-coded in Dart**, like every other Italian string in the app. No ARB, no codegen. Drift guard is a written rule: after a shadcn upgrade, diff the package's `lib/l10n/shadcn_en.arb`.
3. **`DatePicker` is not used directly.** A shared `DateField` (`lib/shared/widgets/date_field.dart`) wraps `ObjectFormField<DateTime>` with shadcn's `DatePickerDialog` as editor and shows `dmyShort()` from `lib/shared/utils/format.dart` — "22/09/26", matching the filter chip today. Two call sites (entry editor, date filter); it breaks the three-call-site rule on purpose, because it is a correctness fix.
4. **`flutter_localizations` leaves `pubspec.yaml`.** Only `GlobalMaterialLocalizations.delegates` needed it; Material is gone. `main.dart` keeps `locale: Locale('it')` and `supportedLocales: [Locale('it')]`, and `localizationsDelegates` becomes `[ShadcnLocalizationsIt.delegate]`. shadcn still depends on it transitively; that is its business. `lib/` does not use `intl`, and does not start to.
5. **Date/time formatting** stays in `format.dart`; shadcn's `formatDateTime` is never shown.

No new tickets. Nothing ruled out of scope.
