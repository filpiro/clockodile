import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Broadcasts whether a row's quiet actions should be visible right now
/// (hovered, or one of them has keyboard focus) to [RowAction] descendants.
/// A [RowAction] doesn't have to live inside [AppListRow]'s own subtree at
/// the call site — see [_ActiveEntryTile]'s pencil in entries_view.dart —
/// only inside the widget tree it renders into, which this inherits down.
class _RowActionsVisibility extends InheritedWidget {
  final bool visible;
  const _RowActionsVisibility({required this.visible, required super.child});

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_RowActionsVisibility>()
          ?.visible ??
      true;

  @override
  bool updateShouldNotify(_RowActionsVisibility oldWidget) =>
      visible != oldWidget.visible;
}

/// A ghost icon button for use as a row action: small, dense, tooltipped,
/// hidden at rest and revealed on row hover or focus (see
/// [_RowActionsVisibility]). [destructive] reddens the icon under the
/// pointer only — never from the row's own hover.
///
/// Isolates itself from the row's hover state (`WidgetStatesProvider.
/// boundary`): without it, shadcn_flutter flows the row `Clickable`'s hover
/// state down into every nested button, so [destructive]'s hover colour
/// would fire from row hover alone.
class RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  const RowAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final visible = _RowActionsVisibility.of(context);
    final style = destructive
        ? const ButtonStyle.ghostIcon().withForegroundColor(
            hoverColor: Theme.of(context).colorScheme.destructive,
          )
        : ButtonStyle.ghostIcon();
    return WidgetStatesProvider.boundary(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: kDefaultDuration,
        child: IgnorePointer(
          ignoring: !visible,
          child: Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(tooltip)),
            child: IconButton(
              variance: style,
              icon: Icon(icon),
              size: ButtonSize.small,
              density: ButtonDensity.iconDense,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one list row: hover paints a muted fill. `onEdit`/`onDelete` render
/// the quiet action pair (hidden until hover/focus, see [RowAction]); rows
/// that need something else pass [trailing] instead.
class AppListRow extends StatefulWidget {
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
  State<AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<AppListRow> {
  bool _hovered = false;

  // canRequestFocus: false so Tab never stops on this node itself; hasFocus
  // still reports true whenever a descendant action button has focus.
  final FocusNode _actionsFocus = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'row-actions',
  );

  @override
  void initState() {
    super.initState();
    _actionsFocus.addListener(_onActionsFocusChange);
  }

  void _onActionsFocusChange() => setState(() {});

  @override
  void dispose() {
    _actionsFocus.removeListener(_onActionsFocusChange);
    _actionsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _hovered || _actionsFocus.hasFocus;
    return _RowActionsVisibility(
      visible: visible,
      child: Clickable(
        onPressed: widget.onTap,
        onHover: (hovered) => setState(() => _hovered = hovered),
        mouseCursor: WidgetStatePropertyAll(
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
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
        child: Focus(
          focusNode: _actionsFocus,
          child: Basic(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: widget.leading,
            // Basic top-aligns leading; centred on title+subtitle it lines up.
            leadingAlignment: Alignment.center,
            title: widget.title,
            subtitle: widget.subtitle,
            trailingAlignment: Alignment.center,
            trailing: widget.trailing ?? _actions(),
          ),
        ),
      ),
    );
  }

  Widget? _actions() {
    if (widget.onEdit == null && widget.onDelete == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (widget.onEdit != null)
          RowAction(
            icon: LucideIcons.pencil,
            tooltip: 'Modifica',
            onPressed: widget.onEdit,
          ),
        if (widget.onDelete != null)
          RowAction(
            icon: LucideIcons.trash2,
            tooltip: 'Elimina',
            onPressed: widget.onDelete,
            destructive: true,
          ),
      ],
    );
  }
}
