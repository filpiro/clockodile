# shadcn_flutter setup facts: version, platform, ShadcnApp, and the theme knobs

Type: research
Status: resolved
Map: ../map.md

## Question

Two halves, one source (pub.dev + `.claude/skills/shadcn-flutter/guides/`).

**Can we run it, and how does the root wire up?**
- Latest published `shadcn_flutter` version, and its Dart/Flutter SDK constraints against ours (Dart SDK 3.13.1, Flutter 3.47.1, `sdk: ^3.10.7` in pubspec).
- Windows desktop support — stated, and any known caveats.
- `ShadcnApp` vs `ShadcnApp.router`: constructor surface, what `go_router` integration looks like, whether `builder` / overlay-above-Navigator composition still works (we stack a custom caption, toasts and a listener above the Navigator today).
- Localization: does `ShadcnApp` take `localizationsDelegates` / `locale` / `supportedLocales`? Does it need `flutter_localizations`, and does it ship its own delegate that must be added? We are Italian-only (`Locale('it')`).
- Keyboard shortcuts: do `shortcuts` / `actions` / `CallbackShortcuts` behave as under `MaterialApp`? We bind Ctrl+W, Ctrl+N, Ctrl+T, Ctrl+1..n.
- Custom title bar: what shadcn offers for a hidden native title bar (`window_manager` `TitleBarStyle.hidden`) — the `Window` component, anything caption-shaped, or nothing (we keep drawing our own).
- Does it bundle Lucide icons (we use `lucide_icons_flutter` via catui today), and under what names?

**What exactly do the given knobs compile to?**
Translate each into real `ThemeData` arguments, with the concrete value and the type:
`themeMode: Dark`, `baseColors: Slate`, `accentColors: Green`, `radius: Rounded`, `density: Reduced`, `scaling: Default`, `surfaceOpacity: Solid`, `surfaceBlur: Medium`.
- How do a *base* colour scheme and a separate *accent* colour compose? Is `ColorSchemes.darkSlate` overridable per-role, or is there an accent parameter?
- What numeric value is "Rounded" radius, "Reduced" density, "Default" scaling, "Solid" surfaceOpacity, "Medium" surfaceBlur — and are `surfaceOpacity`/`surfaceBlur` `ThemeData` fields at all, or per-component?
- The light counterpart of the same knobs, since the light/dark toggle survives.

Capture findings as Markdown in the repo and link them from this ticket.

## Answer

Findings: [research/01-shadcn-app-and-theme.md](../research/01-shadcn-app-and-theme.md)

**Can we run it — yes.** Latest is `shadcn_flutter` **0.0.54** (2026-08-27), needing Dart `>=3.13.0` / Flutter `>=3.47.0`. We have Dart 3.13.1 / Flutter 3.47.1 — compatible by one patch release. Our `sdk: ^3.10.7` intersects cleanly, so no pubspec edit is required. Windows is a stated first-class platform with no documented caveats.

**Root wiring.** `ShadcnApp` is a 1:1 swap for our `MaterialApp`: `builder` (`TransitionBuilder?`), `shortcuts`, `actions`, `navigatorKey`, `home`, `locale`, `supportedLocales`, `localizationsDelegates`, `theme`/`darkTheme`/`themeMode` all carry the same names and types. Our overlay-above-Navigator `Stack` (caption + `AiToastHost` + `SonnerOverlay`) and our Ctrl+W `VoidCallbackIntent` transplant verbatim; `CallbackShortcuts` is pure `widgets.dart` and unaffected. `ShadcnApp.router` exists for `go_router` but we do not need it.

**Localization.** All three parameters exist; `ShadcnLocalizations.delegate` is registered automatically and `flutter_localizations` already comes in transitively. But the package ships **English only** — with `Locale('it')`, shadcn's own built-in strings fall back to English. Needs its own ticket.

**Title bar.** shadcn offers nothing. The `Window` component is in-app MDI (`WindowNavigator` + floating `Window` widgets), unrelated to OS chrome. Keep `window_manager` + `TitleBarStyle.hidden` and keep drawing our own caption.

**Icons.** Lucide is bundled (`LucideIcons.ttf`, 1550+ icons) under the class `LucideIcons`, and every name we use — `listTodo`, `users`, `fileChartColumn`, `settings`, `circleHelp` — exists verbatim. `lucide_icons_flutter` drops out with zero call-site renames.

**The knobs.** Base + accent compose via an extension, not a parameter: `ColorSchemes.darkSlate.green`. `recolor()` overrides exactly three roles — `primary`, `primaryForeground`, `ring` — and notably *not* `accent`/`accentForeground`. `surfaceOpacity` and `surfaceBlur` **are** real `ThemeData` fields (both `double?`, both default `null`), mirrored as per-component overrides that fall back to the theme.

| Knob | Argument | Type | Value |
| :-- | :-- | :-- | :-- |
| `themeMode: Dark` | `ShadcnApp.themeMode` | `ThemeMode` | `ThemeMode.dark` |
| `baseColors: Slate` + `accentColors: Green` | `colorScheme` | `ColorScheme` | `ColorSchemes.darkSlate.green` |
| `radius: Rounded` | `radius` | `double` | **no constant** — any non-negative double, default `0.5`; docs' "rounder" example is `0.7` |
| `density: Reduced` | `density` | `Density` | `Density.reducedDensity` = 12 / 6 / 12 px |
| `scaling: Default` | `scaling` | `double` | `1.0` |
| `surfaceOpacity: Solid` | `surfaceOpacity` | `double?` | `1.0` (inferred from the documented 0.0–1.0 range) |
| `surfaceBlur: Medium` | `surfaceBlur` | `double?` | **no sourced value** — blur radius in px, unbounded, `null` = off |

Light counterpart is identical but for `ThemeData()` + `ColorSchemes.lightSlate.green`; the two constructors differ only in their `colorScheme` default, and brightness rides on the `ColorScheme` itself.

**Not stated in sources:** the numeric value of "Rounded" and of "Medium" blur; whether these labels are an API at all (only `Density` matches a real constant); `surfaceBuilder` (used in the interop guide, absent from the 0.0.54 API); Italian in 0.0.54. Full list in the findings file.

**Blockers — none.** Ranked costs: (1) the 0.0.54 Material split — `Scaffold`, `IconButton`, `CircularProgressIndicator`, `VerticalDivider` and `Theme.of` in `main.dart` assert under a bare `ShadcnApp`; (2) `window_manager`'s `WindowCaption` is itself Material, so it needs a `MaterialLayer` or a ~30-line hand-rolled replacement; (3) shadcn's `ColorScheme` has **no `surface` role** — `surface` → `background`/`card`, `onSurface` → `foreground`, `error` → `destructive`, `outline` → `border`; (4) Italian fallback; (5) the Flutter floor rises to 3.47.0.
