# shadcn_flutter: version, platform, ShadcnApp wiring, and the theme knobs

Ticket: [issues/01-shadcn-app-and-theme-facts.md](../issues/01-shadcn-app-and-theme-facts.md)
Date: 2026-09-20

## Sources

Ranked by trust, and what each one actually settled:

1. **Package source in the Windows pub cache**, `…/AppData/Local/Pub/Cache/hosted/pub.dev/shadcn_flutter-0.0.53/lib/` — the only place that gives exact numeric defaults (`density.dart`, `theme/theme.dart`, `theme/color_scheme.dart`, `src/shadcn_app.dart`). **Caveat: this is 0.0.53, one release behind latest (0.0.54).** Every claim taken from it is marked `[src 0.0.53]`.
2. **pub.dev API** — `https://pub.dev/api/packages/shadcn_flutter` (version list + SDK constraints, authoritative and current) and `https://pub.dev/documentation/shadcn_flutter/latest/…` (0.0.54 class surfaces). Marked `[pub 0.0.54]`.
3. **Offline skill docs**, `.claude/skills/shadcn-flutter/` — written against the 0.0.54-era API (they describe the Material split that 0.0.53 does not have). Marked `[skill]`.

Where 0.0.53 source and the 0.0.54 docs disagree, the docs win and it is called out.

---

## 1. Can we run it?

### Version and SDK constraints — **compatible, no pubspec change required**

| | Value | Source |
| :-- | :-- | :-- |
| Latest published | **0.0.54**, 2026-08-27 | `[pub]` |
| 0.0.54 constraints | `sdk: >=3.13.0 <4.0.0`, `flutter: >=3.47.0` | `[pub]` |
| 0.0.53 constraints | `sdk: >=3.6.0 <4.0.0`, `flutter: >=3.32.3` | `[pub]` |
| Our toolchain | Flutter **3.47.1** stable, Dart **3.13.1** (`pws -c 'flutter --version'`) | measured |
| Our pubspec | `environment: sdk: ^3.10.7` | `pubspec.yaml` |

Verdict: **0.0.54 works on this machine.** Dart 3.13.1 ≥ 3.13.0 and Flutter 3.47.1 ≥ 3.47.0, both by the thinnest possible margin — 0.0.54 was published 8 days after our Flutter build. Our own `sdk: ^3.10.7` (= `>=3.10.7 <4.0.0`) intersects the package's `>=3.13.0` cleanly, so pub resolves without editing `pubspec.yaml`; the effective floor just becomes 3.13.0. Worth bumping ours to `^3.13.0` for honesty, but not required.

Risk to note: the margin is one patch release wide. Anyone on the team below Flutter 3.47.0 cannot build after the migration. 0.0.53 is the fallback (Flutter ≥ 3.32.3) but it is a *different API* — see the Material split below.

### Windows desktop — supported, stated

- pub.dev platform badges list Android, iOS, Linux, macOS, **Web, Windows** `[pub]`.
- `[skill] guides/setup.md`: "Cross-platform: First-class support across Android, iOS, Web, macOS, Windows, and Linux."
- `[skill] guides/installation.md` adds "Desktop: Native scrollbar" behaviour.

No Windows-specific caveats are stated anywhere in the sources. Two implicit ones follow from the design, not from a caveat list:
- Desktop gets `1.0x` adaptive scaling (mobile gets `1.25x`) `[skill] guides/layout.md`.
- `ThemeData.platform` is a `TargetPlatform?` override if the desktop detection ever needs forcing `[src 0.0.53]`.

### The real compatibility problem: the Material split

This is the largest finding of the ticket and it is *not* a version problem, it is an API-shape problem.

`[skill] guides/interop.md`, verbatim:

> A bare `ShadcnApp` no longer installs `Theme`, `Material`, `ScaffoldMessenger` or `CupertinoTheme`, and no longer registers the Material and Cupertino localizations delegates. Material or Cupertino widgets placed under a bare `ShadcnApp` will assert at build time.

Confirmed against the source: 0.0.53 `ShadcnApp` **still** has `materialTheme` / `cupertinoTheme` fields and still installs `m.DefaultMaterialLocalizations.delegate` and `c.DefaultCupertinoLocalizations.delegate` automatically `[src 0.0.53 shadcn_app.dart:411-418]`. The 0.0.54 API docs show `materialTheme` **gone** and `debugShowMaterialGrid` renamed to `debugShowGrid` `[pub 0.0.54]`. So the split landed in 0.0.54 — the version we would adopt.

What this costs us, concretely. `lib/main.dart` today uses these Material widgets under the app root: `Scaffold` (twice), `IconButton`, `CircularProgressIndicator`, `VerticalDivider`, plus `Theme.of(context)` inside the `builder`. All of them assert under a bare `ShadcnApp`. Three ways out `[skill] guides/interop.md`:

| Option | Cost |
| :-- | :-- |
| `MaterialShadcnApp` from `shadcn_flutter_material` | Drop-in, same parameters, keeps Material alive. Adds a dependency; defers the real migration. |
| `ShadcnApp` + `MaterialLayer` around specific subtrees | Surgical, but delegates still must be registered at app level via `kMaterialLocalizationsDelegates`. |
| Go all-in: replace the Material widgets with shadcn equivalents | Cleanest. Our Material usage in the shell is 5 widgets. |

Option 3 is the small one here — the shell's Material surface is tiny. Migration order matters though: **`window_manager`'s `WindowCaption` is itself a Material widget** (it takes `backgroundColor`/`brightness` and renders `Material` internals), so the caption in the `builder` is the one place that may force a `MaterialLayer` even after the screens are converted. Flagged below.

### `ShadcnApp` vs `ShadcnApp.router`

Both exist `[pub 0.0.54]` `[src 0.0.53]`. The default constructor carries the Navigator 1.0 surface (`home`, `routes`, `initialRoute`, `onGenerateRoute`, `onGenerateInitialRoutes`, `onUnknownRoute`, `navigatorObservers`, `navigatorKey`); `.router` carries `routeInformationProvider`, `routeInformationParser`, `routerDelegate`, `backButtonDispatcher`, `routerConfig` and asserts `routerDelegate != null || routerConfig != null` `[src 0.0.53 shadcn_app.dart:78-130]`. `.router` nulls out `navigatorKey`, `navigatorObservers`, `onGenerateRoute` and `home`.

**We do not need `.router`.** Clockodile has no `go_router` dependency and navigates with `IndexedStack` plus one imperative push (`openEntryPage`). The default `ShadcnApp` with `home:` and `navigatorKey:` is a 1:1 swap for our `MaterialApp`.

go_router itself: `[skill] guides/setup.md` FAQ — "Does this support GoRouter? Yes, it does." That is the entire extent of what the sources say; no integration example exists in the offline docs. Not our problem today.

**`builder` and overlay-above-Navigator composition survive intact.** `builder` is a `TransitionBuilder?` on both constructors `[pub 0.0.54]` `[src 0.0.53:177]`, same signature and same position as `MaterialApp.builder`. Our `Stack` of `Column(caption, AiToastHost(child))` + `SonnerOverlay` transplants as-is. The theming guide even uses `builder` for global `ComponentTheme` injection `[skill] guides/theming.md`, so it is an endorsed extension point.

One documented sibling, `surfaceBuilder`, appears in `[skill] guides/interop.md` (the skeletonizer example: `ShadcnApp(surfaceBuilder: (context, child) => SkeletonizerLayer(child: child))`) but **is absent from the 0.0.54 constructor listing on pub.dev and absent from 0.0.53 source.** See the unknowns list — do not build on it.

### Localization — **all three parameters exist; Italian is the catch**

`ShadcnApp` takes `locale` (`Locale?`), `localizationsDelegates` (`Iterable<LocalizationsDelegate>?`) and `supportedLocales` (`Iterable<Locale>`, default `[Locale('en','US')]`) — same names and types as `MaterialApp` `[pub 0.0.54]` `[src 0.0.53:200-213]`.

`ShadcnLocalizations.delegate` is **registered automatically**; you do not add it yourself `[skill] guides/installation.md, comment in the example]`, confirmed by `_localizationsDelegates` in source which appends it after the framework defaults `[src 0.0.53:411-418]`.

`flutter_localizations` is a **transitive dependency of the package already** (`shadcn_flutter`'s own pubspec depends on `flutter_localizations` and `intl: ^0.20.2`) `[src 0.0.53 pubspec.yaml]`. We also declare it directly today; harmless either way.

**The catch:** the package ships exactly one locale. `lib/l10n/` contains only `shadcn_en.arb`, and the only concrete implementation in the tree is `ShadcnLocalizationsEn` (`lib/src/components/locale/shadcn_localizations_en.dart`) `[src 0.0.53]`. The 0.0.54 API page for `ShadcnLocalizations` does not enumerate locales at all, so this could not be re-confirmed for the newest release — but nothing in the changelog-adjacent evidence suggests Italian was added.

Consequence for us: with `locale: Locale('it')`, every string shadcn renders *itself* — date-picker month names, the colour-picker labels, "Cancel"/"OK" in built-in dialogs, sort indicators — falls back to English. Our own copy is unaffected. Two mitigations: subclass `ShadcnLocalizations` with an Italian implementation and prepend its delegate (the delegate list is ours; ours is consulted first), or accept English in the few built-in surfaces we actually use. Worth a ticket of its own; it is not a blocker.

Also note the 0.0.54 change: because Material localizations are no longer auto-registered, our `localizationsDelegates: GlobalMaterialLocalizations.delegates` must become `kMaterialLocalizationsDelegates` if we keep any Material widget `[skill] guides/interop.md` table row].

### Keyboard shortcuts — identical to `MaterialApp`

`shortcuts` (`Map<ShortcutActivator, Intent>?`) and `actions` (`Map<Type, Action<Intent>>?`) are app-level parameters with the same types and null defaults `[pub 0.0.54]` `[src 0.0.53:224-230]`. `ShadcnApp` is a `StatefulWidget` that builds down onto `WidgetsApp`, so `WidgetsApp.defaultShortcuts` / `defaultActions` remain the right spread base.

Our Ctrl+W binding (`VoidCallbackIntent` → `VoidCallbackAction`) transplants verbatim — both types come from `package:flutter/widgets.dart`, not Material.

`CallbackShortcuts` (Ctrl+N, Ctrl+T, Ctrl+1..3, Ctrl+S in `_HomeShellState`) is likewise a `widgets.dart` widget with no Material or shadcn coupling, and its focus-scoping behaviour — the property our code comments rely on, that an open modal suppresses the bindings — is a framework `Focus` property, unchanged. The only thing to verify at runtime is that shadcn's dialogs create their own focus scope the way Material's do; nothing in the sources says otherwise, but it is behaviour we should smoke-test rather than assume.

### Custom title bar — **shadcn offers nothing; keep drawing our own**

The `Window` component is **not** a native-title-bar helper. It is an in-app MDI system: `WindowNavigator` hosts floating `Window` widgets with `bounds` (`Rect?`), `maximized`, `minimized`, `draggable`, `resizable`, `closable`, `alwaysOnTop`, `enableSnapping`, each with a `WindowTheme` `[skill] components/overlay/window.md]`. The example renders two 200×200 panels inside an `OutlinedContainer` labelled "Desktop". It has no connection to OS window chrome and no `window_manager` integration.

Nothing else in the component tree is caption-shaped. `components/application/` contains a single file, `wrapper.md`, which documents `ShadcnUI` — the Material-side interop wrapper, unrelated.

Verdict: **keep `window_manager` with `TitleBarStyle.hidden` and keep drawing our own caption.** Two wrinkles:
- `WindowCaption` / `kWindowCaptionHeight` come from `window_manager` and are Material-dependent, so under a bare 0.0.54 `ShadcnApp` they need a `MaterialLayer` wrapper — or replacing with our own `Row` of shadcn `GhostButton`s over a `DragToMoveArea`. The latter is maybe 30 lines and removes the last Material dependency from the shell.
- Our caption reads `Theme.of(context).colorScheme.surface` and `.brightness`. shadcn's `ColorScheme` has **no `surface` role** — see the role list in section 2. The nearest equivalents are `background` or `card`. This is a mechanical but non-obvious rename.

### Lucide icons — **bundled, drop `lucide_icons_flutter`**

`shadcn_flutter` ships three icon fonts as package assets: `RadixIcons.otf`, `BootstrapIcons.otf`, **`LucideIcons.ttf`** `[src 0.0.53 pubspec.yaml fonts:]`. The skill docs count 1,550+ Lucide icons `[skill] guides/icons.md`.

Accessor class is `LucideIcons`, members are `static const IconData` in lowerCamelCase — **the same names we already use**. Verified each icon in `main.dart` against `lib/src/icons/lucide_icons.dart` `[src 0.0.53]`:

| Our call | In shadcn_flutter | Line |
| :-- | :-- | :-- |
| `LucideIcons.listTodo` | present | 3403 |
| `LucideIcons.users` | present | — (in listing) |
| `LucideIcons.fileChartColumn` | present | 2235 |
| `LucideIcons.settings` | present | — (in listing) |
| `LucideIcons.circleHelp` | present | 1431 |

So `catui`'s `lucide_icons_flutter` re-export can be dropped with **no rename at the call sites**. Usage is `Icon(LucideIcons.activity)` `[skill] guides/icons.md` — note that guide has a typo, `LucideIconss` with a double s; the class is `LucideIcons`, per source.

`[skill] guides/interop.md` also gives the migration `Icons.add` → `LucideIcons.plus`, confirming Lucide is the intended core icon set once Material is gone.

---

## 2. What the knobs compile to

### Base colour + accent: composition is an extension, not a parameter

There is **no accent parameter** on `ThemeData` or on `ColorSchemes`. The two-axis model in the knob list (`baseColors: Slate` + `accentColors: Green`) is expressed by calling an extension getter on a base scheme `[src 0.0.53 color_scheme.dart:924-999]`:

```dart
/// Helpers for deriving accent variants from a base [ColorScheme].
extension ColorSchemeRecolorExtension on ColorScheme {
  ColorScheme recolor(Color primary) {
    return copyWith(
      primary: () => primary,
      primaryForeground: () => primary.getContrastColor(),
      ring: () => primary,
    );
  }

  ColorScheme get green => recolor(Colors.green);
  // … slate, gray, zinc, neutral, stone, red, orange, amber, yellow, lime,
  //    emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose
}
```

So **`baseColors: Slate` + `accentColors: Green` = `ColorSchemes.darkSlate.green`**. All 22 Tailwind palette names are available as getters.

Read exactly what `recolor` touches: it overrides **three** roles — `primary`, `primaryForeground` (auto-contrasted), `ring` (the focus ring). It does **not** touch `accent` / `accentForeground`, despite the doc comment calling it "the accent color". The scheme's own `accent` role stays slate. That is a real semantic trap: in shadcn's vocabulary `accent` means the subtle hover/highlight fill, while the knob's "accent colour" means the brand colour, which lands on `primary`. Buttons, focus rings and selected states go green; hover fills stay slate.

`ColorScheme` is overridable per-role regardless — `copyWith` takes `ValueGetter<Color>` per role (note: getters, not bare colours, so a role can be set to `null`-free lazily). The full role list `[src 0.0.53 color_scheme.dart:457-520, 439-440]`:

`background`, `foreground`, `card`, `cardForeground`, `popover`, `popoverForeground`, `primary`, `primaryForeground`, `secondary`, `secondaryForeground`, `muted`, `mutedForeground`, `accent`, `accentForeground`, `destructive`, `destructiveForeground` (deprecated), `border`, `input`, `ring`, `chart1`–`chart5`.

**No `surface`, no `onSurface`, no `surfaceVariant`, no `error`/`onError`, no `outline`.** Every Material `colorScheme.*` reference in our codebase needs a deliberate mapping, not a search-and-replace. The obvious pairs: `surface` → `background` or `card`, `onSurface` → `foreground` or `cardForeground`, `error` → `destructive`, `outline` → `border`.

Predefined schemes are only the five neutrals × 2 brightnesses `[skill] guides/colors.md`: `lightGray`/`darkGray`, `lightNeutral`/`darkNeutral`, `lightSlate`/`darkSlate`, `lightStone`/`darkStone`, `lightZinc`/`darkZinc`. Colour is reached through `.recolor()` / the named getters, which is why there is no `ColorSchemes.darkGreen`.

### The knob-by-knob translation

`ThemeData` is a plain class with a `const` constructor; every knob is a constructor argument `[src 0.0.53 theme.dart:145-200]`, confirmed against `[pub 0.0.54]`:

| Knob | `ThemeData` argument | Type | Default | Concrete value | Confidence |
| :-- | :-- | :-- | :-- | :-- | :-- |
| `themeMode: Dark` | `ShadcnApp.themeMode` (not `ThemeData`) | `ThemeMode` | `ThemeMode.system` | `ThemeMode.dark` | certain |
| `baseColors: Slate` | `colorScheme` | `ColorScheme` | `lightSlate` / `darkSlate` | `ColorSchemes.darkSlate` | certain |
| `accentColors: Green` | `colorScheme` (same arg) | `ColorScheme` | — | `.green` extension getter | certain |
| `radius: Rounded` | `radius` | `double` | `0.5` | **not an API constant** — see below | **inferred** |
| `density: Reduced` | `density` | `Density` | `Density.defaultDensity` | `Density.reducedDensity` | certain |
| `scaling: Default` | `scaling` | `double` | `1` | `1.0`, i.e. omit it | certain |
| `surfaceOpacity: Solid` | `surfaceOpacity` | `double?` | `null` | `1.0` | **inferred** |
| `surfaceBlur: Medium` | `surfaceBlur` | `double?` | `null` | **no stated value** | **unknown** |

**`surfaceOpacity` and `surfaceBlur` are genuinely `ThemeData` fields** — this was the open question in the ticket, and the answer is yes, at both levels. Source `[src 0.0.53 theme.dart:167-170]`:

```dart
/// Default opacity for surface overlays (0.0 to 1.0).
final double? surfaceOpacity;

/// Default blur radius for surface effects.
final double? surfaceBlur;
```

Both default to `null`, and `null` means *off*, not *some default*. They are **also** per-component overrides of the same names and types on `Card`, `AlertDialog`, `NavigationMenu`, `Bar`, `Command` and others, each documented as "If null, uses theme default" `[skill] components/…]`. So the theme field is the fallback and components can opt out individually. That is the composition model.

### Density — exact numbers

`Density` is a class, not an enum, with four `static const` presets `[src 0.0.53 density.dart:129-155]`:

```dart
static const defaultDensity  = Density(baseContainerPadding: 16.0, baseGap: 8.0,  baseContentPadding: 16.0);
static const reducedDensity  = Density(baseContainerPadding: 12.0, baseGap: 6.0,  baseContentPadding: 12.0);
static const spaciousDensity = Density(baseContainerPadding: 20.0, baseGap: 10.0, baseContentPadding: 20.0);
static const compactDensity  = Density(baseContainerPadding:  8.0, baseGap: 4.0,  baseContentPadding:  8.0);
```

**"Reduced" = `Density.reducedDensity`, and its numbers are stated outright: 12 / 6 / 12 px** against the default 16 / 8 / 16 — a 25% reduction. This is the one knob in the list where a named preset matches the knob name exactly.

The three bases mean different things: `baseContainerPadding` for multi-child containers (Card, AlertDialog, list panels), `baseContentPadding` for content widgets (Button, TextField, Chip), `baseGap` for flex spacing. Each is multiplied by a token constant — `padX2s` 0.25, `padXs` 0.5, `padSm` 1.0, `padMd` 1.5, `padLg` 2.0, `padXl` 2.5, `pad2xl` 3.0, `pad3xl` 3.5, `pad4xl` 4.0; and `gapXs` 0.5, `gapSm` 1.0, `gapMd` 1.5, `gapLg` 2.0, `gapXl` 2.5, `gap2xl` 3.0, `gap3xl` 3.5, `gap4xl` 4.0. So `padLg` at reduced density is 12 × 2.0 = 24 px, not 32. `Density` also has `lerp` and `copyWith`, and arbitrary values are constructible — all three fields are `required double`, unbounded.

Consumers: `DensityGap(gapLg)`, `DensityContentPadding`, `DensityContainerPadding`, `DensityRow`, `DensityColumn`, `EdgeInsetsDensity` `[src 0.0.53 density.dart]`. Using these instead of raw `SizedBox`/`EdgeInsets` is what makes the density knob actually do something.

### Radius — "Rounded" is a label, not a constant

`radius` is a bare `double` multiplier, default `0.5` `[src/pub, both agree]`. Derived tokens `[skill] guides/layout.md`:

| Token | Calculation | At default 0.5 |
| :-- | :-- | :-- |
| `radiusXs` | `radius * 4` | 2 |
| `radiusSm` | `radius * 8` | 4 |
| `radiusMd` | `radius * 12` | 6 |
| `radiusLg` | `radius * 16` | 8 |
| `radiusXl` | `radius * 20` | 10 |
| `radiusXxl` | `radius * 24` | 12 |

Access as `theme.radiusMd` (a `double`) or `theme.borderRadiusMd` (a `BorderRadius`).

**There is no `Radius.rounded`, no radius preset class, and no enum anywhere in `lib/src/theme/`** — grepped for `rounded` across the theme directory, zero hits. "Rounded" is a label from the docs-site theme picker, which the offline skill docs do not reproduce. The API accepts **any non-negative `double`**; nothing in the sources states a maximum or an enumerated set.

What the docs *do* give as a worked "rounder corners" example is `radius: 0.7` `[skill] guides/theming.md`, commented literally `// Rounder corners`. That is the closest thing to a sourced value and it is an example, not a definition of "Rounded". Treat `0.7` as a starting point to eyeball, not as a fact. Range guidance from the token table: `0.5` is default/subtle, `0.0` is square, `1.0` gives 8/16/24px corners which is visibly pill-ish on small controls.

### surfaceOpacity — "Solid" is almost certainly 1.0

Field doc says "Default opacity for surface overlays **(0.0 to 1.0)**" `[src 0.0.53]`, and the per-component mirror on `NavigationMenu` repeats "Values range from 0.0 (fully transparent) to 1.0 (fully opaque)" `[skill] components/navigation/navigation_menu.md:280]`. "Solid" maps to `1.0` by plain reading of that range — this is an inference from the documented endpoints, not a stated mapping, but it is a safe one. Range: **0.0–1.0 inclusive**.

Note `1.0` is not the same as the `null` default: `null` means the component decides (and most render opaque anyway), `1.0` pins it. For a desktop app that never wants see-through panels, `1.0` is the intent-revealing choice.

### surfaceBlur — "Medium" has no sourced value

`surfaceBlur` is a **blur radius in logical pixels**, not a 0–1 fraction: "Default blur radius for surface effects" `[src 0.0.53]`, "Higher values create more pronounced background blur effects" `[skill] components/feedback/alert_dialog.md:139]`. It feeds a backdrop blur behind surfaces.

**No preset, no enum, no example value appears in any source consulted.** Grepped the whole skill tree and the 0.0.53 theme source: every mention is a `double?` property description, never a number. The API accepts any non-negative `double`; `null` (the default) means no blur at all.

Do not invent a number for "Medium". If a value is needed, pick it by eye against the Flutter `ImageFilter.blur` convention where sigma 4–12 reads as light-to-heavy frosted glass — and record it as a chosen value, not a translated one.

Second consideration for Clockodile specifically: backdrop blur on Windows desktop costs a saveLayer per blurred surface. With `surfaceOpacity: 1.0` (solid), a blur behind an opaque surface is invisible anyway — the two knobs partly cancel. Worth questioning whether `surfaceBlur` should be set at all; the combination "Solid + Medium blur" may be self-defeating.

### The light counterpart

Same knobs, same types, one different base scheme, and `ThemeData()` vs `ThemeData.dark()`. The two constructors differ **only** in the `colorScheme` default (`lightSlate` vs `darkSlate`) `[src 0.0.53 theme.dart:190, 202-206]`; every other default is identical, and either constructor accepts an explicit `colorScheme`. Since we pass `colorScheme` explicitly, `ThemeData()` alone would work for both — using `.dark()` for the dark one is clarity, not necessity.

Brightness is carried by the `ColorScheme` itself (it has a `brightness` field), which is how the light/dark toggle survives: `ShadcnApp` picks `theme` or `darkTheme` by `themeMode`, exactly as `MaterialApp` does `[skill] guides/theming.md]`.

### The snippet

Both themes, every knob from the ticket, with the uncertain ones marked:

```dart
// Shared: only the colour scheme and the constructor differ.
const _radius = 0.7;   // "Rounded" — no API constant; 0.7 is the docs' own
                       // "rounder corners" example. Eyeball before locking.

final lightTheme = ThemeData(
  colorScheme: ColorSchemes.lightSlate.green, // base Slate, accent Green
  radius: _radius,
  scaling: 1.0,                               // "Default"
  density: Density.reducedDensity,            // 12 / 6 / 12 px
  surfaceOpacity: 1.0,                        // "Solid"
  // surfaceBlur: no sourced value for "Medium" — left null (= no blur).
  // typography: const Typography.geist() is the default; omit unless overriding.
);

final darkTheme = ThemeData.dark(
  colorScheme: ColorSchemes.darkSlate.green,
  radius: _radius,
  scaling: 1.0,
  density: Density.reducedDensity,
  surfaceOpacity: 1.0,
);

// At the root — themeMode is an app parameter, not a theme one:
ShadcnApp(
  title: 'Clockodile',
  navigatorKey: _navigatorKey,
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: themeMode,                 // ThemeMode.dark for the given knob
  locale: const Locale('it'),
  supportedLocales: const [Locale('it')],
  // ShadcnLocalizations.delegate is added automatically.
  // Add kMaterialLocalizationsDelegates only while Material widgets remain.
  shortcuts: { ...WidgetsApp.defaultShortcuts, /* Ctrl+W as today */ },
  actions:   { ...WidgetsApp.defaultActions,   VoidCallbackIntent: VoidCallbackAction() },
  builder: (context, child) => /* the existing Stack, unchanged */,
  home: /* … */,
)
```

Fonts: Geist ships with the package and is wired automatically by `ThemeData`; override with `typography: Typography.sans(family: 'MyCustomFont')` `[skill] guides/installation.md`.

---

## Unknown / not stated in sources

1. **The numeric value of "Rounded" radius.** No constant, no enum, no mapping. `radius` is a `double` multiplier, default `0.5`, accepting any non-negative value. `0.7` is the docs' own "rounder corners" example and nothing more.
2. **The numeric value of "Medium" `surfaceBlur`.** No preset and no example value anywhere. It is a blur radius in logical pixels, `double?`, default `null` = no blur. Unbounded above.
3. **The exact value of "Solid" `surfaceOpacity`.** `1.0` is inferred from the documented `0.0`–`1.0` range with `1.0` = "fully opaque". Not stated as a mapping.
4. **Whether these knob labels come from a real API at all.** They read as docs-site theme-picker labels. The offline skill docs do not reproduce that picker, and it was not reachable as a primary source. `Density` is the one case where the label matches a real constant (`reducedDensity`).
5. **`surfaceBuilder` on `ShadcnApp`.** Used in `[skill] guides/interop.md`'s skeletonizer example, absent from the 0.0.54 constructor listing on pub.dev and from 0.0.53 source. Either newer than the API docs indexed, older and removed, or a doc error. Verify before depending on it.
6. **Italian localization in 0.0.54.** Confirmed absent in 0.0.53 (only `shadcn_en.arb` / `ShadcnLocalizationsEn`). The 0.0.54 API page does not enumerate locales, so not re-confirmed for the version we would adopt.
7. **0.0.54's exact source.** All numeric defaults here are read from 0.0.53 in the pub cache and cross-checked against the 0.0.54 API docs where those docs state defaults (`colorScheme`, `radius`, `scaling`, `typography`, `iconTheme`, `density`, `surfaceOpacity`, `surfaceBlur`, `platform`, `enableFeedback` — all matched). The `Density` preset numbers and the `recolor` extension body are **0.0.53-only reads**; the API docs do not print constant values. Low risk, non-zero.
8. **go_router integration specifics.** Sources say only "Yes, it does." No example. Irrelevant to us today.
9. **Whether shadcn dialogs create their own focus scope** the way Material's do — our `CallbackShortcuts` suppression-during-modal behaviour depends on it. Not stated; smoke-test it.
10. **Windows-specific caveats.** None stated. Absence of a caveat is not evidence of absence.

---

## What blocks the migration

Nothing blocks it. Ranked by what will actually cost time:

1. **The Material split (0.0.54).** `Scaffold`, `IconButton`, `CircularProgressIndicator`, `VerticalDivider` and `Theme.of(context)` in `main.dart` all assert under a bare `ShadcnApp`. Decide early: `MaterialShadcnApp` as a bridge, or go all-in. The shell's Material surface is 5 widgets — all-in is the smaller total diff.
2. **`WindowCaption` is Material.** The one Material widget we cannot trivially replace with a shadcn equivalent, because it comes from `window_manager`. Either wrap it in `MaterialLayer` or hand-roll the caption (~30 lines over `DragToMoveArea`).
3. **`ColorScheme` has no `surface`.** Every Material colour-role reference needs a deliberate mapping. `surface` → `background`/`card`, `onSurface` → `foreground`, `error` → `destructive`, `outline` → `border`.
4. **Italian falls back to English** in shadcn's own built-in strings. Needs its own ticket; not a blocker.
5. **Flutter floor rises to 3.47.0.** We are on 3.47.1 — one patch above. Anyone below cannot build.

Free wins: shortcuts and `builder` transplant verbatim; Lucide icon names are already identical, so `lucide_icons_flutter` drops out with zero call-site renames.
