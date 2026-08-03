import 'package:catppuccin_flutter/catppuccin_flutter.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Maps a catppuccin [flavor] onto a Material 3 [ThemeData].
///
/// The accent pair is the axis apps differ on; everything else is the house
/// style and is deliberately not parameterised. Both hues fall back to the
/// flavor's own, so a new app gets a coherent theme without stating a brand.
///
/// The foregrounds are not settable: [Flavor.base] contrasts against every
/// accent in the palette, in either brightness, because catppuccin accents all
/// sit mid-range. An accent from outside the palette is on its own.
ThemeData catTheme(
  Flavor flavor,
  Brightness brightness, {
  Color? primary,
  Color? secondary,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary ?? flavor.mauve,
    onPrimary: flavor.base,
    secondary: secondary ?? flavor.pink,
    onSecondary: flavor.base,
    // Muted container so NavigationRail indicator / selected segments stay subtle.
    secondaryContainer: flavor.surface1,
    onSecondaryContainer: flavor.text,
    error: flavor.red,
    onError: flavor.base,
    surface: flavor.base,
    onSurface: flavor.text,
    surfaceContainerLowest: flavor.crust,
    surfaceContainerLow: flavor.mantle,
    surfaceContainer: flavor.surface0,
    surfaceContainerHigh: flavor.surface1,
    surfaceContainerHighest: flavor.surface2,
    onSurfaceVariant: flavor.subtext0,
    outline: flavor.overlay0,
    outlineVariant: flavor.surface1,
  );

  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppTokens.radius)),
  );

  return ThemeData(
    colorScheme: scheme,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(iconSize: AppTokens.iconSize),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: shape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: shape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(shape: shape),
    ),
  );
}
