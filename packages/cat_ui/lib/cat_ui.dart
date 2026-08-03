/// Shared house style: catppuccin theme, design tokens and the atomic widgets
/// built on top of them.
///
/// The palette and icon packages are re-exported so a consuming app declares
/// `cat_ui` only and stays version-locked to the same glyphs and flavors.
library;

export 'package:catppuccin_flutter/catppuccin_flutter.dart';
export 'package:lucide_icons_flutter/lucide_icons.dart';

export 'src/empty_state.dart';
export 'src/hover_tile.dart';
export 'src/row_actions.dart';
export 'src/theme.dart';
export 'src/tokens.dart';
