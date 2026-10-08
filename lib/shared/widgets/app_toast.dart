import 'package:shadcn_flutter/shadcn_flutter.dart' hide showToast;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show showToast;

/// The app's Navigator. Its context sits above every route, so a toast raised
/// through it always lands on ShadcnApp's own toast layer, never on a screen
/// Scaffold's; the Local Model's toast opens its dialogs through it too.
final navigatorKey = GlobalKey<NavigatorState>();

// ponytail: showToast takes no "forever"; a year is one on a desktop app.
const _stickyLife = Duration(days: 365);

/// shadcn's own default, restated only because the call has to pick one.
const _messageLife = Duration(seconds: 5);

/// The Local Model's toast, if one is up. Messages stack over it, and it shows
/// again when they close.
ToastOverlay? _ai;

/// Shows [message] on shadcn's toast stack, bottom right.
///
/// [sticky] is for a state the user has to resolve: it has no timer to speak
/// of, and a new sticky toast replaces the last one. Everything else goes
/// after shadcn's 5s.
void showToast(
  String message, {
  String? action,
  VoidCallback? onAction,
  bool sticky = false,
  bool spinner = false,
}) {
  // No app mounted (a widget test of one screen): nowhere to show it.
  final context = navigatorKey.currentContext;
  if (context == null) return;
  if (sticky) _ai?.close();
  final toast = shadcn.showToast(
    context: context,
    showDuration: sticky ? _stickyLife : _messageLife,
    builder: (context, overlay) => _ToastCard(
      message: message,
      action: action,
      onAction: onAction,
      spinner: spinner,
      onClose: overlay.close,
    ),
  );
  if (sticky) _ai = toast;
}

/// Takes the sticky toast away, for a state that resolved by itself.
void dismissToast() {
  _ai?.close();
  _ai = null;
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
    return SurfaceCard(
      child: Row(
        children: [
          if (spinner) const CircularProgressIndicator(),
          Expanded(child: Text(message).small()),
          if (action != null)
            OutlineButton(
              size: ButtonSize.small,
              onPressed: onAction,
              child: Text(action!),
            ),
          // A desktop app: swipe alone would leave a mouse with no way out.
          // No tooltip: the toast layer sits above the Navigator's Overlay.
          IconButton(
            variance: const ButtonStyle.ghostIcon(),
            density: ButtonDensity.icon,
            size: ButtonSize.small,
            icon: const Icon(LucideIcons.x, semanticLabel: 'Chiudi'),
            onPressed: onClose,
          ),
        ],
      ).gap(8),
    );
  }
}
