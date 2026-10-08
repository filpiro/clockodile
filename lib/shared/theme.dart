import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Locked knobs: Gray base, teal accent, Rounded radius (0.75), default
/// density and scaling, solid surfaces with no blur. Both brightnesses share
/// them; the mode is the user's pick.
ThemeData _theme(ColorScheme base) => ThemeData(
  colorScheme: base.teal,
  radius: 0.75,
  surfaceOpacity: 1.0,
  surfaceBlur: 0.0,
);

/// Off-white surface for light mode: no pure white anywhere.
const _lightSurface = Color(0xFFF5F6F8);

/// Soft-neutral dark ramp: card/popover sit above background, muted/border
/// step up again so hovered rows and dividers stay visible.
const _darkBackground = Color(0xFF16181D);
const _darkForeground = Color(0xFFE4E6EB);
const _darkCard = Color(0xFF1C1F26);
const _darkMuted = Color(0xFF262A33);
const _darkMutedForeground = Color(0xFFA0A4AD);
const _darkBorder = Color(0xFF2E323C);

final ColorScheme _lightGray = ColorSchemes.lightGray.copyWith(
  background: () => _lightSurface,
  card: () => _lightSurface,
  popover: () => _lightSurface,
);

final ColorScheme _darkGray = ColorSchemes.darkGray.copyWith(
  background: () => _darkBackground,
  foreground: () => _darkForeground,
  card: () => _darkCard,
  cardForeground: () => _darkForeground,
  popover: () => _darkCard,
  popoverForeground: () => _darkForeground,
  secondary: () => _darkMuted,
  secondaryForeground: () => _darkForeground,
  muted: () => _darkMuted,
  mutedForeground: () => _darkMutedForeground,
  accent: () => _darkMuted,
  accentForeground: () => _darkForeground,
  border: () => _darkBorder,
  input: () => _darkBorder,
);

final ThemeData lightTheme = _theme(_lightGray);
final ThemeData darkTheme = _theme(_darkGray);

/// Max width of forms and prose. The only shared layout constant; everything
/// else comes from the theme or is a file-local `const`.
const double formMaxWidth = 560;
