import 'package:catppuccin_flutter/catppuccin_flutter.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

final ThemeData lightTheme = catTheme(catppuccin.latte, Brightness.light);
final ThemeData darkTheme = catTheme(catppuccin.mocha, Brightness.dark);

/// Maps a catppuccin [flavor] onto a Material 3 [ThemeData].
///
/// [primary] is the one axis apps are expected to differ on; everything else is
/// the house style and is deliberately not parameterised.
ThemeData catTheme(
  Flavor flavor,
  Brightness brightness, {
  Color primary = AppTokens.primary,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: flavor.base,
    secondary: flavor.pink,
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
