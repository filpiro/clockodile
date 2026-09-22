import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Locked knobs (ticket 07): Slate base, green accent, radius 0.7, reduced
/// density, solid surfaces with no blur. Both brightnesses share them.
ThemeData _theme(ColorScheme base) => ThemeData(
  colorScheme: base.green,
  radius: 0.7,
  density: Density.reducedDensity,
  surfaceOpacity: 1.0,
  surfaceBlur: null,
);

final ThemeData lightTheme = _theme(ColorSchemes.lightSlate);
final ThemeData darkTheme = _theme(ColorSchemes.darkSlate);

/// Max width of forms and prose. The only shared layout constant; everything
/// else comes from the theme or is a file-local `const`.
const double formMaxWidth = 560;
