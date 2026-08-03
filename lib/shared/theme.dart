import 'package:cat_ui/cat_ui.dart';
import 'package:flutter/material.dart';

/// Clockodile's accent. cat_ui defaults to the palette's mauve; green is this
/// app's choice, stated here rather than in the package so a second app can
/// pick its own without touching the house style.
///
/// Taken per flavor rather than fixed, so it tracks the brightness: latte's
/// green is dark, mocha's is light, and both carry [Flavor.base] as foreground.
/// secondary is left to cat_ui.
ThemeData _theme(Flavor flavor, Brightness brightness) =>
    catTheme(flavor, brightness, primary: flavor.green);

final ThemeData lightTheme = _theme(catppuccin.latte, Brightness.light);
final ThemeData darkTheme = _theme(catppuccin.mocha, Brightness.dark);
