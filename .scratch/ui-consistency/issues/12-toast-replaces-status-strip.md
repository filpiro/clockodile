# 12 — Toast replaces the bottom status strip

**What to build:** the full-width bar under the app goes away. Messages and Local
Model states appear instead as a sonner-style toast: a card at the bottom
centre, fixed width, wearing the same surface as the dialogs from ticket 09, with
a close X always present — this is a desktop app, so swipe alone leaves mouse
users with no way out.

One toast at a time: a new one replaces whatever is showing, which is what the
current snackbar helper already does. No stacking.

A Local Model toast is sticky — it has no timer and stays until its state
resolves or the user closes it — and carries its action button (`Aggiorna`,
`Riprova`). A plain message auto-dismisses.

`sonner_toast` supplies only the overlay, motion and gestures; it ships no UI, so
it is a Clockodile dependency configured in the app, exactly like the
autocomplete, and never a catui dependency. The card inside it is built from
catui tokens and the ticket 09 surface recipe.

The status strip widget is deleted: something that renders nothing most of the
time is a side effect, not a widget in the tree. The Local Model state drives the
toast from the app shell, above the Navigator, and keeps the navigator key the
install and update dialogs need.

**Blocked by:** 09 — One catppuccin surface for dialogs.

**Status:** done

- [x] `sonner_toast` is a Clockodile dependency; catui does not depend on it and
      the app's toast card uses catui tokens and the shared surface
- [x] Toasts appear bottom centre, fixed width, with a close X; a new toast
      replaces the outstanding one
- [x] Local Model starting / update-available / error states show a sticky toast
      with the right action, and the action still opens its dialog
- [x] Ordinary messages (settings saved, and the rest) show as auto-dismissing
      toasts
- [x] The status strip file is gone and nothing imports catui's snackbar helper;
      the helper itself stays in catui for other consumers
- [x] The AI status tests are rewritten against the toast
