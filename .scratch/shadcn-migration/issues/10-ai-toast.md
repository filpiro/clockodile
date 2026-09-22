# The AI toast: persistent, self-updating, opens dialogs

Type: grilling
Status: resolved
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

## Answer

Two premises were wrong, and fixing them removes most of the three mismatches:
- **No live byte counter.** The toast goes away during `installing`. Download progress is in the blocking modal (`ai_install_dialogs.dart`). `pendingBytes` appears only in the static `Aggiorna (1,3 GB)` label. The AI toast has three states (`notInstalled`, `starting`, `error`), and they change a few times per app start.
- **The dialog question is answered from source, so no smoke test is needed.** `ToastLayer` wraps `ShadcnApp.builder`, which is above the Navigator (`shadcn_app.dart:606`). Toast content is built with the layer's own context (`toast.dart:702`). So dialogs opened from a toast still need `navigatorKey`.

Facts from the source (shadcn_flutter 0.0.54, `lib/src/components/overlay/toast.dart`):
- Entries past `maxStackedEntries` are hidden but stay alive. When the top toast closes, the one below shows again (lines 649–709).
- Every shadcn `Scaffold` has its own `ToastLayer` (`scaffold.dart:376–379`). `showToast` finds the nearest one.
- `ToastEntry.showDuration` is nullable, but the public `showToast()` makes it non-nullable. The timer pauses on hover.

Decisions:
1. **Native stack.** A message stacks on top of the AI toast. When the message closes, the AI toast shows again. Delete `_sticky`, `_generation` and `Sonner.dismissAll`. `app_toast.dart` keeps one `ToastOverlay? _ai` handle. The AI state closes it and raises a new one. `dismissToast()` becomes `_ai?.close()`.
2. **shadcn defaults for place and size.** `bottomRight`, 320px wide, up to 3 stacked, the stack expands on hover. No `ComponentTheme<ToastTheme>`. `appToastConfig` is deleted. Message toasts use the default 5s `showDuration` (today it is 4s).
3. **The helper borrows `_navigatorKey.currentContext`.** That context is above every route, so it always reaches the app-level `ToastLayer` and never a screen `Scaffold`'s layer. `showToast(String, …)` keeps its signature, so the 7 call sites do not change. The key moves somewhere `app_toast.dart` can reach it (today it is private to `main.dart`).
4. **Close and raise a new toast on each AI state change.** No `BlocBuilder` inside the toast. The AI toast uses `showDuration: Duration(days: 365)`. `AiToastHost` and its `navigatorKey` hand-off stay.
5. **`dismissible: true`.** A swipe or the X means "I read it". The toast comes back only when the state changes. The close X stays hand-added, because this is a desktop app.

Effect on `ai_toast_test.dart`: the harness changes from `MaterialApp` + `SonnerOverlay` to `ShadcnApp`. The state tests stay the same. The two slot tests get new meanings. "A message borrows the slot and hands it back" still holds, because of the native stack. "A message toast replaces the outstanding one" becomes "messages stack", and the timer expectation moves from 4s to 5s.
