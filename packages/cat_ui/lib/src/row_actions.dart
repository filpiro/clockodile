import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tokens.dart';

/// Muted at rest, [accent] on hover — the control states its intent before
/// the click. Shared by the row icon actions and by "Termina", so a hovered
/// destructive control always reads the same wherever it sits.
ButtonStyle intentHoverStyle({required Color idle, required Color accent}) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return idle.withValues(alpha: AppTokens.disabledAlpha);
      }
      return states.contains(WidgetState.hovered) ? accent : idle;
    }),
    // Without this the ripple keeps the default tint and fights the accent.
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.isEmpty
          ? null
          : accent.withValues(alpha: AppTokens.hoverOverlayAlpha),
    ),
  );
}

/// Hover-revealed edit action. Icon size comes from the global
/// `iconButtonTheme`; only the intent colour is set here.
class EditIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const EditIconButton({super.key, this.onPressed, this.tooltip = 'Modifica'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(LucideIcons.pencil),
      style: intentHoverStyle(
        idle: scheme.onSurfaceVariant,
        accent: scheme.primary,
      ),
      onPressed: onPressed,
    );
  }
}

/// Hover-revealed destructive action. [tooltip] is overridable because the
/// entry page explains *why* deletion is blocked on the last session.
class DeleteIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const DeleteIconButton({super.key, this.onPressed, this.tooltip = 'Elimina'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(LucideIcons.trash2),
      style: intentHoverStyle(
        idle: scheme.onSurfaceVariant,
        accent: scheme.error,
      ),
      onPressed: onPressed,
    );
  }
}

/// Confirm button for dialogs that destroy data. Filled with `error` rather
/// than tinted on hover: by this point the user is committing, not browsing.
class DangerButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const DangerButton({super.key, this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
