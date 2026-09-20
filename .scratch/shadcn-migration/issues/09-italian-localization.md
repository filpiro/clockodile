# Italian: shadcn ships English strings only

Type: grilling
Status: open
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
