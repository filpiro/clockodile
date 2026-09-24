import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The one list row: hover paints a muted fill, nothing else changes on
/// hover. `onEdit`/`onDelete` render the always-visible action pair; rows
/// that need something else pass [trailing] instead.
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Clickable(
      onPressed: onTap,
      mouseCursor: WidgetStatePropertyAll(
        onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      ),
      // Clickable has no hover fill of its own. Transparent at rest keeps
      // the box in the tree, so the fill animates in and out.
      decoration: WidgetStateProperty.resolveWith(
        (states) => BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? theme.colorScheme.muted
              : theme.colorScheme.muted.withValues(alpha: 0),
          borderRadius: theme.borderRadiusMd,
        ),
      ),
      child: Basic(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailingAlignment: Alignment.center,
        trailing: trailing ?? _actions(theme),
      ),
    );
  }

  Widget? _actions(ThemeData theme) {
    if (onEdit == null && onDelete == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (onEdit != null)
          _tip(
            'Modifica',
            IconButton(
              variance: ButtonStyle.ghostIcon(),
              icon: const Icon(LucideIcons.pencil),
              density: ButtonDensity.icon,
              onPressed: onEdit,
            ),
          ),
        // Ghost like edit; red only under the pointer.
        if (onDelete != null)
          _tip(
            'Elimina',
            IconButton(
              variance: const ButtonStyle.ghostIcon().withForegroundColor(
                hoverColor: theme.colorScheme.destructive,
              ),
              icon: const Icon(LucideIcons.trash2),
              density: ButtonDensity.icon,
              onPressed: onDelete,
            ),
          ),
      ],
    );
  }

  static Widget _tip(String label, Widget child) => Tooltip(
    tooltip: (_) => TooltipContainer(child: Text(label)),
    child: child,
  );
}
