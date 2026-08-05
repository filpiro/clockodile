import 'package:flutter/material.dart';

import 'package:catui/catui.dart';


/// List row with mouse-hover highlight and hover-only actions
/// (shared UX between the entries, clients and report screens).
class HoverTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;

  /// Revealed on hover; space is reserved so rows don't shift.
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool dense;

  const HoverTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onTap,
    this.dense = false,
  });

  @override
  State<HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<HoverTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final highlight = Theme.of(context).colorScheme.surfaceContainerHighest;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      // The highlight is driven from MouseRegion rather than ListTile's own
      // hoverColor: InkResponse ignores hover when every callback is null, and
      // rows that aren't tappable (the active entry, note-less report rows)
      // still need to light up.
      child: TweenAnimationBuilder<double>(
        duration: AppTokens.hoverFade,
        tween: Tween(end: _hover ? 1.0 : 0.0),
        builder: (context, t, _) => ListTile(
          dense: widget.dense,
          tileColor: highlight.withValues(alpha: t),
          // Stock ink hover would stack on top of the color above.
          hoverColor: Colors.transparent,
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          onTap: widget.onTap,
          trailing: widget.actions.isEmpty
              ? null
              : IgnorePointer(
                  ignoring: !_hover,
                  child: Opacity(
                    opacity: _hover ? 1 : 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
