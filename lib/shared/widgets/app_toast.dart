import 'package:catui/catui.dart';
import 'package:flutter/material.dart';
import 'package:sonner_toast/sonner_toast.dart';

/// Bottom centre, one fixed width, one toast at a time. `sonner_toast` ships no
/// UI: it is the overlay, the motion and the swipe, and the card below is ours.
const appToastConfig = SonnerConfig(
  alignment: Alignment.bottomCenter,
  width: 380,
  maxVisibleToasts: 1,
  outerPadding: EdgeInsets.only(bottom: AppTokens.gutter),
);

const _toastLife = Duration(seconds: 4);

/// The sticky toast waiting for the slot back, if one is outstanding. A message
/// borrows the single slot for [_toastLife]; without this, a "Nota copiata"
/// would bury an unresolved state for the rest of the session, since the state
/// only announces itself when it changes.
_Toast? _sticky;

/// Stamps every raised toast, so a toast that has already been replaced cannot
/// hand the slot back on its way out.
int _generation = 0;

class _Toast {
  const _Toast(this.message, this.action, this.onAction, this.spinner);

  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool spinner;
}

/// Shows [message] as the app's single toast, replacing whatever is showing.
///
/// [sticky] drops the timer: a state the user has to resolve stays until it
/// resolves or the close X is pressed. Everything else fades on its own, and
/// gives the slot back to the sticky toast it interrupted.
void showToast(
  String message, {
  String? action,
  VoidCallback? onAction,
  bool sticky = false,
  bool spinner = false,
}) {
  final toast = _Toast(message, action, onAction, spinner);
  if (sticky) _sticky = toast;
  _raise(toast, sticky: sticky);
}

void _raise(_Toast toast, {required bool sticky}) {
  // Stamp first: dismissAll below makes the outgoing toast run its own
  // onDismiss, which must see that the slot has already moved on.
  final id = ++_generation;
  Sonner.dismissAll();
  Sonner.toast(
    duration: sticky ? null : _toastLife,
    onDismiss: sticky
        ? null
        : () {
            final outstanding = _sticky;
            if (id == _generation && outstanding != null) {
              _raise(outstanding, sticky: true);
            }
          },
    builder: (context, dismiss) => _ToastCard(
      message: toast.message,
      action: toast.action,
      onAction: toast.onAction,
      spinner: toast.spinner,
      onClose: () {
        // Closing the sticky toast by hand is the user saying they have read
        // it: it does not come back until the state changes again.
        if (sticky) _sticky = null;
        dismiss();
      },
    ),
  );
}

/// Takes the outstanding toast away, for a state that resolved by itself.
void dismissToast() {
  _sticky = null;
  _generation++;
  Sonner.dismissAll();
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.action,
    required this.onAction,
    required this.spinner,
    required this.onClose,
  });

  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool spinner;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // The surface is the shared recipe's; Material is here for the buttons'
      // ink and the default text style, not for a colour of its own.
      color: Colors.transparent,
      child: Container(
        decoration: catSurfaceDecoration(theme.colorScheme),
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 8, 8, 8),
        child: Row(
          children: [
            if (spinner) ...[
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
            if (action != null)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: theme.textTheme.bodySmall,
                ),
                onPressed: onAction,
                child: Text(action!),
              ),
            // A desktop app: swipe alone would leave a mouse with no way out.
            // No tooltip: the toast floats above the Navigator's Overlay, and a
            // tooltip needs one over it.
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: AppTokens.iconSize,
              icon: const Icon(LucideIcons.x, semanticLabel: 'Chiudi'),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
