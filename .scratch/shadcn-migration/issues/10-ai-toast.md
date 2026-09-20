# The AI toast: persistent, self-updating, opens dialogs

Type: grilling
Status: open
Blocked by: ~~03~~ (resolved — see `../research/03-component-inventory.md`)
Map: ../map.md

## Question

Graduated from the map's fog by ticket 03, which found this is the single widget shadcn fits worst. `ai_toast.dart` + `app_toast.dart` today: a toast that stays up for the whole model download, whose label counts `pendingBytes` live, which carries buttons that open dialogs, and which is raised and dismissed from a **context-free global helper** via a top-level handle.

What shadcn gives: `showToast({required BuildContext context, required ToastBuilder builder, ToastLocation, bool dismissible, Duration showDuration}) → ToastOverlay`, hosted by `ToastLayer` which `ShadcnApp` already installs. `ToastOverlay` has `isShowing` and `close()`.

The three mismatches, each needing a call:
- **Persistent.** `showDuration` is non-nullable with no sentinel. `Duration(days: 365)` is the workaround. Accept it, or is the AI progress surface not a toast at all any more — an `Alert` pinned in the shell, a `Progress` row, a `Window`?
- **Update in place.** `ToastOverlay` cannot mutate its content. Either close-and-reshow per state (resets the entry animation, visibly janky on a byte counter) or put a `BlocBuilder` **inside** the toast builder — which keeps the UX but inverts today's raise-a-fresh-toast-per-state architecture. Decide which, and if it's the `BlocBuilder`, what that does to `ai_toast_test.dart`.
- **Context-free helper.** `showToast` requires a `BuildContext`; our shared helper has none. Does the helper take a context, does it borrow `_navigatorKey.currentContext`, or does the AI cubit own the toast lifecycle instead?

Also decide:
- Whether `AiToastHost`'s `navigatorKey` hand-off stays. Research could not confirm where `ToastLayer` sits relative to the Navigator, so dialogs opened from inside a toast are unproven — **smoke-test this before designing on it.**
- Whether `dismissible: false` (which also kills swipe) is wanted while a download is in flight.
- What of `appToastConfig` survives: `maxStackedEntries: 1`, `toastConstraints` and `padding` map over; alignment becomes per-call `ToastLocation.bottomCenter`.

Use `/grilling`.
