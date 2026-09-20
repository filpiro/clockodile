# 09 — One catppuccin surface for dialogs

**What to build:** confirm and text-input dialogs stop wearing the default
Material background and sit on a catppuccin surface — one step off the page
background, with a hairline border and the house corner radius — so a dialog
reads as lifted without a Material elevation tint.

The skin is defined once, as a recipe any surface can wear, not inline in the
dialog theme: the toast in ticket 12 needs the identical look, and two
hand-written copies match only until one of them changes.

The date picker is out of scope for this round.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] catui exposes a reusable surface recipe: `mantle` background, 1px
      `outlineVariant`, `AppTokens.radius`
- [x] `catTheme`'s `dialogTheme` uses that recipe; no dialog states its own
      background
- [x] `catConfirm` and `catTextInput` show the new surface in both light and dark
- [x] The date picker is untouched
- [x] Both repos committed, `pubspec.yaml` pinned to the new catui ref, app builds
